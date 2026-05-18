# DropCity Phase 5: Quick Reference & Action Items

**Date**: May 12, 2026  
**Status**: Planning Complete → Ready for Implementation  
**Estimated Duration**: 15 weeks (1-2 developers)

---

## Current vs. Future State (Visual Summary)

```
CURRENT (Phase 1-4: 40% of vision)
├── Auth: Basic onboarding screens ✅
├── Pricing: Engine only ✅
├── Pickup: GPS gate + photo ✅
├── Dropoff: OTP verification ✅
├── Tracking: Background location ✅
├── Admin: Real-time monitoring ✅
└── Missing: Everything else ❌

FUTURE (Phase 5: 100% of vision)
├── Auth: ✅ Multi-step signup/login/forgot password (all apps)
├── Profiles: ✅ Courier (name, ID, license, vehicle), Client (name, username, ID)
├── Delivery: ✅ Multi-step creation (description, size, weight, location, recipient)
├── Routes: ✅ Declaration, management, active status enforcement
├── Parcels: ✅ List screen (pending + accepted), parcels screen
├── Pickup: ✅ Optimized (location edit, alternate suggestions)
├── Dropoff: ✅ Recipient in-app notifications, PIN generation, non-recipient flow
├── Tracking: ✅ Heuristic verification (on-route adherence, anomaly detection)
├── Background Location: ✅ Continuous posting (WorkManager + foreground service)
├── ETA: ✅ Multi-source calculation (declared + distance + Google + historical)
├── Price Model: ✅ Route matching + percentage-based
├── Navigation: ✅ Bottom nav (no burger menus)
└── Admin: ✅ Courier verification, dispute resolution, adherence reports
```

---

## 15-Week Implementation Timeline

### Phase 5A: Auth & Profiles (Weeks 1-2)

**Backend**:
- [ ] Create `backend/src/services/firebase_auth.js` (Firestore connector)
- [ ] Endpoints: signup, login, forgot password, token refresh
- [ ] Database: `backend/sql/020_auth_and_profiles.sql`

**Courier App**:
- [ ] Screen 1: Email/password signup
- [ ] Screen 2: Personal info (full name, ID + image)
- [ ] Screen 3: License (license number + image)
- [ ] Screen 4: Vehicle details (type, make, model, year, color, registration + images, capacity)
- [ ] Controller: State management for 4-step flow
- [ ] Update: Login & forgot password screens

**Client App**:
- [ ] Screen 1: Email/password signup
- [ ] Screen 2: Personal info (full name, username, ID + image)
- [ ] Controller: State management for 2-step flow
- [ ] Update: Login & forgot password screens

**Admin**:
- [ ] Add signup flow (currently only login + forgot password)

---

### Phase 5B: Delivery Creation (Weeks 3-4)

**Client App**:
- [ ] Dashboard: Add "Create Delivery" FAB
- [ ] Screen 1: Description, size (S/M/L picker), weight, arrival time
- [ ] Screen 2: Parcel image capture
- [ ] Screen 3: Location selection (map + address autocomplete via Google Places)
- [ ] Screen 4: Recipient selection (in-app user search OR external phone)
- [ ] Screen 5: Available couriers list (profiles, ratings, recommended price, custom price input)
- [ ] Controller: Multi-step state management + image upload
- [ ] Return to dashboard: Show "Awaiting Courier Confirmation"

**Backend**:
- [ ] Extend POST `/parcels` endpoint
- [ ] Add GET `/parcels/:id/matches` (return matched couriers)
- [ ] Add POST `/parcels/:id/select-courier` (client selects + custom price)
- [ ] Add POST `/parcels/:id/notify-recipient` (send in-app notification)

**Database**:
- [ ] Add to `parcels`: recipient_type, recipient_id, recipient_phone, recipient_name

---

### Phase 5C: Route Management (Weeks 5-6)

**Courier App**:
- [ ] Screen 1: Route declaration - map visualization + draw/define route
- [ ] Screen 2: Time picker - start time + ETA calculation
- [ ] Screen 3: Routes list - show all declared routes with status badges
- [ ] Screen 4: Route details - map + assigned parcels + start/pause/end buttons
- [ ] Controller: Route state management
- [ ] Dashboard: Show active route + next parcels

**Backend**:
- [ ] New route endpoints: POST, GET, PATCH (start/pause/end)
- [ ] Database: `backend/sql/021_routes.sql` (routes table)
- [ ] Logic: Only allow pickups if route is ACTIVE

**Validation**:
- [ ] Pickup handler: Check route active status before allowing pickup
- [ ] Notification: Remind courier 5 min before scheduled start time

