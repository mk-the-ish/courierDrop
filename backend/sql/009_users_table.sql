-- Add columns to existing users table for user profile and role information
-- This is needed for role-based access control in the backend

-- Add display_name column if it doesn't exist
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Add phone_number column if it doesn't exist
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS phone_number TEXT;

-- Add profile_picture_url column if it doesn't exist
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;

-- Add verified_at column if it doesn't exist
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Ensure role column has correct default value
ALTER TABLE public.users
ALTER COLUMN role SET DEFAULT 'user'::text;

-- Create indexes for common queries if they don't exist
CREATE INDEX IF NOT EXISTS users_role_idx ON public.users (role);
CREATE INDEX IF NOT EXISTS users_created_at_idx ON public.users (created_at DESC);
CREATE INDEX IF NOT EXISTS users_email_idx ON public.users (email);

-- Add comments for documentation
COMMENT ON TABLE public.users IS 'Stores user profile and role information';
COMMENT ON COLUMN public.users.id IS 'Firebase UID - primary key';
COMMENT ON COLUMN public.users.email IS 'User email address';
COMMENT ON COLUMN public.users.role IS 'User role: client or courier';
COMMENT ON COLUMN public.users.display_name IS 'User display name';
COMMENT ON COLUMN public.users.phone_number IS 'User phone number for contact';
COMMENT ON COLUMN public.users.profile_picture_url IS 'URL to user profile picture';
COMMENT ON COLUMN public.users.verified_at IS 'When user completed verification (email, phone, etc)';
COMMENT ON COLUMN public.users.created_at IS 'Account creation timestamp';
COMMENT ON COLUMN public.users.updated_at IS 'Last profile update timestamp';
