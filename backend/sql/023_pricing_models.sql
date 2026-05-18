-- Migration 023: Pricing recommendation history and route pricing memory

CREATE TABLE IF NOT EXISTS route_pricing_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_key TEXT NOT NULL,
  corridor_id UUID REFERENCES corridors(id) ON DELETE SET NULL,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  distance_meters NUMERIC,
  weight_kg NUMERIC,
  size_code TEXT,
  recommended_price NUMERIC NOT NULL,
  accepted_price NUMERIC,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS route_pricing_history_route_idx
  ON route_pricing_history (route_key, created_at DESC);

CREATE TABLE IF NOT EXISTS price_recommendations_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id) ON DELETE CASCADE,
  corridor_id UUID REFERENCES corridors(id) ON DELETE SET NULL,
  factors JSONB NOT NULL DEFAULT '{}'::jsonb,
  recommended_price NUMERIC NOT NULL,
  model_version TEXT DEFAULT 'v2',
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS price_recommendations_log_parcel_idx
  ON price_recommendations_log (parcel_id, created_at DESC);

