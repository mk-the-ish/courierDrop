# DropCity Accurate Gap Analysis - Phase 5 (May 2026)

**Date**: May 12, 2026  
**Audit Scope**: Phases 1-4 codebase review + Phase 5 requirements comparison  
**Status**: Comprehensive audit of actual implementation vs. Phase 5 requirements  

---

## Executive Summary

After thorough codebase audit, the platform is **more mature than initially assessed**. Phase 1-4 implementation is ~65% complete (not 40%), with several critical features already in place that were previously thought to be missing.

**Revised Implementation State**:
- Phase 1-3: **95%+ complete** (core delivery flow fully operational)
- Phase 4: **50% complete** (3 admin pages done, backend alert engine + verification/disputes pending)
- Phase 5: **0% complete** (all advanced features pending)
- **Overall**: ~65% of full platform vision complete

---

## What's Actually Implemented (Audit Results)

### ✅ Authentication & User Management (70% complete)

**ALREADY IMPLEMENTED**:
- ✅ Firebase auth backend routing (apps do NOT call Firebase directly - backend handles via `/auth/signup` and `/auth/login`)
- ✅ JWT token generation with role-based claims
- ✅ Refresh token management
- ✅ Multi-app auth coordination (client, courier, admin separate flows)
- ✅ Backend role setup: `POST /users/setup-role` (creates user record in Supabase with role)
- ✅ Login screen for both courier and client apps (single combined screen with role picker)
- ✅ Signup screen for both courier and client apps (single combined screen)
- ✅ Forgot password flow
- ✅ Token storage and persistence
- ✅ Auth state management (`AuthState`, `AuthService`)

**STILL MISSING**:
- ❌ Multi-step signup workflow (current: single signup screen, needs 4-step for courier, 2-step for client)
- ❌ Courier profile capture: full name, ID photo, license photo, vehicle details (4-5 screens needed)
- ❌ Client profile capture: full name, username, ID photo (2 screens needed)
- ❌ Database tables: `courier_profiles`, `client_profiles` (SQL migration 020)
- ❌ Separate endpoints: `/auth/signup/courier`, `/auth/signup/client`, `/auth/login/courier`, `/auth/login/client`
- ❌ Admin signup flow (currently only login + forgot password)

**Gap Size**: ~30% | **Effort**: HIGH | **Priority**: CRITICAL | **Timeline**: Weeks 1-2

---

### ✅ Delivery System (85% complete)

**ALREADY IMPLEMENTED**:
- ✅ Parcel creation flow (`POST /parcels`)
- ✅ Basic parcel request screen
- ✅ Matching algorithm with PostGIS distance filtering
- ✅ Available corridors/couriers display
- ✅ Price recommendation engine (formula-based)
- ✅ Parcel status tracking (REQUESTED → MATCHING → ASSIGNED → IN_TRANSIT → DELIVERED)
- ✅ Photo capture at pickup and dropoff
- ✅ GPS gate verification (50m radius)
- ✅ OTP generation for dropoff verification
- ✅ Rating system (weighted aggregation)

**STILL MISSING**:
- ❌ Multi-step delivery creation workflow (4-5 screens):
  - Screen 1: Description, size (S/M/L), weight, arrival time
  - Screen 2: Parcel image capture
  - Screen 3: Location selection (map + Google Places autocomplete)
  - Screen 4: Recipient selection (in-app or external phone)
  - Screen 5: Available couriers + custom price input
- ❌ Google Places address autocomplete integration
- ❌ Better location picker UX (currently basic map)
- ❌ In-app recipient notifications and recipient handoff screen
- ❌ Non-recipient external delivery flow (sender confirmation)
- ❌ Delivery creation controller (`delivery_creation_controller.dart`)

**Gap Size**: ~15% | **Effort**: HIGH | **Priority**: HIGH | **Timeline**: Weeks 3-4

---

### ✅ Route Management (30% complete)

**ALREADY IMPLEMENTED**:
- ✅ Route declaration screen (`map_route_declaration_screen.dart`, `route_declaration_screen.dart`)
- ✅ Basic map visualization for route drawing
- ✅ Route list display in courier dashboard
- ✅ Backend endpoints started

