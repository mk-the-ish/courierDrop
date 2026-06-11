import 'package:flutter/foundation.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:geolocator/geolocator.dart';

/**
 * Background Location Service
 * Manages flutter_background_geolocation plugin initialization, state, and position updates
 * 
 * Usage:
 *   final service = BackgroundLocationService();
 *   await service.initialize(onLocation: (location) => uploadToBackend(location));
 *   await service.startTracking();
 *   // ... tracking happens in background
 *   await service.stopTracking();
 */

class BackgroundLocationService {
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();

  factory BackgroundLocationService() {
    return _instance;
  }

  BackgroundLocationService._internal();

  bool _isInitialized = false;
  bool _isTracking = false;
  Function(bg.Location)? _onLocation;

  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;

  /**
   * Initialize the background geolocation plugin
   * Must be called before startTracking()
   * 
   * Configuration:
   * - desiredAccuracy: 0 = high accuracy (30m), 10 = cell-level accuracy
   * - distanceFilter: Minimum distance in meters before update (default 50m)
   * - stopOnTerminate: Continue tracking when app is terminated
   * - startOnBoot: Auto-start tracking when device boots
   * - foregroundService: Show persistent notification while tracking
   */
  Future<void> initialize({
    required Function(bg.Location location) onLocation,
  }) async {
    if (_isInitialized) return;

    _onLocation = onLocation;

    try {
      // Configuration
      await bg.BackgroundGeolocation.ready(bg.Config(
        // Accuracy & distance
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_NAVIGATION, // High accuracy, ~10m
        distanceFilter: 25.0, // Update every 25m (avoid excessive updates)
        stationaryRadius: 50.0, // Consider stationary if within 50m for 5 min
        stopTimeout: 5,
        allowIdenticalLocations: false,
        locationAuthorizationRequest: "Always",

        // Activity tracking
        geofenceProximityRadius: 200, // Proximity detection radius
        activityRecognitionInterval: 5000, // Check activity every 5s
        motionTriggerDelay: 30000,

        // Stop conditions
        stopOnTerminate: false, // Keep tracking when app closes
        startOnBoot: true, // Auto-start on device reboot
        scheduleUseAlarmManager: true,
        
        // Geofencing
        geofenceInitialTriggerEntry: true,
        
        // Notifications & UI
        foregroundService: true, // Persistent notification
        
        // HTTP logging (useful for debugging)
        logLevel: kDebugMode ? bg.Config.LOG_LEVEL_VERBOSE : bg.Config.LOG_LEVEL_OFF,
        debug: kDebugMode,
        
        // Geofence options
        maxRecordsToPersist: 500,
        locationsOrderDirection: 'DESC',
      ));

      // Register listeners
      _registerLocationCallback();
      _registerGeofenceCallback();

      _isInitialized = true;
      print('[BackgroundLocation] Initialized successfully');
    } catch (e) {
      print('[BackgroundLocation] Initialization failed: $e');
      rethrow;
    }
  }

  /**
   * Register callback for location updates
   */
  void _registerLocationCallback() {
    bg.BackgroundGeolocation.onLocation((bg.Location location) {
      final lat = location.coords?.latitude;
      final lng = location.coords?.longitude;
      final acc = location.coords?.accuracy;
      if (lat == null || lng == null) {
        print('[BackgroundLocation] Ignoring non-finite location sample');
        return;
      }
      print('[BackgroundLocation] Location: ${lat}, ${lng}, accuracy: ${acc}m');
      // Call the provided callback
      if (_onLocation != null) {
        _onLocation!(location);
      }
    });
  }

  /**
   * Register callback for geofence violations
   */
  void _registerGeofenceCallback() {
    bg.BackgroundGeolocation.onGeofence((bg.GeofenceEvent event) {
      print('[BackgroundLocation] Geofence: ${event.identifier}, action: ${event.action}');
      
      // Can trigger checkpoint verification when entering delivery zone
      if (event.action == 'ENTER') {
        print('[BackgroundLocation] Entered checkpoint zone: ${event.identifier}');
      } else if (event.action == 'EXIT') {
        print('[BackgroundLocation] Exited checkpoint zone: ${event.identifier}');
      } else if (event.action == 'DWELL') {
        print('[BackgroundLocation] Dwelling in zone: ${event.identifier}');
      }
    });
  }

