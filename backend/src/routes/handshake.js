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
const { enqueueNotification } = require("../services/notification_service");
const { NOTIFICATION_EVENT_TYPES } = require("../services/notification_events");
const { parcelClientRecipients } = require("../services/parcel_stakeholders");

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
      .select("id, created_by, assigned_courier_id, recipient_id, dual_tracking")
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }
    if (parcel.created_by && parcel.created_by !== req.user?.uid) {
      throw new ApiError("Not permitted to initialize this parcel", 403, "HANDSHAKE_FORBIDDEN");
    }
    if (!parcel.assigned_courier_id) {
      throw new ApiError("Courier not assigned yet", 409, "HANDSHAKE_COURIER_NOT_ASSIGNED");
    }

    const { data: courierProfile, error: courierError } = await supabase
      .from("users")
      .select("current_route_id,is_active")
      .eq("id", parcel.assigned_courier_id)
      .maybeSingle();
    if (courierError) {
      throw new ApiError(courierError.message, 500, "HANDSHAKE_COURIER_LOOKUP_FAILED");
    }
    if (!courierProfile?.current_route_id || courierProfile.is_active === false) {
      throw new ApiError(
        "Route not started",
        409,
        "ERROR_ROUTE_NOT_STARTED"
      );
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
    const pinRecipients = parcelClientRecipients(parcel || {});
    if (pinRecipients.length > 0) {
      await enqueueNotification({
        type: NOTIFICATION_EVENT_TYPES.HANDSHAKE_PIN_READY,
        title: "PINs ready",
        body: "Pickup and dropoff PINs have been set.",
        recipients: pinRecipients,
        entityType: "parcel",
        entityId: parcelId,
        payload: { parcelId, status: "PINS_SET" }
      });
    }
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
  "/pickup/meeting-point",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, lat, lng } = req.body || {};
    if (!parcelId || typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("parcelId, lat, lng required", 400, "HANDSHAKE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select("id,assigned_courier_id,pickup_lat,pickup_lng,status")
      .eq("id", parcelId)
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }
    if (parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this parcel", 403, "HANDSHAKE_NOT_ASSIGNED");
    }
    if (typeof parcel.pickup_lat !== "number" || typeof parcel.pickup_lng !== "number") {
      throw new ApiError("Pickup location missing", 409, "HANDSHAKE_LOCATION_MISSING");
    }
    const base = { lat: parcel.pickup_lat, lng: parcel.pickup_lng };
    const distance = haversineMeters(base, { lat, lng });
    if (distance > GPS_GATE_METERS) {
      throw new ApiError("Meeting point must be within 50m of pickup", 403, "HANDSHAKE_MEETING_TOO_FAR");
    }
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        meeting_pickup_lat: lat,
        meeting_pickup_lng: lng
      })
      .eq("id", parcelId);
    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }
    return res.json({ status: "ok", parcelId, meetingLat: lat, meetingLng: lng });
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
        "id,pickup_pin_hash,pickup_lat,pickup_lng,pickup_point,meeting_pickup_lat,meeting_pickup_lng,pickup_verified_at,status,created_by,assigned_courier_id,pickup_pin_attempts,pin_locked_until"
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
    const { data: courierProfile, error: courierError } = await supabase
      .from("users")
      .select("current_route_id,is_active")
      .eq("id", req.user?.uid || "")
      .maybeSingle();
    if (courierError) {
      throw new ApiError(courierError.message, 500, "HANDSHAKE_COURIER_LOOKUP_FAILED");
    }
    if (!courierProfile?.current_route_id || courierProfile.is_active === false) {
      throw new ApiError(
        "Route not started",
        409,
        "ERROR_ROUTE_NOT_STARTED"
      );
    }
    const { data: assignedQueue } = await supabase
      .from("parcel_assignment_queue")
      .select("corridor_id,status")
      .eq("parcel_id", parcelId)
      .eq("status", "ASSIGNED")
      .maybeSingle();
    if (assignedQueue?.corridor_id && assignedQueue.corridor_id !== courierProfile.current_route_id) {
      throw new ApiError(
        "Active route does not match assigned corridor",
        409,
        "ERROR_ROUTE_NOT_STARTED"
      );
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

    if (typeof parcel.pickup_lat !== "number" || typeof parcel.pickup_lng !== "number") {
      throw new ApiError("Pickup location missing", 409, "HANDSHAKE_LOCATION_MISSING");
    }
    const courierLocation = `POINT(${lng} ${lat})`;
    let gateLat = parcel.pickup_lat;
    let gateLng = parcel.pickup_lng;
    if (typeof parcel.meeting_pickup_lat === "number" && typeof parcel.meeting_pickup_lng === "number") {
      gateLat = parcel.meeting_pickup_lat;
      gateLng = parcel.meeting_pickup_lng;
    }
    let withinGate = false;
    const gatePointWkt = `POINT(${gateLng} ${gateLat})`;
    if (parcel.pickup_point) {
      const gateGeom = parcel.meeting_pickup_lat != null ? gatePointWkt : parcel.pickup_point;
      const { data: dwithin, error: dwErr } = await supabase.rpc("st_dwithin", {
        geom1: courierLocation,
        geom2: gateGeom,
        distance: GPS_GATE_METERS
      });
      if (!dwErr && dwithin) {
        withinGate = true;
      }
    }
    if (!withinGate) {
      const pickupPoint = { lat: gateLat, lng: gateLng };
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
      .select("created_by,recipient_id,dual_tracking")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToParcelTopic } = require("../utils/notifications");
    const pickupNotify = parcelClientRecipients(parcelOwner || {});
    if (pickupNotify.length > 0) {
      await enqueueNotification({
        type: NOTIFICATION_EVENT_TYPES.HANDSHAKE_PICKUP_COMPLETE,
        title: "Pickup complete",
        body: "Parcel is in transit.",
        recipients: pickupNotify,
        entityType: "parcel",
        entityId: parcelId,
        payload: { parcelId, status: "IN_TRANSIT" }
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
        "id,dropoff_pin_hash,dropoff_point,dropoff_verified_at,pickup_verified_at,status,assigned_courier_id,created_by,recipient_id,dropoff_pin_attempts,pin_locked_until"
      )
      .eq("id", parcelId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel) {
      throw new ApiError("Parcel not found", 404, "HANDSHAKE_NOT_FOUND");
    }
    const uid = req.user?.uid;
    const allowed =
      (parcel.created_by && parcel.created_by === uid) ||
      (parcel.recipient_id && parcel.recipient_id === uid);
    if (!allowed) {
      throw new ApiError("Not permitted to complete dropoff for this parcel", 403, "HANDSHAKE_FORBIDDEN");
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
      .select("created_by,recipient_id,dual_tracking")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToParcelTopic } = require("../utils/notifications");
    const doneRecipients = parcelClientRecipients(parcelOwner || {});
    if (doneRecipients.length > 0) {
      await enqueueNotification({
        type: NOTIFICATION_EVENT_TYPES.HANDSHAKE_DELIVERY_COMPLETE,
        title: "Delivery complete",
        body: "Parcel delivered.",
        recipients: doneRecipients,
        entityType: "parcel",
        entityId: parcelId,
        payload: { parcelId, status: "COMPLETED" }
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

router.post(
  "/recipient/issue-dropoff-otp",
  requireRole("client"),
  asyncHandler(async (req, res) => {
    const { parcelId, lat, lng } = req.body || {};
    if (!parcelId || typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("parcelId, lat, lng required", 400, "HANDSHAKE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select("id,recipient_id,dropoff_point,dropoff_verified_at,pickup_verified_at")
      .eq("id", parcelId)
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel || parcel.recipient_id !== req.user?.uid) {
      throw new ApiError("Not permitted", 403, "HANDSHAKE_FORBIDDEN");
    }
    if (!parcel.pickup_verified_at || parcel.dropoff_verified_at) {
      throw new ApiError("Parcel not ready for recipient dropoff", 409, "HANDSHAKE_NOT_READY");
    }
    const dropoffPoint = parseWktPoint(parcel.dropoff_point);
    if (!dropoffPoint) {
      throw new ApiError("Dropoff location missing", 409, "HANDSHAKE_LOCATION_MISSING");
    }
    const distance = haversineMeters(dropoffPoint, { lat, lng });
    if (distance > GPS_GATE_METERS) {
      throw new ApiError("Outside GPS gate", 403, "HANDSHAKE_GPS_FAIL");
    }
    const otp = generatePin();
    const expires = new Date(Date.now() + 10 * 60 * 1000).toISOString();
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        recipient_dropoff_otp_hash: hashPin(otp),
        recipient_dropoff_otp_expires_at: expires
      })
      .eq("id", parcelId);
    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }

    await enqueueNotification({
      type: NOTIFICATION_EVENT_TYPES.RECIPIENT_DROPOFF_OTP_READY,
      title: "Dropoff code ready",
      body: "Show this code to the courier to complete handoff.",
      recipients: [req.user?.uid],
      entityType: "parcel",
      entityId: parcelId,
      payload: { parcelId, expiresAt: expires }
    });

    return res.json({ parcelId, dropoffOtp: otp, expiresAt: expires });
  })
);

router.post(
  "/courier/request-manual-dropoff-otp",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, phoneE164 } = req.body || {};
    if (!parcelId || !phoneE164 || typeof phoneE164 !== "string") {
      throw new ApiError("parcelId and phoneE164 required", 400, "HANDSHAKE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select("id,assigned_courier_id,dropoff_verified_at,pickup_verified_at")
      .eq("id", parcelId)
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel || parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this parcel", 403, "HANDSHAKE_NOT_ASSIGNED");
    }
    if (!parcel.pickup_verified_at || parcel.dropoff_verified_at) {
      throw new ApiError("Parcel not ready", 409, "HANDSHAKE_NOT_READY");
    }
    const otp = generatePin();
    const expires = new Date(Date.now() + 15 * 60 * 1000).toISOString();
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        manual_dropoff_phone: phoneE164.trim(),
        manual_dropoff_otp_hash: hashPin(otp),
        manual_dropoff_otp_expires_at: expires
      })
      .eq("id", parcelId);
    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }
    await enqueueNotification({
      type: NOTIFICATION_EVENT_TYPES.MANUAL_DROPOFF_OTP_SENT,
      title: "Manual dropoff code sent",
      body: "A manual verification code was generated for courier-assisted handoff.",
      recipients: [req.user.uid],
      entityType: "parcel",
      entityId: parcelId,
      payload: { parcelId, otp, expiresAt: expires, phoneE164: phoneE164.trim() }
    });
    return res.json({
      status: "ok",
      parcelId,
      otp,
      expiresAt: expires
    });
  })
);

