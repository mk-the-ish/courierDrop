import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";
import "../services/courier_tracking_service.dart";
import "../services/tracking_outbox.dart";

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _assigned = const [];
  List<Map<String, dynamic>> _pending = const [];
  List<Map<String, dynamic>> _routes = const [];
  Map<String, dynamic>? _vehicle;
  int _trackingQueueCount = 0;
  int _trackingDeadLetterCount = 0;
  String? _trackingLastSyncAt;
  String? _trackingLastError;
  bool _trackingRunning = false;
  List<Map<String, dynamic>> _deviationAlerts = const [];
  String _serviceState = "OFFLINE";
  String? _activeRouteId;
  String? _selectedRouteId;
  List<Map<String, dynamic>> _notifications = const [];
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final assignedFuture = widget.authState.apiClient.getAssignedParcels();
      final pendingFuture = widget.authState.apiClient.getPendingParcels();
      final routesFuture = widget.authState.apiClient.getCourierRoutes();

      final assigned = await assignedFuture;
      final pending = await pendingFuture;
      final routes = await routesFuture;
      final alerts = await widget.authState.apiClient.getMyTrackingAlerts();
      final serviceState = await widget.authState.apiClient.getCourierServiceState();
      final notifications = await widget.authState.apiClient.getMyNotifications(limit: 30);

      Map<String, dynamic>? vehicle;
      try {
        vehicle = await widget.authState.apiClient.getMyVehicle();
      } catch (_) {
        vehicle = null;
      }

      if (!mounted) return;
      setState(() {
        _assigned = assigned;
        _pending = pending;
        _routes = routes;
        _vehicle = vehicle;
        _deviationAlerts = alerts;
        _serviceState = serviceState["state"]?.toString() ?? "OFFLINE";
        _activeRouteId = serviceState["current_route_id"]?.toString();

        final activeDeclaredRoute = _routes.cast<Map<String, dynamic>?>().firstWhere(
              (route) => (route?["status"]?.toString() ?? "") == "ACTIVE",
              orElse: () => null,
            );
        final activeDeclaredRouteId = activeDeclaredRoute?["id"]?.toString();
        if (activeDeclaredRouteId != null && activeDeclaredRouteId.isNotEmpty) {
          _selectedRouteId = activeDeclaredRouteId;
        } else {
          _selectedRouteId ??= _routes.isNotEmpty ? _routes.first["id"]?.toString() : null;
        }

        _notifications = notifications;
        _unreadNotifications = notifications
            .where((item) => (item["status"]?.toString() ?? "") == "unread")
            .length;
      });
      await _loadTrackingHealth();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Notifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () async {
                        await widget.authState.apiClient.markAllNotificationsRead();
                        if (mounted) Navigator.of(context).pop();
                        await _loadDashboard();
                      },
                      child: const Text("Mark all read"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _notifications
                        .map(
                          (item) => ListTile(
                            title: Text(item["title"]?.toString() ?? "-"),
                            subtitle: Text(item["body"]?.toString() ?? "-"),
                            trailing: (item["status"]?.toString() ?? "") == "unread"
                                ? TextButton(
                                    onPressed: () async {
                                      final id = item["id"]?.toString();
                                      if (id == null || id.isEmpty) return;
                                      await widget.authState.apiClient.markNotificationRead(id);
                                      if (mounted) Navigator.of(context).pop();
                                      await _loadDashboard();
                                    },
                                    child: const Text("Read"),
                                  )
                                : const Icon(Icons.done, size: 16),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadTrackingHealth() async {
    try {
      final outbox = TrackingOutbox();
      final count = await outbox.count();
      final deadLetterCount = await outbox.deadLetterCount();
      await outbox.close();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _trackingQueueCount = count;
        _trackingDeadLetterCount = deadLetterCount;
        _trackingLastSyncAt = prefs.getString(CourierTrackingService.prefLastSyncAt);
        _trackingLastError = prefs.getString(CourierTrackingService.prefLastError);
        _trackingRunning = prefs.getBool(CourierTrackingService.prefIsRunning) ?? false;
      });
    } catch (_) {
      // Keep dashboard usable even if health read fails.
    }
  }

  int _countByStatus(List<Map<String, dynamic>> parcels, String status) {
    final wanted = status.toUpperCase();
    return parcels.where((item) => (item["status"]?.toString().toUpperCase() ?? "") == wanted).length;
  }

  String _formatTrackingFreshness(String? isoValue) {
    if (isoValue == null || isoValue.isEmpty) return "No successful sync yet";
    final parsed = DateTime.tryParse(isoValue)?.toLocal();
    if (parsed == null) return "No successful sync yet";
    final diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) return "Synced just now";
    if (diff.inMinutes < 60) return "Synced ${diff.inMinutes}m ago";
    return "Synced ${diff.inHours}h ago";
  }

  String _deviationLabel(String value) {
    switch (value) {
      case "OFF_CORRIDOR_PROLONGED":
        return "Off corridor for too long";
      case "NO_RECENT_TRACKING":
        return "No recent tracking pulse";
      default:
        return value;
    }
  }

  Future<void> _toggleOnline(bool online) async {
    try {
      await widget.authState.apiClient.setCourierOnline(online);
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Availability update failed: $error")),
      );
    }
  }

  Future<void> _startTravel() async {
    final selectedRoute = _routes.firstWhere(
      (route) => route["id"]?.toString() == _selectedRouteId,
      orElse: () => const <String, dynamic>{},
    );
    final routeId = selectedRoute["id"]?.toString();
    final corridorId = selectedRoute["corridor_id"]?.toString();
    if (routeId == null || routeId.isEmpty || corridorId == null || corridorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a declared route linked to a corridor.")),
      );
      return;
    }
    try {
      await widget.authState.apiClient.updateCourierRouteStatus(routeId: routeId, action: "activate");
      await widget.authState.apiClient.startCourierTravel(corridorId);
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Start route failed: $error")),
      );
    }
  }

  Future<void> _endTravel() async {
    try {
      if (_selectedRouteId != null && _selectedRouteId!.isNotEmpty) {
        await widget.authState.apiClient.updateCourierRouteStatus(
          routeId: _selectedRouteId!,
          action: "complete",
        );
      }
      await widget.authState.apiClient.endCourierTravel();
      await _loadDashboard();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("End route failed: $error")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inTransit = _countByStatus(_assigned, "IN_TRANSIT");
    final completed = _countByStatus(_assigned, "COMPLETED");
    final vehicleType = _vehicle?["vehicleType"]?.toString();
    final plate = _vehicle?["licensePlate"]?.toString();
    final activeRoutes = _routes.where((route) => (route["status"]?.toString() ?? "") == "ACTIVE").length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("DropCity Courier"),
        actions: [
          IconButton(
            tooltip: "Notifications",
            onPressed: _openNotifications,
            icon: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_none),
            ),
          ),
          IconButton(
            tooltip: "Refresh",
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Route Management",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Live courier activity and route readiness",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _InfoChip(label: "Active routes", value: activeRoutes.toString()),
                          _InfoChip(label: "Assigned", value: _assigned.length.toString()),
                          _InfoChip(label: "Pending", value: _pending.length.toString()),
                          _InfoChip(label: "Tracking", value: _trackingRunning ? "Live" : "Paused"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "Could not load dashboard: $_error",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Service State", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Current state: $_serviceState"),
                      Text(
                        vehicleType == null
                            ? "Vehicle info not available"
                            : "Vehicle: $vehicleType${plate == null ? "" : " • $plate"}",
                      ),
                      if (_activeRouteId != null && _activeRouteId!.isNotEmpty) Text("Active route: $_activeRouteId"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _serviceState == "ONLINE" ? () => _toggleOnline(false) : null,
                              child: const Text("Go OFFLINE"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _serviceState == "OFFLINE" ? () => _toggleOnline(true) : null,
                              child: const Text("Go ONLINE"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRouteId,
                        decoration: const InputDecoration(
                          labelText: "Selected declared route",
                          border: OutlineInputBorder(),
                        ),
                        items: _routes
                            .map(
                              (route) => DropdownMenuItem<String>(
                                value: route["id"]?.toString(),
                                child: Text(
                                  "Route ${(route["id"]?.toString() ?? "-").length > 6 ? (route["id"]?.toString() ?? "-").substring(0, 6) : (route["id"]?.toString() ?? "-")} • ${route["status"] ?? "PLANNED"}",
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (_serviceState == "ONLINE" || _serviceState == "OFFLINE")
                            ? (value) => setState(() => _selectedRouteId = value)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _serviceState == "ONLINE" ? _startTravel : null,
                              child: const Text("Activate Route"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _serviceState == "TRAVELLING" ? _endTravel : null,
                              child: const Text("Complete Route"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: Icon(
                    _trackingLastError == null ? Icons.health_and_safety : Icons.warning,
                    color: _trackingLastError == null ? Colors.teal : Colors.orange,
                  ),
                  title: const Text("Tracking Health"),
                  subtitle: Text(
                    _trackingLastError == null
                        ? "Service: ${_trackingRunning ? "running" : "paused"} • ${_formatTrackingFreshness(_trackingLastSyncAt)}\nOutbox queue: $_trackingQueueCount • Dead letter: $_trackingDeadLetterCount"
                        : "Sync issue detected. Outbox queue: $_trackingQueueCount • Dead letter: $_trackingDeadLetterCount\nLast error: $_trackingLastError",
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Route Deviation Alerts (${_deviationAlerts.length})",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_deviationAlerts.isEmpty) const Text("No recent route deviations."),
                      ..._deviationAlerts.take(3).map((alert) {
                        final type = alert["deviation_type"]?.toString() ?? "-";
                        final parcelId = alert["parcel_id"]?.toString() ?? "-";
                        final duration = alert["duration_seconds"]?.toString() ?? "0";
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            "• Parcel $parcelId: ${_deviationLabel(type)} (${duration}s)",
                            style: const TextStyle(color: Colors.orange),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Workload: $inTransit parcels in transit • ${_pending.length} approvals awaiting action",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 6),
        Text(
          "$value",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
