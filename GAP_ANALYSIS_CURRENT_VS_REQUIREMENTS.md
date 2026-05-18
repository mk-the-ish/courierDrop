# DropCity: Gap Analysis - Current vs. Requirements

**Analysis Date**: May 12, 2026
**Project Status**: Phase 4 (60% Complete) → Phase 5 Planning (100%)

---

## Executive Summary

The MASTER_TASK_OBJECTIVES_COMPLETION.md file documents what has been built across Phases 1-4. Your detailed requirements prompt describes a far more sophisticated platform than what's currently implemented. This document maps the gaps and provides prioritized action items.

**Current Implementation**: ~40% of requirements
**Gap**: ~60% of requirements not yet implemented
**Estimated Effort**: 10-12 weeks for Phase 5 (assuming 1 developer)

---

## 1. Authentication & User Profile System

### Current State
- ✅ Admin auth with Supabase (Firebase login, signup, forgot password)
- ✅ Basic courier onboarding (3-step PageView)
- ✅ Basic client onboarding (2-step PageView)

### Required State
- Firestore backend integration (not direct Firebase)
- Courier auth: signup, login, forgot password (3 separate flows)
- Client auth: signup, login, forgot password (3 separate flows)
- Courier profile capture: full name, ID + image, license + image, vehicle + images, vehicle details (4-5 screens)
- Client profile capture: full name, username, ID + image (2-3 screens)
- Admin auth: existing, just needs signup addition

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Firestore Backend** | ❌ N/A | ✅ Required | Backend service | HIGH |
| **Courier Signup Screens** | 1 combined | 4 separate | +3 screens | HIGH |
| **Courier Profile Fields** | Name, phone | Name, ID, license, vehicle | +3 fields | MEDIUM |
| **Client Signup Screens** | 1 combined | 2 separate | +1 screen | MEDIUM |
| **Client Profile Fields** | Name | Name, username, ID | +2 fields | LOW |
| **Password Reset** | ✅ (Admin only) | ✅ All apps | Extend to apps | MEDIUM |
| **Session Management** | ✅ Firebase | ❌ Backend JWT | Replace flow | HIGH |
| **Profile Completion Tracking** | Partial | ✅ Full tracking | Add tracking | LOW |

### Action Items
1. **Backend Service**: Create `backend/src/services/firebase_auth.js` (Firestore connector)
2. **Courier Auth**: Split `courier/lib/screens/auth/signup_screen.dart` → 4 screens (email, personal, license, vehicle)
3. **Client Auth**: Split `client/lib/screens/auth/signup_screen.dart` → 2 screens (email, personal)
4. **Database**: Create `backend/sql/020_auth_and_profiles.sql` (courier_profiles, client_profiles)
5. **Controllers**: Create signup controllers with multi-step state management

**Estimated Effort**: 2-3 weeks

---

## 2. Delivery Order Creation Flow

### Current State
- ❌ No delivery creation screen
- ❌ No parcel description/size/weight input
- ❌ No recipient selection UI
- ❌ No available couriers list
- ✅ Price recommendation engine exists (backend only)
- ✅ Matching service exists (backend only)

### Required State
- Multi-step delivery creation (4-5 screens)
- Parcel details: description, size (S/M/L picker), weight, arrival time
- Parcel image capture
- Location selection: pickup + destination (map + address autocomplete)
- Recipient selection: in-app user search OR external recipient
- Available couriers screen with ratings and custom pricing
- Dashboard integration with "Create New Delivery" button/FAB

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Dashboard Button** | ❌ N/A | ✅ FAB/Card | New UI | LOW |
| **Details Screen** | ❌ N/A | ✅ Description, size, weight | New screen | MEDIUM |
| **Image Capture** | ✅ Exists (pickup) | ✅ For parcel | Reuse component | LOW |
| **Location Selection** | ❌ N/A | ✅ Map + autocomplete | New screen | HIGH |
| **Recipient Selection** | ❌ N/A | ✅ In-app + external | New screen | HIGH |
| **Order Creation API** | ✅ Exists | ✅ Extend POST /parcels | Extend endpoint | MEDIUM |
| **Available Couriers UI** | ❌ N/A | ✅ List with profiles | New screen | MEDIUM |
| **Custom Pricing Input** | ❌ N/A | ✅ Price override | New UI | LOW |

