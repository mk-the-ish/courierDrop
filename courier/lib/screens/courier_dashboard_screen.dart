import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "assigned_parcels_screen.dart";
import "pickup_mode_screen.dart";
import "route_declaration_screen.dart";
import "settings_screen.dart";

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
  Map<String, dynamic>? _vehicle;

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

      final assigned = await assignedFuture;
      final pending = await pendingFuture;
      final corridors = await corridorsFuture;

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
        _vehicle = vehicle;
      });
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

  int _countByStatus(List<Map<String, dynamic>> parcels, String status) {
    final wanted = status.toUpperCase();
    return parcels
        .where((item) => (item["status"]?.toString().toUpperCase() ?? "") == wanted)
        .length;
  }

  int _activeRoutesCount() {
    final now = DateTime.now().toUtc();
    var count = 0;
    for (final route in _corridors) {
      final start = DateTime.tryParse(route["window_start"]?.toString() ?? "");
      final end = DateTime.tryParse(route["window_end"]?.toString() ?? "");
      if (start == null || end == null) {
        continue;
      }
      if (start.isBefore(now) && end.isAfter(now)) {
        count += 1;
      }
    }
    return count;
  }

  Map<String, dynamic>? _nextRoute() {
    final now = DateTime.now().toUtc();
    final candidates = _corridors.where((route) {
      final start = DateTime.tryParse(route["window_start"]?.toString() ?? "");
      return start != null && start.isAfter(now);
    }).toList();
    candidates.sort((a, b) {
      final aStart = DateTime.tryParse(a["window_start"]?.toString() ?? "") ?? now;
      final bStart = DateTime.tryParse(b["window_start"]?.toString() ?? "") ?? now;
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
            tooltip: "Refresh",
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(authState: widget.authState),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16),
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
                  leading: const Icon(Icons.event_available),
                  title: const Text("Next Route Window"),
                  subtitle: nextRoute == null
                      ? const Text("No upcoming route windows")
                      : Text(
                          "${nextRoute["start_location"] ?? "-"} → ${nextRoute["end_location"] ?? "-"}\n"
                          "${_formatWindow(nextRoute["window_start"]?.toString())} - ${_formatWindow(nextRoute["window_end"]?.toString())}",
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        RouteDeclarationScreen(authState: widget.authState),
                  ),
                );
              },
              icon: const Icon(Icons.add_location),
              label: const Text("Declare Route"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PickupModeScreen(authState: widget.authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text("Pickup Mode"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AssignedParcelsScreen(authState: widget.authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inventory),
                    label: const Text("Parcels"),
                  ),
                ),
              ],
            ),
          ],
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
