import "dart:async";

import "../api/api_client.dart";
import "../utils/token_store.dart";

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.idToken,
  });

  final String uid;
  final String email;
  final String idToken;
}

class AuthService {
  AuthService({ApiClient? apiClient, TokenStore? tokenStore})
      : _apiClient = apiClient ?? ApiClient(),
        _tokenStore = tokenStore ?? TokenStore();

  final ApiClient _apiClient;
  final TokenStore _tokenStore;
  AuthUser? _currentUser;

  AuthUser? get currentUser => _currentUser;
  ApiClient get apiClient => _apiClient;

  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final result = await _apiClient.login(email: email, password: password);
    _apiClient.setAuthToken(result.idToken);
    await _tokenStore.saveTokens(
      idToken: result.idToken,
      refreshToken: result.refreshToken ?? "",
    );
    _currentUser = AuthUser(
      uid: result.userId,
      email: email,
      idToken: result.idToken,
    );
    return _currentUser!;
  }

  Future<AuthUser> signUp({
    required String email,
    required String password,
    String? displayName,
    String? role,
  }) async {
    final result = await _apiClient.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    _apiClient.setAuthToken(result.idToken);
    await _tokenStore.saveTokens(
      idToken: result.idToken,
      refreshToken: result.refreshToken ?? "",
    );
    _currentUser = AuthUser(
      uid: result.userId,
      email: email,
      idToken: result.idToken,
    );

    // Set user role if provided
    if (role != null && (role == "client" || role == "courier")) {
      try {
        await _apiClient.setupUserRole(role: role);
      } catch (e) {
        print("[Auth] Warning: Failed to set user role: $e");
        // Don't throw - user can set role later
      }
    }

    return _currentUser!;
  }

  Future<void> signOut() async {
    _apiClient.setAuthToken(null);
    await _tokenStore.clear();
    _currentUser = null;
  }

  Future<String?> refreshSession() async {
    final refresh = await _tokenStore.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return null;
    }
    final result = await _apiClient.refreshToken(refreshToken: refresh);
    _apiClient.setAuthToken(result.idToken);
    _currentUser = AuthUser(
      uid: result.userId,
      email: _currentUser?.email ?? "",
      idToken: result.idToken,
    );
    await _tokenStore.saveTokens(
      idToken: result.idToken,
      refreshToken: result.refreshToken ?? refresh,
    );
    return result.idToken;
  }

  Future<void> restoreSession() async {
    await refreshSession();
  }
}
