const crypto = require("crypto");
const express = require("express");
const multer = require("multer");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { parseWktPoint, haversineMeters } = require("../utils/geo");
const { broadcastParcelStatus, broadcastHandshakeEvent } = require("../ws");
const config = require("../config");
const { requireRole, requireAnyRole } = require("../middleware/auth");

const router = express.Router();
const GPS_GATE_METERS = 50;

const upload = multer({ storage: multer.memoryStorage() });

function hashPin(pin) {
  return crypto.createHash("sha256").update(pin).digest("hex");
}

function generatePin() {
  const pin = Math.floor(100000 + Math.random() * 900000);
  return pin.toString();
}

async function insertEvent(supabase, payload) {
  await supabase.from("handshake_events").insert(payload);
  broadcastHandshakeEvent(payload.parcel_id, payload);
}

router.post(
  "/upload",
  requireAnyRole(["courier", "client"]),
  upload.single("photo"),
  asyncHandler(async (req, res) => {
    if (!req.file) {
      throw new ApiError("photo required", 400, "HANDSHAKE_PHOTO_REQUIRED");
    }
    if (!config.supabaseStorageBucket) {
      throw new ApiError(
        "Supabase storage bucket not configured",
        500,
        "HANDSHAKE_STORAGE_MISCONFIGURED"
      );
    }
    const supabase = getSupabase();
    const parcelId = req.body?.parcelId || "unassigned";
    const timestamp = Date.now();
    const safeName = req.file.originalname.replace(/[^a-zA-Z0-9._-]/g, "_");
    const objectPath = `handshake/${parcelId}/${timestamp}_${safeName}`;
    const { error: uploadError } = await supabase.storage
      .from(config.supabaseStorageBucket)
      .upload(objectPath, req.file.buffer, {
        contentType: req.file.mimetype,
        upsert: false
      });
    if (uploadError) {
      throw new ApiError(uploadError.message, 500, "HANDSHAKE_UPLOAD_FAILED");
    }
    const { data } = supabase.storage
      .from(config.supabaseStorageBucket)
      .getPublicUrl(objectPath);
    return res.status(201).json({ url: data.publicUrl });
  })
);

router.post(
  "/init",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const { parcelId } = req.body || {};
    if (!parcelId) {
      throw new ApiError("parcelId required", 400, "HANDSHAKE_INVALID_INPUT");
    }

    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select("id, created_by")
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }

    const pickupPin = generatePin();
    const dropoffPin = generatePin();
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        pickup_pin_hash: hashPin(pickupPin),
        dropoff_pin_hash: hashPin(dropoffPin),
        status: "PINS_SET"
      })
      .eq("id", parcelId);

    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_INIT_FAILED");
    }

    broadcastParcelStatus(parcelId, {
      status: "PINS_SET",
      parcelId
    });
    const { sendToParcelTopic } = require("../utils/notifications");
    await sendToParcelTopic(parcelId, "PINs ready", "Pickup and dropoff PINs have been set.", {
      parcelId,
      status: "PINS_SET"
    });

    await insertEvent(supabase, {
      parcel_id: parcelId,
      step: "PINS_SET",
      actor_id: req.user?.uid || null,
      status: "SUCCESS"
    });

    return res.json({
      parcelId,
      pickupPin,
      dropoffPin
    });
  })
);

