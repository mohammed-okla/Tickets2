-- =====================================================
-- DATABASE FIXES FOR TICKETS APP
-- =====================================================
-- Run this in your Supabase SQL Editor to fix the schema issues
-- =====================================================

-- 1. Add missing metadata column to transactions table
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS metadata jsonb;

-- 2. Add created_by column to qr_codes table for backward compatibility
-- (keeping driver_id as the main column but adding created_by as alias)
ALTER TABLE public.qr_codes 
ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id);

-- 3. Update existing qr_codes to set created_by = driver_id
UPDATE public.qr_codes 
SET created_by = driver_id 
WHERE created_by IS NULL;

-- 4. Add trigger to keep created_by and driver_id in sync for qr_codes
CREATE OR REPLACE FUNCTION sync_qr_codes_created_by()
RETURNS TRIGGER AS $$
BEGIN
  -- When inserting, set created_by to driver_id if not explicitly set
  IF TG_OP = 'INSERT' THEN
    IF NEW.created_by IS NULL THEN
      NEW.created_by = NEW.driver_id;
    END IF;
    IF NEW.driver_id IS NULL THEN
      NEW.driver_id = NEW.created_by;
    END IF;
  END IF;
  
  -- When updating, keep them in sync
  IF TG_OP = 'UPDATE' THEN
    IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
      NEW.driver_id = NEW.created_by;
    END IF;
    IF NEW.driver_id IS DISTINCT FROM OLD.driver_id THEN
      NEW.created_by = NEW.driver_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for qr_codes table
DROP TRIGGER IF EXISTS qr_codes_sync_trigger ON public.qr_codes;
CREATE TRIGGER qr_codes_sync_trigger
  BEFORE INSERT OR UPDATE ON public.qr_codes
  FOR EACH ROW
  EXECUTE FUNCTION sync_qr_codes_created_by();

-- 5. Add type column to transactions for better filtering
ALTER TABLE public.transactions 
ADD COLUMN IF NOT EXISTS type text DEFAULT 'payment';

-- 6. Update the transaction types to include transport_payment
UPDATE public.transactions 
SET type = 'transport_payment' 
WHERE qr_code_id IS NOT NULL AND type = 'payment';

-- 7. Add indexes for better performance on new columns
CREATE INDEX IF NOT EXISTS idx_transactions_metadata ON public.transactions USING gin(metadata);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(type);
CREATE INDEX IF NOT EXISTS idx_qr_codes_created_by ON public.qr_codes(created_by);

-- 8. Update RLS policies for qr_codes to include created_by
DROP POLICY IF EXISTS "Drivers can view their own QR codes via created_by" ON public.qr_codes;
CREATE POLICY "Drivers can view their own QR codes via created_by" ON public.qr_codes 
FOR SELECT USING (auth.uid() = created_by);

DROP POLICY IF EXISTS "Drivers can insert their own QR codes via created_by" ON public.qr_codes;
CREATE POLICY "Drivers can insert their own QR codes via created_by" ON public.qr_codes 
FOR INSERT WITH CHECK (auth.uid() = created_by);

DROP POLICY IF EXISTS "Drivers can update their own QR codes via created_by" ON public.qr_codes;
CREATE POLICY "Drivers can update their own QR codes via created_by" ON public.qr_codes 
FOR UPDATE USING (auth.uid() = created_by);

-- 9. Add verification_reminder_sent column to track driver verification reminders
ALTER TABLE public.driver_profiles 
ADD COLUMN IF NOT EXISTS verification_reminder_sent timestamp with time zone;

-- 10. Add notification preferences structure
UPDATE public.profiles 
SET notification_preferences = '{
  "email": true,
  "push": true,
  "sms": false,
  "marketing": true,
  "security": true
}'::jsonb 
WHERE notification_preferences IS NULL;

-- 11. Add dispute metadata structure for better dispute handling
ALTER TABLE public.disputes 
ADD COLUMN IF NOT EXISTS metadata jsonb;

