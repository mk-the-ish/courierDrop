# Tracking Data Retention Policy

## Scope
- `courier_tracking_logs`: private raw courier coordinates and movement snapshots.
- `route_deviation_events`: courier-facing route integrity alerts.
- `parcels` tracking summary fields: `tracking_progress_percent`, `tracking_integrity_status`, `tracking_last_update`.

## Retention Rules
- Raw `courier_tracking_logs` records are retained for **30 days**.
- `route_deviation_events` are retained for **90 days**.
- Tracking summary fields on `parcels` are retained as part of parcel lifecycle records and **never expose raw coordinates**.

## Automated Enforcement
- Job: `cleanup_tracking_data`
- Schedule: daily at **02:00** server time
- Implementation: `backend/src/jobs/cleanup_tracking_data.js`
- Scheduler registration: `backend/src/services/scheduler.js`

## Privacy Guarantees
- Public/client APIs only expose summary tracking metrics.
- Raw latitude/longitude is restricted to private tracking tables.
- Deviation alerts are exposed to couriers (`/tracking/alerts/me`) and admin observability only.
