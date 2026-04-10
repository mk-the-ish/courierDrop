create table if not exists job_heartbeats (
  job_name text primary key,
  last_heartbeat_at timestamptz not null default now(),
  expected_frequency_sec integer not null,
  status text not null default 'ACTIVE',
  last_status_change_at timestamptz not null default now(),
  created_by text,
  request_id text,
  updated_at timestamptz not null default now(),
  constraint job_heartbeats_status_check
    check (status in ('ACTIVE', 'STUCK', 'INACTIVE_CLEAN'))
);

create index if not exists job_heartbeats_status_idx
  on job_heartbeats (status);

create table if not exists error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id text,
  device_model text,
  os_version text,
  stack_trace text,
  context jsonb,
  request_id text,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists error_logs_occurred_at_idx
  on error_logs (occurred_at desc);

create table if not exists corridors (
  id uuid primary key default gen_random_uuid(),
  created_by text,
  start_location text not null,
  end_location text not null,
  start_point geography(point, 4326),
  end_point geography(point, 4326),
  corridor_line geography(linestring, 4326),
  window_start text not null,
  window_end text not null,
  allow_multiple_parcels boolean not null default true,
  notes text,
  request_id text,
  created_at timestamptz not null default now()
);

create table if not exists parcels (
  id uuid primary key default gen_random_uuid(),
  created_by text,
  origin text not null,
  destination text not null,
  origin_point geography(point, 4326),
  destination_point geography(point, 4326),
  pickup_point geography(point, 4326),
  dropoff_point geography(point, 4326),
  size text,
  priority text not null,
  fragile boolean not null default false,
  notes text,
  status text not null default 'REQUESTED',
  pickup_pin_hash text,
  dropoff_pin_hash text,
  pickup_photo_url text,
  dropoff_photo_url text,
  pickup_verified_at timestamptz,
  dropoff_verified_at timestamptz,
  pickup_verified_by text,
  dropoff_verified_by text,
  privacy_mode boolean not null default true,
  assigned_courier_id text,
  assigned_at timestamptz,
  pickup_lat double precision,
  pickup_lng double precision,
  pickup_accuracy_m double precision,
  dropoff_lat double precision,
  dropoff_lng double precision,
  dropoff_accuracy_m double precision,
  pickup_pin_attempts integer not null default 0,
  dropoff_pin_attempts integer not null default 0,
  pin_locked_until timestamptz,
  request_id text,
  created_at timestamptz not null default now()
);

create table if not exists parcel_checkpoints (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references parcels(id) on delete cascade,
  sequence integer not null,
  checkpoint_point geography(point, 4326) not null,
  radius_m integer not null default 200,
  reached_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists parcel_checkpoints_parcel_idx
  on parcel_checkpoints (parcel_id, sequence);

create table if not exists parcel_assignment_queue (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references parcels(id) on delete cascade,
  corridor_id uuid not null references corridors(id) on delete cascade,
  rank integer not null default 1,
  status text not null default 'PENDING',
  created_at timestamptz not null default now()
);

create index if not exists parcel_assignment_queue_idx
  on parcel_assignment_queue (parcel_id, status, rank);

create table if not exists handshake_events (
  id uuid primary key default gen_random_uuid(),
  parcel_id uuid not null references parcels(id) on delete cascade,
  step text not null,
  actor_id text,
  status text not null,
  lat double precision,
  lng double precision,
  accuracy_m double precision,
  photo_url text,
  created_at timestamptz not null default now()
);

create index if not exists handshake_events_parcel_idx
  on handshake_events (parcel_id, created_at desc);

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  token text not null unique,
  platform text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on device_tokens (user_id);

create index if not exists corridors_created_by_idx
  on corridors (created_by);

create index if not exists corridors_created_at_idx
  on corridors (created_at desc);

create index if not exists corridors_start_point_gix
  on corridors using gist (start_point);

create index if not exists corridors_end_point_gix
  on corridors using gist (end_point);

create index if not exists corridors_line_gix
  on corridors using gist (corridor_line);

create index if not exists parcels_created_by_idx
  on parcels (created_by);

create index if not exists parcels_created_at_idx
  on parcels (created_at desc);

create index if not exists parcels_origin_point_gix
  on parcels using gist (origin_point);

create index if not exists parcels_destination_point_gix
  on parcels using gist (destination_point);

create index if not exists parcels_pickup_point_gix
  on parcels using gist (pickup_point);

create index if not exists parcels_dropoff_point_gix
  on parcels using gist (dropoff_point);
