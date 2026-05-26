-- Migration 026: Reusable courier route templates

CREATE TABLE IF NOT EXISTS route_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_location TEXT NOT NULL,
  end_location TEXT NOT NULL,
  start_point geography(POINT, 4326),
  end_point geography(POINT, 4326),
  route_line geography(LINESTRING, 4326),
  allow_multiple_parcels BOOLEAN NOT NULL DEFAULT true,
  declared_eta_minutes INTEGER NOT NULL DEFAULT 45,
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS route_templates_courier_idx
  ON route_templates (courier_id, created_at DESC);

CREATE INDEX IF NOT EXISTS route_templates_start_point_gix
  ON route_templates USING gist (start_point);

CREATE INDEX IF NOT EXISTS route_templates_end_point_gix
  ON route_templates USING gist (end_point);

CREATE INDEX IF NOT EXISTS route_templates_route_line_gix
  ON route_templates USING gist (route_line);
