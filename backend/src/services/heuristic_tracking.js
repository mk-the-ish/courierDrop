const { getSupabase } = require("../supabase");

const EARTH_RADIUS_M = 6371000;
const TELEPORT_SPEED_KMH = 140;
const STATIONARY_RADIUS_M = 35;
const STATIONARY_WINDOW_MIN = 8;
const DEVIATION_THRESHOLD_M = 500;
const PICKUP_DROP_VICINITY_M = 50;

function toRad(deg) {
  return (deg * Math.PI) / 180;
}

function haversineMeters(a, b) {
  if (!a || !b) return null;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return 2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(h));
}

function parsePointWkt(wkt) {
  if (!wkt || typeof wkt !== "string") return null;
  const m = wkt.match(/POINT\(([-\d.]+)\s+([-\d.]+)\)/i);
  if (!m) return null;
  return { lng: Number(m[1]), lat: Number(m[2]) };
}

function pointFromLog(log) {
  return parsePointWkt(log.raw_location);
}

function durationMinutes(fromIso, toIso) {
  const a = new Date(fromIso).getTime();
  const b = new Date(toIso).getTime();
  if (!Number.isFinite(a) || !Number.isFinite(b)) return 0;
  return Math.max(0, (b - a) / 60000);
}

async function analyzeParcelHeuristics(parcelId) {
  const supabase = getSupabase();
  const { data: parcel, error: parcelErr } = await supabase
    .from("parcels")
    .select("id,assigned_courier_id,pickup_point,dropoff_point,destination_point,status")
    .eq("id", parcelId)
    .maybeSingle();
  if (parcelErr) throw new Error(parcelErr.message);
  if (!parcel) return null;

  const { data: logs, error: logsErr } = await supabase
    .from("courier_tracking_logs")
    .select("id,created_at,raw_location,is_on_corridor,current_distance_m")
    .eq("parcel_id", parcelId)
    .order("created_at", { ascending: false })
    .limit(120);
  if (logsErr) throw new Error(logsErr.message);
  if (!logs || logs.length < 2) return null;

  const chron = [...logs].reverse();
  let maxSpeedKmh = 0;
  let teleportDetected = false;
  let stationaryMinutes = 0;
  let offCorridorCount = 0;

  for (let i = 1; i < chron.length; i++) {
    const prev = chron[i - 1];
    const curr = chron[i];
    const p1 = pointFromLog(prev);
    const p2 = pointFromLog(curr);
    if (!p1 || !p2) continue;
    const dM = haversineMeters(p1, p2) || 0;
    const dtH = Math.max(1 / 3600, (new Date(curr.created_at) - new Date(prev.created_at)) / 3600000);
    const speed = dM / 1000 / dtH;
    maxSpeedKmh = Math.max(maxSpeedKmh, speed);
    if (speed >= TELEPORT_SPEED_KMH) teleportDetected = true;
    if (dM <= STATIONARY_RADIUS_M) {
      stationaryMinutes += durationMinutes(prev.created_at, curr.created_at);
    }
    if (curr.is_on_corridor === false) offCorridorCount += 1;
  }

  const offCorridorRatio = offCorridorCount / chron.length;
  const adherenceScore = Math.max(0, Math.round((1 - offCorridorRatio) * 100));

  const pickupPoint = parsePointWkt(parcel.pickup_point);
  const dropoffPoint = parsePointWkt(parcel.dropoff_point || parcel.destination_point);
  let pickupVisited = false;
  let dropoffVisited = false;
  let pickupVisitedAt = null;
  let dropoffVisitedAt = null;

  for (const log of chron) {
    const p = pointFromLog(log);
    if (!p) continue;
    if (!pickupVisited && pickupPoint) {
      const d = haversineMeters(p, pickupPoint);
      if (d !== null && d <= PICKUP_DROP_VICINITY_M) {
        pickupVisited = true;
        pickupVisitedAt = log.created_at;
      }
    }
    if (!dropoffVisited && dropoffPoint) {
      const d = haversineMeters(p, dropoffPoint);
      if (d !== null && d <= PICKUP_DROP_VICINITY_M) {
        dropoffVisited = true;
        dropoffVisitedAt = log.created_at;
      }
    }
  }

  const stationaryDetected = stationaryMinutes >= STATIONARY_WINDOW_MIN;
  const severeDeviation = offCorridorRatio >= 0.6;
  const alerts = [];
  if (teleportDetected) alerts.push("TELEPORT_SPEED_ANOMALY");
  if (stationaryDetected) alerts.push("STATIONARY_PROLONGED");
  if (severeDeviation) alerts.push("OFF_CORRIDOR_PROLONGED");

  if (alerts.length > 0) {
    for (const deviationType of alerts) {
      await supabase.from("route_deviation_events").insert({
        parcel_id: parcel.id,
        courier_id: parcel.assigned_courier_id,
        deviation_type: deviationType,
        duration_seconds: Math.floor(stationaryMinutes * 60),
        created_at: new Date().toISOString()
      });
    }
  }

  const result = {
    parcelId: parcel.id,
    courierId: parcel.assigned_courier_id,
    adherenceScore,
    offCorridorRatio,
    maxSpeedKmh: Number(maxSpeedKmh.toFixed(2)),
    teleportDetected,
    stationaryDetected,
    stationaryMinutes: Number(stationaryMinutes.toFixed(2)),
    pickupVisited,
    pickupVisitedAt,
    dropoffVisited,
    dropoffVisitedAt,
    severeDeviation,
    deviationThresholdMeters: DEVIATION_THRESHOLD_M
  };

  await supabase.from("route_adherence_reports").insert({
    courier_id: parcel.assigned_courier_id,
    parcel_id: parcel.id,
    adherence_score: adherenceScore,
    off_corridor_ratio: offCorridorRatio,
    stationary_minutes: stationaryMinutes,
    max_speed_kmh: maxSpeedKmh,
    anomalies: alerts,
    pickup_visited: pickupVisited,
    dropoff_visited: dropoffVisited,
    generated_at: new Date().toISOString()
  });

  await supabase.from("courier_score_snapshots").insert({
    courier_id: parcel.assigned_courier_id,
    score: adherenceScore,
    components: {
      source: "heuristic_tracking",
      parcel_id: parcel.id,
      off_corridor_ratio: offCorridorRatio,
      max_speed_kmh: maxSpeedKmh,
      stationary_minutes: stationaryMinutes,
      pickup_visited: pickupVisited,
      dropoff_visited: dropoffVisited
    },
    created_at: new Date().toISOString()
  });

  return result;
}

async function runHeuristicTrackingSweep() {
  const supabase = getSupabase();
  const { data: parcels, error } = await supabase
    .from("parcels")
    .select("id")
    .in("status", ["IN_TRANSIT", "ASSIGNED"]);
  if (error) throw new Error(error.message);
  let processed = 0;
  for (const row of parcels || []) {
    await analyzeParcelHeuristics(row.id);
    processed += 1;
  }
  return { processed };
}

module.exports = {
  analyzeParcelHeuristics,
  runHeuristicTrackingSweep
};
