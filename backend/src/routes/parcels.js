const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireRole } = require("../middleware/auth");
const { parseWktPoint, haversineMeters } = require("../utils/geo");

const router = express.Router();
const conflictAttempts = new Map();
const CONFLICT_WINDOW_MS = 10 * 60 * 1000;
const CONFLICT_MAX = 5;

const ETA_CACHE_TTL_MS = 5 * 60 * 1000;
const ETA_HISTORY_DAYS = 30;
const ETA_HISTORY_LIMIT = 400;
const ETA_MIN_MINUTES = 5;

const ETA_DEFAULTS = {
  "same-day": { leadMinutes: 85, transitMinutes: 40, speedKmh: 33 },
  express: { leadMinutes: 120, transitMinutes: 55, speedKmh: 29 },
  standard: { leadMinutes: 180, transitMinutes: 75, speedKmh: 24 },
  overall: { leadMinutes: 150, transitMinutes: 60, speedKmh: 26 }
};

const DAYPART_TRAFFIC_FACTOR = {
  morning: 1.2,
  afternoon: 1.0,
  evening: 1.25,
  night: 0.85
};

let etaModelCache = {
  fetchedAt: 0,
  model: null
};

function checkConflictRateLimit(key) {
  const now = Date.now();
  const bucket = conflictAttempts.get(key) || [];
  const recent = bucket.filter((timestamp) => now - timestamp < CONFLICT_WINDOW_MS);
  if (recent.length >= CONFLICT_MAX) {
    return false;
  }
  recent.push(now);
  conflictAttempts.set(key, recent);
  return true;
}

function hasRole(user, role) {
  const userRole = user?.role || user?.roles || user?.claims?.role || user?.claims?.roles;
  if (!userRole) return false;
  const roles = Array.isArray(userRole) ? userRole : [userRole];
  return roles.includes(role);
}

async function ensureParcelAccess(supabase, parcelId, user) {
  const { data, error } = await supabase
    .from("parcels")
    .select("created_by,assigned_courier_id")
    .eq("id", parcelId)
    .maybeSingle();
  if (error) {
    throw new ApiError(error.message, 500, "PARCEL_LOOKUP_FAILED");
  }
  if (!data) {
    throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
  }
  const uid = user?.uid;
  if (hasRole(user, "admin")) {
    return data;
  }
  if (data.created_by === uid || data.assigned_courier_id === uid) {
    return data;
  }
  throw new ApiError("Not permitted to access parcel", 403, "PARCEL_FORBIDDEN");
}

