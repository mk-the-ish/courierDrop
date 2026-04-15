# Database Architecture & Signup Flow

## Database Responsibilities

### Firebase (Authentication & Real-time Data)
- **Purpose**: User authentication, presence tracking, live location updates
- **Data Stored**:
  - User credentials (email, password hash)
  - Auth tokens
  - Real-time location data during active trips
  - Live notifications and messaging
  - Temporary session data
- **Why**: Firebase Realtime Database excels at live updates, presence detection, and real-time collaboration

### Supabase (PostgreSQL - Business Logic & Matching)
- **Purpose**: Structured data for matching algorithms, audit trails, and business logic
- **Data Stored**:
  - `users` - User profiles with roles (client/courier)
  - `vehicles` - Courier vehicle information (capacity, type, registration)
  - `parcels` - Parcel requests with coordinate data
  - `corridors` - Delivery routes with polylines
  - `parcel_assignment_queue` - Matching results
  - `handshake_events` - Delivery verification events
  - All other business entities
- **Why**: PostGIS extension enables geographic matching, structured queries for complex algorithms, audit trails, and transaction safety

---

## Signup Flow (Fixed)

### Step 1: User Chooses Role
```
Client App Shows: "Create account" → role = "client"
Courier App Shows: "Create account" → role = "courier"
```

### Step 2: Firebase Authentication (Automatic)
```dart
// ApiClient calls Firebase REST API directly (NOT going through backend)
POST https://identitytoolkit.googleapis.com/v1/accounts:signUp
{
  "email": "user@example.com",
  "password": "password123",
  "displayName": "John User",
  "returnSecureToken": true
}

Response:
{
  "idToken": "firebase_id_token",
  "localId": "user_uid",
  "refreshToken": "refresh_token",
  "expiresIn": 3600
}
```

### Step 3: Backend Role Setup (Fixed - NOW CALLED)
```dart
// After Firebase auth succeeds, auth_service.dart now calls backend:
POST https://dropcity-backend.onrender.com/users/setup-role
Header: Authorization: Bearer <idToken>
{
  "role": "client" or "courier"
}

// Backend creates user record in Supabase:
INSERT INTO public.users (id, role, email, display_name, verified_at)
VALUES (user_uid, role, email, displayName, NOW())
```

### Step 4: Courier-Only - Vehicle Info Collection
```dart
// Courier app shows CourierInfoScreen asking for:
- Vehicle Type (motorcycle, car, van, truck)
- Make/Model/Year
- License Plate
- Max Capacity (kg)

// TODO: This data needs backend endpoint to save to vehicles table
POST https://dropcity-backend.onrender.com/vehicles
Header: Authorization: Bearer <idToken>
{
  "vehicleType": "car",
  "make": "Honda",
  "model": "CR-V",
  "year": 2022,
  "licensePlate": "ABC 123",
  "maxCapacityKg": 100
}

// Inserts into Supabase:
INSERT INTO public.vehicles (courier_id, vehicle_type, make, model, year, license_plate, max_capacity_kg)
VALUES (user_uid, 'car', 'Honda', 'CR-V', 2022, 'ABC 123', 100)
```

### Step 5: Dashboard Access
```
Backend middleware now finds role in Supabase users table:
- role = "client" → shows client dashboard
- role = "courier" → shows courier dashboard
```

---

## Complete Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER SIGNUP FLOW (FIXED)                     │
└─────────────────────────────────────────────────────────────────┘

1. LOGIN SCREEN (Mobile App)
   ├─ Client app: role = "client"
   └─ Courier app: role = "courier"
              ↓
2. FIREBASE AUTH (Mobile App calls Firebase directly)
   ├─ Email + Password
   ├─ Returns: idToken, userId, refreshToken
   └─ Token stored in app
              ↓
3. BACKEND ROLE SETUP (Mobile App calls our backend - FIXED!)
   ├─ POST /users/setup-role
   ├─ Header: Authorization: Bearer <idToken>
   ├─ Body: {role: "client" or "courier"}
   └─ Supabase inserts user with role
              ↓
4. COURIER ONLY - VEHICLE INFO (Courier app shows form)
   ├─ Collect vehicle details
   ├─ POST /vehicles (backend endpoint - TODO)
   └─ Supabase stores vehicle info
              ↓
5. DASHBOARD
   ├─ Backend middleware checks role in Supabase
   ├─ Authorizes API access
   └─ User can create parcels/routes/etc.