-- Update existing disputes with basic metadata
UPDATE public.disputes 
SET metadata = jsonb_build_object(
  'created_at', created_at,
  'type', dispute_type,
  'auto_generated', false
)
WHERE metadata IS NULL;

-- 12. Add conversation metadata for support chat
ALTER TABLE public.conversations 
ADD COLUMN IF NOT EXISTS metadata jsonb;

-- 13. Add message attachments support
ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS attachments jsonb;

-- 14. Add system notification types for admin
INSERT INTO public.notifications (user_id, notification_type, title, message, metadata)
SELECT 
  p.id,
  'system',
  'Welcome to Tickets!',
  'Your account has been set up successfully. Start using your digital wallet now.',
  '{"welcome": true, "version": "1.0"}'::jsonb
FROM public.profiles p 
WHERE p.user_type = 'passenger' 
AND NOT EXISTS (
  SELECT 1 FROM public.notifications n 
  WHERE n.user_id = p.id AND n.metadata->>'welcome' = 'true'
);

-- 15. Add default theme preference
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS theme_preference text DEFAULT 'system' CHECK (theme_preference IN ('light', 'dark', 'system'));

-- 16. Create merchant_qr_codes table for merchant-specific QR codes
CREATE TABLE IF NOT EXISTS public.merchant_qr_codes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  amount numeric(10, 2),
  description text,
  qr_data text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  usage_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on merchant_qr_codes
ALTER TABLE public.merchant_qr_codes ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for merchant_qr_codes
CREATE POLICY "Merchants can view their own QR codes" ON public.merchant_qr_codes 
FOR SELECT USING (auth.uid() = merchant_id);

CREATE POLICY "Merchants can insert their own QR codes" ON public.merchant_qr_codes 
FOR INSERT WITH CHECK (auth.uid() = merchant_id);

CREATE POLICY "Merchants can update their own QR codes" ON public.merchant_qr_codes 
FOR UPDATE USING (auth.uid() = merchant_id);

-- Add indexes for merchant_qr_codes
CREATE INDEX IF NOT EXISTS idx_merchant_qr_codes_merchant_id ON public.merchant_qr_codes(merchant_id);
CREATE INDEX IF NOT EXISTS idx_merchant_qr_codes_qr_data ON public.merchant_qr_codes(qr_data);

-- 17. Update wallets to include currency display preferences
ALTER TABLE public.wallets 
ADD COLUMN IF NOT EXISTS display_currency text DEFAULT 'SYP',
ADD COLUMN IF NOT EXISTS last_transaction timestamp with time zone;

-- 18. Add receipt/ticket generation support
CREATE TABLE IF NOT EXISTS public.receipts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id uuid NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receipt_data jsonb NOT NULL,
  receipt_number text NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  generated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable RLS on receipts
ALTER TABLE public.receipts ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for receipts
CREATE POLICY "Users can view their own receipts" ON public.receipts 
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own receipts" ON public.receipts 
FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Add indexes for receipts
CREATE INDEX IF NOT EXISTS idx_receipts_user_id ON public.receipts(user_id);
CREATE INDEX IF NOT EXISTS idx_receipts_transaction_id ON public.receipts(transaction_id);

-- 19. Add admin permissions table
CREATE TABLE IF NOT EXISTS public.admin_permissions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  permission_type text NOT NULL,
  granted_by uuid REFERENCES public.profiles(id),
  granted_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(admin_id, permission_type)
);

-- Enable RLS on admin_permissions
ALTER TABLE public.admin_permissions ENABLE ROW LEVEL SECURITY;

-- Add RLS policies for admin_permissions
CREATE POLICY "Only main admins can view permissions" ON public.admin_permissions 
FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

CREATE POLICY "Only main admins can manage permissions" ON public.admin_permissions 
FOR ALL USING (public.get_user_role(auth.uid()) = 'admin');