**STILL MISSING**:
- ❌ Complete route declaration workflow (2-step):
  - Step 1: Map visualization + route drawing
  - Step 2: Time picker (start time + ETA calculation)
- ❌ Routes management screen (list with status badges)
- ❌ Route detail screen (map + parcels + start/pause/end buttons)
- ❌ Active route enforcement (only allow pickups if route ACTIVE)
- ❌ Route status management (PLANNED → ACTIVE → COMPLETED)
- ❌ Backend endpoints: POST, GET, PATCH for route lifecycle
- ❌ Database table: `routes` (SQL migration 021)
- ❌ Route controller with state management

**Gap Size**: ~70% | **Effort**: HIGH | **Priority**: HIGH | **Timeline**: Weeks 5-6

---

### ✅ Pickup & Dropoff (90% complete)

**ALREADY IMPLEMENTED**:
- ✅ Pickup photo capture screen
- ✅ GPS gate verification (50m radius threshold)
- ✅ Location validation at pickup point
- ✅ Dropoff photo capture screen
- ✅ OTP generation for recipient verification
- ✅ Assigned parcels list screen
- ✅ Handshake events tracking (database + WebSocket)

**STILL MISSING**:
- ❌ Pickup location editing capability (if outside route, suggest alternate on route)
- ❌ Recipient pickup screen (if in-app user):
  - Photo capture of recipient acceptance
  - GPS verification
  - PIN generation (4-digit)
  - PIN sharing mechanism
- ❌ Courier dropoff with PIN entry validation
- ❌ Non-recipient external delivery flow
  - Sender confirmation notification
  - Sender dispute mechanism
- ❌ Post-delivery rating screen (currently rating exists, needs better UX)

**Gap Size**: ~10% | **Effort**: MEDIUM | **Priority**: MEDIUM | **Timeline**: Weeks 7-8

---

### ✅ Background Location Tracking (50% complete)

**ALREADY IMPLEMENTED**:
- ✅ Background location service (`background_location_service.dart`)
- ✅ Location posting to backend (`POST /courier/location`)
- ✅ Geofencing logic
- ✅ Checkpoint detection
- ✅ Location storage in database (courier_locations table)
- ✅ Location tracking controller

**STILL MISSING** (Critical for production):
- ❌ WorkManager integration for periodic tasks (Android)
- ❌ Foreground service configuration (required for Android 10+)
- ❌ Continuous location posting when app is closed
- ❌ Adaptive update frequency based on battery/connectivity
- ❌ Android manifest permissions (FOREGROUND_SERVICE_LOCATION)
- ❌ Background task retry logic

**Current Limitation**: Location tracking only works while app is in foreground. Needs WorkManager to work when app is closed.

**Gap Size**: ~50% | **Effort**: MEDIUM | **Priority**: HIGH | **Timeline**: Week 11

---

### ✅ Heuristic Tracking (0% complete)

**ALREADY IMPLEMENTED**:
- ✅ Basic rating aggregator (`rating_aggregator.js`)
- ✅ Tracking vector service skeleton

