import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../auth/auth_state.dart";
import "../controllers/delivery_creation_controller.dart";
import "delivery_picker.dart";

class _PlaceSuggestion {
  const _PlaceSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

class DeliveryCreationFlowScreen extends StatelessWidget {
  const DeliveryCreationFlowScreen({super.key, required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DeliveryCreationController(authState: authState),
      child: const _DeliveryFlowBody(),
    );
  }
}

class _DeliveryFlowBody extends StatefulWidget {
  const _DeliveryFlowBody();

  @override
  State<_DeliveryFlowBody> createState() => _DeliveryFlowBodyState();
}

class _DeliveryFlowBodyState extends State<_DeliveryFlowBody> {
  final _descriptionController = TextEditingController();
  final _weightController = TextEditingController(text: "1");
  final _customPriceController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _recipientSearchController = TextEditingController();
  final _externalRecipientNameController = TextEditingController();
  final _externalRecipientPhoneController = TextEditingController();
  final _imagePicker = ImagePicker();

  Timer? _originDebounce;
  Timer? _destinationDebounce;
  List<_PlaceSuggestion> _originSuggestions = const [];
  List<_PlaceSuggestion> _destinationSuggestions = const [];
  List<Map<String, dynamic>> _recipientSuggestions = const [];
  bool _searchingOrigin = false;
  bool _searchingDestination = false;
  bool _searchingRecipient = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _weightController.dispose();
    _customPriceController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _recipientSearchController.dispose();
    _externalRecipientNameController.dispose();
    _externalRecipientPhoneController.dispose();
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
    super.dispose();
  }

