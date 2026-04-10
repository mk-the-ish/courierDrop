# 🧪 Backend Testing Suite - Complete Index

## 📦 Testing Files Overview

This directory contains everything you need to test the DropCity backend API:

### Postman Collection & Environment
- **dropcity-api.postman_collection.json** - Complete Postman collection with all endpoints
- **postman-environment-template.json** - Environment variables template

### Documentation
- **POSTMAN_TESTING_GUIDE.md** - Comprehensive testing guide with examples
- **TESTING_QUICK_START.md** - Quick start guide (5 minutes)
- **ALERTS_SETUP.md** - API configuration and details

### Setup Scripts
- **setup-testing.sh** - Automated setup for Linux/macOS
- **setup-testing.bat** - Automated setup for Windows

### Test Command Files
- **test-api-commands.sh** - Pre-made curl commands (Linux/macOS)
- **test-api-commands.bat** - Pre-made curl commands (Windows)

---

## 🚀 Getting Started

### Choose Your Method

#### Method 1: Postman (Recommended - Easiest)
```
1. Import dropcity-api.postman_collection.json
2. Set variables (base_url, admin_token)
3. Click "Send" on any request
4. See response in real-time
```

#### Method 2: curl Commands
```
1. Open test-api-commands.sh or .bat
2. Set BASE_URL and ADMIN_TOKEN
3. Run the script
4. See API responses
```

#### Method 3: Manual curl
```
curl -H "Authorization: Bearer TOKEN" \
  http://localhost:8080/admin/alerts/rules
```

---

## 📋 Testing Workflows

### Quick Health Check (2 minutes)
```
✅ GET /                    (API health)
✅ GET /health/jobs         (Scheduler status)
```

### Alert System Testing (10 minutes)
```
✅ GET /admin/alerts/rules          (List rules)
✅ POST /admin/alerts/rules         (Create rule)
✅ PATCH /admin/alerts/rules/{id}   (Update rule)
✅ DELETE /admin/alerts/rules/{id}  (Delete rule)
✅ GET /admin/alerts/history        (View history)
```

### Error Tracking Testing (5 minutes)
```
✅ POST /logs                       (Log error)
✅ GET /admin/errors/summary        (Error stats)
✅ GET /admin/errors                (Error list)
```

### Admin Operations Testing (5 minutes)
```
✅ POST /admin/users/{uid}/role           (Set role)
✅ DELETE /admin/users/{uid}/role         (Clear role)
✅ POST /admin/parcels/assign             (Assign parcel)
```

---

## 🎯 Recommended Testing Sequence

### Step 1: Verify Backend Running
```
File: TESTING_QUICK_START.md
Time: 2 minutes
```

### Step 2: Import Postman Collection
```
File: dropcity-api.postman_collection.json
Time: 2 minutes
```

### Step 3: Set Variables
```
Section: "Set Variables" in TESTING_QUICK_START.md
Time: 3 minutes
```

### Step 4: Run Health Checks
```
Requests:
- System Health → Get API Health
- System Health → Get Scheduler Job Status
Time: 2 minutes
```

### Step 5: Test Alert System
```
Requests:
- Alert System → Get All Alert Rules
- Alert System → Create Alert Rule
- Alert System → Get Alert History
Time: 10 minutes
```

### Step 6: Test Error Tracking
```
Requests:
- Error Logging → Log Test Error
- Error Tracking → Get Error Summary
- Error Tracking → Get Errors with Filters
Time: 5 minutes
```

### Step 7: Test Admin Operations
```
Requests:
- Admin Operations → Set User Role
- Admin Operations → Assign Parcel to Courier
Time: 5 minutes
```

**Total Time: ~30 minutes for complete testing**

---

## 🔑 Getting Firebase Tokens

### Quick Way (Firebase Console)
```
1. Go to Firebase Console
2. Find your test user
3. Click "Copy UID"
4. Use Firebase Admin SDK to create token
```

