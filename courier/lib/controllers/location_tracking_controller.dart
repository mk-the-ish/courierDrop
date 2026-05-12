import 'package:flutter/material.dart';
import 'package:background_geolocation/background_geolocation.dart' as bg;
import '../services/background_location_service.dart';
import '../api/api_client.dart';

/**
 * Location Tracking Controller
 * Manages background location tracking state and periodic uploads to backend
 * 
 * Tracks:
 * - Current location
 * - Tracking state
 * - Distance traveled
 * - Battery consumption
 * - Upload status
 */

class LocationTrackingController extends ChangeNotifier {
  final ApiClient apiClient;
  final BackgroundLocationService locationService;

  // Tracking state
  bool _isTracking = false;
  bool _isInitialized = false;
  
  // Current location
  double? _currentLatitude;
  double? _currentLongitude;
  double? _currentAccuracy;
  DateTime? _lastLocationUpdate;

  // Distance & analytics
  double _totalDistanceTraveledKm = 0.0;
  int _totalLocationsRecorded = 0;
  DateTime? _trackingStartedAt;

  // Upload tracking
  bool _isUploading = false;
  int _failedUploadCount = 0;
  String? _lastUploadError;

  // Getters
  bool get isTracking => _isTracking;
  bool get isInitialized => _isInitialized;
  double? get currentLatitude => _currentLatitude;
  double? get currentLongitude => _currentLongitude;
  double? get currentAccuracy => _currentAccuracy;
  DateTime? get lastLocationUpdate => _lastLocationUpdate;
  double get totalDistanceTraveledKm => _totalDistanceTraveledKm;
  int get totalLocationsRecorded => _totalLocationsRecorded;
  DateTime? get trackingStartedAt => _trackingStartedAt;
  bool get isUploading => _isUploading;
  int get failedUploadCount => _failedUploadCount;
  String? get lastUploadError => _lastUploadError;

  LocationTrackingController({
    required this.apiClient,
    required this.locationService,
  });

  /**
   * Initialize location tracking
   * Sets up callbacks and permissions
   */
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check and request location permissions
      final hasPermission = await locationService.checkAndRequestPermission();
      if (!hasPermission) {
        throw Exception('Location permission denied');
      }

      // Initialize the background location service
      await locationService.initialize(
        onLocation: _handleLocationUpdate,
      );

