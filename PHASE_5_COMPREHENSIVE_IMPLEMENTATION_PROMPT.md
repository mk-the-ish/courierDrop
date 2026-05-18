# DropCity Phase 5: Platform Polish & Advanced Workflows
## Comprehensive Implementation Prompt

### Overview
This document outlines the remaining implementations needed to complete DropCity from a functional MVP (Phase 1-4) to a production-ready platform with advanced delivery workflows, route management, and AI-based optimization.

---

## 1. Authentication & User Profile System (PRIORITY: CRITICAL)

### 1.1 Firestore Backend Integration

**Objective**: Centralize auth through backend with Firestore support (not direct Firebase in apps)

**Backend Services to Create** (`backend/src/services/auth.js` - refactor):
- Firestore connector for courier/client auth
- JWT token generation with role-based claims
- Session management (refresh tokens, token expiry)
- Multi-app auth coordination (client, courier, admin)

**Auth Endpoints** (`backend/src/routes/auth.js` - extend):
```
POST   /auth/signup/courier                 → Courier signup (email, password, basic info)
POST   /auth/signup/client                  → Client signup (email, password, basic info)
POST   /auth/login/courier                  → Courier login
POST   /auth/login/client                   → Client login
POST   /auth/forgot-password/courier        → Courier password reset
POST   /auth/forgot-password/client         → Client password reset
POST   /auth/verify-token                   → Verify JWT token
POST   /auth/refresh-token                  → Refresh expired token
GET    /auth/me                             → Get current user profile
```

**Database Schema** (`backend/sql/020_auth_and_profiles.sql`):
```sql
-- Courier Profiles Table
CREATE TABLE courier_profiles (
  id TEXT PRIMARY KEY REFERENCES users(id),
  full_name TEXT NOT NULL,
  id_number TEXT UNIQUE NOT NULL,
  id_image_url TEXT,
  license_number TEXT UNIQUE NOT NULL,
  license_image_url TEXT,
  vehicle_registration TEXT UNIQUE NOT NULL,
  vehicle_registration_images TEXT[], -- Array of URLs
  vehicle_type TEXT,
  vehicle_make TEXT,
  vehicle_model TEXT,
  vehicle_year INTEGER,
  vehicle_color TEXT,
  vehicle_capacity_kg DECIMAL,
  profile_complete BOOLEAN DEFAULT FALSE,
  verified_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Client Profiles Table
CREATE TABLE client_profiles (
  id TEXT PRIMARY KEY REFERENCES users(id),
  full_name TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  id_number TEXT UNIQUE NOT NULL,
  id_image_url TEXT,
  profile_complete BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add columns to users table
ALTER TABLE users ADD COLUMN profile_step INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN auth_method TEXT; -- 'firestore' or 'supabase'
```

---

### 1.2 Courier App: Multi-Step Signup Flow

**Screens to Create**:

1. **CourierSignupStep1_Email** (`courier/lib/screens/auth/signup_step1_email.dart`)
   - Email & password input
   - Validation (email format, password strength)
   - Next button → Step 2

2. **CourierSignupStep2_PersonalInfo** (`courier/lib/screens/auth/signup_step2_personal.dart`)
   - Full name, ID number input
   - ID photo capture (camera + gallery)
   - Save & proceed → Step 3

3. **CourierSignupStep3_License** (`courier/lib/screens/auth/signup_step3_license.dart`)
   - License number input
   - License photo capture
   - Save & proceed → Step 4

4. **CourierSignupStep4_Vehicle** (`courier/lib/screens/auth/signup_step4_vehicle.dart`)
   - Vehicle type (pickup, van, truck)
   - Vehicle make/model/year
   - Vehicle color
   - Vehicle registration number
   - Vehicle registration images (multiple)
   - Estimated capacity (kg)
   - Save & complete signup

**Controller**: `courier/lib/controllers/signup_controller.dart`
- State management for multi-step form
- Image upload handling
- Form validation
- API calls to backend

**UI Components**:
- Progress indicator (4 steps)
- Image picker wrapper with preview
- Form validation with error messages
- Loading states

---

### 1.3 Client App: Multi-Step Signup Flow

**Screens to Create**:

1. **ClientSignupStep1_Email** (`client/lib/screens/auth/signup_step1_email.dart`)
   - Email & password input
   - Next → Step 2

