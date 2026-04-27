-- Add tracking summary fields to parcels table
-- These fields store the latest tracking progress and integrity status
-- for privacy-preserving real-time updates without exposing raw locations

alter table parcels add column if not exists tracking_progress_percent double precision;
alter table parcels add column if not exists tracking_integrity_status text;
alter table parcels add column if not exists tracking_last_update timestamptz;

-- Add index for efficient queries on tracking status
create index if not exists parcels_tracking_last_update_idx
  on parcels (tracking_last_update desc)
  where tracking_last_update is not null;

-- Add constraint to validate integrity_status values
alter table parcels add constraint parcels_integrity_status_check
  check (tracking_integrity_status is null or tracking_integrity_status in (
    'NOMINAL',
    'ON_CORRIDOR', 
    'MOVING_POSITIVELY',
    'OFF_CORRIDOR_STATIONARY'
  )) not valid;
