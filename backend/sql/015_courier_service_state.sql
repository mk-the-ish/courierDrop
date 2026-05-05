-- Courier service-state extensions
-- OFFLINE/ONLINE/TRAVELLING lifecycle support

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS current_route_id UUID NULL REFERENCES public.corridors(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS users_is_active_idx ON public.users(is_active);
CREATE INDEX IF NOT EXISTS users_current_route_idx ON public.users(current_route_id);

-- Admin-configurable system settings
CREATE TABLE IF NOT EXISTS public.system_settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_by TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.system_settings (key, value, updated_by)
VALUES
  ('maintenance_mode', 'false'::jsonb, 'migration'),
  ('global_matching_buffer_m', '500'::jsonb, 'migration'),
  ('route_deviation_threshold_m', '500'::jsonb, 'migration'),
  ('inactivity_timeout_minutes', '15'::jsonb, 'migration')
ON CONFLICT (key) DO NOTHING;
