-- =====================================================
-- STORAGE SETUP FOR DRIVER VERIFICATION DOCUMENTS  
-- =====================================================
-- This creates the storage bucket for verification documents
-- Run this in your Supabase SQL Editor
-- =====================================================

-- Insert the verification-docs bucket into storage.buckets table
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'verification-docs',
  'verification-docs', 
  false, -- not public - only accessible to authenticated users
  20971520, -- 20MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for the verification-docs bucket
-- Allow authenticated users to upload files to their own folder
CREATE POLICY "Users can upload verification documents" ON storage.objects
  FOR INSERT 
  TO authenticated 
  WITH CHECK (
    bucket_id = 'verification-docs' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to view their own verification documents
CREATE POLICY "Users can view their own verification documents" ON storage.objects
  FOR SELECT 
  TO authenticated 
  USING (
    bucket_id = 'verification-docs' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow admins to view all verification documents for review
CREATE POLICY "Admins can view all verification documents" ON storage.objects
  FOR SELECT 
  TO authenticated 
  USING (
    bucket_id = 'verification-docs' AND 
    public.get_user_role(auth.uid()) = 'admin'
  );

-- Allow users to update/replace their own verification documents
CREATE POLICY "Users can update their own verification documents" ON storage.objects
  FOR UPDATE 
  TO authenticated 
  USING (
    bucket_id = 'verification-docs' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow users to delete their own verification documents if needed
CREATE POLICY "Users can delete their own verification documents" ON storage.objects
  FOR DELETE 
  TO authenticated 
  USING (
    bucket_id = 'verification-docs' AND 
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- =====================================================
-- VERIFICATION COMPLETE MESSAGE
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE 'Storage setup complete!';
    RAISE NOTICE 'Bucket created: verification-docs';
    RAISE NOTICE 'File size limit: 20MB';
    RAISE NOTICE 'Allowed types: JPEG, PNG, PDF';
    RAISE NOTICE 'RLS policies created for user access control';
END $$;