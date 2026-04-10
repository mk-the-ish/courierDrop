# Backend Testing Guide - Quick Start

## 📦 What You Have

This testing package includes everything needed to test all DropCity backend API endpoints:

1. **dropcity-api.postman_collection.json** - Complete Postman collection with all endpoints
2. **POSTMAN_TESTING_GUIDE.md** - Detailed testing documentation
3. **setup-testing.sh** - Automated setup script
4. **test-api-commands.sh** - Pre-made curl commands
5. **postman-environment-template.json** - Postman environment template

---

## 🚀 Quick Start (5 minutes)

### Step 1: Import Postman Collection
```bash
# In Postman:
1. File → Import
2. Select dropcity-api.postman_collection.json
3. Collection appears in left sidebar
```

### Step 2: Set Variables
```bash
# In Postman collection:
1. Click on collection name
2. Click "Variables" tab
3. Set these values:
   - base_url: http://localhost:8080
   - admin_token: YOUR_FIREBASE_ADMIN_TOKEN
   - user_token: YOUR_FIREBASE_USER_TOKEN
4. Click Save
```

### Step 3: Start Testing
```bash
# In Postman:
1. Expand "Alert System" folder
2. Click "Get All Alert Rules"
3. Click "Send"
4. See response at bottom
```

---

## 🔑 Get Firebase Tokens

### Option A: Firebase Console
```
1. Go to https://console.firebase.google.com/
2. Select your project
3. Go to Authentication
4. Find your test user
5. Copy their UID
6. Use Firebase Admin SDK to create token
```

### Option B: Firebase Admin SDK (Node.js)
```javascript
const admin = require('firebase-admin');

async function getToken() {
  const uid = 'your-user-uid';
  const token = await admin.auth().createCustomToken(uid);
  console.log(token); // Use this as Bearer token
}
```

### Option C: Firebase REST API
```bash
curl -X POST https://identitytoolkit.googleapis.com/v1/accounts:signUp \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "returnSecureToken": true
  }' | jq .idToken
```

---

## 📊 Testing Workflows

### Workflow 1: Alert System (10 minutes)

```
1. Get All Alert Rules
   → See 3 default rules

2. Create Alert Rule
   → Creates new error_spike rule

3. Update Alert Rule
   → Changes threshold to 75

4. Get Alert History
   → Shows triggered alerts

5. Delete Alert Rule
   → Removes the rule
```

### Workflow 2: Error Tracking (5 minutes)

```
1. Log Test Error
   → Creates test error in system

2. Get Error Summary
   → Shows error statistics

3. Get Errors with Filters
   → Lists paginated errors
```

### Workflow 3: Health Check (2 minutes)

```
1. Get API Health
   → Verifies backend running

2. Get Scheduler Job Status
   → Shows job execution status
```

---

## 🎯 Most Important Endpoints

### ✅ Check Backend is Running
```
GET http://localhost:8080/
No auth required
```

### ✅ Check Scheduler Jobs
```
GET http://localhost:8080/health/jobs
Header: Authorization: Bearer {admin_token}
```

### ✅ Test Alert System
```
GET http://localhost:8080/admin/alerts/rules
Header: Authorization: Bearer {admin_token}
```

### ✅ Test Error Tracking
```
GET http://localhost:8080/admin/errors/summary
Header: Authorization: Bearer {admin_token}
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| **401 Unauthorized** | Check token is set correctly in Variables |
| **Backend not found** | Start backend: `cd backend && npm start` |
| **No responses** | Check base_url is correct (http://localhost:8080) |
| **401 on health endpoint** | Some endpoints don't need auth (like GET /) |
| **Rule ID not found** | Get ID from "Get All Alert Rules" response |

---

## 📝 Using curl Commands

### Alternative: Test with curl
```bash
# Set token
export ADMIN_TOKEN="your-token-here"

# Test API health
curl http://localhost:8080/

# Get alert rules
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8080/admin/alerts/rules

# Create alert rule
curl -X POST http://localhost:8080/admin/alerts/rules \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "error_spike",
    "name": "Test Alert",
    "threshold": 50,
    "time_window_minutes": 30,
    "severity": "warning",
    "notification_channels": ["slack"]
  }'
```

---

## 📚 Full Documentation

For complete details, see:
- **POSTMAN_TESTING_GUIDE.md** - Comprehensive testing guide
- **ALERTS_SETUP.md** - API configuration and details
- **dropcity-api.postman_collection.json** - All endpoints with examples

---

## ✨ Pro Tips

1. **Save Variables** - Click Save after changing variables
2. **Copy Response IDs** - Use IDs from responses in other requests
3. **Use Environments** - Create separate dev/staging/prod environments
4. **Run Collections** - Use Runner to test multiple endpoints
5. **Add Tests** - Write Postman tests to validate responses

---

## 🎓 What Each Folder Contains

### Alert System
- Get all rules
- Create rule (error spike, stuck job, failure rate)
- Update rule
- Delete rule
- View alert history

### Error Tracking
- Get error summary
- Get errors with filtering

### System Health
- Check API health
- Check scheduler jobs

### Admin Operations
- Set user role
- Clear user role
- Assign parcel to courier

### Error Logging
- Log test errors

---

## ✅ Verification Checklist

After setup, verify:

- [ ] Postman collection imported
- [ ] Variables set (base_url, admin_token)
- [ ] Backend running (GET / returns 200)
- [ ] Jobs running (GET /health/jobs shows RUNNING)
- [ ] Alert rules exist (GET /admin/alerts/rules returns data)
- [ ] Can create alert rule (POST succeeds)
- [ ] Can get errors (GET /admin/errors/summary returns data)

---

## 🚀 Next Steps

1. **Test Basic Endpoints**
   - Run health check requests first
   - Then test alert system
   - Finally test error tracking

2. **Create Test Data**
   - Create alert rules
   - Log test errors
   - Verify alerts trigger

3. **Monitor System**
   - Check job status regularly
   - Review error trends
   - Test notifications

---

## 📞 Need Help?

1. Check POSTMAN_TESTING_GUIDE.md for detailed examples
2. Review ALERTS_SETUP.md for configuration
3. Check backend logs: `npm start`
4. Verify token is valid and not expired

---

**Happy Testing! 🎉**
