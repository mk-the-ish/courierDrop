import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class CourierDashboardScreen extends StatefulWidget {
  const CourierDashboardScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
  bool loading = true;
  String state = "OFFLINE";
  List<Map<String, dynamic>> assigned = [];
  List<Map<String, dynamic>> pending = [];
  int completed = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      final assignedRows = await widget.authState.apiClient.getAssignedParcels();
      final pendingRows = await widget.authState.apiClient.getPendingParcels();
      final serviceState = await widget.authState.apiClient.getCourierServiceState();
      if (!mounted) return;
      setState(() {
        assigned = assignedRows;
        pending = pendingRows;
        state = serviceState["state"]?.toString() ?? "OFFLINE";
        completed = assignedRows.where((item) => (item["status"]?.toString() ?? "").toUpperCase() == "COMPLETED").length;
      });
    } catch (_) {
      // keep last-known state
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggleOnline(bool online) async {
    await widget.authState.apiClient.setCourierOnline(online);
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final online = state.toUpperCase() != "OFFLINE";
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      appBar: AppBar(
        backgroundColor: dropCityCloudWhite,
        foregroundColor: dropCitySafeSlate,
        elevation: 0,
        title: const Row(
          children: [
            Image(image: AssetImage('assets/images/logo.png'), width: 32, height: 32),
            SizedBox(width: 8),
            Text("DropCity", style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: online ? dropCityActiveMint : dropCitySlateGrey),
                const SizedBox(width: 6),
                Text(online ? "ONLINE" : "OFFLINE", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dropCitySafeSlate,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          online ? "ONLINE" : "OFFLINE",
                          style: TextStyle(
                            color: online ? dropCityActiveMint : dropCitySlateGrey,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text("Courier availability", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                  Switch(value: online, activeColor: dropCityActiveMint, onChanged: toggleOnline),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(label: "Active Deliveries", value: "${assigned.length}"),
                const SizedBox(width: 8),
                _Metric(label: "Completed Today", value: "$completed"),
                const SizedBox(width: 8),
                const _Metric(label: "Courier Score", value: "78.4"),
              ],
            ),
            const SizedBox(height: 22),
            const Text("RECENT ACTIVITY", style: TextStyle(color: dropCitySlateGrey, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 8),
            if (loading) const LinearProgressIndicator(),
            if (!loading && assigned.isEmpty && pending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text("No recent activity yet.", textAlign: TextAlign.center, style: TextStyle(color: dropCitySlateGrey)),
              )
            else
              ...((assigned.isNotEmpty ? assigned : pending).take(3).map((parcel) => _Activity(parcel: parcel, onTap: () {}))),
            const SizedBox(height: 22),
            const Text("Live state", style: TextStyle(color: dropCitySlateGrey, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: .8)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assigned: ${assigned.length}", style: const TextStyle(color: dropCitySafeSlate, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text("Pending offers: ${pending.length}", style: const TextStyle(color: dropCitySlateGrey)),
                  const SizedBox(height: 6),
                  Text("Service state: $state", style: const TextStyle(color: dropCitySlateGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: dropCityTransitTeal, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: dropCitySlateGrey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.parcel, required this.onTap});

  final Map<String, dynamic> parcel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = parcel["status"]?.toString() ?? "ASSIGNED";
    final id = parcel["id"]?.toString() ?? "-";
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text("Parcel ${id.length > 8 ? id.substring(0, 8) : id}"),
        subtitle: Text(parcel["destination"]?.toString() ?? "Route delivery"),
        trailing: Chip(
          label: Text(status),
          backgroundColor: dropCityActiveMint.withOpacity(.12),
          labelStyle: const TextStyle(color: dropCityActiveMint, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
