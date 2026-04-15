-- Schema Synchronization Migration
-- This migration ensures all tables match the desired schema by adding any missing columns and constraints

-- ============================================================================
-- users table - Ensure proper types and constraints
-- ============================================================================
ALTER TABLE public.users
ALTER COLUMN created_at TYPE timestamp without time zone USING created_at::timestamp without time zone;

ALTER TABLE public.users
ALTER COLUMN updated_at TYPE timestamp without time zone USING updated_at::timestamp without time zone;

-- ============================================================================
-- vehicles table - Add missing columns if any
-- ============================================================================
ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS registration_number TEXT;

ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS max_dimensions_cm TEXT;

ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS verification_photos JSONB;

ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

ALTER TABLE public.vehicles
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add unique constraint for registration_number if it doesn't exist
ALTER TABLE public.vehicles
DROP CONSTRAINT IF EXISTS vehicles_registration_number_key;

ALTER TABLE public.vehicles
ADD CONSTRAINT vehicles_registration_number_key UNIQUE (registration_number);

-- ============================================================================
-- corridors table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- parcels table - Already up to date (migration 011 was run)
-- ============================================================================
-- No changes needed, schema matches after migration 011

-- ============================================================================
-- parcel_checkpoints table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- handshake_events table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- error_logs table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- job_heartbeats table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- alert_rules table - Ensure it exists (referenced by alert_history)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.alert_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  condition JSONB NOT NULL,
  actions JSONB NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add missing columns if they don't exist
ALTER TABLE public.alert_rules
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

ALTER TABLE public.alert_rules
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.alert_rules
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS alert_rules_is_active_idx ON public.alert_rules (is_active);
CREATE INDEX IF NOT EXISTS alert_rules_created_at_idx ON public.alert_rules (created_at DESC);

-- ============================================================================
-- alert_history table - Already up to date
-- ============================================================================
-- No changes needed, schema matches

-- ============================================================================
-- device_tokens table - Ensure it exists
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  platform TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON public.device_tokens (user_id);

-- ============================================================================
-- parcel_assignment_queue table - Ensure it exists
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.parcel_assignment_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID NOT NULL REFERENCES public.parcels(id) ON DELETE CASCADE,
  corridor_id UUID NOT NULL REFERENCES public.corridors(id) ON DELETE CASCADE,
  rank INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'PENDING',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS parcel_assignment_queue_idx ON public.parcel_assignment_queue (parcel_id, status, rank);

-- ============================================================================
-- Final cleanup and verification
-- ============================================================================
-- Ensure all required columns and indexes are in place
-- All tables should now match the desired schema
