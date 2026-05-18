# Courier App Authentication Flow - Phase 5A Implementation

## Overview

This document describes the complete authentication flow implementation for the DropCity Courier app, featuring a modern multi-step signup workflow with real-time validation and secure credential management.

## Architecture

### Screens Flow

```
Splash Screen
    ↓
Welcome Screen (Signup / Login buttons)
    ├→ Signup Button → Multi-Step Signup (4 steps)
    │   ├→ Step 1: Email & Password
    │   ├→ Step 2: Personal Info (Name, ID Number, ID Image)
    │   ├→ Step 3: License Info (License Number, License Image)
    │   ├→ Step 4: Vehicle Info (Type, Make, Model, Year, Color, Capacity, Photos)
    │   └→ Completion Screen
    │
    └→ Login Button → Login Screen (Email & Password)
         ↓
    Dashboard (on success)
```

### State Management

The authentication system uses Provider pattern with three main components:

1. **AuthService** (`lib/auth/auth_service.dart`)
   - Low-level authentication operations
   - Firebase authentication integration
   - Token management and session refresh
   - Handles both generic and role-specific auth

2. **AuthState** (`lib/auth/auth_state.dart`)
   - ChangeNotifier for reactive updates
   - Manages user authentication state globally
   - Provides `loginCourier()` and `signupCourier()` methods
   - Tracks loading state and error messages
   - Auto-schedules token refresh every 55 minutes

3. **CourierSignupController** (`lib/controllers/signup_controller.dart`)
   - Manages multi-step signup workflow state
   - Handles image uploads and base64 encoding
   - Submits complete profile to backend at step 4
   - Tracks current step (1-5, with step 5 being completion)
   - Error handling with user-friendly messages

### Database Schema

The backend uses the following tables (created in migration 020):

```sql
-- users table (extended)
- id TEXT PRIMARY KEY
- email TEXT
- role TEXT ('COURIER', 'CLIENT', 'ADMIN')
- profile_step INTEGER (tracks completion)
- profile_complete BOOLEAN
- verification_status TEXT ('PENDING', 'APPROVED', 'REJECTED')

-- courier_profiles table
- id TEXT PRIMARY KEY (references users.id)
- full_name TEXT
- id_number TEXT UNIQUE
- id_image_url TEXT
- license_number TEXT UNIQUE
- license_image_url TEXT
- vehicle_registration TEXT UNIQUE
- vehicle_registration_images TEXT[] (array of URLs)
- vehicle_type TEXT
- vehicle_make TEXT
- vehicle_model TEXT
- vehicle_year INTEGER
- vehicle_color TEXT
- vehicle_capacity_kg DECIMAL
- profile_complete BOOLEAN
- verified_at TIMESTAMP
```

## Step-by-Step Implementation

### 1. Splash Screen

**File**: `lib/screens/auth/splash_screen.dart`

Features:
- Logo animation (fade + slide)
- Brand name and tagline
- "Continue" button to proceed

**Flow**:
```dart
SplashScreen
  → Tap Continue
  → Navigate to WelcomeScreen
```

### 2. Welcome Screen

**File**: `lib/screens/auth/welcome_screen.dart`

Features:
- Two call-to-action buttons:
  - "Sign Up as Courier" → Leads to multi-step signup
  - "Log In" → Leads to simple login screen
- Responsive layout
- Brand colors and gradient background

### 3. Multi-Step Signup

#### Controller

**File**: `lib/controllers/signup_controller.dart`

```dart
class CourierSignupController extends ChangeNotifier {
  int _currentStep = 1; // 1-5
  String? _email, _password, _fullName, _idNumber, _idImagePath;
  String? _licenseNumber, _licenseImagePath;
  Map<String, dynamic>? _vehicleData;
  List<String>? _vehicleImagePaths;
  
  bool _isLoading = false;
  String? _errorMessage;
  
  // Step completion checks
  bool get isStep1Complete => _email != null && _password != null;
  bool get isStep2Complete => _fullName != null && _idNumber != null && _idImagePath != null;
  
  // Methods
  Future<bool> submitStep1({required String email, required String password})
  Future<bool> submitStep2({required String fullName, required String idNumber, required String idImagePath})
  Future<bool> submitStep3({required String licenseNumber, required String licenseImagePath})
  Future<bool> submitStep4({required Map<String, dynamic> vehicleData, required List<String> vehicleImagePaths})
  
  void goBack() // Navigate to previous step
  void reset() // Reset entire flow
}
```

#### Step 1: Email & Password

**File**: `lib/screens/auth/signup_steps/step1_email.dart`

Form Fields:
- Email address (with validation)
- Password (minimum 8 characters)
- Confirm password (must match)

Validations:
- Email format check (regex)
- Password length ≥ 8 characters
- Password confirmation match

Backend Call:
```javascript
POST /auth/signup/courier
{
  "email": "user@example.com",
  "password": "securepass123",
  "displayName": "user"
}
Response:
{
  "idToken": "...",
  "refreshToken": "...",
  "localId": "...",
  "role": "courier"
}
```

