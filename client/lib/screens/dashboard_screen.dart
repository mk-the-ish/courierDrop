import "package:flutter/material.dart";
import "../auth/auth_state.dart";
import "parcel_request_screen.dart";
import "progress_screen.dart";
import "parcel_status_screen.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _parcels = const [];

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
      final data = await widget.authState.apiClient.getClientDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = data.stats;
        _parcels = data.parcels;
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

  int _intStat(String key) {
    final value = _stats[key];
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  String _formatEta(int? minutes) {
    if (minutes == null) {
      return "No active ETA";
    }
    if (minutes <= 0) {
      return "Arriving now";
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) {
      return "$mins min";
    }
    if (mins == 0) {
      return "$hours hr";
    }
    return "$hours hr $mins min";
  }

  String _friendlyStatus(String value) {
    final status = value.toUpperCase();
    switch (status) {
      case "REQUESTED":
        return "Pending";
      case "ASSIGNED":
      case "ACCEPTED":
      case "PINS_SET":
        return "Assigned";
      case "IN_TRANSIT":
        return "In transit";
      case "COMPLETED":
        return "Completed";
      default:
        return value;
    }
  }

  String _friendlyConfidence(String? value) {
    final normalized = (value ?? "").toUpperCase();
    if (normalized == "HIGH") return "High";
    if (normalized == "MEDIUM") return "Medium";
    if (normalized == "LOW") return "Low";
    return "Unknown";
  }

  Color _confidenceColor(String? value) {
    final normalized = (value ?? "").toUpperCase();
    if (normalized == "HIGH") return Colors.green;
    if (normalized == "MEDIUM") return Colors.orange;
    if (normalized == "LOW") return Colors.red;
    return Colors.grey;
  }

  Widget _confidenceBadge(String? value) {
    return _ConfidenceBadge(
      label: _friendlyConfidence(value),
      color: _confidenceColor(value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextEtaMinutes = (_stats["nextEtaMinutes"] as num?)?.toInt();
    final nextEtaParcelId = _stats["nextEtaParcelId"]?.toString();
    final nextEtaConfidence = _stats["nextEtaConfidence"]?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text("DropCity Client"),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh dashboard",
          ),
          TextButton(
            onPressed: widget.authState.signOut,
            child: const Text(
              "Sign out",
              style: TextStyle(color: Colors.white),
            ),
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
                "Parcel Delivery Management",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Live activity for your deliveries",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "Failed to load dashboard: $_error",
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatTile(
                        icon: Icons.local_shipping,
                        iconColor: Colors.teal,
                        value: _intStat("pending"),
                        label: "Pending",
                      ),
                      _StatTile(
                        icon: Icons.assignment_turned_in,
                        iconColor: Colors.indigo,
                        value: _intStat("assigned"),
                        label: "Assigned",
                      ),
                      _StatTile(
                        icon: Icons.location_on,
                        iconColor: Colors.orange,
                        value: _intStat("inTransit"),
                        label: "In transit",
                      ),
                      _StatTile(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        value: _intStat("completed"),
                        label: "Completed",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text("Next ETA: ${_formatEta(nextEtaMinutes)}"),
                  subtitle: nextEtaParcelId == null
                      ? const Text("No active parcels right now")
                      : Row(
                          children: [
                            Expanded(child: Text("Parcel: $nextEtaParcelId")),
                            _confidenceBadge(nextEtaConfidence),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: const Text("Total parcels"),
                  trailing: Text(
                    "${_intStat("total")}",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Recent Parcels",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_parcels.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text("No parcels yet. Request your first parcel below."),
                  ),
                ),
              ..._parcels.take(5).map((parcel) {
                final etaMinutes = (parcel["etaMinutes"] as num?)?.toInt();
                final id = parcel["id"]?.toString() ?? "-";
                final origin = parcel["origin"]?.toString() ?? "-";
                final destination = parcel["destination"]?.toString() ?? "-";
                final status = _friendlyStatus(parcel["status"]?.toString() ?? "-");
                final canOpenStatus = id != "-";
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: !canOpenStatus
                        ? null
                        : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ParcelStatusScreen(
                                  authState: widget.authState,
                                  initialParcelId: id,
                                ),
                              ),
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Parcel $id",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text("Status: $status"),
                          Row(
                            children: [
                              Expanded(
                                child: Text("ETA: ${_formatEta(etaMinutes)}"),
                              ),
                              _confidenceBadge(parcel["etaConfidence"]?.toString()),
                            ],
                          ),
                          Text("From: $origin"),
                          Text("To: $destination"),
                          const SizedBox(height: 6),
                          const Text(
                            "Tap to open live status",
                            style: TextStyle(color: Colors.teal),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
                        ParcelRequestScreen(authState: widget.authState),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle),
              label: const Text("Request Parcel"),
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
                              ProgressScreen(authState: widget.authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation),
                    label: const Text("Progress"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ParcelStatusScreen(authState: widget.authState),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info),
                    label: const Text("Status"),
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

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
