# Courier Auth Flow - Quick Reference

## 🚀 Quick Start

### How to Use the Auth Flow in Your Code

#### 1. Access Current User
```dart
final user = context.read<AuthState>().user;
print(user?.email); // Current user's email
```

#### 2. Check if Authenticated
```dart
final isAuth = context.watch<AuthState>().isAuthenticated;
if (isAuth) {
  // Show authenticated content
} else {
  // Show login screen
}
```

#### 3. Perform Login
```dart
final authState = context.read<AuthState>();
bool success = await authState.loginCourier(
  email: 'user@example.com',
  password: 'password123',
);
if (success) {
  Navigator.pushNamed(context, '/dashboard');
} else {
  // Show error: authState.errorMessage
}
```

#### 4. Perform Signup (Multi-Step)
The signup controller handles this automatically. Just navigate to `/signup`:
```dart
Navigator.pushNamed(context, '/signup');
```

#### 5. Logout
```dart
context.read<AuthState>().signOut();
Navigator.pushReplacementNamed(context, '/login');
```

## 🗂️ Key Files

| File | Purpose |
|------|---------|
| `lib/screens/auth/splash_screen.dart` | Intro screen |
| `lib/screens/auth/welcome_screen.dart` | Signup/Login choice |
| `lib/screens/auth/login_screen.dart` | Simple login form |
| `lib/screens/auth/signup_screen.dart` | Multi-step container |
| `lib/controllers/signup_controller.dart` | Signup state management |
| `lib/auth/auth_state.dart` | Global auth state (Provider) |
| `lib/auth/auth_service.dart` | Firebase integration |
| `lib/main.dart` | Routes and app config |

## 🔄 Navigation Flow

```
/splash → /welcome → /signup (steps 1-4) → /dashboard
                   ↓
                /login → /dashboard
```

## 📱 Step-by-Step Signup

### Step 1: Email & Password
```dart
await controller.submitStep1(
  email: 'user@example.com',
  password: 'SecurePass123',
);
// Calls: POST /auth/signup/courier
// Result: Firebase account created, tokens received
```

### Step 2: Personal Info
```dart
await controller.submitStep2(
  fullName: 'John Doe',
  idNumber: 'ID123456789',
  idImagePath: '/path/to/image.jpg',
);
// Result: Image converted to base64, stored in controller
```

### Step 3: License
```dart
await controller.submitStep3(
  licenseNumber: 'DL987654321',
  licenseImagePath: '/path/to/license.jpg',
);
// Result: License image stored in controller
```

### Step 4: Vehicle & Submit
```dart
await controller.submitStep4(
  vehicleData: {
    'vehicle_type': 'Car',
    'vehicle_registration': 'ABC123',
    'vehicle_make': 'Toyota',
    'vehicle_model': 'Camry',
    'vehicle_year': 2022,
    'vehicle_color': 'White',
    'vehicle_capacity_kg': 200,
  },
  vehicleImagePaths: ['/path/to/pic1.jpg', '/path/to/pic2.jpg'],
);
// Calls: POST /users/courier/profile
// Submits: All collected data + base64 images
// Result: Profile saved, profile_complete = true
```

## 🎨 Color Reference

| Color | Hex | Usage |
|-------|-----|-------|
| Primary Orange | #FF6B35 | Buttons, icons, focus states |
| Dark Blue | #1a1a2e | Background |
| Darker Blue | #16213e | Accents |
| Error Red | #EF5350 | Error text |
| Grey (Light) | #A0A0A0 | Disabled, placeholders |
| Grey (Dark) | #404040 | Text, borders |

## ✅ Validation Rules

### Email
- Must match pattern: `^[^@]+@[^@]+\.[^@]+$`

### Password
- Minimum 8 characters
- Must match confirmation field

### ID Image
- Accepted formats: JPEG, PNG
- Max size: 12MB (after compression: ~500KB)
- Resolution: max 1024x1024

### Vehicle Photos
- 1-3 photos required at step 4
- Same size limits as ID image

## 🔐 Secure Practices

1. **Passwords**
   - Never logged or stored in plaintext
   - Always sent over HTTPS
   - Confirmed before submission

2. **Tokens**
   - Stored in secure platform storage
   - Refreshed automatically every 55 mins
   - Cleared on logout

3. **Images**
   - Compressed before transmission
   - Converted to base64 (not multipart)
   - Not stored on device after submission

## 🐛 Common Issues & Solutions

### Issue: Form validation not working
**Solution**: Ensure `setState()` is called after validation logic
```dart
setState(() {
  _emailError = 'Invalid email';
});
```

### Issue: Image picker not showing
**Solution**: Check app has camera permission in manifest
- Android: `AndroidManifest.xml` has camera permission
- iOS: `Info.plist` has camera usage description

### Issue: Images not uploading
**Solution**: Check file path exists before converting to base64
```dart
if (!File(imagePath).existsSync()) {
  throw Exception('Image file not found');
}
```

### Issue: Navigation not working
**Solution**: Ensure route name matches exactly in main.dart
```dart
// This must match the route definition
Navigator.pushNamed(context, '/signup');

// In main.dart:
'/signup': (context) => SignupScreen(),
```

