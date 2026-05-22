# DropCity Platform Source of Truth

Last updated: May 22, 2026  
Owner: Project team (update this file whenever core flows or APIs change)

## 1) What DropCity Is Supposed To Achieve
DropCity is a multi-app courier logistics platform designed to:
- let clients create parcel deliveries with minimal friction
- match deliveries to couriers whose route and capacity can serve them
- track parcel movement robustly and transparently
- support secure pickup/dropoff handshakes
- provide admin visibility, alerting, and dispute/conflict handling

Core outcome:
- safer and faster urban delivery by combining route-aware matching, tracking, and evidence-backed handoff flows.

## 2) Product Objectives
- Reliable auth and identity across Client, Courier, Admin.
- Multi-step, uncluttered mobile workflows.
- Route declaration lifecycle for couriers.
- Route-aware parcel matching.
- Tracking integrity (adherence + anomaly detection).
- ETA confidence with updates.
- Pricing recommendation that adapts to route, urgency, weight, and demand.
- Admin visibility and operational conflict resolution.

## 3) Solution Architecture

### Apps
- `client` (Flutter): sender/client experience.
- `courier` (Flutter): courier operations (routes, parcels, pickup/dropoff, tracking).
- `admin` (Next.js): operations and monitoring console.
- `backend` (Node/Express + Supabase + Firebase integration): API, matching, notifications, jobs.

### Data/Auth
- Mobile auth: Firebase via backend endpoints (not direct Firebase SDK auth calls for business auth).
- Admin auth: Supabase.
- Main persistence: Supabase/Postgres + PostGIS.
- Push/in-app notifications: Firebase + backend notification pipeline.

### Real-time and Jobs
- WebSocket channel for parcel status/tracking updates.
- Scheduler/background jobs for matching, scoring, cleanup, and tracking checks.

## 4) Desired End-to-End Flows

### Client happy path
1. Signup/Login/Forgot password.
2. Complete client profile.
3. Create delivery (multi-step).
4. Get matched courier options + pricing.
5. Courier accepts; client receives notifications.
6. Track parcel progress and ETA.
7. Complete handoff.
8. Submit courier rating.

### Courier happy path
1. Signup/Login/Forgot password.
2. Complete courier profile + vehicle details.
3. Declare route and activate route.
4. Receive/accept parcel request.
5. Pickup fast flow (photo + location + gate checks).
6. In-transit tracking and ETA updates.
7. Dropoff handshake completion.

### Admin happy path
1. Login.
2. Monitor parcels/couriers/errors/alerts.
3. Investigate deviations and handoff issues via `Disputes`.
4. Resolve disputes with explicit decision actions and immutable audit trail.

## 5) Screen and Page Inventory (Current Repo)

### Client app screens (`client/lib/screens`)
- `client_navigation_hub_screen.dart` (3-tab bottom navigation: Home, Deliveries, Account)
- `client_account_screen.dart`
- `dashboard_screen.dart`
- `delivery_creation_flow_screen.dart` (5-step client delivery creation flow)
- `parcel_status_screen.dart`
- `progress_screen.dart`
- `recipient_handoff_screen.dart`
- `sender_handoff_fallback_screen.dart`
- `delivery_picker.dart`
- `dropoff_screen.dart`
- `login_screen.dart`
- `onboarding_screen.dart`
- `splash_screen.dart` (displays DropCity logo from assets)
- `welcome_screen.dart` (displays DropCity logo from assets)
- Auth screens:
  - `auth/signup_screen.dart`
  - `auth/signup_step1_email.dart`
  - `auth/signup_step2_personal.dart`

### Courier app screens (`courier/lib/screens`)
- `navigation_hub_screen.dart` (4-tab bottom navigation: Home, Routes, Parcels, Settings)
- `home_screen.dart`
- `courier_dashboard_screen.dart` (metrics display, no navigation buttons)
- `assigned_parcels_screen.dart` (includes Pickup Mode button in AppBar)
- `route_declaration_screen.dart`
- `route_details_screen.dart`
- `map_route_declaration_screen.dart`
- `pickup_mode_screen.dart`
- `pickup_screen.dart`
- `dropoff_screen.dart`
- `settings_screen.dart`
- `courier_info_screen.dart`
- `splash_screen.dart` (displays DropCity logo from assets)
- `welcome_screen.dart` (displays DropCity logo from assets)
- Auth screens:
  - `auth/login_screen.dart`
  - `auth/signup_screen.dart`
  - `auth/splash_screen.dart`
  - `auth/welcome_screen.dart`
  - `auth/signup_steps/step1_email.dart`
  - `auth/signup_steps/step2_personal.dart`
  - `auth/signup_steps/step3_license.dart`
  - `auth/signup_steps/step4_vehicle.dart`

