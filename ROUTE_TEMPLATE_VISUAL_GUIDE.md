# Route Template Architecture - Visual Guide

## The Problem (Before)

```
COURIER'S MENTAL MODEL:
┌────────────────────────────────────────┐
│ I created a route called "Downtown"    │
│ I used it Monday - worked great!       │
│ I completed it - delivery done         │
│ Can I use it again Tuesday? ❌ NO!     │
│ It says "COMPLETED" - can't click it   │
└────────────────────────────────────────┘

WHY THIS IS BAD:
- Must recreate same route every day
- Wastes time and effort
- Error-prone (might miss waypoints)
- No sense of reusability
```

## The Solution (After)

```
COURIER'S MENTAL MODEL:
┌────────────────────────────────────────┐
│ I created a route template: "Downtown" │
│ It shows [REUSABLE]                    │
│ Used it Monday → delivered             │
│ Can I use it again Tuesday?            │
│ YES! ✅ It still says [REUSABLE]       │
│ Used it Tuesday → delivered again      │
│ Can I use it Wednesday?                │
│ YES! ✅ Still [REUSABLE]               │
└────────────────────────────────────────┘

WHY THIS IS GOOD:
- Create once, reuse forever
- Same route shape and stops
- Different deliveries each day
- No need to recreate
- Always available
```

## Technical Architecture

```
                    CLIENT SIDE
                    (Courier App)
┌──────────────────────────────────────────┐
│                                          │
│  "My Route Templates" Screen             │
│  ┌──────────────────────────────────┐   │
│  │ Downtown Route      [REUSABLE] ✅ │   │
│  │ ETA: 45 min                      │   │
│  │ [Use This Route Template]  ←──┐  │   │
│  └──────────────────────────────┼──┘   │
│                                  │      │
│  Suburbs Route      [REUSABLE] ✅ │      │
│  ETA: 60 min                      │      │
│  [Use This Route Template]        │      │
│                                  │      │
└──────────────────────────────────┼──────┘
                                   │
                    When Clicked: Call createCorridorFromTemplate(templateId, time)
                                   │
                                   ↓
                    BACKEND SIDE
                    (Server/Database)
┌──────────────────────────────────────────┐
│                                          │
│  POST /couriers/routes/from-template     │
│                                          │
│  Input:  template_id: uuid-1            │
│          start_time: 2026-05-27 09:00   │
│                                          │
│  Process:                                │
│  1. Find template record                │
│  2. Create NEW corridor record          │
│  3. Set start time                      │
│  4. Return corridor_id                  │
│                                          │
│  Output: corridor_id: corr-uuid-1       │
│                                          │
└──────────────────────────────────────────┘
           ↓
┌──────────────────────────────────────────┐
│      DATABASE (PostgreSQL)               │
├──────────────────────────────────────────┤
│                                          │
│  route_templates TABLE                   │
│  ┌──────────────────────────────────┐   │
│  │ id: uuid-1                       │   │
│  │ courier_id: xxx                  │   │
│  │ start: 40.712, -74.006           │   │
│  │ end: 40.750, -73.997             │   │
│  │ polyline: [...]                  │   │
│  │ eta_minutes: 45                  │   │
│  │ notes: "downtown morning"        │   │
│  │ created: 2026-05-26              │   │
│  └──────────────────────────────────┘   │
│                                          │
│  corridors TABLE                         │
│  ┌──────────────────────────────────┐   │
│  │ id: corr-uuid-1                  │   │
│  │ route_template_id: uuid-1 ← LINK│   │
│  │ courier_id: xxx                  │   │
│  │ status: ACTIVE                   │   │
│  │ start: 40.712, -74.006           │   │
│  │ end: 40.750, -73.997             │   │
│  │ planned_start: 2026-05-27 09:00  │   │
│  ├──────────────────────────────────┤   │
│  │ id: corr-uuid-2 (NEW!)           │   │
│  │ route_template_id: uuid-1 ← SAME │   │
│  │ courier_id: xxx                  │   │
│  │ status: ACTIVE                   │   │
│  │ start: 40.712, -74.006           │   │
│  │ end: 40.750, -73.997             │   │
│  │ planned_start: 2026-05-28 09:00  │   │
│  │ (Different date, different ID!)  │   │
│  ├──────────────────────────────────┤   │
│  │ id: corr-uuid-3 (NEW!)           │   │
│  │ route_template_id: uuid-1 ← SAME │   │
│  │ courier_id: xxx                  │   │
│  │ status: COMPLETED                │   │
│  │ start: 40.712, -74.006           │   │
│  │ end: 40.750, -73.997             │   │
│  │ planned_start: 2026-05-29 09:00  │   │
│  │ (3 corridors from 1 template!)   │   │
│  └──────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘
```