### Issue: Provider not accessible
**Solution**: Wrap widget with Consumer or use context.read/watch
```dart
// Don't do this (will fail):
controller = context.read<CourierSignupController>();

// Do this instead:
Consumer<CourierSignupController>(
  builder: (context, controller, _) {
    // Now controller is accessible
  },
)

// Or use watch for reactive updates:
controller = context.watch<CourierSignupController>();
```

## 📊 State Diagram

```
AuthState
├── isAuthenticated: bool
├── user: AuthUser?
├── isBusy: bool
├── errorMessage: String?
└── Methods:
    ├── loginCourier(email, password) → Future<bool>
    ├── signupCourier(email, password) → Future<bool>
    ├── signOut() → Future<void>
    └── refreshSession() → Future<String?>

CourierSignupController
├── currentStep: int (1-5)
├── isLoading: bool
├── errorMessage: String?
├── Step completion checks:
│   ├── isStep1Complete
│   ├── isStep2Complete
│   ├── isStep3Complete
│   └── isStep4Complete
└── Methods:
    ├── submitStep1(email, password) → Future<bool>
    ├── submitStep2(name, id, image) → Future<bool>
    ├── submitStep3(license, image) → Future<bool>
    ├── submitStep4(vehicle, images) → Future<bool>
    ├── goBack() → void
    └── reset() → void
```

## 🔗 Backend Endpoints

### Authentication

```
POST /auth/signup/courier
Headers: Content-Type: application/json
Body: {
  "email": "user@example.com",
  "password": "password123",
  "displayName": "user"
}
Response: {
  "idToken": "eyJhbGc...",
  "refreshToken": "AEu4IL...",
  "localId": "uid123",
  "role": "courier"
}
```

```
POST /auth/login/courier
Headers: Content-Type: application/json
Body: {
  "email": "user@example.com",
  "password": "password123"
}
Response: {
  "idToken": "eyJhbGc...",
  "refreshToken": "AEu4IL...",
  "localId": "uid123",
  "role": "courier"
}
```

### Profile

```
POST /users/courier/profile
Headers: 
  - Authorization: Bearer {idToken}
  - Content-Type: application/json
Body: {
  "full_name": "John Doe",
  "id_number": "ID123456789",
  "id_image_url": "data:image/jpeg;base64,...",
  "license_number": "DL987654321",
  "license_image_url": "data:image/jpeg;base64,...",
  "vehicle_registration": "ABC123",
  "vehicle_registration_images": ["data:image/jpeg;base64,..."],
  "vehicle_type": "Car",
  "vehicle_make": "Toyota",
  "vehicle_model": "Camry",
  "vehicle_year": 2022,
  "vehicle_color": "White",
  "vehicle_capacity_kg": 200
}
Response: {
  "status": "ok",
  "message": "Courier profile saved successfully"
}
```

## 🧪 Testing Commands

### Run Flutter App
```bash
cd courier
flutter run
```

### Run with Specific Device
```bash
flutter devices  # List devices
flutter run -d <device_id>
```

### Enable Debug Logs
```dart
// In AuthState
debugPrint('[AuthState] Current step: ${_currentStep}');
```

### Test Login Flow
1. Tap "Log In" on welcome screen
2. Enter: `test@dropcity.dev` / `TestPass123`
3. Verify navigation to dashboard

### Test Signup Flow
1. Tap "Sign Up as Courier" on welcome screen
2. Complete all 4 steps:
   - Step 1: Any valid email/password
   - Step 2: Name + ID photo (from gallery or camera)
   - Step 3: License number + license photo
   - Step 4: Vehicle details + 1-3 photos
3. Verify success screen and dashboard navigation

## 📝 Debugging Tips

### Print Current State
```dart
print('AuthState: ${context.read<AuthState>()}');
print('Signup Step: ${context.read<CourierSignupController>().currentStep}');
```

### Monitor Navigation
```dart
// Add observer to MaterialApp:
navigatorObservers: [RouteObserver<PageRoute>()],
```

### Check Token Storage
```dart
final tokenStore = TokenStore();
final idToken = await tokenStore.getIdToken();
print('Stored ID Token: $idToken');
```

## 🎯 Best Practices

1. **Always use Consumer for reactive updates**
   ```dart
   Consumer<AuthState>(
     builder: (context, authState, _) { ... }
   )
   ```

2. **Handle errors explicitly**
   ```dart
   if (authState.errorMessage != null) {
     ScaffoldMessenger.of(context).showSnackBar(...);
   }
   ```

3. **Disable UI during loading**
   ```dart
   onPressed: controller.isLoading ? null : _handleSubmit,
   ```

4. **Show progress indicators**
   ```dart
   if (controller.isLoading) {
     return CircularProgressIndicator();
   }
   ```

5. **Validate before submission**
   ```dart
   if (!_validateForm()) return;
   ```

## 📚 Additional Resources

- [Provider Package Documentation](https://pub.dev/packages/provider)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Flutter Image Picker](https://pub.dev/packages/image_picker)
- [Flutter Forms & Validation](https://flutter.dev/docs/cookbook/forms)

---

**Last Updated**: Phase 5A Implementation
**Status**: ✅ Complete and Ready for Testing
