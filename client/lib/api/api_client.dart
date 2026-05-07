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

class ClientDashboardData {
  const ClientDashboardData({
    required this.stats,
    required this.parcels,
  });

  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> parcels;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? "https://dropcity-backend.onrender.com";

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
    final uri = Uri.parse("$baseUrl/auth/login");
    final payload = <String, dynamic>{
      "email": email,
      "password": password,
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

  Future<void> setupUserRole({required String role}) async {
    // Valid roles: 'client' or 'courier'
    if (role != "client" && role != "courier") {
      throw Exception("Invalid role. Must be 'client' or 'courier'.");
    }

    final uri = Uri.parse("$baseUrl/users/setup-role");
    final payload = {
      "role": role,
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception(
          "Failed to set user role: ${response.statusCode} ${response.body}");
    }

    // Role was successfully set
  }

  Future<void> submitVehicleInfo({
    required String vehicleType,
    required String licensePlate,
    required int maxCapacityKg,
    String? make,
    String? model,
    int? year,
    String? color,
    String? notes,
  }) async {
    final uri = Uri.parse("$baseUrl/vehicles");
    final payload = <String, dynamic>{
      "vehicleType": vehicleType,
      "licensePlate": licensePlate,
      "maxCapacityKg": maxCapacityKg,
      if (make != null) "make": make,
      if (model != null) "model": model,
      if (year != null) "year": year,
      if (color != null) "color": color,
      if (notes != null) "notes": notes,
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to submit vehicle info: ${response.body}");
    }

    // Vehicle info was successfully saved
  }

  Future<String> postParcelRequest({
    required String origin,
    required String destination,
    String? size,
    required String priority,
    required bool fragile,
    String? notes,
    String? clientId,
  }) async {
    final uri = Uri.parse("$baseUrl/parcels");
    final payload = <String, dynamic>{
      if (clientId != null && clientId.isNotEmpty) "clientId": clientId,
      "origin": origin,
      "destination": destination,
      "size": size ?? "",
      "priority": priority,
      "fragile": fragile,
      "notes": notes ?? "",
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to submit parcel: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final id = decoded["id"] as String?;
    if (id == null || id.isEmpty) {
      throw Exception("Backend did not return parcel id.");
    }
    return id;
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

  Future<List<Map<String, dynamic>>> matchCorridors({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
    double maxDetourMeters = 50,
  }) async {
    final uri = Uri.parse("$baseUrl/matches/corridors");
    final payload = {
      "origin": {"lat": originLat, "lng": originLng},
      "destination": {"lat": destinationLat, "lng": destinationLng},
      "maxDetourMeters": maxDetourMeters,
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Match lookup failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final matches = decoded["matches"] as List<dynamic>? ?? [];
    return matches.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> requestCourier({
    required String parcelId,
    required String corridorId,
    List<String>? corridorIds,
  }) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/request-courier");
    final payload = {
      "corridorId": corridorId,
      if (corridorIds != null && corridorIds.isNotEmpty)
        "corridorIds": corridorIds
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Request courier failed: ${response.body}");
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

  Future<void> dropoffHandshake({
    required String parcelId,
    required String pin,
    required double lat,
    required double lng,
    double? accuracy,
    required String photoUrl,
  }) async {
    final uri = Uri.parse("$baseUrl/handshake/dropoff");
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
      throw Exception("Dropoff failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> getParcelStatus(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId");
    final response = await _client.get(
      uri,
      headers: _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception("Parcel status failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded["parcel"] as Map).cast<String, dynamic>();
  }

  Future<ClientDashboardData> getClientDashboard() async {
    final uri = Uri.parse("$baseUrl/parcels/created/me");
    final response = await _client.get(
      uri,
      headers: _headers(),
    );
    if (response.statusCode >= 400) {
      throw Exception("Dashboard fetch failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final stats = (decoded["stats"] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final parcelsRaw = decoded["parcels"] as List<dynamic>? ?? <dynamic>[];
    final parcels = parcelsRaw
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
    return ClientDashboardData(
      stats: stats,
      parcels: parcels,
    );
  }

  Future<void> rateParcel({
    required String parcelId,
    required int rating,
    String? feedback,
  }) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/rate");
    final payload = <String, dynamic>{
      "rating": rating,
      "feedback": feedback ?? "",
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Rating submit failed: ${response.body}");
    }
  }

  Future<List<Map<String, dynamic>>> getHandshakeEvents(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/events");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Handshake events failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["events"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> generateCheckpoints(String parcelId,
      {int count = 3, int radiusMeters = 200}) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/checkpoints/generate");
    final payload = {"count": count, "radiusMeters": radiusMeters};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Checkpoint generate failed: ${response.body}");
    }
  }

  Future<List<Map<String, dynamic>>> getCheckpoints(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/checkpoints");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Checkpoint fetch failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["checkpoints"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> verifyCheckpoint({
    required String parcelId,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/checkpoints/verify");
    final payload = {"lat": lat, "lng": lng};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Checkpoint verify failed: ${response.body}");
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
}
