# Testing Phase 5A: Courier Auth Flow

## 🚀 Getting Started

### Prerequisites
```bash
# Install Flutter (if not already done)
flutter --version

# Ensure emulator or device is running
flutter devices

# Install dependencies
cd courier
flutter pub get
```

### Build & Run

```bash
# Run in debug mode
flutter run

# Run with verbose logging
flutter run -v

# Run on specific device
flutter devices  # List devices
flutter run -d <device_id>

# Run with specific flavor (if applicable)
flutter run --flavor dev

# Build APK
flutter build apk

# Build IPA (iOS)
flutter build ios
```

## 📱 Testing Scenarios

### Scenario 1: App Startup (Fresh Install)

**Expected Flow**:
```
App starts
  ↓
LaunchScreen (loading indicator)
  ↓
Session restoration in background (1-2 seconds)
  ↓
/splash route (SplashScreen)
  ↓
User taps "Continue" button
  ↓
/welcome route (WelcomeScreen)
```

**Test Steps**:
1. Fresh install on device
2. Launch app
3. Observe splash screen animations
4. Verify continue button works
5. Verify navigation to welcome screen

**Expected Results**:
- [x] Splash screen displays
- [x] Logo animation plays
- [x] "Continue" button is clickable
- [x] Navigates to welcome screen

---

### Scenario 2: Complete Signup Flow

**Test Path**: `/welcome` → `/signup` (steps 1-4) → success → `/dashboard`

#### 2a. Tap "Sign Up as Courier"

**Expected**:
- Navigate to `/signup`
- Show Step 1 form
- Progress bar at 25%
- Step text shows "Step 1 of 4: Email"

**Test**:
```
1. From welcome screen, tap "Sign Up as Courier" button
2. Verify navigation to signup
3. Verify progress indicator shows 1/4
4. Verify step name "Email"
```

#### 2b. Step 1: Email & Password

**Fill Form**:
```
Email: test.courier.1@dropcity.dev
Password: TestPassword123
Confirm: TestPassword123
```

**Invalid Test Cases**:
```
Email: invalid-email
Expected: "Please enter a valid email" error

Email: valid@test.com
Password: short
Expected: "Password must be at least 8 characters" error

Email: valid@test.com
Password: TestPassword123
Confirm: Different123
Expected: "Passwords do not match" error
```

**Valid Submission**:
```
1. Fill all fields with valid data
2. Tap "Next" button
3. Verify loading indicator appears
4. Wait for backend response
5. Verify navigation to Step 2
```

#### 2c. Step 2: Personal Information

**Expected**:
- Progress bar at 50%
- "Step 2 of 4: Personal" displayed
- Back button visible
- Close (X) button visible

**Fill Form**:
```
Full Name: John Courier Test
ID Number: TEST123456789
ID Photo: (capture from camera or gallery)
```

**Test Back Navigation**:
```
1. Tap back button
2. Verify return to Step 1
3. Verify Step 1 data is preserved
4. Tap "Next" again to return to Step 2
```

**Test Image Upload**:
```
1. Tap on image upload area
2. Camera picker opens
3. Take a photo (or select from gallery)
4. Verify image preview displays
5. Tap "Next" to submit
```

**Test Image Removal**:
```
1. After uploading image
2. Tap "X" button on image
3. Verify image removed
4. Upload new image (if needed)
```

#### 2d. Step 3: License

**Expected**:
- Progress bar at 75%
- "Step 3 of 4: License" displayed

**Fill Form**:
```
License Number: DL98765432101
License Photo: (capture or select)
```

**Test**:
```
1. Fill license number
2. Upload license photo
3. Verify form validation
4. Tap "Next" to continue
```

#### 2e. Step 4: Vehicle Information

**Expected**:
- Progress bar at 100%
- "Step 4 of 4: Vehicle" displayed
- "Complete Profile" button instead of "Next"

**Fill Form**:
```
Vehicle Type: Car (from dropdown)
Registration: ABC123XYZ
Make: Toyota
Model: Camry
Year: 2022
Color: White
Capacity: 150 (kg)
Photos: Upload 1-3 photos
```

**Test Dropdown**:
```
1. Tap Vehicle Type dropdown
2. Verify all options visible:
   - Motorcycle
   - Scooter
   - Car
   - Van
   - Truck
3. Select "Car"
4. Verify selection displayed
```

**Test Photo Grid**:
```
1. Tap "Add Photo" button
2. Capture/select first photo
3. Verify image displays in grid
4. Repeat for up to 3 photos
5. Verify remove (X) buttons work
6. Verify "Add Photo" button disabled at 3 photos
```

**Test Form Validation**:
```
Empty fields should prevent submission:
- Leave Vehicle Type empty → Error: "Please select vehicle type"
- Leave Registration empty → Error: "Registration number is required"
- Leave Capacity empty → Error: "Capacity is required"
- Enter non-numeric capacity → Error: "Please enter a valid number"
- Upload 0 photos → Error: "Please upload at least one vehicle image"
```

**Submit Complete Profile**:
```
1. Fill all fields with valid data
2. Upload 1-3 vehicle photos
3. Tap "Complete Profile" button
4. Verify loading indicator
5. Wait for backend response (2-5 seconds)
6. Verify success screen displays
```