2. **ClientSignupStep2_PersonalInfo** (`client/lib/screens/auth/signup_step2_personal.dart`)
   - Full name, username, ID number
   - ID photo capture
   - Complete signup

**Controller**: `client/lib/controllers/signup_controller.dart`

---

### 1.4 Admin Auth (Supabase) - Enhance

**Current Status**: Basic Firebase auth exists. Need to:
- Add "Sign Up" flow (currently login + forgot password only)
- Add multi-step admin profile creation
- Add role verification during signup

---

## 2. Delivery Order Creation Flow (PRIORITY: HIGH)

### 2.1 Client App Dashboard Enhancement

**Update**: `client/lib/screens/dashboard/client_dashboard.dart`
- Add prominent "Create New Delivery" button (FAB or card)

---

### 2.2 Delivery Creation Screens

**Screen 1**: `client/lib/screens/delivery/delivery_creation_step1_details.dart`
- **Parcel Description** text field
- **Size Selector** (S/M/L with visual indicators)
- **Weight** input (kg)
- **Desired Arrival Time** (time picker)
- Next button → Step 2

**Screen 2**: `client/lib/screens/delivery/delivery_creation_step2_image.dart`
- Parcel image capture
- Image preview
- Next button → Step 3

**Screen 3**: `client/lib/screens/delivery/delivery_creation_step3_locations.dart`
- **Pickup Point**: 
  - Google Maps widget
  - Manual address input with autocomplete
  - "Use current location" button
- **Destination**:
  - Same as pickup (map + address)
- Next button → Step 4

**Screen 4**: `client/lib/screens/delivery/delivery_creation_step4_recipient.dart`
- **Recipient Selection**:
  - Option 1: Search existing app user (by username/email)
  - Option 2: External recipient (phone number, name)
  - If in-app recipient selected: show profile card with verification
  - If external: show "sender will be notified" warning
- Create Delivery button

**Controller**: `client/lib/controllers/delivery_creation_controller.dart`
- State management for all steps
- Image upload
- Location geocoding/validation
- API call to POST `/parcels`

---

### 2.3 Backend Delivery Endpoint Enhancement

**Update**: `backend/src/routes/parcels.js`

```javascript
POST /parcels
{
  description: string,
  size: "S|M|L",
  weight_kg: number,
  desired_arrival_time: ISO8601,
  image_url: string,
  origin_address: string,
  origin_point: geography (WGS84),
  destination_address: string,
  destination_point: geography (WGS84),
  recipient_id: string (nullable - if in-app user),
  recipient_phone: string (nullable - if external),
  recipient_name: string (nullable - if external),
  created_by: string (current user)
}

Response:
{
  id: uuid,
  status: "REQUESTED",
  recommended_price: number,
  recipient_in_app: boolean,
  estimated_pickup_time: ISO8601,
  matching_triggered: boolean
}
```

---

### 2.4 Available Couriers Screen

**Screen**: `client/lib/screens/delivery/available_couriers_screen.dart`
- List of matched couriers (from matching service)
- Each courier card shows:
  - Profile photo
  - Name & rating (stars)
  - Total trips
  - Current location (distance from pickup)
  - Recommended price (from pricing engine)
  - Custom price input field
  - "Select Courier" button
- After selection → return to dashboard, show "Awaiting Courier Confirmation"

**Controller**: `client/lib/controllers/available_couriers_controller.dart`
- Fetch matched couriers from GET `/parcels/:id/matches`
- Handle custom price submission POST `/parcels/:id/select-courier`

---

### 2.5 Backend Endpoints

```
GET    /parcels/:id/matches              → Get matched couriers for parcel
POST   /parcels/:id/select-courier       → Client selects courier + custom price
POST   /parcels/:id/notify-recipient     → Send in-app notification to recipient
GET    /parcels/client/:id/active        → Get active parcels for client
```

---

## 3. Courier Route Management (PRIORITY: HIGH)

### 3.1 Route Declaration Workflow

**Screen 1**: `courier/lib/screens/routes/route_declaration_step1_map.dart`
- **Google Maps** widget
- Draw/define route manually (start → end points on map)
- OR: Pre-populated from matching algorithm
- Show route distance and estimated travel time
- Next → Step 2

**Screen 2**: `courier/lib/screens/routes/route_declaration_step2_time.dart`
- **Trip Start Time** (time picker)
- **Estimated End Time** (auto-calculated or manual)
- **Break Duration** (optional)
- Calculate ETA based on:
  - Distance
  - Average speed (default 40 km/h, adjustable)
  - Traffic data (if available via Google)
