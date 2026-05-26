# Backend API Specification: Route Templates

## Overview
Two new endpoints required to complete the Route Template architecture on the backend.

---

## Endpoint 1: Create Route Template

### Request
```http
POST /couriers/route-templates
Content-Type: application/json
Authorization: Bearer {idToken}

{
  "startLocation": "40.7128,-74.0060",
  "endLocation": "40.7505,-73.9972",
  "polylinePoints": [
    {"lat": 40.7128, "lng": -74.0060},
    {"lat": 40.7200, "lng": -73.9900},
    {"lat": 40.7505, "lng": -73.9972}
  ],
  "allowMultipleParcels": true,
  "declaredEtaMinutes": 45,
  "notes": "Downtown morning route - avoid rush hour traffic"
}
```

### Response (Success)
```http
200 OK
Content-Type: application/json

{
  "id": "template-uuid-1234"
}
```

### Response (Error - Invalid Input)
```http
400 Bad Request
Content-Type: application/json

{
  "error": "Invalid startLocation format",
  "details": "Expected lat,lng format"
}
```

### Response (Error - Auth)
```http
401 Unauthorized
Content-Type: application/json

{
  "error": "Missing or invalid authentication"
}
```

### Validation Rules
- `startLocation`: Required, format "lat,lng", valid coordinates
- `endLocation`: Required, format "lat,lng", valid coordinates  
- `polylinePoints`: Required, array of {lat, lng}, at least 2 points
- `allowMultipleParcels`: Boolean, optional (default: true)
- `declaredEtaMinutes`: Required, integer > 0
- `notes`: String, optional, max 500 characters

### Database Action
```sql
INSERT INTO route_templates (
  id,
  courier_id,
  start_location,
  end_location,
  polyline,
  allow_multiple_parcels,
  declared_eta_minutes,
  notes,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  (SELECT id FROM users WHERE auth_uid = $1),
  $2,
  $3,
  $4::jsonb,
  $5,
  $6,
  $7,
  NOW(),
  NOW()
);
```

---

## Endpoint 2: Create Corridor from Template

### Request
```http
POST /couriers/routes/from-template
Content-Type: application/json
Authorization: Bearer {idToken}

{
  "routeTemplateId": "template-uuid-1234",
  "plannedStartAt": "2026-05-27T09:00:00Z"
}
```

### Response (Success)
```http
200 OK
Content-Type: application/json

{
  "corridorId": "corridor-uuid-5678"
}
```

### Response (Error - Template Not Found)
```http
404 Not Found
Content-Type: application/json

{
  "error": "Route template not found",
  "templateId": "template-uuid-1234"
}
```

### Response (Error - Auth)
```http
401 Unauthorized
Content-Type: application/json

{
  "error": "Missing or invalid authentication"
}
```

### Validation Rules
- `routeTemplateId`: Required, UUID format, must exist and belong to authenticated courier
- `plannedStartAt`: Required, ISO 8601 format, must be in future

### Database Actions

```sql
-- Step 1: Retrieve template
SELECT * FROM route_templates 
WHERE id = $1 AND courier_id = $2;

-- Step 2: Create corridor from template
INSERT INTO corridors (
  id,
  courier_id,
  route_template_id,
  start_location,
  end_location,
  planned_start_at,
  window_start,
  window_end,
  allow_multiple_parcels,
  declared_eta_minutes,
  notes,
  status,
  created_at,
  updated_at
) VALUES (
  gen_random_uuid(),
  $1,
  $2,
  $3,
  $4,
  $5,
  '00:00',
  '23:59',
  $6,
  $7,
  $8,
  'ACTIVE',
  NOW(),
  NOW()
);

-- Step 3: Upload polyline (same as existing postCorridorLine logic)
UPDATE corridors 
SET corridor_line = ST_GeomFromGeoJSON($1)
WHERE id = $2;
```

---

## Database Schema