### Using Firebase Admin SDK (Node.js)
```javascript
const admin = require('firebase-admin');

const uid = 'user-uid-here';
const token = await admin.auth().createCustomToken(uid);
console.log(token);
```

### Using REST API
```bash
curl -X POST https://identitytoolkit.googleapis.com/v1/accounts:signUp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"pass","returnSecureToken":true}' \
  | jq .idToken
```

---

## 📊 Endpoint Reference Quick Lookup

### Alert Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | /admin/alerts/rules | List all rules |
| POST | /admin/alerts/rules | Create rule |
| PATCH | /admin/alerts/rules/{id} | Update rule |
| DELETE | /admin/alerts/rules/{id} | Delete rule |
| GET | /admin/alerts/history | View history |

### Error Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /logs | Log error |
| GET | /admin/errors/summary | Error stats |
| GET | /admin/errors | Error list |

### Health Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | / | API health |
| GET | /health/jobs | Job status |

### Admin Endpoints
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | /admin/users/{uid}/role | Set role |
| DELETE | /admin/users/{uid}/role | Clear role |
| POST | /admin/parcels/assign | Assign parcel |

---

## 🧪 Test Cases by Feature

### Alert System
- [x] Create error spike alert
- [x] Create stuck job alert
- [x] Create failure rate alert
- [x] Update alert threshold
- [x] Enable/disable alert
- [x] Delete alert
- [x] View alert history
- [x] Filter history by rule

### Error Tracking
- [x] Log test errors
- [x] Get error summary
- [x] Filter errors by device
- [x] Filter errors by OS version
- [x] Paginate error list
- [x] View error details

### System Health
- [x] Check API health
- [x] Check heartbeat_watchdog status
- [x] Check check_alerts status
- [x] Verify job execution times
- [x] Monitor error counts

### Admin Operations
- [x] Set user as admin
- [x] Set user as courier
- [x] Set user as client
- [x] Clear user role
- [x] Assign parcel to courier
- [x] Verify assignment

---

## 🐛 Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | Check token in Variables is set |
| 403 Forbidden | Verify user has admin role |
| 404 Not Found | Check endpoint path is correct |
| Backend not found | Start: `cd backend && npm start` |
| No response | Check base_url is http://localhost:8080 |
| Expired token | Get new token from Firebase |
| Database error | Check Supabase connection |

---

## 💡 Testing Tips

### Tip 1: Use Postman Environments
```
1. Create separate environments for dev/staging/prod
2. Switch between them easily
3. Keep tokens organized
```

### Tip 2: Save Response Examples
```
1. Run successful request
2. Click "Save as example"
3. Reference later for comparison
```

### Tip 3: Use Postman Tests
```
Add Postman test for validation:

pm.test("Status is 200", function() {
  pm.response.to.have.status(200);
});
```

### Tip 4: Chain Requests
```
1. Create alert rule (returns ID)
2. Use ID in next request (PATCH, DELETE)
3. Automate multi-step workflows
```

### Tip 5: Monitor Backend Logs
```
Terminal 1: npm start (watch logs)
Terminal 2: Run Postman tests
See real-time logs of API execution
```

---

## 📈 Performance Testing

### Response Time Goals
| Endpoint | Target |
|----------|--------|
| GET /admin/alerts/rules | <200ms |
| POST /admin/alerts/rules | <300ms |
| GET /admin/errors | <500ms (with pagination) |
| GET /health/jobs | <150ms |

### Load Testing
Use Postman Runner to execute multiple requests:
1. Click "Runner" button
2. Select requests to run
3. Set iteration count
4. Monitor response times

---

## 🔍 Verification Checklist

Before considering testing complete:

