import "package:flutter/material.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class ParcelStatusScreen extends StatelessWidget {
  const ParcelStatusScreen({
    super.key,
    required this.authState,
    this.initialParcelId,
  });

  final AuthState authState;
  final String? initialParcelId;

  @override
  Widget build(BuildContext context) {
    final parcel = {
      "status": "IN TRANSIT",
      "description": "Books (2 kg)",
      "courier": "Tanaka M.",
      "rating": "4.8 (128)",
      "vehicle": "KOMBI",
      "pickupTitle": "Parkview Shopping Centre",
      "pickupSub": "Shop 23, Parkview, Borrowdale Rd, Borrowdale, Harare",
      "dropoffTitle": "Sam Levy's Village",
      "dropoffSub": "Sam Levy's Village, Borrowdale Rd, Borrowdale, Harare",
      "progress": 45,
      "eta": "~18 minutes remaining",
    };

    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      appBar: AppBar(
        backgroundColor: dropCityCloudWhite,
        foregroundColor: dropCitySafeSlate,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text("Delivery Status", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          _HeroBanner(parcel: parcel),
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
                    value: 0.45,
                    color: dropCityActiveMint,
                    backgroundColor: dropCitySlateGrey.withOpacity(.20),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              const Text("45%", style: TextStyle(color: dropCityTransitTeal, fontSize: 22, fontWeight: FontWeight.w900)),
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
            children: const [
              Icon(Icons.access_time, color: dropCityTransitTeal),
              SizedBox(width: 10),
              Text("~18 minutes remaining", style: TextStyle(color: dropCityTransitTeal, fontSize: 22, fontWeight: FontWeight.w900)),
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
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.parcel});
  final Map<String, dynamic> parcel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dropCityTransitTeal,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parcel["status"]?.toString() ?? "IN TRANSIT", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
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
                          Text("★ ${parcel["rating"]}", style: const TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dropCitySlateGrey.withOpacity(.16)),
      ),
      child: Column(
        children: [
          _StopRow(
            title: "PICKUP",
            main: parcel["pickupTitle"]?.toString() ?? "-",
            sub: parcel["pickupSub"]?.toString() ?? "-",
          ),
          const SizedBox(height: 20),
          Container(
            height: 32,
            width: 2,
            decoration: BoxDecoration(
              color: dropCityTransitTeal.withOpacity(.6),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          _StopRow(
            title: "DROPOFF",
            main: parcel["dropoffTitle"]?.toString() ?? "-",
            sub: parcel["dropoffSub"]?.toString() ?? "-",
          ),
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
        Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(color: dropCityTransitTeal, shape: BoxShape.circle),
        ),
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
  const _Checkpoint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.active = false,
  });

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
