import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:web_socket_channel/web_socket_channel.dart";
import "package:web_socket_channel/io.dart";
import "package:geolocator/geolocator.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:mobile_scanner/mobile_scanner.dart";

import "../auth/auth_state.dart";

class ParcelStatusScreen extends StatefulWidget {
  const ParcelStatusScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<ParcelStatusScreen> createState() => _ParcelStatusScreenState();
}

class _ParcelStatusScreenState extends State<ParcelStatusScreen> {
  final _parcelIdController = TextEditingController();
  Timer? _pollTimer;
  bool _isLoading = false;
  Map<String, dynamic>? _parcel;
  WebSocketChannel? _channel;
  bool _reconnectAttempted = false;
  List<Map<String, dynamic>> _checkpoints = [];
  bool _showAcceptedBanner = false;
  bool _dismissAcceptedForever = false;
  bool _showReassignedBanner = false;
  String? _currentTopic;
  final List<Map<String, dynamic>> _handshakeEvents = [];
  String _eventFilter = "all";
  bool _historyUnavailable = false;

  static const _dismissKey = "dismiss_courier_accepted_banner";

  @override
  void initState() {
    super.initState();
    _loadDismissPreference();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _channel?.sink.close();
    _parcelIdController.dispose();
    _unsubscribeTopic();
    super.dispose();
  }

