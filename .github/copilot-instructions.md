# DropCity AI Coding Agent Instructions

DropCity is a real-time delivery coordination platform with three main services: Flutter client apps (customer & courier), Node.js/Express backend, and Next.js admin dashboard.

## Architecture Overview

### Three-Service Stack
- **Backend** (`backend/src`): Express API + WebSocket server; Supabase database + Firebase Auth
- **Admin Dashboard** (`admin/src`): Next.js 14 dashboard for system monitoring and alert rules
- **Client Apps** (`client/lib` + `courier/lib`): Flutter apps for customer and courier roles

### Critical Data Flow
1. **Parcel Lifecycle**: REQUESTED → MATCHING → ASSIGNED → IN_TRANSIT → DELIVERED
2. **Matching Service** (`backend/src/services/matching.js`): Periodically matches unassigned parcels to corridors using PostGIS geography functions
3. **WebSocket Broadcasting**: `ws.js` manages pub/sub for parcel status updates (via `broadcastParcelStatus()` and `broadcastHandshakeEvent()`)
4. **Authentication**: Firebase ID tokens + Supabase role table for multi-tenant role enforcement

### Database Structure
- Supabase PostgreSQL with PostGIS extensions (`sql/000_extensions.sql` onwards)
- Key tables: `parcels`, `corridors`, `users`, `vehicles`, `parcel_assignment_queue`, `handshake_events`
- Schema migration files numbered 001-012; always add new migrations with next sequence number

## Service-Specific Patterns

### Backend (Express)
- **Config-driven**: Environment variables loaded in `src/config.js` (REQUIRE_AUTH toggles auth enforcement)
- **Request ID tracking**: Every request gets UUID in `x-request-id` header and JSON response; skip this for `/health/heartbeats` (marked with `res.locals.skipRequestIdBody`)
- **Role-based access**: Auth middleware (`src/middleware/auth.js`) loads user role from Supabase users table after Firebase verification
- **Routes structure**: Each domain (auth, parcels, corridors, vehicles, etc.) has own file in `src/routes/`
- **Scheduler**: Node-cron based jobs in `src/jobs/` (e.g., heartbeat watchdog, matching service)

### Admin Dashboard (Next.js)
- **Real-time health monitoring**: Fetches job status every 5 seconds
- **Alert Rules**: CRUD operations with multiple condition types and notification channels
- **Radix UI + Tailwind**: Component library pattern with dark sidebar nav
- **File structure**: `src/app/` contains pages (alerts/, health/, scheduler/, admin/)

### Client Apps (Flutter)
- **ApiClient pattern**: `lib/api/api_client.dart` wraps HTTP + WebSocket with Bearer token auth
- **AuthState management**: `lib/auth/auth_state.dart` handles Firebase/Supabase user session
- **Offline queue**: `lib/utils/offline_queue.dart` queues requests when offline
- **Error reporting**: `lib/utils/error_reporter.dart` sends client errors to backend error_logs table
- **Screen structure**: Dashboard, parcel request, status tracking, map selection screens

## Critical Development Workflows

### Starting Backend
```bash
cd backend
npm install
# Set .env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, FIREBASE_* vars
npm run dev  # Runs on port 8080
```

### Database Migrations
1. Create new SQL file: `backend/sql/013_description.sql`
2. Execute via Supabase dashboard or CLI
3. Run-scripts use SQL migrations (backend/scripts/); check before running

### PostGIS Matching Algorithm Deep Dive

**Core Concept**: Match parcels to delivery corridors using geographic constraints. A corridor is a pre-defined route (LineString) with a time window. A parcel can ride on a corridor if both pickup and dropoff points fall within acceptable distance (detour) of the corridor path and are ordered correctly along the line.

**Key Data Structures**:
- `corridors.corridor_line`: Geography(LineString, 4326) - the actual route path in WGS84
- `parcels.origin_point`, `parcels.destination_point`: Geography(Point, 4326) - parcel start/end
- `parcel_assignment_queue`: Ranked queue of matched corridors per parcel

**Matching Algorithm** (`match_corridors_for_parcel` RPC in `sql/002_matching.sql`):

1. **Distance Filter** (st_dwithin): Corridor line must be within `p_max_detour_m` (default 50km) of both origin AND destination
   ```sql
   st_dwithin(c.corridor_line, p_origin, p_max_detour_m)
   and st_dwithin(c.corridor_line, p_destination, p_max_detour_m)
   ```