router.post(
  "/courier/complete-dropoff",
  requireRole("courier"),
  asyncHandler(async (req, res) => {
    const { parcelId, otp, photoUrl, lat, lng, accuracy } = req.body || {};
    if (!parcelId || !otp || !photoUrl || typeof lat !== "number" || typeof lng !== "number") {
      throw new ApiError("Missing required fields", 400, "HANDSHAKE_INVALID_INPUT");
    }
    const supabase = getSupabase();
    const { data: parcel, error } = await supabase
      .from("parcels")
      .select(
        "id,assigned_courier_id,dropoff_point,dropoff_verified_at,pickup_verified_at,recipient_dropoff_otp_hash,recipient_dropoff_otp_expires_at,manual_dropoff_otp_hash,manual_dropoff_otp_expires_at"
      )
      .eq("id", parcelId)
      .maybeSingle();
    if (error) {
      throw new ApiError(error.message, 500, "HANDSHAKE_LOOKUP_FAILED");
    }
    if (!parcel || parcel.assigned_courier_id !== req.user?.uid) {
      throw new ApiError("Not assigned to this parcel", 403, "HANDSHAKE_NOT_ASSIGNED");
    }
    if (!parcel.pickup_verified_at || parcel.dropoff_verified_at) {
      throw new ApiError("Parcel not ready", 409, "HANDSHAKE_NOT_READY");
    }
    const now = new Date();
    let otpOk = false;
    if (
      parcel.recipient_dropoff_otp_hash &&
      parcel.recipient_dropoff_otp_expires_at &&
      new Date(parcel.recipient_dropoff_otp_expires_at) > now &&
      hashPin(otp) === parcel.recipient_dropoff_otp_hash
    ) {
      otpOk = true;
    }
    if (
      !otpOk &&
      parcel.manual_dropoff_otp_hash &&
      parcel.manual_dropoff_otp_expires_at &&
      new Date(parcel.manual_dropoff_otp_expires_at) > now &&
      hashPin(otp) === parcel.manual_dropoff_otp_hash
    ) {
      otpOk = true;
    }
    if (!otpOk) {
      throw new ApiError("Invalid or expired OTP", 401, "HANDSHAKE_INVALID_OTP");
    }
    const dropoffPoint = parseWktPoint(parcel.dropoff_point);
    if (!dropoffPoint) {
      throw new ApiError("Dropoff location missing", 409, "HANDSHAKE_LOCATION_MISSING");
    }
    const distance = haversineMeters(dropoffPoint, { lat, lng });
    if (distance > GPS_GATE_METERS) {
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
        status: "COMPLETED",
        recipient_dropoff_otp_hash: null,
        recipient_dropoff_otp_expires_at: null,
        manual_dropoff_otp_hash: null,
        manual_dropoff_otp_expires_at: null
      })
      .eq("id", parcelId);
    if (updateError) {
      throw new ApiError(updateError.message, 500, "HANDSHAKE_UPDATE_FAILED");
    }
    broadcastParcelStatus(parcelId, { status: "COMPLETED", parcelId });
    const { data: parcelOwner } = await supabase
      .from("parcels")
      .select("created_by,recipient_id,dual_tracking")
      .eq("id", parcelId)
      .maybeSingle();
    const { sendToParcelTopic } = require("../utils/notifications");
    const doneRecipients = parcelClientRecipients(parcelOwner || {});
    if (doneRecipients.length > 0) {
      await enqueueNotification({
        type: NOTIFICATION_EVENT_TYPES.HANDSHAKE_DELIVERY_COMPLETE,
        title: "Delivery complete",
        body: "Parcel delivered.",
        recipients: doneRecipients,
        entityType: "parcel",
        entityId: parcelId,
        payload: { parcelId, status: "COMPLETED" }
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
      status: "SUCCESS_COURIER_OTP",
      lat,
      lng,
      accuracy_m: typeof accuracy === "number" ? accuracy : null,
      photo_url: photoUrl
    });
    return res.json({ status: "ok" });
  })
);

module.exports = router;
