import 'package:flutter/foundation.dart';

/// Manages multi-step client onboarding flow
/// Step 1: Bio (name, username)
/// Step 2: ID Number + Photo
class ClientOnboardingController extends ChangeNotifier {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;

  // Step 1: Bio
  String? displayName;
  String? username;

  // Step 2: ID
  String? idNumber;
  String? idDocumentPath;
  String? idDocumentUrl;

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
                           username != null && username!.isNotEmpty;
  
  bool get isStep2Valid => idNumber != null && idNumber!.isNotEmpty &&
                           idDocumentUrl != null && idDocumentUrl!.isNotEmpty;

  /// Move to next step
  void nextStep() {
    if (_currentStep < 1) {
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
    if (step >= 0 && step <= 1) {
      _currentStep = step;
      _error = null;
      notifyListeners();
    }
  }

  /// Update Step 1 bio
  void updateBio({String? name, String? usernameVal}) {
    if (name != null) displayName = name;
    if (usernameVal != null) username = usernameVal;
    _error = null;
    notifyListeners();
  }

  /// Update Step 2 ID info
  void updateId({String? number, String? docPath}) {
    if (number != null) idNumber = number;
    if (docPath != null) idDocumentPath = docPath;
    _error = null;
    notifyListeners();
  }

  /// Set ID document URL after upload
  void setIdDocumentUrl(String url) {
    idDocumentUrl = url;
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
    username = null;
    idNumber = null;
    idDocumentPath = null;
    idDocumentUrl = null;
    _isVerified = false;
    _submittedAt = null;
    notifyListeners();
  }
}
