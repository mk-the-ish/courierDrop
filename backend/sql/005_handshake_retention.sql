create or replace function cleanup_handshake_events(p_days integer default 30)
returns integer
language plpgsql
as $$
declare
  deleted_count integer;
begin
  delete from handshake_events
  where created_at < now() - (p_days || ' days')::interval;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;