      _isInitialized = true;
      notifyListeners();
      print('[LocationTracking] Initialized successfully');
    } catch (e) {
      print('[LocationTracking] Initialization failed: $e');
      rethrow;
    }
  }

  /**
   * Start tracking deliveries
   */
  Future<void> startTracking({String? parcelId}) async {
    if (!_isInitialized) {
      throw Exception('LocationTrackingController not initialized');
    }

    if (_isTracking) return;

    try {
      _isTracking = true;
      _trackingStartedAt = DateTime.now();
      _totalDistanceTraveledKm = 0.0;
      _totalLocationsRecorded = 0;
      _failedUploadCount = 0;

      await locationService.startTracking();
      notifyListeners();
      print('[LocationTracking] Tracking started');
    } catch (e) {
      _isTracking = false;
      notifyListeners();
      print('[LocationTracking] Failed to start tracking: $e');
      rethrow;
    }
  }

  /**
   * Stop tracking deliveries
   */
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      await locationService.stopTracking();
      _isTracking = false;
      notifyListeners();
      print('[LocationTracking] Tracking stopped');
    } catch (e) {
      print('[LocationTracking] Failed to stop tracking: $e');
      rethrow;
    }
  }

  /**
   * Handle location update from background service
   * Uploads location to backend
   */
  Future<void> _handleLocationUpdate(bg.Location location) async {
    // Update current location
    final prevLat = _currentLatitude;
    final prevLng = _currentLongitude;

    _currentLatitude = location.latitude;
    _currentLongitude = location.longitude;
    _currentAccuracy = location.accuracy;
    _lastLocationUpdate = DateTime.now();
    _totalLocationsRecorded++;

    // Calculate distance traveled if we have a previous location
    if (prevLat != null && prevLng != null) {
      final distance = _calculateDistance(prevLat, prevLng, location.latitude, location.longitude);
      _totalDistanceTraveledKm += distance;
    }

    // Upload location to backend (non-blocking)
    _uploadLocationToBackend(location);

    notifyListeners();
  }

  /**
   * Upload location to backend API
   */
  Future<void> _uploadLocationToBackend(bg.Location location) async {
    if (_isUploading) return; // Avoid concurrent uploads

    _isUploading = true;
    notifyListeners();

    try {
      await apiClient.post(
        '/courier/location',
        body: {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'accuracy': location.accuracy,
          'timestamp': location.timestamp.toIso8601String(),
          'speed': location.speed,
          'heading': location.bearing,
          'altitude': location.altitude,
        },
      );

      _failedUploadCount = 0;
      _lastUploadError = null;
    } catch (e) {
      _failedUploadCount++;
      _lastUploadError = e.toString();
      print('[LocationTracking] Failed to upload location: $e');
      
      // Keep tracking even if upload fails - location updates will retry
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  /**
   * Get current location immediately (for GPS gate verification)
   */
  Future<({double lat, double lng, double accuracy})> getCurrentLocationSnapshot() async {
    try {
      final location = await locationService.getCurrentLocation();
      return (
        lat: location.latitude,
        lng: location.longitude,
        accuracy: location.accuracy,
      );
    } catch (e) {
      print('[LocationTracking] Failed to get current location: $e');
      rethrow;
    }
  }

  /**
   * Add checkpoint for geofencing
   */
  Future<void> addCheckpoint({
    required String checkpointId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    try {
      await locationService.addCheckpointGeofence(
        checkpointId: checkpointId,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radiusMeters,
      );
      notifyListeners();
    } catch (e) {
      print('[LocationTracking] Failed to add checkpoint: $e');
    }
  }

  /**
   * Remove checkpoint geofence
   */
  Future<void> removeCheckpoint(String checkpointId) async {
    try {
      await locationService.removeCheckpointGeofence(checkpointId);
      notifyListeners();
    } catch (e) {
      print('[LocationTracking] Failed to remove checkpoint: $e');
    }
  }

  /**
   * Calculate distance between two points using Haversine formula
   * Returns distance in kilometers
   */
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(lat1)) *
            Math.cos(_toRadians(lat2)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) {
    return degrees * (3.141592653589793 / 180.0);
  }

  /**
   * Get tracking summary
   */
  Map<String, dynamic> getTrackingSummary() {
    final duration = _trackingStartedAt != null
        ? DateTime.now().difference(_trackingStartedAt!)
        : Duration.zero;

    return {
      'isTracking': _isTracking,
      'startedAt': _trackingStartedAt?.toIso8601String(),
      'durationMinutes': duration.inMinutes,
      'currentLocation': {
        'latitude': _currentLatitude,
        'longitude': _currentLongitude,
        'accuracy': _currentAccuracy,
      },
      'totalDistanceKm': _totalDistanceTraveledKm.toStringAsFixed(2),
      'totalLocationsRecorded': _totalLocationsRecorded,
      'uploadStatus': {
        'isUploading': _isUploading,
        'failedCount': _failedUploadCount,
        'lastError': _lastUploadError,
      },
    };
  }

  /**
   * Reset tracking state (end of delivery)
   */
  void resetTracking() {
    _totalDistanceTraveledKm = 0.0;
    _totalLocationsRecorded = 0;
    _trackingStartedAt = null;
    _failedUploadCount = 0;
    _lastUploadError = null;
    notifyListeners();
  }

  /**
   * Cleanup
   */
  @override
  Future<void> dispose() async {
    if (_isTracking) {
      await stopTracking();
    }
    await locationService.dispose();
    super.dispose();
  }
}

// Simple Math class since dart:math import might conflict
class Math {
  static double sin(double x) => _mathSin(x);
  static double cos(double x) => _mathCos(x);
  static double atan2(double y, double x) => _mathAtan2(y, x);
  static double sqrt(double x) => _mathSqrt(x);

  static double _mathSin(double x) {
    // Simplified sine using Taylor series (good enough for geolocation)
    x = x % (2 * 3.141592653589793);
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double _mathCos(double x) {
    x = x % (2 * 3.141592653589793);
    double result = 1;
    double term = 1;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  static double _mathAtan2(double y, double x) {
    if (x > 0) return (y / x).atan();
    if (x < 0 && y >= 0) return (y / x).atan() + 3.141592653589793;
    if (x < 0 && y < 0) return (y / x).atan() - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _mathSqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    double guess = x;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
}
