import "dart:convert";

import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:http/http.dart" as http;

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
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
  MapService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = (apiKey ?? const String.fromEnvironment("MAPS_API_KEY")).trim();

  final http.Client _client;
  final String _apiKey;

  bool get isConfigured => _apiKey.isNotEmpty;

  Future<List<PlaceSuggestion>> autocomplete(String query) async {
    if (!isConfigured || query.trim().length < 3) {
      return const [];
    }

    final response = await _client.post(
      Uri.parse("https://places.googleapis.com/v1/places:autocomplete"),
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": _apiKey,
        "X-Goog-FieldMask": "suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat",
      },
      body: jsonEncode({"input": query.trim()}),
    );

    if (response.statusCode != 200) {
      return const [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = body["suggestions"] as List<dynamic>? ?? const [];

    return suggestions
        .map((item) {
          final placePrediction =
              (item as Map<String, dynamic>)["placePrediction"] as Map<String, dynamic>? ?? const {};
          final structured =
              placePrediction["structuredFormat"] as Map<String, dynamic>? ?? const {};
          final text = placePrediction["text"] as Map<String, dynamic>? ?? const {};

          final primary =
              (structured["mainText"] as Map<String, dynamic>?)?["text"]?.toString() ?? "";
          final secondary =
              (structured["secondaryText"] as Map<String, dynamic>?)?["text"]?.toString() ?? "";
          final fullText = text["text"]?.toString() ??
              [primary, secondary].where((x) => x.isNotEmpty).join(", ");

          return PlaceSuggestion(
            placeId: placePrediction["placeId"]?.toString() ?? "",
            primaryText: primary,
            secondaryText: secondary,
            fullText: fullText,
          );
        })
        .where((s) => s.placeId.isNotEmpty)
        .toList();
  }

  Future<LatLng?> getPlaceCoordinates(String placeId) async {
    if (!isConfigured || placeId.isEmpty) {
      return null;
    }

    final response = await _client.get(
      Uri.parse("https://places.googleapis.com/v1/places/$placeId"),
      headers: {
        "X-Goog-Api-Key": _apiKey,
        "X-Goog-FieldMask": "location",
      },
    );

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final location = body["location"] as Map<String, dynamic>?;
    if (location == null) {
      return null;
    }

    final lat = (location["latitude"] as num?)?.toDouble();
    final lng = (location["longitude"] as num?)?.toDouble();
    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(lat, lng);
  }

  Future<String> reverseGeocode(LatLng coordinates) async {
    final fallback =
        "${coordinates.latitude.toStringAsFixed(5)}, ${coordinates.longitude.toStringAsFixed(5)}";

    if (!isConfigured) {
      return fallback;
    }

    final response = await _client.get(
      Uri.parse(
        "https://maps.googleapis.com/maps/api/geocode/json"
        "?latlng=${coordinates.latitude},${coordinates.longitude}&key=$_apiKey",
      ),
    );

    if (response.statusCode != 200) {
      return fallback;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = body["results"] as List<dynamic>? ?? const [];
    if (results.isEmpty) {
      return fallback;
    }

    return (results.first as Map<String, dynamic>)["formatted_address"]?.toString() ?? fallback;
  }

  Future<RouteInfo?> directions({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (!isConfigured) {
      return null;
    }

    final response = await _client.get(
      Uri.parse(
        "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${origin.latitude},${origin.longitude}"
        "&destination=${destination.latitude},${destination.longitude}"
        "&mode=driving&key=$_apiKey",
      ),
    );

    if (response.statusCode != 200) {
      return null;
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body["routes"] as List<dynamic>? ?? const [];
    if (routes.isEmpty) {
      return null;
    }

    final route = routes.first as Map<String, dynamic>;
    final overview = route["overview_polyline"] as Map<String, dynamic>? ?? const {};
    final points = overview["points"]?.toString() ?? "";
    final legs = route["legs"] as List<dynamic>? ?? const [];
    final firstLeg = legs.isNotEmpty
        ? legs.first as Map<String, dynamic>
        : const <String, dynamic>{};

    return RouteInfo(
      polylinePoints: _decodePolyline(points),
      distanceText:
          (firstLeg["distance"] as Map<String, dynamic>?)?["text"]?.toString() ?? "",
      durationText:
          (firstLeg["duration"] as Map<String, dynamic>?)?["text"]?.toString() ?? "",
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
