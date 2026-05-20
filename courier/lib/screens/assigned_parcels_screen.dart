import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "../auth/auth_state.dart";
import "pickup_mode_screen.dart";

class AssignedParcelsScreen extends StatefulWidget {
  const AssignedParcelsScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<AssignedParcelsScreen> createState() => _AssignedParcelsScreenState();
}

class _AssignedParcelsScreenState extends State<AssignedParcelsScreen> {
  bool _isLoading = false;
  bool _routeActive = false;
  List<Map<String, dynamic>> _pendingParcels = [];
  List<Map<String, dynamic>> _assignedParcels = [];

  @override
  void initState() {
    super.initState();
    _loadParcels();
  }

  Future<void> _loadParcels() async {
    setState(() => _isLoading = true);
    try {
      final pending = await widget.authState.apiClient.getPendingParcels();
      final assigned = await widget.authState.apiClient.getAssignedParcels();
      final state = await widget.authState.apiClient.getCourierServiceState();
      if (!mounted) return;
      setState(() {
        _pendingParcels = pending;
        _assignedParcels = assigned;
        _routeActive = (state["state"]?.toString() ?? "") == "TRAVELLING";
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Load error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptParcel(String parcelId) async {
    if (!_routeActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Start an active route before accepting parcels.")),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.authState.apiClient.acceptPendingParcel(parcelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parcel accepted!")),
      );
      await _loadParcels();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Accept error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _declineParcel(String parcelId) async {
    setState(() => _isLoading = true);
    try {
      await widget.authState.apiClient.declinePendingParcel(parcelId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Parcel declined. Next candidate assigned.")),
      );
      await _loadParcels();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Decline error: $error")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildParcelCard(Map<String, dynamic> parcel, {bool isPending = false}) {
    final status = parcel["status"]?.toString() ?? "-";
    final queueRank = parcel["queueRank"] as int?;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(parcel["id"]?.toString() ?? "Parcel"),
        subtitle: Text(
          "${parcel["origin"] ?? "-"} → ${parcel["destination"] ?? "-"}\n"
          "${parcel["size"] ?? "No size"} | ${parcel["priority"] ?? "Priority"} | Status: $status"
          "${queueRank != null ? " | Queue Rank: $queueRank" : ""}",
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: "Copy Parcel ID",
              onPressed: () async {
                final id = parcel["id"]?.toString() ?? "";
                if (id.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: id));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Parcel ID copied.")),
                );
              },
              icon: const Icon(Icons.copy),
            ),
            if (isPending) ...[
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: _isLoading || !_routeActive ? null : () => _acceptParcel(parcel["id"].toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text("Accept", style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => _declineParcel(parcel["id"].toString()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text("Decline", style: TextStyle(fontSize: 12)),
                ),
              ),
            ] else ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: OutlinedButton(
                  onPressed: _isLoading || !_routeActive
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PickupModeScreen(
                                authState: widget.authState,
                                initialParcelId: parcel["id"]?.toString(),
                                initialPickupPointWkt: parcel["pickup_point"]?.toString(),
                              ),
                            ),
                          );
                        },
                  child: const Text("Pickup", style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Parcels"),
        actions: [
          IconButton(
            tooltip: "Pickup Mode",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PickupModeScreen(authState: widget.authState),
                ),
              );
            },
            icon: const Icon(Icons.location_on),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadParcels,
        child: ListView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
          children: [
            if (!_routeActive)
              MaterialBanner(
                content: const Text("Route is not active. Activate a route to accept or pickup parcels."),
                leading: const Icon(Icons.route, color: Colors.orange),
                actions: [
                  TextButton(
                    onPressed: _loadParcels,
                    child: const Text("Refresh"),
                  ),
                ],
              ),
            if (_isLoading) const LinearProgressIndicator(),
            
            // Pending section
            if (_pendingParcels.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  "Pending Requests",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._pendingParcels.map((p) => _buildParcelCard(p, isPending: true)),
            ] else if (_pendingParcels.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No pending parcels."),
              ),
            
            // Assigned section
            if (_assignedParcels.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  "Assigned Parcels",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ..._assignedParcels.map((p) => _buildParcelCard(p, isPending: false)),
            ] else if (_assignedParcels.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text("No assigned parcels."),
              ),
          ],
        ),
      ),
    );
  }
}
