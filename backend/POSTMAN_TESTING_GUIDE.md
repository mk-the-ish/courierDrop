# Postman Collection Guide - DropCity API Testing

## 📥 How to Import

### Method 1: Direct Import
1. Open Postman
2. Click **File** → **Import**
3. Select **dropcity-api.postman_collection.json**
4. Collection will appear in your Postman workspace

### Method 2: Link Import
1. In Postman, click **Import**
2. Select **Raw text** tab
3. Copy entire content of `dropcity-api.postman_collection.json`
4. Paste into text area
5. Click **Import**

---

## ⚙️ Setup Variables

Before testing, configure these variables:

### Step 1: Set Base URL
1. In Postman collection, click **Variables** tab
2. Find `base_url` variable
3. Set value to: `http://localhost:8080` (or your backend URL)
4. Find `base_url_ws` variable
5. Set value to: `localhost:8080`

### Step 2: Get Firebase Tokens
```bash
# Get your Firebase ID token from:
1. Firebase Console → Authentication
2. Your user's custom claims
3. Use Firebase Admin SDK to generate token

# Or use curl:
curl -X POST https://identitytoolkit.googleapis.com/v1/accounts:signUp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "password123",
    "returnSecureToken": true
  }' | jq .idToken
```

### Step 3: Set Token Variables
1. Click **Variables** tab
2. Set `admin_token` to your Firebase admin token
3. Set `user_token` to your Firebase user token

### Step 4: Set IDs
1. `user_uid` - Firebase UID of test user
2. `rule_id` - Alert rule UUID (get from "Get All Alert Rules" response)
3. `parcel_id` - Parcel UUID (get from parcels list)
4. `courier_uid` - Courier Firebase UID

---

## 🧪 Testing Workflows

### Workflow 1: Alert System Complete Test

#### Step 1: Check Current Rules
```
Request: Alert System → Get All Alert Rules
Expected: List of alert rules (3 defaults should exist)
```

#### Step 2: Create New Alert Rule
```
Request: Alert System → Create Alert Rule - Error Spike
Expected: 201 status, rule ID returned
Note: Copy rule ID to clipboard
```

#### Step 3: Update Alert Rule
```
Request: Alert System → Update Alert Rule
Variables: Set rule_id to ID from Step 2
Body: Change threshold to 75
Expected: 200 status, rule updated
```

#### Step 4: Get Alert History
```
Request: Alert System → Get Alert History
Expected: List of triggered alerts
```

#### Step 5: Delete Alert Rule
```
Request: Alert System → Delete Alert Rule
Variables: Set rule_id to ID from Step 2
Expected: 200 status
```

---

### Workflow 2: Error Tracking Test

#### Step 1: Log Test Error
```
Request: Error Logging → Log Test Error
Header: Use user_token
Body: Fill in test error details
Expected: 200 status
```

#### Step 2: Get Error Summary
```
Request: Error Tracking → Get Error Summary
Expected: Summary stats with error counts
```

#### Step 3: Get Errors List
```
Request: Error Tracking → Get Errors with Filters
Query params: Adjust days, device, os_version
Expected: Paginated error list
```

---

### Workflow 3: Health Check Test

#### Step 1: Check API Health
```
Request: System Health → Get API Health
Expected: 200 status, API running message
```

#### Step 2: Check Job Status
```
Request: System Health → Get Scheduler Job Status
Expected: Status of heartbeat_watchdog and check_alerts jobs
Look for:
- status: "RUNNING"
- lastRun: recent timestamp
- nextRun: within 2 minutes
```

---

### Workflow 4: Admin Operations Test

#### Step 1: Set User Role
```
Request: Admin Operations → Set User Role
Variables: Set user_uid
Body: Set role to "admin"
Expected: 200 status
```

#### Step 2: Assign Parcel to Courier
```
Request: Admin Operations → Assign Parcel to Courier
Variables: Set parcel_id and courier_uid
Expected: 200 status
```

#### Step 3: Clear User Role
```
Request: Admin Operations → Clear User Role
Variables: Set user_uid
Expected: 200 status
```

---

## 📋 Request Reference

### Alert System Endpoints

#### GET /admin/alerts/rules
**Purpose**: Fetch all alert rules  
**Auth**: admin_token  
**Params**: None  
**Response**: Array of alert rules

```json
[
  {
    "id": "uuid",
    "type": "error_spike",
    "name": "High Error Volume",
    "threshold": 50,
    "time_window_minutes": 30,
    "severity": "warning",
    "notification_channels": ["slack", "email"],
    "enabled": true,
    "created_at": "2024-01-15T10:00:00Z"
  }
]
```

