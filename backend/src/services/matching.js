/**
 * Matching Service
 * Objective 8 completion:
 * - origin + destination near route
 * - route ACTIVE or ABOUT_TO_START
 * - courier capacity check
 * - route progress gate (not past feasible pickup)
 */

const { getSupabase } = require("../supabase");
const { parseWktPoint } = require("../utils/geo");

const ABOUT_TO_START_WINDOW_MIN = 45;
const PROGRESS_PICKUP_BUFFER = 0.03;
const DEFAULT_CAPACITY_KG = 50;

function toPoint({ lat, lng }) {
  if (typeof lat !== "number" || typeof lng !== "number") return null;
  return `SRID=4326;POINT(${lng} ${lat})`;
}

function parseParcelWeightKg(parcel) {
  const v = Number(parcel?.weight_kg);
  if (!Number.isFinite(v) || v <= 0) return 1;
  return v;
}

function isAboutToStart(route, now = new Date()) {
  if (!route || route.status !== "PLANNED") return false;
  const plannedAt = route.planned_start_at ? new Date(route.planned_start_at) : null;
  if (!plannedAt || Number.isNaN(plannedAt.getTime())) return false;
  const diffMin = (plannedAt.getTime() - now.getTime()) / 60000;
  return diffMin >= -5 && diffMin <= ABOUT_TO_START_WINDOW_MIN;
}

function routeLifecycleState(route, now = new Date()) {
  if (!route) return "UNAVAILABLE";
  if (route.status === "ACTIVE") return "ACTIVE";
  if (isAboutToStart(route, now)) return "ABOUT_TO_START";
  return route.status || "UNKNOWN";
}

