# Route Declaration Flow Refactoring - Complete

## Overview
The route declaration flow has been completely refactored to provide a cleaner, more intuitive user experience. Instead of a complex multi-step form, users now follow a linear flow: view routes → create new → select map → confirm details → activate/manage.

---

## New Flow Architecture

### 1. **Route Declaration Screen** (`route_declaration_screen.dart`)
**Purpose**: Main hub for viewing and managing routes

**Features**:
- Displays list of all declared routes with status badges (PLANNED, ACTIVE, COMPLETED, CANCELLED)
- Empty state with CTA when no routes exist
- Floating Action Button (FAB) to create new routes
- Pull-to-refresh routes list
- Quick action buttons: Activate, Complete, Cancel
- Status color coding:
  - Orange: PLANNED
  - Green: ACTIVE
  - Blue-Grey: COMPLETED
  - Red: CANCELLED

**State Management**:
- `_routes`: List of courier routes
- `_isLoading`: Loading state for initial fetch
- Auto-load routes on screen init

---

### 2. **Map Route Declaration Screen** (existing - unchanged)
**Purpose**: Interactive map where user draws/selects start and end points

**Returns**: Map object containing:
```dart
{
  'startPoint': LatLng,
  'endPoint': LatLng,
  'polyline': List<LatLng>  // All points along the route
}
```

---

### 3. **Route Details Screen** (NEW - `route_details_screen.dart`)
**Purpose**: Confirm route details and set operational parameters

**Displays** (Read-only):
- Start Point (coordinates from map)
- End Point (coordinates from map)
- Number of waypoints

**User Input Fields**:
1. **Planned Start Time** (Date + Time picker)
   - Default: next hour from now
   - Range: today to 30 days future
   - Required field

2. **Declared ETA** (minutes)
   - Numeric input
   - Default: 45 minutes
   - Validation: Must be > 0
   - Required field

3. **Allow Multiple Parcels** (Toggle)
   - Default: ON
   - Allows multiple parcels to be assigned to this route

4. **Notes** (Optional text area)
   - Up to 3 lines
   - For driver notes/special instructions

**Backend Operations on Submit**:
1. Creates corridor (route definition) via `postRouteDeclaration()`
   - Window times hardcoded to 00:00-23:59 (flexible)
   - Location strings derived from map coordinates
   
2. Uploads polyline via `postCorridorLine()`
   - Sends all waypoints from map
   
3. Creates courier route via `createCourierRoute()`
   - Links courier to corridor
   - Sets planned start time
   - Records declared ETA

**Success**: Returns `true` to route declaration screen, triggers refresh

---

## Backend Integration

### API Endpoints Used

**POST /couriers/routes**
- Creates a new courier route
- Body:
  ```json
  {
    "corridorId": "uuid",
    "plannedStartAt": "2024-05-19T10:30:00Z",
    "declaredEtaMinutes": 45
  }
  ```

**POST /corridors**
- Creates corridor (pre-existing endpoint)
- Body:
  ```json
  {
    "clientId": "uuid",
    "startLocation": "lat,lng",
    "endLocation": "lat,lng",
    "windowStart": "HH:MM",
    "windowEnd": "HH:MM",
    "allowMultipleParcels": true,
    "notes": "optional"
  }
  ```

**POST /corridors/:id/line**
- Uploads corridor polyline
- Body:
  ```json
  {
    "polyline": [
      { "lat": 17.8252, "lng": 31.0335 },
      ...
    ]
  }
  ```

**PATCH /couriers/routes/:routeId**
- Updates route status
- Body:
  ```json
  {
    "action": "activate|complete|cancel"
  }
  ```

**GET /couriers/routes**
- Fetches all routes for courier
- Returns: Array of route objects with id, status, planned_start_at, declared_eta_minutes

---

## Database Impact

### No Schema Changes Required
The existing schema supports all new functionality:

- `corridors` table: Already stores start_point, end_point, corridor_line (polyline)
- `routes` table: Already has planned_start_at, declared_eta_minutes, status
- `users` table: Already tracks current_route_id for state management

**Optional Future Enhancements**:
- Add `window_start`, `window_end` to routes table (currently in corridors)
- Add indexes on routes(courier_id, status) for faster queries

---

## UI/Theme Updates

### Dark Theme Application
Both screens use centralized theme from `lib/theme.dart`:

```dart
// Colors
dropCityOrangeAccent: #FF6B35
dropCityTextLight: #FFFFFF
dropCityTextGrey: #9CA3AF
dropCityInputBackground: #2A2A3E
dropCityInputBorder: #404050
dropCityBorderRadius: 12.0

// Button styling
ElevatedButton: Orange background with white text
OutlinedButton: Orange border with white text
TextFormField: Dark background with orange focused state
```

### Component Updates
- ✅ Route declaration screen: Dark theme with orange FAB
- ✅ Route details screen: Dark card, themed form inputs, orange button
- ✅ Status badges: Color-coded with rounded borders
- ✅ Route cards: Dark background (Colors.grey[900]) with clear typography hierarchy

---

## User Journey Example

1. **Landing**: User opens "My Routes" screen
   - Empty state shown → Tap FAB
   
2. **Map Selection**: Map screen appears
   - User draws route from point A to point B
   - Confirms → Map data returned
   
3. **Details Entry**: Route details screen shown
   - Start/End points displayed (read-only, greyed out)
   - Pick planned start time: "May 19, 2024 at 10:30 AM"
   - ETA: "45" minutes
   - Parcels toggle: ON
   - Notes: "Avoid main road construction"
   - Tap "Create Route"
   
4. **Backend Processing**:
   - Corridor created with map coordinates
   - Polyline uploaded
   - Route linked with ETA and start time
   
5. **Return**: Back to "My Routes" screen
   - New route appears in list with PLANNED status
   - User can now activate it by tapping "Activate"

---

## File Changes Summary

### New Files
- `courier/lib/screens/route_details_screen.dart` (260 lines)

### Modified Files
- `courier/lib/screens/route_declaration_screen.dart` (refactored from 469 → 258 lines)
  - Removed multi-step form logic
  - Focused on route list display
  - Integrated FAB navigation

### Unchanged Files
- `courier/lib/theme.dart` (dark theme colors - already updated)
- Backend API endpoints (existing functionality leveraged)
- Database schema (no changes needed)

---

## Testing Checklist

- [ ] Empty state shows correctly when no routes exist
- [ ] FAB navigates to map selection
- [ ] Map selection returns start/end points correctly
- [ ] Route details screen displays selected coordinates (read-only)
- [ ] Date/time picker shows correct range
- [ ] ETA validation rejects invalid values
- [ ] Multiple parcels toggle works
- [ ] Route creation successful with ETA and start time
- [ ] New route appears in list after creation
- [ ] Status badges display correct colors
- [ ] Activate button changes status to ACTIVE
- [ ] Complete button works when ACTIVE
- [ ] Cancel button works when PLANNED
- [ ] Theme colors consistent (orange accents, dark backgrounds)
- [ ] Loading state shown while fetching routes
- [ ] Error messages display on failures

---

## Future Enhancements

1. **Window Times**: Allow user to set pickup/dropoff windows separately
2. **Route Analytics**: Show estimated distance, duration before confirming
3. **Historical Routes**: Save and reuse previous routes
4. **Batch Declare**: Allow declaring multiple routes at once
5. **Route Sharing**: Share routes with other couriers
6. **Real-time Status**: WebSocket updates for route status changes