#### POST /admin/alerts/rules
**Purpose**: Create new alert rule  
**Auth**: admin_token  
**Body**:
```json
{
  "type": "error_spike|stuck_job|high_failure_rate",
  "name": "Rule Name",
  "threshold": 50,
  "time_window_minutes": 30,
  "severity": "info|warning|critical",
  "notification_channels": ["slack", "email", "sms"]
}
```

#### PATCH /admin/alerts/rules/{id}
**Purpose**: Update alert rule  
**Auth**: admin_token  
**Params**: rule_id in path  
**Body**:
```json
{
  "enabled": false,
  "threshold": 75,
  "notification_channels": ["slack"]
}
```

#### DELETE /admin/alerts/rules/{id}
**Purpose**: Delete alert rule  
**Auth**: admin_token  
**Params**: rule_id in path

#### GET /admin/alerts/history
**Purpose**: Fetch alert history  
**Auth**: admin_token  
**Params**:
- `limit` (optional, default 50)
- `rule_id` (optional, filter by rule)

---

### Error Tracking Endpoints

#### GET /admin/errors/summary
**Purpose**: Get error statistics  
**Auth**: admin_token  
**Params**:
- `days` (optional, default 7)
- `device` (optional, filter by device model)
- `os_version` (optional, filter by OS version)

**Response**:
```json
{
  "total_errors": 150,
  "unique_devices": 25,
  "unique_os_versions": 3,
  "top_errors": [...],
  "device_breakdown": {...},
  "os_breakdown": {...}
}
```

#### GET /admin/errors
**Purpose**: Get paginated errors  
**Auth**: admin_token  
**Params**:
- `page` (default 0)
- `limit` (default 50)
- `days` (optional)
- `device` (optional)
- `os_version` (optional)

---

### Health Endpoints

#### GET /health/jobs
**Purpose**: Get scheduler job status  
**Auth**: admin_token  
**Response**:
```json
[
  {
    "name": "heartbeat_watchdog",
    "status": "RUNNING",
    "lastRun": "2024-01-15T10:05:00Z",
    "nextRun": "2024-01-15T10:10:00Z",
    "successCount": 45,
    "failureCount": 0,
    "cronExpression": "*/5 * * * *"
  },
  {
    "name": "check_alerts",
    "status": "RUNNING",
    "lastRun": "2024-01-15T10:04:00Z",
    "nextRun": "2024-01-15T10:06:00Z",
    "successCount": 85,
    "failureCount": 0,
    "cronExpression": "*/2 * * * *"
  }
]
```

#### GET /
**Purpose**: Check API health  
**Auth**: None required  
**Response**:
```json
{
  "status": "ok",
  "message": "DropCity API",
  "timestamp": "2024-01-15T10:05:30Z"
}
```

---

## 🔑 Authentication

### Getting Admin Token

#### Option 1: Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your DropCity project
3. Go to Authentication → Users
4. Find admin user
5. Copy their UID
6. Use Firebase Admin SDK or custom token endpoint

#### Option 2: Firebase Admin SDK (Node.js)
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

const uid = 'your-admin-uid';
const customToken = await admin.auth().createCustomToken(uid);
console.log(customToken); // Use this as Bearer token
```

#### Option 3: Firebase REST API
```bash
curl -X POST https://identitytoolkit.googleapis.com/v1/accounts:signUp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@example.com",
    "password": "your-password",
    "returnSecureToken": true
  }' | jq .idToken
