create or replace function set_corridor_line(
  p_corridor_id uuid,
  p_line_wkt text,
  p_start_wkt text,
  p_end_wkt text
)
returns void
language sql
as $$
  update corridors
  set
    corridor_line = st_geogfromtext(p_line_wkt),
    start_point = st_geogfromtext(p_start_wkt),
    end_point = st_geogfromtext(p_end_wkt)
  where id = p_corridor_id;
$$;