#### 2f. Success Screen

**Expected**:
- Green checkmark icon
- "Welcome to DropCity!" title
- "Your profile has been created..." message
- "Go to Dashboard" button

**Test**:
```
1. Verify success screen displays
2. Verify all text is readable
3. Tap "Go to Dashboard" button
4. Verify navigation to /dashboard
5. Verify dashboard loads with user data
```

---

### Scenario 3: Close/Cancel Signup

**Test Path**: `/welcome` → `/signup` → Close button → back to `/welcome`

**Test**:
```
1. From welcome, tap "Sign Up as Courier"
2. At any step, tap "X" (close) button
3. Verify dialog appears asking for confirmation (if implemented)
4. Confirm close
5. Verify navigation back to /welcome
6. Verify signup state is reset
```

---

### Scenario 4: Login Flow

**Test Path**: `/welcome` → `/login` → submit → `/dashboard`

#### 4a. Navigate to Login

**Test**:
```
1. From welcome, tap "Log In" button
2. Verify navigation to /login
3. Verify login form displays
4. Verify email and password fields present
5. Verify "Log In" button present
6. Verify "Sign Up" link present
7. Verify "Forgot password?" link present
```

#### 4b. Invalid Credentials

**Test Cases**:
```
Email: invalid-email
Expected: "Please enter a valid email" error

Email: (empty)
Expected: "Email is required" error

Email: test@test.com
Password: (empty)
Expected: "Password is required" error

Email: nonexistent@test.com
Password: WrongPass123
Expected: Server response error displayed
```

#### 4c. Valid Login

**Test**:
```
1. Enter valid credentials:
   Email: test.courier@dropcity.dev
   Password: (password set during signup)
2. Tap "Log In" button
3. Verify loading indicator
4. Wait for response
5. Verify error or success message
6. On success, verify navigation to /dashboard
```

#### 4d. Show/Hide Password

**Test**:
```
1. On login screen, enter a password
2. Verify text is hidden (dots/asterisks)
3. Tap eye icon to show password
4. Verify password is now visible
5. Tap eye icon again to hide
6. Verify password is hidden again
```

---

### Scenario 5: Error Handling

#### 5a. Network Error

**Simulate Offline**:
```
1. Turn off WiFi and mobile data
2. Try to submit signup step 1
3. Verify timeout error message appears
4. Verify form is not cleared
5. Verify can edit and retry
6. Turn wifi back on
7. Verify submission succeeds
```

#### 5b. Backend Error

**Test**:
```
1. Try to signup with existing email
   (if backend validation exists)
2. Verify error message from backend
3. Verify user can correct and retry
4. Verify form state is preserved
```

#### 5c. Image Upload Error

**Test**:
```
1. Try to upload corrupted image file
   (if applicable)
2. Verify error message
3. Verify can upload different image
4. Verify process continues
```

---

### Scenario 6: Session Management

#### 6a. Token Refresh

**Test**:
```
1. Login to app
2. Wait 1 hour (or use time manipulation)
3. Try any authenticated action
4. Verify token is silently refreshed
5. Verify action completes without interruption
```

#### 6b. Token Expiry

**Test**:
```
1. Login to app
2. Clear saved tokens (emulator tool or app)
3. Try any action requiring auth
4. Verify redirected to login
5. Verify error message about session
```

#### 6c. Logout

**Test**:
```
1. Login to app
2. Navigate to settings/profile (if applicable)
3. Tap "Logout" or similar
4. Verify tokens cleared
5. Verify navigation to /login
6. Verify next app launch shows /splash
```

---

### Scenario 7: Navigation & Back Button

#### 7a. In-App Navigation

**Test**:
```
Signup Steps:
1. Step 1 → Step 2: Tap Next → Step 2 shows
2. Step 2 → Step 3: Tap Next → Step 3 shows
3. Step 3 → Step 4: Tap Next → Step 4 shows
4. Step 4 → Success: Tap Complete Profile → Success shows
5. Success → Dashboard: Tap Go to Dashboard → Dashboard loads

Back Navigation:
1. Step 2 → Step 1: Tap Back → Step 1 shows (data preserved)
2. Step 3 → Step 2: Tap Back → Step 2 shows (data preserved)
3. Step 4 → Step 3: Tap Back → Step 3 shows (data preserved)
```

#### 7b. Hardware Back Button

**Test (Android)**:
```
1. At Step 2 or later, press hardware back button
2. Verify back navigation works (if handling implemented)
3. Or verify dialog asking to confirm exit (implementation-specific)
```

---

## 🎯 Test Data

### Test Accounts (For Backend Testing)

```
Account 1 - Motorcycle Courier:
Email: test.moto@dropcity.dev
Password: TestMoto12345
Vehicle: Motorcycle

Account 2 - Car Courier:
Email: test.car@dropcity.dev
Password: TestCar123456
Vehicle: Car

Account 3 - Van Courier:
Email: test.van@dropcity.dev
Password: TestVan123456
Vehicle: Van
```

### Test Images

**Create dummy images for testing**:

