import "dart:convert";

import "package:http/http.dart" as http;

class AuthResponse {
  const AuthResponse({
    required this.idToken,
    required this.userId,
    this.refreshToken,
  });

  final String idToken;
  final String userId;
  final String? refreshToken;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? "http://localhost:8080";

  final http.Client _client;
  final String baseUrl;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> _headers() {
    final headers = <String, String>{
      "Content-Type": "application/json",
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_authToken";
    }
    return headers;
  }

  String _friendlyAuthError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final message = decoded["error"]?.toString() ?? "";
      final code = decoded["code"]?.toString() ?? "";
      final combined = "$code $message".toUpperCase();

      if (combined.contains("EMAIL_EXISTS")) {
        return "That email is already in use.";
      }
      if (combined.contains("INVALID_PASSWORD") ||
          combined.contains("EMAIL_NOT_FOUND")) {
        return "Incorrect email or password.";
      }
      if (combined.contains("WEAK_PASSWORD")) {
        return "Password is too weak. Use at least 6 characters.";
      }
      if (combined.contains("INVALID_EMAIL")) {
        return "Please enter a valid email address.";
      }
      if (combined.contains("USER_DISABLED")) {
        return "This account has been disabled.";
      }
    } catch (_) {
      // fall through
    }
    return "Authentication failed. Please try again.";
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final uri = Uri.parse("$baseUrl/auth/signup");
    final payload = <String, dynamic>{
      "email": email,
      "password": password,
      if (displayName != null && displayName.isNotEmpty)
        "displayName": displayName,
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception(_friendlyAuthError(response.body));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResponse(
      idToken: decoded["idToken"] as String,
      userId: decoded["localId"] as String,
      refreshToken: decoded["refreshToken"] as String?,
    );
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    print("[API] 🔐 Attempting login for: $email");
    print("[API] 📡 Making request to: $baseUrl/auth/login");

    final uri = Uri.parse("$baseUrl/auth/login");
    final payload = <String, dynamic>{
      "email": email,
      "password": password,
    };

    print("[API] 📤 Sending payload: ${jsonEncode(payload)}");

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    print("[API] 📥 Response status: ${response.statusCode}");
    print("[API] 📥 Response body: ${response.body}");

    if (response.statusCode >= 400) {
      throw Exception(_friendlyAuthError(response.body));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResponse(
      idToken: decoded["idToken"] as String,
      userId: decoded["localId"] as String,
      refreshToken: decoded["refreshToken"] as String?,
    );
  }

  Future<AuthResponse> refreshToken({
    required String refreshToken,
  }) async {
    final uri = Uri.parse("$baseUrl/auth/refresh");
    final payload = {"refreshToken": refreshToken};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Token refresh failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResponse(
      idToken: decoded["idToken"] as String,
      userId: decoded["localId"] as String,
      refreshToken: decoded["refreshToken"] as String?,
    );
  }

  Future<void> logout() async {
    // Logout implementation
  }

  Future<String> postRouteDeclaration({
    required String startLocation,
    required String endLocation,
    required String windowStart,
    required String windowEnd,
    required bool allowMultipleParcels,
    String? notes,
    String? clientId,
  }) async {
    final uri = Uri.parse("$baseUrl/corridors");
    final payload = <String, dynamic>{
      if (clientId != null && clientId.isNotEmpty) "clientId": clientId,
      "startLocation": startLocation,
      "endLocation": endLocation,
      "windowStart": windowStart,
      "windowEnd": windowEnd,
      "allowMultipleParcels": allowMultipleParcels,
      "notes": notes ?? "",
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to declare route: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    final id = decoded?["id"] as String?;
    if (id == null || id.isEmpty) {
      throw Exception("Backend did not return corridor id.");
    }
    return id;
  }

  Future<void> postCorridorLine({
    required String corridorId,
    required List<Map<String, double>> polyline,
  }) async {
    final uri = Uri.parse("$baseUrl/corridors/$corridorId/line");
    final payload = <String, dynamic>{
      "polyline": polyline,
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to save corridor line: ${response.body}");
    }
  }

  Future<void> postErrorLog({
    String? userId,
    String? deviceModel,
    String? osVersion,
    required String stackTrace,
    Map<String, dynamic>? context,
    String? timestamp,
    String? clientId,
  }) async {
    final uri = Uri.parse("$baseUrl/logs/error");
    final payload = <String, dynamic>{
      if (clientId != null && clientId.isNotEmpty) "clientId": clientId,
      "userId": userId,
      "deviceModel": deviceModel,
      "osVersion": osVersion,
      "stackTrace": stackTrace,
      "context": context,
      "timestamp": timestamp
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to log error: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> initHandshake(String parcelId) async {
    final uri = Uri.parse("$baseUrl/handshake/init");
    final payload = {"parcelId": parcelId};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Handshake init failed: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> pickupHandshake({
    required String parcelId,
    required String pin,
    required double lat,
    required double lng,
    double? accuracy,
    required String photoUrl,
  }) async {
    final uri = Uri.parse("$baseUrl/handshake/pickup");
    final payload = {
      "parcelId": parcelId,
      "pin": pin,
      "lat": lat,
      "lng": lng,
      "accuracy": accuracy,
      "photoUrl": photoUrl
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Pickup failed: ${response.body}");
    }
  }

  Future<List<Map<String, dynamic>>> getAssignedParcels() async {
    final uri = Uri.parse("$baseUrl/parcels/assigned/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Assigned parcels failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["parcels"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    final uri = Uri.parse("$baseUrl/devices/register");
    final payload = {"token": token, "platform": platform};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Device register failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getParcel(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Parcel lookup failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded["parcel"] as Map).cast<String, dynamic>();
  }

  Future<void> acceptParcel(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/accept");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Accept failed: ${response.body}");
    }
  }

  Future<void> declineParcel(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/decline");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Decline failed: ${response.body}");
    }
  }

  Future<String> uploadHandshakePhoto(String filePath, {String? parcelId}) async {
    final uri = Uri.parse("$baseUrl/handshake/upload");
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(_headers());
    request.files.add(await http.MultipartFile.fromPath("photo", filePath));
    if (parcelId != null && parcelId.isNotEmpty) {
      request.fields["parcelId"] = parcelId;
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      throw Exception("Photo upload failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded["url"] as String;
  }

  Future<Map<String, dynamic>> healthCheck() async {
    print("[API] 🏥 Health check to: $baseUrl/");

    final uri = Uri.parse("$baseUrl/");
    final response = await _client.get(uri, headers: _headers());

    print("[API] 📥 Health response status: ${response.statusCode}");
    print("[API] 📥 Health response body: ${response.body}");

    if (response.statusCode >= 400) {
      throw Exception("Health check failed: ${response.body}");
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
