-- Migration 027: Add place name fields to route_templates and corridors

ALTER TABLE route_templates
  ADD COLUMN start_place_name TEXT,
  ADD COLUMN end_place_name TEXT;

ALTER TABLE corridors
  ADD COLUMN start_place_name TEXT,
  ADD COLUMN end_place_name TEXT;

CREATE INDEX IF NOT EXISTS route_templates_place_names_idx
  ON route_templates (start_place_name, end_place_name);

CREATE INDEX IF NOT EXISTS corridors_place_names_idx
  ON corridors (start_place_name, end_place_name);