router.post(
  "/pickup",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, pin, lat, lng, accuracy, photoUrl } = req.body || {};
    if (!parcelId || !pin || typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("Missing required fields", 400, "HANDSHAKE_INVALID_INPUT");
    }
    if (!photoUrl) {
      throw new ApiError("photoUrl required", 400, "HANDSHAKE_PHOTO_REQUIRED");
    }

    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select(
        "id,pickup_pin_hash,pickup_point,pickup_verified_at,status,created_by,assigned_courier_id,pickup_pin_attempts,pin_locked_until"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }
    if (parcel.assigned_courier_id && parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this courier", 403, "HANDSHAKE_NOT_ASSIGNED");
    }
    if (!parcel.pickup_pin_hash) {
      throw new ApiError("Pickup PIN not initialized", 409, "HANDSHAKE_NOT_READY");
    }
    if (parcel.pin_locked_until && new Date(parcel.pin_locked_until) > new Date()) {
      const remainingSeconds = Math.max(
        0,
        Math.round((new Date(parcel.pin_locked_until) - new Date()) / 1000)
      );
      return res.status(429).json({
        error: "PIN locked. Try later.",
        code: "HANDSHAKE_PIN_LOCKED",
        retryAfterSeconds: remainingSeconds
      });
    }
    if (parcel.pickup_verified_at) {
      return res.json({ status: "already_verified" });
    }

    if (hashPin(pin) !== parcel.pickup_pin_hash) {
      const attempts = (parcel.pickup_pin_attempts || 0) + 1;
      const lockedUntil =
        attempts >= 5 ? new Date(Date.now() + 10 * 60 * 1000) : null;
      await supabase
        .from("parcels")
        .update({
          pickup_pin_attempts: attempts,
          pin_locked_until: lockedUntil ? lockedUntil.toISOString() : null
        })
        .eq("id", parcelId);
      await insertEvent(supabase, {
        parcel_id: parcelId,
        step: "PICKUP",
        actor_id: req.user?.uid || null,
        status: "FAILED_PIN"
      });
      throw new ApiError("Invalid PIN", 401, "HANDSHAKE_INVALID_PIN");
    }

    const pickupPoint = parseWktPoint(parcel.pickup_point);
    if (!pickupPoint) {
      throw new ApiError("Pickup location missing", 409, "HANDSHAKE_LOCATION_MISSING");
    }
    const distance = haversineMeters(pickupPoint, { lat, lng });
    if (distance > GPS_GATE_METERS) {
      await insertEvent(supabase, {
        parcel_id: parcelId,
        step: "PICKUP",
        actor_id: req.user?.uid || null,
        status: "FAILED_GPS",
        lat,
        lng,
        accuracy_m: typeof accuracy === "number" ? accuracy : null
      });
      return res.status(403).json({
        error: "Outside GPS gate",
        code: "HANDSHAKE_GPS_FAIL",
        distanceMeters: Math.round(distance)
      });
    }

    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        pickup_photo_url: photoUrl,
        pickup_verified_at: new Date().toISOString(),
        pickup_verified_by: req.user?.uid || null,
        pickup_lat: lat,
        pickup_lng: lng,
        pickup_accuracy_m: typeof accuracy === "number" ? accuracy : null,
        pickup_pin_attempts: 0,
        pin_locked_until: null,
        status: "IN_TRANSIT"
      })
      .eq("id", parcelId);

    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }

    broadcastParcelStatus(parcelId, {
      status: "IN_TRANSIT",
      parcelId
    });

    const { data: parcelOwner } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcelOwner?.created_by) {
      await sendToUser(parcelOwner.created_by, "Pickup complete", "Parcel is in transit.", {
        parcelId
      });
    }
    await sendToParcelTopic(parcelId, "Pickup complete", "Parcel is in transit.", {
      parcelId,
      status: "IN_TRANSIT"
    });

    await insertEvent(supabase, {
      parcel_id: parcelId,
      step: "PICKUP",
      actor_id: req.user?.uid || null,
      status: "SUCCESS",
      lat,
      lng,
      accuracy_m: typeof accuracy === "number" ? accuracy : null,
      photo_url: photoUrl
    });

    return res.json({ status: "ok", pickupVerified: true });
  })
);

