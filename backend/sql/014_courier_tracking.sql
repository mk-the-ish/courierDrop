-- Courier Tracking Logs (Private: Raw locations and corridor validation)
create table if not exists courier_tracking_logs (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references parcels(id) on delete cascade,
  courier_id text not null,
  raw_location geography(point, 4326) not null,
  corridor_id uuid,
  is_on_corridor boolean not null default false,
  progress_index double precision,
  previous_distance_m double precision,
  current_distance_m double precision,
  movement_direction text,
  created_at timestamptz not null default now()
);

create index if not exists courier_tracking_logs_parcel_idx on courier_tracking_logs (parcel_id);
create index if not exists courier_tracking_logs_courier_idx on courier_tracking_logs (courier_id);
create index if not exists courier_tracking_logs_created_at_idx on courier_tracking_logs (created_at desc);
create index if not exists courier_tracking_logs_location_gist on courier_tracking_logs using gist (raw_location);

-- Route Deviation Events (for alert tracking)
create table if not exists route_deviation_events (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references parcels(id) on delete cascade,
  courier_id text not null,
  deviation_type text not null,
  duration_seconds integer,
  last_on_corridor_at timestamptz,
  last_progress_increase_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists route_deviation_events_parcel_idx on route_deviation_events (parcel_id);
create index if not exists route_deviation_events_created_at_idx on route_deviation_events (created_at desc);

-- Helper function to calculate courier progress on corridor
create or replace function calculate_courier_progress(
  p_corridor_id uuid,
  p_courier_location geography
)
returns table (
  progress_index double precision,
  distance_to_start_m double precision,
  distance_to_end_m double precision,
  distance_on_route_m double precision
)
language sql
stable
as $$
  select
    st_linelocatepoint(c.corridor_line::geometry, p_courier_location::geometry) as progress_index,
    st_distance(c.start_point, p_courier_location) as distance_to_start_m,
    st_distance(c.end_point, p_courier_location) as distance_to_end_m,
    st_distance(c.corridor_line, p_courier_location) as distance_on_route_m
  from corridors c
  where c.id = p_corridor_id;
$$;

-- Helper function to detect positive movement (heuristic for off-corridor tracking)
create or replace function detect_positive_movement(
  p_parcel_id uuid,
  p_current_distance_m double precision
)
returns table (
  is_moving_positive boolean,
  previous_distance_m double precision,
  distance_change_m double precision
)
language sql
stable
as $$
  select
    p_current_distance_m < coalesce(
      (select current_distance_m from courier_tracking_logs 
       where parcel_id = p_parcel_id 
       order by created_at desc 
       limit 1),
      p_current_distance_m + 1000
    ) as is_moving_positive,
    (select current_distance_m from courier_tracking_logs 
     where parcel_id = p_parcel_id 
     order by created_at desc 
     limit 1) as previous_distance_m,
    coalesce(
      (select current_distance_m from courier_tracking_logs 
       where parcel_id = p_parcel_id 
       order by created_at desc 
       limit 1),
      p_current_distance_m + 1000
    ) - p_current_distance_m as distance_change_m;
$$;
