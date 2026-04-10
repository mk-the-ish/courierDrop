-- Schedule daily cleanup at 02:00 Africa/Johannesburg.
-- Requires pg_cron to be enabled in Supabase.
-- Runs cleanup_handshake_events(30).
select
  cron.schedule(
    'handshake_cleanup_daily',
    '0 2 * * *',
    $$select cleanup_handshake_events(30);$$
  );
