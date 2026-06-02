-- Migration 027: align backend runtime tables with current code paths

CREATE TABLE IF NOT EXISTS public.courier_score_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  score NUMERIC NOT NULL,
  components JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS courier_score_snapshots_courier_idx
  ON public.courier_score_snapshots (courier_id, created_at DESC);

ALTER TABLE public.notification_recipients
  ALTER COLUMN user_id TYPE TEXT USING user_id::text;