- Submit → Create route

**Controller**: `courier/lib/controllers/route_declaration_controller.dart`

---

### 3.2 Routes Management Screen

**Screen**: `courier/lib/screens/routes/routes_list_screen.dart`
- List of all declared routes:
  - Route name (e.g., "Harare - Chitungwiza")
  - Start time & ETA
  - Status badge (PLANNED, ACTIVE, COMPLETED, CANCELLED)
  - Distance
  - Parcels assigned (count)
- "Declare New Route" FAB
- Tap route → route detail page
- Route detail shows:
  - Map visualization
  - All assigned parcels with pickup/dropoff points
  - Start/resume/end buttons
  - Pickup next route button

**Controller**: `courier/lib/controllers/routes_controller.dart`

---

### 3.3 Route Status Management

**Screen**: `courier/lib/screens/routes/route_detail_screen.dart`
- Show route on map with polyline
- Show all parcels assigned to this route as markers
- **Start Route Button**: Activate route
  - Notification reminder sent 5 min before start time
  - Only allow pickup orders once route is ACTIVE
- **Pause Route Button**: Temporarily stop (for breaks)
- **End Route Button**: Mark route as completed

---

### 3.4 Backend Route Endpoints

```
POST   /courier/routes                 → Create new route
GET    /courier/routes                 → List courier's routes
GET    /courier/routes/:id             → Get route details
PATCH  /courier/routes/:id/start       → Start route (set status to ACTIVE)
PATCH  /courier/routes/:id/pause       → Pause route
PATCH  /courier/routes/:id/end         → End route
POST   /courier/routes/:id/parcels     → Get parcels for this route
```

**Database Schema** (`backend/sql/021_routes.sql`):
```sql
CREATE TABLE routes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT NOT NULL REFERENCES users(id),
  route_name TEXT,
  start_point GEOGRAPHY(Point, 4326),
  end_point GEOGRAPHY(Point, 4326),
  route_polyline TEXT, -- Google Maps encoded polyline
  start_time TIMESTAMP NOT NULL,
  estimated_end_time TIMESTAMP,
  actual_end_time TIMESTAMP,
  status TEXT DEFAULT 'PLANNED', -- PLANNED, ACTIVE, COMPLETED, CANCELLED
  capacity_remaining_kg DECIMAL,
  total_parcels INTEGER DEFAULT 0,
  completed_parcels INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT NOW()
);

ALTER TABLE parcels ADD COLUMN assigned_route_id UUID REFERENCES routes(id);
```

---

## 4. Enhanced Pickup & Dropoff Workflows (PRIORITY: HIGH)

### 4.1 Parcels Screen (Courier App)

**Screen**: `courier/lib/screens/parcels/parcels_screen.dart`
- **Pending Parcels Tab**:
  - List of unaccepted parcels near courier's current location
  - Each card shows:
    - Pickup address
    - Destination address
    - Offered price
    - Sender name & rating
    - Distance from current location
    - Accept/Decline buttons
- **Accepted Parcels Tab**:
  - List of accepted parcels in current route
  - Each card shows:
    - Status (PENDING_PICKUP, IN_TRANSIT, PENDING_DROPOFF, DELIVERED)
    - Pickup button (if PENDING_PICKUP)
    - View on map button
    - Dropoff button (if IN_TRANSIT)
- Pull-to-refresh

**Controller**: `courier/lib/controllers/parcels_controller.dart`

---

### 4.2 Optimized Pickup Flow

**Current Flow** (from Phase 2):
1. Tap parcel
2. Photo capture screen
3. Post photo + coordinates
4. Backend verification

**New Optimized Flow**:
1. Tap parcel → **Pickup button** (on parcels list card)
2. → Photo capture screen
   - Capture photo of parcel
   - Show current GPS coordinates
   - **Edit Location Button**: Manual adjustment (if pickup point not on exact route)
3. Upload photo + coordinates
4. Backend verifies:
   - Location within 50m of pickup point
   - If outside route but close: suggest alternate pickup point on route
5. Confirmation

**Controller Update**: `courier/lib/controllers/pickup_controller.dart`
- Add location editing
- Handle alternate pickup point suggestion

---

### 4.3 Dropoff: With In-App Recipient

