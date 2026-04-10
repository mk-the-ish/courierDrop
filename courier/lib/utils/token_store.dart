import "package:shared_preferences/shared_preferences.dart";

class TokenStore {
  static const _idTokenKey = "auth_id_token";
  static const _refreshTokenKey = "auth_refresh_token";

  Future<void> saveTokens({
    required String idToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_idTokenKey, idToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  Future<String?> getIdToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_idTokenKey);
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_idTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}
