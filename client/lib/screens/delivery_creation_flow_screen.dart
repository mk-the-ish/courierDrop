import "dart:async";
import "dart:convert";

import "package:flutter/material.dart";
import "package:flutter_map/flutter_map.dart";
import "package:geolocator/geolocator.dart";
import "package:latlong2/latlong.dart";
import "package:http/http.dart" as http;
import "package:image_picker/image_picker.dart";
import "package:provider/provider.dart";

import "../auth/auth_state.dart";
import "../controllers/delivery_creation_controller.dart";
import "../services/map_service.dart";
import "delivery_picker.dart";
import "../theme.dart";
import "../widgets/dropcity_brand.dart";

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
  final MapController _mapController = MapController();
  final MapService _mapService = MapService();
  LatLng _mapCenter = const LatLng(-17.825284, 31.044512);
  bool _fragile = false;
  bool _selectingPickup = true;

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

  Future<void> _selectMapLocation(LatLng point, DeliveryCreationController c) async {
    try {
      final address = await _mapService.reverseGeocode(point);
      if (_selectingPickup) {
        c.originLatLng = point;
        c.originAddress = address;
        _originController.text = address;
      } else {
        c.destinationLatLng = point;
        c.destinationAddress = address;
        _destinationController.text = address;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(point, 14);
        }
      });
      setState(() {
        if (_selectingPickup) {
          _originSuggestions = const [];
        } else {
          _destinationSuggestions = const [];
        }
      });
      c.notifyListeners();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to select location: $error")),
        );
      }
    }
  }

  void _updateLocationFromSuggestion(_PlaceSuggestion suggestion, DeliveryCreationController c) {
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    if (_selectingPickup) {
      c.originLatLng = point;
      c.originAddress = suggestion.displayName;
      _originController.text = suggestion.displayName;
      _originSuggestions = const [];
    } else {
      c.destinationLatLng = point;
      c.destinationAddress = suggestion.displayName;
      _destinationController.text = suggestion.displayName;
      _destinationSuggestions = const [];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(point, 14);
      }
    });
    setState(() {});
    c.notifyListeners();
  }

  Future<void> _useCurrentLocation(DeliveryCreationController c) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permission is required to use current location.")),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission permanently denied. Please enable it in settings.")),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(position.latitude, position.longitude);
      final address = await _mapService.reverseGeocode(latLng);

      if (_selectingPickup) {
        c.originLatLng = latLng;
        c.originAddress = address;
        _originController.text = address;
      } else {
        c.destinationLatLng = latLng;
        c.destinationAddress = address;
        _destinationController.text = address;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(latLng, 14);
        }
      });
      setState(() {
        _mapCenter = latLng;
      });
      c.notifyListeners();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to get current location: $error")),
        );
      }
    }
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
                  Text("Step ${c.step} of 6", style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: c.step / 6),
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
      case 6:
        return _buildStep6(c);
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
                    : c.step == 5
                        ? c.canAdvanceStep5()
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
                  : c.step < 6
                      ? (canNext ? () => _onNext(context, c) : null)
                      : null,
              child: Text(c.step < 6 ? "Next" : "Done"),
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
    if (c.step == 4) {
      c.originAddress = _originController.text.trim();
      c.destinationAddress = _destinationController.text.trim();
      c.nextStep();
      return;
    }
    if (c.step == 5) {
      c.recipientName = _externalRecipientNameController.text.trim();
      c.recipientPhone = _externalRecipientPhoneController.text.trim();
      c.nextStep();
      return;
    }
    c.nextStep();
  }

  Widget _buildStep1(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const StepDots(activeIndex: 0, count: 6),
        const SizedBox(height: 28),
        const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: dropCityTransitTeal, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                "What are you sending?",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dropCitySafeSlate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text("1. Description", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dropCitySafeSlate)),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: "e.g. documents, clothing, phone",
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) {
            c.description = _descriptionController.text.trim();
            c.notifyListeners();
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text("2. Size", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dropCitySafeSlate)),
            const SizedBox(width: 10),
            Icon(Icons.info_outline, size: 19, color: dropCityTransitTeal.withOpacity(0.9)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _SizeTile(label: "S", sublabel: "Backpack", icon: Icons.backpack_outlined, selected: c.parcelSize == "S", onTap: () { c.parcelSize = "S"; c.notifyListeners(); })),
            const SizedBox(width: 12),
            Expanded(child: _SizeTile(label: "M", sublabel: "Seat", icon: Icons.airline_seat_recline_normal_outlined, selected: c.parcelSize == "M", onTap: () { c.parcelSize = "M"; c.notifyListeners(); })),
            const SizedBox(width: 12),
            Expanded(child: _SizeTile(label: "L", sublabel: "Full Seat", icon: Icons.event_seat_outlined, selected: c.parcelSize == "L", onTap: () { c.parcelSize = "L"; c.notifyListeners(); })),
          ],
        ),
        const SizedBox(height: 22),
        const Text("3. Weight", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dropCitySafeSlate)),
        const SizedBox(height: 10),
        TextField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: "Enter weight",
            filled: true,
            fillColor: Colors.white,
            suffixIcon: Container(
              alignment: Alignment.center,
              width: 64,
              child: const Text("kg", style: TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (_) {
            c.weightKg = double.tryParse(_weightController.text.trim()) ?? 1;
            c.notifyListeners();
          },
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("4. Fragile / Handle with care?", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dropCitySafeSlate)),
                  SizedBox(height: 6),
                  Text("Mark if the item is fragile or requires careful handling.", style: TextStyle(color: dropCitySlateGrey)),
                ],
              ),
            ),
            Switch(
              value: _fragile,
              onChanged: (value) {
                setState(() {
                  _fragile = value;
                  c.fragile = value;
                  c.notifyListeners();
                });
              },
              activeColor: dropCityActiveMint,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerRight,
          child: Text("1 of 6", style: TextStyle(color: dropCitySlateGrey, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  String _formatArrivalDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final date = "${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}";
    final time = "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
    return "$date $time";
  }

  Widget _buildStep2(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const StepDots(activeIndex: 1, count: 6),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.schedule_outlined, color: dropCityTransitTeal, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                "When should it arrive?",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dropCitySafeSlate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          "Desired arrival",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dropCitySafeSlate),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final now = DateTime.now();
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: c.desiredArrivalTime ?? now.add(const Duration(hours: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 14)),
            );
            if (selectedDate == null) return;
            final selectedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(c.desiredArrivalTime ?? now.add(const Duration(hours: 1))),
            );
            if (selectedTime == null) return;
            final selectedDateTime = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            setState(() {
              c.desiredArrivalTime = selectedDateTime;
              c.notifyListeners();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    c.desiredArrivalTime == null
                        ? "Tap to choose arrival date and time"
                        : _formatArrivalDateTime(c.desiredArrivalTime!),
                    style: TextStyle(
                      color: c.desiredArrivalTime == null ? dropCitySlateGrey : dropCitySafeSlate,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.calendar_today, color: dropCityTransitTeal),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          "This helps couriers plan pickup and delivery in the right time window.",
          style: TextStyle(color: dropCitySlateGrey, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildStep3(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StepDots(activeIndex: 2, count: 6),
        const SizedBox(height: 12),
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

  Widget _buildStep4(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const StepDots(activeIndex: 3, count: 6),
        const SizedBox(height: 24),
        const Row(
          children: [
            Icon(Icons.location_on_outlined, color: dropCityTransitTeal, size: 30),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                "Where should the courier meet you?",
                style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: dropCitySafeSlate),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
          ),
          clipBehavior: Clip.hardEdge,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: c.originLatLng ?? c.destinationLatLng ?? _mapCenter,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) => _selectMapLocation(point, c),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.dropcity_client',
              ),
              if (c.originLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: c.originLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_pin, color: dropCityErrorRed, size: 40),
                    ),
                  ],
                ),
              if (c.destinationLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: c.destinationLatLng!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.flag, color: dropCityTransitTeal, size: 40),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text("Pickup"),
                selected: _selectingPickup,
                onSelected: (selected) {
                  setState(() {
                    _selectingPickup = true;
                  });
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text("Dropoff"),
                selected: !_selectingPickup,
                onSelected: (selected) {
                  setState(() {
                    _selectingPickup = false;
                  });
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            _selectingPickup
                ? "Tap the map to choose a pickup point, or search above."
                : "Tap the map to choose a dropoff point, or search above.",
            style: const TextStyle(color: dropCitySlateGrey, fontSize: 14, height: 1.4),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _selectingPickup ? _originController : _destinationController,
          decoration: InputDecoration(
            hintText: _selectingPickup ? "Search pickup location..." : "Search dropoff location...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onChanged: (value) {
            if (_selectingPickup) {
              _originDebounce?.cancel();
              _originDebounce = Timer(const Duration(milliseconds: 350), () async {
                setState(() => _searchingOrigin = true);
                _originSuggestions = await _fetchPlaces(value);
                if (mounted) setState(() => _searchingOrigin = false);
              });
            } else {
              _destinationDebounce?.cancel();
              _destinationDebounce = Timer(const Duration(milliseconds: 350), () async {
                setState(() => _searchingDestination = true);
                _destinationSuggestions = await _fetchPlaces(value);
                if (mounted) setState(() => _searchingDestination = false);
              });
            }
          },
        ),
        if (_selectingPickup ? _searchingOrigin : _searchingDestination) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_selectingPickup ? _originSuggestions.isNotEmpty : _destinationSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dropCitySlateGrey.withOpacity(0.16)),
            ),
            child: Column(
              children: (_selectingPickup ? _originSuggestions : _destinationSuggestions).take(3).map((s) {
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined, color: dropCitySafeSlate),
                  title: Text(s.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _updateLocationFromSuggestion(s, c),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _useCurrentLocation(c),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: dropCityTransitTeal.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dropCityTransitTeal.withOpacity(0.18)),
            ),
            child: const Row(
              children: [
                Icon(Icons.gps_fixed, color: dropCityTransitTeal),
                SizedBox(width: 12),
                Text(
                  "Use my current location",
                  style: TextStyle(color: dropCityTransitTeal, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dropCityTransitTeal.withOpacity(0.20)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.info_outline, color: dropCityTransitTeal),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Virtual Pickup Point",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dropCitySafeSlate),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "We will auto-calculate the nearest corridor intersection to ensure optimal courier matching.",
                      style: TextStyle(color: dropCitySafeSlate, height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "-17.825284, 31.044512 (WGS84)",
                      style: TextStyle(
                        color: dropCitySafeSlate,
                        fontFamily: "monospace",
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DropCityPrimaryButton(
          label: "Confirm Locations",
          icon: Icons.arrow_forward,
          onPressed: c.canAdvanceStep4() ? () => _onNext(context, c) : null,
        ),
      ],
    );
  }

  Widget _buildStep5(DeliveryCreationController c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StepDots(activeIndex: 4, count: 6),
        const SizedBox(height: 24),
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
            if (c.recipientMode == RecipientMode.external) {
              _recipientSearchController.clear();
            } else {
              _recipientSearchController.text = c.recipientName;
            }
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
              c.recipientId = null;
              c.recipientName = value.trim();
              c.notifyListeners();
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
                if (value == null) return;
                c.recipientId = value;
                c.recipientName = u["display_name"]?.toString().isNotEmpty == true
                    ? u["display_name"].toString()
                    : (u["email"]?.toString() ?? "Selected recipient");
                _recipientSearchController.text = c.recipientName;
                setState(() => _recipientSuggestions = const []);
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

  Widget _buildStep6(DeliveryCreationController c) {
    if (c.recommendedPrice != null && _customPriceController.text.isEmpty) {
      _customPriceController.text = c.recommendedPrice!.toStringAsFixed(2);
    }
    final recommended = c.recommendedPrice ?? 1.50;
    final offer = double.tryParse(_customPriceController.text.trim()) ?? recommended;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const StepDots(activeIndex: 5, count: 6),
        const SizedBox(height: 24),
        const Text(
          "Review your delivery",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: dropCitySafeSlate),
        ),
        const SizedBox(height: 6),
        const Text(
          "Please confirm the details before posting.",
          style: TextStyle(color: dropCitySlateGrey, fontSize: 16),
        ),
        const SizedBox(height: 16),
        _SummaryReviewCard(
          pickup: c.originAddress.isEmpty ? "Pickup address" : c.originAddress,
          dropoff: c.destinationAddress.isEmpty ? "Dropoff address" : c.destinationAddress,
          recipient: c.recipientMode == RecipientMode.inApp
              ? (c.recipientName.isNotEmpty ? c.recipientName : "DropCity recipient")
              : c.recipientName,
          parcelSize: c.parcelSize,
        ),
        const SizedBox(height: 16),
        const Text(
          "PRICE BREAKDOWN",
          style: TextStyle(color: dropCitySlateGrey, fontWeight: FontWeight.w800, letterSpacing: .8),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Recommended Price",
                      style: TextStyle(fontSize: 18, color: dropCitySafeSlate),
                    ),
                  ),
                  Text(
                    "\$${recommended.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, color: dropCityTransitTeal, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Your offer", style: TextStyle(fontSize: 18, color: dropCitySafeSlate)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _PriceNudgeButton(icon: Icons.remove, onTap: () {
                    final next = (offer - 0.10).clamp(0.0, 9999.0);
                    _customPriceController.text = next.toStringAsFixed(2);
                    setState(() {});
                  }),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _customPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onChanged: (_) {
                        c.customPrice = _customPriceController.text.trim();
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PriceNudgeButton(icon: Icons.add, onTap: () {
                    final next = (offer + 0.10).clamp(0.0, 9999.0);
                    _customPriceController.text = next.toStringAsFixed(2);
                    setState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Couriers may counter-offer. Final price agreed at pickup.",
                  style: TextStyle(color: dropCitySlateGrey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "RECIPIENT",
          style: TextStyle(color: dropCitySlateGrey, fontWeight: FontWeight.w800, letterSpacing: .8),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _RecipientModeTile(
                label: "Recipient is on DropCity",
                selected: c.recipientMode == RecipientMode.inApp,
                onTap: () {
                  c.recipientMode = RecipientMode.inApp;
                  c.notifyListeners();
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RecipientModeTile(
                label: "Send to phone number only",
                selected: c.recipientMode == RecipientMode.external,
                onTap: () {
                  c.recipientMode = RecipientMode.external;
                  c.notifyListeners();
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (c.recipientMode == RecipientMode.inApp) ...[
          TextField(
            controller: _recipientSearchController,
            decoration: InputDecoration(
              labelText: "Recipient",
              hintText: "Select recipient",
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ] else ...[
          TextField(
            controller: _externalRecipientPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: "Phone Number",
              hintText: "+263 7X XXX XXXX",
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.call),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
        const SizedBox(height: 18),
        if (c.busy)
          Container(
            height: 58,
            decoration: BoxDecoration(
              color: dropCityTransitTeal,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text("Finding couriers...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          )
        else
          DropCityPrimaryButton(
            label: "Post Delivery Request",
            onPressed: c.busy
                ? null
                : () async {
                    try {
                      c.customPrice = _customPriceController.text.trim();
                      if (c.parcelId == null) {
                        await c.createOrderAndMatch();
                      }
                      if (c.selectedCorridorId == null && c.matchedCorridors.isNotEmpty) {
                        c.selectedCorridorId = (c.matchedCorridors.first["corridorId"] ?? c.matchedCorridors.first["corridor_id"])?.toString();
                      }
                      await c.requestSelectedCourier();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Delivery request posted.")),
                      );
                      Navigator.of(context).pop(true);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to post delivery request: $e")),
                      );
                    }
                  },
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

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? dropCityTransitTeal : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? dropCityTransitTeal : dropCitySlateGrey.withOpacity(0.35), width: selected ? 0 : 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? Colors.white : dropCitySafeSlate, size: 34),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: selected ? Colors.white : dropCitySafeSlate, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text("— $sublabel", style: TextStyle(color: selected ? Colors.white : dropCitySafeSlate, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _GridMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 2;
    final thin = Paint()
      ..color = dropCitySlateGrey.withOpacity(0.12)
      ..strokeWidth = 1;
    for (var x = 0.1; x < 1; x += 0.18) {
      canvas.drawLine(Offset(size.width * x, 0), Offset(size.width * x, size.height), thin);
    }
    for (var y = 0.12; y < 1; y += 0.18) {
      canvas.drawLine(Offset(0, size.height * y), Offset(size.width, size.height * y), thin);
    }
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.48), 16, Paint()..color = dropCityAlertAmber);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.48), 7, Paint()..color = Colors.white);
    canvas.drawLine(Offset(size.width * 0.55, size.height * 0.12), Offset(size.width * 0.55, size.height * 0.88), road);
    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.62), Offset(size.width * 0.85, size.height * 0.62), road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SummaryReviewCard extends StatelessWidget {
  const _SummaryReviewCard({
    required this.pickup,
    required this.dropoff,
    required this.recipient,
    required this.parcelSize,
  });

  final String pickup;
  final String dropoff;
  final String recipient;
  final String parcelSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dropCitySlateGrey.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const Icon(Icons.arrow_upward, color: dropCityTransitTeal),
              Container(width: 2, height: 26, color: dropCitySlateGrey.withOpacity(0.5)),
              const Icon(Icons.location_on, color: dropCityTransitTeal),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Pickup", style: TextStyle(color: dropCitySlateGrey)),
                Text(pickup, style: const TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text("Dropoff", style: TextStyle(color: dropCitySlateGrey)),
                Text(dropoff, style: const TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text("Recipient", style: TextStyle(color: dropCitySlateGrey)),
                Text(recipient, style: const TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dropCityActiveMint.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(parcelSize, style: const TextStyle(color: dropCitySafeSlate, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _PriceNudgeButton extends StatelessWidget {
  const _PriceNudgeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dropCitySlateGrey.withOpacity(0.24)),
        ),
        child: Icon(icon, color: dropCitySafeSlate, size: 28),
      ),
    );
  }
}

class _RecipientModeTile extends StatelessWidget {
  const _RecipientModeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? dropCityCloudWhite : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? dropCityTransitTeal : dropCitySlateGrey.withOpacity(0.24), width: selected ? 1.4 : 1),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? dropCitySafeSlate : dropCitySlateGrey,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