**Screen 1**: `client/lib/screens/delivery/recipient_pickup_screen.dart` (if recipient is in-app user)
- Recipient receives notification when courier is 5 min away
- Recipient navigates to this screen
- **Camera**: Capture photo of parcel acceptance
- **Current Location**: Show GPS coordinates
- Backend verifies location within 50m of destination
- **Generate PIN Button**: Creates 4-digit PIN
- PIN displayed to recipient (copy/see option)
- Recipient shares PIN with courier (verbally or in-app message)

**Screen 2**: `courier/lib/screens/delivery/dropoff_delivery_screen.dart` (courier side)
- Similar to pickup but dropoff-focused
- **Enter PIN Field**: Courier enters PIN from recipient
- **Verify PIN**: Backend confirms PIN matches
- **Photo Capture**: Courier takes photo of recipient/parcel handoff
- Upload photo + coordinates
- Backend verifies coordinates within destination
- **Rating Prompt**: Ask recipient to rate courier in-app

---

### 4.4 Dropoff: Non-In-App Recipient

**Challenge**: 3WH without recipient phone/internet

**Two Options**:

**Option A: Sender Verification** (current default)
- Courier captures photo at destination with coordinates
- Backend verifies location
- Sender (who has app) receives notification "Parcel delivered at [location]"
- Sender can confirm or dispute
- If sender disputes: mark as disputed, admin review later

**Option B: Recipient PIN (works offline after generation)**
1. Courier generates random PIN in-app (no connectivity needed)
2. Shows PIN to recipient
3. Recipient verbally confirms acceptance
4. Courier marks complete
5. Later syncs with backend when connectivity returns

**Implementation**:
- Add delivery_recipient_type field to parcels table
- If type = "external": use Option A or B based on settings
- Backend flag: `require_recipient_confirmation` boolean

---

### 4.5 Three-Way Handshake Rating (After Successful Dropoff)

**Screen**: `client/lib/screens/delivery/post_delivery_rating_screen.dart`
- Show courier profile (photo, name)
- **Star Rating** (1-5)
- **Comments** text field
- **Feedback Categories** (optional):
  - Professionalism
  - Speed
  - Care with package
  - Communication
- Submit button

**Backend**: POST `/parcels/:id/rate`

---

## 5. Advanced Backend Features (PRIORITY: CRITICAL)

### 5.1 Heuristic Tracking System

**Objective**: Verify courier is actually moving along declared route (prevent fraud)

**Module**: `backend/src/services/heuristic_tracking.js`

**Features**:
1. **Route Adherence Verification**:
   - Compare courier's actual location updates against declared route
   - Calculate deviation from route polyline
   - Alert if deviation > 500m for > 2 minutes
   - Track percentage of route completed

2. **Movement Verification**:
   - Ensure location updates show actual movement
   - Detect stationary periods longer than expected breaks
   - Calculate actual speed vs. expected speed
   - Flag suspicious patterns (teleportation, impossible speeds)

3. **Waypoint Validation**:
   - Confirm courier passes through pickup point (within 50m)
   - Confirm courier passes through destination point (within 50m)
   - Record timestamps for each waypoint

**Key Functions**:
```javascript
verifyRouteAdherence(courierId, locationUpdates, routePolyline)
  → returns { adherencePercentage, deviations, flags }

detectMovementAnomalies(courierId, locationHistory)
  → returns { anomalies, suspiciousEvents }

calculateActualSpeed(location1, location2, timeElapsed)
  → returns speedKmH

validateWaypoints(locations, routePolyline, waypointRadius)
  → returns { waypoinsPassedAt, missedWaypoints }
```