  Future<List<_PlaceSuggestion>> _fetchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.https("nominatim.openstreetmap.org", "/search", {
      "q": q,
      "format": "jsonv2",
      "limit": "5",
    });
    final response = await http.get(uri, headers: const {"User-Agent": "dropcity-client"});
    if (response.statusCode >= 400) return const [];
    final rows = jsonDecode(response.body) as List<dynamic>;
    return rows
        .map((row) => row as Map<String, dynamic>)
        .map(
          (map) => _PlaceSuggestion(
            displayName: map["display_name"]?.toString() ?? "Unknown",
            latitude: double.tryParse(map["lat"]?.toString() ?? "") ?? 0,
            longitude: double.tryParse(map["lon"]?.toString() ?? "") ?? 0,
          ),
        )
        .where((x) => x.latitude != 0 || x.longitude != 0)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeliveryCreationController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Delivery"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Step ${c.step} of 5", style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: c.step / 5),
                ],
              ),
            ),
            Expanded(
              child: _buildStepContent(context, c),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(context, c),
    );
  }

  Widget _buildStepContent(BuildContext context, DeliveryCreationController c) {
    switch (c.step) {
      case 1:
        return _buildStep1(c);
      case 2:
        return _buildStep2(c);
      case 3:
        return _buildStep3(c);
      case 4:
        return _buildStep4(c);
      case 5:
        return _buildStep5(c);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomActions(BuildContext context, DeliveryCreationController c) {
    final canNext = c.step == 1
        ? c.canAdvanceStep1()
        : c.step == 2
            ? c.canAdvanceStep2()
            : c.step == 3
                ? c.canAdvanceStep3()
                : c.step == 4
                    ? c.canAdvanceStep4()
                    : false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          if (c.step > 1)
            Expanded(
              child: OutlinedButton(
                onPressed: c.busy ? null : c.prevStep,
                child: const Text("Back"),
              ),
            ),
          if (c.step > 1) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: c.busy
                  ? null
                  : c.step < 5
                      ? (canNext ? () => _onNext(context, c) : null)
                      : null,
              child: Text(c.step < 5 ? "Next" : "Done"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onNext(BuildContext context, DeliveryCreationController c) async {
    if (c.step == 1) {
      c.description = _descriptionController.text.trim();
      c.weightKg = double.tryParse(_weightController.text.trim()) ?? 1;
      c.nextStep();
      return;
    }
    if (c.step == 3) {
      c.originAddress = _originController.text.trim();
      c.destinationAddress = _destinationController.text.trim();
      c.nextStep();
      return;
    }
    if (c.step == 4) {
      c.recipientName = _externalRecipientNameController.text.trim();
      c.recipientPhone = _externalRecipientPhoneController.text.trim();
      try {
        await c.createOrderAndMatch();
        if (!mounted) return;
        c.nextStep();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create order: $e")),
        );
      }
      return;
    }
    c.nextStep();
  }

  Widget _buildStep1(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Parcel Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
          onChanged: (_) {
            c.description = _descriptionController.text.trim();
            c.notifyListeners();
          },
        ),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: "S", label: Text("Small")),
            ButtonSegment(value: "M", label: Text("Medium")),
            ButtonSegment(value: "L", label: Text("Large")),
          ],
          selected: {c.parcelSize},
          onSelectionChanged: (s) {
            c.parcelSize = s.first;
            c.notifyListeners();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Approx weight (kg)", border: OutlineInputBorder()),
          onChanged: (_) {
            c.weightKg = double.tryParse(_weightController.text.trim()) ?? 1;
            c.notifyListeners();
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Desired arrival time"),
          subtitle: Text(c.desiredArrivalTime == null
              ? "Not selected"
              : "${c.desiredArrivalTime}"),
          trailing: TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: now.add(const Duration(days: 30)),
                initialDate: now,
              );
              if (date == null) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
              );
              if (time == null) return;
              c.desiredArrivalTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              c.notifyListeners();
            },
            child: const Text("Pick"),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Parcel Image", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (c.parcelImageDataUrl == null)
          OutlinedButton.icon(
            onPressed: () async {
              final file = await _imagePicker.pickImage(source: ImageSource.camera);
              if (file == null) return;
              await c.setParcelImageFromPath(file.path);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text("Capture parcel photo"),
          )
        else
          Column(
            children: [
              Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: MemoryImage(base64Decode(c.parcelImageDataUrl!.split(",").last)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  final file = await _imagePicker.pickImage(source: ImageSource.camera);
                  if (file == null) return;
                  await c.setParcelImageFromPath(file.path);
                },
                child: const Text("Retake"),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStep3(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Pickup & Destination", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            final result = await Navigator.of(context).push<Map<String, dynamic>>(
              MaterialPageRoute(builder: (_) => const DeliveryPickerScreen()),
            );
            if (result == null) return;
            final pickup = result["pickup"];
            final dropoff = result["dropoff"];
            if (pickup is LatLng && dropoff is LatLng) {
              c.originLatLng = pickup;
              c.destinationLatLng = dropoff;
              c.originAddress = result["pickupAddress"]?.toString() ?? "";
              c.destinationAddress = result["dropoffAddress"]?.toString() ?? "";
              _originController.text = c.originAddress;
              _destinationController.text = c.destinationAddress;
              c.notifyListeners();
            }
          },
          icon: const Icon(Icons.map),
          label: const Text("Pick on map"),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _originController,
          decoration: const InputDecoration(labelText: "Pickup location", border: OutlineInputBorder()),
          onChanged: (value) {
            _originDebounce?.cancel();
            _originDebounce = Timer(const Duration(milliseconds: 350), () async {
              setState(() => _searchingOrigin = true);
              _originSuggestions = await _fetchPlaces(value);
              if (mounted) setState(() => _searchingOrigin = false);
            });
          },
        ),
        if (_searchingOrigin) const LinearProgressIndicator(),
        ..._originSuggestions.map((s) => ListTile(
              dense: true,
              title: Text(s.displayName),
              onTap: () {
                c.originLatLng = LatLng(s.latitude, s.longitude);
                c.originAddress = s.displayName;
                _originController.text = s.displayName;
                setState(() => _originSuggestions = const []);
                c.notifyListeners();
              },
            )),
        const SizedBox(height: 12),
        TextField(
          controller: _destinationController,
          decoration: const InputDecoration(labelText: "Destination location", border: OutlineInputBorder()),
          onChanged: (value) {
            _destinationDebounce?.cancel();
            _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
              setState(() => _searchingDestination = true);
              _destinationSuggestions = await _fetchPlaces(value);
              if (mounted) setState(() => _searchingDestination = false);
            });
          },
        ),
        if (_searchingDestination) const LinearProgressIndicator(),
        ..._destinationSuggestions.map((s) => ListTile(
              dense: true,
              title: Text(s.displayName),
              onTap: () {
                c.destinationLatLng = LatLng(s.latitude, s.longitude);
                c.destinationAddress = s.displayName;
                _destinationController.text = s.displayName;
                setState(() => _destinationSuggestions = const []);
                c.notifyListeners();
              },
            )),
      ],
    );
  }

  Widget _buildStep4(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Recipient", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SegmentedButton<RecipientMode>(
          segments: const [
            ButtonSegment(value: RecipientMode.inApp, label: Text("In-app recipient")),
            ButtonSegment(value: RecipientMode.external, label: Text("External recipient")),
          ],
          selected: {c.recipientMode},
          onSelectionChanged: (set) {
            c.recipientMode = set.first;
            c.recipientId = null;
            c.notifyListeners();
            setState(() => _recipientSuggestions = const []);
          },
        ),
        const SizedBox(height: 12),
        if (c.recipientMode == RecipientMode.inApp) ...[
          TextField(
            controller: _recipientSearchController,
            decoration: const InputDecoration(
              labelText: "Search recipient by email",
              border: OutlineInputBorder(),
            ),
            onChanged: (value) async {
              if (value.trim().length < 3) {
                setState(() => _recipientSuggestions = const []);
                return;
              }
              setState(() => _searchingRecipient = true);
              try {
                final users = await c.authState.apiClient.searchRecipientUsers(value.trim());
                setState(() => _recipientSuggestions = users);
              } finally {
                if (mounted) setState(() => _searchingRecipient = false);
              }
            },
          ),
          if (_searchingRecipient) const LinearProgressIndicator(),
          ..._recipientSuggestions.map(
            (u) => RadioListTile<String>(
              value: u["id"]?.toString() ?? "",
              groupValue: c.recipientId,
              title: Text(u["display_name"]?.toString().isNotEmpty == true
                  ? u["display_name"].toString()
                  : (u["email"]?.toString() ?? "Unknown")),
              subtitle: Text(u["email"]?.toString() ?? ""),
              onChanged: (value) {
                c.recipientId = value;
                c.notifyListeners();
              },
            ),
          ),
        ] else ...[
          TextField(
            controller: _externalRecipientNameController,
            decoration: const InputDecoration(labelText: "Recipient full name", border: OutlineInputBorder()),
            onChanged: (_) {
              c.recipientName = _externalRecipientNameController.text.trim();
              c.notifyListeners();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _externalRecipientPhoneController,
            decoration: const InputDecoration(labelText: "Recipient phone", border: OutlineInputBorder()),
            keyboardType: TextInputType.phone,
            onChanged: (_) {
              c.recipientPhone = _externalRecipientPhoneController.text.trim();
              c.notifyListeners();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildStep5(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Available Couriers",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          "Order ID: ${c.parcelId ?? "-"}",
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 10),
        if (c.recommendedPrice != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Recommended price: ${c.recommendedPrice!.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        if (c.matchedCorridors.isEmpty) ...[
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "No available couriers found yet. The order is created and matching will continue in backend.",
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          ...c.matchedCorridors.map((m) {
            final corridorId = m["corridorId"]?.toString() ?? "";
            final courierName = m["courierName"]?.toString() ?? "Courier";
            final rating = (m["courierRating"] as num?)?.toDouble();
            final recPrice = (m["recommendedPrice"] as num?)?.toDouble();
            final selected = c.selectedCorridorId == corridorId;
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: c.busy
                  ? null
                  : () {
                      c.selectedCorridorId = corridorId;
                      c.recommendedPrice = recPrice;
                      c.notifyListeners();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? Colors.teal : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                  color: selected ? Colors.teal.shade50 : Colors.white,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: selected ? Colors.teal : Colors.grey.shade300,
                      child: Text(
                        courierName.isNotEmpty ? courierName[0].toUpperCase() : "C",
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courierName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _CourierChip(
                                icon: Icons.star,
                                label: rating == null ? "No rating" : rating.toStringAsFixed(1),
                                color: Colors.amber.shade700,
                              ),
                              _CourierChip(
                                icon: Icons.payments_outlined,
                                label: recPrice == null ? "No quote" : recPrice.toStringAsFixed(2),
                                color: Colors.teal.shade700,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: corridorId,
                      groupValue: c.selectedCorridorId,
                      onChanged: c.busy
                          ? null
                          : (v) {
                              c.selectedCorridorId = v;
                              c.recommendedPrice = recPrice;
                              c.notifyListeners();
                            },
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: _customPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: "Your price offer (optional)",
              hintText: c.recommendedPrice == null
                  ? null
                  : c.recommendedPrice!.toStringAsFixed(2),
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => c.customPrice = v.trim(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: c.busy || c.selectedCorridorId == null
                ? null
                : () async {
                    try {
                      await c.requestSelectedCourier();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Courier request sent. Returning to dashboard.")),
                      );
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to request courier: $e")),
                      );
                    }
                  },
            child: Text(c.busy ? "Submitting..." : "Request selected courier"),
          ),
          const SizedBox(height: 6),
          Text(
            "After this, we return to dashboard and wait for courier confirmation.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text("Return to dashboard"),
        ),
      ],
    );
  }
}

class _CourierChip extends StatelessWidget {
  const _CourierChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
