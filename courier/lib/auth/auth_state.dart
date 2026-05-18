import "dart:async";

import "package:flutter/foundation.dart";

import "auth_service.dart";
import "../api/api_client.dart";

class AuthState extends ChangeNotifier implements ValueListenable<Object?> {
  AuthState(this._authService);

  final AuthService _authService;

  AuthUser? get user => _authService.currentUser;
  ApiClient get apiClient => _authService.apiClient;

  bool get isAuthenticated => user != null;

  bool get isBusy => _isBusy;

  @override
  Object? get value => isBusy;

  bool _isBusy = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  String? get errorMessage => _errorMessage;

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!isAuthenticated) {
      return;
    }
    _refreshTimer = Timer(const Duration(minutes: 55), () {
      refreshSession();
    });
  }

  Future<void> signIn(String email, String password) async {
    _isBusy = true;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      _scheduleRefresh();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signUp(String email, String password, {String? displayName, String? role}) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      _scheduleRefresh();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // Courier-specific login
  Future<bool> loginCourier({required String email, required String password}) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
      _scheduleRefresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  // Courier-specific signup
  Future<bool> signupCourier({required String email, required String password}) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: email.split('@')[0],
        role: 'courier',
      );
      _scheduleRefresh();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isBusy = true;
    notifyListeners();
    try {
      await _authService.signOut();
      _refreshTimer?.cancel();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      final restored = await _authService.restoreSession();
      _scheduleRefresh();
      return restored;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> refreshSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      final token = await _authService.refreshSession();
      _scheduleRefresh();
      return token;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
