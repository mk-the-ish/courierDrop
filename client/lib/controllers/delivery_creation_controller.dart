import "dart:convert";
import "dart:io";

import "package:flutter/foundation.dart";
import "package:latlong2/latlong.dart";

import "../auth/auth_state.dart";

enum RecipientMode { inApp, external }

class DeliveryCreationController extends ChangeNotifier {
  DeliveryCreationController({required this.authState});

  final AuthState authState;

  int _step = 1;
  bool _busy = false;
  String? _error;

  String description = "";
  String parcelSize = "M";
  double weightKg = 1;
  DateTime? desiredArrivalTime;
  String priority = "standard";
  bool fragile = false;
  String? parcelImageDataUrl;

  String originAddress = "";
  String destinationAddress = "";
  LatLng? originLatLng;
  LatLng? destinationLatLng;

  RecipientMode recipientMode = RecipientMode.inApp;
  String? recipientId;
  String recipientName = "";
  String recipientPhone = "";

  String? parcelId;
  double? recommendedPrice;
  List<Map<String, dynamic>> matchedCorridors = const [];
  String? selectedCorridorId;
  String customPrice = "";
  double? userPrice;

  int get step => _step;
  bool get busy => _busy;
  String? get error => _error;

  bool canAdvanceStep1() {
    return description.trim().isNotEmpty && weightKg > 0;
  }

  bool canAdvanceStep2() => desiredArrivalTime != null;

  bool canAdvanceStep3() => parcelImageDataUrl != null;

  bool canAdvanceStep4() {
    return originAddress.trim().isNotEmpty &&
        destinationAddress.trim().isNotEmpty &&
        originLatLng != null &&
        destinationLatLng != null;
  }

  bool canAdvanceStep5() {
    if (recipientMode == RecipientMode.inApp) {
      return recipientId != null && recipientId!.isNotEmpty;
    }
    return recipientName.trim().isNotEmpty && recipientPhone.trim().isNotEmpty;
  }

  void nextStep() {
    if (_step < 6) {
      _step += 1;
      notifyListeners();
    }
  }

  void prevStep() {
    if (_step > 1) {
      _step -= 1;
      notifyListeners();
    }
  }

  Future<void> setParcelImageFromPath(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    parcelImageDataUrl = "data:image/jpeg;base64,${base64Encode(bytes)}";
    notifyListeners();
  }

  Future<void> createOrderAndMatch() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      final int? etaMins = desiredArrivalTime == null
          ? null
          : (desiredArrivalTime!.difference(now).inMinutes.clamp(1, 24 * 60) as int);

      final recipientNote = recipientMode == RecipientMode.external
          ? "recipient_name:$recipientName;recipient_phone:$recipientPhone"
          : "";
      
      // Build notes WITHOUT the image data to avoid "request entity too large" error
      // Image should be uploaded separately if needed
      final notes = [
        description.trim(),
        recipientNote
      ].where((x) => x.isNotEmpty).join(" | ");

      userPrice = customPrice.trim().isNotEmpty
          ? double.tryParse(customPrice.trim())
          : null;
      parcelId = await authState.apiClient.postParcelRequest(
        origin: "${originLatLng!.latitude.toStringAsFixed(6)}, ${originLatLng!.longitude.toStringAsFixed(6)}",
        destination:
            "${destinationLatLng!.latitude.toStringAsFixed(6)}, ${destinationLatLng!.longitude.toStringAsFixed(6)}",
        size: parcelSize,
        priority: priority,
        fragile: fragile,
        notes: notes,
        recipientId: recipientMode == RecipientMode.inApp ? recipientId : null,
        dualTracking: recipientMode == RecipientMode.inApp,
        weightKg: weightKg,
        clientEtaMinutes: etaMins,
        userPrice: userPrice,
      );

      // TODO: Upload parcel image separately after parcel is created
      // if (parcelImageDataUrl != null && parcelId != null) {
      //   await authState.apiClient.uploadParcelImage(parcelId!, parcelImageDataUrl!);
      // }

      final matches = await authState.apiClient.matchCorridors(
        originLat: originLatLng!.latitude,
        originLng: originLatLng!.longitude,
        destinationLat: destinationLatLng!.latitude,
        destinationLng: destinationLatLng!.longitude,
      );
      matchedCorridors = matches;
      if (matches.isNotEmpty) {
        selectedCorridorId =
            (matches.first["corridorId"] ?? matches.first["corridor_id"])
                ?.toString();
        final rec = matches.first["recommendedPrice"];
        if (rec is num) {
          recommendedPrice = rec.toDouble();
        }
      }
      if (recommendedPrice != null && customPrice.trim().isEmpty) {
        customPrice = recommendedPrice!.toStringAsFixed(2);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> requestSelectedCourier() async {
    if (parcelId == null) {
      throw Exception("Parcel has not been created yet.");
    }
    if (selectedCorridorId == null && matchedCorridors.isNotEmpty) {
      selectedCorridorId =
          (matchedCorridors.first["corridorId"] ?? matchedCorridors.first["corridor_id"])
              ?.toString();
    }
    if (selectedCorridorId == null) {
      throw Exception("No courier matches are available to request.");
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await authState.apiClient.requestCourier(
        parcelId: parcelId!,
        corridorId: selectedCorridorId!,
      );
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
