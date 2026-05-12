-- Logistics lifecycle: onboarding, recipient/dual tracking, meeting pickup, 3WH, tracking metadata

-- Users: verification flag (default false) + onboarding document URLs
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_verified boolean NOT NULL DEFAULT false;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS id_document_url text;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS license_document_url text;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS vehicle_document_url text;

-- Parcels: recipient + dual tracking + delivery metadata
ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS recipient_id text;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS dual_tracking boolean NOT NULL DEFAULT false;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS weight_kg double precision;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS client_eta_minutes integer;

-- Optional meeting point (courier-adjusted pickup gate)
ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS meeting_pickup_lat double precision;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS meeting_pickup_lng double precision;

-- Recipient-issued dropoff OTP (Scenario A)
ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS recipient_dropoff_otp_hash text;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS recipient_dropoff_otp_expires_at timestamptz;

-- Manual SMS dropoff OTP (Scenario B)
ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS manual_dropoff_phone text;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS manual_dropoff_otp_hash text;

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS manual_dropoff_otp_expires_at timestamptz;

CREATE INDEX IF NOT EXISTS parcels_recipient_id_idx ON public.parcels (recipient_id);

-- Courier aggregate score (updated by background job)
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS courier_score double precision;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS courier_score_updated_at timestamptz;

-- Tracking log metadata
ALTER TABLE public.courier_tracking_logs
  ADD COLUMN IF NOT EXISTS device_info jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.courier_tracking_logs
  ADD COLUMN IF NOT EXISTS network_info jsonb NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.courier_tracking_logs
  ADD COLUMN IF NOT EXISTS vector_progress_delta double precision;

-- Connectivity audit: optional metadata for pulse-gap analysis
ALTER TABLE public.connectivity_audit
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.users.is_verified IS 'KYC / onboarding complete; false until admin or policy verifies';
COMMENT ON COLUMN public.parcels.dual_tracking IS 'When true, notify both sender and recipient for parcel events';
