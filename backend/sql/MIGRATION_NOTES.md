# Migration Notes

## 2026-03-21: Heartbeat Ownership Column

`job_heartbeats` now includes `created_by` to enforce ownership checks on
heartbeat upserts. If your table already exists, apply:

```sql
alter table job_heartbeats
  add column if not exists created_by text;
```

## 2026-03-21: Request ID Columns

Request tracing columns were added for correlation across writes. If you have
existing tables, apply:

```sql
alter table job_heartbeats
  add column if not exists request_id text;

alter table error_logs
  add column if not exists request_id text;

alter table corridors
  add column if not exists request_id text;

alter table parcels
  add column if not exists request_id text;
```

## 2026-03-21: Spatial Fields (PostGIS)

Corridors and parcels now include geography columns for matching. Apply:

```sql
alter table corridors
  add column if not exists start_point geography(point, 4326),
  add column if not exists end_point geography(point, 4326),
  add column if not exists corridor_line geography(linestring, 4326);

alter table parcels
  add column if not exists origin_point geography(point, 4326),
  add column if not exists destination_point geography(point, 4326),
  add column if not exists pickup_point geography(point, 4326),
  add column if not exists dropoff_point geography(point, 4326);
```

Optional indexes:

```sql
create index if not exists corridors_line_gix on corridors using gist (corridor_line);
create index if not exists corridors_start_point_gix on corridors using gist (start_point);
create index if not exists corridors_end_point_gix on corridors using gist (end_point);

create index if not exists parcels_origin_point_gix on parcels using gist (origin_point);
create index if not exists parcels_destination_point_gix on parcels using gist (destination_point);
create index if not exists parcels_pickup_point_gix on parcels using gist (pickup_point);
create index if not exists parcels_dropoff_point_gix on parcels using gist (dropoff_point);
```

## 2026-03-21: Matching RPCs

If the RPCs are not present, apply:

```sql
-- match_delivery_to_couriers
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

-- match_corridors_for_parcel
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
```

## 2026-03-21: Corridor Line Helper Function

If the corridor line helper does not exist, apply:

```sql
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
```

## 2026-03-21: Heartbeat & Error Indexes

Optional indexes to speed up monitoring and admin queries:

```sql
create index if not exists job_heartbeats_status_idx
  on job_heartbeats (status);

create index if not exists error_logs_occurred_at_idx
  on error_logs (occurred_at desc);
```
