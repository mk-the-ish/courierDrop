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
  List<Map<String, dynamic>> _corridors = const [];
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
  String? _selectedRouteId; // declared route id
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
      final corridorsFuture = widget.authState.apiClient.getMyCorridors();
      final routesFuture = widget.authState.apiClient.getCourierRoutes();

      final assigned = await assignedFuture;
      final pending = await pendingFuture;
      final corridors = await corridorsFuture;
      final routes = await routesFuture;
      final alerts = await widget.authState.apiClient.getMyTrackingAlerts();
      final serviceState = await widget.authState.apiClient.getCourierServiceState();
      final notifications =
          await widget.authState.apiClient.getMyNotifications(limit: 30);

      Map<String, dynamic>? vehicle;
      try {
        vehicle = await widget.authState.apiClient.getMyVehicle();
      } catch (_) {
        vehicle = null;
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _assigned = assigned;
        _pending = pending;
        _corridors = corridors;
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
      if (!mounted) {
        return;
      }
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
                    const Text(
                      "Notifications",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.authState.apiClient
                            .markAllNotificationsRead();
                        if (mounted) Navigator.of(context).pop();
                        await _loadDashboard();
                      },
                      child: const Text("Mark all read"),
                    )
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
                                      await widget.authState.apiClient
                                          .markNotificationRead(id);
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
      if (!mounted) {
        return;
      }
      setState(() {
        _trackingQueueCount = count;
        _trackingDeadLetterCount = deadLetterCount;
        _trackingLastSyncAt =
            prefs.getString(CourierTrackingService.prefLastSyncAt);
        _trackingLastError =
            prefs.getString(CourierTrackingService.prefLastError);
        _trackingRunning =
            prefs.getBool(CourierTrackingService.prefIsRunning) ?? false;
      });
    } catch (_) {
      // Keep dashboard usable even if health read fails.
    }
  }

  int _countByStatus(List<Map<String, dynamic>> parcels, String status) {
    final wanted = status.toUpperCase();
    return parcels
        .where((item) => (item["status"]?.toString().toUpperCase() ?? "") == wanted)
        .length;
  }

  int _activeRoutesCount() {
    return _routes.where((route) => (route["status"]?.toString() ?? "") == "ACTIVE").length;
  }

  Map<String, dynamic>? _nextRoute() {
    final now = DateTime.now().toUtc();
    final candidates = _routes.where((route) {
      final start = DateTime.tryParse(route["planned_start_at"]?.toString() ?? "");
      return start != null && start.isAfter(now);
    }).toList();
    candidates.sort((a, b) {
      final aStart = DateTime.tryParse(a["planned_start_at"]?.toString() ?? "") ?? now;
      final bStart = DateTime.tryParse(b["planned_start_at"]?.toString() ?? "") ?? now;
      return aStart.compareTo(bStart);
    });
    return candidates.isEmpty ? null : candidates.first;
  }

  String _formatWindow(String? isoValue) {
    if (isoValue == null || isoValue.isEmpty) {
      return "-";
    }
    final date = DateTime.tryParse(isoValue)?.toLocal();
    if (date == null) {
      return "-";
    }
    final h = date.hour.toString().padLeft(2, "0");
    final m = date.minute.toString().padLeft(2, "0");
    return "${date.year}-${date.month.toString().padLeft(2, "0")}-${date.day.toString().padLeft(2, "0")} $h:$m";
  }

  String _formatTrackingFreshness(String? isoValue) {
    if (isoValue == null || isoValue.isEmpty) {
      return "No successful sync yet";
    }
    final parsed = DateTime.tryParse(isoValue)?.toLocal();
    if (parsed == null) {
      return "No successful sync yet";
    }
    final diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) {
      return "Synced just now";
    }
    if (diff.inMinutes < 60) {
      return "Synced ${diff.inMinutes}m ago";
    }
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
      await widget.authState.apiClient.updateCourierRouteStatus(
        routeId: routeId,
        action: "activate",
      );
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
    final activeRoutes = _activeRoutesCount();
    final nextRoute = _nextRoute();
    final queueTop = _pending.isEmpty ? null : _pending.first;
    final vehicleType = _vehicle?["vehicleType"]?.toString();
    final plate = _vehicle?["licensePlate"]?.toString();

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
              const Text(
                "Route Management",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Live courier activity and route readiness",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "Could not load dashboard: $_error",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatTile(
                        icon: Icons.route,
                        iconColor: Colors.blue,
                        value: activeRoutes,
                        label: "Active Routes",
                      ),
                      _StatTile(
                        icon: Icons.local_shipping,
                        iconColor: Colors.indigo,
                        value: _assigned.length,
                        label: "Assigned",
                      ),
                      _StatTile(
                        icon: Icons.inventory,
                        iconColor: Colors.orange,
                        value: _pending.length,
                        label: "Pending",
                      ),
                      _StatTile(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        value: completed,
                        label: "Completed",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.two_wheeler),
                  title: const Text("Courier Setup"),
                  subtitle: Text(
                    vehicleType == null
                        ? "Vehicle info not available"
                        : "$vehicleType${plate == null ? "" : " • $plate"}",
                  ),
                  trailing: Text(
                    vehicleType == null ? "Check" : "Ready",
                    style: TextStyle(
                      color: vehicleType == null ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
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
                      const Text(
                        "Service State",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text("Current state: $_serviceState"),
                      if (_activeRouteId != null && _activeRouteId!.isNotEmpty)
                        Text("Active route: $_activeRouteId"),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _serviceState == "ONLINE"
                                  ? () => _toggleOnline(false)
                                  : null,
                              child: const Text("Go OFFLINE"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _serviceState == "OFFLINE"
                                  ? () => _toggleOnline(true)
                                  : null,
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
                                  "Route ${((route["id"]?.toString() ?? "-").length > 6 ? (route["id"]?.toString() ?? "-").substring(0, 6) : (route["id"]?.toString() ?? "-"))} • ${route["status"] ?? "PLANNED"}",
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
                  leading: const Icon(Icons.timelapse),
                  title: const Text("Transit Workload"),
                  subtitle: Text(
                    "In transit: $inTransit • Pending approvals: ${_pending.length}",
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
                      if (_deviationAlerts.isEmpty)
                        const Text("No recent route deviations."),
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
                child: ListTile(
                  leading: const Icon(Icons.event_available),
                  title: const Text("Next Route Window"),
                  subtitle: nextRoute == null
                      ? const Text("No upcoming route windows")
                      : Text(
                          "Route ${nextRoute["id"]?.toString() ?? "-"} • ${nextRoute["status"] ?? "PLANNED"}\n"
                          "Planned start: ${_formatWindow(nextRoute["planned_start_at"]?.toString())}",
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.priority_high),
                  title: const Text("Top Queue Parcel"),
                  subtitle: queueTop == null
                      ? const Text("No pending parcel approvals")
                      : Text(
                          "Parcel ${queueTop["id"] ?? "-"} • Rank ${queueTop["queueRank"] ?? "-"}\n"
                          "${queueTop["origin"] ?? "-"} → ${queueTop["destination"] ?? "-"}",
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
