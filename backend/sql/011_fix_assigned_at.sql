-- Add missing columns to parcels table from backend requirements
-- This migration adds courier assignment and delivery tracking columns

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS assigned_courier_id text null,
ADD COLUMN IF NOT EXISTS assigned_at timestamp with time zone null,
ADD COLUMN IF NOT EXISTS pickup_lat double precision null,
ADD COLUMN IF NOT EXISTS pickup_lng double precision null,
ADD COLUMN IF NOT EXISTS pickup_accuracy_m double precision null,
ADD COLUMN IF NOT EXISTS dropoff_lat double precision null,
ADD COLUMN IF NOT EXISTS dropoff_lng double precision null,
ADD COLUMN IF NOT EXISTS dropoff_accuracy_m double precision null,
ADD COLUMN IF NOT EXISTS pickup_pin_attempts integer not null default 0,
ADD COLUMN IF NOT EXISTS dropoff_pin_attempts integer not null default 0,
ADD COLUMN IF NOT EXISTS pin_locked_until timestamp with time zone null;

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS parcels_assigned_courier_idx
  ON public.parcels (assigned_courier_id, assigned_at DESC);

CREATE INDEX IF NOT EXISTS parcels_status_idx
  ON public.parcels (status);

CREATE INDEX IF NOT EXISTS parcels_assigned_courier_status_idx
  ON public.parcels (assigned_courier_id, status);