### Admin pages (`admin/src/app`)
- Public/admin areas include:
  - `login`, `forgot-password`, `reset-password`
  - `admin/monitoring`
  - `admin/alerts`
  - `admin/logs`
  - `admin/couriers`
  - `admin/vehicles`
  - `admin/health`
  - `admin/disputes` (conflict resolution workspace)
  - `admin/settings`
  - `admin/scheduler`
  - `admin/spatial-analytics`
  - plus top-level `couriers`, `logs`, `spatial-analytics`, and root pages

## 6) Backend API Surface (Mounted Route Modules)
Backend entrypoint: `backend/src/index.js`

Mounted groups:
- `/health`
- `/auth`
- `/users`
- `/vehicles`
- `/corridors`
- `/parcels`
- `/matches`
- `/handshake`
- `/heartbeat`
- `/logs`
- `/admin`
- `/devices`
- `/couriers`
- `/tracking`
- `/notifications`

Practical domain mapping:
- Auth/session/reset flows: `/auth/*`
- Profiles/role setup: `/users/*`
- Vehicle capacity/metadata: `/vehicles/*`
- Corridor declaration + geometry: `/corridors/*`
- Delivery lifecycle + rating + checkpoint operations: `/parcels/*`
- Matching queries: `/matches/*`
- Handoff operations: `/handshake/*`
- Courier state/routes lifecycle: `/couriers/*`
- Tracking updates/heuristics/eta: `/tracking/*`
- Notification center read/mark-read: `/notifications/*`
- Admin operations dashboards/jobs/ops endpoints: `/admin/*`

## 7) How Key Elements Work

### Authentication
- Client/Courier auth requests call backend endpoints.
- Backend handles Firebase token flows, issues session tokens, and stores needed user records/state.
- Admin uses Supabase auth path.

### Delivery creation
- Client uses multi-screen form to avoid crowded UI.
- Data captured: parcel details, image, locations, recipient mode, pricing preferences.
- Backend persists parcel + triggers matching.

### Matching algorithm (current upgraded logic)
- Starts from route/corridor proximity candidates.
- Filters candidates by:
  - route lifecycle (`ACTIVE` or `ABOUT_TO_START`)
  - vehicle capacity remaining vs parcel weight
  - active route progress not already beyond feasible pickup
- Scores and ranks candidates for queue/offer ordering.

### Route declaration and lifecycle
- Courier declares route from map geometry + route details.
- Route statuses: `PLANNED -> ACTIVE -> COMPLETED` (+ `CANCELLED`).
- Pickup acceptance should be restricted to active route state.

### Pickup/dropoff handshake
- Pickup: fast action with photo + location gate checks.
- Dropoff:
  - in-app recipient flow supports verification and secure completion.
  - external recipient flow provides fallback + dispute/reporting path.

### Tracking
- Tracking endpoint stores location pulses with corridor/vector context.
- Per-pulse diagnostics include confidence and anomaly flags.
- Heuristic sweeps produce adherence reports and score snapshots.
- Courier mobile tracking runtime now uses `flutter_background_geolocation` as the primary engine
  (foreground service + `stopOnTerminate=false` + `startOnBoot=true`) with the existing local outbox/retry/dead-letter pipeline.

### ETA
- ETA model blends:
  - declared ETA
  - distance/baseline speed ETA
  - historical corridor ETA
  - map-provider ETA (Google Directions, when server API key is configured)
- Returns confidence label + confidence score + source breakdown.
- Sender ETA update notifications are throttled and delta-aware.

### Pricing
- Pricing model v2 includes:
  - route segment transfer %
  - urgency multiplier
  - weight multiplier
  - demand/load modifier
  - historical adjustment
- Logs recommendation factors and route pricing history.

## 8) Database and Migrations
SQL migrations live in `backend/sql`.

