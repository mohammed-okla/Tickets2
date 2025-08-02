-- =====================================================
-- TICKETS APP - COMPLETE SUPABASE SETUP
-- =====================================================
-- This file contains all SQL code and setup instructions
-- for the Tickets App Supabase backend infrastructure
-- =====================================================

-- =====================================================
-- 1. CUSTOM ENUMS
-- =====================================================

-- Create custom enums for the Tickets app
CREATE TYPE public.user_role AS ENUM ('passenger', 'driver', 'merchant', 'event_admin', 'admin');
CREATE TYPE public.language AS ENUM ('en', 'ar');
CREATE TYPE public.transaction_type AS ENUM ('payment', 'recharge', 'refund', 'withdrawal');
CREATE TYPE public.transaction_status AS ENUM ('pending', 'completed', 'failed', 'cancelled');
CREATE TYPE public.verification_status AS ENUM ('not_submitted', 'pending', 'approved', 'rejected');
CREATE TYPE public.notification_type AS ENUM ('payment', 'recharge', 'ticket', 'system', 'support');
CREATE TYPE public.conversation_status AS ENUM ('open', 'closed');
CREATE TYPE public.log_level AS ENUM ('info', 'warning', 'error', 'debug');

-- =====================================================
-- 2. CORE TABLES
-- =====================================================

