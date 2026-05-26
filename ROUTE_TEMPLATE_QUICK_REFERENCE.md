# Quick Reference: Route Template vs Corridor

## Visual Architecture

```
┌─────────────────────────────────────────────────────────┐
│               COURIER APP (Client Side)                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  "My Route Templates" Screen                             │
│  ┌──────────────────────────────────┐                   │
│  │ Template A           [REUSABLE]   │ "Use This        │
│  │ ETA: 45 min          Badge        │  Route Template" │
│  ├──────────────────────────────────┤ Button (always)   │
│  │ Template B           [REUSABLE]   │                  │
│  │ ETA: 60 min          Badge        │ Use Same          │
│  └──────────────────────────────────┘ Template 3x       │
│                                                           │
│  When User Clicks "Use This Route Template":             │
│  1. Pick date/time                                       │
│  2. Confirm                                              │
│  3. Call: createCorridorFromTemplate()                   │
│                                                           │
└─────────────────────────────────────────────────────────┘
                           ↓
        ┌────────────────────────────────────┐
        │  BACKEND (Not Yet Implemented)      │
        ├────────────────────────────────────┤
        │                                    │
        │ POST /couriers/routes/from-template│
        │                                    │
        │ Input: routeTemplateId + start time│
        │ Output: Create new corridor UUID   │
        │                                    │
        └────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│                    DATABASE                              │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  route_templates (reusable definitions)                  │
│  ┌──────────────────────────────────────────────────┐   │
│  │ id: uuid-1         courier_id: xxx              │   │
│  │ start: lat1, lng1  end: lat2, lng2              │   │
│  │ polyline: [...]    eta_minutes: 45              │   │
│  ├──────────────────────────────────────────────────┤   │
│  │ id: uuid-2         courier_id: xxx              │   │
│  │ start: lat3, lng3  end: lat4, lng4              │   │
│  │ polyline: [...]    eta_minutes: 60              │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  corridors (operational instances)                       │
│  ┌──────────────────────────────────────────────────┐   │
│  │ id: corr-uuid-1   route_template_id: uuid-1     │   │
│  │ status: ACTIVE    planned_start_at: 2026-05-27  │   │
│  │ assigned_courier: xxx                           │   │
│  ├──────────────────────────────────────────────────┤   │
│  │ id: corr-uuid-2   route_template_id: uuid-1     │   │
│  │ status: ACTIVE    planned_start_at: 2026-05-28  │   │
│  │ assigned_courier: yyy                           │   │
│  ├──────────────────────────────────────────────────┤   │
│  │ id: corr-uuid-3   route_template_id: uuid-1     │   │
│  │ status: COMPLETED planned_start_at: 2026-05-29  │   │
│  │ assigned_courier: zzz                           │   │
│  └──────────────────────────────────────────────────┘   │
│                                                           │
│  Each time "Use" is clicked:                             │
│  → New corridor created with same route_template_id     │
│  → But different corridor UUID                          │
│  → Can have different planned start time                │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Before vs After

### BEFORE (Broken)
```
Courier creates "Route" → Status = PLANNED
         ↓
Courier uses route → Status = ACTIVE
         ↓
Courier completes → Status = COMPLETED ❌ CANNOT REUSE
```

### AFTER (Fixed)
```
Courier creates "Route Template" → Always REUSABLE
         ↓
Courier clicks "Use" → Creates Corridor #1 (ACTIVE)
         ↓
Corridor #1 completes → Status = COMPLETED (But Template unchanged!)
         ↓
Courier clicks "Use" again → Creates Corridor #2 (ACTIVE) ✅ NEW INSTANCE
         ↓
Courier clicks "Use" again → Creates Corridor #3 (ACTIVE) ✅ STILL REUSABLE
```

## Key API Changes

### OLD (Removed)
```dart
// Create corridor directly (one-time use)
postRouteDeclaration(...) → returns corridorId