function parseDate(value) {
  if (!value) {
    return null;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date;
}

function elapsedMinutesSince(value, now) {
  const started = parseDate(value);
  if (!started) {
    return 0;
  }
  const diffMs = now.getTime() - started.getTime();
  if (!Number.isFinite(diffMs) || diffMs <= 0) {
    return 0;
  }
  return Math.floor(diffMs / 60000);
}

function getPriorityKey(priorityValue) {
  const normalized = (priorityValue || "").toString().trim().toLowerCase();
  if (normalized === "same-day" || normalized === "sameday") {
    return "same-day";
  }
  if (normalized === "express") {
    return "express";
  }
  return "standard";
}

function getDayPart(dateValue) {
  const date = parseDate(dateValue);
  if (!date) {
    return "afternoon";
  }
  const hour = date.getUTCHours();
  if (hour >= 5 && hour < 11) return "morning";
  if (hour >= 11 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 22) return "evening";
  return "night";
}

function minutesBetween(startValue, endValue) {
  const start = parseDate(startValue);
  const end = parseDate(endValue);
  if (!start || !end) {
    return null;
  }
  const diffMs = end.getTime() - start.getTime();
  if (!Number.isFinite(diffMs) || diffMs <= 0) {
    return null;
  }
  return diffMs / 60000;
}

function getDistanceKm(parcel) {
  const origin = parseWktPoint(parcel.origin_point);
  const destination = parseWktPoint(parcel.destination_point);
  const distanceMeters = haversineMeters(origin, destination);
  if (!Number.isFinite(distanceMeters) || distanceMeters <= 0) {
    return null;
  }
  return distanceMeters / 1000;
}

function createMetricBucket() {
  return {
    count: 0,
    leadMinutes: 0,
    transitMinutes: 0,
    speedKmh: 0
  };
}

function addMetricSample(bucket, sample) {
  bucket.count += 1;
  bucket.leadMinutes += sample.leadMinutes;
  bucket.transitMinutes += sample.transitMinutes;
  bucket.speedKmh += sample.speedKmh;
}

function averageMetricBucket(bucket) {
  if (!bucket || bucket.count <= 0) {
    return null;
  }
  return {
    count: bucket.count,
    leadMinutes: bucket.leadMinutes / bucket.count,
    transitMinutes: bucket.transitMinutes / bucket.count,
    speedKmh: bucket.speedKmh / bucket.count
  };
}

function blendWithFallback(observed, fallbackValue) {
  if (!Number.isFinite(observed) || observed <= 0) {
    return fallbackValue;
  }
  const effectiveSamples = Math.min(1, (observed.count || 0) / 20);
  return fallbackValue * (1 - effectiveSamples) + observed.value * effectiveSamples;
}

function buildEtaModel(historyRows) {
  const overall = createMetricBucket();
  const byPriority = {};
  const byDayPart = {};
  const byPriorityDayPart = {};

  for (const row of historyRows) {
    const leadMinutes = minutesBetween(row.created_at, row.pickup_verified_at);
    const transitMinutes = minutesBetween(
      row.pickup_verified_at,
      row.dropoff_verified_at
    );
    const distanceKm = getDistanceKm(row);

    if (!leadMinutes || !transitMinutes || !distanceKm || distanceKm <= 0.2) {
      continue;
    }

    const speedKmh = distanceKm / (transitMinutes / 60);
    if (!Number.isFinite(speedKmh) || speedKmh <= 4 || speedKmh > 120) {
      continue;
    }

    const priorityKey = getPriorityKey(row.priority);
    const dayPart = getDayPart(row.created_at);
    const compositeKey = `${priorityKey}:${dayPart}`;
    const sample = { leadMinutes, transitMinutes, speedKmh };

    if (!byPriority[priorityKey]) {
      byPriority[priorityKey] = createMetricBucket();
    }
    if (!byDayPart[dayPart]) {
      byDayPart[dayPart] = createMetricBucket();
    }
    if (!byPriorityDayPart[compositeKey]) {
      byPriorityDayPart[compositeKey] = createMetricBucket();
    }

    addMetricSample(overall, sample);
    addMetricSample(byPriority[priorityKey], sample);
    addMetricSample(byDayPart[dayPart], sample);
    addMetricSample(byPriorityDayPart[compositeKey], sample);
  }

  const normalizedPriority = Object.fromEntries(
    Object.entries(byPriority).map(([key, bucket]) => [key, averageMetricBucket(bucket)])
  );
  const normalizedDayPart = Object.fromEntries(
    Object.entries(byDayPart).map(([key, bucket]) => [key, averageMetricBucket(bucket)])
  );
  const normalizedPriorityDayPart = Object.fromEntries(
    Object.entries(byPriorityDayPart).map(([key, bucket]) => [key, averageMetricBucket(bucket)])
  );

  return {
    overall: averageMetricBucket(overall),
    byPriority: normalizedPriority,
    byDayPart: normalizedDayPart,
    byPriorityDayPart: normalizedPriorityDayPart
  };
}

async function getEtaModel(supabase) {
  const now = Date.now();
  if (etaModelCache.model && now - etaModelCache.fetchedAt < ETA_CACHE_TTL_MS) {
    return etaModelCache.model;
  }

  const since = new Date(now - ETA_HISTORY_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data, error } = await supabase
    .from("parcels")
    .select(
      "priority,created_at,pickup_verified_at,dropoff_verified_at,origin_point,destination_point"
    )
    .gte("dropoff_verified_at", since)
    .not("pickup_verified_at", "is", null)
    .not("dropoff_verified_at", "is", null)
    .order("dropoff_verified_at", { ascending: false })
    .limit(ETA_HISTORY_LIMIT);

  if (error) {
    throw new ApiError(error.message, 500, "ETA_HISTORY_FETCH_FAILED");
  }

  const model = buildEtaModel(data || []);
  etaModelCache = {
    fetchedAt: now,
    model
  };
  return model;
}

function selectMetricSegment(model, priorityKey, dayPart) {
  const compositeKey = `${priorityKey}:${dayPart}`;
  return (
    model.byPriorityDayPart[compositeKey] ||
    model.byPriority[priorityKey] ||
    model.byDayPart[dayPart] ||
    model.overall ||
    null
  );
}

function resolveEtaMetrics(model, priorityKey, dayPart) {
  const fallback = ETA_DEFAULTS[priorityKey] || ETA_DEFAULTS.overall;
  const selected = selectMetricSegment(model, priorityKey, dayPart);

  const leadMinutes = blendWithFallback(
    selected ? { value: selected.leadMinutes, count: selected.count } : null,
    fallback.leadMinutes
  );
  const transitMinutes = blendWithFallback(
    selected ? { value: selected.transitMinutes, count: selected.count } : null,
    fallback.transitMinutes
  );
  const speedKmh = blendWithFallback(
    selected ? { value: selected.speedKmh, count: selected.count } : null,
    fallback.speedKmh
  );

  return {
    leadMinutes,
    transitMinutes,
    speedKmh,
    sampleCount: selected?.count || 0
  };
}

function etaConfidenceLabel({ sampleCount, hasDistance, status }) {
  const normalizedStatus = (status || "").toString().toUpperCase();
  if (normalizedStatus === "COMPLETED") {
    return "HIGH";
  }
  if (hasDistance && sampleCount >= 20) {
    return "HIGH";
  }
  if (hasDistance && sampleCount >= 8) {
    return "MEDIUM";
  }
  return "LOW";
}

function estimateEta(parcel, model, now = new Date()) {
  const status = (parcel.status || "").toString().toUpperCase();
  const priorityKey = getPriorityKey(parcel.priority);
  const dayPart = getDayPart(parcel.created_at || now.toISOString());
  const trafficFactor = DAYPART_TRAFFIC_FACTOR[dayPart] || 1.0;
  const completedAt = parseDate(parcel.dropoff_verified_at);
  const metrics = resolveEtaMetrics(model, priorityKey, dayPart);
  const parsedDistanceKm = getDistanceKm(parcel);
  const distanceKm = parsedDistanceKm || 3;
  const hasDistance = Number.isFinite(parsedDistanceKm) && parsedDistanceKm > 0;

  if (status === "COMPLETED" || completedAt) {
    return {
      etaMinutes: 0,
      etaAt: (completedAt || now).toISOString(),
      etaConfidence: etaConfidenceLabel({
        sampleCount: metrics.sampleCount,
        hasDistance,
        status
      })
    };
  }

  const rawTransitByDistance = (distanceKm / Math.max(8, metrics.speedKmh)) * 60;
  const transitMinutes = Math.max(
    10,
    rawTransitByDistance * trafficFactor + 8
  );

  const rawLeadMinutes = Math.max(
    15,
    metrics.leadMinutes * trafficFactor
  );

  const elapsedMinutes = status === "IN_TRANSIT"
    ? elapsedMinutesSince(parcel.pickup_verified_at, now)
    : status === "ASSIGNED" || status === "PINS_SET" || status === "ACCEPTED"
      ? elapsedMinutesSince(parcel.assigned_at || parcel.created_at, now)
      : elapsedMinutesSince(parcel.created_at, now);

  const baselineByStatus = {
    IN_TRANSIT: transitMinutes,
    ASSIGNED: rawLeadMinutes * 0.45 + transitMinutes,
    PINS_SET: rawLeadMinutes * 0.45 + transitMinutes,
    ACCEPTED: rawLeadMinutes * 0.45 + transitMinutes,
    REQUESTED: rawLeadMinutes + transitMinutes
  };

  const baseMinutes = baselineByStatus[status] || baselineByStatus.REQUESTED;

  const remainingMinutes = Math.max(
    ETA_MIN_MINUTES,
    Math.round(baseMinutes - elapsedMinutes)
  );
  return {
    etaMinutes: remainingMinutes,
    etaAt: new Date(now.getTime() + remainingMinutes * 60000).toISOString(),
    etaConfidence: etaConfidenceLabel({
      sampleCount: metrics.sampleCount,
      hasDistance,
      status
    })
  };
}

router.post(
  "/",
  asyncHandler(async (req, res) => {
  const { origin, destination, size, priority, fragile, notes, clientId } =
    req.body || {};

    if (!origin || !destination || !priority) {
      throw new ApiError("Missing required fields", 400, "PARCEL_INVALID_INPUT");
    }

  const supabase = getSupabase();
  if (clientId) {
    const { data: existing, error: lookupError } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", clientId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "PARCEL_LOOKUP_FAILED");
    }

    if (existing && existing.created_by && existing.created_by !== req.user?.uid) {
      const rateKey = `parcel:${req.user?.uid || "anon"}`;
      if (!checkConflictRateLimit(rateKey)) {
        throw new ApiError(
          "Too many conflict attempts. Try again later.",
          429,
          "PARCEL_CONFLICT_RATE_LIMIT"
        );
      }
      throw new ApiError(
        "clientId already used by another user",
        409,
        "PARCEL_CONFLICT"
      );
    }
  }

  // Parse coordinates from "latitude, longitude" string format
  const parseCoordinates = (coordString) => {
    if (!coordString) return null;
    const parts = coordString.trim().split(",").map((s) => parseFloat(s.trim()));
    if (parts.length !== 2 || parts.some((p) => isNaN(p))) return null;
    const [lat, lng] = parts;
    // PostGIS expects POINT(longitude latitude)
    return { lat, lng };
  };

  const originCoords = parseCoordinates(origin);
  const destCoords = parseCoordinates(destination);

  if (!originCoords) {
    throw new ApiError("Invalid origin coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_ORIGIN");
  }

  if (!destCoords) {
    throw new ApiError("Invalid destination coordinates format. Expected 'latitude, longitude'", 400, "PARCEL_INVALID_DESTINATION");
  }

  const payload = {
    ...(clientId ? { id: clientId } : {}),
    origin,
    destination,
    origin_point: `POINT(${originCoords.lng} ${originCoords.lat})`,
    destination_point: `POINT(${destCoords.lng} ${destCoords.lat})`,
    pickup_point: `POINT(${originCoords.lng} ${originCoords.lat})`,
    pickup_lat: originCoords.lat,
    pickup_lng: originCoords.lng,
    size: size || null,
    priority,
    fragile: Boolean(fragile),
    notes: notes || null,
    created_by: req.user?.uid || null,
    request_id: req.requestId || null
  };

  const { data, error } = await supabase
    .from("parcels")
    .upsert(payload, { onConflict: "id" })
    .select("id");

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_INSERT_FAILED");
    }

    return res.status(201).json({ id: data?.[0]?.id });
  })
);