**STILL MISSING** (CRITICAL - User's #1 priority):
- ❌ Route adherence verification
  - Compare actual location vs. declared route polyline
  - Calculate deviation percentage
  - Flag if deviation > 500m for > 2 minutes
- ❌ Movement verification
  - Detect stationary periods (longer than expected)
  - Detect teleportation (impossible speeds)
  - Calculate actual speed vs. expected speed
- ❌ Waypoint validation
  - Confirm pickup point visit (within 50m)
  - Confirm dropoff point visit (within 50m)
  - Timestamp recording
- ❌ Heuristic tracking service (`backend/src/services/heuristic_tracking.js`)
- ❌ Tracking logs database schema (SQL migration 022)
- ❌ Background job (cron) for continuous verification
- ❌ Admin adherence reports

**Gap Size**: ~100% | **Effort**: CRITICAL | **Priority**: CRITICAL | **Timeline**: Weeks 9-10

---

### ✅ Pricing Model (60% complete)

**ALREADY IMPLEMENTED**:
- ✅ Price recommendation engine (`price_recommendation.js`)
- ✅ Base fare calculation
- ✅ Size multiplier (S=0.5, M=1.0, L=2.0)
- ✅ Distance coefficient calculation
- ✅ Formula: `F = min((S × D) + (P_r × 2), MWP)`

**STILL MISSING**:
- ❌ Route matching pricing (find historical route, apply percentage)
- ❌ Dynamic pricing based on demand/congestion
- ❌ Pricing history logging
- ❌ Weight-based adjustments (currently only size)
- ❌ Database: `route_pricing_history`, `price_recommendations_log` (SQL 023)

**Gap Size**: ~40% | **Effort**: LOW | **Priority**: MEDIUM | **Timeline**: Week 12

---

### ✅ ETA Model (0% complete)

**ALREADY IMPLEMENTED**:
- ✅ None (all pending)

**NEEDED**:
- ❌ Multi-source ETA calculation:
  1. Courier declared time
  2. Distance ÷ average speed (40 km/h)
  3. Google Maps API (traffic-aware)
  4. Historical average for this route
- ❌ Weighted average with confidence scores
- ❌ Service: `backend/src/services/eta_model.js`
- ❌ Connectivity mapping service
- ❌ Database: `eta_calculations_log`, `connectivity_map`, `zone_connectivity` (SQL 024)
- ❌ 5-minute buffer before estimated pickup

**Gap Size**: ~100% | **Effort**: HIGH | **Priority**: HIGH | **Timeline**: Week 12

---

### ✅ Navigation & UX (20% complete)

**ALREADY IMPLEMENTED**:
- ✅ Basic tab navigation in courier and client apps
- ✅ Home, settings screens
- ✅ Basic FAB (floating action button)

**STILL MISSING**:
- ❌ Bottom navigation bar (replace tab bar)
- ❌ Courier: 4-item bottom nav (Home, Parcels, Routes, Settings)
- ❌ Client: 3-item bottom nav (Home, Deliveries, Account)
- ❌ FAB for primary actions (no burger menus)
- ❌ Parcels list screen (pending + accepted)
- ❌ Minimalist screen design review
- ❌ Multi-screen workflow optimization

**Gap Size**: ~80% | **Effort**: LOW | **Priority**: MEDIUM | **Timeline**: Week 13

---

### ✅ Admin Dashboard (60% complete)

**ALREADY IMPLEMENTED**:
- ✅ Monitoring page (real-time parcel + courier status)
- ✅ Alerts rules UI (CRUD operations)
- ✅ Error logs & analytics page
- ✅ Real-time auto-refresh (5 seconds)
- ✅ Search, filtering, CSV export

**STILL MISSING**:
- ❌ Courier verification page (approve/reject documents)
- ❌ Handshake dispute resolution page
- ❌ Adherence reports (route adherence per courier)
- ❌ Backend alert rules evaluation cron job
- ❌ Backend endpoints for verification/disputes
- ❌ Admin signup flow

**Gap Size**: ~40% | **Effort**: MEDIUM | **Priority**: MEDIUM | **Timeline**: Weeks 14-15

---

### ✅ Backend API Endpoints (90% complete)

**ALREADY IMPLEMENTED** (30+ endpoints):
- ✅ `/auth/*` (signup, login, refresh, forgot password)
- ✅ `/users/*` (setup-role, profile, me)
- ✅ `/parcels/*` (create, list, update status, assign)
- ✅ `/corridors/*` (declare, list, match)
- ✅ `/couriers/*` (profile, list, online status)
- ✅ `/vehicles/*` (save, update)
- ✅ `/handshake/*` (events tracking)
- ✅ `/location/*` (background tracking)
- ✅ `/admin/*` (parcels, couriers, errors, logs, alerts)

**STILL MISSING**:
- ❌ `/auth/signup/courier`, `/auth/signup/client` (separated endpoints)
- ❌ `/auth/login/courier`, `/auth/login/client`
- ❌ `/courier/routes/*` (create, get, patch start/end)
- ❌ `/admin/courier/:id/approve` (verification)
- ❌ `/admin/disputes/*` (list, resolve)
- ❌ `/admin/adherence/*` (reports)

**Gap Size**: ~10% | **Effort**: LOW | **Priority**: MEDIUM

---

## Detailed Gap Analysis Matrix

| Feature Category | Current State | Required State | Gap % | Effort | Priority | Timeline |
|---|---|---|---|---|---|---|
| **Auth & Profiles** | Basic Firebase routing | Multi-step signup + profile capture | 30% | HIGH | CRITICAL | W1-2 |
| **Delivery Creation** | Basic form + matching | Multi-step UX with Places autocomplete | 15% | HIGH | HIGH | W3-4 |
| **Route Management** | Partial screens | Complete declaration + lifecycle | 70% | HIGH | HIGH | W5-6 |
| **Pickup & Dropoff** | Photo + GPS + OTP | Recipient handoff + location editing | 10% | MEDIUM | MEDIUM | W7-8 |
| **Background Location** | Foreground only | WorkManager + continuous | 50% | MEDIUM | HIGH | W11 |
| **Heuristic Tracking** | Not started | Route adherence + anomalies | 100% | HIGH | **CRITICAL** | W9-10 |
| **Price Model** | Formula-based | Route matching + dynamic | 40% | LOW | MEDIUM | W12 |
| **ETA Model** | Not started | Multi-source + learning | 100% | HIGH | HIGH | W12 |
| **Navigation & UX** | Tab-based | Bottom nav + FAB | 80% | LOW | MEDIUM | W13 |
| **Admin Dashboard** | Monitoring + alerts | Verification + disputes + reports | 40% | MEDIUM | MEDIUM | W14-15 |
| **Backend Endpoints** | 30+ endpoints | 40+ endpoints | 10% | LOW | MEDIUM | W3-4 |
| **Database** | 19 migrations | 24 migrations | 20% | LOW | MEDIUM | W1-15 |

---

## Implementation Roadmap (Corrected - 12 Weeks)

### Weeks 1-2: Auth & Profiles Foundation
**Deliverables**:
- Split signup: 4-step courier, 2-step client
- Courier profile capture (name, ID, license, vehicle)
- Client profile capture (name, username, ID)
- Database: `courier_profiles`, `client_profiles` tables
- Endpoint separation: `/auth/signup/courier`, `/auth/signup/client`
- Separate endpoints for courier login, client login

**Effort**: 2 developers × 2 weeks = 40 dev-days

---

### Weeks 3-4: Delivery Creation UX
**Deliverables**:
- 5-step delivery creation workflow
- Google Places address autocomplete
- Better location picker (map + address)
- Recipient in-app search + external phone
- Available couriers list with custom pricing
- Delivery creation controller + state management

**Effort**: 1.5 developers × 2 weeks = 30 dev-days

---

### Weeks 5-6: Route Management
**Deliverables**:
- Complete route declaration (2-step workflow)
- Route management UI (list + detail)
- Active route enforcement
- Route lifecycle (PLANNED → ACTIVE → COMPLETED)
- Database: `routes` table
- Backend: POST, GET, PATCH endpoints

**Effort**: 1.5 developers × 2 weeks = 30 dev-days

---

### Weeks 7-8: Pickup & Dropoff Polish
**Deliverables**:
- Location editing at pickup (alternate points)
- Recipient handoff screen (in-app users)
- PIN generation (4-digit)
- Non-recipient external delivery flow
- Post-delivery rating UX improvement
- Recipient notification system (5-min warning)

**Effort**: 1.5 developers × 2 weeks = 30 dev-days

---

### Weeks 9-10: Heuristic Tracking (CRITICAL)
**Deliverables**:
- Route adherence verification service
- Movement anomaly detection
- Waypoint validation logic
- Background cron job for continuous checking
- Database: `tracking_logs`, `route_adherence_report` tables
- Admin adherence reports page

**Effort**: 2 developers × 2 weeks = 40 dev-days (most complex)

---

### Week 11: Background Location + Price
**Deliverables**:
- WorkManager integration (Android)
- Foreground service setup
- Continuous location posting (app closed)
- Route matching for pricing
- Battery/connectivity optimization

**Effort**: 1.5 developers × 1 week = 15 dev-days

---

### Week 12: ETA Model + UX Navigation
**Deliverables**:
- Multi-source ETA calculation service
- Connectivity mapping
- Historical data learning
- Bottom navigation (courier + client)
- FAB implementation
- Parcels list screen

**Effort**: 1.5 developers × 1 week = 15 dev-days

---

## Missing SQL Migrations

| File | Purpose | Lines | Complexity |
|---|---|---|---|
| `020_auth_and_profiles.sql` | `courier_profiles`, `client_profiles` tables | 50 | LOW |
| `021_routes.sql` | `routes` table with lifecycle | 60 | MEDIUM |
| `022_tracking_logs.sql` | `tracking_logs`, `route_adherence_report` | 70 | HIGH |
| `023_pricing_models.sql` | `route_pricing_history`, `price_recommendations_log` | 50 | LOW |
| `024_eta_and_connectivity.sql` | `connectivity_map`, `eta_calculations_log`, `zone_connectivity` | 70 | MEDIUM |

**Total**: 300 lines of SQL across 5 new migrations

---

## Missing Backend Services

| Service | File | Lines | Complexity | Priority |
|---|---|---|---|---|
| Heuristic Tracking | `backend/src/services/heuristic_tracking.js` | 350 | HIGH | CRITICAL |
| ETA Model | `backend/src/services/eta_model.js` | 300 | HIGH | HIGH |
| Connectivity Mapper | `backend/src/services/connectivity_mapper.js` | 150 | MEDIUM | MEDIUM |
| Enhanced Price Model | Update `price_recommendation.js` | 100 | MEDIUM | MEDIUM |
| Alert Rules Engine | `backend/src/jobs/alert_rules_evaluator.js` | 200 | HIGH | HIGH |

**Total**: ~1,100 lines of JavaScript

---

## Missing Flutter Screens

**Courier App** (6 screens):
1. `signup_step1_email.dart` - Email & password
2. `signup_step2_personal.dart` - Name, ID + photo
3. `signup_step3_license.dart` - License number + photo
4. `signup_step4_vehicle.dart` - Vehicle details + images
5. `parcels_list_screen.dart` - Pending + accepted parcels
6. `route_detail_screen.dart` - Map + start/pause/end

**Client App** (5 screens):
1. `signup_step1_email.dart` - Email & password
2. `signup_step2_personal.dart` - Name, username, ID + photo
3. `delivery_creation_step1_details.dart` - Description, size, weight, time
4. `delivery_creation_step2_image.dart` - Photo capture
5. `delivery_creation_step3_locations.dart` - Pickup + destination (Places autocomplete)
6. `delivery_creation_step4_recipient.dart` - Recipient selection
7. `available_couriers_screen.dart` - Couriers list + selection
8. `recipient_handoff_screen.dart` - Recipient delivery (if in-app user)

**Total**: 11 new screens

---

## Missing Controllers

**Courier App**:
- `signup_controller.dart` - Multi-step form state
- `route_declaration_controller.dart` - Route declaration state
- `routes_controller.dart` - Routes management
- `parcels_controller.dart` - Parcels list

**Client App**:
- `signup_controller.dart` - Multi-step form state
- `delivery_creation_controller.dart` - 5-step delivery workflow
- `available_couriers_controller.dart` - Couriers list + selection
- `recipient_handoff_controller.dart` - Recipient delivery

**Total**: 8 new controllers

---

## Key Insights

### 1. Authentication Already Backend-Driven ✅
The platform **already implements Firebase auth through backend** (not direct). Mobile apps call `/auth/signup` and `/auth/login`, backend handles Firebase REST API. This was a major misconception—it's already correct.

### 2. Most Core Features Exist ✅
Phases 1-3 are **95%+ complete**:
- Matching algorithm working
- Price calculation functioning
- Location tracking operational
- OTP verification implemented
- Rating system operational

### 3. Phase 4 is 50% Done ✅
Admin dashboard has:
- ✅ Monitoring page (complete)
- ✅ Alerts UI (complete)
- ✅ Error logs (complete)
- ❌ Alert engine (backend job pending)
- ❌ Verification page (not started)
- ❌ Disputes page (not started)

### 4. Heuristic Tracking is the Biggest Gap ❌
**User's stated priority #1**: "Heuristic tracking is the most important feature together with offline mapping"

Current state: **0% implemented**. This requires:
- New service: `heuristic_tracking.js` (350 lines)
- Background job for continuous evaluation
- Database schema for tracking logs
- Admin reporting interface
- **Estimated effort: 40 dev-days** (most complex feature)

### 5. Background Location Needs WorkManager ❌
Current: Only works in foreground (limitation on Android 10+)
Needed: WorkManager + foreground service for continuous posting
**Cannot ship without this for production courier experience**

### 6. Database is 19/24 Migrations (79% complete) ✅
Only 5 new migrations needed:
- 020: Auth & profiles
- 021: Routes
- 022: Tracking logs (for heuristic)
- 023: Pricing models
- 024: ETA & connectivity

---

## Updated Phase 5 Timeline

**Total Duration**: 12 weeks (not 15 - more is already done)  
**Team Size**: 1 backend dev + 1 mobile dev + 0.5 QA = 1.5 FTE

**Weekly Breakdown**:
- Week 1-2: Auth & Profiles (40 dev-days)
- Week 3-4: Delivery Creation (30 dev-days)
- Week 5-6: Route Management (30 dev-days)
- Week 7-8: Pickup & Dropoff Polish (30 dev-days)
- Week 9-10: Heuristic Tracking (40 dev-days) ← **CRITICAL BLOCKER**
- Week 11: Background Location + Price (15 dev-days)
- Week 12: ETA + Navigation (15 dev-days)

**Total Effort**: ~200 dev-days ≈ 10 developer-weeks (2 devs working in parallel)

---

## Critical Path Items

**Must complete BEFORE public launch**:
1. ✅ Auth & profiles (week 1-2)
2. ✅ Delivery creation (week 3-4)
3. ❌ **Heuristic tracking (week 9-10)** - User's top priority
4. ❌ Background location WorkManager (week 11)
5. ✅ Route management (week 5-6) - enables matching
6. ❌ ETA model (week 12) - improves UX

**Nice-to-have before launch**:
- Pricing model enhancements
- Navigation UX polish
- Admin verification/disputes

---

## Blockers & Dependencies

| Item | Depends On | Blocker? |
|---|---|---|
| Heuristic tracking | Background location working | YES |
| ETA model | Route management + historical data | NO |
| Route enforcement | Routes table + management UX | YES |
| Multi-step auth | Auth profiles tables | YES |
| Delivery creation | Auth profiles + routes | YES |

---

## Resource Requirements (Revised)

| Role | Hours/Week | Duration | Total | Cost (est.) |
|---|---|---|---|---|
| Backend Dev | 40 | 12 weeks | 480 hours | $19,200 (@ $40/hr) |
| Mobile Dev | 40 | 12 weeks | 480 hours | $19,200 (@ $40/hr) |
| QA | 20 | 12 weeks | 240 hours | $4,800 (@ $20/hr) |
| **Total** | 100 | - | **1,200 hours** | **$43,200** |

---

## Recommendations

### 1. Prioritize Heuristic Tracking ✅
Start week 9-10 as early as possible. It's the largest gap and user's stated priority. Can parallelize with route management (week 5-6).

### 2. Implement WorkManager Immediately ⚠️
Don't defer background location. It's a hard requirement for Android 10+ production apps. Affects heuristic tracking reliability.

### 3. Split Development in Parallel ✅
- **Backend dev**: Services (auth, heuristic, ETA)
- **Mobile dev**: Screens (signup multi-step, delivery creation, routes)
- Can overlap weeks 1-4 without blocking

### 4. Create Test Data Set 📊
For heuristic tracking testing, need:
- Pre-recorded GPS traces (valid + fraudulent patterns)
- Route polylines with known adherence %
- Synthetic speed anomalies for testing

### 5. API Rate Limiting ⚠️
Consider adding rate limits on location posting (currently unlimited).
Suggested: 1 request per 30 seconds per courier.

---

## Success Metrics

- ✅ Zero 403 auth errors in production
- ✅ Multi-step signup completion rate > 95%
- ✅ Delivery creation < 90 seconds (5 steps)
- ✅ Route adherence detection accuracy > 95%
- ✅ Heuristic false positive rate < 2%
- ✅ Background location posts 30+ consecutive updates after app close
- ✅ ETA accuracy within ±5 minutes
- ✅ API response time < 500ms (p95)
- ✅ Admin verification throughput > 50 couriers/hour

---

## Implementation Checklist

### Phase 5A: Auth & Profiles (Weeks 1-2)
- [ ] Create `020_auth_and_profiles.sql` migration
- [ ] Split auth endpoints (`/auth/signup/courier`, etc.)
- [ ] Create 4-step courier signup screens + controller
- [ ] Create 2-step client signup screens + controller
- [ ] Add profile_step and auth_method columns to users table
- [ ] Test end-to-end signup flow for both roles
- [ ] Admin signup form (defer to week 14)

### Phase 5B: Delivery Creation (Weeks 3-4)
- [ ] Integrate Google Places API
- [ ] Create 5-step delivery creation screens
- [ ] Create delivery_creation_controller
- [ ] Extend POST /parcels endpoint
- [ ] Add recipient_type field to parcels table
- [ ] Available couriers filtering and ranking
- [ ] Test end-to-end delivery creation workflow

### Phase 5C: Route Management (Weeks 5-6)
- [ ] Create `021_routes.sql` migration
- [ ] Complete route declaration workflow (2 steps)
- [ ] Create routes list + detail screens
- [ ] Implement route lifecycle (PLANNED → ACTIVE → COMPLETED)
- [ ] Add route status enforcement in pickup handler
- [ ] Create routes_controller
- [ ] Test active route enforcement

### Phase 5D: Pickup & Dropoff (Weeks 7-8)
- [ ] Add location editing at pickup
- [ ] Create recipient_handoff_screen for in-app users
- [ ] Implement PIN generation (4-digit)
- [ ] Add recipient notification system (5-min warning)
- [ ] Implement non-recipient external delivery flow
- [ ] Improve post-delivery rating UX
- [ ] Test all handoff scenarios

### Phase 5E: Heuristic Tracking (Weeks 9-10) ⭐ CRITICAL
- [ ] Create `022_tracking_logs.sql` migration
- [ ] Implement `heuristic_tracking.js` service
- [ ] Add route adherence verification logic
- [ ] Add movement anomaly detection
- [ ] Add waypoint validation
- [ ] Create background cron job (runs every 2 min)
- [ ] Create admin adherence reports page
- [ ] Test with synthetic GPS traces (valid + fraudulent)
- [ ] Calibrate deviation thresholds (500m, 2 min)
- [ ] Monitor false positive rate

### Phase 5F: Background Location (Week 11)
- [ ] Add WorkManager dependency
- [ ] Add flutter_foreground_task dependency
- [ ] Implement periodic location task
- [ ] Configure foreground service
- [ ] Update Android manifest permissions
- [ ] Test continuous location posting (app closed)
- [ ] Measure battery impact
- [ ] Implement adaptive frequency

### Phase 5G: Price & ETA Models (Week 12)
- [ ] Create `023_pricing_models.sql` and `024_eta_and_connectivity.sql`
- [ ] Enhance price_recommendation.js (route matching)
- [ ] Implement `eta_model.js` service
- [ ] Implement `connectivity_mapper.js`
- [ ] Add ETA sources (declared, distance, Google, historical)
- [ ] Weighted average calculation
- [ ] Test ETA accuracy ±5 minutes

### Phase 5H: Navigation & Completion (Weeks 13)
- [ ] Implement bottom navigation (courier + client)
- [ ] Create parcels_list_screen
- [ ] Create active_deliveries_screen (client)
- [ ] Implement FAB for primary actions
- [ ] Remove burger menus
- [ ] Review minimalist design
- [ ] Complete admin verification page
- [ ] Complete admin disputes page
- [ ] Integration testing (end-to-end flows)
- [ ] Performance optimization
- [ ] Production readiness checklist

---

## Document Version History

| Version | Date | Changes |
|---|---|---|
| 1.0 | May 12, 2026 | Initial comprehensive audit-based gap analysis |

---

**Status**: Ready for development team handoff  
**Next Step**: Assign developers to Phase 5A (weeks 1-2) starting immediately
