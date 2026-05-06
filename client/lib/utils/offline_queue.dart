import "dart:async";
import "dart:convert";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:dropcity_client/api/api_client.dart";
import "package:shared_preferences/shared_preferences.dart";

class OfflineQueue {
  OfflineQueue._({required ApiClient apiClient}) : _apiClient = apiClient;

  static OfflineQueue? _instance;

  static OfflineQueue instance(ApiClient apiClient) {
    _instance ??= OfflineQueue._(apiClient: apiClient);
    return _instance!;
  }

  final ApiClient _apiClient;
  StreamSubscription<List<ConnectivityResult>>? subscription;
  bool _isFlushing = false;

  static const _queueKey = "client_offline_queue";
  static const _queueLimit = 50;
  static const _baseDelaySeconds = 5;
  static const _maxDelaySeconds = 300;

  Future<void> start() async {
    await flush();
    subscription = Connectivity().onConnectivityChanged.listen((_) {
      flush();
    });
  }

  Future<void> enqueueParcel(Map<String, dynamic> payload) async {
    final item = {
      "type": "parcel",
      "payload": payload,
      "queuedAt": DateTime.now().toIso8601String(),
      "retryCount": 0,
      "nextAttemptAt": DateTime.now().toIso8601String(),
    };
    await _enqueue(item);
  }

  Future<void> flush() async {
    if (_isFlushing) {
      return;
    }
    _isFlushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_queueKey) ?? [];
      if (existing.isEmpty) {
        return;
      }
      final remaining = <String>[];
      for (final raw in existing) {
        final payload = _parsePayload(raw);
        if (payload == null) {
          continue;
        }
        if (!_isReady(payload)) {
          remaining.add(raw);
          continue;
        }
        try {
          final type = payload["type"];
          if (type == "parcel") {
            final parcelPayload =
                (payload["payload"] as Map).cast<String, dynamic>();
            await _apiClient.postParcelRequest(
              clientId: parcelPayload["clientId"] as String?,
              origin: parcelPayload["origin"] as String,
              destination: parcelPayload["destination"] as String,
              size: parcelPayload["size"] as String?,
              priority: parcelPayload["priority"] as String,
              fragile: parcelPayload["fragile"] as bool? ?? false,
              notes: parcelPayload["notes"] as String?,
            );
          }
        } catch (_) {
          final updated = _scheduleRetry(payload);
          remaining.add(jsonEncode(updated));
        }
      }
      await prefs.setStringList(_queueKey, remaining);
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_queueKey) ?? [];
    final updated = [...existing, jsonEncode(payload)];
    final trimmed = updated.length > _queueLimit
        ? updated.sublist(updated.length - _queueLimit)
        : updated;
    await prefs.setStringList(_queueKey, trimmed);
  }

  Map<String, dynamic>? _parsePayload(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  bool _isReady(Map<String, dynamic> payload) {
    final nextAttemptRaw = payload["nextAttemptAt"] as String?;
    if (nextAttemptRaw == null) {
      return true;
    }
    final nextAttempt = DateTime.tryParse(nextAttemptRaw);
    if (nextAttempt == null) {
      return true;
    }
    return DateTime.now().isAfter(nextAttempt);
  }

  Map<String, dynamic> _scheduleRetry(Map<String, dynamic> payload) {
    final current = (payload["retryCount"] as int?) ?? 0;
    final nextCount = current + 1;
    final delaySeconds = (_baseDelaySeconds * (1 << (nextCount - 1)))
        .clamp(_baseDelaySeconds, _maxDelaySeconds);
    final jitter = (delaySeconds * 0.2).round();
    final jitterOffset = jitter == 0
        ? 0
        : (DateTime.now().millisecondsSinceEpoch % (jitter * 2)) - jitter;
    final nextAttempt = DateTime.now().add(
      Duration(seconds: delaySeconds + jitterOffset),
    );
    return {
      ...payload,
      "retryCount": nextCount,
      "nextAttemptAt": nextAttempt.toIso8601String(),
    };
  }
}