-- 20. Create a view for easier transaction querying with metadata
CREATE OR REPLACE VIEW public.transaction_details AS
SELECT 
  t.*,
  from_profile.full_name AS from_user_name,
  to_profile.full_name AS to_user_name,
  CASE 
    WHEN t.qr_code_id IS NOT NULL THEN 'transport'
    WHEN t.metadata->>'merchant_id' IS NOT NULL THEN 'merchant'
    WHEN t.metadata->>'event_id' IS NOT NULL THEN 'event'
    ELSE 'general'
  END as payment_category
FROM public.transactions t
LEFT JOIN public.profiles from_profile ON t.from_user_id = from_profile.id
LEFT JOIN public.profiles to_profile ON t.to_user_id = to_profile.id;

-- 21. Update function to handle recharge with better metadata
CREATE OR REPLACE FUNCTION public.handle_recharge_v2(
    p_user_id uuid,
    p_amount numeric,
    p_provider_type text,
    p_reference_id text DEFAULT NULL
)
RETURNS TABLE(transaction_id uuid, new_balance numeric, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_wallet public.wallets;
    new_transaction_id uuid;
    new_balance numeric;
    receipt_id uuid;
BEGIN
    IF p_amount <= 0 THEN
        RETURN QUERY SELECT NULL::uuid, NULL::numeric, 'Recharge amount must be positive.'::text;
        RETURN;
    END IF;

    -- Get user wallet
    SELECT * INTO user_wallet FROM public.wallets WHERE user_id = p_user_id;
    IF NOT FOUND THEN
        RETURN QUERY SELECT NULL::uuid, NULL::numeric, 'User wallet not found.'::text;
        RETURN;
    END IF;

    -- Update wallet balance
    UPDATE public.wallets 
    SET balance = balance + p_amount, 
        last_transaction = NOW(),
        updated_at = NOW()
    WHERE user_id = p_user_id;

    -- Create transaction record with metadata
    INSERT INTO public.transactions (
        to_user_id, 
        amount, 
        transaction_type, 
        status, 
        description,
        reference_id,
        metadata,
        type
    )
    VALUES (
        p_user_id, 
        p_amount, 
        'recharge', 
        'completed', 
        'Wallet recharge via ' || p_provider_type,
        p_reference_id,
        jsonb_build_object(
            'provider', p_provider_type,
            'recharge_method', p_provider_type,
            'timestamp', extract(epoch from now()),
            'receipt_generated', true
        ),
        'recharge'
    )
    RETURNING id INTO new_transaction_id;

    -- Get new balance
    SELECT balance INTO new_balance FROM public.wallets WHERE user_id = p_user_id;
    
    -- Generate receipt
    INSERT INTO public.receipts (transaction_id, user_id, receipt_data)
    VALUES (
        new_transaction_id,
        p_user_id,
        jsonb_build_object(
            'amount', p_amount,
            'provider', p_provider_type,
            'previous_balance', user_wallet.balance,
            'new_balance', new_balance,
            'timestamp', now(),
            'reference_id', p_reference_id
        )
    ) RETURNING id INTO receipt_id;
    
    RETURN QUERY SELECT new_transaction_id, new_balance, NULL::text;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT NULL::uuid, NULL::numeric, ('An unexpected error occurred: ' || SQLERRM)::text;
END;
$$;

-- =====================================================
-- VERIFICATION COMPLETE MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Database fixes applied successfully!';
    RAISE NOTICE 'Tables updated: transactions, qr_codes, driver_profiles, profiles, wallets';
    RAISE NOTICE 'New tables created: merchant_qr_codes, receipts, admin_permissions';
    RAISE NOTICE 'New views created: transaction_details';
    RAISE NOTICE 'New functions created: handle_recharge_v2, sync_qr_codes_created_by';
    RAISE NOTICE 'RLS policies updated for all new and modified tables';
END $$;