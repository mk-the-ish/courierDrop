# Backend Setup Guide: Users, Roles & Matching

## Problem Summary

The backend was unable to access assigned parcels for couriers because:
1. The `users` table didn't exist in the database
2. Users weren't assigned roles (client/courier) after signup
3. The backend middleware couldn't find roles and rejected requests with `Auth_Role_Required` (403 error)

## Solution Overview

### 1. Database Changes

**New Migration File: `009_users_table.sql`**
- Creates `public.users` table with columns: `id`, `role`, `display_name`, `email`, `phone_number`, `profile_picture_url`, `verified_at`, `created_at`, `updated_at`
- Adds indexes for efficient queries
- This table stores user role information that the backend middleware queries

### 2. Backend API Changes

**New Route File: `src/routes/users.js`**

#### Endpoints:

**`POST /users/setup-role`** (Protected - requires authentication)
- Called after user signup to assign their role
- Request body:
  ```json
  {
    "role": "courier",
    "displayName": "John Courier"
  }
  ```
- Response: 
  ```json
  {
    "id": "user_uid",
    "role": "courier",
    "message": "User role set to courier"
  }
  ```
- Returns 409 error if role already set
- Valid roles: `"client"` or `"courier"`

**`GET /users/me`** (Protected - requires authentication)
- Returns current user's profile including role
- Response includes: `id`, `role`, `email`, `display_name`, `verified_at`, `created_at`

**`GET /users/:id`** (Public)
- Returns user profile by UID
- Used for looking up courier/client information

### 3. Updated Main Index: `src/index.js`
- Imported users route
- Registered `/users` endpoint with authentication middleware
- Now handles `POST /users/setup-role` for role assignment

## How It Works Now

### Signup Flow
```
1. User signs up via Firebase Auth (POST /auth/signup)
   → Returns idToken, refreshToken
   
2. App calls POST /users/setup-role with idToken
   → Backend verifies token
   → Creates/updates user record in `users` table with role
   → User is now "client" or "courier"
   
3. Next API calls (parcels, corridors, etc.)
   → Backend queries users table for role
   → User is authorized to proceed
```

### Matching Flow

**How Matching Works:**

1. **Client creates a parcel request**
   ```
   POST /parcels
   {
     "origin": "-17.8252, 31.0335",
     "destination": "-18.5, 31.5",
     "size": "small box",
     "priority": "Standard"
   }
   ```
   → Parcel stored with `status: "REQUESTED"`
   → `origin_point` and `destination_point` populated (from coordinate parsing)

2. **Courier declares a delivery route**
   ```
   POST /corridors
   {
     "startLocation": "-17.8, 31.0",
     "endLocation": "-18.4, 31.6",
     "windowStart": "09:00",
     "windowEnd": "17:00"
   }
   ```
   → Corridor stored
   
   ```
   POST /corridors/{corridorId}/line
   {
     "polyline": [
       {"lat": -17.8, "lng": 31.0},
       {"lat": -17.9, "lng": 31.1},
       {"lat": -18.5, "lng": 31.5}
     ]
   }
   ```
   → Corridor line (polyline) stored as geography

3. **Matching Check** (Client app initiates)
   ```
   POST /matches/corridors
   {
     "origin": {"lat": -17.8252, "lng": 31.0335},
     "destination": {"lat": -18.5, "lng": 31.5},
     "maxDetourMeters": 5000
   }
   ```
   → Backend executes PostgreSQL function: `match_corridors_for_parcel`
   → Finds corridors that pass within 5km of both origin and destination
   → Returns matching corridors with pickup/dropoff fractions and points
   
   Response:
   ```json
   {
     "matches": [
       {
         "corridor_id": "uuid",
         "pickup_fraction": 0.25,
         "dropoff_fraction": 0.75,
         "pickup_point": {"lat": -17.85, "lng": 31.05},
         "dropoff_point": {"lat": -18.45, "lng": 31.55}
       }
     ]
   }
   ```

4. **Assign parcel to corridor**
   ```
   POST /parcels/{parcelId}/assign
   {
     "corridorId": "uuid"
   }
   ```
   → Updates parcel with `assigned_courier_id` and `status: "ASSIGNED"`
   → Courier notified via WebSocket

5. **Start Trip** (When courier begins)
   ```
   POST /parcels/{parcelId}/start-trip
   ```
   → Updates parcel `status: "IN_TRANSIT"`
   → WebSocket broadcasts to client

## Testing the Setup

### 1. Set User Roles

**For Courier User:**
```bash
curl -X POST https://dropcity-backend.onrender.com/users/setup-role \
  -H "Authorization: Bearer <COURIER_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"role": "courier", "displayName": "John Courier"}'
```

**For Client User:**
```bash
curl -X POST https://dropcity-backend.onrender.com/users/setup-role \
  -H "Authorization: Bearer <CLIENT_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"role": "client", "displayName": "Jane Client"}'
```

### 2. Verify Role Assignment

```bash
curl https://dropcity-backend.onrender.com/users/me \
  -H "Authorization: Bearer <ANY_USER_ID_TOKEN>"
```

Response should show the assigned role.

### 3. Check Assigned Parcels (Courier Only)

```bash
curl https://dropcity-backend.onrender.com/parcels/assigned/me \
  -H "Authorization: Bearer <COURIER_ID_TOKEN>"
```

Should now return 200 OK instead of 403 Auth_Role_Required.

### 4. Test Matching

```bash
curl -X POST https://dropcity-backend.onrender.com/matches/corridors \
  -H "Authorization: Bearer <CLIENT_ID_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "origin": {"lat": -17.8252, "lng": 31.0335},
    "destination": {"lat": -18.5, "lng": 31.5},
    "maxDetourMeters": 5000
  }'
```

## Files Changed

- **New**: `backend/sql/009_users_table.sql` - Users table schema
- **New**: `backend/src/routes/users.js` - User management endpoints
- **Modified**: `backend/src/index.js` - Registered users route

## Next Steps

1. **Deploy to Render**
   - Push changes to repository
   - Run migration: `009_users_table.sql` in Supabase
   
2. **Set Roles for Existing Users**
   - Use the POST /users/setup-role endpoint
   - Or run direct SQL:
   ```sql
   INSERT INTO public.users (id, role, email, created_at)
   VALUES ('GUpu16Av8YXCk6Kfgr7qTtVg7O32', 'courier', 'courier@example.com', NOW())
   ON CONFLICT(id) DO UPDATE SET role = 'courier';
   ```

3. **Mobile Apps Update**
   - After signup, call POST /users/setup-role before accessing other endpoints
   - This ensures role is set in the database immediately

4. **Monitor Backend Logs**
   - Should see: `[Auth] Loaded role for {uid}: client` instead of "No role found"
   - GET /parcels/assigned/me should return 200 OK