Notable phase migrations:
- `020_auth_and_profiles.sql`
- `021_routes.sql`
- `022_tracking_logs.sql`
- `023_pricing_models.sql`
- `024_eta_and_connectivity.sql`

Key entities:
- `users`, `parcels`, `corridors`, `parcel_assignment_queue`
- `routes`, `vehicles`
- `courier_tracking_logs`, `route_deviation_events`, `route_adherence_reports`
- `price_recommendations_log`, `route_pricing_history`
- `eta_calculations_log`, `connectivity_map`, `zone_connectivity`
- notifications/outbox tables, handshake events, checkpoints

## 9) Deliverables Status (Implemented vs Pending)

### Implemented (high confidence)
- Multi-step courier signup flow and profile capture screens.
- Multi-step client signup flow.
- Client 5-step delivery creation flow wired from dashboard.
- Old parcel request flow removed/replaced by new client flow.
- Available couriers UX polish pass.
- Courier route declaration + route list/detail workflow.
- Route lifecycle actions in courier flow.
- Recipient vs non-recipient split handoff UI path.
- Handoff issue report endpoint.
- Tracking diagnostics persistence (per-pulse heuristic flags/confidence).
- ETA service v1 and ETA logging with confidence score.
- Sender ETA update notifications (throttled + significant delta logic).
- Pricing model v2 with factor logging.
- Matching objective 8 constraints implemented in service + route path.
- **Client app logo and navigation**: DropCity logo asset on splash/welcome screens; 3-tab bottom navigation (`Home`, `Deliveries`, `Account`) with theme colors (orange accent #FF6B35, dark background).
- **Courier app logo and navigation**: DropCity logo asset on splash/welcome screens; 4-tab bottom navigation (`Home`, `Routes`, `Parcels`, `Settings`) with consolidated navigation; dashboard cleaned up (removed action buttons, settings icon moved to nav); pickup mode button moved to parcels screen.
- Client navigation integrated (ClientNavigationHubScreen) with IndexedStack for efficient screen switching.
- Courier navigation integrated (NavigationHubScreen) with proper screen management and WillPopScope.
- Background tracking hardening for app-closed resilience upgraded on courier runtime using background geolocation engine.
- Map-provider ETA source integration implemented (Google Directions, key-dependent graceful fallback).
- Flutter background geolocation API corrections applied (removed invalid notificationTitle/Text params, fixed onLocation callback async handling).

### Partially implemented / still maturing
- Full recipient/courier PIN-and-proof completion UX hardening across all edge cases.
- Admin conflict resolution now includes dedicated UI + actions + audit trail; remaining work is policy tuning (SLA automation, refunds integration, escalation workflow routing).
- Device/OEM-specific background execution policy tuning and long-haul field validation still recommended.
- Asset management: logo.png files need to be copied to `assets/images/` directories in both courier and client apps.

### Pending / likely next
- Objective 9: admin conflict resolution screen and backend action endpoints alignment.
- Google Places deep integration and location picker polish where still basic.
- End-to-end integration testing + regression suite for critical flows.
- Performance/reliability hardening (timeouts, retries, telemetry, rate limits).
- Asset build verification and APK/IPA generation testing.

## 10) Operational Expectations
- Matching job should continuously process unassigned requested parcels.
- Tracking updates must be resilient to intermittent connectivity.
- Notification outbox must be processed by background job pipeline.
- Admin should have enough evidence (photo/GPS/timestamps) for disputes.

## 11) Known Risks and Constraints
- Some repo documents are stale relative to current implementation.
- Repo currently has unrelated dirty changes; avoid reverting unknown edits.
- Mobile background behavior differs by Android OEM/device policies.
- Connectivity assumptions vary by network/provider/device.

## 12) Agent Handoff Guidance
If an agent has only this file:
1. Start with section 9 for state of implementation.
2. Use sections 5 and 6 to find screens/pages/endpoints quickly.
3. Use sections 7 and 8 to understand architecture and data flow.
4. For new changes, update this file first to keep it authoritative.

## 13) Definition of “Source of Truth” for this Project
This file is authoritative for:
- project intent and target behavior
- current implementation state
- gap direction and next priorities

When code changes affect flows/endpoints/screens/status, update this file in the same PR/commit.
