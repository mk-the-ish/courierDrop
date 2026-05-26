import "dart:convert";
import "dart:io";

import "package:flutter/material.dart";

import "../api/api_client.dart";
import "../auth/auth_state.dart";

class ClientSignupController extends ChangeNotifier {
  ClientSignupController({
    required this.authState,
    required this.apiClient,
  });

  final AuthState authState;
  final ApiClient apiClient;

  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _email;
  String? _password;
  bool _completed = false;

  int get step => _step;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> submitStep1({
    required String email,
    required String password,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _email = email;
      _password = password;
      _step = 2;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> submitStep2({
    required String fullName,
    required String username,
    required String idNumber,
    required String idImagePath,
  }) async {
    if (_loading || _completed) {
      return false;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      if (_email == null || _password == null) {
        throw Exception("Missing account credentials from step 1");
      }
      await _signUpOrSignInIfAlreadyExists(fullName: fullName);
      final idImageUrl = await _toDataUrl(idImagePath);
      await apiClient.submitClientProfile(
        fullName: fullName,
        username: username,
        idNumber: idNumber,
        idImageUrl: idImageUrl,
      );
      _completed = true;
      _step = 3;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _signUpOrSignInIfAlreadyExists({
    required String fullName,
  }) async {
    try {
      await authState.signUp(
        _email!,
        _password!,
        displayName: fullName,
        role: "client",
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final looksLikeExistingAccount =
          msg.contains("already in use") || msg.contains("email_exists");
      if (!looksLikeExistingAccount) {
        rethrow;
      }
      await authState.signIn(_email!, _password!);
    }
  }

  void back() {
    if (_completed) return;
    if (_step > 1) {
      _step -= 1;
      notifyListeners();
    }
  }

  Future<String> _toDataUrl(String path) async {
    final bytes = await File(path).readAsBytes();
    return "data:image/jpeg;base64,${base64Encode(bytes)}";
  }
}
