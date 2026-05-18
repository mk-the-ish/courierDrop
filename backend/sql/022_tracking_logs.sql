-- Migration 022: Heuristic tracking log support

ALTER TABLE courier_tracking_logs
ADD COLUMN IF NOT EXISTS heuristic_flags JSONB DEFAULT '{}'::jsonb;

ALTER TABLE courier_tracking_logs
ADD COLUMN IF NOT EXISTS speed_kmh NUMERIC;

ALTER TABLE courier_tracking_logs
ADD COLUMN IF NOT EXISTS waypoint_tag TEXT; -- PICKUP|DROPOFF|null

ALTER TABLE route_deviation_events
ADD COLUMN IF NOT EXISTS resolution_status TEXT;

ALTER TABLE route_deviation_events
ADD COLUMN IF NOT EXISTS resolution_notes TEXT;

ALTER TABLE route_deviation_events
ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP;

ALTER TABLE route_deviation_events
ADD COLUMN IF NOT EXISTS resolved_by TEXT;

CREATE TABLE IF NOT EXISTS route_adherence_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parcel_id UUID REFERENCES parcels(id) ON DELETE SET NULL,
  adherence_score INTEGER NOT NULL,
  off_corridor_ratio NUMERIC,
  stationary_minutes NUMERIC,
  max_speed_kmh NUMERIC,
  anomalies JSONB DEFAULT '[]'::jsonb,
  pickup_visited BOOLEAN DEFAULT FALSE,
  dropoff_visited BOOLEAN DEFAULT FALSE,
  generated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS route_adherence_reports_courier_idx
  ON route_adherence_reports (courier_id, generated_at DESC);