router.get(
  "/created/me",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const etaModel = await getEtaModel(supabase);
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,origin,destination,priority,fragile,created_at,assigned_at,pickup_verified_at,dropoff_verified_at,origin_point,destination_point,rating_submitted,rating_value,rating_feedback,rated_at"
      )
      .eq("created_by", req.user?.uid || "")
      .order("created_at", { ascending: false });

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_FETCH_FAILED");
    }

    const now = new Date();
    const parcels = (data || []).map((parcel) => {
      const eta = estimateEta(parcel, etaModel, now);
      return { ...parcel, ...eta };
    });

    const stats = parcels.reduce(
      (acc, parcel) => {
        const status = (parcel.status || "").toString().toUpperCase();
        acc.total += 1;
        if (status === "COMPLETED") {
          acc.completed += 1;
        } else if (status === "IN_TRANSIT") {
          acc.inTransit += 1;
        } else if (status === "ASSIGNED" || status === "PINS_SET" || status === "ACCEPTED") {
          acc.assigned += 1;
        } else {
          acc.pending += 1;
        }
        return acc;
      },
      {
        total: 0,
        pending: 0,
        assigned: 0,
        inTransit: 0,
        completed: 0
      }
    );

    const activeParcels = parcels.filter(
      (parcel) => (parcel.status || "").toString().toUpperCase() !== "COMPLETED"
    );
    activeParcels.sort((a, b) => (a.etaMinutes || 0) - (b.etaMinutes || 0));
    const nextEta = activeParcels.length > 0 ? activeParcels[0] : null;

    return res.json({
      stats: {
        ...stats,
        nextEtaMinutes: nextEta?.etaMinutes ?? null,
        nextEtaAt: nextEta?.etaAt ?? null,
        nextEtaParcelId: nextEta?.id ?? null,
        nextEtaConfidence: nextEta?.etaConfidence ?? null
      },
      parcels
    });
  })
);

