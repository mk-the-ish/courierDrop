# DropCity API Technical Manual

Last updated: May 27, 2026  
API owner: DropCity backend (`backend/src`)

## 1. Overview
DropCity exposes a REST API for:
- authentication (Firebase/Supabase-backed)
- user profile/onboarding
- courier route templates and corridor operations
- parcel lifecycle (create, assign, accept/decline, tracking, handshakes)
- notifications
- admin operations and conflict resolution

Default production base URL used by mobile apps:
- `https://dropcity-backend.onrender.com`

## 2. Authentication Protocol

## 2.1 Token type
Send Firebase ID token (mobile) or Supabase access token (admin) as bearer:

```http
Authorization: Bearer <token>
```

Middleware behavior (`backend/src/middleware/auth.js`):
- verifies Firebase token first
- falls back to Supabase token verification
- resolves role from token claims or `users` table fallback

## 2.2 Role gates
Role-protected routes return:
- `403 AUTH_ROLE_REQUIRED` (no role)
- `403 AUTH_ROLE_FORBIDDEN` (wrong role)

## 2.3 Common auth errors
- `401 AUTH_MISSING_TOKEN`
- `401 AUTH_INVALID_TOKEN`
- `401 AUTH_ERROR`
- `401 AUTH_REQUIRED`

## 3. Response Envelope Convention

Most JSON responses are wrapped with `requestId` by server middleware:

```json
{
  "requestId": "uuid",
  "...": "payload fields"
}
```

Errors:

```json
{
  "requestId": "uuid",
  "error": "Human message",
  "code": "MACHINE_CODE"
}
```

## 4. Endpoint Groups

Mounted route groups (`backend/src/index.js`):
- `/health`
- `/auth`
- `/users`
- `/vehicles`
- `/corridors`
- `/parcels`
- `/matches`
- `/handshake`
- `/heartbeat`
- `/logs`
- `/admin`
- `/devices`
- `/couriers`
- `/tracking`
- `/notifications`

---

## 5. Authentication Endpoints

Base: `/auth`