**Database Logging** (`backend/sql/022_tracking_logs.sql`):
```sql
CREATE TABLE tracking_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id),
  courier_id TEXT REFERENCES users(id),
  location_point GEOGRAPHY(Point, 4326),
  accuracy_m INTEGER,
  speed_kmh DECIMAL,
  heading INTEGER,
  route_deviation_m INTEGER,
  waypoint_proximity TEXT,
  movement_anomaly BOOLEAN,
  recorded_at TIMESTAMP NOT NULL
);

CREATE TABLE route_adherence_report (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT REFERENCES users(id),
  route_id UUID REFERENCES routes(id),
  adherence_percentage DECIMAL,
  total_deviations INTEGER,
  flags_raised INTEGER,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### 5.2 Background Location Posting (Android Permission Handling)

**Objective**: Post location even when app is not in foreground

**Current Issue**: Android 10+ only allows location access "while using app"

**Solution**: Use WorkManager + foreground service

**Update**: `courier/lib/services/background_location_service.dart`

```dart
import 'package:workmanager/workmanager.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundLocationService {
  static Future<void> initBackgroundLocationWithForegroundService() async {
    // Request Android permission: ACCESS_FINE_LOCATION with FOREGROUND_SERVICE
    
    // Configure foreground service
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'delivery_tracking',
        channelName: 'Delivery Tracking',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: IOSNotificationOptions(
        showNotification: false,
      ),
    );

    // Register background task
    Workmanager().registerPeriodicTask(
      'location_upload',
      'uploadLocationTask',
      frequency: Duration(seconds: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false, // Allow even on low battery
        requiresCharging: false,
      ),
    );
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
      if (task == 'uploadLocationTask') {
        await uploadCurrentLocation();
        return true;
      }
      return false;
    });
  }

  static Future<void> uploadCurrentLocation() async {
    // Get current location
    Position position = await Geolocator.getCurrentPosition();
    
    // Post to backend
    await apiClient.post('/courier/location', {
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      timestamp: DateTime.now().toIso8601String(),
    });
  }
}
```

**pubspec.yaml updates**:
```yaml
dependencies:
  workmanager: ^0.5.1
  flutter_foreground_task: ^3.10.0
```

**Android Manifest** (`courier/android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<service
  android:name="flutter.foreground.task.service.FlutterForegroundTaskService"
  android:foregroundServiceType="location"
  android:enabled="true"
  android:exported="false" />
```

---

### 5.3 Advanced Price Recommendation Model

**Objective**: Price parcels based on:
1. Declared route matching
2. Distance percentage
3. Historical route data

**Module**: `backend/src/services/price_model.js` (enhance)

```javascript
calculateDynamicPrice(parcel, declaredRoute, historicalData) {
  // Step 1: Match parcel route to nearest declared route
  const matchedRoute = findClosestRoute(
    parcel.origin_point,
    parcel.destination_point,
    historicalData.routes
  );

  // Step 2: Calculate position on route
  const percentageOfRoute = calculateRoutePercentage(
    parcel.origin_point,
    parcel.destination_point,
    matchedRoute.polyline
  );

  // Step 3: Get base fare for route
  const baseFare = matchedRoute.base_fare;

  // Step 4: Apply modifiers
  const weight_modifier = 1 + (parcel.weight_kg - 2) * 0.05; // +5% per kg over 2kg
  const size_modifier = getSizeMultiplier(parcel.size); // 0.5 (S), 1.0 (M), 2.0 (L)
  const distance_modifier = 1 + (percentageOfRoute * 0.3); // +30% if full route

  // Step 5: Calculate final price
  const recommended_price = baseFare 
    * weight_modifier 
    * size_modifier 
    * distance_modifier;

  return {
    recommended_price: Math.round(recommended_price * 100) / 100,
    matched_route: matchedRoute.name,
    route_percentage: percentageOfRoute,
    factors: {
      base_fare: baseFare,
      weight_modifier,
      size_modifier,
      distance_modifier
    }
  };
}
```

**Database Enhancement** (`backend/sql/023_pricing_models.sql`):
```sql
CREATE TABLE route_pricing_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  route_id UUID REFERENCES routes(id),
  parcels_completed INTEGER,
  total_revenue DECIMAL,
  average_price DECIMAL,
  average_weight DECIMAL,
  avg_completion_time_minutes INTEGER,
  recorded_date DATE
);

CREATE TABLE price_recommendations_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id),
  base_recommended_price DECIMAL,
  final_price DECIMAL (after user customization),
  price_adjustment_percent DECIMAL,
  matched_route TEXT,
  route_percentage DECIMAL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

### 5.4 ETA Calculation Model

**Objective**: Predict parcel arrival time using multiple data sources

**Module**: `backend/src/services/eta_model.js` (new)