### Database Changes
- `parcels` table: add recipient_selection_type (in_app/external), recipient_id (nullable), recipient_phone, recipient_name

### Action Items
1. **Screen 1**: `client/lib/screens/delivery/delivery_creation_step1_details.dart`
2. **Screen 2**: `client/lib/screens/delivery/delivery_creation_step2_image.dart`
3. **Screen 3**: `client/lib/screens/delivery/delivery_creation_step3_locations.dart` (Google Places autocomplete)
4. **Screen 4**: `client/lib/screens/delivery/delivery_creation_step4_recipient.dart`
5. **Screen 5**: `client/lib/screens/delivery/available_couriers_screen.dart`
6. **Controller**: `client/lib/controllers/delivery_creation_controller.dart`
7. **Backend**: Extend POST `/parcels`, add GET `/parcels/:id/matches`

**Estimated Effort**: 2-3 weeks

---

## 3. Courier Route Management

### Current State
- ❌ No route declaration screen
- ❌ No routes list screen
- ❌ No route status management
- ❌ No "start route" button
- ❌ No active route tracking
- ✅ Background location service exists

### Required State
- Route declaration: map visualization + time picker (2 screens)
- Routes list showing all declared routes with status
- Route details: map, assigned parcels, start/pause/end buttons
- Active route enforcement (no pickups without active route)
- ETA management based on distance + time
- Notifications before scheduled start time

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Route Declaration** | ❌ N/A | ✅ 2-step flow | New feature | HIGH |
| **Routes List Screen** | ❌ N/A | ✅ Show all routes | New screen | MEDIUM |
| **Route Details Screen** | ❌ N/A | ✅ Map + parcels | New screen | HIGH |
| **Start Route Button** | ❌ N/A | ✅ Activate route | New feature | MEDIUM |
| **Route Status Management** | ❌ N/A | ✅ PLANNED→ACTIVE→COMPLETED | DB + logic | MEDIUM |
| **ETA Calculation** | ✅ Exists (backend) | ✅ Display in app | Add to UI | LOW |
| **Active Route Enforcement** | ❌ N/A | ✅ Pickup gate check | New validation | MEDIUM |

### Database Changes
- New `routes` table (route_id, courier_id, start_time, status, parcels_count, etc.)
- Add `assigned_route_id` to parcels table
- Add route status validation in pickup workflow

### Action Items
1. **Backend**: Create `backend/src/routes/routes.js` API
2. **Database**: Create `backend/sql/021_routes.sql`
3. **Screen 1**: `courier/lib/screens/routes/route_declaration_step1_map.dart`
4. **Screen 2**: `courier/lib/screens/routes/route_declaration_step2_time.dart`
5. **Screen 3**: `courier/lib/screens/routes/routes_list_screen.dart`
6. **Screen 4**: `courier/lib/screens/routes/route_detail_screen.dart`
7. **Controller**: `courier/lib/controllers/route_declaration_controller.dart`
8. **Validation**: Add route active check in pickup handler

**Estimated Effort**: 2-3 weeks

---

## 4. Enhanced Pickup & Dropoff Workflows

### Current State
- ✅ Basic pickup screen (photo + GPS)
- ✅ Basic GPS gate verification (50m)
- ✅ PIN hashing
- ✅ OTP for recipient (basic)
- ✅ Dropoff screens for both sides
- ❌ Location editing in pickup
- ❌ Alternate pickup point suggestion
- ❌ In-app recipient notifications
- ❌ Non-recipient delivery flow (no 3WH)

### Required State
- Optimized pickup: photo + editable location + backend verification
- Alternate pickup point suggestion (if outside route)
- Parcels screen showing pending + accepted parcels with status
- Recipient notifications when courier is 5 min away
- Recipient capture photo + GPS verification
- Non-recipient delivery: sender receives notification + optional confirmation
- Ratings after successful dropoff

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Parcels Screen** | ❌ N/A | ✅ List pending/accepted | New screen | MEDIUM |
| **Pickup Location Edit** | ❌ N/A | ✅ Allow manual adjustment | Add feature | LOW |
| **Alternate Pickup Point** | ❌ N/A | ✅ Backend suggestion | Backend logic | HIGH |
| **Recipient Notifications** | ❌ N/A | ✅ 5 min before arrival | Add notification | MEDIUM |
| **Recipient Pickup Screen** | ❌ N/A | ✅ Photo + GPS + PIN gen | New screen | MEDIUM |
| **Non-Recipient Delivery** | ❌ N/A | ✅ Sender confirmation flow | New workflow | HIGH |
| **Rating Screen** | ✅ Exists | ✅ Post-delivery | Reuse component | LOW |

