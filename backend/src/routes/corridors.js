const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");

const router = express.Router();
const conflictAttempts = new Map();
const CONFLICT_WINDOW_MS = 10 * 60 * 1000;
const CONFLICT_MAX = 5;

function isNumber(value) {
  return typeof value === "number" && Number.isFinite(value);
}

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

function toPointWkt(point) {
  if (!point || !isNumber(point.lat) || !isNumber(point.lng)) {
    return null;
  }
  return `SRID=4326;POINT(${point.lng} ${point.lat})`;
}

function toLineStringWkt(points) {
  if (!Array.isArray(points) || points.length < 2) {
    return null;
  }
  const segments = [];
  for (const point of points) {
    if (!isNumber(point?.lat) || !isNumber(point?.lng)) {
      return null;
    }
    segments.push(`${point.lng} ${point.lat}`);
  }
  return `SRID=4326;LINESTRING(${segments.join(",")})`;
}

router.post(
  "/",
  asyncHandler(async (req, res) => {
  const {
    startLocation,
    endLocation,
    windowStart,
    windowEnd,
    allowMultipleParcels,
    notes,
    clientId
  } = req.body || {};

    if (!startLocation || !endLocation || !windowStart || !windowEnd) {
      throw new ApiError("Missing required fields", 400, "CORRIDOR_INVALID_INPUT");
    }

  const supabase = getSupabase();
  if (clientId) {
    const { data: existing, error: lookupError } = await supabase
      .from("corridors")
      .select("created_by")
      .eq("id", clientId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "CORRIDOR_LOOKUP_FAILED");
    }

    if (existing && existing.created_by && existing.created_by !== req.user?.uid) {
      const rateKey = `corridor:${req.user?.uid || "anon"}`;
      if (!checkConflictRateLimit(rateKey)) {
        throw new ApiError(
          "Too many conflict attempts. Try again later.",
          429,
          "CORRIDOR_CONFLICT_RATE_LIMIT"
        );
      }
      throw new ApiError(
        "clientId already used by another user",
        409,
        "CORRIDOR_CONFLICT"
      );
    }
  }

  const payload = {
    ...(clientId ? { id: clientId } : {}),
    start_location: startLocation,
    end_location: endLocation,
    window_start: windowStart,
    window_end: windowEnd,
    allow_multiple_parcels: Boolean(allowMultipleParcels),
    notes: notes || null,
    created_by: req.user?.uid || null,
    request_id: req.requestId || null
  };

  // Parse coordinates from "latitude, longitude" string format
  const parseCoordinates = (coordString) => {
    if (!coordString) return null;
    const parts = coordString.trim().split(",").map((s) => parseFloat(s.trim()));
    if (parts.length !== 2 || parts.some((p) => isNaN(p))) return null;
    return { lat: parts[0], lng: parts[1] };
  };

  const startCoords = parseCoordinates(startLocation);
  const endCoords = parseCoordinates(endLocation);

  if (startCoords) {
    payload.start_point = `SRID=4326;POINT(${startCoords.lng} ${startCoords.lat})`;
  }

  if (endCoords) {
    payload.end_point = `SRID=4326;POINT(${endCoords.lng} ${endCoords.lat})`;
  }

  const { data, error } = await supabase
    .from("corridors")
    .upsert(payload, { onConflict: "id" })
    .select("id");

    if (error) {
      throw new ApiError(error.message, 500, "CORRIDOR_INSERT_FAILED");
    }

    return res.status(201).json({ id: data?.[0]?.id });
  })
);

router.post(
  "/:id/line",
  asyncHandler(async (req, res) => {
    const corridorId = req.params.id;
    const { polyline } = req.body || {};

  const lineWkt = toLineStringWkt(polyline);
  if (!lineWkt) {
    throw new ApiError(
      "polyline must be an array of at least 2 points with lat/lng",
      400,
      "CORRIDOR_INVALID_POLYLINE"
    );
  }

  const startPoint = polyline[0];
  const endPoint = polyline[polyline.length - 1];
  const startWkt = toPointWkt(startPoint);
  const endWkt = toPointWkt(endPoint);

  if (!startWkt || !endWkt) {
    throw new ApiError(
      "polyline points must include numeric lat/lng",
      400,
      "CORRIDOR_INVALID_POLYLINE"
    );
  }

  const supabase = getSupabase();
  const { error } = await supabase.rpc("set_corridor_line", {
    p_corridor_id: corridorId,
    p_line_wkt: lineWkt,
    p_start_wkt: startWkt,
    p_end_wkt: endWkt
  });

    if (error) {
      throw new ApiError(error.message, 500, "CORRIDOR_LINE_FAILED");
    }

    return res.json({ status: "ok" });
  })
);

module.exports = router;