  /**
   * Start background location tracking
   */
  Future<void> startTracking() async {
    if (!_isInitialized) {
      throw Exception('BackgroundLocationService not initialized. Call initialize() first.');
    }

    if (_isTracking) return;

    try {
      await bg.BackgroundGeolocation.start();
      _isTracking = true;
      print('[BackgroundLocation] Tracking started.');
    } catch (e) {
      print('[BackgroundLocation] Failed to start tracking: $e');
      rethrow;
    }
  }

  /**
   * Stop background location tracking
   */
  Future<void> stopTracking() async {
    if (!_isTracking) return;

    try {
      await bg.BackgroundGeolocation.stop();
      _isTracking = false;
      print('[BackgroundLocation] Tracking stopped');
    } catch (e) {
      print('[BackgroundLocation] Failed to stop tracking: $e');
      rethrow;
    }
  }

  /**
   * Get current location immediately
   * Useful for GPS gate verification at pickup/dropoff
   */
  Future<bg.Location> getCurrentLocation() async {
    try {
      final location = await bg.BackgroundGeolocation.getCurrentPosition(
        samples: 3, // Take 3 samples for accuracy
        timeout: 30, // 30 second timeout
        maximumAge: 5000, // Use cache if < 5 seconds old
      );
      return location;
    } catch (e) {
      print('[BackgroundLocation] Failed to get current location: $e');
      rethrow;
    }
  }

  /**
   * Add geofence for checkpoint
   * Triggers callback when courier enters/exits zone
   */
  Future<void> addCheckpointGeofence({
    required String checkpointId,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    if (!_isInitialized) return;

    try {
      await bg.BackgroundGeolocation.addGeofence(bg.Geofence(
        identifier: checkpointId,
        latitude: latitude,
        longitude: longitude,
        radius: radiusMeters,
        notifyOnEntry: true,
        notifyOnExit: true,
        loiteringDelay: 30000, // 30 second dwell time before DWELL event
      ));
      print('[BackgroundLocation] Geofence added: $checkpointId (${radiusMeters}m)');
    } catch (e) {
      print('[BackgroundLocation] Failed to add geofence: $e');
    }
  }

  /**
   * Remove geofence
   */
  Future<void> removeCheckpointGeofence(String checkpointId) async {
    if (!_isInitialized) return;

    try {
      await bg.BackgroundGeolocation.removeGeofence(checkpointId);
      print('[BackgroundLocation] Geofence removed: $checkpointId');
    } catch (e) {
      print('[BackgroundLocation] Failed to remove geofence: $e');
    }
  }

  /**
   * Get list of currently tracked geofences
   */
  Future<List<bg.Geofence>> getGeofences() async {
    if (!_isInitialized) return [];

    try {
      final geofences = await bg.BackgroundGeolocation.geofences;
      return geofences;
    } catch (e) {
      print('[BackgroundLocation] Failed to get geofences: $e');
      return [];
    }
  }

  /**
   * Enable/disable location accuracy filter
   * When enabled, poor accuracy locations are ignored
   */
  Future<void> setDesiredAccuracy(int accuracy) async {
    if (!_isInitialized) return;

    // This plugin version does not expose a direct `setDesiredAccuracy` API.
    // Keep as a no-op for compatibility; log the requested value.
    print('[BackgroundLocation] setDesiredAccuracy called with: $accuracy (no-op for this plugin version)');
  }

  /**
   * Enable motion activity recognition
   * Intelligently pauses tracking when stationary
   */
  Future<void> enableMotionActivityRecognition() async {
    if (!_isInitialized) return;
    // Activity recognition start is not available in this plugin version.
    print('[BackgroundLocation] Motion activity recognition not available; omitted');
  }

  /**
   * Check permission and request if needed
   */
  Future<bool> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission != LocationPermission.always) {
        return false;
      }

      return true;
    } catch (e) {
      print('[BackgroundLocation] Permission check failed: $e');
      return false;
    }
  }

  /**
   * Cleanup: Stop tracking and reset state
   */
  Future<void> dispose() async {
    if (_isTracking) {
      await stopTracking();
    }
    _isInitialized = false;
    print('[BackgroundLocation] Disposed');
  }
}