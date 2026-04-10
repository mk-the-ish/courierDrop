create or replace function match_delivery_to_couriers(
  p_origin geography,
  p_destination geography,
  p_max_detour_m double precision default 50
)
returns table (
  corridor_id uuid,
  pickup_point geography,
  dropoff_point geography,
  pickup_fraction double precision,
  dropoff_fraction double precision,
  corridor_line geography
)
language sql
stable
as $$
  select
    c.id as corridor_id,
    st_closestpoint(c.corridor_line::geometry, p_origin::geometry)::geography as pickup_point,
    st_closestpoint(c.corridor_line::geometry, p_destination::geometry)::geography as dropoff_point,
    st_linelocatepoint(c.corridor_line::geometry, p_origin::geometry) as pickup_fraction,
    st_linelocatepoint(c.corridor_line::geometry, p_destination::geometry) as dropoff_fraction,
    c.corridor_line
  from corridors c
  where c.corridor_line is not null
    and st_dwithin(c.corridor_line, p_origin, p_max_detour_m)
    and st_dwithin(c.corridor_line, p_destination, p_max_detour_m)
    and st_linelocatepoint(c.corridor_line::geometry, p_origin::geometry)
        < st_linelocatepoint(c.corridor_line::geometry, p_destination::geometry)
  order by
    st_distance(c.corridor_line, p_origin) + st_distance(c.corridor_line, p_destination)
  limit 50;
$$;

create or replace function match_corridors_for_parcel(
  p_origin geography,
  p_destination geography,
  p_max_detour_m double precision default 50
)
returns table (
  corridor_id uuid,
  pickup_point geography,
  dropoff_point geography,
  pickup_fraction double precision,
  dropoff_fraction double precision
)
language sql
stable
as $$
  select
    c.id as corridor_id,
    st_closestpoint(c.corridor_line::geometry, p_origin::geometry)::geography as pickup_point,
    st_closestpoint(c.corridor_line::geometry, p_destination::geometry)::geography as dropoff_point,
    st_linelocatepoint(c.corridor_line::geometry, p_origin::geometry) as pickup_fraction,
    st_linelocatepoint(c.corridor_line::geometry, p_destination::geometry) as dropoff_fraction
  from corridors c
  where c.corridor_line is not null
    and st_dwithin(c.corridor_line, p_origin, p_max_detour_m)
    and st_dwithin(c.corridor_line, p_destination, p_max_detour_m)
    and st_linelocatepoint(c.corridor_line::geometry, p_origin::geometry)
        < st_linelocatepoint(c.corridor_line::geometry, p_destination::geometry)
  order by
    st_distance(c.corridor_line, p_origin) + st_distance(c.corridor_line, p_destination)
  limit 50;
$$;