### Action Items
1. **Screen**: `courier/lib/screens/parcels/parcels_screen.dart` (new)
2. **Update**: `courier/lib/screens/pickup_screen.dart` (add location editing)
3. **Screen**: `client/lib/screens/delivery/recipient_pickup_screen.dart` (new)
4. **Backend**: POST `/parcels/:id/suggest-alternate-pickup` (new endpoint)
5. **Logic**: Handle non-recipient delivery flow with sender notification
6. **Notification**: Add Firebase messaging for recipient pickup reminder

**Estimated Effort**: 2-3 weeks

---

## 5. Advanced Backend Features (CRITICAL)

### 5.1 Heuristic Tracking System

**Current State**: ❌ Not implemented
**Required State**: ✅ Full route adherence verification with movement anomaly detection

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Route Adherence Check** | ❌ N/A | ✅ Compare to polyline | New service | HIGH |
| **Deviation Detection** | ❌ N/A | ✅ Flag >500m deviation | New logic | HIGH |
| **Movement Verification** | ❌ N/A | ✅ Detect stationary/teleport | New logic | HIGH |
| **Waypoint Validation** | ❌ N/A | ✅ Confirm pickup/dropoff | New logic | MEDIUM |
| **Speed Calculation** | ✅ Basic exists | ✅ Detect impossible speeds | Enhance | MEDIUM |
| **Tracking Logs** | ❌ N/A | ✅ Store all events | New table | LOW |
| **Adherence Reports** | ❌ N/A | ✅ Admin dashboard integration | New table + UI | MEDIUM |

### Action Items
1. **Service**: `backend/src/services/heuristic_tracking.js` (new, ~400 lines)
2. **Database**: `backend/sql/022_tracking_logs.sql`
3. **Job**: Cron job to analyze location updates
4. **API**: Endpoint for adherence reports

**Estimated Effort**: 2 weeks

### 5.2 Background Location Posting

**Current State**: ✅ Exists but not in background (foreground only)
**Required State**: ✅ Continuous posting even when app closed

**Gap Analysis**:
- Need WorkManager for periodic tasks
- Need foreground service for background location access
- Need Android permissions handling (FOREGROUND_SERVICE)
- Need to balance battery vs. tracking accuracy

### Action Items
1. **Update**: `courier/lib/services/background_location_service.dart` (add WorkManager)
2. **Dependencies**: Add `workmanager`, `flutter_foreground_task` to pubspec.yaml
3. **Android Config**: Update AndroidManifest.xml with permissions
4. **Testing**: Verify location posting continues after app close

**Estimated Effort**: 1 week

### 5.3 Advanced Price Recommendation Model

**Current State**: ✅ Basic engine exists
**Required State**: ✅ Route matching + percentage-based pricing

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Route Matching** | ✅ Corridor lookup | ✅ Declared route match | Enhance | MEDIUM |
| **Percentage Calculation** | ❌ N/A | ✅ % of route | New math | LOW |
| **Historical Data** | ❌ N/A | ✅ Track per-route history | New table | LOW |
| **Pricing History Log** | ❌ N/A | ✅ Store all calculations | New table | LOW |

### Action Items
1. **Enhance**: `backend/src/services/price_recommendation.js` (route percentage logic)
2. **Database**: `backend/sql/023_pricing_models.sql`

**Estimated Effort**: 1 week

### 5.4 ETA Calculation Model

**Current State**: ❌ Not implemented
**Required State**: ✅ Multi-source ETA with historical learning

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Declared Time** | ❌ N/A | ✅ Use courier estimate | New logic | LOW |
| **Distance/Speed** | ✅ Basic exists | ✅ Enhanced calculation | Enhance | LOW |
| **Google Maps API** | ❌ N/A | ✅ Traffic-aware ETA | New API call | MEDIUM |
| **Historical Averaging** | ❌ N/A | ✅ Learn from past trips | New logic | MEDIUM |
| **Connectivity Mapping** | ❌ N/A | ✅ Track signal zones | New service | HIGH |
| **Weighted Averaging** | ❌ N/A | ✅ Combine sources | New math | LOW |

