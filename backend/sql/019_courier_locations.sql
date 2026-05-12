-- Courier Locations History Table
-- Stores background location tracking data from courier app
-- Used for delivery analytics, deviation detection, and geofencing

create table if not exists courier_locations (
  id uuid primary key default gen_random_uuid(),
  
  -- Courier reference
  courier_id text not null references users(id) on delete cascade,
  
  -- Location data
  location_point geography(point, 4326) not null,
  accuracy_m numeric not null,
  speed_kmh numeric,
  heading numeric, -- 0-360 degrees
  altitude_m numeric,
  
  -- Metadata
  recorded_at timestamp with time zone not null,
  created_at timestamp with time zone default now()
);

-- Indexes for efficient queries
create index if not exists idx_courier_locations_courier_id on courier_locations(courier_id);
create index if not exists idx_courier_locations_recorded_at on courier_locations(recorded_at);
create index if not exists idx_courier_locations_location on courier_locations using gist(location_point);
create index if not exists idx_courier_locations_recent on courier_locations(courier_id, recorded_at desc);

-- Composite index for common query pattern (courier + time range)
create index if not exists idx_courier_locations_courier_time on courier_locations(courier_id, recorded_at desc);

-- RPC function to get courier location history within time range
create or replace function get_courier_location_history(
  p_courier_id text,
  p_minutes_back integer default 120
)
returns table (
  id uuid,
  latitude numeric,
  longitude numeric,
  accuracy_m numeric,
  speed_kmh numeric,
  heading numeric,
  altitude_m numeric,
  recorded_at timestamp with time zone
) as $$
begin
  return query
  select
    courier_locations.id,
    st_y(courier_locations.location_point::geometry)::numeric,
    st_x(courier_locations.location_point::geometry)::numeric,
    courier_locations.accuracy_m,
    courier_locations.speed_kmh,
    courier_locations.heading,
    courier_locations.altitude_m,
    courier_locations.recorded_at
  from courier_locations
  where
    courier_locations.courier_id = p_courier_id
    and courier_locations.recorded_at > now() - (p_minutes_back || ' minutes')::interval
  order by courier_locations.recorded_at desc;
end;
$$ language plpgsql;

-- RPC function to get current courier location
create or replace function get_courier_current_location(
  p_courier_id text
)
returns table (
  latitude numeric,
  longitude numeric,
  accuracy_m numeric,
  speed_kmh numeric,
  heading numeric,
  altitude_m numeric,
  recorded_at timestamp with time zone
) as $$
begin
  return query
  select
    st_y(location_point::geometry)::numeric,
    st_x(location_point::geometry)::numeric,
    accuracy_m,
    speed_kmh,
    heading,
    altitude_m,
    recorded_at
  from courier_locations
  where courier_id = p_courier_id
  order by recorded_at desc
  limit 1;
end;
$$ language plpgsql;

-- RPC function to clean up old location data (older than 30 days)
create or replace function cleanup_old_courier_locations()
returns json as $$
declare
  v_deleted_count integer;
begin
  delete from courier_locations
  where recorded_at < now() - interval '30 days';
  
  get diagnostics v_deleted_count = row_count;
  
  return json_build_object(
    'deleted_count', v_deleted_count,
    'message', 'Cleanup completed'
  );
end;
$$ language plpgsql;

-- Comment on table for documentation
comment on table courier_locations is 'Real-time location history for delivery tracking and analytics';
comment on column courier_locations.location_point is 'Geographic point (lat, lng) recorded during delivery';
comment on column courier_locations.accuracy_m is 'GPS accuracy in meters (lower is better)';
comment on column courier_locations.speed_kmh is 'Speed at time of recording in km/h';
comment on column courier_locations.heading is 'Direction of travel (0-360 degrees)';
comment on column courier_locations.recorded_at is 'Time when location was recorded by client app';