router.post(
  "/:id/rate",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { rating, feedback } = req.body || {};
    const normalizedRating = Number(rating);

    if (!Number.isInteger(normalizedRating) || normalizedRating < 1 || normalizedRating > 5) {
      throw new ApiError("rating must be an integer between 1 and 5", 400, "RATING_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const { data: parcel, error: parcelError } = await supabase
      .from("parcels")
      .select("id,created_by,status,rating_submitted")
      .eq("id", parcelId)
      .maybeSingle();

    if (parcelError) {
      throw new ApiError(parcelError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }
    if (parcel.created_by !== req.user?.uid) {
      throw new ApiError("Not permitted to rate this parcel", 403, "PARCEL_FORBIDDEN");
    }
    if (parcel.rating_submitted) {
      return res.json({ status: "already_rated", parcelId });
    }

    const status = (parcel.status || "").toString().toUpperCase();
    if (status !== "DELIVERED" && status !== "COMPLETED") {
      throw new ApiError("Parcel is not delivered yet", 409, "RATING_NOT_ALLOWED");
    }

    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        rating_submitted: true,
        rating_value: normalizedRating,
        rating_feedback: typeof feedback === "string" && feedback.trim().length > 0
          ? feedback.trim()
          : null,
        rated_at: new Date().toISOString()
      })
      .eq("id", parcelId);

    if (updateError) {
      throw new ApiError(updateError.message, 500, "RATING_SAVE_FAILED");
    }

    return res.json({ status: "ok", parcelId, rating: normalizedRating });
  })
);