---

### Phase 5D: Pickup & Dropoff (Weeks 7-8)

**Courier App**:
- [ ] Screen: Parcels list (pending + accepted with status badges)
- [ ] Update pickup screen: Add location editing capability
- [ ] Backend suggest alternate pickup point if outside route

**Client App**:
- [ ] Screen: Recipient pickup (if in-app user) - photo + GPS + PIN generation
- [ ] Notification: "Courier arriving in 5 minutes"

**Courier App**:
- [ ] Update dropoff screen: Show recipient details + PIN entry
- [ ] Photo capture: Handoff confirmation

**Backend**:
- [ ] POST `/parcels/:id/suggest-alternate-pickup` (location suggestion)
- [ ] Logic: Validate recipient location within 50m of destination
- [ ] Logic: Generate 4-digit PIN (no external recipient flow)

**Non-Recipient Flow**:
- [ ] Sender receives notification: "Parcel delivered at [location]"
- [ ] Sender can confirm or dispute delivery
- [ ] If dispute: flag for admin review

---

### Phase 5E: Heuristic Tracking (Weeks 9-10)

**Backend** (CRITICAL):
- [ ] Service: `backend/src/services/heuristic_tracking.js`
  - Route adherence verification (compare to polyline)
  - Deviation detection (>500m for >2 min)
  - Movement verification (no teleportation, detect stationary)
  - Waypoint validation (pickup/dropoff confirmation)
  - Speed anomaly detection (impossible speeds)
- [ ] Database: `backend/sql/022_tracking_logs.sql`
- [ ] Job: Cron to analyze location updates in real-time
- [ ] Admin API: Endpoint for adherence reports + route deviation logs

**Functions to Implement**:
```javascript
verifyRouteAdherence(courierId, locations, route)
  → { adherencePercent, deviations[], flags[] }

detectMovementAnomalies(courierId, locationHistory)
  → { anomalies[], suspiciousEvents[] }

validateWaypoints(locations, route, radius=50m)
  → { waypointsPassedAt[], missedWaypoints[] }

calculateActualSpeed(lat1, lng1, lat2, lng2, timeDelta)
  → speedKmH (flag if > 200 km/h)
```

**Logging**:
- Every location update gets heuristic analysis
- Store results in tracking_logs table
- Generate adherence reports daily

---

### Phase 5F: Background Location Posting (Week 11)

**Courier App**:
- [ ] Update: `courier/lib/services/background_location_service.dart`
- [ ] Add: `workmanager` package (periodic tasks)
- [ ] Add: `flutter_foreground_task` package (foreground service)
- [ ] Logic: Post location every 30 seconds (even when app closed)

**Android Setup**:
- [ ] AndroidManifest.xml permissions:
  - `ACCESS_FINE_LOCATION`
  - `FOREGROUND_SERVICE`
  - `FOREGROUND_SERVICE_LOCATION`
- [ ] foregroundTask service declaration

**pubspec.yaml**:
```yaml
dependencies:
  workmanager: ^0.5.1
  flutter_foreground_task: ^3.10.0
```

**Testing**:
- [ ] Verify location posts after app close
- [ ] Check battery impact
- [ ] Test on Android 10+ (permission handling)

---

### Phase 5G: Price & ETA Models (Week 12)

**Backend - Price Model**:
- [ ] Enhance: `backend/src/services/price_recommendation.js`
- [ ] Add: Route matching (find closest historical route)
- [ ] Add: Percentage calculation (distance % of route)
- [ ] Database: `backend/sql/023_pricing_models.sql` (pricing history)

**Backend - ETA Model**:
- [ ] Create: `backend/src/services/eta_model.js`
- [ ] Sources:
  1. Courier declared time
  2. Distance ÷ average speed (40 km/h)
  3. Google Maps API (traffic-aware)
  4. Historical average for this route
- [ ] Weighted average with confidence scores
- [ ] Add 5-min buffer before estimated pickup

**Backend - Connectivity Mapping**:
- [ ] Service: `backend/src/services/connectivity_mapper.js`
- [ ] Track signal strength by location (future ETA adjustment)
- [ ] Database: `backend/sql/024_eta_and_connectivity.sql`

---

### Phase 5H: Navigation & UX (Week 13)

**Courier App**:
- [ ] Update: `courier/lib/main.dart`
- [ ] Add BottomNavigationBar with 4 items:
  1. Home (dashboard + stats)
  2. Parcels (pending + accepted list)
  3. Routes (declared routes management)
  4. Settings (profile, preferences, logout)