## Data Flow: Create and Use Template

```
Step 1: CREATE ROUTE TEMPLATE
═══════════════════════════════════════════

Client Action:
  [Courier clicks "Create Route Template"]
  → Draws route on map
  → Enters ETA and notes
  → Clicks "Create Route Template"
  
API Call:
  POST /couriers/route-templates
  {
    startLocation: "40.712,-74.006",
    endLocation: "40.750,-73.997",
    polylinePoints: [...],
    declaredEtaMinutes: 45,
    notes: "Downtown morning route"
  }

Backend Processing:
  1. Validate input
  2. Insert into route_templates table
  3. Generate UUID: template-uuid-1
  4. Return template ID

Database Result:
  route_templates.id = template-uuid-1
  
Client Result:
  ✅ "Route Template Created!"
  Template now appears in "My Route Templates" with [REUSABLE]


Step 2: USE ROUTE TEMPLATE (First Time)
═══════════════════════════════════════════

Client Action:
  [Courier sees template "Downtown Route"]
  [Clicks "Use This Route Template"]
  → Picks date: 2026-05-27
  → Picks time: 09:00 AM
  → Clicks "Confirm & Use"

API Call:
  POST /couriers/routes/from-template
  {
    routeTemplateId: "template-uuid-1",
    plannedStartAt: "2026-05-27T09:00:00Z"
  }

Backend Processing:
  1. Retrieve template by ID
  2. Create new corridor record with:
     - route_template_id: template-uuid-1
     - start_location: (from template)
     - end_location: (from template)
     - planned_start_at: 2026-05-27 09:00
     - status: ACTIVE
  3. Generate UUID: corridor-uuid-1
  4. Return corridor ID

Database Result:
  corridors.id = corridor-uuid-1
  corridors.route_template_id = template-uuid-1
  corridors.status = ACTIVE

Client Result:
  ✅ "Corridor created for May 27, 09:00"
  Courier starts delivery operations


Step 3: USE ROUTE TEMPLATE (Second Time)
═══════════════════════════════════════════

Next Day...

Client Action:
  [Courier checks "My Route Templates"]
  [Template still shows [REUSABLE]] ← KEY POINT
  [Clicks "Use This Route Template" again]
  → Picks date: 2026-05-28
  → Picks time: 09:00 AM
  → Clicks "Confirm & Use"

API Call:
  POST /couriers/routes/from-template
  {
    routeTemplateId: "template-uuid-1", ← SAME TEMPLATE
    plannedStartAt: "2026-05-28T09:00:00Z" ← DIFFERENT TIME
  }

Backend Processing:
  1. Retrieve template by ID (same as before)
  2. Create NEW corridor record with:
     - route_template_id: template-uuid-1 (SAME)
     - status: ACTIVE
     - planned_start_at: 2026-05-28 09:00 (DIFFERENT)
  3. Generate UUID: corridor-uuid-2 ← DIFFERENT!
  4. Return corridor ID

Database Result:
  corridors.id = corridor-uuid-2 ← NEW UUID
  corridors.route_template_id = template-uuid-1 (same template)
  corridors.status = ACTIVE

Client Result:
  ✅ "Corridor created for May 28, 09:00"
  Courier starts delivery operations (independent from May 27)

KEY INSIGHT:
  ✓ Same template (uuid-1)
  ✓ Different corridors (uuid-1 vs uuid-2)
  ✓ Different dates/times
  ✓ Template remains REUSABLE


Step 4: USE ROUTE TEMPLATE (Third Time)
═══════════════════════════════════════════

And again the next day...

[Same process repeats]

Result:
  corridors.id = corridor-uuid-3 ← ANOTHER NEW UUID
  corridors.route_template_id = template-uuid-1 (STILL same)
  corridors.status = ACTIVE
  
Template still shows [REUSABLE] ← ALWAYS AVAILABLE
```

## Database State Example