### New Table: route_templates
```sql
CREATE TABLE route_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_location TEXT NOT NULL,
  end_location TEXT NOT NULL,
  polyline JSONB NOT NULL,
  allow_multiple_parcels BOOLEAN DEFAULT true,
  declared_eta_minutes INTEGER NOT NULL CHECK (declared_eta_minutes > 0),
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_route_templates_courier_id ON route_templates(courier_id);
CREATE INDEX idx_route_templates_created_at ON route_templates(created_at);
```

### Existing Table: corridors (MODIFY)
```sql
-- Add column to track which template created this corridor (optional but useful)
ALTER TABLE corridors 
ADD COLUMN route_template_id UUID REFERENCES route_templates(id) ON DELETE SET NULL;

CREATE INDEX idx_corridors_route_template_id ON corridors(route_template_id);
```

---

## Migration Script Example

```sql
-- File: backend/sql/025_route_templates.sql

-- Create route_templates table
CREATE TABLE route_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  start_location TEXT NOT NULL,
  end_location TEXT NOT NULL,
  polyline JSONB NOT NULL,
  allow_multiple_parcels BOOLEAN DEFAULT true,
  declared_eta_minutes INTEGER NOT NULL CHECK (declared_eta_minutes > 0),
  notes TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_route_templates_courier_id ON route_templates(courier_id);
CREATE INDEX idx_route_templates_created_at ON route_templates(created_at);

-- Add route_template_id to corridors
ALTER TABLE corridors 
ADD COLUMN route_template_id UUID REFERENCES route_templates(id) ON DELETE SET NULL;

CREATE INDEX idx_corridors_route_template_id ON corridors(route_template_id);

-- Grant permissions (if using row-level security)
ALTER TABLE route_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY route_templates_own_only ON route_templates
  USING (courier_id = auth.uid())
  WITH CHECK (courier_id = auth.uid());
```

---

## Implementation Notes

### Error Handling
- All endpoints should validate auth token first
- Return 401 for missing/invalid token
- Return 400 for validation errors with details
- Return 404 for not found errors
- Return 500 for server errors with request ID

### Authentication
- Verify bearer token is valid Firebase ID token
- Extract `auth_uid` from token claims
- Match `auth_uid` to `users.auth_uid` to get `user.id`
- All operations scoped to authenticated courier's ID

### Response Format
- All responses include request ID in header: `x-request-id`
- Success responses: 200 with JSON body
- Error responses: appropriate status code with error details

### Idempotency
- Not required for these endpoints (create operations are not idempotent by design)
- Each request creates new instances

### Rate Limiting
- Recommend limiting template creation: 100/hour per user
- Recommend limiting corridor creation from template: 500/hour per user

### Logging
- Log all template creates with courier_id
- Log all corridor creates with template_id and courier_id
- Include in audit trail for compliance

---

## Testing Scenarios

### Scenario 1: Normal Flow
```
1. POST /couriers/route-templates
   Response: template-uuid-1

2. POST /couriers/routes/from-template
   Request: template-uuid-1, 2026-05-27T09:00:00Z
   Response: corridor-uuid-1

3. POST /couriers/routes/from-template
   Request: template-uuid-1, 2026-05-28T09:00:00Z
   Response: corridor-uuid-2 (different from uuid-1)

Expected: Two different corridors created from same template
```

### Scenario 2: Auth Failure
```
1. POST /couriers/route-templates
   No Authorization header
   Response: 401 Unauthorized
```

### Scenario 3: Invalid Template ID
```
1. POST /couriers/routes/from-template
   Request: invalid-uuid, 2026-05-27T09:00:00Z
   Response: 404 Not Found
```

### Scenario 4: Invalid Start Time
```
1. POST /couriers/routes/from-template
   Request: template-uuid-1, 2020-05-27T09:00:00Z (past date)
   Response: 400 Bad Request - "plannedStartAt must be in future"
```

### Scenario 5: Valid Reuse
```
1. Create template A
2. Use template A at 09:00 → Corridor 1 created
3. Corridor 1 completes (status = COMPLETED)
4. Use template A at 09:00 next day → Corridor 2 created (NEW UUID)
5. Both corridors can match parcels independently

Expected: Template remains reusable, multiple independent corridors
```

