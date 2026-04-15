-- Create vehicles table to store courier vehicle information
-- This allows matching algorithms to consider vehicle capacity and type

CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL UNIQUE,
  vehicle_type TEXT NOT NULL, -- e.g., 'motorcycle', 'car', 'van', 'truck'
  make TEXT,
  model TEXT,
  year INTEGER,
  color TEXT,
  registration_number TEXT UNIQUE,
  license_plate TEXT,
  max_capacity_kg INTEGER,
  max_dimensions_cm TEXT, -- JSON: {"length": 100, "width": 80, "height": 60}
  current_utilization_kg INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  verification_status TEXT DEFAULT 'unverified', -- 'unverified', 'verified', 'rejected'
  verification_photos JSONB, -- URLs to verification photos
  verified_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT fk_courier_id FOREIGN KEY (courier_id) REFERENCES public.users(id) ON DELETE CASCADE
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS vehicles_courier_id_idx ON public.vehicles (courier_id);
CREATE INDEX IF NOT EXISTS vehicles_is_active_idx ON public.vehicles (is_active);
CREATE INDEX IF NOT EXISTS vehicles_vehicle_type_idx ON public.vehicles (vehicle_type);
CREATE INDEX IF NOT EXISTS vehicles_verification_status_idx ON public.vehicles (verification_status);

-- Add comments for documentation
COMMENT ON TABLE public.vehicles IS 'Stores courier vehicle information for delivery matching and capacity checks';
COMMENT ON COLUMN public.vehicles.courier_id IS 'Firebase UID of the courier who owns this vehicle';
COMMENT ON COLUMN public.vehicles.vehicle_type IS 'Type of vehicle: motorcycle, car, van, truck';
COMMENT ON COLUMN public.vehicles.max_capacity_kg IS 'Maximum weight capacity in kilograms';
COMMENT ON COLUMN public.vehicles.max_dimensions_cm IS 'Maximum parcel dimensions as JSON object';
COMMENT ON COLUMN public.vehicles.current_utilization_kg IS 'Current weight loaded on vehicle';
COMMENT ON COLUMN public.vehicles.verification_status IS 'Verification status for admin approval';
