-- Migration 028: Corridor lifecycle status

ALTER TABLE corridors
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'PENDING';

ALTER TABLE corridors
  ADD COLUMN IF NOT EXISTS planned_start_at timestamptz;

CREATE INDEX IF NOT EXISTS corridors_status_idx
  ON corridors (status, created_at desc);

UPDATE corridors
SET status = CASE
  WHEN status IS NULL THEN 'PENDING'
  ELSE status
END;

ALTER TABLE corridors
  ADD CONSTRAINT corridors_status_check
  CHECK (status IN ('PENDING', 'ACTIVE', 'COMPLETED', 'CANCELLED'));