#### Step 2: Personal Information

**File**: `lib/screens/auth/signup_steps/step2_personal.dart`

Form Fields:
- Full name
- National ID number
- ID image (camera capture)

Image Handling:
- Uses `image_picker` package for camera capture
- Compresses to max 1024x1024, quality 80
- Converts to base64 for transmission

Backend Call:
```javascript
// Image is uploaded as base64
POST /users/courier/profile
{
  "full_name": "John Doe",
  "id_number": "ID123456789",
  "id_image_url": "data:image/jpeg;base64,..." // base64 encoded
}
```

#### Step 3: Driving License

**File**: `lib/screens/auth/signup_steps/step3_license.dart`

Form Fields:
- Driving license number
- License image (camera capture)

Similar image handling as Step 2.

#### Step 4: Vehicle Information

**File**: `lib/screens/auth/signup_steps/step4_vehicle.dart`

Form Fields:
- Vehicle type (dropdown: Motorcycle, Scooter, Car, Van, Truck)
- Registration number
- Make and Model (side-by-side)
- Year and Color (side-by-side)
- Capacity in kg
- Vehicle photos (up to 3 images)

Grid Display:
- Shows uploaded images in 3-column grid
- Click to remove individual photos
- "Add Photo" button to upload more (max 3)

Final Submission:
```javascript
POST /users/courier/profile
{
  "full_name": "John Doe",
  "id_number": "ID123456789",
  "id_image_url": "data:image/jpeg;base64,...",
  "license_number": "LIC987654",
  "license_image_url": "data:image/jpeg;base64,...",
  "vehicle_registration": "ABC123",
  "vehicle_registration_images": ["data:image/jpeg;base64,...", ...],
  "vehicle_type": "Car",
  "vehicle_make": "Toyota",
  "vehicle_model": "Camry",
  "vehicle_year": 2022,
  "vehicle_color": "White",
  "vehicle_capacity_kg": 200
}
```

#### Completion Screen

Shows success message with checkmark and "Go to Dashboard" button.

### 4. Login Screen

**File**: `lib/screens/auth/login_screen.dart`

Form Fields:
- Email address
- Password
- "Forgot password?" link (placeholder for future implementation)

Backend Call:
```javascript
POST /auth/login/courier
{
  "email": "user@example.com",
  "password": "securepass123"
}
Response:
{
  "idToken": "...",
  "refreshToken": "...",
  "localId": "...",
  "role": "courier"
}
```

Success:
- Tokens stored in secure local storage
- Navigate to dashboard
- AuthState updates automatically
- Tracking service starts if needed

## UI/UX Features

### Animations

1. **Splash Screen**:
   - Fade-in animation (1.5s)
   - Slide-up animation for logo

2. **Progress Indicator**:
   - Shows current step (1/4, 2/4, etc.)
   - Linear progress bar fills as steps complete
   - Step name displayed

### Styling

- **Color Scheme**:
  - Primary: #FF6B35 (Orange)
  - Background: #1a1a2e (Dark Blue)
  - Accent: #16213e (Darker Blue)
  
- **Typography**:
  - Headlines: Bold, 24-28px
  - Body: Regular, 14-16px
  - Labels: Medium, 12-14px

