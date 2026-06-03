import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "pickup_mode_screen.dart";

class AssignedParcelsScreen extends StatefulWidget {
  const AssignedParcelsScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<AssignedParcelsScreen> createState() => _AssignedParcelsScreenState();
}

class _AssignedParcelsScreenState extends State<AssignedParcelsScreen> {
  bool loading = false;
  bool active = false;
  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> assigned = [];
  String filter = "All";

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final pendingRows = await widget.authState.apiClient.getPendingParcels();
      final assignedRows = await widget.authState.apiClient.getAssignedParcels();
      final state = await widget.authState.apiClient.getCourierServiceState();
      if (mounted) {
        setState(() {
          pending = pendingRows;
          assigned = assignedRows;
          active = (state["state"]?.toString() ?? "") == "TRAVELLING";
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = [...pending, ...assigned];
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Parcels"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dropCityAlertAmber,
                foregroundColor: dropCitySafeSlate,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PickupModeScreen(authState: widget.authState)),
              ),
              child: const Text("PICKUP MODE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            Wrap(
              spacing: 8,
              children: ["All", "Assigned", "In Transit", "Completed"]
                  .map((f) => ChoiceChip(label: Text(f), selected: filter == f, onSelected: (_) => setState(() => filter = f)))
                  .toList(),
            ),
            if (loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            if (!active)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dropCityAlertAmber.withOpacity(.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "No active route - activate your route to receive offers.",
                  style: TextStyle(color: dropCitySafeSlate),
                ),
              ),
            if (all.isEmpty && !loading)
              const Padding(
                padding: EdgeInsets.only(top: 90),
                child: Column(
                  children: [
                    Icon(Icons.delivery_dining, size: 72, color: dropCitySlateGrey),
                    SizedBox(height: 12),
                    Text(
                      "No parcels assigned yet - activate your route to receive offers.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: dropCitySlateGrey),
                    ),
                  ],
                ),
              ),
            ...all.map(
              (parcel) => _ParcelCard(
                parcel: parcel,
                active: assigned.contains(parcel),
                onPickup: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PickupModeScreen(
                      authState: widget.authState,
                      initialParcelId: parcel["id"]?.toString(),
                      initialPickupPointWkt: parcel["pickup_point"]?.toString(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel, required this.active, required this.onPickup});

  final Map<String, dynamic> parcel;
  final bool active;
  final VoidCallback onPickup;

  @override
  Widget build(BuildContext context) {
    final id = parcel["id"]?.toString() ?? "";
    final status = parcel["status"]?.toString() ?? "ASSIGNED";
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: active ? dropCityTransitTeal : Colors.transparent, width: 4)),
        ),
        child: ListTile(
          onTap: onPickup,
          leading: Chip(
            label: Text(parcel["size"]?.toString() ?? "M"),
            backgroundColor: dropCityTransitTeal,
            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          title: Text(
            parcel["notes"]?.toString() ?? "Parcel ${id.length > 8 ? id.substring(0, 8) : id}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text("Virtual pickup: ${parcel["origin"] ?? "nearest corridor point"}\n23% along your route - 0.8km away"),
          isThreeLine: true,
          trailing: Chip(
            label: Text(status),
            backgroundColor: dropCityActiveMint.withOpacity(.12),
            labelStyle: const TextStyle(color: dropCityActiveMint, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
