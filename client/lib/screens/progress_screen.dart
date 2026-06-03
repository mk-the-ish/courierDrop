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
  List<Map<String, dynamic>> _parcels = const [];
  Map<String, dynamic>? _selected;
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final savedId = (await SharedPreferences.getInstance()).getString(_prefsKey);
      final dashboard = await widget.authState.apiClient.getClientDashboard();
      final parcels = dashboard.parcels;
      if (!mounted) return;
      setState(() {
        _parcels = parcels;
        _selected = null;
        if (savedId != null) {
          for (final parcel in parcels) {
            if (parcel["id"]?.toString() == savedId) {
              _selected = parcel;
              break;
            }
          }
        }
        _selected ??= parcels.isNotEmpty ? parcels.first : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
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
          if (_parcels.isNotEmpty)
            DropdownButtonFormField<String>(
              hint: const Text("Select parcel"),
              value: selected?["id"]?.toString(),
              decoration: InputDecoration(
                labelText: "Live parcel",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.inventory_2_outlined),
              ),
              items: _parcels
                  .map(
                    (parcel) => DropdownMenuItem<String>(
                      value: parcel["id"]?.toString(),
                      child: Text(_parcelLabel(parcel)),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                final parcel = _parcels.firstWhere((item) => item["id"]?.toString() == value);
                setState(() => _selected = parcel);
                await _persistSelection(value);
              },
            )
          else if (!_loading)
            const _ProgressEmptyState(),
          const SizedBox(height: 12),
          if (_error != null) ...[
            _ErrorCard(message: _error!, onRetry: _loadSelection),
          ] else if (_loading || selected == null) ...[
            _EmptyProgressState(pulse: _pulse),
          ] else ...[
            _StatusBanner(pulse: _pulse, label: _statusHeadline(selected)),
            const SizedBox(height: 14),
            _ProgressCard(
              progress: _progressFor(selected),
              statusIndex: _statusIndexFor(selected),
              eta: _etaLabel(selected),
              pulse: _pulse,
              parcel: selected,
            ),
          ],
        ],
      ),
    );
  }

  String _parcelLabel(Map<String, dynamic> parcel) {
    final description = parcel["description"]?.toString().trim();
    final size = parcel["size"]?.toString().trim();
    final id = parcel["id"]?.toString() ?? "-";
    if (description != null && description.isNotEmpty) {
      return size != null && size.isNotEmpty ? "$description ($size)" : description;
    }
    if (size != null && size.isNotEmpty) {
      return "$size parcel";
    }
    return id;
  }

  String _statusHeadline(Map<String, dynamic> parcel) {
    final status = parcel["status"]?.toString().trim();
    if (status == null || status.isEmpty) {
      return "Your parcel is on the way";
    }
    return status.replaceAll("_", " ");
  }

  int _progressFor(Map<String, dynamic> parcel) {
    final raw = parcel["progress"] ?? parcel["progress_percent"] ?? parcel["progressPercent"];
    if (raw is num) return raw.round().clamp(0, 100);
    final status = parcel["status"]?.toString().toUpperCase() ?? "";
    if (status.contains("DELIVERED") || status.contains("COMPLETED")) return 100;
    if (status.contains("PICKUP")) return 20;
    if (status.contains("TRANSIT") || status.contains("IN_TRANSIT") || status.contains("ON_THE_WAY")) return 45;
    return 25;
  }

  int _statusIndexFor(Map<String, dynamic> parcel) {
    final raw = parcel["statusIndex"] ?? parcel["status_index"];
    if (raw is num) return raw.round().clamp(0, 2);
    final progress = _progressFor(parcel);
    if (progress >= 70) return 2;
    if (progress >= 25) return 1;
    return 0;
  }

  String _etaLabel(Map<String, dynamic> parcel) {
    final eta = parcel["eta"]?.toString().trim() ?? parcel["etaLabel"]?.toString().trim();
    if (eta != null && eta.isNotEmpty) return eta;
    final etaMinutes = parcel["etaMinutes"] ?? parcel["eta_minutes"];
    if (etaMinutes is num) {
      return "~${etaMinutes.round()} min";
    }
    return "~18 min";
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

class _ProgressEmptyState extends StatelessWidget {
  const _ProgressEmptyState();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dropCityAlertAmber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: dropCitySafeSlate)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text("Retry")),
        ],
      ),
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
    required this.parcel,
  });

  final int progress;
  final int statusIndex;
  final String eta;
  final AnimationController pulse;
  final Map<String, dynamic> parcel;

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
