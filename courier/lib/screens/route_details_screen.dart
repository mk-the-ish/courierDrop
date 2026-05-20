import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:uuid/uuid.dart";

import "../auth/auth_state.dart";
import "../theme.dart";

class RouteDetailsScreen extends StatefulWidget {
  final AuthState authState;
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> polyline;

  const RouteDetailsScreen({
    super.key,
    required this.authState,
    required this.startPoint,
    required this.endPoint,
    required this.polyline,
  });

  @override
  State<RouteDetailsScreen> createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _etaController = TextEditingController(text: "45");
  final _notesController = TextEditingController();
  bool _allowMultipleParcels = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _etaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      // Step 1: Create corridor (route definition)
      final corridorPayload = {
        "clientId": const Uuid().v4(),
        "startLocation": "${widget.startPoint.latitude},${widget.startPoint.longitude}",
        "endLocation": "${widget.endPoint.latitude},${widget.endPoint.longitude}",
        "windowStart": "00:00",
        "windowEnd": "23:59",
        "allowMultipleParcels": _allowMultipleParcels,
        "notes": _notesController.text.trim(),
      };

      final corridorId =
          await widget.authState.apiClient.postRouteDeclaration(
        clientId: corridorPayload["clientId"] as String,
        startLocation: corridorPayload["startLocation"] as String,
        endLocation: corridorPayload["endLocation"] as String,
        windowStart: corridorPayload["windowStart"] as String,
        windowEnd: corridorPayload["windowEnd"] as String,
        allowMultipleParcels: corridorPayload["allowMultipleParcels"] as bool,
        notes: corridorPayload["notes"] as String?,
      );

      // Step 2: Upload polyline/corridor line
      if (widget.polyline.length >= 2) {
        await widget.authState.apiClient.postCorridorLine(
          corridorId: corridorId,
          polyline: widget.polyline
              .map((point) => {"lat": point.latitude, "lng": point.longitude})
              .toList(),
        );
      }

      // Step 3: Create courier route WITHOUT start time (user will set it when using)
      await widget.authState.apiClient.createCourierRoute(
        corridorId: corridorId,
        plannedStartAtIso: null,
        declaredEtaMinutes: int.tryParse(_etaController.text.trim()),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route template created! Use it anytime.")),
      );

      // Return success to route_declaration_screen
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create route: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Confirm Route Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Route preview card
            Card(
              color: Colors.grey[900],
              margin: const EdgeInsets.only(bottom: 24),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Route Summary",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: dropCityTextLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLocationRow(
                      icon: Icons.location_on,
                      label: "Start Point",
                      value:
                          "${widget.startPoint.latitude.toStringAsFixed(4)}, ${widget.startPoint.longitude.toStringAsFixed(4)}",
                    ),
                    const SizedBox(height: 12),
                    _buildLocationRow(
                      icon: Icons.location_on,
                      label: "End Point",
                      value:
                          "${widget.endPoint.latitude.toStringAsFixed(4)}, ${widget.endPoint.longitude.toStringAsFixed(4)}",
                    ),
                    const SizedBox(height: 12),
                    _buildLocationRow(
                      icon: Icons.route,
                      label: "Waypoints",
                      value: "${widget.polyline.length} points",
                    ),
                  ],
                ),
              ),
            ),

            const Text(
              "Route Configuration",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: dropCityTextLight,
              ),
            ),
            const SizedBox(height: 16),

            // Form fields
            Form(
              key: _formKey,
              child: Column(
                children: [
                  // ETA
                  TextFormField(
                    controller: _etaController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: dropCityTextLight),
                    decoration: InputDecoration(
                      labelText: "Declared ETA (minutes)",
                      labelStyle: const TextStyle(color: dropCityTextGrey),
                      prefixIcon: const Icon(
                        Icons.timer_outlined,
                        color: dropCityOrangeAccent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dropCityBorderRadius),
                      ),
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? "");
                      if (n == null || n <= 0) return "Enter valid minutes";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Multiple parcels toggle
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: dropCityInputBorder),
                      borderRadius:
                          BorderRadius.circular(dropCityBorderRadius),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        "Accept Multiple Parcels",
                        style: TextStyle(color: dropCityTextLight),
                      ),
                      subtitle: const Text(
                        "Allow multiple parcels on this route",
                        style: TextStyle(color: dropCityTextGrey),
                      ),
                      value: _allowMultipleParcels,
                      onChanged:
                          _isSubmitting ? null : (v) =>
                              setState(() => _allowMultipleParcels = v),
                      activeColor: dropCityOrangeAccent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 3,
                    style: const TextStyle(color: dropCityTextLight),
                    decoration: InputDecoration(
                      labelText: "Notes (optional)",
                      labelStyle: const TextStyle(color: dropCityTextGrey),
                      hintText: "Any additional details about this route",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(dropCityBorderRadius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text("Cancel"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text("Create Route"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: dropCityOrangeAccent, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: dropCityTextGrey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: dropCityTextLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
