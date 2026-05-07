-- Admin intelligence and rating lifecycle additions

ALTER TABLE public.courier_tracking_logs
ADD COLUMN IF NOT EXISTS via_batch_sync boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS courier_tracking_logs_via_batch_sync_idx
  ON public.courier_tracking_logs (via_batch_sync, created_at DESC);

CREATE TABLE IF NOT EXISTS public.connectivity_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id text,
  parcel_id uuid REFERENCES public.parcels(id) ON DELETE SET NULL,
  lat double precision,
  lng double precision,
  source text NOT NULL DEFAULT 'batch_sync_failure',
  reason text,
  age_ms bigint,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS connectivity_audit_created_idx
  ON public.connectivity_audit (created_at DESC);

CREATE INDEX IF NOT EXISTS connectivity_audit_source_idx
  ON public.connectivity_audit (source, created_at DESC);

CREATE INDEX IF NOT EXISTS connectivity_audit_lat_lng_idx
  ON public.connectivity_audit (lat, lng);

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS rating_submitted boolean NOT NULL DEFAULT false;

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS rating_value integer;

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS rating_feedback text;

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS rated_at timestamptz;

CREATE INDEX IF NOT EXISTS parcels_rating_submitted_idx
  ON public.parcels (rating_submitted, dropoff_verified_at DESC);
