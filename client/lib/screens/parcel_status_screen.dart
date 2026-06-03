import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class ParcelStatusScreen extends StatefulWidget {
  const ParcelStatusScreen({
    super.key,
    required this.authState,
    this.initialParcelId,
  });

  final AuthState authState;
  final String? initialParcelId;

  @override
  State<ParcelStatusScreen> createState() => _ParcelStatusScreenState();
}

class _ParcelStatusScreenState extends State<ParcelStatusScreen> {
  late final Future<Map<String, dynamic>> _parcelFuture = _loadParcel();

  Future<Map<String, dynamic>> _loadParcel() async {
    if (widget.initialParcelId == null || widget.initialParcelId!.isEmpty) {
      final dashboard = await widget.authState.apiClient.getClientDashboard();
      if (dashboard.parcels.isNotEmpty) {
        return widget.authState.apiClient.getParcelStatus(dashboard.parcels.first["id"]?.toString() ?? "");
      }
      throw Exception("No parcel available.");
    }
    return widget.authState.apiClient.getParcelStatus(widget.initialParcelId!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _parcelFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final error = snapshot.error?.toString();
        final parcel = snapshot.data;
        return Scaffold(
          backgroundColor: dropCityCloudWhite,
          appBar: AppBar(
            backgroundColor: dropCityCloudWhite,
            foregroundColor: dropCitySafeSlate,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text("Delivery Status", style: TextStyle(fontWeight: FontWeight.w900)),
            actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.ios_share_outlined))],
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _HeroBanner(parcel: parcel!),
                        const SizedBox(height: 18),
                        _RouteSection(parcel: parcel),
                        const SizedBox(height: 18),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        const Text("DELIVERY PROGRESS", style: TextStyle(color: dropCitySlateGrey, fontWeight: FontWeight.w800, letterSpacing: .8)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 10,
                                  value: _progress(parcel) / 100,
                                  color: dropCityActiveMint,
                                  backgroundColor: dropCitySlateGrey.withOpacity(.20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text("${_progress(parcel)}%", style: const TextStyle(color: dropCityTransitTeal, fontSize: 22, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: const [
                            _Checkpoint(icon: Icons.check, color: dropCityTransitTeal, title: "Accepted", subtitle: "Completed"),
                            _Checkpoint(icon: Icons.circle, color: dropCityAlertAmber, title: "On the way", subtitle: "In progress", active: true),
                            _Checkpoint(icon: Icons.circle_outlined, color: dropCitySlateGrey, title: "Delivered", subtitle: "Pending"),
                          ],
                        ),
                        const SizedBox(height: 22),
                        const Divider(height: 1),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: dropCityTransitTeal),
                            const SizedBox(width: 10),
                            Text(_etaLabel(parcel), style: const TextStyle(color: dropCityTransitTeal, fontSize: 22, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: dropCitySlateGrey, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.report_gmailerrorred_outlined, color: dropCitySafeSlate),
                          label: const Text("Report an Issue", style: TextStyle(color: dropCitySafeSlate, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
        );
      },
    );
  }

  int _progress(Map<String, dynamic> parcel) {
    final raw = parcel["progress"] ?? parcel["progress_percent"] ?? parcel["progressPercent"];
    if (raw is num) return raw.round().clamp(0, 100);
    final status = parcel["status"]?.toString().toUpperCase() ?? "";
    if (status.contains("DELIVERED") || status.contains("COMPLETED")) return 100;
    if (status.contains("PICKUP")) return 20;
    if (status.contains("TRANSIT") || status.contains("IN_TRANSIT") || status.contains("ON_THE_WAY")) return 45;
    return 25;
  }

  String _etaLabel(Map<String, dynamic> parcel) {
    final eta = parcel["eta"]?.toString().trim() ?? parcel["etaLabel"]?.toString().trim();
    if (eta != null && eta.isNotEmpty) return eta;
    final etaMinutes = parcel["etaMinutes"] ?? parcel["eta_minutes"];
    if (etaMinutes is num) return "~${etaMinutes.round()} min";
    return "~18 minutes remaining";
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.parcel});
  final Map<String, dynamic> parcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: dropCityTransitTeal, borderRadius: BorderRadius.circular(22)),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.18), shape: BoxShape.circle),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text((parcel["status"]?.toString() ?? "IN TRANSIT").toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(parcel["description"]?.toString() ?? "Parcel", style: const TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 14),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const CircleAvatar(radius: 22, backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(parcel["courier"]?.toString() ?? "Courier", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text("★ ${parcel["rating"] ?? "4.8"}", style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(parcel["vehicle"]?.toString() ?? "VEHICLE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteSection extends StatelessWidget {
  const _RouteSection({required this.parcel});
  final Map<String, dynamic> parcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: dropCitySlateGrey.withOpacity(.16))),
      child: Column(
        children: [
          _StopRow(title: "PICKUP", main: parcel["pickupTitle"]?.toString() ?? "-", sub: parcel["pickupSub"]?.toString() ?? "-"),
          const SizedBox(height: 20),
          Container(height: 32, width: 2, decoration: BoxDecoration(color: dropCityTransitTeal.withOpacity(.6), borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 20),
          _StopRow(title: "DROPOFF", main: parcel["dropoffTitle"]?.toString() ?? "-", sub: parcel["dropoffSub"]?.toString() ?? "-"),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.title, required this.main, required this.sub});
  final String title;
  final String main;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 14, height: 14, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: dropCityTransitTeal, shape: BoxShape.circle)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: dropCitySlateGrey, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(main, style: const TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: dropCitySlateGrey, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Checkpoint extends StatelessWidget {
  const _Checkpoint({required this.icon, required this.color, required this.title, required this.subtitle, this.active = false});
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(active ? .16 : .12),
            border: Border.all(color: color.withOpacity(active ? .35 : .20), width: active ? 3 : 1.2),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(color: dropCitySafeSlate, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: dropCitySlateGrey)),
      ],
    );
  }
}