router.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,pickup_verified_at,dropoff_verified_at,created_at,pickup_photo_url,dropoff_photo_url,assigned_courier_id,assigned_at,created_by,pickup_point,tracking_progress_percent,tracking_integrity_status,tracking_last_update"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!data) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }

    const canSeePickup =
      data.assigned_courier_id === req.user?.uid || data.created_by === req.user?.uid || hasRole(req.user, "admin");
    const parcel = {
      ...data,
      pickup_point: canSeePickup ? data.pickup_point : null
    };
    return res.json({ parcel });
  })
);

router.post(
  "/:id/assign",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { courierId } = req.body || {};
    if (!courierId) {
      throw new ApiError("courierId required", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: courierId,
        assigned_at: new Date().toISOString()
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_ASSIGN_FAILED");
    }
    return res.json({ status: "ok", parcelId, courierId });
  })
);

router.post(
  "/:id/request-courier",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { corridorId, corridorIds } = req.body || {};
    const candidates =
      Array.isArray(corridorIds) && corridorIds.length > 0
        ? corridorIds
        : corridorId
        ? [corridorId]
        : [];
    if (candidates.length === 0) {
      throw new ApiError("corridorId(s) required", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const queuePayload = candidates.map((id, index) => ({
      parcel_id: parcelId,
      corridor_id: id,
      rank: index + 1,
      status: "PENDING"
    }));
    const { error: queueError } = await supabase
      .from("parcel_assignment_queue")
      .insert(queuePayload);
    if (queueError) {
      throw new ApiError(queueError.message, 500, "ASSIGNMENT_QUEUE_FAILED");
    }

    const { data: corridor, error: corridorError } = await supabase
      .from("corridors")
      .select("id,created_by")
      .eq("id", candidates[0])
      .maybeSingle();
    if (corridorError) {
      throw new ApiError(corridorError.message, 500, "CORRIDOR_LOOKUP_FAILED");
    }
    if (!corridor) {
      throw new ApiError("Corridor not found", 404, "CORRIDOR_NOT_FOUND");
    }
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: corridor.created_by,
        assigned_at: new Date().toISOString(),
        status: "ASSIGNED"
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_ASSIGN_FAILED");
    }
    const { data: parcel } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcel?.created_by) {
      sendToUser(parcel.created_by, "Courier assigned", "A courier has been assigned.", {
        parcelId
      });
    }
    if (corridor.created_by) {
      sendToUser(corridor.created_by, "New delivery request", "You have a new parcel request.", {
        parcelId
      });
    }
    sendToParcelTopic(parcelId, "Courier assigned", "A courier has been assigned.", {
      parcelId,
      status: "ASSIGNED"
    });
    await supabase
      .from("parcel_assignment_queue")
      .update({ status: "ASSIGNED" })
      .eq("parcel_id", parcelId)
      .eq("corridor_id", candidates[0]);
    return res.json({
      status: "ok",
      parcelId,
      courierId: corridor.created_by
    });
  })
);