2. **Order Constraint** (st_linelocatepoint): Pickup must occur before dropoff along the corridor line. `st_linelocatepoint` returns a fraction [0,1] indicating position along the line:
   ```sql
   st_linelocatepoint(c.corridor_line::geometry, p_origin::geometry)
     < st_linelocatepoint(c.corridor_line::geometry, p_destination::geometry)
   ```

3. **Exact Pickup/Dropoff Points** (st_closestpoint): Finds the nearest point on the corridor line to origin/destination:
   ```sql
   st_closestpoint(c.corridor_line::geometry, p_origin::geometry) as pickup_point
   ```

4. **Ranking by Detour Distance**: Results ordered by total detour (distance from origin to pickup + dropoff to destination), favoring the shortest diversions:
   ```sql
   order by st_distance(c.corridor_line, p_origin) + st_distance(c.corridor_line, p_destination)
   limit 50
   ```

**Returns**: Ordered list of matched corridors with:
- `corridor_id`: UUID of the corridor
- `pickup_point`, `dropoff_point`: Geography points on the corridor line
- `pickup_fraction`, `dropoff_fraction`: Position [0,1] along the corridor (used to verify order and calculate ride distance)

**Queue Management** (`src/services/matching.js`):
1. Service runs periodically (scheduled job) to find all REQUESTED parcels without assignments
2. Calls RPC for each parcel, receives ranked corridor matches
3. Inserts all matches into `parcel_assignment_queue` with `rank` field (1=best match)
4. When a courier accepts a corridor, that queue entry transitions to ASSIGNED and triggers parcel status update

**Testing Matching Service**:
- Create REQUESTED parcel with valid `origin_point` and `destination_point` (geography types)
- Create corridor with `corridor_line` set via `set_corridor_line(id, line_wkt, start_wkt, end_wkt)`
- Manually call: `select * from match_corridors_for_parcel('POINT(lon lat)'::geography, 'POINT(lon lat)'::geography, 50000)`
- Verify results appear in `parcel_assignment_queue` after scheduler runs

### Client App Architecture
- **Firebase Messaging**: Handles push notifications; payload in `firebase_options.dart`
- **Connectivity tracking**: `connectivity_plus` package detects online/offline
- **GeoLocation**: `geolocator` package for real-time location (requires platform permissions)
- **Image scanning**: `mobile_scanner` for QR codes; `image_picker` for photos

## Project-Specific Conventions

### WebSocket Message Format
Emitted via `ws.js` broadcaster:
```javascript
{ type: "parcel_status", payload: {...} }
{ type: "handshake_event", payload: {...} }
```
Clients subscribe via parcel ID; unsubscribe on connection close.

### Parcel Assignment Queue
`parcel_assignment_queue` holds multiple corridor candidates ranked by match quality. Assignment happens when courier accepts corridor.

### Role-Based Authorization
Valid roles: `CUSTOMER`, `COURIER`, `ADMIN`. Check via `hasRole(user, role)` in `ws.js` or middleware. Roles stored in Supabase `users.role` field.

### Error Logs
Client errors sent to `backend/routes/error_logs.js` POST endpoint. Includes device_model, os_version, stack_trace, and context (JSONB).

### Handshake Events (Real-time Parcel Handoff)
Track parcel pickup/delivery confirmations. Events stored in `handshake_events` table; broadcasted via WebSocket to subscribed clients.

## Common Tasks & Patterns

**Adding a new API endpoint**: Create route file in `backend/src/routes/`, add Supabase query using `getSupabase()`, export route, mount in `index.js`.

**Listening for parcel updates**: Client connects WebSocket, subscribes to parcel ID via auth token, receives `parcel_status` or `handshake_event` messages.

**Matching a parcel**: Matching service calls Supabase RPC function that uses PostGIS to find corridors within detour threshold; enqueues results.

**Dashboard alert rule**: Admin creates rule in alert rules UI; stored as condition JSON; alerting service (`backend/src/services/alerting.js`) evaluates against metrics.

## File Reference Guide

- **Backend core**: `backend/src/index.js` (server entry), `ws.js` (WebSocket), `supabase.js` (client), `firebase.js` (auth)
- **Matching logic**: `backend/src/services/matching.js`
- **Database schema**: `backend/sql/001_init.sql` (base tables), `002_matching.sql` (matching RPC functions)
- **Client architecture**: `client/lib/main.dart`, `lib/api/api_client.dart`, `lib/auth/auth_service.dart`
- **Admin app**: `admin/src/app/page.tsx` (dashboard), `alerts/page.tsx` (alert rules)
