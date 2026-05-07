import "package:flutter/material.dart";
import "dart:async";
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
  Timer? _activeParcelsTimer;
  bool _ratingSheetOpen = false;
  final Set<String> _ratingInProgress = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _activeParcelsTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => _loadDashboard(),
    );
  }

  @override
  void dispose() {
    _activeParcelsTimer?.cancel();
    super.dispose();
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
      _checkForPendingRating();
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

  void _checkForPendingRating() {
    if (!mounted || _ratingSheetOpen) {
      return;
    }
    final pending = _parcels.firstWhere(
      (parcel) {
        final status = (parcel["status"]?.toString() ?? "").toUpperCase();
        final delivered = status == "DELIVERED" || status == "COMPLETED";
        final submitted = parcel["rating_submitted"] == true;
        final id = parcel["id"]?.toString() ?? "";
        return delivered && !submitted && id.isNotEmpty && !_ratingInProgress.contains(id);
      },
      orElse: () => const {},
    );
    if (pending.isEmpty) {
      return;
    }
    final parcelId = pending["id"]?.toString() ?? "";
    if (parcelId.isEmpty) {
      return;
    }
    _showRatingSheet(parcelId);
  }

  Future<void> _showRatingSheet(String parcelId) async {
    _ratingSheetOpen = true;
    _ratingInProgress.add(parcelId);
    final result = await showModalBottomSheet<_RatingPayload>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RatingBottomSheet(parcelId: parcelId),
    );
    _ratingSheetOpen = false;
    if (result == null) {
      _ratingInProgress.remove(parcelId);
      return;
    }
    try {
      await widget.authState.apiClient.rateParcel(
        parcelId: parcelId,
        rating: result.stars,
        feedback: result.feedback,
      );
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit rating: $error")),
      );
    } finally {
      _ratingInProgress.remove(parcelId);
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
        title: const Text("DropCity Dashboard"),
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
                "Parcel Management",
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
                "Your Parcels",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_parcels.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        "No parcels yet. Request your first parcel below."),
                  ),
                ),
              ..._parcels.take(5).map((parcel) {
                final etaMinutes = (parcel["etaMinutes"] as num?)?.toInt();
                final id = parcel["id"]?.toString() ?? "-";
                final origin = parcel["origin"]?.toString() ?? "-";
                final destination = parcel["destination"]?.toString() ?? "-";
                final status =
                    _friendlyStatus(parcel["status"]?.toString() ?? "-");
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
                              _confidenceBadge(
                                  parcel["etaConfidence"]?.toString()),
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
              label: const Text("New Parcel"),
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
                    label: const Text("Pickup/Dropoff"),
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

class _RatingPayload {
  const _RatingPayload({
    required this.stars,
    required this.feedback,
  });

  final int stars;
  final String feedback;
}

class _RatingBottomSheet extends StatefulWidget {
  const _RatingBottomSheet({required this.parcelId});

  final String parcelId;

  @override
  State<_RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<_RatingBottomSheet> {
  final TextEditingController _feedbackController = TextEditingController();
  int _stars = 5;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Rate Delivery",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text("Parcel ${widget.parcelId} was delivered. How was your experience?"),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _stars = star),
                  icon: Icon(
                    star <= _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            TextField(
              controller: _feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Feedback (optional)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    _RatingPayload(
                      stars: _stars,
                      feedback: _feedbackController.text.trim(),
                    ),
                  );
                },
                child: const Text("Submit Rating"),
              ),
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
