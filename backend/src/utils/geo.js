function parseWktPoint(value) {
  if (!value) {
    return null;
  }
  const text = value.toString();
  const match = text.match(/POINT\(([-\d\.]+) ([-\d\.]+)\)/);
  if (!match) {
    return null;
  }
  const lng = Number.parseFloat(match[1]);
  const lat = Number.parseFloat(match[2]);
  if (Number.isNaN(lat) || Number.isNaN(lng)) {
    return null;
  }
  return { lat, lng };
}

function haversineMeters(a, b) {
  if (!a || !b) {
    return Number.POSITIVE_INFINITY;
  }
  const toRad = (deg) => (deg * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const sinDLat = Math.sin(dLat / 2);
  const sinDLng = Math.sin(dLng / 2);
  const h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
  return 6371000 * c;
}

module.exports = {
  parseWktPoint,
  haversineMeters
};
