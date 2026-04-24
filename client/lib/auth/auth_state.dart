import "package:flutter/foundation.dart";

import "auth_service.dart";
import "../api/api_client.dart";

class AuthState extends ChangeNotifier {
  AuthState(this._authService);

  final AuthService _authService;

  AuthUser? get user => _authService.currentUser;
  ApiClient get apiClient => _authService.apiClient;

  bool get isAuthenticated => user != null;

  bool get isBusy => _isBusy;

  bool _isBusy = false;

  Future<void> signIn(String email, String password) async {
    _isBusy = true;
    notifyListeners();
    try {
      await _authService.signIn(email: email, password: password);
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
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<String?> refreshSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      return await _authService.refreshSession();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> restoreSession() async {
    _isBusy = true;
    notifyListeners();
    try {
      return await _authService.restoreSession();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