  Future<void> _loadDismissPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final dismiss = prefs.getBool(_dismissKey) ?? false;
    if (mounted) {
      setState(() => _dismissAcceptedForever = dismiss);
    }
  }

  Future<void> _fetchStatus() async {
    final parcelId = _parcelIdController.text.trim();
    if (parcelId.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final parcel = await widget.authState.apiClient.getParcelStatus(parcelId);
      final checkpoints =
          await widget.authState.apiClient.getCheckpoints(parcelId);
      try {
        final events =
            await widget.authState.apiClient.getHandshakeEvents(parcelId);
        _mergeEvents(events);
        if (mounted) {
          setState(() => _historyUnavailable = false);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _historyUnavailable = true);
        }
      }
      if (!mounted) return;
      setState(() {
        _parcel = parcel;
        _checkpoints = checkpoints;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCheckpoints() async {
    final parcelId = _parcelIdController.text.trim();
    if (parcelId.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.authState.apiClient.generateCheckpoints(parcelId);
      await _fetchStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Generate error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIn() async {
    final parcelId = _parcelIdController.text.trim();
    if (parcelId.isEmpty) {
      return;
    }
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await widget.authState.apiClient.verifyCheckpoint(
        parcelId: parcelId,
        lat: position.latitude,
        lng: position.longitude,
      );
      await _fetchStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Checkpoint reached.")),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Check-in error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchStatus());
  }

  Future<void> _connectWebSocket() async {
    final parcelId = _parcelIdController.text.trim();
    var token = widget.authState.user?.idToken;
    if (parcelId.isEmpty) {
      return;
    }
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Live updates are not supported on web.")),
        );
      }
      return;
    }
    if (token == null || token.isEmpty) {
      token = await widget.authState.refreshSession();
    }
    if (token == null || token.isEmpty) {
      return;
    }
    await _subscribeToTopic(parcelId);
    _channel?.sink.close();
    final uri = Uri.parse("ws://localhost:8080/ws?parcelId=$parcelId");
    _channel = IOWebSocketChannel.connect(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    _channel!.stream.listen((event) {
      try {
        final decoded = jsonDecode(event.toString()) as Map<String, dynamic>;
        if (decoded["type"] == "parcel_status") {
          final payload = (decoded["payload"] as Map).cast<String, dynamic>();
          if (mounted) {
            setState(() {
              _parcel = {
                ...?_parcel,
                "status": payload["status"],
                "id": payload["parcelId"]
              };
              if (payload["status"] == "ACCEPTED") {
                if (!_dismissAcceptedForever) {
                  _showAcceptedBanner = true;
                }
              }
              if (payload["reassigned"] == true) {
                _showReassignedBanner = true;
              }
            });
          }
        }
        if (decoded["type"] == "handshake_event") {
          final payload = (decoded["payload"] as Map).cast<String, dynamic>();
          if (mounted) {
            setState(() {
              _mergeEvents([payload]);
            });
          }
        }
      } catch (_) {
        // ignore invalid messages
      }
    }, onDone: () async {
      if (_reconnectAttempted) {
        return;
      }
      _reconnectAttempted = true;
      await widget.authState.refreshSession();
      if (mounted) {
        _connectWebSocket();
      }
    });
  }

  Future<void> _scanQr() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _parcelIdController.text = result);
      await _subscribeToTopic(result);
    }
  }

  Future<void> _subscribeToTopic(String parcelId) async {
    final topic = "parcel_$parcelId";
    if (_currentTopic == topic) {
      return;
    }
    await _unsubscribeTopic();
    await FirebaseMessaging.instance.subscribeToTopic(topic);
    _currentTopic = topic;
  }

  Future<void> _unsubscribeTopic() async {
    final topic = _currentTopic;
    if (topic == null) {
      return;
    }
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    _currentTopic = null;
  }

  String _statusLabel(String status) {
    switch (status) {
      case "PINS_SET":
        return "Pins Set";
      case "IN_TRANSIT":
        return "In Transit";
      case "ACCEPTED":
        return "Courier Accepted";
      case "COMPLETED":
        return "Completed";
      case "REQUESTED":
        return "Requested";
      default:
        return status;
    }
  }

  String _eventLabel(Map<String, dynamic> event) {
    final step = event["step"]?.toString() ?? "-";
    final status = event["status"]?.toString() ?? "-";
    return "$step • $status";
  }

  String _formatWhen(String value) {
    try {
      final time = DateTime.parse(value);
      final diff = DateTime.now().difference(time);
      if (diff.inSeconds < 60) return "${diff.inSeconds}s ago";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (_) {
      return value;
    }
  }

  bool _isFailure(String status) {
    final upper = status.toUpperCase();
    return upper.contains("FAIL");
  }

  List<Map<String, dynamic>> _filteredEvents() {
    if (_eventFilter == "success") {
      return _handshakeEvents.where((e) {
        return (e["status"]?.toString() ?? "") == "SUCCESS";
      }).toList();
    }
    if (_eventFilter == "fail") {
      return _handshakeEvents.where((e) {
        return _isFailure(e["status"]?.toString() ?? "");
      }).toList();
    }
    return _handshakeEvents;
  }

  void _mergeEvents(List<Map<String, dynamic>> incoming) {
    for (final event in incoming) {
      final createdAt = event["created_at"]?.toString();
      event["created_at"] = createdAt ?? DateTime.now().toIso8601String();
      final id = event["id"]?.toString();
      final exists = _handshakeEvents.any((existing) {
        if (id != null && id.isNotEmpty) {
          return existing["id"]?.toString() == id;
        }
        return existing["step"] == event["step"] &&
            existing["status"] == event["status"] &&
            existing["created_at"] == event["created_at"];
      });
      if (!exists) {
        _handshakeEvents.insert(0, event);
      }
    }
    if (_handshakeEvents.length > 50) {
      _handshakeEvents.removeRange(50, _handshakeEvents.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _parcel?["status"]?.toString() ?? "-";
    return Scaffold(
      appBar: AppBar(title: const Text("Parcel Status")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_showAcceptedBanner)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Courier accepted your request.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showAcceptedBanner = false),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
            ),
          if (_showAcceptedBanner)
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_dismissKey, true);
                if (mounted) {
                  setState(() {
                    _dismissAcceptedForever = true;
                    _showAcceptedBanner = false;
                  });
                }
              },
              child: const Text("Dismiss forever"),
            ),
          if (_showAcceptedBanner) const SizedBox(height: 12),
          if (_showReassignedBanner)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.refresh, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      "Courier reassigned. Waiting for a new acceptance.",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showReassignedBanner = false),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),
            ),
          if (_showReassignedBanner) const SizedBox(height: 12),
          SwitchListTile(
            title: const Text("Show courier acceptance banner"),
            value: !_dismissAcceptedForever,
            onChanged: (value) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_dismissKey, !value);
              if (mounted) {
                setState(() {
                  _dismissAcceptedForever = !value;
                });
              }
            },
          ),
          TextField(
            controller: _parcelIdController,
            decoration: const InputDecoration(
              labelText: "Parcel ID",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isLoading ? null : _scanQr,
            child: const Text("Scan Parcel QR"),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          _reconnectAttempted = false;
                          _fetchStatus();
                          _startPolling();
                          _connectWebSocket();
                        },
                  child: Text(_isLoading ? "Loading..." : "Track parcel"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _generateCheckpoints,
                  child: const Text("Generate Checkpoints"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _checkIn,
                  child: const Text("Check In"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              title: Text(_statusLabel(status)),
              subtitle: Text("Status: $status"),
            ),
          ),
          if (_parcel != null) ...[
            const SizedBox(height: 8),
            ListTile(
              title: const Text("Pickup Status"),
              subtitle: Text(
                _parcel?["pickup_verified_at"] != null
                    ? "Pickup completed"
                    : "Awaiting pickup",
              ),
            ),
            ListTile(
              title: const Text("Pickup Verified At"),
              subtitle: Text(_parcel?["pickup_verified_at"]?.toString() ?? "-"),
            ),
            ListTile(
              title: const Text("Dropoff Verified At"),
              subtitle: Text(_parcel?["dropoff_verified_at"]?.toString() ?? "-"),
            ),
            const Divider(),
            const Text(
              "Geofenced Checkpoints",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_checkpoints.isEmpty)
              const Text("No checkpoints generated yet."),
            if (_checkpoints.isNotEmpty)
              ..._checkpoints.map((checkpoint) {
                final sequence = checkpoint["sequence"]?.toString() ?? "-";
                final reached = checkpoint["reached_at"] != null;
                return ListTile(
                  leading: Icon(
                    reached ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: reached ? Colors.green : Colors.grey,
                  ),
                  title: Text("Checkpoint $sequence"),
                  subtitle: Text(reached ? "Reached" : "Pending"),
                );
              }).toList(),
            const Divider(),
            const Text(
              "Handshake Events (Live)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          if (_handshakeEvents.isEmpty)
            const Text("No handshake events yet."),
          if (_historyUnavailable && _handshakeEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                "Historical events require admin access.",
                style: TextStyle(color: Colors.orange),
              ),
            ),
          if (_handshakeEvents.isNotEmpty)
            Row(
              children: [
                const Text("Filter:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _eventFilter,
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _eventFilter = value);
                  },
                  items: const [
                    DropdownMenuItem(value: "all", child: Text("All")),
                    DropdownMenuItem(value: "success", child: Text("Success")),
                    DropdownMenuItem(value: "fail", child: Text("Failures")),
                  ],
                ),
              ],
            ),
          if (_handshakeEvents.isNotEmpty)
            ..._filteredEvents().map((event) {
              final createdAt = event["created_at"]?.toString() ?? "";
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(_eventLabel(event)),
                subtitle: Text(
                  createdAt.isEmpty ? "-" : _formatWhen(createdAt),
                ),
              );
            }).toList(),
          ],
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  late MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Parcel QR")),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            final code = barcodes.first.rawValue;
            if (code != null && code.isNotEmpty) {
              _controller.stop();
              Navigator.of(context).pop(code);
            }
          }
        },
      ),
    );
  }
}
