import "dart:async";
import "dart:io";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:flutter_background_geolocation/flutter_background_geolocation.dart"
    as bg;
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

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _refreshActiveParcelsTimer;

  final Set<String> _activeParcelIds = <String>{};
  bool _isRunning = false;
  bool _isFlushing = false;
  bool _bgReady = false;
  Map<String, dynamic>? _deviceInfoCache;

  Future<Map<String, dynamic>> _telemetrySnapshot() async {
    try {
      _deviceInfoCache ??= await _loadDeviceInfo();
      final connectivity = await Connectivity().checkConnectivity();
      return {
        "deviceInfo": _deviceInfoCache,
        "networkInfo": {
          "types": connectivity.map((e) => e.name).toList(),
        },
      };
    } catch (_) {
      return {
        "deviceInfo": _deviceInfoCache ?? const <String, dynamic>{},
        "networkInfo": const <String, dynamic>{},
      };
    }
  }

  Future<Map<String, dynamic>> _loadDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await plugin.androidInfo;
      return {
        "brand": a.brand,
        "model": a.model,
        "manufacturer": a.manufacturer,
        "os": "android",
        "sdkInt": a.version.sdkInt,
      };
    }
    if (Platform.isIOS) {
      final ios = await plugin.iosInfo;
      return {
        "model": ios.model,
        "name": ios.name,
        "os": "ios",
        "systemVersion": ios.systemVersion,
      };
    }
    return {"os": Platform.operatingSystem};
  }

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
    await _prepareBackgroundEngine();
    await _refreshActiveParcels();
    await _sendImmediatePulseIfPossible();
    await _startBackgroundEngine();
    _refreshActiveParcelsTimer = Timer.periodic(
      _refreshActiveParcelsEvery,
      (_) => _refreshActiveParcels(),
    );
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      flush();
    });
    await flush();
  }

  Future<void> _sendImmediatePulseIfPossible() async {
    if (_activeParcelIds.isEmpty) {
      return;
    }
    try {
      final position = await bg.BackgroundGeolocation.getCurrentPosition(
        persist: false,
        samples: 2,
        timeout: 20,
      );
      if (!position.coords.latitude.isFinite || !position.coords.longitude.isFinite) {
        return;
      }
      final timestamp = DateTime.now().toUtc().toIso8601String();
      for (final parcelId in _activeParcelIds) {
        final sent = await _sendLiveUpdate(
          parcelId: parcelId,
          lat: position.coords.latitude,
          lng: position.coords.longitude,
          accuracy: position.coords.accuracy,
        );
        if (!sent) {
          await _outbox.enqueue(
            parcelId: parcelId,
            lat: position.coords.latitude,
            lng: position.coords.longitude,
            accuracy: position.coords.accuracy,
            timestampIso: timestamp,
          );
        }
      }
    } catch (_) {
      // Fall back to stream-based updates.
    }
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
    try {
      await bg.BackgroundGeolocation.stop();
    } catch (_) {
      // ignore stop failures
    }
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
      debugPrint("[Tracking.refreshActiveParcels] Updated active parcels: ${nextIds.length} parcels (${nextIds.toList()})");
      if (nextIds.isNotEmpty) {
        await flush();
      }
    } catch (error) {
      debugPrint("[Tracking.refreshActiveParcels] Failed to refresh active parcels: $error");
    }
  }

  Future<void> _prepareBackgroundEngine() async {
    if (_bgReady) {
      return;
    }
    await bg.BackgroundGeolocation.ready(
      bg.Config(
        desiredAccuracy: bg.Config.DESIRED_ACCURACY_NAVIGATION,
        distanceFilter: _distanceFilterMeters.toDouble(),
        stopOnTerminate: false,
        startOnBoot: true,
        foregroundService: true,
        heartbeatInterval: 60,
        logLevel: bg.Config.LOG_LEVEL_OFF,
        debug: false,
      ),
    );
    _bgReady = true;
  }

  Future<void> _startBackgroundEngine() async {
    debugPrint("[Tracking.startBackgroundEngine] Starting BG geolocation engine");
    bg.BackgroundGeolocation.onLocation((location) async {
      if (!_isRunning || _activeParcelIds.isEmpty) {
        return;
      }
      if (!location.coords.latitude.isFinite || !location.coords.longitude.isFinite) {
        debugPrint("[Tracking.bgLocation] Ignored non-finite location sample");
        return;
      }
      debugPrint("[Tracking.bgLocation] Location update: lat=${location.coords.latitude}, lng=${location.coords.longitude}, accuracy=${location.coords.accuracy}m");
      final timestamp = DateTime.now().toUtc().toIso8601String();
      int sentCount = 0;
      int queuedCount = 0;
      for (final parcelId in _activeParcelIds) {
        final sent = await _sendLiveUpdate(
          parcelId: parcelId,
          lat: location.coords.latitude,
          lng: location.coords.longitude,
          accuracy: location.coords.accuracy,
        );
        if (!sent) {
          await _outbox.enqueue(
            parcelId: parcelId,
            lat: location.coords.latitude,
            lng: location.coords.longitude,
            accuracy: location.coords.accuracy,
            timestampIso: timestamp,
          );
          queuedCount++;
        } else {
          sentCount++;
        }
      }
      debugPrint("[Tracking.bgLocation] Processed location: sent=$sentCount, queued=$queuedCount, activeCount=${_activeParcelIds.length}");
      await flush();
    }, (error) async {
      await _setHealth(lastError: "bg_location_error_$error");
    });
    await bg.BackgroundGeolocation.start();
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
        debugPrint("[Tracking.sendLiveUpdate] NO_NETWORK: parcelId=$parcelId");
        return false;
      }
      debugPrint("[Tracking.sendLiveUpdate] SENDING: parcelId=$parcelId, lat=$lat, lng=$lng");
      final telemetry = await _telemetrySnapshot();
      await _apiClient
          .postTrackingUpdate(
            parcelId: parcelId,
            lat: lat,
            lng: lng,
            accuracy: accuracy,
            deviceInfo: telemetry["deviceInfo"] as Map<String, dynamic>?,
            networkInfo: telemetry["networkInfo"] as Map<String, dynamic>?,
          )
          .timeout(const Duration(seconds: 5));
      debugPrint("[Tracking.sendLiveUpdate] SUCCESS: parcelId=$parcelId");
      return true;
    } catch (error) {
      debugPrint("[Tracking.sendLiveUpdate] ERROR: parcelId=$parcelId, error=$error");
      return false;
    }
  }

  Future<void> flush() async {
    if (_isFlushing) {
      debugPrint("[Tracking.flush] Already flushing, skipping");
      return;
    }
    _isFlushing = true;
    debugPrint("[Tracking.flush] START");
    await _setHealth(lastAttemptAtIso: DateTime.now().toUtc().toIso8601String());
    try {
      await _outbox.removeOlderThan(_maxOutboxAge);
      final connectivity = await Connectivity().checkConnectivity();
      final hasNetwork =
          connectivity.any((item) => item != ConnectivityResult.none);
      if (!hasNetwork) {
        debugPrint("[Tracking.flush] NO_NETWORK, aborting");
        return;
      }

      debugPrint("[Tracking.flush] NETWORK_OK, processing queue");
      int batchesProcessed = 0;
      int totalRowsProcessed = 0;
      while (true) {
        final batch = await _outbox.fetchBatch(limit: _batchSize);
        if (batch.isEmpty) {
          debugPrint("[Tracking.flush] Queue empty, ending flush");
          break;
        }
        debugPrint("[Tracking.flush] Processing batch ${batchesProcessed + 1}: ${batch.length} rows");
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
        int deletedCount = 0, retryCount = 0, deadLetterCount = 0;
        for (var i = 0; i < batch.length; i++) {
          final row = batch[i];
          final id = row["id"] as int?;
          if (id == null) {
            continue;
          }
          final result = i < results.length ? results[i] : const <String, dynamic>{};
          final status = result["status"]?.toString().toLowerCase() ?? "";
          final reason = result["reason"]?.toString().toLowerCase() ?? "";
          final retries = (row["retry_count"] as int?) ?? 0;

          final shouldDrop = status == "synced" ||
              status == "skipped" ||
              reason == "unauthorized" ||
              reason == "too_old" ||
              reason == "invalid_coordinates";
          if (shouldDrop) {
            idsToDelete.add(id);
            deletedCount++;
          } else if (retries >= _maxRetryAttempts) {
            idsToDeadLetter.add(id);
            deadLetterCount++;
          } else {
            idsToRetry.add(id);
            retryCount++;
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

        debugPrint("[Tracking.flush] Batch result: deleted=$deletedCount, retry=$retryCount, deadLetter=$deadLetterCount");
        totalRowsProcessed += batch.length;
        batchesProcessed++;

        if (batch.length < _batchSize) {
          debugPrint("[Tracking.flush] Final batch processed, ending flush");
          break;
        }
      }
      debugPrint("[Tracking.flush] COMPLETE: ${batchesProcessed} batches, $totalRowsProcessed rows");
      await _setHealth(
        lastSyncAtIso: DateTime.now().toUtc().toIso8601String(),
        clearError: true,
      );
    } catch (error) {
      debugPrint("[Tracking.flush] FAILED: $error");
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
