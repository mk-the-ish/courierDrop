import "package:flutter/material.dart";
import "dart:async";
import 'dart:ui' as ui;
import "package:latlong2/latlong.dart";
import "../auth/auth_state.dart";
import "../services/map_service.dart";
import "delivery_creation_flow_screen.dart";
import "parcel_status_screen.dart";
import "../theme.dart";

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
  final MapService _mapService = MapService();
  final Map<String, String> _placeNameCache = {};
  bool _ratingSheetOpen = false;
  final Set<String> _ratingInProgress = {};
  List<Map<String, dynamic>> _notifications = const [];
  int _unreadNotifications = 0;
  Map<String, dynamic>? _latestEtaUpdate;

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
      final notifications =
          await widget.authState.apiClient.getMyNotifications(limit: 30);
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = data.stats;
        _parcels = data.parcels;
        _notifications = notifications;
        _unreadNotifications = notifications
            .where((item) => (item["status"]?.toString() ?? "") == "unread")
            .length;
        _latestEtaUpdate = notifications.cast<Map<String, dynamic>>().firstWhere(
              (item) =>
                  (item["type"]?.toString() ?? "") ==
                  "tracking.sender_eta_update",
              orElse: () => const {},
            );
        if (_latestEtaUpdate != null && _latestEtaUpdate!.isEmpty) {
          _latestEtaUpdate = null;
        }
      });
      _resolveParcelPlaceNames(data.parcels);
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

  Future<void> _openNotifications() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Notifications",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.authState.apiClient
                            .markAllNotificationsRead();
                        if (mounted) Navigator.of(context).pop();
                        await _loadDashboard();
                      },
                      child: const Text("Mark all read"),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _notifications
                        .map(
                          (item) => ListTile(
                            title: Text(item["title"]?.toString() ?? "-"),
                            subtitle: Text(item["body"]?.toString() ?? "-"),
                            trailing: (item["status"]?.toString() ?? "") == "unread"
                                ? TextButton(
                                    onPressed: () async {
                                      final id = item["id"]?.toString();
                                      if (id == null || id.isEmpty) return;
                                      await widget.authState.apiClient
                                          .markNotificationRead(id);
                                      if (mounted) Navigator.of(context).pop();
                                      await _loadDashboard();
                                    },
                                    child: const Text("Read"),
                                  )
                                : const Icon(Icons.done, size: 16),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

  LatLng? _parseLatLng(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith("POINT(") && trimmed.endsWith(")")) {
      final inner = trimmed.substring(6, trimmed.length - 1).trim();
      final parts = inner.split(RegExp(r"[ ,]+"));
      if (parts.length >= 2) {
        final lat = double.tryParse(parts[0]);
        final lng = double.tryParse(parts[1]);
        if (lat != null && lng != null) {
          return LatLng(lat, lng);
        }
      }
      return null;
    }
    final parts = trimmed.split(RegExp(r"[ ,]+"));
    if (parts.length >= 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
    return null;
  }

  Future<String> _resolvePlaceName(String rawValue, String fallback) async {
    final location = _parseLatLng(rawValue);
    if (location == null) {
      return fallback;
    }
    try {
      final label = await _mapService.reverseGeocode(location);
      return label.isNotEmpty ? label : fallback;
    } catch (_) {
      return fallback;
    }
  }

  Future<void> _resolveParcelPlaceNames(List<Map<String, dynamic>> parcels) async {
    final candidates = parcels.take(5).toList();
    for (final parcel in candidates) {
      final parcelId = parcel["id"]?.toString();
      if (parcelId == null || parcelId.isEmpty) {
        continue;
      }
      final originKey = "$parcelId-origin";
      final destinationKey = "$parcelId-destination";
      if (_placeNameCache.containsKey(originKey) && _placeNameCache.containsKey(destinationKey)) {
        continue;
      }
      final originRaw = parcel["origin"]?.toString() ?? "";
      final destinationRaw = parcel["destination"]?.toString() ?? "";
      final originLabel = await _resolvePlaceName(originRaw, originRaw);
      final destinationLabel = await _resolvePlaceName(destinationRaw, destinationRaw);
      if (!mounted) {
        return;
      }
      setState(() {
        _placeNameCache[originKey] = originLabel;
        _placeNameCache[destinationKey] = destinationLabel;
      });
    }
  }

  String _routeTitle(Map<String, dynamic> parcel) {
    final parcelId = parcel["id"]?.toString() ?? "";
    final origin = _placeNameCache["$parcelId-origin"] ?? parcel["origin"]?.toString() ?? "Unknown";
    final destination = _placeNameCache["$parcelId-destination"] ?? parcel["destination"]?.toString() ?? "Unknown";
    final originLabel = origin.split(",").first.trim();
    final destinationLabel = destination.split(",").first.trim();
    if (originLabel.isEmpty || destinationLabel.isEmpty) {
      return "Delivery summary";
    }
    return "$originLabel → $destinationLabel";
  }

  double _parcelProgress(Map<String, dynamic> parcel) {
    final rawStatus = parcel["status"]?.toString() ?? "";
    final status = rawStatus.toUpperCase();
    if (status == "COMPLETED") {
      return 100.0;
    }
    final createdAt = DateTime.tryParse(parcel["created_at"]?.toString() ?? "");
    final etaAt = DateTime.tryParse(parcel["etaAt"]?.toString() ?? "");
    if (createdAt != null && etaAt != null && etaAt.isAfter(createdAt)) {
      final total = etaAt.difference(createdAt).inSeconds;
      final elapsed = DateTime.now().difference(createdAt).inSeconds;
      final progress = (elapsed / total) * 100.0;
      if (status == "IN_TRANSIT") {
        return progress.clamp(50.0, 99.0);
      }
      return progress.clamp(10.0, 90.0);
    }
    if (status == "IN_TRANSIT") {
      return 75.0;
    }
    return 25.0;
  }

  String _statusChipLabel(String rawStatus) {
    final status = rawStatus.toUpperCase();
    if (status == "IN_TRANSIT") {
      return "IN TRANSIT";
    }
    return "MATCHING";
  }

  Color _statusChipColor(String rawStatus) {
    final status = rawStatus.toUpperCase();
    if (status == "IN_TRANSIT") {
      return dropCityActiveMint;
    }
    return dropCityAlertAmber;
  }

  String _friendlyDateLabel(String rawValue) {
    final date = DateTime.tryParse(rawValue);
    if (date == null) {
      return rawValue;
    }
    return "${date.day}/${date.month}/${date.year}";
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

  String _formatWhen(String value) {
    try {
      final time = DateTime.parse(value);
      final diff = DateTime.now().difference(time);
      if (diff.inSeconds < 60) return "just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24) return "${diff.inHours}h ago";
      return "${diff.inDays}d ago";
    } catch (_) {
      return "-";
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
    if (normalized == "HIGH") return dropCityActiveMint;
    if (normalized == "MEDIUM") return dropCityAlertAmber;
    if (normalized == "LOW") return dropCityErrorRed;
    return dropCitySlateGrey;
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
    final totalParcels = _intStat("total");
    final pendingParcels = _intStat("pending");
    final assignedParcels = _intStat("assigned");
    final inTransitParcels = _intStat("inTransit");

    final displayName = widget.authState.user?.displayName?.split(" ").first ?? widget.authState.user?.email.split("@").first ?? "there";
    return Scaffold(
      backgroundColor: dropCityCloudWhite,
      appBar: AppBar(
        backgroundColor: dropCityCloudWhite,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Image.asset(
            "assets/images/logo.png",
            width: 36,
            height: 36,
            fit: BoxFit.contain,
          ),
        ),
        title: const Text(
          "DropCity",
          style: TextStyle(
            color: dropCitySafeSlate,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: Badge.count(
              count: _unreadNotifications,
              isLabelVisible: _unreadNotifications > 0,
              child: const Icon(Icons.notifications_none),
            ),
            tooltip: "Notifications",
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
            children: [
              Text(
                "Good morning, $displayName 👋",
                style: const TextStyle(
                  color: dropCitySafeSlate,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DeliveryCreationFlowScreen(authState: widget.authState),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: dropCityTransitTeal,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: dropCityTransitTeal.withOpacity(0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white24,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              "Send a Parcel",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              "Create a new delivery request",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "YOUR ACTIVE DELIVERIES",
                style: TextStyle(
                  color: dropCitySlateGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      "Failed to load dashboard: $_error",
                      style: const TextStyle(color: dropCityErrorRed),
                    ),
                  ),
                ),
              if (!_isLoading && _error == null && _parcels.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _EmptyBoxIllustration(size: 92, color: dropCitySlateGrey),
                          const SizedBox(height: 16),
                          const Text(
                            "No active deliveries — send your first parcel.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: dropCitySlateGrey,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ..._parcels.take(5).map((parcel) {
                final id = parcel["id"]?.toString() ?? "-";
                final status = parcel["status"]?.toString() ?? "";
                final routeTitle = _routeTitle(parcel);
                final progress = _parcelProgress(parcel) / 100.0;
                final originLabel = _placeNameCache["$id-origin"] ?? parcel["origin"]?.toString() ?? "-";
                final destinationLabel = _placeNameCache["$id-destination"] ?? parcel["destination"]?.toString() ?? "-";
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: dropCityTransitTeal.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    color: dropCityTransitTeal,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        routeTitle,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _statusChipColor(status).withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          _statusChipLabel(status),
                                          style: TextStyle(
                                            color: _statusChipColor(status),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "From: $originLabel",
                              style: const TextStyle(
                                color: dropCitySafeSlate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              originLabel,
                              style: const TextStyle(color: dropCitySlateGrey, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "To: $destinationLabel",
                              style: const TextStyle(
                                color: dropCitySafeSlate,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              destinationLabel,
                              style: const TextStyle(color: dropCitySlateGrey, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor: dropCitySlateGrey.withOpacity(0.16),
                                color: dropCityTransitTeal,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Parcel $id",
                                  style: const TextStyle(
                                    color: dropCitySlateGrey,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "${(progress * 100).round()}% complete",
                                  style: const TextStyle(
                                    color: dropCitySafeSlate,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dropCityTransitTeal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dropCityTransitTeal.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: dropCitySlateGrey)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EmptyBoxIllustration extends StatelessWidget {
  const _EmptyBoxIllustration({this.size = 72, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _EmptyBoxPainter(color),
      ),
    );
  }
}

class _EmptyBoxPainter extends CustomPainter {
  _EmptyBoxPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final rect = Rect.fromLTWH(w * 0.12, h * 0.34, w * 0.76, h * 0.5);
    canvas.drawRect(rect, paint);

    final path = ui.Path();
    path.moveTo(w * 0.12, h * 0.34);
    path.lineTo(w * 0.5, h * 0.08);
    path.lineTo(w * 0.88, h * 0.34);
    canvas.drawPath(path, paint);

    // center fold line
    canvas.drawLine(Offset(w * 0.5, h * 0.08), Offset(w * 0.5, h * 0.34), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        Text(label, style: const TextStyle(color: dropCitySlateGrey)),
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