// Then use that same corridor
updateCourierRouteStatus(id, "activate")
updateCourierRouteStatus(id, "complete") // Can't reuse
```

### NEW (Added)
```dart
// Create reusable template
createRouteTemplate(...) → returns templateId

// Each use creates new corridor
createCorridorFromTemplate(templateId, startTime) → returns new corridorId
createCorridorFromTemplate(templateId, startTime) → returns new corridorId ✅
createCorridorFromTemplate(templateId, startTime) → returns new corridorId ✅
```

## Files Changed Summary

| File | Change | Lines |
|------|--------|-------|
| route_declaration_screen.dart | Removed status management, updated UI | ~80 |
| route_details_screen.dart | Changed to createRouteTemplate | ~40 |
| api_client.dart | Added 2 new methods | +80 |
| DROPCITY_SOURCE_OF_TRUTH.md | Documented architecture change | +20 |
| ROUTE_TEMPLATE_ARCHITECTURE.md | Full specification | NEW |
| ROUTE_TEMPLATE_IMPLEMENTATION_May26.md | Implementation guide | NEW |

## Status of Implementation

### ✅ COMPLETE (Client Side)
- UI updated to show route templates
- API methods added to ApiClient
- No compile errors
- Flow logic implemented

### ⏳ PENDING (Backend)
- POST /couriers/route-templates endpoint
- POST /couriers/routes/from-template endpoint
- route_templates database table
- Database schema migration

### ⏳ PENDING (Testing)
- End-to-end integration tests
- Create template → use multiple times verification
- Backward compatibility verification
- Error handling tests

## What Courier Sees (User Experience)

### Screen 1: My Route Templates
```
────────────────────────────────
  My Route Templates        [+]
────────────────────────────────
│ Template: Downtown Route    │
│ Status: [REUSABLE]          │
│ ETA: 45 minutes             │
│ [Use This Route Template]   │
────────────────────────────────
│ Template: Suburbs Route     │
│ Status: [REUSABLE]          │
│ ETA: 60 minutes             │
│ [Use This Route Template]   │
────────────────────────────────
```

### Screen 2: Use Template (Date/Time Picker)
```
────────────────────────────────
  Use This Route Template
────────────────────────────────
  Select date: [2026-05-27]
  Select time: [09:00 AM]
  
  A new corridor will be created
  from this template
  
  [Cancel] [Confirm & Use]
────────────────────────────────
```

### Result
```
✅ Corridor created for May 27 at 09:00
   (Independent operation)
   
✅ Template still REUSABLE for next day
   (Can use again with different time)
```

## Key Concepts for Documentation

1. **Template is permanent** - Never changes status
2. **Corridor is temporary** - Goes through lifecycle
3. **Multiple corridors from one template** - Each use creates new
4. **Couriers don't see corridors** - Only see templates
5. **Backend tracks corridors** - For matching/tracking/delivery
6. **Each use gets unique ID** - Different corridor UUID each time

## Testing Scenario

**Scenario**: Courier has a daily "Downtown Morning Route"

**Monday**:
1. Create route template "Downtown Morning"
2. Click "Use" → Pick May 27, 9:00 AM
3. System creates Corridor-001, starts delivery
4. Complete deliveries → Corridor-001 status = COMPLETED

**Tuesday**:
1. See "Downtown Morning" template (still REUSABLE!) ✅
2. Click "Use" → Pick May 28, 9:00 AM  
3. System creates Corridor-002 (NEW instance), starts delivery
4. Complete deliveries → Corridor-002 status = COMPLETED

**Wednesday**:
1. See "Downtown Morning" template (still REUSABLE!) ✅
2. Click "Use" → Pick May 29, 9:00 AM
3. System creates Corridor-003 (NEW instance), starts delivery
4. Complete deliveries → Corridor-003 status = COMPLETED

**Result**: Template used 3 times, 3 independent corridors created, all completed, template still available.