```
AFTER 3 USES OF SAME TEMPLATE:

route_templates TABLE:
┌─────────────┬──────────────────────────────────────┐
│ id          │ template-uuid-1                      │
│ courier_id  │ courier-xxx                          │
│ start       │ 40.712, -74.006                      │
│ end         │ 40.750, -73.997                      │
│ polyline    │ [array of points]                    │
│ eta_minutes │ 45                                   │
│ notes       │ Downtown morning route               │
│ created     │ 2026-05-26 14:30:00                  │
└─────────────┴──────────────────────────────────────┘

corridors TABLE:
┌──────────────┬──────────────────┬───────────────┐
│ id           │ status           │ planned_start │
├──────────────┼──────────────────┼───────────────┤
│ corridor-1   │ COMPLETED        │ 2026-05-27    │
│ corridor-2   │ ACTIVE           │ 2026-05-28    │
│ corridor-3   │ ACTIVE           │ 2026-05-29    │
└──────────────┴──────────────────┴───────────────┘

All 3 corridors have:
route_template_id = template-uuid-1
courier_id = courier-xxx

RELATIONSHIP:
  template-uuid-1
       ├─→ corridor-1 (May 27, status: COMPLETED)
       ├─→ corridor-2 (May 28, status: ACTIVE)
       └─→ corridor-3 (May 29, status: ACTIVE)

COURIER'S VIEW:
  [1 Template] marked [REUSABLE]
  
BACKEND'S VIEW:
  [3 Corridors] linked to 1 template
```

## State Transitions

```
ROUTE TEMPLATE STATE:
┌─────────────────────┐
│     REUSABLE        │ ← Always here
│  (Forever, unless   │   (No transitions)
│   explicitly deleted)│
└─────────────────────┘

CORRIDOR STATE (Created from template):
Start
  ↓
┌─────────────┐
│   ACTIVE    │ ← Courier making deliveries
└──────┬──────┘
       ↓ (Parcels delivered or abandoned)
  ┌────────────────────┐
  │    COMPLETED   or  │
  │    CANCELLED       │
  └────────────────────┘
       ↓
      End

Multiple Corridors from Same Template:
┌──────────────────────────────────┐
│ Template: Always [REUSABLE]      │
│                                  │
│ ├─ Corridor 1: COMPLETED        │
│ │  May 27: Deliveries done      │
│ │                                │
│ ├─ Corridor 2: ACTIVE           │
│ │  May 28: Currently delivering │
│ │                                │
│ └─ Corridor 3: ACTIVE           │
│    May 29: Starting tomorrow    │
│                                  │
│ Each corridor is independent    │
│ Template remains available for  │
│ unlimited future use!           │
└──────────────────────────────────┘
```

## API Methods Added

```
NEW METHOD 1: createRouteTemplate()
─────────────────────────────────────
Purpose:   Create reusable route template
Endpoint:  POST /couriers/route-templates
Input:     startLocation, endLocation, polylinePoints,
           allowMultipleParcels, declaredEtaMinutes, notes
Output:    template_id (UUID)
Result:    Template stored, returns immediately
           Ready to use unlimited times

NEW METHOD 2: createCorridorFromTemplate()
──────────────────────────────────────────
Purpose:   Use route template to create operational corridor
Endpoint:  POST /couriers/routes/from-template
Input:     routeTemplateId, plannedStartAtIso
Output:    corridor_id (UUID)
Result:    New corridor created, independent instance
           Can call again with different time
           Returns different corridor_id each time
```

## Key Differences: Before vs After

```
BEFORE (Broken Model):
┌─────────────────────────────────────┐
│ Create route → Use → Complete       │
│ If you want to use again:           │
│ ❌ Can't - status is COMPLETED      │
│ ❌ Must create new route again      │
│ ❌ Route gets "locked" after use    │
└─────────────────────────────────────┘

AFTER (Fixed Model):
┌─────────────────────────────────────┐
│ Create template → Use → Complete    │
│ If you want to use again:           │
│ ✅ Template is still [REUSABLE]     │
│ ✅ Click "Use" with different time  │
│ ✅ Creates new corridor instance    │
│ ✅ Template never gets locked       │
│ ✅ Can reuse unlimited times        │
└─────────────────────────────────────┘
```

## Summary: What Changed

```
TERMINOLOGY:
  Routes (Old) → Route Templates (New) = Reusable definitions
  Corridors (Old) → Corridors (New) = Operational instances

BEHAVIOR:
  One-time use → Unlimited reuse = Core improvement

DATABASE:
  No route templates table (Old) → New table for templates = Better data model

API:
  Direct corridor creation (Old) → Template-based creation (New) = Cleaner flow

USER EXPERIENCE:
  "Can't reuse" (Old) → "Always reusable" (New) = Solves the problem
```