router.post(
  "/:id/accept",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const courierId = req.user?.uid;
    const supabase = getSupabase();

    // Get parcel and check if it's in the queue for one of our corridors
    const { data: parcel, error: lookupError } = await supabase
      .from("parcels")
      .select("status")
      .eq("id", parcelId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }

    // Get the queue entry for this parcel in our corridors
    const { data: corridors } = await supabase
      .from("corridors")
      .select("id")
      .eq("created_by", courierId);

    const corridorIds = (corridors || []).map((c) => c.id);
    if (corridorIds.length === 0) {
      throw new ApiError("No corridors found for this courier", 403, "NO_CORRIDORS");
    }

    // Get the BEST queue entry (lowest rank = best match) for this parcel in our corridors
    const { data: queueEntry, error: queueError } = await supabase
      .from("parcel_assignment_queue")
      .select("corridor_id,status,rank")
      .eq("parcel_id", parcelId)
      .in("corridor_id", corridorIds)
      .order("rank", { ascending: true })
      .limit(1)
      .maybeSingle();

    if (queueError) {
      throw new ApiError(queueError.message, 500, "QUEUE_LOOKUP_FAILED");
    }
    if (!queueEntry) {
      throw new ApiError("Parcel not in queue for this courier", 403, "PARCEL_NOT_IN_QUEUE");
    }

    // Update parcel to ASSIGNED with this courier
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: courierId,
        assigned_at: new Date().toISOString(),
        status: "ASSIGNED"
      })
      .eq("id", parcelId);

    if (updateError) {
      throw new ApiError(updateError.message, 500, "PARCEL_ASSIGN_FAILED");
    }

    // Update queue entry to ASSIGNED
    const { error: queueUpdateError } = await supabase
      .from("parcel_assignment_queue")
      .update({ status: "ASSIGNED" })
      .eq("parcel_id", parcelId)
      .eq("corridor_id", queueEntry.corridor_id);

    if (queueUpdateError) {
      throw new ApiError(queueUpdateError.message, 500, "QUEUE_UPDATE_FAILED");
    }

    // Send notifications
    const { data: parcelInfo } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();

    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcelInfo?.created_by) {
      await sendToUser(parcelInfo.created_by, "Courier accepted", "Your courier accepted the delivery.", {
        parcelId
      });
    }
    await sendToParcelTopic(parcelId, "Courier accepted", "Your courier accepted the delivery.", {
      parcelId,
      status: "ASSIGNED"
    });

    const { broadcastParcelStatus } = require("../ws");
    broadcastParcelStatus(parcelId, { status: "ASSIGNED", parcelId });

    return res.json({ status: "ok", parcelId, courierId });
  })
);