```javascript
calculateETA(parcel, courier, declaredRoute) {
  const etaSources = [];

  // Source 1: Courier declared time
  const declaredETA = new Date(declaredRoute.estimated_end_time);
  etaSources.push({
    source: 'declared',
    eta: declaredETA,
    confidence: 0.4 // 40% confidence in initial declaration
  });

  // Source 2: Distance / Average Speed
  const distance = calculateDistance(parcel.origin_point, parcel.destination_point);
  const avgSpeed = 40; // km/h default
  const travelTimeMinutes = (distance / avgSpeed) * 60;
  const calculatedETA = new Date(Date.now() + travelTimeMinutes * 60000);
  etaSources.push({
    source: 'distance_speed',
    eta: calculatedETA,
    confidence: 0.3
  });

  // Source 3: Google Maps API (if available)
  let googleETA = null;
  try {
    googleETA = await getGoogleMapsETA(
      parcel.origin_point,
      parcel.destination_point,
      new Date()
    );
    etaSources.push({
      source: 'google_maps',
      eta: googleETA,
      confidence: 0.3
    });
  } catch (err) {
    // Fallback if API unavailable
  }

  // Source 4: Historical data for this route (if available)
  const historicalAvg = await getHistoricalAverageTime(declaredRoute.id);
  if (historicalAvg) {
    etaSources.push({
      source: 'historical',
      eta: new Date(Date.now() + historicalAvg * 60000),
      confidence: 0.5 // Higher confidence with historical data
    });
  }

  // Weighted average
  const finalETA = calculateWeightedAverage(etaSources);

  return {
    eta: finalETA,
    sources: etaSources,
    confidence_score: etaSources.reduce((sum, s) => sum + s.confidence, 0),
    pickup_notification_time: new Date(finalETA - 5 * 60000), // 5 min before
  };
}
```

**Connectivity Mapping** (`backend/src/services/connectivity_mapper.js` - new):
```javascript
// Track connectivity zones to improve ETA
recordConnectivityPoint(courierId, location, signalStrength, provider, deviceModel) {
  // Store in connectivity_map table
  // Later: identify low-signal zones for future ETA adjustments
}

getConnectivityZoneModifier(location) {
  // Returns ETA modifier based on historical connectivity data
  // If zone is known low-signal: add buffer to ETA
}
```

**Database** (`backend/sql/024_eta_and_connectivity.sql`):
```sql
CREATE TABLE connectivity_map (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id TEXT REFERENCES users(id),
  location_point GEOGRAPHY(Point, 4326),
  signal_strength_dbm INTEGER,
  network_provider TEXT,
  device_model TEXT,
  recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE eta_calculations_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parcel_id UUID REFERENCES parcels(id),
  estimated_arrival TIMESTAMP,
  actual_arrival TIMESTAMP,
  variance_minutes INTEGER,
  primary_source TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE zone_connectivity (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  zone_center GEOGRAPHY(Point, 4326),
  zone_radius_m INTEGER,
  avg_signal_strength_dbm INTEGER,
  common_providers TEXT[],
  eta_delay_minutes INTEGER
);
```

---

### 5.5 Advanced Matching Algorithm

**Objective**: Ensure couriers are matched correctly based on route, status, and capacity

**Module**: `backend/src/services/matching.js` (enhance current version)

```javascript
async findMatchingCouriers(parcel) {
  // Step 1: Distance Filter (existing)
  const nearbyRoutes = await supabase.rpc('match_corridors_for_parcel', {
    p_origin: parcel.origin_point,
    p_destination: parcel.destination_point,
    p_max_detour_m: 50000 // 50km
  });

  // Step 2: Filter by route status and timing (NEW)
  const validCouriers = nearbyRoutes.filter(route => {
    const now = new Date();
    const routeStartTime = new Date(route.start_time);
    
    // Route must be ACTIVE or starting within next 30 min
    const isActiveOrStarting = (
      route.status === 'ACTIVE' ||
      (route.status === 'PLANNED' && routeStartTime <= new Date(now + 30*60000))
    );

    // Courier must not have passed parcel start point yet
    const hasNotPassed = calculateDistanceToStart(
      route.current_location,
      parcel.origin_point
    ) > 0; // Positive means not yet passed

    return isActiveOrStarting && hasNotPassed;
  });

  // Step 3: Filter by capacity (NEW)
  const capableCouriers = validCouriers.filter(route => {
    const parcelWeight = parcel.weight_kg || 2;
    return route.capacity_remaining_kg >= parcelWeight;
  });

  // Step 4: Rank by distance + ETA (existing ranking)
  const rankedCouriers = capableCouriers.sort((a, b) => {
    return a.detour_distance - b.detour_distance;
  });

  return rankedCouriers;
}
```

