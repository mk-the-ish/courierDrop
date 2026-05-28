import 'package:latlong2/latlong.dart';

const LatLng kDefaultMapCenter = LatLng(-17.8252, 31.0335);

bool isFiniteLatLng(LatLng? value) {
  return value != null &&
      value.latitude.isFinite &&
      value.longitude.isFinite;
}

LatLng normalizeLatLng(LatLng? value, {LatLng fallback = kDefaultMapCenter}) {
  if (isFiniteLatLng(value)) {
    return value!;
  }
  return fallback;
}
