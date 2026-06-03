import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../auth/auth_state.dart";
import "../theme.dart";
import "../widgets/dropcity_brand.dart";

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  static const _prefsKey = "progress_selected_parcel_id";

  final List<Map<String, dynamic>> _demoParcels = const [
    {
      "id": "DC12345678",
      "label": "Books (2 kg)",
      "progress": 45,
      "statusIndex": 1,
      "eta": "~18 min",
    },
    {
      "id": "DC99887766",
      "label": "Documents (0.4 kg)",
      "progress": 23,
      "statusIndex": 0,
      "eta": "~32 min",
    },
    {
      "id": "DC44556677",
      "label": "Phone charger (0.2 kg)",
      "progress": 78,
      "statusIndex": 2,
      "eta": "~8 min",
    },
  ];

  Map<String, dynamic>? _selected;
  bool _loading = true;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _loadSelection();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _selected = null;
      if (savedId != null) {
        for (final parcel in _demoParcels) {
          if (parcel["id"] == savedId) {
            _selected = parcel;
            break;
          }
        }
      }
      _loading = false;
    });
  }

  Future<void> _persistSelection(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
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
        title: const Column(
          children: [
            Text("Live Progress", style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text("Parcel ID: DC12345678", style: TextStyle(color: dropCitySlateGrey, fontSize: 12)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          DropdownButtonFormField<String>(
            hint: const Text("Select parcel"),
            value: selected?["id"]?.toString(),
            decoration: InputDecoration(
              labelText: "Live parcel",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              prefixIcon: const Icon(Icons.inventory_2_outlined),
            ),
            items: _demoParcels
                .map(
                  (parcel) => DropdownMenuItem<String>(
                    value: parcel["id"]?.toString(),
                    child: Text(parcel["label"]?.toString() ?? parcel["id"].toString()),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              final parcel = _demoParcels.firstWhere((item) => item["id"] == value);
              setState(() => _selected = parcel);
              await _persistSelection(value);
            },
          ),
          const SizedBox(height: 12),
          if (_loading || selected == null) ...[
            _EmptyProgressState(pulse: _pulse),
          ] else ...[
            _StatusBanner(pulse: _pulse, label: "Your parcel is on the way"),
            const SizedBox(height: 14),
            _ProgressCard(
              progress: selected["progress"] as int,
              statusIndex: selected["statusIndex"] as int,
              eta: selected["eta"]?.toString() ?? "~18 min",
              pulse: _pulse,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyProgressState extends StatelessWidget {
  const _EmptyProgressState({required this.pulse});

  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dropCitySafeSlate,
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: dropCityTransitTeal,
                child: Icon(Icons.inventory_2_outlined, color: Colors.white, size: 20),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  "Your parcel is on the way",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          height: 320,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_outlined, size: 72, color: dropCityTransitTeal),
                const SizedBox(height: 10),
                const Text("No parcel selected yet", style: TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text("Use the dropdown above to load a live parcel.", style: TextStyle(color: dropCitySlateGrey)),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.45 + (pulse.value * 0.45),
                      child: child,
                    );
                  },
                  child: const Icon(Icons.circle, color: dropCityActiveMint, size: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.pulse, required this.label});
  final AnimationController pulse;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dropCitySafeSlate,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, _) {
              final scale = 0.92 + pulse.value * 0.16;
              return Transform.scale(
                scale: scale,
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: dropCityActiveMint,
                  child: Icon(Icons.radio_button_checked, color: Colors.white, size: 18),
                ),
              );
            },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.statusIndex,
    required this.eta,
    required this.pulse,
  });

  final int progress;
  final int statusIndex;
  final String eta;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dropCitySlateGrey.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress / 100,
                  strokeWidth: 10,
                  backgroundColor: dropCitySlateGrey.withOpacity(0.18),
                  valueColor: const AlwaysStoppedAnimation(dropCityTransitTeal),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("$progress%", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: dropCitySafeSlate)),
                    const SizedBox(height: 8),
                    const Text("Progress", style: TextStyle(color: dropCitySlateGrey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _MilestoneRow(index: 0, activeIndex: statusIndex, title: "Picked up from sender", activeLabel: "Completed", pulse: pulse),
          _MilestoneRow(index: 1, activeIndex: statusIndex, title: "En route - Avondale checkpoint", activeLabel: "In progress", pulse: pulse),
          _MilestoneRow(index: 2, activeIndex: statusIndex, title: "Arriving at your location", activeLabel: "Pending", pulse: pulse),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dropCityCloudWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dropCitySlateGrey.withOpacity(0.16)),
            ),
            child: Column(
              children: [
                Text(eta, style: const TextStyle(color: dropCityTransitTeal, fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                const Text("Estimated arrival", style: TextStyle(color: dropCitySlateGrey)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: dropCitySlateGrey),
              SizedBox(width: 6),
              Text(
                "Your courier's location is private",
                style: TextStyle(color: dropCitySlateGrey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.index,
    required this.activeIndex,
    required this.title,
    required this.activeLabel,
    required this.pulse,
  });

  final int index;
  final int activeIndex;
  final String title;
  final String activeLabel;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final completed = index < activeIndex;
    final active = index == activeIndex;
    final pending = index > activeIndex;
    final color = completed
        ? dropCityActiveMint
        : active
            ? dropCityTransitTeal
            : dropCitySlateGrey;
    final icon = completed
        ? Icons.check_circle
        : active
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          if (active)
            AnimatedBuilder(
              animation: pulse,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.45 + (pulse.value * 0.55),
                  child: child,
                );
              },
              child: Icon(icon, color: color, size: 28),
            )
          else
            Icon(icon, color: color, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                Text(
                  completed
                      ? "Completed"
                      : active
                          ? activeLabel
                          : "Pending",
                  style: const TextStyle(color: dropCitySlateGrey),
                ),
              ],
            ),
          ),
          if (pending) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