-- User profiles table
CREATE TABLE public.profiles (
  id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL,
  email text UNIQUE NOT NULL,
  phone_number text,
  avatar_url text,
  user_type public.user_role NOT NULL DEFAULT 'passenger',
  language_preference public.language NOT NULL DEFAULT 'en',
  notification_preferences jsonb,
  is_active boolean NOT NULL DEFAULT true,
  is_verified boolean NOT NULL DEFAULT false,
  has_completed_tour boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Digital wallets table
CREATE TABLE public.wallets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  balance numeric(10, 2) NOT NULL DEFAULT 0.00,
  currency character varying(3) NOT NULL DEFAULT 'SYP',
  is_frozen boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Events table
CREATE TABLE public.events (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  parent_event_id uuid REFERENCES public.events(id) ON DELETE CASCADE,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  title text NOT NULL,
  description text,
  category text,
  start_date timestamp with time zone,
  end_date timestamp with time zone,
  location text,
  price numeric(10, 2),
  image_url text,
  available_quantity integer,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Driver profiles table
CREATE TABLE public.driver_profiles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  license_number text,
  license_expiry date,
  vehicle_type text,
  vehicle_model text,
  vehicle_plate text,
  route_name text,
  route_description text,
  ticket_fee numeric(10, 2) DEFAULT 500.00,
  earnings_today numeric(10, 2) NOT NULL DEFAULT 0.00,
  earnings_week numeric(10, 2) NOT NULL DEFAULT 0.00,
  earnings_month numeric(10, 2) NOT NULL DEFAULT 0.00,
  is_active boolean NOT NULL DEFAULT true,
  verification_status public.verification_status NOT NULL DEFAULT 'not_submitted',
  verification_documents jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Merchants table
CREATE TABLE public.merchants (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  business_name text NOT NULL,
  business_category text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- QR codes table
CREATE TABLE public.qr_codes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  qr_data text NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true,
  usage_count integer NOT NULL DEFAULT 0,
  max_usage integer,
  route_info text,
  vehicle_info text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  expires_at timestamp with time zone
);

-- Transactions table
CREATE TABLE public.transactions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  from_user_id uuid REFERENCES public.profiles(id),
  to_user_id uuid REFERENCES public.profiles(id),
  amount numeric(10, 2) NOT NULL,
  currency character varying(3) NOT NULL DEFAULT 'SYP',
  transaction_type public.transaction_type NOT NULL,
  status public.transaction_status NOT NULL DEFAULT 'pending',
  description text,
  reference_id text,
  qr_code_id uuid REFERENCES public.qr_codes(id),
  trip_id uuid,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  completed_at timestamp with time zone
);

-- User tickets table
CREATE TABLE public.user_tickets (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  transaction_id uuid NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  qr_code_data text NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'active',
  purchased_at timestamp with time zone NOT NULL DEFAULT now(),
  event_details_snapshot jsonb NOT NULL,
  ticket_number text NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Event admins table
CREATE TABLE public.event_admins (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE
);

-- Notifications table
CREATE TABLE public.notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  notification_type public.notification_type NOT NULL,
  title text NOT NULL,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  read_at timestamp with time zone,
  metadata jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Disputes table
CREATE TABLE public.disputes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  transaction_id uuid NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  reported_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  dispute_type text NOT NULL,
  description text NOT NULL,
  status text NOT NULL DEFAULT 'open',
  resolved_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Conversations table
CREATE TABLE public.conversations (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    status public.conversation_status NOT NULL DEFAULT 'open',
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Messages table
CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    conversation_id uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content text NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- System logs table
CREATE TABLE public.system_logs (
    id bigint generated by default as identity primary key,
    user_id uuid REFERENCES public.profiles(id),
    log_level public.log_level NOT NULL DEFAULT 'info',
    event_type text NOT NULL,
    message text NOT NULL,
    metadata jsonb,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Driver trips table
CREATE TABLE public.driver_trips (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  driver_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  route_name text,
  status text NOT NULL DEFAULT 'ongoing',
  passenger_count integer DEFAULT 0,
  earnings numeric(10, 2) DEFAULT 0.00,
  started_at timestamp with time zone DEFAULT now(),
  ended_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- =====================================================
-- 3. DATABASE FUNCTIONS
-- =====================================================

-- Helper function to get user role
CREATE OR REPLACE FUNCTION public.get_user_role(user_id uuid)
RETURNS public.user_role
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_role_result public.user_role;
BEGIN
  SELECT user_type INTO user_role_result
  FROM public.profiles
  WHERE id = user_id;
  
  RETURN user_role_result;
END;
$$;

-- Function to handle new user registration
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
    new.raw_user_meta_data->>'full_name',
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
    VALUES (new.id, new.raw_user_meta_data->>'full_name' || '''s Store');
  END IF;
  
  RETURN new;
END;
$$;

-- Function to process transport payments from passengers to drivers
CREATE OR REPLACE FUNCTION public.process_transport_payment(
    p_passenger_id uuid,
    p_driver_id uuid,
    p_amount numeric,
    p_qr_code_id uuid,
    p_quantity integer
)
RETURNS TABLE(transaction_id uuid, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  passenger_wallet public.wallets;
  driver_wallet public.wallets;
  new_transaction_id uuid;
  v_trip_id uuid;
BEGIN
  -- Validate inputs
  IF p_amount <= 0 THEN
    RETURN QUERY SELECT NULL::uuid, 'Payment amount must be positive.'::text;
    RETURN;
  END IF;
  IF p_quantity <= 0 THEN
      RETURN QUERY SELECT NULL::uuid, 'Quantity must be positive.'::text;
      RETURN;
  END IF;

  -- Get passenger's wallet
  SELECT * INTO passenger_wallet FROM public.wallets WHERE user_id = p_passenger_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, 'Passenger wallet not found.'::text;
    RETURN;
  END IF;
  IF passenger_wallet.balance < p_amount THEN
    RETURN QUERY SELECT NULL::uuid, 'Insufficient balance.'::text;
    RETURN;
  END IF;

  -- Get driver's wallet
  SELECT * INTO driver_wallet FROM public.wallets WHERE user_id = p_driver_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, 'Driver wallet not found.'::text;
    RETURN;
  END IF;
  
  -- Find the driver's currently active trip
  SELECT id INTO v_trip_id FROM public.driver_trips
  WHERE driver_id = p_driver_id AND status = 'ongoing'
  ORDER BY started_at DESC LIMIT 1;

  -- Perform the transfer
  UPDATE public.wallets SET balance = balance - p_amount WHERE id = passenger_wallet.id;
  UPDATE public.wallets SET balance = balance + p_amount WHERE id = driver_wallet.id;

  -- Update driver's daily earnings
  UPDATE public.driver_profiles SET earnings_today = earnings_today + p_amount WHERE user_id = p_driver_id;

  -- Create a transaction record
  INSERT INTO public.transactions (from_user_id, to_user_id, amount, transaction_type, status, qr_code_id, trip_id, description)
  VALUES (p_passenger_id, p_driver_id, p_amount, 'payment', 'completed', p_qr_code_id, v_trip_id, p_quantity || ' ticket(s)')
  RETURNING id INTO new_transaction_id;

  RETURN QUERY SELECT new_transaction_id, NULL::text;
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::uuid, 'An unexpected error occurred: ' || SQLERRM;
END;
$$;

-- Function to process merchant payments
CREATE OR REPLACE FUNCTION public.process_merchant_payment(
    p_passenger_id uuid,
    p_merchant_id uuid,
    p_amount numeric
)
RETURNS TABLE(transaction_id uuid, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  passenger_wallet public.wallets;
  merchant_wallet public.wallets;
  new_transaction_id uuid;
BEGIN
  IF p_amount <= 0 THEN
    RETURN QUERY SELECT NULL::uuid, 'Payment amount must be positive.'::text;
    RETURN;
  END IF;

  SELECT * INTO passenger_wallet FROM public.wallets WHERE user_id = p_passenger_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, 'Passenger wallet not found.'::text;
    RETURN;
  END IF;
  IF passenger_wallet.balance < p_amount THEN
    RETURN QUERY SELECT NULL::uuid, 'Insufficient balance.'::text;
    RETURN;
  END IF;

  SELECT * INTO merchant_wallet FROM public.wallets WHERE user_id = p_merchant_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, 'Merchant wallet not found.'::text;
    RETURN;
  END IF;

  UPDATE public.wallets SET balance = balance - p_amount WHERE id = passenger_wallet.id;
  UPDATE public.wallets SET balance = balance + p_amount WHERE id = merchant_wallet.id;

  INSERT INTO public.transactions (from_user_id, to_user_id, amount, transaction_type, status)
  VALUES (p_passenger_id, p_merchant_id, p_amount, 'payment', 'completed')
  RETURNING id INTO new_transaction_id;

  RETURN QUERY SELECT new_transaction_id, NULL::text;
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::uuid, 'An unexpected error occurred: ' || SQLERRM;
END;
$$;

-- Function to handle wallet recharge
CREATE OR REPLACE FUNCTION public.handle_recharge(
    p_user_id uuid,
    p_amount numeric,
    p_provider_type text
)
RETURNS TABLE(transaction_id uuid, new_balance numeric, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_wallet public.wallets;
    new_transaction_id uuid;
    new_balance numeric;
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
    UPDATE public.wallets SET balance = balance + p_amount WHERE user_id = p_user_id;

    -- Create transaction record
    INSERT INTO public.transactions (to_user_id, amount, transaction_type, status, description)
    VALUES (p_user_id, p_amount, 'recharge', 'completed', 'Wallet recharge via ' || p_provider_type)
    RETURNING id INTO new_transaction_id;

    -- Get new balance
    SELECT balance INTO new_balance FROM public.wallets WHERE user_id = p_user_id;
    
    RETURN QUERY SELECT new_transaction_id, new_balance, NULL::text;
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT NULL::uuid, NULL::numeric, 'An unexpected error occurred: ' || SQLERRM;
END;
$$;

-- Function to purchase event tickets
CREATE OR REPLACE FUNCTION public.purchase_event_ticket(
    p_event_id uuid,
    p_user_id uuid,
    p_quantity integer
)
RETURNS TABLE(ticket_id uuid, transaction_id uuid, error_message text)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_event public.events;
  v_user_wallet public.wallets;
  v_total_price numeric;
  v_new_transaction_id uuid;
  i integer;
  v_new_ticket_id uuid;
BEGIN
  -- Validate inputs
  IF p_quantity <= 0 THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'Quantity must be at least 1.'::text;
    RETURN;
  END IF;

  -- Get event details
  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'Event not found.'::text;
    RETURN;
  END IF;

  -- Check if event is active and has tickets available
  IF NOT v_event.is_active THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'This event is not active for ticket sales.'::text;
    RETURN;
  END IF;
  
  IF v_event.available_quantity IS NOT NULL AND v_event.available_quantity < p_quantity THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'Not enough tickets available.'::text;
    RETURN;
  END IF;

  -- Get user wallet and check balance
  v_total_price := v_event.price * p_quantity;
  SELECT * INTO v_user_wallet FROM public.wallets WHERE user_id = p_user_id;
  IF v_user_wallet.balance < v_total_price THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'Insufficient balance.'::text;
    RETURN;
  END IF;

  -- Start transaction
  UPDATE public.wallets SET balance = balance - v_total_price WHERE user_id = p_user_id;

  -- Update event quantity
  IF v_event.available_quantity IS NOT NULL THEN
    UPDATE public.events SET available_quantity = available_quantity - p_quantity WHERE id = p_event_id;
  END IF;

  -- Create a single financial transaction for the entire purchase
  INSERT INTO public.transactions (from_user_id, to_user_id, amount, transaction_type, status, description, reference_id)
  VALUES (p_user_id, v_event.created_by, v_total_price, 'payment', 'completed', p_quantity || ' ticket(s) for ' || v_event.title, p_event_id)
  RETURNING id INTO v_new_transaction_id;

  -- Create individual tickets
  FOR i IN 1..p_quantity LOOP
    INSERT INTO public.user_tickets (user_id, event_id, transaction_id, event_details_snapshot)
    VALUES (p_user_id, p_event_id, v_new_transaction_id, jsonb_build_object('name', v_event.title, 'event_date', v_event.start_date, 'location', v_event.location, 'price', v_event.price))
    RETURNING id INTO v_new_ticket_id;
  END LOOP;

  -- Return the ID of the last ticket created and the transaction ID
  RETURN QUERY SELECT v_new_ticket_id, v_new_transaction_id, NULL::text;
EXCEPTION
  WHEN OTHERS THEN
    RETURN QUERY SELECT NULL::uuid, NULL::uuid, 'An unexpected error occurred: ' || SQLERRM;
END;
$$;

-- =====================================================
-- 4. TRIGGERS
-- =====================================================

-- Create trigger for new user registration
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- =====================================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disputes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_trips ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Admins can update all profiles" ON public.profiles FOR UPDATE USING (public.get_user_role(auth.uid()) = 'admin');

-- Wallets policies
CREATE POLICY "Users can view their own wallet" ON public.wallets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own wallet" ON public.wallets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all wallets" ON public.wallets FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- Transactions policies
CREATE POLICY "Users can view their own transactions" ON public.transactions FOR SELECT 
USING (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "Users can insert their own transactions" ON public.transactions FOR INSERT 
WITH CHECK (auth.uid() = from_user_id OR auth.uid() = to_user_id);
CREATE POLICY "Admins can view all transactions" ON public.transactions FOR SELECT 
USING (public.get_user_role(auth.uid()) = 'admin');

-- Events policies
CREATE POLICY "Anyone can view active events" ON public.events FOR SELECT USING (is_active = true);
CREATE POLICY "Event creators can view their events" ON public.events FOR SELECT USING (auth.uid() = created_by);
CREATE POLICY "Event creators can update their events" ON public.events FOR UPDATE USING (auth.uid() = created_by);
CREATE POLICY "Event creators can insert events" ON public.events FOR INSERT WITH CHECK (auth.uid() = created_by);
CREATE POLICY "Event admins can view their events" ON public.events FOR SELECT 
USING (EXISTS (SELECT 1 FROM public.event_admins WHERE user_id = auth.uid() AND event_id = events.id));
CREATE POLICY "Admins can view all events" ON public.events FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- User tickets policies
CREATE POLICY "Users can view their own tickets" ON public.user_tickets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tickets" ON public.user_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Event admins can view tickets for their events" ON public.user_tickets FOR SELECT 
USING (EXISTS (SELECT 1 FROM public.event_admins WHERE user_id = auth.uid() AND event_id = user_tickets.event_id));

-- Event admins policies
CREATE POLICY "Event admins can view their assignments" ON public.event_admins FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Event creators can manage event admins" ON public.event_admins FOR ALL 
USING (EXISTS (SELECT 1 FROM public.events WHERE created_by = auth.uid() AND id = event_admins.event_id));

-- Driver profiles policies
CREATE POLICY "Drivers can view their own profile" ON public.driver_profiles FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Drivers can update their own profile" ON public.driver_profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Drivers can insert their own profile" ON public.driver_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all driver profiles" ON public.driver_profiles FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- Merchants policies
CREATE POLICY "Merchants can view their own profile" ON public.merchants FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Merchants can update their own profile" ON public.merchants FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Merchants can insert their own profile" ON public.merchants FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can view all merchant profiles" ON public.merchants FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- QR codes policies
CREATE POLICY "Drivers can view their own QR codes" ON public.qr_codes FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can insert their own QR codes" ON public.qr_codes FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers can update their own QR codes" ON public.qr_codes FOR UPDATE USING (auth.uid() = driver_id);

-- Notifications policies
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "System can insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- Disputes policies
CREATE POLICY "Users can view their own disputes" ON public.disputes FOR SELECT USING (auth.uid() = reported_by);
CREATE POLICY "Users can insert their own disputes" ON public.disputes FOR INSERT WITH CHECK (auth.uid() = reported_by);
CREATE POLICY "Admins can view all disputes" ON public.disputes FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Admins can update all disputes" ON public.disputes FOR UPDATE USING (public.get_user_role(auth.uid()) = 'admin');

-- Conversations policies
CREATE POLICY "Users can view their own conversations" ON public.conversations FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own conversations" ON public.conversations FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own conversations" ON public.conversations FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Admins can view all conversations" ON public.conversations FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- Messages policies
CREATE POLICY "Users can view messages in their conversations" ON public.messages FOR SELECT 
USING (EXISTS (SELECT 1 FROM public.conversations WHERE id = messages.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Users can insert messages in their conversations" ON public.messages FOR INSERT 
WITH CHECK (EXISTS (SELECT 1 FROM public.conversations WHERE id = messages.conversation_id AND user_id = auth.uid()));
CREATE POLICY "Admins can view all messages" ON public.messages FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "Admins can insert messages" ON public.messages FOR INSERT WITH CHECK (public.get_user_role(auth.uid()) = 'admin');

-- System logs policies
CREATE POLICY "Only admins can view system logs" ON public.system_logs FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');
CREATE POLICY "System can insert logs" ON public.system_logs FOR INSERT WITH CHECK (true);

-- Driver trips policies
CREATE POLICY "Drivers can view their own trips" ON public.driver_trips FOR SELECT USING (auth.uid() = driver_id);
CREATE POLICY "Drivers can insert their own trips" ON public.driver_trips FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "Drivers can update their own trips" ON public.driver_trips FOR UPDATE USING (auth.uid() = driver_id);
CREATE POLICY "Admins can view all trips" ON public.driver_trips FOR SELECT USING (public.get_user_role(auth.uid()) = 'admin');

-- =====================================================
-- 6. PERFORMANCE INDEXES
-- =====================================================

-- Performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(to_user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_from_user_id ON public.transactions(from_user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON public.transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON public.transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_events_active ON public.events(is_active);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.events(created_by);
CREATE INDEX IF NOT EXISTS idx_events_parent_event_id ON public.events(parent_event_id);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON public.wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallets_balance ON public.wallets(balance);
CREATE INDEX IF NOT EXISTS idx_user_tickets_user_id ON public.user_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_event_id ON public.user_tickets(event_id);
CREATE INDEX IF NOT EXISTS idx_user_tickets_transaction_id ON public.user_tickets(transaction_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON public.notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_user_id ON public.driver_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_merchants_user_id ON public.merchants(user_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_driver_id ON public.qr_codes(driver_id);
CREATE INDEX IF NOT EXISTS idx_qr_codes_qr_data ON public.qr_codes(qr_data);
CREATE INDEX IF NOT EXISTS idx_disputes_reported_by ON public.disputes(reported_by);
CREATE INDEX IF NOT EXISTS idx_disputes_transaction_id ON public.disputes(transaction_id);
CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON public.conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON public.messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_driver_trips_driver_id ON public.driver_trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_trips_status ON public.driver_trips(status);

-- =====================================================
-- 7. STORAGE BUCKETS SETUP INSTRUCTIONS
-- =====================================================

/*
STORAGE BUCKETS TO CREATE MANUALLY IN SUPABASE DASHBOARD:

1. Bucket: "avatars"
   - Public access: Enabled
   - File size limit: 5MB
   - Allowed mime types: image/*

2. Bucket: "event-images" 
   - Public access: Enabled
   - File size limit: 10MB
   - Allowed mime types: image/*

3. Bucket: "verification-docs"
   - Public access: Enabled  
   - File size limit: 20MB
   - Allowed mime types: image/*, application/pdf

Each bucket will automatically have RLS policies created for public access.
*/

-- =====================================================
-- 8. EDGE FUNCTIONS (Deploy separately)
-- =====================================================

/*
EDGE FUNCTIONS TO DEPLOY:

1. handle-recharge
   - Purpose: Processes wallet recharge requests
   - URL: /functions/v1/handle-recharge
   - Method: POST
   - Body: { amount: number, provider: string }

2. process-payment  
   - Purpose: Handles transport and merchant payments
   - URL: /functions/v1/process-payment
   - Method: POST
   - Body: { payment_type: string, to_user_id: uuid, amount: number, qr_code_id?: uuid, quantity?: number }

3. purchase-ticket
   - Purpose: Processes event ticket purchases
   - URL: /functions/v1/purchase-ticket
   - Method: POST
   - Body: { event_id: uuid, quantity: number }

All functions include:
- CORS headers for frontend integration
- JWT authentication validation
- Comprehensive error handling
- Input validation
*/

-- =====================================================
-- 9. SETUP COMPLETION CHECKLIST
-- =====================================================

/*
SETUP CHECKLIST:

✅ Database Schema:
   - Run all SQL commands above in order
   - Verify all tables are created (15 tables total)
   - Confirm all functions are deployed (6 functions)
   - Check all RLS policies are active (30+ policies)
   - Verify all indexes are created (20+ indexes)

✅ Storage:
   - Create 3 storage buckets manually
   - Verify public access is enabled
   - Test file upload permissions

✅ Edge Functions:
   - Deploy 3 edge functions separately
   - Test function endpoints
   - Verify CORS and authentication

✅ Testing:
   - Create test user accounts for each role
   - Test wallet creation and recharge
   - Test payment processing
   - Test event ticket purchasing
   - Verify all RLS policies work correctly

The backend infrastructure is now complete and ready for frontend integration!
*/

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
    current_table text;
BEGIN
    FOREACH current_table IN ARRAY table_names
    LOOP
        -- Enable RLS if table exists
        IF EXISTS (SELECT FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_name = current_table) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', current_table);
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
-- Fixed SQL Script - Run this in Supabase SQL Editor
-- =====================================================

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Check if essential tables exist and have RLS enabled (FIXED)
DO $$
DECLARE
    table_names text[] := ARRAY['profiles', 'wallets', 'transactions', 'events', 'user_tickets', 'driver_profiles', 'merchants'];
    table_name text;
BEGIN
    FOREACH table_name IN ARRAY table_names
    LOOP
        -- Enable RLS if table exists
        IF EXISTS (SELECT FROM information_schema.tables t WHERE t.table_schema = 'public' AND t.table_name = table_name) THEN
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', table_name);
        END IF;
    END LOOP;
END $$;
-- =====================================================
-- END OF ESSENTIAL SETUP
-- =====================================================

-- =====================================================
-- END OF SUPABASE SETUP
-- =====================================================