router.post(
  "/dropoff",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const { parcelId, pin, lat, lng, accuracy, photoUrl } = req.body || {};
    if (!parcelId || !pin || typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("Missing required fields", 400, "HANDSHAKE_INVALID_INPUT");
    }
    if (!photoUrl) {
      throw new ApiError("photoUrl required", 400, "HANDSHAKE_PHOTO_REQUIRED");
    }

    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select(
        "id,dropoff_pin_hash,dropoff_point,dropoff_verified_at,pickup_verified_at,status,assigned_courier_id,dropoff_pin_attempts,pin_locked_until"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }
    if (parcel.assigned_courier_id && parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this courier", 403, "HANDSHAKE_NOT_ASSIGNED");
    }
    if (!parcel.dropoff_pin_hash) {
      throw new ApiError("Dropoff PIN not initialized", 409, "HANDSHAKE_NOT_READY");
    }
    if (!parcel.pickup_verified_at) {
      throw new ApiError("Pickup not completed", 409, "HANDSHAKE_PICKUP_REQUIRED");
    }
    if (parcel.pin_locked_until && new Date(parcel.pin_locked_until) > new Date()) {
      const remainingSeconds = Math.max(
        0,
        Math.round((new Date(parcel.pin_locked_until) - new Date()) / 1000)
      );
      return res.status(429).json({
        error: "PIN locked. Try later.",
        code: "HANDSHAKE_PIN_LOCKED",
        retryAfterSeconds: remainingSeconds
      });
    }
    if (parcel.dropoff_verified_at) {
      return res.json({ status: "already_verified" });
    }

    if (hashPin(pin) !== parcel.dropoff_pin_hash) {
      const attempts = (parcel.dropoff_pin_attempts || 0) + 1;
      const lockedUntil =
        attempts >= 5 ? new Date(Date.now() + 10 * 60 * 1000) : null;
      await supabase
        .from("parcels")
        .update({
          dropoff_pin_attempts: attempts,
          pin_locked_until: lockedUntil ? lockedUntil.toISOString() : null
        })
        .eq("id", parcelId);
      await insertEvent(supabase, {
        parcel_id: parcelId,
        step: "DROPOFF",
        actor_id: req.user?.uid || null,
        status: "FAILED_PIN"
      });
      throw new ApiError("Invalid PIN", 401, "HANDSHAKE_INVALID_PIN");
    }

    const dropoffPoint = parseWktPoint(parcel.dropoff_point);
    if (!dropoffPoint) {
      throw new ApiError(
        "Dropoff location missing",
        409,
        "HANDSHAKE_LOCATION_MISSING"
      );
    }
    const distance = haversineMeters(dropoffPoint, { lat, lng });
    if (distance > GPS_GATE_METERS) {
      await insertEvent(supabase, {
        parcel_id: parcelId,
        step: "DROPOFF",
        actor_id: req.user?.uid || null,
        status: "FAILED_GPS",
        lat,
        lng,
        accuracy_m: typeof accuracy === "number" ? accuracy : null
      });
      throw new ApiError("Outside GPS gate", 403, "HANDSHAKE_GPS_FAIL");
    }

    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        dropoff_photo_url: photoUrl,
        dropoff_verified_at: new Date().toISOString(),
        dropoff_verified_by: req.user?.uid || null,
        dropoff_lat: lat,
        dropoff_lng: lng,
        dropoff_accuracy_m: typeof accuracy === "number" ? accuracy : null,
        dropoff_pin_attempts: 0,
        pin_locked_until: null,
        status: "COMPLETED"
      })
      .eq("id", parcelId);

    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }

    broadcastParcelStatus(parcelId, {
      status: "COMPLETED",
      parcelId
    });

    const { data: parcelOwner } = await supabase
      .from("parcels")
      .select("created_by")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToUser, sendToParcelTopic } = require("../utils/notifications");
    if (parcelOwner?.created_by) {
      await sendToUser(parcelOwner.created_by, "Delivery complete", "Parcel delivered.", {
        parcelId
      });
    }
    await sendToParcelTopic(parcelId, "Delivery complete", "Parcel delivered.", {
      parcelId,
      status: "COMPLETED"
    });

    await insertEvent(supabase, {
      parcel_id: parcelId,
      step: "DROPOFF",
      actor_id: req.user?.uid || null,
      status: "SUCCESS",
      lat,
      lng,
      accuracy_m: typeof accuracy === "number" ? accuracy : null,
      photo_url: photoUrl
    });

    return res.json({ status: "ok" });
  })
);

module.exports = router;
