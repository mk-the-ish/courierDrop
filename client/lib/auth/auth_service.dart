import "dart:async";
import "dart:convert";

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
    final result = await _apiClient.loginClient(email: email, password: password);
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
    final result = await _apiClient.signUpClient(
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

    return _currentUser!;
  }

  Future<void> requestPasswordReset(String email) {
    return _apiClient.requestClientPasswordReset(email: email);
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
    final currentEmail = _currentUser?.email ?? "";
    _currentUser = AuthUser(
      uid: result.userId,
      email: currentEmail,
      idToken: result.idToken,
    );
    await _tokenStore.saveTokens(
      idToken: result.idToken,
      refreshToken: result.refreshToken ?? refresh,
    );
    return result.idToken;
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split(".");
    if (parts.length < 2) {
      return null;
    }
    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return (jsonDecode(decoded) as Map).cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  bool _restoreFromCachedIdToken(String token) {
    final payload = _decodeJwtPayload(token);
    final uid = payload?["user_id"]?.toString() ??
        payload?["sub"]?.toString() ??
        "";
    if (uid.isEmpty) {
      return false;
    }
    _apiClient.setAuthToken(token);
    _currentUser = AuthUser(
      uid: uid,
      email: payload?["email"]?.toString() ?? "",
      idToken: token,
    );
    return true;
  }

  Future<bool> restoreSession() async {
    final cachedIdToken = await _tokenStore.getIdToken();
    var restoredFromCache = false;
    if (cachedIdToken != null && cachedIdToken.isNotEmpty) {
      restoredFromCache = _restoreFromCachedIdToken(cachedIdToken);
    }
    try {
      final refreshed = await refreshSession();
      return refreshed != null;
    } catch (_) {
      if (restoredFromCache) {
        return true;
      }
      await signOut();
      return false;
    }
  }
}