- [ ] Backend running (GET / returns 200)
- [ ] Scheduler healthy (GET /health/jobs shows RUNNING)
- [ ] Can list alert rules (GET /admin/alerts/rules)
- [ ] Can create alert rule (POST succeeds, returns ID)
- [ ] Can update alert rule (PATCH changes values)
- [ ] Can delete alert rule (DELETE succeeds)
- [ ] Can view alert history (GET returns records)
- [ ] Can log errors (POST /logs succeeds)
- [ ] Can view error stats (GET /admin/errors/summary)
- [ ] Can filter errors (GET with query params)
- [ ] Can set user role (POST succeeds)
- [ ] Can assign parcels (POST succeeds)

---

## 📚 File Navigation

**Quick Start?** → Read [TESTING_QUICK_START.md](TESTING_QUICK_START.md)

**Detailed Guide?** → Read [POSTMAN_TESTING_GUIDE.md](POSTMAN_TESTING_GUIDE.md)

**API Details?** → Read [ALERTS_SETUP.md](../ALERTS_SETUP.md)

**Postman Collection?** → Import [dropcity-api.postman_collection.json](dropcity-api.postman_collection.json)

**Windows Setup?** → Run [setup-testing.bat](setup-testing.bat)

**Linux/macOS Setup?** → Run [setup-testing.sh](setup-testing.sh)

---

## 🎓 Learning Path

### Beginner (First Time Testing)
1. Read TESTING_QUICK_START.md
2. Import Postman collection
3. Run health check endpoints
4. Test one alert workflow

### Intermediate (Hands-On)
1. Read POSTMAN_TESTING_GUIDE.md
2. Test all workflows sequentially
3. Create custom test scenarios
4. Add Postman tests for validation

### Advanced (Automation)
1. Use Postman Runner for batch testing
2. Create request chains
3. Set up performance monitoring
4. Write test scripts

---

## 🚀 Next Steps After Testing

1. **Document Results**
   - Note any issues found
   - Record response times
   - Test data created

2. **Verify Functionality**
   - Alerts work end-to-end
   - Errors are tracked
   - Scheduler runs correctly

3. **Check Notifications** (if configured)
   - Alert messages sent to Slack
   - Email notifications received
   - SMS alerts working

4. **Performance Review**
   - Response times acceptable
   - No timeout issues
   - Database queries optimized

5. **Security Validation**
   - Auth tokens enforced
   - Role-based access works
   - Input validation present

---

## 📞 Support

### For Issues:
1. Check [POSTMAN_TESTING_GUIDE.md](POSTMAN_TESTING_GUIDE.md) troubleshooting
2. Review backend logs
3. Verify configuration in ALERTS_SETUP.md
4. Check Firebase token validity

### For Questions:
1. See [TESTING_QUICK_START.md](TESTING_QUICK_START.md)
2. Review [POSTMAN_TESTING_GUIDE.md](POSTMAN_TESTING_GUIDE.md)
3. Check endpoint examples in collection

---

## 📊 Test Results Template

```
Date: _____________
Tester: _____________
Environment: dev / staging / prod

Health Checks:
[ ] GET / → Status: ___ Response Time: ___
[ ] GET /health/jobs → Status: ___ Response Time: ___

Alert System:
[ ] GET /admin/alerts/rules → Status: ___ 
[ ] POST /admin/alerts/rules → Status: ___
[ ] PATCH /admin/alerts/rules/{id} → Status: ___
[ ] DELETE /admin/alerts/rules/{id} → Status: ___
[ ] GET /admin/alerts/history → Status: ___

Error Tracking:
[ ] POST /logs → Status: ___
[ ] GET /admin/errors/summary → Status: ___
[ ] GET /admin/errors → Status: ___

Admin Ops:
[ ] POST /admin/users/{uid}/role → Status: ___
[ ] POST /admin/parcels/assign → Status: ___

Issues Found:
1. ________________
2. ________________

Notes:
_____________________
```

---

**Status**: Complete Testing Suite ✅  
**Last Updated**: January 2024  
**Version**: 1.0.0  
**Ready to Test**: YES ✅