- [ ] Remove burger menus, use FAB for primary actions

**Client App**:
- [ ] Update: `client/lib/main.dart`
- [ ] Add BottomNavigationBar with 3 items:
  1. Home (dashboard + create delivery FAB)
  2. Deliveries (active + completed)
  3. Account (profile, settings, logout)

**UX Review**:
- [ ] Minimize information per screen
- [ ] Prefer multi-screen workflows
- [ ] Remove clutter from existing screens

---

### Phase 5I: Admin & Testing (Weeks 14-15)

**Admin**:
- [ ] Screen: `admin/src/app/admin/verification/page.tsx` (courier approval/rejection)
- [ ] Screen: `admin/src/app/admin/disputes/page.tsx` (conflict resolution)
  - List incidents (heuristic violations, gate failures, ratings, offline events)
  - Approve delivery, deny delivery, request info, auto-refund, escalate
  - Evidence: GPS data, photos, location logs
- [ ] Page: Adherence reports (charts + tables)

**Backend**:
- [ ] Alert rules evaluation cron job (check every 2 min)
- [ ] Endpoints: POST `/admin/courier/:id/approve`, GET `/admin/disputes`, etc.

**Testing**:
- [ ] Integration tests: End-to-end delivery flow
- [ ] Error scenarios: Failed PIN, gate violation, offline sync
- [ ] Performance: <500ms API response time (p95)
- [ ] Background location: 30+ consecutive updates after app close

---

## Critical Success Criteria (Must Have)

- ✅ All auth flows working (signup, login, forgot password)
- ✅ Courier profile creation with all fields + images
- ✅ Delivery creation with multi-step UX
- ✅ Route declaration + active route enforcement
- ✅ Heuristic tracking detecting on-route adherence
- ✅ Background location posting continuously
- ✅ ETA accuracy within ±5 minutes
- ✅ Matching algorithm matching >90% of parcels
- ✅ No 404 errors in production
- ✅ API response time <500ms (p95)

---

## File Changes Summary

### New Screens (11 Flutter + 6 TypeScript)
**Courier App**: signup_step1-4, route_declaration_step1-2, routes_list, route_detail, parcels_list
**Client App**: signup_step1-2, delivery_creation_step1-4, available_couriers, recipient_pickup
**Admin**: verification, disputes, adherence_reports

### New Services (7)
**Backend**: firebase_auth, heuristic_tracking, eta_model, connectivity_mapper, enhanced price_recommendation, enhanced matching

### New Database Migrations (5)
`020_auth_and_profiles.sql`, `021_routes.sql`, `022_tracking_logs.sql`, `023_pricing_models.sql`, `024_eta_and_connectivity.sql`

### New Controllers (4)
**Courier**: signup_controller, route_declaration_controller, routes_controller, parcels_controller
**Client**: signup_controller, delivery_creation_controller, available_couriers_controller, recipient_pickup_controller

---

## Dependencies to Add

```yaml
# Courier/Client pubspec.yaml
dependencies:
  workmanager: ^0.5.1
  flutter_foreground_task: ^3.10.0
  google_places_flutter: ^2.0.0  # For address autocomplete
  flutter_polyline_points: ^0.2.0  # For route visualization
```

```javascript
// Backend package.json
{
  "google-maps-services": "^1.17.0",  // For ETA/geocoding
  "workmanager": "^6.0.0"
}
```

---

## Resource Allocation

| Role | Hours/Week | Duration | Total |
|------|-----------|----------|-------|
| Backend Dev | 40 | 12 weeks | 480 hours |
| Mobile Dev | 40 | 12 weeks | 480 hours |
| QA | 20 | 15 weeks | 300 hours |
| **Total** | - | - | **1,260 hours** |

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| **Battery drain** | Implement adaptive update frequency, test on real device, set max battery usage threshold |
| **Google API costs** | Set quota limits, cache responses, use predictive caching |
| **Heuristic false positives** | Train algorithm with real data, add manual override capability, log confidence scores |
| **Background task termination** | Implement retry logic, use WorkManager best practices, test across Android versions |
| **Scope creep** | Strict feature freeze, use checklist-based acceptance criteria |

---

## Next Steps

1. **Review** this document with team
2. **Prioritize** features by business value
3. **Assign** developer roles (backend, mobile)
4. **Setup** development branches
5. **Begin** Phase 5A (Auth & Profiles)

**Start Date**: [Set internally]  
**Target Completion**: 15 weeks after start

---

*Last Updated: May 12, 2026*
*Document Status: FINAL - Ready for Implementation*
