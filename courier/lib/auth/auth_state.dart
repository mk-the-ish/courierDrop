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
  Timer? _refreshTimer;

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
    notifyListeners();
    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      _scheduleRefresh();
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

  Future<void> restoreSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      await _authService.restoreSession();
      _scheduleRefresh();
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