### Action Items
1. **Service**: `backend/src/services/eta_model.js` (new, ~300 lines)
2. **Service**: `backend/src/services/connectivity_mapper.js` (new)
3. **Database**: `backend/sql/024_eta_and_connectivity.sql`
4. **API Key**: Google Maps API setup for routing

**Estimated Effort**: 2 weeks

### 5.5 Advanced Matching Algorithm

**Current State**: ✅ Basic matching exists
**Required State**: ✅ Enhanced with route status + capacity checks

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Distance Filter** | ✅ Exists | ✅ Keep | No gap | - |
| **Route Status Check** | ❌ N/A | ✅ ACTIVE or PLANNED | New filter | LOW |
| **Start Time Validation** | ❌ N/A | ✅ Within 30 min | New filter | LOW |
| **Capacity Check** | ❌ N/A | ✅ Remaining kg | New filter | LOW |
| **Ranking Logic** | ✅ Exists | ✅ Enhance with status | Update | LOW |

### Action Items
1. **Update**: `backend/src/services/matching.js` (add filters)
2. **Update**: `backend/sql/002_matching.sql` (RPC enhancement)

**Estimated Effort**: 1 week

---

## 6. Mobile App Navigation & UX

### Current State
- ❌ No bottom navigation in courier app
- ❌ No bottom navigation in client app
- ❌ Burger menus used instead of FAB
- ❌ Screens crowded with information

### Required State
- Courier app: 4 bottom nav buttons (home, parcels, routes, settings)
- Client app: 3 bottom nav buttons (home, deliveries, account)
- FAB for primary actions (declare route, create delivery)
- Minimalist screens with multi-screen workflows
- No burger menus

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Courier Bottom Nav** | ❌ N/A | ✅ 4 buttons | New navigation | MEDIUM |
| **Client Bottom Nav** | ❌ N/A | ✅ 3 buttons | New navigation | MEDIUM |
| **FAB Integration** | Partial | ✅ Primary actions | Enhance | LOW |
| **Screen Redesign** | ❌ N/A | ✅ Minimize info | UX review | MEDIUM |
| **Burger Menu Removal** | ✅ Mostly done | ✅ Complete removal | Minor update | LOW |

### Action Items
1. **Update**: `courier/lib/main.dart` (add BottomNavigationBar)
2. **Update**: `client/lib/main.dart` (add BottomNavigationBar)
3. **Reorganize**: Move screens into bottom nav structure
4. **UX Review**: Minimize information per screen

**Estimated Effort**: 1 week

---

## 7. Admin Dashboard Features

### Current State
- ✅ Monitoring dashboard (real-time stats)
- ✅ Alert rules UI
- ✅ Logs & analytics page
- ❌ Courier verification page
- ❌ Dispute resolution page
- ❌ Adherence reports

### Required State
- Courier verification: approve/reject pending couriers
- Conflict resolution: handle heuristic violations, failed gates, ratings
- Adherence reports: see route adherence per courier
- Low connectivity zones visualization

### Gap Analysis

| Feature | Current | Required | Gap | Complexity |
|---------|---------|----------|-----|------------|
| **Monitoring Dashboard** | ✅ Complete | ✅ Keep | No gap | - |
| **Alert Rules** | ✅ UI complete | ✅ Backend engine needed | Backend | HIGH |
| **Logs & Analytics** | ✅ Complete | ✅ Keep | No gap | - |
| **Courier Verification** | ❌ N/A | ✅ New page | New screen | MEDIUM |
| **Dispute Resolution** | ❌ N/A | ✅ New page | New screen | HIGH |
| **Adherence Reports** | ❌ N/A | ✅ Chart view | New page | MEDIUM |

### Action Items
1. **Screen**: `admin/src/app/admin/verification/page.tsx` (courier approval)
2. **Screen**: `admin/src/app/admin/disputes/page.tsx` (conflict resolution)
3. **Backend**: Alert rules evaluation cron job
4. **Backend**: Adherence calculation endpoint

**Estimated Effort**: 2-3 weeks

---

## 8. Database Migrations Summary

**Required New Migrations**:
- ✅ `020_auth_and_profiles.sql` (courier_profiles, client_profiles)
- ✅ `021_routes.sql` (routes table, route status)
- ✅ `022_tracking_logs.sql` (heuristic tracking logs)
- ✅ `023_pricing_models.sql` (pricing history)
- ✅ `024_eta_and_connectivity.sql` (ETA logs, connectivity map)

