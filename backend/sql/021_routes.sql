-- Migration 021: Route lifecycle management

CREATE TABLE IF NOT EXISTS routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  corridor_id UUID REFERENCES corridors(id) ON DELETE SET NULL,
  start_point geography(POINT, 4326),
  end_point geography(POINT, 4326),
  planned_start_at TIMESTAMP,
  declared_eta_minutes INTEGER,
  expected_duration_minutes INTEGER,
  status TEXT NOT NULL DEFAULT 'PLANNED', -- PLANNED|ACTIVE|COMPLETED|CANCELLED
  activated_at TIMESTAMP,
  completed_at TIMESTAMP,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS routes_courier_idx ON routes (courier_id, created_at DESC);
CREATE INDEX IF NOT EXISTS routes_status_idx ON routes (status, planned_start_at);

