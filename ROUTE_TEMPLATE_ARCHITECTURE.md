# Route Template vs Corridor Architecture

## Overview

The courier app now distinguishes between **Route Templates** (reusable daily route definitions) and **Corridors** (operational instances created when a template is used).

---

## Terminology

### Route Template
- **What it is**: A saved, reusable route definition that a courier creates once and reuses multiple times daily
- **User visibility**: Fully visible in the "My Route Templates" screen
- **Status**: Always reusable (no ACTIVE/COMPLETED/CANCELLED states)
- **Lifetime**: Persists indefinitely until explicitly deleted
- **Key data**: Start location, end location, polyline, ETA, allowed parcel count, notes
- **Usage**: Courier clicks "Use This Route Template" to activate it

### Corridor
- **What it is**: An operational instance created each time a route template is used
- **User visibility**: Hidden from courier (operational detail)
- **Status**: Transitions through CREATED → ACTIVE → COMPLETED/CANCELLED
- **Lifetime**: Exists for the duration of one use (one day/shift)
- **Key data**: Unique ID, assigned courier, current parcels, geolocation tracking, delivery status
- **Backend role**: Used for parcel matching, vehicle tracking, and delivery coordination

---

## Data Flow

### Creating a Route Template

1. Courier opens "My Route Templates" → clicks "Create Route Template"
2. Courier selects start and end points on map and confirms polyline
3. In `RouteDetailsScreen`, courier enters:
   - Declared ETA (minutes)
   - Allow Multiple Parcels (toggle)
   - Optional notes
4. Clicking "Create Route Template" calls:
   ```
   ApiClient.createRouteTemplate(...)
   ```
   Backend creates: `route_templates` table entry with unique UUID
5. Route template immediately appears in list and can be reused

### Using a Route Template (Creating a Corridor)

1. Courier sees route template in list with "REUSABLE" badge
2. Courier clicks "Use This Route Template"
3. Date/time picker opens → courier selects start date and time
4. Confirmation dialog shows the start time
5. Clicking "Confirm & Use" calls:
   ```
   ApiClient.createCorridorFromTemplate(
     routeTemplateId: <template-id>,
     plannedStartAtIso: <selected-datetime>
   )
   ```
6. Backend creates: New `corridors` entry with:
   - Unique corridor UUID (different ID each time)
   - `route_template_id` reference (links to template)
   - `planned_start_at` set to selected time
   - Status: ACTIVE
7. Courier is notified "Corridor created" and can now use it

### Template Reuse Behavior

- **Before**: Courier creates route → uses it → completes it → cannot reuse (status = COMPLETED)
- **After**: Courier creates route template → uses it (creates corridor #1) → uses it again (creates corridor #2) → uses it again (creates corridor #3)
- Each use creates a NEW corridor with its own UUID
- Template itself never changes status

---

## Implementation Details

### Client-Side Changes

**route_declaration_screen.dart**:
- Displays route templates (not corridors)
- Cards show "REUSABLE" badge instead of status badges
- "Use This Route Template" button calls `createCorridorFromTemplate()`
- Removed activate/complete/cancel buttons (only for corridors)

**route_details_screen.dart**:
- Renamed "Complete Route" to reflect saving a template
- Calls `createRouteTemplate()` instead of `postRouteDeclaration()`
- No longer creates corridor directly; backend handles that when template is used

### API Methods Added

**ApiClient.createRouteTemplate()**:
- Endpoint: `POST /couriers/route-templates`
- Parameters: startLocation, endLocation, polylinePoints, allowMultipleParcels, declaredEtaMinutes, notes
- Returns: route_template_id
- Backend: Creates entry in `route_templates` table

**ApiClient.createCorridorFromTemplate()**:
- Endpoint: `POST /couriers/routes/from-template`
- Parameters: routeTemplateId, plannedStartAtIso
- Returns: corridorId (newly created corridor's UUID)
- Backend: Creates entry in `corridors` table with route_template_id reference

---

## Backend Requirements

### New Route Templates Table

```sql
CREATE TABLE route_templates (
  id UUID PRIMARY KEY,
  courier_id UUID NOT NULL REFERENCES users(id),
  start_location TEXT NOT NULL,
  end_location TEXT NOT NULL,
  polyline JSONB NOT NULL, -- Array of {lat, lng} points
  allow_multiple_parcels BOOLEAN DEFAULT true,
  declared_eta_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Corridor Modifications

```sql
ALTER TABLE corridors ADD COLUMN route_template_id UUID REFERENCES route_templates(id);
-- Existing corridors have route_template_id = NULL
```

### API Endpoints to Implement

**POST /couriers/route-templates**
- Create new route template
- Store all template data
- Return template UUID

**POST /couriers/routes/from-template**
- Accept routeTemplateId and plannedStartAtIso
- Create new corridor entry with template data + start time
- Perform polyline setup (like postCorridorLine did before)
- Return newly created corridorId

**GET /couriers/route-templates**
- Return all route templates for authenticated courier
- Include usage count (how many times used)
- Include last used date

---

## User Experience Flow

### Creating a Reusable Route

```
[Route Declaration Screen - Empty]
        ↓ (click + button)
[Map Selection Screen]
        ↓ (draw route)
[Route Details Screen - Enter ETA & options]
        ↓ (click "Create Route Template")
[Route Template Saved]
        ↓
[Route Templates List - Shows new template with REUSABLE badge]
```

### Using the Route Multiple Times

```
[Route Templates List - See "Template A" REUSABLE]
        ↓ (click "Use This Route Template")
[Date/Time Picker - Select when to start]
        ↓ (confirm)
[Corridor #1 Created & ACTIVE - Courier can now deliver]
        ↓ (next day, same template)
[Route Templates List - "Template A" still REUSABLE]
        ↓ (click "Use This Route Template" again)
[Date/Time Picker - Select new date/time]
        ↓ (confirm)
[Corridor #2 Created & ACTIVE - New independent corridor]
```

---

## Benefits

1. **Reusability**: Couriers don't recreate routes daily
2. **Operational Clarity**: Backend can track corridors independently (matching, tracking, completion)
3. **Hidden Complexity**: Courier sees friendly "Route Templates"; backend manages corridor instances
4. **Data Integrity**: Each corridor has its own complete lifecycle and tracking data
5. **Scalability**: Templates can be shared, cloned, or templated in future
6. **Better Analytics**: Track which templates are used most, how many parcels per corridor, etc.

---

## Testing Checklist

- [ ] Create a route template and verify it appears in list
- [ ] Use the same route template 3 times and verify 3 different corridors are created
- [ ] Verify template still shows as REUSABLE after multiple uses
- [ ] Verify each corridor use has different corridor ID
- [ ] Verify each use can have different start times
- [ ] Confirm parcels can be matched to corridors created from templates
- [ ] Verify client error handling if createCorridorFromTemplate fails
