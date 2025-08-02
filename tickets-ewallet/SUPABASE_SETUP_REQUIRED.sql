-- =====================================================
-- ESSENTIAL SUPABASE SETUP FOR TICKETS APP
-- =====================================================
-- Run these commands in Supabase SQL Editor if not already done
-- =====================================================

-- Enable necessary extensions first
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Check if enums exist, create if missing
DO $$ 
BEGIN
    -- Create user_role enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE public.user_role AS ENUM ('passenger', 'driver', 'merchant', 'event_admin', 'admin');
    END IF;

    -- Create language enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'language') THEN
        CREATE TYPE public.language AS ENUM ('en', 'ar');
    END IF;

    -- Create transaction_type enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_type') THEN
        CREATE TYPE public.transaction_type AS ENUM ('payment', 'recharge', 'refund', 'withdrawal');
    END IF;

    -- Create transaction_status enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'transaction_status') THEN
        CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'failed', 'cancelled');
    END IF;

    -- Create verification_status enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'verification_status') THEN
        CREATE TYPE public.verification_status AS ENUM ('not_submitted', 'pending', 'approved', 'rejected');
    END IF;

    -- Create notification_type enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_type') THEN
        CREATE TYPE public.notification_type AS ENUM ('payment', 'recharge', 'ticket', 'system', 'support');
    END IF;

    -- Create conversation_status enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'conversation_status') THEN
        CREATE TYPE public.conversation_status AS ENUM ('open', 'closed');
    END IF;

    -- Create log_level enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'log_level') THEN
        CREATE TYPE public.log_level AS ENUM ('info', 'warning', 'error', 'debug');
    END IF;
END $$;

-- Ensure the trigger function exists for new user registration
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_role public.user_role;
BEGIN
  -- Extract user role from metadata, default to 'passenger'
  v_user_role := (new.raw_user_meta_data->>'user_role')::public.user_role;
  IF v_user_role IS NULL THEN
    v_user_role := 'passenger';
  END IF;

  -- Create a profile for the new user
  INSERT INTO public.profiles (id, full_name, email, user_type)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'full_name', new.email),
    new.email,
    v_user_role
  );

  -- Create a wallet for the new user
  INSERT INTO public.wallets (user_id) VALUES (new.id);

  -- Create a driver/merchant profile if applicable
  IF v_user_role = 'driver' THEN
    INSERT INTO public.driver_profiles (user_id, license_number) VALUES (new.id, 'PENDING');
  ELSIF v_user_role = 'merchant' THEN
    INSERT INTO public.merchants (user_id, business_name)
    VALUES (new.id, COALESCE(new.raw_user_meta_data->>'full_name', new.email) || '''s Store');
  END IF;
  
  RETURN new;
END;
$$;

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Check if essential tables exist and have RLS enabled
DO $$
DECLARE
    table_names text[] := ARRAY['profiles', 'wallets', 'transactions', 'events', 'user_tickets', 'driver_profiles', 'merchants'];
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY table_names
    LOOP
        -- Enable RLS if table exists
        IF EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = table_name) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
        END IF;
    END LOOP;
END $$;

-- Essential RLS policies (re-create if missing)
-- Profiles policies
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Wallets policies
DROP POLICY IF EXISTS "Users can view their own wallet" ON public.wallets;
CREATE POLICY "Users can view their own wallet" ON public.wallets FOR SELECT USING (auth.uid() = user_id);

-- Enable realtime if needed for notifications
ALTER publication supabase_realtime ADD TABLE public.notifications;
ALTER publication supabase_realtime ADD TABLE public.transactions;

-- =====================================================
-- MANUAL STEPS REQUIRED IN SUPABASE DASHBOARD:
-- =====================================================

/*
1. STORAGE BUCKETS (Create in Storage section):
   - "avatars" (Public, 5MB limit, image/* types)
   - "event-images" (Public, 10MB limit, image/* types) 
   - "verification-docs" (Public, 20MB limit, image/*, application/pdf)

2. AUTHENTICATION SETTINGS:
   - Enable Email authentication
   - Set Site URL to your domain (for production)
   - Configure Email templates if needed

3. API SETTINGS:
   - Your URL: https://zedwbdksnduazpdveoab.supabase.co
   - Your Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InplZHdiZGtzbmR1YXpwZHZlb2FiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQwMDcwNDIsImV4cCI6MjA2OTU4MzA0Mn0.LjhdIRxPhAM0JTUdX9YdxHaSkffoDLV4RBkglKFksxI
*/

-- =====================================================
-- VERIFICATION QUERIES (Run to check setup):
-- =====================================================

-- Check if essential tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'wallets', 'transactions', 'events', 'user_tickets');

-- Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('profiles', 'wallets', 'transactions');

-- Check if trigger function exists
SELECT proname 
FROM pg_proc 
WHERE proname = 'handle_new_user';

-- Check if trigger exists
SELECT trigger_name 
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
AND trigger_name = 'on_auth_user_created';

-- =====================================================
-- END OF ESSENTIAL SETUP
-- =====================================================