**Update Matching RPC** (`backend/sql/002_matching.sql` - enhance):
```sql
ALTER FUNCTION match_corridors_for_parcel ADD FILTER:
  -- Filter by route status
  AND c.route_status IN ('ACTIVE', 'PLANNED')
  -- Filter by route start time (must be within next 30 min)
  AND (c.route_status = 'ACTIVE' OR c.start_time <= NOW() + INTERVAL '30 minutes')
  -- Filter by capacity
  AND c.capacity_remaining_kg >= p_weight_kg
  -- Filter by start point not passed
  AND st_distance(c.current_location, p_origin) > 0
```

---

## 6. Mobile App Navigation & UX (PRIORITY: MEDIUM)

### 6.1 Courier App Bottom Navigation

**Update**: `courier/lib/main.dart`

```dart
class CourierApp extends StatefulWidget {
  @override
  _CourierAppState createState() => _CourierAppState();
}

class _CourierAppState extends State<CourierApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomePage(),           // Index 0
    ParcelsScreen(),      // Index 1
    RoutesScreen(),       // Index 2
    SettingsProfileScreen() // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: 'Parcels'),
          BottomNavigationBarItem(icon: Icon(Icons.directions), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: (_selectedIndex == 0 || _selectedIndex == 2)
        ? FloatingActionButton(
            onPressed: () => navigateTo(DeclareRouteScreen()),
            child: Icon(Icons.add_location),
            tooltip: 'Declare New Route',
          )
        : null,
    );
  }
}
```

**Screens**:
- Home: Dashboard with quick stats, active route, next parcels
- Parcels: List of pending/accepted parcels
- Routes: Declared routes management
- Settings: Profile, preferences, logout

---

### 6.2 Client App Bottom Navigation

**Update**: `client/lib/main.dart`

```dart
class ClientApp extends StatefulWidget {
  @override
  _ClientAppState createState() => _ClientAppState();
}

class _ClientAppState extends State<ClientApp> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    ClientDashboard(),     // Index 0
    ActiveDeliveries(),    // Index 1
    AccountSettings(),     // Index 2
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Deliveries'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Account'),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
        ? FloatingActionButton(
            onPressed: () => navigateTo(DeliveryCreationStep1()),
            child: Icon(Icons.add),
            tooltip: 'Create Delivery',
          )
        : null,
    );
  }
}
```

---

## 7. Admin Features Enhancement (PRIORITY: MEDIUM)

### 7.1 Conflict Resolution Screen

**Screen**: `admin/src/app/admin/disputes/page.tsx`
- List of flagged incidents:
  - Heuristic tracking violations (off-route)
  - Failed GPS gate verifications
  - Failed PIN attempts
  - Low rating complaints
  - Offline incidents
- Each incident shows:
  - Parcel ID, courier, sender, timestamp
  - Description of issue
  - GPS data (if available)
  - Evidence (photos, location logs)
  - Status (OPEN, INVESTIGATING, RESOLVED)
- Action buttons:
  - Approve delivery (override GPS gate)
  - Deny delivery (courier liable)
  - Request more info (from courier/client)
  - Auto-refund (if applicable)
  - Escalate (to higher authority)

---

## 8. Implementation Sequence Recommendation

**Phase 5A (Weeks 1-2)**: Auth & Profiles
1. Firestore backend integration
2. Courier multi-step signup
3. Client multi-step signup

**Phase 5B (Weeks 3-4)**: Delivery Creation
1. Delivery creation multi-step flow
2. Available couriers screen
3. Matching algorithm updates

**Phase 5C (Weeks 5-6)**: Route Management
1. Route declaration
2. Routes list & management
3. Active route management

**Phase 5D (Weeks 7-8)**: Advanced Tracking
1. Heuristic tracking system
2. Background location posting
3. ETA calculation model

**Phase 5E (Weeks 9-10)**: Polish & Testing
1. Navigation enhancements
2. Conflict resolution admin page
3. Integration testing

---

## 9. Success Criteria

- ✅ All auth flows working (signup, login, forgot password)
- ✅ Courier profile creation with all fields + images
- ✅ Delivery creation with multi-step flow
- ✅ Route declaration and management
- ✅ Real-time heuristic tracking operational
- ✅ ETA accuracy within ±5 minutes
- ✅ Background location posting continuously
- ✅ Matching algorithm matching >90% of parcels
- ✅ Admin conflict resolution functional
- ✅ Zero 404 errors in production
- ✅ API response time <500ms (p95)

---

*Document Version: 1.0*
*Last Updated: May 12, 2026*
*Status: Ready for Implementation*