```bash
# For ID image (minimal valid image):
# Can use any photo from device gallery
# Or use placeholder from camera

# For License image:
# Can use any photo, doesn't need real license

# For Vehicle images:
# Can be any 3 photos of any vehicle
# Can be duplicates for testing
```

---

## 🐛 Debugging

### Enable Debug Logging

**In terminal**:
```bash
flutter run -v
```

**In code**:
```dart
// Add to auth_state.dart
debugPrint('[AuthState] Current state: isAuthenticated=$isAuthenticated, step=$currentStep');

// Add to signup_controller.dart
debugPrint('[SignupController] Step ${_currentStep} submitted');
```

### Check Network Requests

**Using Charles Proxy or Fiddler**:
```
1. Configure device to use proxy
2. Monitor all HTTP/HTTPS traffic
3. Verify payload being sent
4. Verify response from backend
5. Check error codes and messages
```

### Local Storage

**Check Saved Tokens**:
```bash
# Android (via adb):
adb shell "pm grant com.example.app android.permission.READ_LOGS"
adb shell dumpsys package com.example.app

# Or use Android Studio Device File Explorer:
# Open Device File Explorer
# Navigate to: data/data/com.example.app/shared_prefs/
```

### Firebase Console

```
1. Go to Firebase Console
2. Select project "dropcity-courier" (or your project)
3. Navigate to: Authentication → Users
4. Check new user accounts are created
5. Verify email addresses match test data
```

---

## 📊 Performance Metrics

### Benchmark Targets

```
Splash Screen:
- Animation duration: ~1.5 seconds ✓
- Navigation time: <200ms

Welcome Screen:
- Load time: <100ms
- Button response: <100ms

Signup Form:
- Validation: <50ms
- Form submission: 2-5 seconds (network dependent)

Image Compression:
- Time: <500ms per image
- File size reduction: 70-80%

Navigation:
- Route change: <150ms
- Back button response: <100ms
```

### Current Performance

**Run with diagnostics**:
```bash
flutter run --enable-checking-null-safety
```

---

## ✅ Test Checklist

### Pre-Testing

- [ ] App builds successfully
- [ ] Device/emulator available
- [ ] Internet connection working
- [ ] Backend server accessible
- [ ] Test accounts created (optional)

### Splash Screen Tests

- [ ] Displays on app launch
- [ ] Animation plays smoothly
- [ ] "Continue" button clickable
- [ ] Navigation works

### Welcome Screen Tests

- [ ] Displays after splash
- [ ] "Sign Up" button works
- [ ] "Log In" button works
- [ ] Layout responsive
- [ ] All text readable

### Signup Form Tests

- [ ] Progress indicator accurate
- [ ] All form fields functional
- [ ] Validation messages correct
- [ ] Image upload works
- [ ] Back navigation works
- [ ] Close button works

### Login Tests

- [ ] Form displays correctly
- [ ] Validation works
- [ ] Successful login redirects
- [ ] Error messages show

### Backend Integration

- [ ] Login succeeds with valid credentials
- [ ] Signup creates user account
- [ ] Profile saved correctly
- [ ] Tokens stored securely

### Error Handling

- [ ] Network errors handled
- [ ] Server errors displayed
- [ ] Validation errors clear
- [ ] Can retry after error

### Session Management

- [ ] Tokens persist across sessions
- [ ] Auto-login on restart
- [ ] Logout clears tokens
- [ ] Session timeout handled

---

## 📝 Bug Report Template

**When Testing, If You Find a Bug**:

```
**Title**: [Component] Issue description

**Steps to Reproduce**:
1. 
2. 
3. 

**Expected Result**:

**Actual Result**:

**Environment**:
- Device: (iPhone 12 / Pixel 4 / Emulator)
- OS: (iOS 15 / Android 12)
- Flutter version: (flutter --version)

**Logs**:
(Paste relevant debug logs)

**Screenshots/Videos**:
(Attach if possible)

**Severity**: (Critical / High / Medium / Low)
```

---

## 🎬 Video Recording Guide

### Record Test Session

```bash
# iOS Simulator:
1. Simulator → Device → Record Screen
2. Perform test steps
3. Stop recording
4. Save to desktop

# Android Emulator:
1. Terminal: adb shell screenrecord /sdcard/test.mp4
2. Perform test steps
3. Terminal: adb pull /sdcard/test.mp4 ~/Desktop/
```

### Share Findings

1. Record video of issue
2. Note exact steps
3. Include error messages
4. Attach logs
5. Share with team

---

## 📞 Support & Escalation

**If You Encounter Issues**:

1. **Check Documentation**:
   - COURIER_AUTH_IMPLEMENTATION.md
   - COURIER_AUTH_QUICK_REFERENCE.md

2. **Review Code**:
   - Check for syntax errors
   - Verify imports
   - Check backend connectivity

3. **Debug**:
   - Run with verbose logging
   - Check network requests
   - Monitor Firebase console

4. **Report**:
   - Use bug report template
   - Include all diagnostic info
   - Attach reproduction steps

---

**Happy Testing! 🚀**

For questions or issues, refer to the implementation documentation or contact the development team.
