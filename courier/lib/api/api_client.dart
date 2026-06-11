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

  Future<Map<String, dynamic>> getMyVehicle() async {
    final uri = Uri.parse("$baseUrl/vehicles/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Vehicle lookup failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded;
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

  Future<List<Map<String, dynamic>>> getPendingParcels() async {
    final uri = Uri.parse("$baseUrl/parcels/pending/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Pending parcels failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["parcels"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> getMyCorridors() async {
    final uri = Uri.parse("$baseUrl/corridors/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("My corridors failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["corridors"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> acceptPendingParcel(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/accept");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Accept pending parcel failed: ${response.body}");
    }
  }

  Future<void> declinePendingParcel(String parcelId) async {
    final uri = Uri.parse("$baseUrl/parcels/$parcelId/decline");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Decline pending parcel failed: ${response.body}");
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

  Future<Map<String, dynamic>> postTrackingUpdate({
    required String parcelId,
    required double lat,
    required double lng,
    double? accuracy,
    Map<String, dynamic>? deviceInfo,
    Map<String, dynamic>? networkInfo,
  }) async {
    final uri = Uri.parse("$baseUrl/tracking/update");
    final payload = <String, dynamic>{
      "parcelId": parcelId,
      "lat": lat,
      "lng": lng,
      "accuracy": accuracy,
      if (deviceInfo != null) "deviceInfo": deviceInfo,
      if (networkInfo != null) "networkInfo": networkInfo,
    };
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Tracking update failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> batchSyncTracking({
    required List<Map<String, dynamic>> updates,
  }) async {
    final uri = Uri.parse("$baseUrl/tracking/batch-sync");
    final payload = {"updates": updates};
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode >= 400) {
      throw Exception("Tracking batch sync failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getMyTrackingAlerts() async {
    final uri = Uri.parse("$baseUrl/tracking/alerts/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Tracking alerts fetch failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["alerts"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
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

  Future<String> uploadHandshakePhoto(String filePath,
      {String? parcelId}) async {
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

  Future<Map<String, dynamic>> getMyProfile() async {
    final uri = Uri.parse("$baseUrl/users/me");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Profile fetch failed: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> patchOnboardingProfile({
    String? displayName,
    String? phoneNumber,
  }) async {
    final uri = Uri.parse("$baseUrl/users/onboarding/profile");
    final response = await _client.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({
        if (displayName != null) "displayName": displayName,
        if (phoneNumber != null) "phoneNumber": phoneNumber,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception("Profile update failed: ${response.body}");
    }
  }

  Future<String> uploadOnboardingDocument(String filePath,
      {required String kind}) async {
    final uri = Uri.parse("$baseUrl/users/onboarding/document");
    final request = http.MultipartRequest("POST", uri);
    request.headers.addAll(_headers());
    request.fields["kind"] = kind;
    request.files.add(await http.MultipartFile.fromPath("file", filePath));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      throw Exception("Document upload failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded["url"] as String;
  }

  Future<void> postPickupMeetingPoint({
    required String parcelId,
    required double lat,
    required double lng,
  }) async {
    final uri = Uri.parse("$baseUrl/handshake/pickup/meeting-point");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({"parcelId": parcelId, "lat": lat, "lng": lng}),
    );
    if (response.statusCode >= 400) {
      throw Exception("Meeting point failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> requestManualDropoffOtp({
    required String parcelId,
    required String phoneE164,
  }) async {
    final uri =
        Uri.parse("$baseUrl/handshake/courier/request-manual-dropoff-otp");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({"parcelId": parcelId, "phoneE164": phoneE164}),
    );
    if (response.statusCode >= 400) {
      throw Exception("Manual OTP request failed: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> completeCourierDropoff({
    required String parcelId,
    required String otp,
    required String photoUrl,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    final uri = Uri.parse("$baseUrl/handshake/courier/complete-dropoff");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        "parcelId": parcelId,
        "otp": otp,
        "photoUrl": photoUrl,
        "lat": lat,
        "lng": lng,
        "accuracy": accuracy,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception("Complete dropoff failed: ${response.body}");
    }
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

  Future<Map<String, dynamic>> getCourierServiceState() async {
    final uri = Uri.parse("$baseUrl/couriers/state");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Courier state failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> setCourierOnline(bool online) async {
    final uri = Uri.parse("$baseUrl/couriers/set-online");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({"online": online}),
    );
    if (response.statusCode >= 400) {
      throw Exception("Courier availability update failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> startCourierTravel(String corridorId) async {
    final uri = Uri.parse("$baseUrl/couriers/start-travel");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({"corridorId": corridorId}),
    );
    if (response.statusCode >= 400) {
      throw Exception("Start travel failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> endCourierTravel() async {
    final uri = Uri.parse("$baseUrl/couriers/end-travel");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("End travel failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  /// Post location telemetry to backend
  Future<void> postLocation(Map<String, dynamic> body) async {
    final uri = Uri.parse("$baseUrl/courier/location");
    final response = await _client.post(uri, headers: _headers(), body: jsonEncode(body));
    if (response.statusCode >= 400) {
      throw Exception("Location post failed: ${response.body}");
    }
  }

  Future<Map<String, dynamic>> createCourierRoute({
    required String corridorId,
    String? plannedStartAtIso,
    int? declaredEtaMinutes,
  }) async {
    final uri = Uri.parse("$baseUrl/couriers/routes");
    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode({
        "corridorId": corridorId,
        if (plannedStartAtIso != null) "plannedStartAt": plannedStartAtIso,
        if (declaredEtaMinutes != null)
          "declaredEtaMinutes": declaredEtaMinutes,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception("Create route failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getCourierRoutes() async {
    final uri = Uri.parse("$baseUrl/couriers/routes");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Fetch routes failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded["routes"] as List<dynamic>? ?? [];
    return items.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> updateCourierRouteStatus({
    required String routeId,
    required String action, // activate|complete|cancel
  }) async {
    final uri = Uri.parse("$baseUrl/couriers/routes/$routeId");
    final response = await _client.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({"action": action}),
    );
    if (response.statusCode >= 400) {
      throw Exception("Route update failed: ${response.body}");
    }
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> getMyNotifications({
    String? status,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      "limit": limit.toString(),
      "offset": offset.toString(),
      if (status != null && status.isNotEmpty) "status": status,
    };
    final uri =
        Uri.parse("$baseUrl/notifications/me").replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Notification fetch failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded["notifications"] as List<dynamic>? ?? [];
    return rows.map((item) => (item as Map).cast<String, dynamic>()).toList();
  }

  Future<void> markNotificationRead(String notificationId) async {
    final uri = Uri.parse("$baseUrl/notifications/$notificationId/read");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Mark notification read failed: ${response.body}");
    }
  }

  Future<void> markAllNotificationsRead() async {
    final uri = Uri.parse("$baseUrl/notifications/read-all");
    final response = await _client.post(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Mark all notifications read failed: ${response.body}");
    }
  }

  Future<void> submitCourierProfile({
    required String fullName,
    required String idNumber,
    required String idImageUrl,
    required String licenseNumber,
    required String licenseImageUrl,
    required String vehicleRegistration,
    required List<String> vehicleRegistrationImages,
    required String vehicleType,
    required String vehicleMake,
    required String vehicleModel,
    required String vehicleYear,
    required String vehicleColor,
    required String vehicleCapacityKg,
  }) async {
    final uri = Uri.parse("$baseUrl/users/courier/profile");
    final payload = <String, dynamic>{
      "full_name": fullName,
      "id_number": idNumber,
      "id_image_url": idImageUrl,
      "license_number": licenseNumber,
      "license_image_url": licenseImageUrl,
      "vehicle_registration": vehicleRegistration,
      "vehicle_registration_images": vehicleRegistrationImages,
      "vehicle_type": vehicleType,
      "vehicle_make": vehicleMake,
      "vehicle_model": vehicleModel,
      "vehicle_year": vehicleYear,
      "vehicle_color": vehicleColor,
      "vehicle_capacity_kg": vehicleCapacityKg,
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to submit courier profile: ${response.body}");
    }
  }

  /// Creates a reusable route template
  /// Route templates can be used multiple times; each usage creates a new corridor
  Future<String> createRouteTemplate({
    required String startLocation,
    required String endLocation,
    required List<dynamic> polylinePoints,
    required bool allowMultipleParcels,
    required int declaredEtaMinutes,
    String? startPlaceName,
    String? endPlaceName,
    String? notes,
  }) async {
    final uri = Uri.parse("$baseUrl/couriers/route-templates");
    final payload = {
      "startLocation": startLocation,
      "endLocation": endLocation,
      "startPlaceName": startPlaceName,
      "endPlaceName": endPlaceName,
      "polylinePoints": polylinePoints,
      "allowMultipleParcels": allowMultipleParcels,
      "declaredEtaMinutes": declaredEtaMinutes,
      "notes": notes ?? "",
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception("Failed to create route template: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    final id = decoded?["id"] as String?;
    if (id == null || id.isEmpty) {
      throw Exception("Backend did not return route template id.");
    }
    return id;
  }

  /// Uses a route template by creating a new corridor instance
  /// This creates a new corridor with its own ID for operational tracking
  Future<String> createCorridorFromTemplate({
    required String routeTemplateId,
    required String plannedStartAtIso,
  }) async {
    final uri = Uri.parse("$baseUrl/couriers/routes/from-template");
    final payload = {
      "routeTemplateId": routeTemplateId,
      "plannedStartAt": plannedStartAtIso,
    };

    final response = await _client.post(
      uri,
      headers: _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode >= 400) {
      throw Exception(
          "Failed to create corridor from template: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
    final corridorId = decoded?["corridorId"] as String?;
    if (corridorId == null || corridorId.isEmpty) {
      throw Exception("Backend did not return corridor id.");
    }
    return corridorId;
  }

  Future<List<Map<String, dynamic>>> getRouteTemplates() async {
    final uri = Uri.parse("$baseUrl/couriers/route-templates");
    final response = await _client.get(uri, headers: _headers());
    if (response.statusCode >= 400) {
      throw Exception("Route template fetch failed: ${response.body}");
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rows = decoded["templates"] as List<dynamic>? ?? [];
    return rows.map((item) => (item as Map).cast<String, dynamic>()).toList();
  }
}