---

## Integration Points

### Parcel Matching Service
- Matches parcels to `corridors` table as before
- Corridor can be matched whether from template or direct creation
- No changes needed to matching logic

### Tracking Service
- Tracks `corridors` by ID as before
- Each corridor has independent lifecycle
- No changes needed to tracking logic

### Courier Route Management
- `GET /couriers/routes` returns corridors (as before)
- New endpoint `GET /couriers/route-templates` for templates
- Consider: Should we return both routes and templates, or separate?

---

## Implementation Checklist for Backend Team

- [ ] Create route_templates table
- [ ] Add route_template_id column to corridors
- [ ] Implement POST /couriers/route-templates endpoint
- [ ] Implement POST /couriers/routes/from-template endpoint
- [ ] Add auth/validation/error handling
- [ ] Add logging/audit trail
- [ ] Test with provided scenarios
- [ ] Update API documentation
- [ ] Test integration with parcel matching
- [ ] Test integration with tracking service
- [ ] Performance test (load testing recommended)
- [ ] Deploy to staging for UAT

---

## Questions for Backend Team

1. Should we also implement `GET /couriers/route-templates` to list templates?
2. Should we implement `DELETE /couriers/route-templates/:id` to delete templates?
3. Should we implement `PUT /couriers/route-templates/:id` to edit templates?
4. Should we track "times used" metric on templates?
5. Should template deletion cascade to corridors, or set route_template_id to NULL?
6. What rate limits should we apply?
7. Should we add soft-delete to templates for audit trail?
8. Should templates be shareable between couriers?

---

## Reference: Client-Side API Calls

### Call 1: Create Template
```dart
Future<String> createRouteTemplate({
  required String startLocation,
  required String endLocation,
  required List<dynamic> polylinePoints,
  required bool allowMultipleParcels,
  required int declaredEtaMinutes,
  String? notes,
}) async {
  final uri = Uri.parse("$baseUrl/couriers/route-templates");
  final payload = {
    "startLocation": startLocation,
    "endLocation": endLocation,
    "polylinePoints": polylinePoints,
    "allowMultipleParcels": allowMultipleParcels,
    "declaredEtaMinutes": declaredEtaMinutes,
    "notes": notes ?? "",
  };
  
  final response = await _client.post(
    uri,
    headers: _headers(),
    body: jsonEncode(payload),
  );
  
  if (response.statusCode >= 400) {
    throw Exception("Failed to create route template: ${response.body}");
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
  final id = decoded?["id"] as String?;
  if (id == null || id.isEmpty) {
    throw Exception("Backend did not return route template id.");
  }
  return id;
}
```

### Call 2: Use Template
```dart
Future<String> createCorridorFromTemplate({
  required String routeTemplateId,
  required String plannedStartAtIso,
}) async {
  final uri = Uri.parse("$baseUrl/couriers/routes/from-template");
  final payload = {
    "routeTemplateId": routeTemplateId,
    "plannedStartAt": plannedStartAtIso,
  };
  
  final response = await _client.post(
    uri,
    headers: _headers(),
    body: jsonEncode(payload),
  );
  
  if (response.statusCode >= 400) {
    throw Exception("Failed to create corridor from template: ${response.body}");
  }
  final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
  final corridorId = decoded?["corridorId"] as String?;
  if (corridorId == null || corridorId.isEmpty) {
    throw Exception("Backend did not return corridor id.");
  }
  return corridorId;
}
```

---

## Success Criteria

✅ Both endpoints implemented and tested  
✅ Database schema created and migrated  
✅ Auth/validation working correctly  
✅ Error handling returning proper status codes  
✅ Integration tests with parcel matching passing  
✅ Integration tests with tracking service passing  
✅ End-to-end flow works: create template → use → use again  
✅ Different corridor IDs returned for each use  
✅ Backward compatible with existing routes/corridors  