router.post(
  "/:id/decline",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const courierId = req.user?.uid;
    const supabase = getSupabase();

    // Get courier's corridors
    const { data: corridors } = await supabase
      .from("corridors")
      .select("id")
      .eq("created_by", courierId);

    const corridorIds = (corridors || []).map((c) => c.id);

    // Find and mark the queue entry as DECLINED
    const { data: queueEntry, error: queueError } = await supabase
      .from("parcel_assignment_queue")
      .select("corridor_id,rank")
      .eq("parcel_id", parcelId)
      .in("corridor_id", corridorIds)
      .maybeSingle();

    if (queueError) {
      throw new ApiError(queueError.message, 500, "QUEUE_LOOKUP_FAILED");
    }

    if (queueEntry?.corridor_id) {
      await supabase
        .from("parcel_assignment_queue")
        .update({ status: "DECLINED" })
        .eq("parcel_id", parcelId)
        .eq("corridor_id", queueEntry.corridor_id);
    }

    // Look for next PENDING candidate in queue
    const { data: nextCandidate } = await supabase
      .from("parcel_assignment_queue")
      .select("corridor_id")
      .eq("parcel_id", parcelId)
      .eq("status", "PENDING")
      .order("rank", { ascending: true })
      .maybeSingle();

    if (nextCandidate?.corridor_id) {
      // Assign to next courier
      const { data: nextCorridor } = await supabase
        .from("corridors")
        .select("created_by")
        .eq("id", nextCandidate.corridor_id)
        .maybeSingle();

      if (nextCorridor?.created_by) {
        const { error: assignError } = await supabase
          .from("parcels")
          .update({
            assigned_courier_id: nextCorridor.created_by,
            assigned_at: new Date().toISOString(),
            status: "ASSIGNED"
          })
          .eq("id", parcelId);

        if (!assignError) {
          await supabase
            .from("parcel_assignment_queue")
            .update({ status: "ASSIGNED" })
            .eq("parcel_id", parcelId)
            .eq("corridor_id", nextCandidate.corridor_id);

          const { broadcastParcelStatus } = require("../ws");
          broadcastParcelStatus(parcelId, {
            status: "ASSIGNED",
            parcelId,
            reassigned: true
          });

          const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
          if (nextCorridor?.created_by) {
            await sendToUser(nextCorridor.created_by, "New delivery request", "You have a new parcel request.", {
              parcelId
            });
          }
          await sendToParcelTopic(parcelId, "Courier reassigned", "Finding a new courier.", {
            parcelId,
            status: "ASSIGNED"
          });

          return res.json({ status: "reassigned", parcelId });
        }
      }
    }

    // No more candidates - reset parcel status
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: null,
        assigned_at: null,
        status: "REQUESTED"
      })
      .eq("id", parcelId);

    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_DECLINE_FAILED");
    }

    const { broadcastParcelStatus } = require("../ws");
    broadcastParcelStatus(parcelId, { status: "REQUESTED", parcelId });

    return res.json({ status: "ok", parcelId });
  })
);

router.get(
  "/:id/events",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("handshake_events")
      .select("id,step,status,created_at,actor_id")
      .eq("parcel_id", parcelId)
      .order("created_at", { ascending: false });
    if (error) {
      throw new ApiError(error.message, 500, "EVENTS_FETCH_FAILED");
    }
    return res.json({ events: data || [] });
  })
);

router.post(
  "/:id/unassign",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({
        assigned_courier_id: null,
        assigned_at: null
      })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_UNASSIGN_FAILED");
    }
    return res.json({ status: "ok", parcelId });
  })
);

router.get(
  "/assigned/me",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("parcels")
      .select(
        "id,status,origin,destination,priority,fragile,assigned_at,created_at,origin_point,destination_point"
      )
      .eq("assigned_courier_id", req.user?.uid || "")
      .order("created_at", { ascending: false });
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_FETCH_FAILED");
    }
    return res.json({ parcels: data || [] });
  })
);

router.get(
  "/pending/me",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    const supabase = getSupabase();

    // Get corridors created by this courier
    const { data: corridors, error: corridorError } = await supabase
      .from("corridors")
      .select("id")
      .eq("created_by", courierId);

    if (corridorError) {
      throw new ApiError(corridorError.message, 500, "CORRIDOR_FETCH_FAILED");
    }

    if (!corridors || corridors.length === 0) {
      return res.json({ parcels: [] });
    }

    const corridorIds = corridors.map((c) => c.id);

    // Get parcels in the assignment queue for these corridors with PENDING status
    const { data: queueEntries, error: queueError } = await supabase
      .from("parcel_assignment_queue")
      .select(
        "parcel_id,corridor_id,rank,status,created_at"
      )
      .in("corridor_id", corridorIds)
      .eq("status", "PENDING")
      .order("rank", { ascending: true });

    if (queueError) {
      throw new ApiError(queueError.message, 500, "QUEUE_FETCH_FAILED");
    }

    if (!queueEntries || queueEntries.length === 0) {
      return res.json({ parcels: [] });
    }

    const parcelIds = queueEntries.map((q) => q.parcel_id);

    // Get full parcel details
    const { data: parcels, error: parcelError } = await supabase
      .from("parcels")
      .select(
        "id,status,origin,destination,priority,fragile,created_at,origin_point,destination_point,size,notes"
      )
      .in("id", parcelIds);

    if (parcelError) {
      throw new ApiError(parcelError.message, 500, "PARCEL_FETCH_FAILED");
    }

    // Enrich parcels with queue info (rank)
    const enrichedParcels = (parcels || []).map((parcel) => {
      const queueInfo = queueEntries.find((q) => q.parcel_id === parcel.id);
      return {
        ...parcel,
        queueRank: queueInfo?.rank || 0,
        queuedAt: queueInfo?.created_at
      };
    });

    return res.json({ parcels: enrichedParcels });
  })
);

