import 'dart:io';
import 'package:flutter/material.dart';

import '../api/api_client.dart';

class CourierSignupStep {
  final int step;
  final String title;

  CourierSignupStep({required this.step, required this.title});
}

class CourierSignupController extends ChangeNotifier {
  final ApiClient _apiClient;

  int _currentStep = 1; // 1: email, 2: personal, 3: license, 4: vehicle
  String? _email;
  String? _password;
  String? _fullName;
  String? _idNumber;
  String? _idImagePath;
  String? _licenseNumber;
  String? _licenseImagePath;
  Map<String, dynamic>? _vehicleData;
  List<String>? _vehicleImagePaths;

  bool _isLoading = false;
  String? _errorMessage;

  CourierSignupController(this._apiClient);

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isStep1Complete => _email != null && _password != null;
  bool get isStep2Complete => _fullName != null && _idNumber != null && _idImagePath != null;
  bool get isStep3Complete => _licenseNumber != null && _licenseImagePath != null;
  bool get isStep4Complete => _vehicleData != null && _vehicleImagePaths != null;

  // Step 1: Email & Password
  Future<bool> submitStep1({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = await _signUpOrSignIn(email: email, password: password);
      if (auth.idToken.isEmpty) {
        throw Exception("Authentication token missing after signup.");
      }

      _apiClient.setAuthToken(auth.idToken);
      await _apiClient.setupUserRole(role: "courier");

      _email = email;
      _password = password;
      _currentStep = 2;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<AuthResponse> _signUpOrSignIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _apiClient.signUp(
        email: email,
        password: password,
        displayName: email.split("@")[0],
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final alreadyExists =
          msg.contains("already in use") || msg.contains("email_exists");
      if (!alreadyExists) {
        rethrow;
      }
      return await _apiClient.login(email: email, password: password);
    }
  }

  // Step 2: Personal Info
  Future<bool> submitStep2({
    required String fullName,
    required String idNumber,
    required String idImagePath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload ID image using multipart
      final idImageUrl = await _apiClient.uploadOnboardingDocument(
        idImagePath,
        kind: 'id',
      );

      _fullName = fullName;
      _idNumber = idNumber;
      _idImagePath = idImageUrl;
      _currentStep = 3;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Step 3: License
  Future<bool> submitStep3({
    required String licenseNumber,
    required String licenseImageFrontPath,
    required String licenseImageBackPath,
    DateTime? expiryDate,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload both license images using 'license' kind
      // The backend stores the last uploaded one, so we upload front then back
      // and track both URLs locally for the final profile submission
      final frontUrl = await _apiClient.uploadOnboardingDocument(
        licenseImageFrontPath,
        kind: 'license',
      );

      final backUrl = await _apiClient.uploadOnboardingDocument(
        licenseImageBackPath,
        kind: 'license',
      );

      _licenseNumber = licenseNumber;
      _licenseImagePath = frontUrl; // Store front image URL
      // TODO: Need to store backUrl as well for profile submission
      // For now, the backend will have the last uploaded (back) image
      _currentStep = 4;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Step 4: Vehicle & Complete
  Future<bool> submitStep4({
    required Map<String, dynamic> vehicleData,
    required List<String> vehicleImagePaths,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Upload vehicle images using 'vehicle' kind
      final uploadedImageUrls = <String>[];
      for (final imagePath in vehicleImagePaths) {
        final url = await _apiClient.uploadOnboardingDocument(
          imagePath,
          kind: 'vehicle',
        );
        uploadedImageUrls.add(url);
      }

      // Submit complete profile to backend
      await _apiClient.submitCourierProfile(
        fullName: _fullName!,
        idNumber: _idNumber!,
        idImageUrl: _idImagePath!,
        licenseNumber: _licenseNumber!,
        licenseImageUrl: _licenseImagePath!,
        vehicleRegistration: vehicleData['vehicle_registration'],
        vehicleRegistrationImages: uploadedImageUrls,
        vehicleType: vehicleData['vehicle_type'],
        vehicleMake: vehicleData['vehicle_make'],
        vehicleModel: vehicleData['vehicle_model'],
        vehicleYear: vehicleData['vehicle_year'],
        vehicleColor: vehicleData['vehicle_color'],
        vehicleCapacityKg: vehicleData['vehicle_capacity_kg'],
      );

      _vehicleData = vehicleData;
      _vehicleImagePaths = uploadedImageUrls;
      _currentStep = 5; // Completed
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Go back one step
  void goBack() {
    if (_currentStep > 1) {
      _currentStep--;
      notifyListeners();
    }
  }

  // Reset for restart
  void reset() {
    _currentStep = 1;
    _email = null;
    _password = null;
    _fullName = null;
    _idNumber = null;
    _idImagePath = null;
    _licenseNumber = null;
    _licenseImagePath = null;
    _vehicleData = null;
    _vehicleImagePaths = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
