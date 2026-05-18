# DropCity Phase 5B Continuation Prompt

You are continuing an existing multi-app logistics platform (`backend`, `client`, `courier`, `admin`) and must implement only the missing parts while preserving current behavior.

## Current Baseline (already in repo)
- Backend: role-specific auth endpoints for client/courier signup/login; profile tables and profile save endpoints exist.
- Client app: now has 2-step signup flow (email/password -> personal info + ID image), login, forgot-password.
- Courier app: 4-step signup flow exists with profile capture and submit.
- Existing parcel, matching, handshake, notifications, and tracking foundations exist.

## Objectives to Complete

### 1) Client Delivery Creation Multi-Screen Workflow
Implement a new 5-screen flow and wire from dashboard:
1. `details`: description, size (S/M/L), weight, desired arrival time
2. `parcel image`: capture/upload image
3. `locations`: pickup + destination (map pick + typed search)
4. `recipient`: in-app recipient vs external recipient decision
5. `courier offers`: list matched couriers + recommended price + custom bid input

Requirements:
- Keep each screen minimal and uncluttered.
- Preserve offline queue behavior.
- Return to dashboard after order creation and offer request.

### 2) Recipient/Non-Recipient Split Logic
Implement two distinct dropoff handshake paths:
- In-app recipient path: recipient location check + photo + PIN generation; courier enters PIN and uploads final proof.
- External recipient path: sender fallback confirmation workflow using OTP/SMS + courier proof image + dispute opening window.

### 3) Courier Route Declaration & Activation Lifecycle
Implement route lifecycle:
- `PLANNED -> ACTIVE -> COMPLETED`
- Courier declares route + expected start time + ETA estimate.
- Matching should include ACTIVE and ABOUT_TO_START couriers.
- Enforce “courier can accept pickup only when route is ACTIVE”.
- Add reminder notification shortly before expected start time.

### 4) Pickup Fast Flow + Route-Aware Pickup Adjustments
- From parcels list: single-tap pickup action.
- Capture photo + location, allow editable pickup point override.
- Backend gate check verifies courier is within pickup vicinity.
- Add backend suggestion endpoint for route-adjacent pickup points and sender acceptance.

### 5) Tracking Robustness (Critical)
Implement production-grade tracking:
- Foreground service + background location posting (Android-compliant).
- Heuristic tracking service:
  - route adherence scoring
  - anomaly detection (teleportation/impossible speed/stagnation)
  - checkpoint confidence + movement confidence
- Persist per-update diagnostics for admin analysis.

### 6) ETA Model v1
Build backend ETA service blending:
- courier declared ETA
- distance / baseline speed
- map-provider ETA (if available)
- historical corridor ETA

Return confidence score and source breakdown; notify sender on pickup ETA and dropoff ETA updates.

### 7) Pricing Model v2
Enhance recommendation engine with:
- route segment transfer percentage pricing
- weight and urgency sensitivity
- demand/load modifier
- historical adjustment log table

### 8) Matching Algorithm Completion
Match on:
- origin near route
- destination near route
- route ACTIVE or ABOUT_TO_START
- courier capacity/space remaining
- route progress check (not already past feasible pickup)

### 9) Admin Conflict Resolution
Add admin screen for failed handshakes and disputes:
- evidence panel (photos, GPS, timestamps)
- decision actions (approve, refund, partial, escalate)
- immutable audit trail

## Technical Constraints
- Keep auth for `client` and `courier` via Firebase through backend endpoints.
- Keep admin auth via Supabase.
- No burger menus in mobile apps.
- Client bottom nav: 3 tabs.
- Courier bottom nav: 4 tabs (`home`, `parcels`, `routes`, `settings`).
- Prefer multi-screen workflows over crowded forms.

## Definition of Done
- End-to-end happy path:
  - client signup -> profile completion -> create delivery -> select courier -> receive confirmation
  - courier route declaration -> route activation -> accept parcel -> pickup -> tracking -> dropoff handshake
  - rating submission and aggregate update
- External-recipient fallback path works without requiring recipient app account.
- Tracking remains functional during background execution and intermittent connectivity.
- Admin can resolve failed handshakes from UI.
- Add/update tests for critical flows and regression-prone endpoints.