**Total New Columns/Tables**: 15+

---

## 9. Summary: Gap vs. Effort Matrix

| Category | Gap Size | Effort | Priority | Timeline |
|----------|----------|--------|----------|----------|
| **Auth & Profiles** | 60% | HIGH | CRITICAL | Weeks 1-2 |
| **Delivery Creation** | 90% | HIGH | CRITICAL | Weeks 3-4 |
| **Route Management** | 100% | HIGH | HIGH | Weeks 5-6 |
| **Pickup/Dropoff** | 70% | MEDIUM | HIGH | Weeks 7-8 |
| **Heuristic Tracking** | 100% | HIGH | CRITICAL | Weeks 9-10 |
| **Background Location** | 50% | MEDIUM | HIGH | Week 11 |
| **Price Model** | 50% | LOW | MEDIUM | Week 11 |
| **ETA Model** | 100% | MEDIUM | HIGH | Week 12 |
| **Navigation/UX** | 40% | MEDIUM | MEDIUM | Week 13 |
| **Admin Features** | 50% | MEDIUM | MEDIUM | Weeks 14-15 |

---

## 10. Implementation Roadmap - Phase 5 (15 Weeks)

### Week 1-2: Authentication Foundation
- Firestore backend integration
- Courier multi-step signup (4 screens)
- Client multi-step signup (2 screens)

### Week 3-4: Delivery Workflow
- Delivery creation (4 screens)
- Available couriers screen
- Backend API extensions

### Week 5-6: Route Management
- Route declaration (2 screens)
- Routes list & details
- Active route enforcement

### Week 7-8: Pickup & Dropoff Polish
- Parcels screen (courier)
- Location editing in pickup
- Recipient notification flows
- Non-recipient delivery handling

### Week 9-10: Heuristic Tracking
- Route adherence verification
- Movement anomaly detection
- Waypoint validation
- Tracking logs & reports

### Week 11: Background Location & Optimization
- WorkManager integration
- Foreground service setup
- Android permission handling
- Price model route matching

### Week 12: ETA & Connectivity
- Multi-source ETA calculation
- Connectivity mapping
- Historical learning

### Week 13: Navigation & UX
- Bottom navigation implementation
- Screen redesigns
- FAB integration

### Week 14-15: Admin & Testing
- Courier verification page
- Dispute resolution page
- Alert rules evaluation job
- Integration testing

---

## 11. Resource Requirements

**Backend Developer**: 1 FTE (10-12 weeks)
- Auth integration
- Advanced algorithms (heuristic, ETA, pricing)
- New API endpoints
- Database migrations

**Mobile Developer**: 1 FTE (10-12 weeks)
- Multi-step onboarding
- Delivery workflows
- Route management
- UI/UX implementation

**Quality Assurance**: 0.5 FTE (ongoing)
- Integration testing
- End-to-end scenarios
- Performance testing

**Total Effort**: ~25 developer weeks (1 backend + 1 mobile developer working in parallel)

---

## 12. Risk Factors

| Risk | Impact | Mitigation |
|------|--------|-----------|
| **Google Maps API costs** | HIGH | Implement caching, set quota limits |
| **Battery drain** | HIGH | Optimize location update frequency, test on device |
| **Background task termination** | MEDIUM | Implement retry logic, use WorkManager best practices |
| **Heuristic accuracy** | HIGH | Collect data early, refine algorithm over time |
| **3WH security (non-recipient)** | HIGH | Require sender confirmation, log all interactions |
| **Scope creep** | MEDIUM | Strict feature freeze, prioritize MVP |

---

## Conclusion

The DropCity platform currently implements the core delivery logistics features (Phases 1-3) but is missing the advanced workflows and optimizations described in your comprehensive requirements. Phase 5 represents a significant undertaking (10-12 weeks) but is essential for a production-ready platform.

**Recommendation**: Prioritize in this order:
1. **Authentication & Profiles** (foundation for all users)
2. **Delivery Creation** (core business flow)
3. **Heuristic Tracking** (critical for fraud prevention)
4. **Route Management** (enables efficient matching)
5. **Admin Features** (operational visibility)

Begin immediately with Phase 5A (Auth & Profiles) to establish the foundation for subsequent phases.

---

*Document Version: 1.0*
*Analysis Date: May 12, 2026*
*Status: Ready for Implementation Planning*
