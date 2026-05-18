-- Migration 024: ETA model and connectivity intelligence

CREATE TABLE IF NOT EXISTS eta_calculations_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id) ON DELETE CASCADE,
  courier_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  eta_minutes INTEGER NOT NULL,
  confidence TEXT NOT NULL DEFAULT 'LOW', -- LOW|MEDIUM|HIGH
  distance_meters NUMERIC,
  breakdown JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS eta_calculations_log_parcel_idx
  ON eta_calculations_log (parcel_id, created_at DESC);

CREATE TABLE IF NOT EXISTS connectivity_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  lat NUMERIC NOT NULL,
  lng NUMERIC NOT NULL,
  network_provider TEXT,
  device_model TEXT,
  signal_bucket TEXT, -- GOOD|FAIR|POOR|OFFLINE
  source TEXT DEFAULT 'tracking_pulse',
  observed_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS connectivity_map_observed_idx
  ON connectivity_map (observed_at DESC);

CREATE TABLE IF NOT EXISTS zone_connectivity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_key TEXT NOT NULL UNIQUE,
  center_lat NUMERIC NOT NULL,
  center_lng NUMERIC NOT NULL,
  pulse_count INTEGER NOT NULL DEFAULT 0,
  poor_count INTEGER NOT NULL DEFAULT 0,
  offline_count INTEGER NOT NULL DEFAULT 0,
  score NUMERIC DEFAULT 1.0,
  updated_at TIMESTAMP DEFAULT NOW()
);

