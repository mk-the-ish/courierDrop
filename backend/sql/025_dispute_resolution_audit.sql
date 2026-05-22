-- Migration 025: Immutable dispute resolution audit trail

CREATE TABLE IF NOT EXISTS dispute_resolution_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dispute_id UUID NOT NULL,
  parcel_id UUID,
  courier_id TEXT,
  admin_id TEXT,
  decision TEXT NOT NULL, -- APPROVE|REFUND|PARTIAL|ESCALATE
  notes TEXT,
  partial_amount NUMERIC,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS dispute_resolution_audit_dispute_idx
  ON dispute_resolution_audit (dispute_id, created_at DESC);

CREATE INDEX IF NOT EXISTS dispute_resolution_audit_parcel_idx
  ON dispute_resolution_audit (parcel_id, created_at DESC);

CREATE OR REPLACE FUNCTION prevent_dispute_audit_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'dispute_resolution_audit is immutable';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_dispute_audit_update ON dispute_resolution_audit;
CREATE TRIGGER trg_prevent_dispute_audit_update
BEFORE UPDATE ON dispute_resolution_audit
FOR EACH ROW EXECUTE FUNCTION prevent_dispute_audit_mutation();

DROP TRIGGER IF EXISTS trg_prevent_dispute_audit_delete ON dispute_resolution_audit;
CREATE TRIGGER trg_prevent_dispute_audit_delete
BEFORE DELETE ON dispute_resolution_audit
FOR EACH ROW EXECUTE FUNCTION prevent_dispute_audit_mutation();