Core flows:
- `POST /auth/signup`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/signup/courier`
- `POST /auth/signup/client`
- `POST /auth/login/courier`
- `POST /auth/login/client`
- `POST /auth/forgot-password`
- `POST /auth/forgot-password/courier`
- `POST /auth/forgot-password/client`

### Example: Client signup
`POST /auth/signup/client`

```json
{
  "email": "alice@example.com",
  "password": "secret123",
  "displayName": "Alice"
}
```

Typical success:

```json
{
  "requestId": "uuid",
  "idToken": "eyJhbGciOi...",
  "refreshToken": "...",
  "localId": "firebase_uid"
}
```

---

## 6. User & Onboarding Endpoints

Base: `/users`

Common endpoints:
- `GET /users/me`
- `POST /users/setup-role`
- `GET /users/search/recipient?q=<text>`
- `PATCH /users/onboarding/profile`
- `POST /users/onboarding/document` (multipart form-data: `file`, `kind`)
- `POST /users/courier/profile`
- `POST /users/client/profile`

### Example: Set role
`POST /users/setup-role`

```json
{
  "role": "courier"
}
```

---

## 7. Courier Routing Endpoints

Base: `/couriers`

Service state:
- `GET /couriers/state`
- `POST /couriers/set-online`
- `POST /couriers/start-travel`
- `POST /couriers/end-travel`

Route templates (reusable route definitions):
- `POST /couriers/route-templates`
- `GET /couriers/route-templates`

Route instance creation from template (creates unique corridor + planned route):
- `POST /couriers/routes/from-template`

Route lifecycle:
- `POST /couriers/routes`
- `GET /couriers/routes`
- `PATCH /couriers/routes/:routeId` (`action`: `activate|complete|cancel`)

### Example: Create route template
`POST /couriers/route-templates`

```json
{
  "startLocation": "-17.8252,31.0335",
  "endLocation": "-17.7849,31.0530",
  "polylinePoints": [
    {"lat": -17.8252, "lng": 31.0335},
    {"lat": -17.8120, "lng": 31.0410},
    {"lat": -17.7849, "lng": 31.0530}
  ],
  "allowMultipleParcels": true,
  "declaredEtaMinutes": 35,
  "notes": "CBD to Mount Pleasant"
}
```

### Example: Use template for scheduled route
`POST /couriers/routes/from-template`

```json
{
  "routeTemplateId": "template-uuid",
  "plannedStartAt": "2026-05-27T12:10:00.000Z"
}
```

Success includes generated operational corridor:

```json
{
  "requestId": "uuid",
  "corridorId": "corridor-uuid",
  "routeId": "route-uuid",
  "status": "PLANNED"
}
```

---

## 8. Corridors Endpoints

Base: `/corridors`

- `POST /corridors` (direct corridor declaration)
- `GET /corridors/me`
- `POST /corridors/:id/line` (polyline geometry)

Notes:
- corridor is the operational entity used by matching/tracking.
- courier UI may hide corridor complexity when using templates.

---

## 9. Parcel Endpoints

Base: `/parcels`

Primary operations include:
- create parcel request
- list created parcels (`/created/me`)
- list assigned/pending courier parcels (`/assigned/me`, `/pending/me`)
- request courier for parcel
- courier accept/decline
- fetch parcel details
- rating
- checkpoints generate/list/verify
- handoff issue report

### Example: Create parcel
`POST /parcels`

```json
{
  "origin": "Avondale, Harare",
  "destination": "Borrowdale, Harare",
  "size": "MEDIUM",
  "priority": "NORMAL",
  "fragile": false,
  "notes": "Handle with care",
  "dualTracking": true,
  "weightKg": 2.5,
  "clientEtaMinutes": 60
}
```

### Example: Request courier shortlist
`POST /parcels/:parcelId/request-courier`

```json
{
  "corridorId": "corridor-uuid"
}
```

or:

```json
{
  "corridorIds": ["corridor-1", "corridor-2"]
}
```

---

## 10. Matching Endpoints

Base: `/matches`

- `POST /matches/corridors`
- `POST /matches/delivery`

Used to retrieve route/corridor candidates by geography and constraints.

---

## 11. Tracking Endpoints

Base: `/tracking`

- `POST /tracking/update`
- `POST /tracking/batch-sync`
- `GET /tracking/alerts/me`
- additional tracking diagnostics endpoints under `/tracking/*`

### Example: Tracking pulse
`POST /tracking/update`

```json
{
  "parcelId": "parcel-uuid",
  "lat": -17.824,
  "lng": 31.041,
  "accuracy": 8.2,
  "deviceInfo": {"model": "SM A042F"},
  "networkInfo": {"type": "mobile"}
}
```

---

## 12. Handshake Endpoints

Base: `/handshake`

Secure pickup/dropoff operations:
- `POST /handshake/upload`
- `POST /handshake/init`
- `POST /handshake/pickup/meeting-point`
- `POST /handshake/pickup`
- `POST /handshake/dropoff`
- `POST /handshake/recipient/issue-dropoff-otp`
- `POST /handshake/courier/request-manual-dropoff-otp`
- `POST /handshake/courier/complete-dropoff`

### Example: Pickup confirmation
`POST /handshake/pickup`

```json
{
  "parcelId": "parcel-uuid",
  "pin": "123456",
  "lat": -17.825,
  "lng": 31.033,
  "accuracy": 7.1,
  "photoUrl": "https://..."
}
```

Common handshake error codes:
- `HANDSHAKE_INVALID_INPUT`
- `HANDSHAKE_NOT_FOUND`
- `HANDSHAKE_NOT_READY`
- `HANDSHAKE_GPS_FAIL`
- `HANDSHAKE_INVALID_PIN`
- `HANDSHAKE_PIN_LOCKED`
- `ERROR_ROUTE_NOT_STARTED`

---

## 13. Notifications Endpoints

Base: `/notifications`

- `GET /notifications/me?status=unread&limit=20&offset=0`
- `POST /notifications/:id/read`
- `POST /notifications/read-all`

Used for in-app notification center state.

---

## 14. Device Token Endpoint

Base: `/devices`

- `POST /devices/register`

Example:

```json
{
  "token": "fcm_device_token",
  "platform": "android"
}
```

---

## 15. Vehicles Endpoints

Base: `/vehicles`

- `POST /vehicles`
- `GET /vehicles/me`
- `GET /vehicles/:id`
- `DELETE /vehicles/:id`

---

## 16. Admin Endpoints (Operational)

Base: `/admin`

Covers:
- monitoring metrics
- alerts rules and health
- logs/errors views
- scheduler/jobs triggers
- couriers/vehicles management
- conflict/dispute resolution and audit surfaces

Because admin surface is broad, use route files for full reference:
- `backend/src/routes/admin.js`

---

## 17. Health Endpoints

Base: `/health`

- `GET /health/`
- `GET /health/heartbeats`
- `GET /health/jobs`
- `GET /health/status`

Public root probe:
- `GET /`

---

## 18. Error Codes Reference (Common)

Global:
- `NOT_FOUND`
- `UNKNOWN_ERROR`

Auth:
- `AUTH_MISSING_TOKEN`
- `AUTH_INVALID_TOKEN`
- `AUTH_ERROR`
- `AUTH_REQUIRED`
- `AUTH_ROLE_REQUIRED`
- `AUTH_ROLE_FORBIDDEN`

Courier/Route:
- `COURIER_INVALID_INPUT`
- `COURIER_OFFLINE`
- `COURIER_ALREADY_TRAVELLING`
- `COURIER_TRAVEL_ACTIVE`
- `ROUTE_INVALID_INPUT`
- `ROUTE_INVALID_ACTION`
- `ROUTE_TEMPLATE_INVALID_INPUT`
- `ROUTE_TEMPLATE_NOT_FOUND`

Handshake:
- `HANDSHAKE_INVALID_INPUT`
- `HANDSHAKE_NOT_READY`
- `HANDSHAKE_INVALID_PIN`
- `HANDSHAKE_INVALID_OTP`
- `HANDSHAKE_GPS_FAIL`
- `HANDSHAKE_PIN_LOCKED`

Parcels/Matching/Tracking:
- module-specific codes are returned in `code`; inspect response payload directly.

---

## 19. Integration Quick Start

1. Create account via `/auth/signup/client` or `/auth/signup/courier`.
2. Save `idToken`, pass as bearer on all protected requests.
3. Set role (`/users/setup-role`) if not already done during onboarding.
4. Register device token (`/devices/register`) for push notifications.
5. For courier:
   - create route template (`/couriers/route-templates`)
   - schedule via `/couriers/routes/from-template`
   - start route lifecycle with `/couriers/routes/:id` + `/couriers/start-travel`
6. For client:
   - create parcel (`/parcels`)
   - request courier (`/parcels/:id/request-courier`)
   - track + handshake flows.

---

## 20. Source Files

Authoritative implementation references:
- `backend/src/index.js`
- `backend/src/middleware/auth.js`
- `backend/src/routes/*.js`
- `backend/src/services/*.js`

This manual is intentionally implementation-driven. Update it when routes, payloads, or auth policy changes.
