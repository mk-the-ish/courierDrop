-- Ensure device_tokens table exists with proper schema
-- This migration is idempotent and safe to run multiple times

CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  platform TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for optimal query performance
CREATE INDEX IF NOT EXISTS device_tokens_user_idx ON public.device_tokens (user_id);
CREATE INDEX IF NOT EXISTS device_tokens_token_idx ON public.device_tokens (token);
CREATE INDEX IF NOT EXISTS device_tokens_created_at_idx ON public.device_tokens (created_at DESC);

-- Set table description for documentation
COMMENT ON TABLE public.device_tokens IS 'Stores Firebase push notification tokens for each user device';
COMMENT ON COLUMN public.device_tokens.user_id IS 'User identifier';
COMMENT ON COLUMN public.device_tokens.token IS 'Firebase push notification token';
COMMENT ON COLUMN public.device_tokens.platform IS 'Device platform (ios, android, web)';
COMMENT ON COLUMN public.device_tokens.last_seen_at IS 'Last time this token was verified as active';
