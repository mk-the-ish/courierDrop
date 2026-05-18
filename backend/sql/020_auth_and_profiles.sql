-- Migration 020: Auth & Profiles System
-- Purpose: Add courier and client profile tables, extend users table for profile tracking

-- Add profile tracking columns to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_step INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_method TEXT DEFAULT 'firebase'; -- 'firebase' or 'supabase'
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_complete BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'PENDING'; -- PENDING, APPROVED, REJECTED

-- Create courier profiles table
CREATE TABLE IF NOT EXISTS courier_profiles (
  id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  full_name TEXT,
  id_number TEXT UNIQUE,
  id_image_url TEXT,
  license_number TEXT UNIQUE,
  license_image_url TEXT,
  vehicle_registration TEXT UNIQUE,
  vehicle_registration_images TEXT[], -- Array of image URLs
  vehicle_type TEXT, -- 'motorcycle', 'car', 'van', 'truck'
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_year INTEGER,
  vehicle_color TEXT,
  vehicle_capacity_kg DECIMAL DEFAULT 50,
  vehicle_insurance_expiry DATE,
  profile_complete BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMP,
  verification_notes TEXT,
  rejected_at TIMESTAMP,
  rejection_reason TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  CONSTRAINT vehicle_year_range CHECK (vehicle_year >= 1990 AND vehicle_year <= EXTRACT(YEAR FROM NOW()) + 1)
);

-- Create client profiles table
CREATE TABLE IF NOT EXISTS client_profiles (
  id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  full_name TEXT,
  username TEXT UNIQUE,
  id_number TEXT UNIQUE,
  id_image_url TEXT,
  phone_number TEXT,
  profile_complete BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create profile verification audit table
CREATE TABLE IF NOT EXISTS profile_verification_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT REFERENCES users(id) ON DELETE CASCADE,
  admin_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL, -- 'approved', 'rejected', 'pending'
  reason TEXT,
  documents_reviewed TEXT[], -- Fields reviewed
  previous_status TEXT,
  new_status TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_courier_profiles_verification_status ON users(verification_status) WHERE role = 'courier';
CREATE INDEX IF NOT EXISTS idx_client_profiles_created ON client_profiles(created_at);
CREATE INDEX IF NOT EXISTS idx_courier_profiles_created ON courier_profiles(created_at);

-- Add comment for migration documentation
COMMENT ON TABLE courier_profiles IS 'Stores courier profile information including vehicle details and verification status';
COMMENT ON TABLE client_profiles IS 'Stores client profile information for account personalization';
COMMENT ON TABLE profile_verification_audit IS 'Audit trail for courier profile verification decisions';