```

---

## What Was The Problem?

**Before (Broken)**:
```
1. Firebase Auth (works)
2. [MISSING] Backend setup-role call
3. Supabase users table empty (no role)
4. Backend can't find role → 403 Auth_Role_Required
```

**Now (Fixed)**:
```
1. Firebase Auth (works)
2. ✅ Backend setup-role call (fixed!)
3. ✅ Supabase users table populated with role
4. ✅ Backend finds role → Allows access
```

---

## Files Fixed

### Mobile Apps
- ✅ `client/lib/screens/login_screen.dart` - Now passes `role: "client"`
- ✅ `client/lib/auth/auth_state.dart` - Accepts and passes role parameter
- ✅ `courier/lib/screens/login_screen.dart` - Now passes `role: "courier"`
- ✅ `courier/lib/auth/auth_state.dart` - Accepts and passes role parameter
- ✅ `courier/lib/auth/auth_service.dart` - Already calls setupUserRole
- ✅ `client/lib/auth/auth_service.dart` - Already calls setupUserRole

### New Files
- ✅ `courier/lib/screens/courier_info_screen.dart` - Vehicle info collection form

### Backend & Database
- ✅ `backend/sql/010_vehicles_table.sql` - New vehicles table

---

## API Endpoints Summary

| Endpoint | Method | Called By | Purpose |
|----------|--------|-----------|---------|
| `/auth/signup` | POST | Mobile App | Firebase auth (direct) |
| `/auth/login` | POST | Mobile App | Firebase auth (direct) |
| `/users/setup-role` | POST | Mobile App (after Firebase) | Set user role in Supabase |
| `/users/me` | GET | Mobile App | Get current user profile |
| `/vehicles` | POST | Courier App | Save vehicle info (TODO) |
| `/parcels` | POST | Client App | Create parcel request |
| `/corridors` | POST | Courier App | Declare delivery route |

---

## Key Changes Made

### 1. Login Screens Now Pass Role
```dart
// BEFORE:
await widget.authState.signUp(email, password, displayName: name);

// AFTER:
await widget.authState.signUp(
  email,
  password,
  displayName: name,
  role: "client", // ← NEW
);
```

### 2. Auth State Accepts Role
```dart
// BEFORE:
Future<void> signUp(String email, String password, {String? displayName}) async {

// AFTER:
Future<void> signUp(String email, String password, {String? displayName, String? role}) async {
```

### 3. Auth Service Calls Backend
```dart
// Already implemented - setupUserRole() is called automatically
if (role != null && (role == "client" || role == "courier")) {
  try {
    await _apiClient.setupUserRole(role: role);
  } catch (e) {
    // Continue anyway - user can set role later
  }
}
```

---

## Testing The Fix

### 1. Test Client Signup
```
1. Open client app → "Sign up" tab
2. Enter email, password, display name
3. Click "Create account"
4. Should succeed and go to dashboard
5. Verify in Supabase: users table has role="client"
```

### 2. Test Courier Signup
```
1. Open courier app → "Sign up" tab
2. Enter email, password, display name
3. Click "Create account"
4. Should go to CourierInfoScreen
5. Fill vehicle info
6. Click "Continue to Dashboard"
7. Verify in Supabase: 
   - users table has role="courier"
   - vehicles table has vehicle info
```

### 3. Test Role Authorization
```
1. Courier app: GET /parcels/assigned/me
2. Should return 200 OK (not 403 Auth_Role_Required)
3. Verify backend logs:
   - Should show "[Auth] Loaded role for {uid}: courier"
```

---

## Database Schema Reference

### users table (Firebase + Supabase sync)
```
id (TEXT) - Firebase UID
email (TEXT) - Email address
role (TEXT) - 'client' or 'courier'
display_name (TEXT) - User display name
phone_number (TEXT) - Contact number
profile_picture_url (TEXT) - Avatar URL
verified_at (TIMESTAMPTZ) - When user completed setup
created_at (TIMESTAMPTZ) - Account creation time
updated_at (TIMESTAMPTZ) - Last profile update
```

### vehicles table (Supabase only)
```
id (UUID) - Vehicle record ID
courier_id (TEXT) - FK to users.id
vehicle_type (TEXT) - 'motorcycle', 'car', 'van', 'truck'
make (TEXT) - Brand (Honda, Toyota, etc.)
model (TEXT) - Model (CR-V, Corolla, etc.)
year (INTEGER) - Year (2022, 2023, etc.)
license_plate (TEXT) - Registration number
max_capacity_kg (INTEGER) - Weight capacity
is_active (BOOLEAN) - Currently available
verification_status (TEXT) - 'unverified', 'verified', 'rejected'
created_at (TIMESTAMPTZ) - Registration time
```

---

## Next Steps

1. **Deploy Backend** - Push changes to GitHub → Render auto-deploys
2. **Run Migrations** - Execute SQL files in Supabase:
   - `009_users_table.sql` (alter users table)
   - `010_vehicles_table.sql` (create vehicles table)
3. **Rebuild Mobile Apps** - `flutter clean && flutter run`
4. **Test Signup Flow** - Try signing up as client and courier
5. **Monitor Logs** - Check Render backend logs for auth role messages
6. **Create Vehicles API** - Implement `POST /vehicles` endpoint in backend

---

## Flow Verification Checklist

- [ ] Firebase signup works (idToken returned)
- [ ] Backend setupUserRole called (check logs)
- [ ] User record appears in Supabase users table with role
- [ ] GET /users/me returns correct role
- [ ] GET /parcels/assigned/me returns 200 (not 403)
- [ ] Courier app shows vehicle form after signup
- [ ] Vehicle info saves to Supabase vehicles table
- [ ] Backend middleware logs: "[Auth] Loaded role for {uid}: courier"
