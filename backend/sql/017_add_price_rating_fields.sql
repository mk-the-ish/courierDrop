-- Add price-related fields to parcels table if they don't exist
ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS recommended_price NUMERIC,
ADD COLUMN IF NOT EXISTS user_price NUMERIC,
ADD COLUMN IF NOT EXISTS final_price NUMERIC,
ADD COLUMN IF NOT EXISTS size_code TEXT;

-- Add rating fields if they don't exist
ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS rating_value NUMERIC,
ADD COLUMN IF NOT EXISTS rating_feedback TEXT,
ADD COLUMN IF NOT EXISTS rating_submitted BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS rated_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS route_adherence_percent NUMERIC,
ADD COLUMN IF NOT EXISTS punctuality_minutes_delta NUMERIC;

-- Create index for price lookups
CREATE INDEX IF NOT EXISTS parcels_price_idx ON public.parcels(recommended_price, user_price);
CREATE INDEX IF NOT EXISTS parcels_size_idx ON public.parcels(size_code);
CREATE INDEX IF NOT EXISTS parcels_rating_idx ON public.parcels(rating_submitted, rating_value);
