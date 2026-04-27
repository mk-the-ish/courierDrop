import "dart:async";
import "dart:io";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/foundation.dart";
import "package:geolocator/geolocator.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../api/api_client.dart";
import "../auth/auth_state.dart";
import "tracking_outbox.dart";

class CourierTrackingService {
  CourierTrackingService({
    required ApiClient apiClient,
    TrackingOutbox? outbox,
  })  : _apiClient = apiClient,
        _outbox = outbox ?? TrackingOutbox();

  final ApiClient _apiClient;
  final TrackingOutbox _outbox;

  static const _refreshActiveParcelsEvery = Duration(seconds: 60);
  static const _maxOutboxAge = Duration(hours: 24);
  static const _distanceFilterMeters = 25;
  static const _batchSize = 120;
  static const _maxRetryAttempts = 8;
  static const prefLastSyncAt = "tracking_health_last_sync_at";
  static const prefLastError = "tracking_health_last_error";
  static const prefLastAttemptAt = "tracking_health_last_attempt_at";
  static const prefIsRunning = "tracking_health_is_running";

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _refreshActiveParcelsTimer;

  final Set<String> _activeParcelIds = <String>{};
  bool _isRunning = false;
  bool _isFlushing = false;

  Future<void> start(AuthState authState) async {
    if (_isRunning) {
      return;
    }
    if (!authState.isAuthenticated) {
      return;
    }
    final permissionReady = await _ensureLocationPermission();
    if (!permissionReady) {
      await _setHealth(lastError: "Location permission denied");
      return;
    }
    await _setHealth(isRunning: true);
    _isRunning = true;
    await _refreshActiveParcels();
    _startPositionStream();
    _refreshActiveParcelsTimer = Timer.periodic(
      _refreshActiveParcelsEvery,
      (_) => _refreshActiveParcels(),
    );
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      flush();
    });
    await flush();
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    return true;
  }

  Future<void> stop() async {
    _isRunning = false;
    await _setHealth(isRunning: false);
    _activeParcelIds.clear();
    await _positionSub?.cancel();
    _positionSub = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _refreshActiveParcelsTimer?.cancel();
    _refreshActiveParcelsTimer = null;
  }

  Future<void> dispose() async {
    await stop();
    await _outbox.close();
  }

  Future<void> _refreshActiveParcels() async {
    try {
      final assigned = await _apiClient.getAssignedParcels();
      final activeStatuses = <String>{
        "ASSIGNED",
        "ACCEPTED",
        "PINS_SET",
        "IN_TRANSIT",
      };
      final nextIds = assigned
          .where((item) {
            final status = item["status"]?.toString().toUpperCase() ?? "";
            return activeStatuses.contains(status);
          })
          .map((item) => item["id"]?.toString() ?? "")
          .where((id) => id.isNotEmpty)
          .toSet();
      _activeParcelIds
        ..clear()
        ..addAll(nextIds);
      if (nextIds.isNotEmpty) {
        await flush();
      }
    } catch (error) {
      debugPrint("[Tracking] Failed to refresh active parcels: $error");
    }
  }

  void _startPositionStream() {
    _positionSub?.cancel();
    final locationSettings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: _distanceFilterMeters,
            intervalDuration: const Duration(seconds: 20),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: "DropCity courier tracking active",
              notificationText:
                  "Tracking delivery progress in the background.",
              enableWakeLock: true,
            ),
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: _distanceFilterMeters,
          );
    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) async {
      if (!_isRunning || _activeParcelIds.isEmpty) {
        return;
      }
      final timestamp = DateTime.now().toUtc().toIso8601String();
      for (final parcelId in _activeParcelIds) {
        final sent = await _sendLiveUpdate(
          parcelId: parcelId,
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
        );
        if (!sent) {
          await _outbox.enqueue(
            parcelId: parcelId,
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
            timestampIso: timestamp,
          );
        }
      }
      await flush();
    });
  }

  Future<bool> _sendLiveUpdate({
    required String parcelId,
    required double lat,
    required double lng,
    required double accuracy,
  }) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork =
          connectivity.any((item) => item != ConnectivityResult.none);
      if (!hasNetwork) {
        return false;
      }
      await _apiClient
          .postTrackingUpdate(
            parcelId: parcelId,
            lat: lat,
            lng: lng,
            accuracy: accuracy,
          )
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> flush() async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    await _setHealth(lastAttemptAtIso: DateTime.now().toUtc().toIso8601String());
    try {
      await _outbox.removeOlderThan(_maxOutboxAge);
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork =
          connectivity.any((item) => item != ConnectivityResult.none);
      if (!hasNetwork) {
        return;
      }

      while (true) {
        final batch = await _outbox.fetchBatch(limit: _batchSize);
        if (batch.isEmpty) {
          break;
        }
        final payload = batch.map((row) {
          return {
            "parcelId": row["parcel_id"],
            "lat": row["lat"],
            "lng": row["lng"],
            "accuracy": row["accuracy"],
            "timestamp": row["timestamp"],
          };
        }).toList();

        final response = await _apiClient.batchSyncTracking(updates: payload);
        final results = (response["results"] as List<dynamic>? ?? <dynamic>[])
            .map((entry) => (entry as Map).cast<String, dynamic>())
            .toList();

        final idsToDelete = <int>[];
        final idsToRetry = <int>[];
        final idsToDeadLetter = <int>[];
        var retryReason = "sync_failed";
        for (var i = 0; i < batch.length; i++) {
          final row = batch[i];
          final id = row["id"] as int?;
          if (id == null) {
            continue;
          }
          final result = i < results.length ? results[i] : const <String, dynamic>{};
          final status = result["status"]?.toString().toLowerCase() ?? "";
          final reason = result["reason"]?.toString().toLowerCase() ?? "";
          final retryCount = (row["retry_count"] as int?) ?? 0;

          final shouldDrop = status == "synced" ||
              status == "skipped" ||
              reason == "unauthorized" ||
              reason == "too_old" ||
              reason == "invalid_coordinates";
          if (shouldDrop) {
            idsToDelete.add(id);
          } else if (retryCount >= _maxRetryAttempts) {
            idsToDeadLetter.add(id);
          } else {
            idsToRetry.add(id);
            if (reason.isNotEmpty) {
              retryReason = reason;
            }
          }
        }

        await _outbox.deleteByIds(idsToDelete);
        await _outbox.scheduleRetry(idsToRetry, error: retryReason);
        await _outbox.moveToDeadLetter(
          idsToDeadLetter,
          reason: "max_retries_exceeded",
        );

        if (batch.length < _batchSize) {
          break;
        }
      }
      await _setHealth(
        lastSyncAtIso: DateTime.now().toUtc().toIso8601String(),
        clearError: true,
      );
    } catch (error) {
      debugPrint("[Tracking] Flush failed: $error");
      await _setHealth(lastError: error.toString());
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _setHealth({
    String? lastSyncAtIso,
    String? lastAttemptAtIso,
    String? lastError,
    bool clearError = false,
    bool? isRunning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (lastSyncAtIso != null) {
      await prefs.setString(prefLastSyncAt, lastSyncAtIso);
    }
    if (lastAttemptAtIso != null) {
      await prefs.setString(prefLastAttemptAt, lastAttemptAtIso);
    }
    if (clearError) {
      await prefs.remove(prefLastError);
    } else if (lastError != null && lastError.isNotEmpty) {
      await prefs.setString(prefLastError, lastError);
    }
    if (isRunning != null) {
      await prefs.setBool(prefIsRunning, isRunning);
    }
  }
}
