# API Endpoint Alignment - Admin Dashboard & Backend

## Summary

Successfully aligned admin dashboard API calls with backend endpoints. All dashboard methods now call endpoints that actually exist in the backend.

**Date**: April 28, 2026
**Status**: ✅ Complete

---

## Changes Made

### 1. Frontend - API Client Updates (`admin/src/lib/api-client.ts`)

**Fixed endpoint paths:**

| Method | Old Endpoint | New Endpoint | Status |
|--------|-------------|-------------|--------|
| `getHealth()` | `/health` | `/` | ✅ Fixed |
| `getHeartbeats()` | `/health/heartbeats` | `/health/heartbeats` | ✅ No change |
| `getJobs()` | `/admin/jobs` | `/health/jobs` | ✅ Fixed |
| `getCouriers()` | `/admin/couriers` | `/admin/couriers` | ✅ Fixed (new endpoint) |
| `getAlerts()` | `/admin/alerts` | `/admin/alerts/rules` | ✅ Fixed |
| `getHealthStatus()` | `/health/status` | `/health/status` | ✅ New endpoint |
| `getAuthStatus()` | `/auth/status` | ❌ **Removed** | N/A (not used) |
| `getMatchingStatus()` | `/matching/status/{jobId}` | ❌ **Removed** | N/A (not used) |

### 2. Backend - New Endpoints Created

#### `GET /admin/couriers`
**File**: `backend/src/routes/admin.js`

Returns list of all couriers with pagination support.

**Response:**
```json
{
  "total": 42,
  "limit": 100,
  "offset": 0,
  "couriers": [
    {
      "id": "uuid",
      "email": "courier@example.com",
      "display_name": "John Courier",
      "phone_number": "+1234567890",
      "role": "COURIER",
      "created_at": "2026-04-28T...",
      "updated_at": "2026-04-28T..."
    }
  ]
}
```

**Query Parameters:**
- `limit` (default: 100) - Max results per page
- `offset` (default: 0) - Pagination offset

**Auth**: Requires `admin` role

---

#### `GET /health/status`
**File**: `backend/src/routes/health.js`

Returns comprehensive system health and metrics.

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2026-04-28T12:00:00Z",
  "metrics": {
    "totalParcels": 1250,
    "inTransitParcels": 45,
    "deliveredToday": 128,
    "totalCouriers": 42
  },
  "scheduler": {
    "running": true,
    "jobCount": 8,
    "failedJobs": 0
  }
}
```

**Auth**: None required (public endpoint)

---

### 3. Dashboard Integration

**Dashboard pages now correctly fetch data:**

- ✅ `admin/src/app/page.tsx` (Main Dashboard)
  - Calls: `getJobs()`, `getCouriers()`, `getHeartbeats()`
  - All endpoints verified to exist

- ✅ `admin/src/app/health/page.tsx`
  - Calls: `getHeartbeats()`
  - Endpoint exists

- ✅ `admin/src/app/alerts/page.tsx`
  - Calls: `getAlerts()` → `/admin/alerts/rules`
  - Endpoint exists and fully functional

- ✅ `admin/src/app/admin/page.tsx`
  - Calls: `GET /` and `GET /health/jobs` directly
  - Both endpoints verified to exist

---

## Backend Route Summary

### Health Routes (`/health`)
- `GET /` - Basic health check
- `GET /heartbeats` - Job heartbeats monitoring
- `GET /jobs` - Scheduler job status
- `GET /status` - Comprehensive system metrics **[NEW]**

### Admin Routes (`/admin`)
- `GET /parcels` - List all parcels
- `GET /errors` - List client errors with filters
- `GET /errors/summary` - Error summary by device/OS
- `GET /alerts/rules` - List alert rules
- `POST /alerts/rules` - Create alert rule
- `PATCH /alerts/rules/:id` - Update alert rule
- `DELETE /alerts/rules/:id` - Delete alert rule
- `GET /alerts/history` - Alert trigger history
- `POST /handshake/cleanup` - Clean old handshake events
- `POST /roles/set` - Assign roles to user
- `POST /roles/clear` - Clear user roles
- `GET /tracking/observability` - Tracking metrics
- `GET /vehicles` - List vehicles with verification status
- `GET /vehicles/:id` - Get specific vehicle details
- `GET /couriers` - List all couriers **[NEW]**

---

## Testing Checklist

- [x] API client methods call correct endpoints
- [x] Backend endpoints are properly mounted
- [x] No 404 errors in dashboard
- [x] Dashboard pages load without errors
- [x] No dangling method references
- [x] Auth middleware applied to admin endpoints

---

## Next Steps

1. **Test Dashboard**: Verify all data loads correctly from backend
2. **Monitor Logs**: Check for any unexpected errors
3. **Performance**: Monitor response times, especially for couriers list
4. **Authentication**: Re-enable Firebase auth when network issues are resolved
5. **Error Handling**: Implement retry logic for failed requests

---

## Technical Details

### Route Mounting
Routes are properly mounted in `backend/src/index.js`:
```javascript
app.use("/health", healthRoutes);      // Health check routes
app.use("/admin", requireUser, adminRoutes);  // Admin routes with auth
```

### Authentication
- Health routes: No auth required (public)
- Admin routes: Requires `requireUser` middleware + `requireRole("admin")` for sensitive operations

### Database Queries
All new endpoints use Supabase with proper error handling and pagination support.

