# Route Declaration Flow - Visual Architecture

## Screen Navigation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                   ROUTE DECLARATION SCREEN                      │
│                      (route_declaration_screen.dart)            │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AppBar: "My Routes" with back button                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Route List (or empty state)                             │  │
│  │                                                          │  │
│  │  [Route Card #1]                                         │  │
│  │  ├─ Route ID & timestamp                                │  │
│  │  ├─ Status Badge (PLANNED/ACTIVE/etc)                   │  │
│  │  ├─ ETA: 45 min                                         │  │
│  │  └─ [Activate] [Complete] [Cancel]                     │  │
│  │                                                          │  │
│  │  [Route Card #2]                                         │  │
│  │  └─ ...                                                  │  │
│  │                                                          │  │
│  │  Empty State (if no routes):                            │  │
│  │  ├─ Icon: directions_run                               │  │
│  │  ├─ Text: "No routes declared yet"                      │  │
│  │  └─ Button: "Create Route"                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  FAB: Orange + icon                                      │  │
│  │  onPressed → Navigate to MapRouteDeclarationScreen      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ User taps FAB or "Create Route"
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│             MAP ROUTE DECLARATION SCREEN                        │
│          (map_route_declaration_screen.dart - existing)         │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Google Map with polyline drawing tools                  │  │
│  │                                                          │  │
│  │ User Action:                                            │  │
│  │ 1. Tap to set start point                               │  │
│  │ 2. Tap along route to draw waypoints                    │  │
│  │ 3. Tap to set end point                                 │  │
│  │ 4. Confirm selection                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Returns to route_declaration_screen with:                     │
│  {                                                              │
│    'startPoint': LatLng(-17.8252, 31.0335),                    │
│    'endPoint': LatLng(-17.8256, 31.0340),                      │
│    'polyline': [LatLng, LatLng, LatLng, ...]                  │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ route_details = await Navigator.push()
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│              ROUTE DETAILS SCREEN                               │
│             (route_details_screen.dart - NEW)                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AppBar: "Confirm Route Details"                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Route Summary Card (READ-ONLY)                          │  │
│  │                                                          │  │
│  │  📍 Start Point: -17.8252, 31.0335                      │  │
│  │  📍 End Point: -17.8256, 31.0340                        │  │
│  │  🛣️  Waypoints: 15 points                                │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Route Configuration (USER INPUT)                         │  │
│  │                                                          │  │
│  │  1. Planned Start Time *REQUIRED*                       │  │
│  │     [Pick] → Shows DatePicker + TimePicker              │  │
│  │     Default: Tomorrow at 10:00 AM                       │  │
│  │                                                          │  │
│  │  2. Declared ETA (minutes) *REQUIRED*                   │  │
│  │     [45]  (numeric input, validation: > 0)              │  │
│  │                                                          │  │
│  │  3. ⚙️ Accept Multiple Parcels (Toggle)                  │  │
│  │     [ON] (default)                                      │  │
│  │     "Allow multiple parcels on this route"              │  │
│  │                                                          │  │
│  │  4. Notes (Optional)                                    │  │
│  │     [Text area - 3 lines max]                           │  │
│  │     Placeholder: "Any additional details..."            │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Bottom Navigation Bar                                    │  │
│  │                                                          │  │
│  │  [Cancel]              [Create Route] 🟠                │  │
│  │                                                          │  │
│  │ Create Route button:                                    │  │
│  │ ├─ Disabled while submitting (shows spinner)            │  │
│  │ └─ Orange background (#FF6B35)                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Backend Operations on Submit:                                 │
│  ├─ POST /corridors (create corridor from map points)         │  │
│  ├─ POST /corridors/:id/line (upload polyline)                │  │
│  └─ POST /couriers/routes (create route with ETA & time)      │  │
│                                                                 │
│  Returns: true (success) to route_declaration_screen           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ if (routeDetails == true)
                              │   _loadRoutes() → Refresh list
                              │ else
                              │   stay on details screen
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│            Back to ROUTE DECLARATION SCREEN                     │
│                                                                 │
│  ✓ New route appears in list with PLANNED status              │
│  ✓ User can now Activate, Complete, or Cancel                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## State Flow Diagram

```
[Route Declaration Screen]
   ├─ _routes: List<Map>
   ├─ _isLoading: bool
   └─ Actions:
      ├─ _loadRoutes()           → Fetch from API
      ├─ _createNewRoute()       → Navigate to map
      └─ _updateRouteStatus()    → Activate/Complete/Cancel

                   ↓ (user taps FAB)

[Map Selection Screen]
   └─ Actions:
      └─ Return map data
      
                   ↓ (route data received)

[Route Details Screen]
   ├─ _plannedStartAt: DateTime?
   ├─ _etaController: TextEditingController
   ├─ _allowMultipleParcels: bool
   ├─ _notesController: TextEditingController
   ├─ _isSubmitting: bool
   └─ Actions:
      ├─ _pickPlannedStart()     → Date/Time picker
      └─ _submit()
         ├─ Validate inputs
         ├─ Create corridor
         ├─ Upload polyline
         ├─ Create route with ETA
         └─ Return true to parent

                   ↓ (success)

[Back to Route Declaration Screen]
   ├─ Reload _routes from API
   └─ Display updated list with new route
```

---

## Data Model

### Input: MapRouteDeclarationScreen Result
```dart
{
  'startPoint': LatLng,          // User-selected start
  'endPoint': LatLng,            // User-selected end
  'polyline': List<LatLng>       // All points along route
}
```

### Corridor Creation Payload
```dart
{
  'clientId': 'uuid',
  'startLocation': 'lat,lng',
  'endLocation': 'lat,lng',
  'windowStart': '00:00',
  'windowEnd': '23:59',
  'allowMultipleParcels': true,
  'notes': 'optional text'
}
```

### Route Creation Payload
```dart
{
  'corridorId': 'uuid',
  'plannedStartAt': 'ISO8601 timestamp',
  'declaredEtaMinutes': 45
}
```

### Route Object (from GET /couriers/routes)
```dart
{
  'id': 'uuid',
  'corridor_id': 'uuid',
  'courier_id': 'user_id',
  'start_point': 'geography',
  'end_point': 'geography',
  'planned_start_at': 'timestamp',
  'declared_eta_minutes': 45,
  'status': 'PLANNED|ACTIVE|COMPLETED|CANCELLED',
  'activated_at': 'timestamp',
  'completed_at': 'timestamp',
  'created_at': 'timestamp',
  'updated_at': 'timestamp'
}
```

---

## Error Handling

### Route Details Screen
```
User Action              → Error Case              → Recovery
├─ Pick Start Time       → Cancelled               → Retry pick
├─ Enter ETA            → Invalid (≤ 0)           → Show validation error
├─ Submit               → Network error            → Show snackbar + retry
│                       → API validation fail      → Show specific error
└─                      → Success                  → Pop screen + refresh list
```

---

## Theme Colors Used

```
Dark Theme (#FF6B35 Orange Accent):

AppBar:           Transparent background, white text
InputField:       #2A2A3E background, #404050 border
                  Orange (#FF6B35) on focus
Button:           Orange background, white text
FAB:              Orange background (#FF6B35)
CardBackground:   Colors.grey[900]
Text (Primary):   #FFFFFF (dropCityTextLight)
Text (Secondary): #9CA3AF (dropCityTextGrey)
Status Badges:    Color-coded (green/orange/red/grey)
```

---

## Summary: Key Improvements

✅ **Simplified Flow**: 4 screens reduced to 2 sequential screens  
✅ **Clear Separation**: Route management vs. route creation  
✅ **Read-Only Confirmation**: Users can't accidentally edit map selection  
✅ **Flexible Scheduling**: Pick exact date/time for route activation  
✅ **Dark Theme**: Consistent orange accent (#FF6B35) throughout  
✅ **Backend Aligned**: Uses existing endpoints, no schema changes needed  
✅ **Error Resilient**: Validation and error messages at each step  
✅ **UX Friendly**: Empty states, FAB, quick actions on route cards