```

### Setting Token in Postman

1. Click **Collections** tab
2. Click **dropcity-api** collection
3. Click **Variables** tab
4. Find `admin_token`
5. Paste your token in "Initial value" column
6. Click **Save**

---

## ⚡ Quick Commands Reference

### Test Alert System
```
1. GET  /admin/alerts/rules               (view all)
2. POST /admin/alerts/rules               (create new)
3. PATCH /admin/alerts/rules/{id}         (update)
4. GET  /admin/alerts/history             (view history)
5. DELETE /admin/alerts/rules/{id}        (delete)
```

### Test Error Tracking
```
1. POST /logs                              (log error)
2. GET  /admin/errors/summary              (summary stats)
3. GET  /admin/errors                      (error list)
```

### Test System Health
```
1. GET  /                                  (API health)
2. GET  /health/jobs                       (job status)
```

### Test Admin Operations
```
1. POST /admin/users/{uid}/role            (set role)
2. DELETE /admin/users/{uid}/role          (clear role)
3. POST /admin/parcels/assign              (assign parcel)
```

---

## 🐛 Troubleshooting

### Issue: 401 Unauthorized
**Cause**: Invalid or missing token  
**Solution**:
1. Check token is set in Variables
2. Verify token is not expired
3. Get new token from Firebase
4. Check Authorization header is set

### Issue: 403 Forbidden
**Cause**: User doesn't have admin role  
**Solution**:
1. Use admin_token, not user_token
2. Verify user has "admin" role in Firestore
3. Set role using Set User Role endpoint

### Issue: Network Error
**Cause**: Backend not running  
**Solution**:
1. Start backend: `cd backend && npm start`
2. Verify base_url is correct
3. Check backend logs for errors

### Issue: 404 Not Found
**Cause**: Endpoint doesn't exist  
**Solution**:
1. Verify endpoint path is correct
2. Check API version matches
3. Review backend route definitions

### Issue: 500 Internal Server Error
**Cause**: Server error  
**Solution**:
1. Check backend logs
2. Verify database connection
3. Validate request body format
4. Check error message in response

---

## 💡 Testing Tips

### Tip 1: Save Responses
After each request, response appears at bottom. Click **Save as example** to remember successful responses.

### Tip 2: Use Tests Tab
Add Postman tests for automation:
```javascript
pm.test("Status is 200", function() {
  pm.response.to.have.status(200);
});

pm.test("Response contains rule_id", function() {
  let jsonData = pm.response.json();
  pm.expect(jsonData).to.have.property("id");
});
```

### Tip 3: Copy Values from Response
When you create a rule, copy the ID:
1. Get response from POST request
2. Click on response body
3. Highlight the ID
4. Drag into Variables or next request

### Tip 4: Use Postman Runners
Test multiple requests sequentially:
1. Click **Runner** button
2. Select **dropcity-api** collection
3. Choose which requests to run
4. Click **Start Run**

### Tip 5: Environment Variables
Create separate environments for dev/staging/production:
1. Click **Environments** gear icon
2. Click **+** to create new
3. Set different base_url for each
4. Switch environments in top-right dropdown

---

## 📊 Test Scenarios

### Scenario 1: Complete Alert Workflow
1. ✅ Create alert rule (error_spike)
2. ✅ Verify rule exists (GET rules)
3. ✅ Log test error
4. ✅ Check alert triggered (GET history)
5. ✅ Update rule (change threshold)
6. ✅ Delete rule

### Scenario 2: Error Tracking Workflow
1. ✅ Log multiple test errors
2. ✅ Get error summary
3. ✅ Filter errors by device
4. ✅ Filter errors by OS
5. ✅ Paginate through results

### Scenario 3: System Health Check
1. ✅ API health endpoint
2. ✅ Scheduler job status
3. ✅ Verify jobs are RUNNING
4. ✅ Check recent execution times

---

## 📝 Example Request/Response

### Example: Create Alert Rule

**Request**:
```
POST http://localhost:8080/admin/alerts/rules
Header: Authorization: Bearer your_token
Content-Type: application/json

{
  "type": "error_spike",
  "name": "Test Alert",
  "threshold": 10,
  "time_window_minutes": 30,
  "severity": "warning",
  "notification_channels": ["slack"]
}
```

**Response (201)**:
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "type": "error_spike",
  "name": "Test Alert",
  "threshold": 10,
  "time_window_minutes": 30,
  "severity": "warning",
  "notification_channels": ["slack"],
  "enabled": true,
  "created_at": "2024-01-15T10:05:00Z"
}
```

---

## 🎯 Common Test Cases

| Test | Endpoint | Expected Status |
|------|----------|-----------------|
| Get all rules | GET /admin/alerts/rules | 200 |
| Create rule | POST /admin/alerts/rules | 201 |
| Update rule | PATCH /admin/alerts/rules/{id} | 200 |
| Delete rule | DELETE /admin/alerts/rules/{id} | 200 |
| Get history | GET /admin/alerts/history | 200 |
| Error summary | GET /admin/errors/summary | 200 |
| Error list | GET /admin/errors | 200 |
| Job status | GET /health/jobs | 200 |
| API health | GET / | 200 |
| Set role | POST /admin/users/{uid}/role | 200 |
| Assign parcel | POST /admin/parcels/assign | 200 |

---

## 📞 Support

For issues:
1. Check backend logs: `npm start`
2. Verify token is valid
3. Check base_url matches your backend
4. Review error response message
5. See ALERTS_SETUP.md troubleshooting section

---

**Last Updated**: January 2024  
**Collection Version**: 1.0.0  
**API Version**: Latest