- **Interactive Elements**:
  - Buttons: 16px vertical padding, 12px border radius
  - Text fields: 12px border radius, smooth focus transitions
  - Icons: Orange (#FF6B35) or grey depending on context

### Error Handling

1. **Field-Level Validation**:
   - Real-time format checking (email, number fields)
   - Length validation
   - Confirmation matching

2. **Form-Level Errors**:
   - Display below each field
   - Red (#EF5350) error text
   - Clear error messages

3. **Network Errors**:
   - Bottom snackbar with error message
   - Retry capability
   - Timeout handling (30 seconds)

## Navigation

### Routes Configuration

```dart
routes: {
  '/': (context) => _LaunchScreen(), // Restore session
  '/splash': (context) => const SplashScreen(),
  '/welcome': (context) => const WelcomeScreen(),
  '/login': (context) => const LoginScreen(),
  '/signup': (context) => ChangeNotifierProvider(
    create: (_) => CourierSignupController(...),
    child: const SignupScreen(),
  ),
  '/dashboard': (context) => HomeScreen(...),
}
```

### Navigation Flow

```
App Launch
  ↓
_restoreSession() in background
  ├→ Session restored → Go to /dashboard
  ├→ No session → Redirect to /splash
  └→ Timeout → Show continue button
  
User Signup Flow:
  /splash → /welcome → /signup
    ↓
  Step 1-4 progression
    ↓
  On Step 4 success → Completion screen → /dashboard
    
User Login Flow:
  /welcome → /login → /dashboard
```

## Security Considerations

1. **Password Security**:
   - Minimum 8 characters enforced client-side
   - Sent over HTTPS only
   - Firebase handles password hashing

2. **Token Management**:
   - Tokens stored in secure local storage (platform-specific):
     - iOS: Keychain
     - Android: EncryptedSharedPreferences
   - Auto-refresh every 55 minutes
   - Clear on logout

3. **Image Handling**:
   - Compressed before transmission (max 1024x1024)
   - Sent as base64 in request body
   - Backend validates image format
   - Could enhance with server-side upload using signed URLs

4. **Rate Limiting**:
   - Backend: 20 auth requests per 10 minutes per IP
   - Frontend: Disable submit button during request

## Testing Checklist

- [ ] Splash screen animation plays smoothly
- [ ] Welcome screen buttons navigate correctly
- [ ] Step 1 form validation works (email, password match)
- [ ] Step 2 camera picker opens and image displays
- [ ] Step 3 license upload works
- [ ] Step 4 vehicle form with photo grid works
- [ ] Back button navigates to previous step
- [ ] Close button (X) exits signup and returns to welcome
- [ ] Completion screen shows after successful submission
- [ ] Progress bar updates correctly
- [ ] Login screen validates email and password
- [ ] Error messages display properly
- [ ] Loading indicators show during submission
- [ ] Tokens stored correctly after login/signup
- [ ] Dashboard loads after successful auth
- [ ] Session restoration works on app restart

## Future Enhancements

1. **Image Upload Optimization**:
   - Implement signed URL uploads to AWS S3
   - Client-side image cropping
   - Multiple image formats (PNG, WEBP)

2. **Profile Verification**:
   - Admin dashboard for profile review
   - Email verification step
   - Phone number verification (SMS)
   - Document OCR for ID/License auto-fill

3. **Social Login**:
   - Google Sign-In integration
   - Apple Sign-In (for iOS)

4. **Enhanced Validation**:
   - Real-time email existence check
   - License number format validation (per country)
   - Vehicle registration format validation

5. **Biometric Authentication**:
   - Fingerprint/Face ID login option
   - Stored biometric bypass after verification

## Files Reference

```
courier/lib/
├── screens/auth/
│   ├── splash_screen.dart (brand intro, continue button)
│   ├── welcome_screen.dart (signup/login choice)
│   ├── login_screen.dart (simple email/password login)
│   ├── signup_screen.dart (container for multi-step flow)
│   └── signup_steps/
│       ├── step1_email.dart
│       ├── step2_personal.dart
│       ├── step3_license.dart
│       └── step4_vehicle.dart
├── controllers/
│   └── signup_controller.dart (multi-step state management)
├── auth/
│   ├── auth_state.dart (global auth state, ChangeNotifier)
│   ├── auth_service.dart (Firebase integration, token storage)
│   └── auth.dart (auth models)
└── main.dart (app entry, route configuration)

backend/src/routes/
├── auth.js (POST /auth/signup/courier, /auth/login/courier)
└── users.js (POST /users/courier/profile)

backend/sql/
└── 020_auth_and_profiles.sql (courier_profiles, client_profiles tables)
```

## Backend Endpoints Summary

### Authentication

1. **POST /auth/signup/courier** - Create courier account
   - Request: `{ email, password, displayName }`
   - Response: `{ idToken, refreshToken, localId, role }`

2. **POST /auth/login/courier** - Login courier
   - Request: `{ email, password }`
   - Response: `{ idToken, refreshToken, localId, role }`

3. **POST /auth/refresh** - Refresh tokens
   - Request: `{ refreshToken }`
   - Response: `{ idToken, refreshToken, expiresIn }`

### Profile Management

1. **POST /users/courier/profile** - Save complete courier profile
   - Requires: `Authorization: Bearer {idToken}`
   - Request: Full courier profile data including images as base64
   - Response: `{ status: "ok", message: "..." }`

2. **GET /users/me** - Get current user profile
   - Requires: `Authorization: Bearer {idToken}`
   - Response: User and profile data

## Appendix: Code Snippets

### Using AuthState in a Widget

```dart
Consumer<AuthState>(
  builder: (context, authState, _) {
    if (authState.isLoading) {
      return CircularProgressIndicator();
    }
    
    if (authState.isAuthenticated) {
      return Text('Welcome ${authState.user?.email}');
    }
    
    return ElevatedButton(
      onPressed: () {
        authState.loginCourier(
          email: 'user@example.com',
          password: 'password123',
        );
      },
      child: Text('Login'),
    );
  },
)
```

### Using CourierSignupController

```dart
Consumer<CourierSignupController>(
  builder: (context, controller, _) {
    return Column(
      children: [
        Text('Step ${controller.currentStep} of 4'),
        if (controller.errorMessage != null)
          Text(controller.errorMessage!, style: TextStyle(color: Colors.red)),
        ElevatedButton(
          onPressed: controller.isLoading ? null : () => _handleNext(),
          child: Text('Next'),
        ),
      ],
    );
  },
)
```