router.post(
  "/:id/checkpoints/generate",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { count, radiusMeters } = req.body || {};
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { error } = await supabase.rpc("generate_parcel_checkpoints", {
      p_parcel_id: parcelId,
      p_count: count ?? 3,
      p_radius_m: radiusMeters ?? 200
    });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_GENERATE_FAILED");
    }
    return res.json({ status: "ok" });
  })
);

router.get(
  "/:id/checkpoints",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data: parcel, error: parcelError } = await supabase
      .from("parcels")
      .select("privacy_mode")
      .eq("id", parcelId)
      .maybeSingle();
    if (parcelError) {
      throw new ApiError(parcelError.message, 500, "PARCEL_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "PARCEL_NOT_FOUND");
    }

    const fields = parcel.privacy_mode
      ? "id,sequence,radius_m,reached_at"
      : "id,sequence,radius_m,reached_at,checkpoint_point";

    const { data, error } = await supabase
      .from("parcel_checkpoints")
      .select(fields)
      .eq("parcel_id", parcelId)
      .order("sequence", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_FETCH_FAILED");
    }
    return res.json({ checkpoints: data || [] });
  })
);

router.post(
  "/:id/privacy",
  requireRole("admin"),
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { privacyMode } = req.body || {};
    if (typeof privacyMode !== "boolean") {
      throw new ApiError("privacyMode must be boolean", 400, "PARCEL_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { error } = await supabase
      .from("parcels")
      .update({ privacy_mode: privacyMode })
      .eq("id", parcelId);
    if (error) {
      throw new ApiError(error.message, 500, "PARCEL_UPDATE_FAILED");
    }
    return res.json({ status: "ok", privacyMode });
  })
);

router.post(
  "/:id/checkpoints/verify",
  asyncHandler(async (req, res) => {
    const parcelId = req.params.id;
    const { lat, lng } = req.body || {};
    if (typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("lat/lng required", 400, "CHECKPOINT_INVALID_INPUT");
    }
    const supabase = getSupabase();
    await ensureParcelAccess(supabase, parcelId, req.user);
    const { data, error } = await supabase
      .from("parcel_checkpoints")
      .select("id,checkpoint_point,radius_m,reached_at")
      .eq("parcel_id", parcelId)
      .order("sequence", { ascending: true });
    if (error) {
      throw new ApiError(error.message, 500, "CHECKPOINT_FETCH_FAILED");
    }
    if (!data || data.length == 0) {
      throw new ApiError("No checkpoints", 404, "CHECKPOINT_NOT_FOUND");
    }

    for (const checkpoint of data) {
      if (checkpoint.reached_at) {
        continue;
      }
      const point = checkpoint.checkpoint_point;
      const wktMatch = point?.toString()?.match(/POINT\\(([-\\d\\.]+) ([-\\d\\.]+)\\)/);
      if (!wktMatch) {
        continue;
      }
      const cLng = Number.parseFloat(wktMatch[1]);
      const cLat = Number.parseFloat(wktMatch[2]);
      const toRad = (deg) => (deg * Math.PI) / 180;
      const dLat = toRad(cLat - lat);
      const dLng = toRad(cLng - lng);
      const lat1 = toRad(lat);
      const lat2 = toRad(cLat);
      const sinDLat = Math.sin(dLat / 2);
      const sinDLng = Math.sin(dLng / 2);
      const h =
        sinDLat * sinDLat +
        Math.cos(lat1) * Math.cos(lat2) * sinDLng * sinDLng;
      const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
      const distance = 6371000 * c;
      if (distance <= (checkpoint.radius_m || 200)) {
        const { error: updateError } = await supabase
          .from("parcel_checkpoints")
          .update({ reached_at: new Date().toISOString() })
          .eq("id", checkpoint.id);
        if (updateError) {
          throw new ApiError(updateError.message, 500, "CHECKPOINT_UPDATE_FAILED");
        }
        return res.json({ status: "ok", checkpointId: checkpoint.id });
      }
    }

    return res.status(403).json({ error: "Outside checkpoint radius", code: "CHECKPOINT_GEOFENCE_FAIL" });
  })
);

module.exports = router;
