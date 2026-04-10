import "dart:async";
import "dart:convert";
import "dart:io";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:uuid/uuid.dart";

import "../api/api_client.dart";
import "../auth/auth_state.dart";

class ErrorReporter {
  ErrorReporter({required ApiClient apiClient, required AuthState authState})
      : _apiClient = apiClient,
        _authState = authState;

  final ApiClient _apiClient;
  final AuthState _authState;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isFlushing = false;

  static const _queueKey = "error_log_queue";
  static const _queueLimit = 50;

  Future<void> start() async {
    await _flushQueue();
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      _flushQueue();
    });
  }

  Future<void> reportFlutterError(FlutterErrorDetails details) async {
    FlutterError.presentError(details);
    await report(
      details.exception,
      details.stack ?? StackTrace.current,
      context: "flutter",
    );
  }

  Future<void> report(Object error, StackTrace stack,
      {required String context}) async {
    final device = await _deviceInfo();
    final payload = {
      "clientId": const Uuid().v4(),
      "userId": _authState.user?.uid,
      "deviceModel": device["deviceModel"],
      "osVersion": device["osVersion"],
      "stackTrace": "$error\n$stack",
      "context": {"context": context, "platform": Platform.operatingSystem},
      "timestamp": DateTime.now().toIso8601String(),
    };
    try {
      await _apiClient.postErrorLog(
        clientId: payload["clientId"] as String,
        userId: payload["userId"] as String?,
        deviceModel: payload["deviceModel"] as String?,
        osVersion: payload["osVersion"] as String?,
        stackTrace: payload["stackTrace"] as String,
        context: payload["context"] as Map<String, dynamic>,
        timestamp: payload["timestamp"] as String,
      );
    } catch (_) {
      await _enqueue(payload);
    }
  }

  Future<Map<String, String>> _deviceInfo() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      return {
        "deviceModel": android.model ?? "Android",
        "osVersion": android.version.release ?? Platform.operatingSystemVersion
      };
    }
    if (Platform.isIOS) {
      final ios = await info.iosInfo;
      return {
        "deviceModel": ios.utsname.machine ?? "iOS",
        "osVersion": ios.systemVersion ?? Platform.operatingSystemVersion
      };
    }
    return {
      "deviceModel": Platform.operatingSystem,
      "osVersion": Platform.operatingSystemVersion
    };
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
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> _flushQueue() async {
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
        try {
          await _apiClient.postErrorLog(
            clientId: payload["clientId"] as String?,
            userId: payload["userId"] as String?,
            deviceModel: payload["deviceModel"] as String?,
            osVersion: payload["osVersion"] as String?,
            stackTrace: payload["stackTrace"] as String? ?? "",
            context: (payload["context"] as Map?)?.cast<String, dynamic>(),
            timestamp: payload["timestamp"] as String?,
          );
        } catch (_) {
          remaining.add(raw);
        }
      }
      await prefs.setStringList(_queueKey, remaining);
    } finally {
      _isFlushing = false;
    }
  }
}
