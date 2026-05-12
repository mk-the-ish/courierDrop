import 'package:flutter/foundation.dart';

/// Manages multi-step courier onboarding flow
/// Step 1: Bio (name, phone)
/// Step 2: ID/License + Photos
/// Step 3: Vehicle Details + Photos
class CourierOnboardingController extends ChangeNotifier {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;

  // Step 1: Bio
  String? displayName;
  String? phoneNumber;

  // Step 2: ID & License
  String? idDocumentPath;
  String? licenseDocumentPath;
  String? idDocumentUrl;
  String? licenseDocumentUrl;

  // Step 3: Vehicle
  String? vehicleType;
  String? vehicleMake;
  String? vehicleModel;
  int? vehicleYear;
  String? vehicleColor;
  String? licensePlate;
  int? maxCapacityKg;
  String? vehicleDocumentPath;
  String? vehicleDocumentUrl;

  // Overall status
  bool _isVerified = false;
  DateTime? _submittedAt;

  // Getters
  int get currentStep => _currentStep;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isVerified => _isVerified;
  DateTime? get submittedAt => _submittedAt;

  bool get isStep1Valid => displayName != null && displayName!.isNotEmpty && 
                           phoneNumber != null && phoneNumber!.isNotEmpty;
  
  bool get isStep2Valid => idDocumentUrl != null && licenseDocumentUrl != null;
  
  bool get isStep3Valid => vehicleType != null && vehicleType!.isNotEmpty &&
                          licensePlate != null && licensePlate!.isNotEmpty &&
                          vehicleDocumentUrl != null;

  /// Move to next step
  void nextStep() {
    if (_currentStep < 2) {
      _currentStep++;
      _error = null;
      notifyListeners();
    }
  }

  /// Move to previous step
  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _error = null;
      notifyListeners();
    }
  }

  /// Go to specific step
  void goToStep(int step) {
    if (step >= 0 && step <= 2) {
      _currentStep = step;
      _error = null;
      notifyListeners();
    }
  }

  /// Update Step 1 bio
  void updateBio({String? name, String? phone}) {
    if (name != null) displayName = name;
    if (phone != null) phoneNumber = phone;
    _error = null;
    notifyListeners();
  }

  /// Update Step 2 document paths
  void updateDocuments({String? idPath, String? licensePath}) {
    if (idPath != null) idDocumentPath = idPath;
    if (licensePath != null) licenseDocumentPath = licensePath;
    _error = null;
    notifyListeners();
  }

  /// Set document URLs after upload
  void setDocumentUrls({String? idUrl, String? licenseUrl}) {
    if (idUrl != null) idDocumentUrl = idUrl;
    if (licenseUrl != null) licenseDocumentUrl = licenseUrl;
    notifyListeners();
  }

  /// Update Step 3 vehicle details
  void updateVehicle({
    String? type,
    String? make,
    String? model,
    int? year,
    String? color,
    String? plate,
    int? capacity,
  }) {
    if (type != null) vehicleType = type;
    if (make != null) vehicleMake = make;
    if (model != null) vehicleModel = model;
    if (year != null) vehicleYear = year;
    if (color != null) vehicleColor = color;
    if (plate != null) licensePlate = plate;
    if (capacity != null) maxCapacityKg = capacity;
    _error = null;
    notifyListeners();
  }

  /// Set vehicle document URL after upload
  void setVehicleDocumentUrl(String url) {
    vehicleDocumentUrl = url;
    notifyListeners();
  }

  /// Mark as loading
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error message
  void setError(String? err) {
    _error = err;
    notifyListeners();
  }

  /// Submit complete onboarding
  void markSubmitted() {
    _submittedAt = DateTime.now();
    _isVerified = false; // Will be set to true after admin approval
    notifyListeners();
  }

  /// Reset to initial state
  void reset() {
    _currentStep = 0;
    _isLoading = false;
    _error = null;
    displayName = null;
    phoneNumber = null;
    idDocumentPath = null;
    licenseDocumentPath = null;
    idDocumentUrl = null;
    licenseDocumentUrl = null;
    vehicleType = null;
    vehicleMake = null;
    vehicleModel = null;
    vehicleYear = null;
    vehicleColor = null;
    licensePlate = null;
    maxCapacityKg = null;
    vehicleDocumentPath = null;
    vehicleDocumentUrl = null;
    _isVerified = false;
    _submittedAt = null;
    notifyListeners();
  }
}
