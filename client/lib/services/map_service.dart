import "dart:async";
import "dart:convert";
import "dart:io";

import "package:http/http.dart" as http;
import "package:http/retry.dart";
import "package:latlong2/latlong.dart";

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
    this.coordinates,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
  final LatLng? coordinates;
}

class RouteInfo {
  const RouteInfo({
    required this.polylinePoints,
    required this.distanceText,
    required this.durationText,
  });

  final List<LatLng> polylinePoints;
  final String distanceText;
  final String durationText;
}

class MapService {
  MapService({http.Client? client})
      : _client = RetryClient(
          client ?? http.Client(),
          retries: 3,
          when: _shouldRetryResponse,
          whenError: _shouldRetryError,
          delay: _retryDelay,
        );

  final http.Client _client;

  static bool _shouldRetryResponse(http.BaseResponse response) {
    return response.statusCode == 429 || response.statusCode >= 500;
  }

  static bool _shouldRetryError(Object error, StackTrace stackTrace) {
    return error is SocketException || error is TimeoutException;
  }

  static Duration _retryDelay(int retryCount) {
    return Duration(milliseconds: 400 * (1 << retryCount));
  }

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (query.trim().length < 3) {
      return const [];
    }

    final uri = Uri.parse("https://nominatim.openstreetmap.org/search").replace(
      queryParameters: {
        "q": query.trim(),
        "format": "jsonv2",
        "addressdetails": "1",
        "limit": "8",
        "countrycodes": "zw",
      },
    );
    final response = await _client
        .get(uri, headers: {"User-Agent": "DropCity/1.0"})
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      return const [];
    }
    final body = jsonDecode(response.body) as List<dynamic>;
    return body.map((item) {
      final row = item as Map<String, dynamic>;
      final lat = double.tryParse(row["lat"]?.toString() ?? "");
      final lon = double.tryParse(row["lon"]?.toString() ?? "");
      return PlaceSuggestion(
        placeId: "${lat ?? 0},${lon ?? 0}",
        primaryText: (row["display_name"]?.toString() ?? "").split(",").first.trim(),
        secondaryText: row["display_name"]?.toString() ?? "",
        fullText: row["display_name"]?.toString() ?? "",
        coordinates: (lat != null && lon != null) ? LatLng(lat, lon) : null,
      );
    }).where((s) => s.coordinates != null).toList();
  }

  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (placeId.isEmpty) {
      return null;
    }
    final parts = placeId.split(",");
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<String> reverseGeocode(LatLng coordinates) async {
    final fallback =
        "${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}";

    final response = await _client
        .get(
      Uri.parse(
        "https://nominatim.openstreetmap.org/reverse"
        "?lat=${coordinates.latitude}&lon=${coordinates.longitude}&format=jsonv2",
      ),
      headers: {"User-Agent": "DropCity/1.0"},
    )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return fallback;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body["display_name"]?.toString() ?? fallback;
  }

  Future<RouteInfo?> directions({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final response = await _client
        .get(
      Uri.parse(
        "https://router.project-osrm.org/route/v1/driving/"
        "${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}"
        "?overview=full&geometries=polyline&alternatives=false&steps=false",
      ),
    )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body["code"]?.toString() != "Ok") {
      return null;
    }
    final routes = body["routes"] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      return null;
    }

    final route = routes.first as Map<String, dynamic>;
    final geometry = route["geometry"]?.toString() ?? "";
    final distanceMeters = (route["distance"] as num?)?.toDouble();
    final durationSeconds = (route["duration"] as num?)?.toDouble();

    return RouteInfo(
      polylinePoints: _decodePolyline(geometry),
      distanceText: distanceMeters == null ? "" : "${(distanceMeters / 1000).toStringAsFixed(1)} km",
      durationText: durationSeconds == null ? "" : "${(durationSeconds / 60).ceil()} min",
    );
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int b;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}