async function fetchLatestProgressIndexByCorridor(supabase, courierId, corridorIds) {
  const result = {};
  if (!courierId || !corridorIds || corridorIds.length === 0) return result;
  for (const corridorId of corridorIds) {
    const { data } = await supabase
      .from("courier_tracking_logs")
      .select("progress_index,created_at")
      .eq("courier_id", courierId)
      .eq("corridor_id", corridorId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    result[corridorId] =
      typeof data?.progress_index === "number" ? data.progress_index : null;
  }
  return result;
}

function capacityState(vehicle, parcelWeightKg) {
  if (!vehicle) {
    return {
      ok: true,
      availableKg: DEFAULT_CAPACITY_KG,
      reason: "vehicle_not_set_default_capacity"
    };
  }
  const max = Number(vehicle.max_capacity_kg);
  const current = Number(vehicle.current_utilization_kg) || 0;
  const effectiveMax = Number.isFinite(max) && max > 0 ? max : DEFAULT_CAPACITY_KG;
  const available = Math.max(0, effectiveMax - current);
  return {
    ok: available >= parcelWeightKg,
    availableKg: available,
    reason: available >= parcelWeightKg ? "capacity_ok" : "capacity_exceeded"
  };
}

async function getEligibleCourierMatches({
  origin,
  destination,
  maxDetourMeters = 500,
  parcelWeightKg = 1
}) {
  const originPoint = toPoint(origin || {});
  const destinationPoint = toPoint(destination || {});
  if (!originPoint || !destinationPoint) {
    throw new Error("origin and destination must include numeric lat/lng");
  }

  const supabase = getSupabase();
  const { data: rawMatches, error: matchError } = await supabase.rpc(
    "match_delivery_to_couriers",
    {
      p_origin: originPoint,
      p_destination: destinationPoint,
      p_max_detour_m: maxDetourMeters
    }
  );
  if (matchError) {
    throw new Error(matchError.message);
  }
  if (!rawMatches || rawMatches.length === 0) return [];

  const corridorIds = rawMatches.map((m) => m.corridor_id).filter(Boolean);
  const { data: corridors, error: corridorError } = await supabase
    .from("corridors")
    .select("id,created_by")
    .in("id", corridorIds);
  if (corridorError) {
    throw new Error(corridorError.message);
  }
  const corridorById = new Map((corridors || []).map((c) => [c.id, c]));
  const courierIds = Array.from(
    new Set((corridors || []).map((c) => c.created_by).filter(Boolean))
  );
  if (courierIds.length === 0) return [];

  const { data: routes, error: routeError } = await supabase
    .from("routes")
    .select("id,courier_id,corridor_id,status,planned_start_at,activated_at,completed_at")
    .in("courier_id", courierIds)
    .in("status", ["ACTIVE", "PLANNED"])
    .order("created_at", { ascending: false });
  if (routeError) {
    throw new Error(routeError.message);
  }

  const routeByCorridor = new Map();
  for (const route of routes || []) {
    if (!route?.corridor_id) continue;
    if (!routeByCorridor.has(route.corridor_id)) {
      routeByCorridor.set(route.corridor_id, route);
    }
  }

  const { data: vehicles } = await supabase
    .from("vehicles")
    .select("courier_id,max_capacity_kg,current_utilization_kg,is_active,verification_status")
    .in("courier_id", courierIds);
  const vehicleByCourier = new Map((vehicles || []).map((v) => [v.courier_id, v]));

  const now = new Date();
  const out = [];

  // Preload latest progress for all relevant corridors by courier
  const progressByCourierCorridor = {};
  for (const courierId of courierIds) {
    progressByCourierCorridor[courierId] = await fetchLatestProgressIndexByCorridor(
      supabase,
      courierId,
      corridorIds
    );
  }

  for (const raw of rawMatches) {
    const corridor = corridorById.get(raw.corridor_id);
    if (!corridor?.created_by) continue;
    const courierId = corridor.created_by;
    const route = routeByCorridor.get(raw.corridor_id);
    const lifecycle = routeLifecycleState(route, now);
    if (!(lifecycle === "ACTIVE" || lifecycle === "ABOUT_TO_START")) {
      continue;
    }

    const vehicle = vehicleByCourier.get(courierId);
    if (vehicle && vehicle.is_active === false) continue;
    const cap = capacityState(vehicle, parcelWeightKg);
    if (!cap.ok) continue;

    const pickupFraction = Number(raw.pickup_fraction);
    const latestProgress =
      progressByCourierCorridor[courierId]?.[raw.corridor_id] ?? null;

    // If route is ACTIVE and courier already passed feasible pickup, reject.
    if (
      lifecycle === "ACTIVE" &&
      Number.isFinite(latestProgress) &&
      Number.isFinite(pickupFraction) &&
      latestProgress > pickupFraction + PROGRESS_PICKUP_BUFFER
    ) {
      continue;
    }

    const statusBoost = lifecycle === "ACTIVE" ? 20 : 10;
    const progressPenalty =
      lifecycle === "ACTIVE" && Number.isFinite(latestProgress) && Number.isFinite(pickupFraction)
        ? Math.max(0, (latestProgress - pickupFraction) * 100)
        : 0;
    const score = Math.max(
      0,
      Math.round(
        100 +
          statusBoost +
          Math.min(20, cap.availableKg) -
          progressPenalty
      )
    );

    out.push({
      corridor_id: raw.corridor_id,
      courier_id: courierId,
      pickup_point: parseWktPoint(raw.pickup_point),
      dropoff_point: parseWktPoint(raw.dropoff_point),
      pickup_fraction: raw.pickup_fraction,
      dropoff_fraction: raw.dropoff_fraction,
      route_state: lifecycle,
      latest_progress_index: latestProgress,
      available_capacity_kg: cap.availableKg,
      score
    });
  }

  out.sort((a, b) => b.score - a.score);
  return out;
}

/**
 * Match pending parcels with route/capacity/progress-aware courier constraints.
 */
async function matchPendingParcels() {
  const supabase = getSupabase();

  try {
    const { data: parcels, error: parcelError } = await supabase
      .from("parcels")
      .select("id,origin_point,destination_point,origin,destination,weight_kg")
      .eq("status", "REQUESTED")
      .is("assigned_courier_id", null);

    if (parcelError) {
      console.error("[Matching] Error fetching parcels:", parcelError);
      return;
    }
    if (!parcels || parcels.length === 0) {
      console.log("[Matching] No pending parcels to match");
      return;
    }

    let matchedCount = 0;
    let queuedCount = 0;

    for (const parcel of parcels) {
      try {
        const { data: existing } = await supabase
          .from("parcel_assignment_queue")
          .select("id")
          .eq("parcel_id", parcel.id)
          .limit(1);
        if (existing && existing.length > 0) continue;

        const origin = parseWktPoint(parcel.origin_point);
        const destination = parseWktPoint(parcel.destination_point);
        if (!origin || !destination) continue;

        const eligible = await getEligibleCourierMatches({
          origin,
          destination,
          maxDetourMeters: 500,
          parcelWeightKg: parseParcelWeightKg(parcel)
        });

        if (eligible.length === 0) {
          console.log(`[Matching] No eligible couriers for parcel ${parcel.id}`);
          continue;
        }

        matchedCount += 1;
        const queueEntries = eligible.map((match, index) => ({
          parcel_id: parcel.id,
          corridor_id: match.corridor_id,
          rank: index + 1,
          status: "PENDING"
        }));

        const { error: insertError } = await supabase
          .from("parcel_assignment_queue")
          .insert(queueEntries);
        if (insertError) {
          console.error(`[Matching] Queue insert failed for ${parcel.id}:`, insertError);
          continue;
        }
        queuedCount += queueEntries.length;
      } catch (err) {
        console.error(`[Matching] Parcel ${parcel.id} failed:`, err.message);
      }
    }

    console.log(`[Matching] ✓ Matched ${matchedCount} parcels with ${queuedCount} queue entries`);
  } catch (error) {
    console.error("[Matching] Fatal error in matching service:", error);
  }
}

module.exports = {
  getEligibleCourierMatches,
  matchPendingParcels
};

