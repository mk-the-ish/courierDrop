const express = require("express");
const { getSupabase } = require("../supabase");
const ApiError = require("../utils/api_error");
const asyncHandler = require("../utils/async_handler");
const { requireUser } = require("../middleware/auth");

const router = express.Router();

// POST /vehicles - Create or update courier vehicle
router.post(
  "/",
  requireUser,
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    if (!courierId) {
      throw new ApiError("User ID not found in token", 400, "USER_ID_MISSING");
    }

    const {
      vehicleType,
      make,
      model,
      year,
      color,
      licensePlate,
      maxCapacityKg,
      notes
    } = req.body || {};

    if (!vehicleType || !licensePlate || !maxCapacityKg) {
      throw new ApiError(
        "vehicleType, licensePlate, and maxCapacityKg are required",
        400,
        "VEHICLE_INVALID_INPUT"
      );
    }

    if (!["motorcycle", "bicycle", "scooter", "car", "van", "truck"].includes(vehicleType)) {
      throw new ApiError(
        "Invalid vehicleType. Must be one of: motorcycle, bicycle, scooter, car, van, truck",
        400,
        "VEHICLE_INVALID_TYPE"
      );
    }

    const supabase = getSupabase();

    // Check if courier already has a vehicle
    const { data: existing, error: lookupError } = await supabase
      .from("vehicles")
      .select("id")
      .eq("courier_id", courierId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "VEHICLE_LOOKUP_FAILED");
    }

    const payload = {
      courier_id: courierId,
      vehicle_type: vehicleType,
      make: make || null,
      model: model || null,
      year: year ? parseInt(year) : null,
      color: color || null,
      license_plate: licensePlate,
      max_capacity_kg: parseInt(maxCapacityKg),
      notes: notes || null,
      verification_status: "unverified",
      is_active: true
    };

    let result;

    if (existing) {
      // Update existing vehicle
      const { data, error } = await supabase
        .from("vehicles")
        .update(payload)
        .eq("id", existing.id)
        .select("id");

      if (error) {
        throw new ApiError(error.message, 500, "VEHICLE_UPDATE_FAILED");
      }

      result = data?.[0];
    } else {
      // Create new vehicle
      const { data, error } = await supabase
        .from("vehicles")
        .insert(payload)
        .select("id");

      if (error) {
        throw new ApiError(error.message, 500, "VEHICLE_INSERT_FAILED");
      }

      result = data?.[0];
    }

    return res.status(201).json({
      id: result?.id,
      courierId,
      vehicleType,
      licensePlate,
      maxCapacityKg,
      message: "Vehicle information saved successfully"
    });
  })
);

// GET /vehicles/me - Get current courier's vehicle
router.get(
  "/me",
  requireUser,
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    if (!courierId) {
      throw new ApiError("User ID not found in token", 400, "USER_ID_MISSING");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("vehicles")
      .select("*")
      .eq("courier_id", courierId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_LOOKUP_FAILED");
    }

    if (!data) {
      return res.status(404).json({
        error: "Vehicle not found",
        code: "VEHICLE_NOT_FOUND"
      });
    }

    return res.json(data);
  })
);

// GET /vehicles/:id - Get vehicle by ID (for admin)
router.get(
  "/:id",
  requireUser,
  asyncHandler(async (req, res) => {
    const vehicleId = req.params.id;
    if (!vehicleId) {
      throw new ApiError("Vehicle ID required", 400, "VEHICLE_ID_REQUIRED");
    }

    const supabase = getSupabase();
    const { data, error } = await supabase
      .from("vehicles")
      .select("*")
      .eq("id", vehicleId)
      .maybeSingle();

    if (error) {
      throw new ApiError(error.message, 500, "VEHICLE_LOOKUP_FAILED");
    }

    if (!data) {
      throw new ApiError("Vehicle not found", 404, "VEHICLE_NOT_FOUND");
    }

    return res.json(data);
  })
);

// DELETE /vehicles/me - Delete current courier's vehicle
router.delete(
  "/me",
  requireUser,
  asyncHandler(async (req, res) => {
    const courierId = req.user?.uid;
    if (!courierId) {
      throw new ApiError("User ID not found in token", 400, "USER_ID_MISSING");
    }

    const supabase = getSupabase();

    // Get vehicle first to verify ownership
    const { data: vehicle, error: lookupError } = await supabase
      .from("vehicles")
      .select("id")
      .eq("courier_id", courierId)
      .maybeSingle();

    if (lookupError) {
      throw new ApiError(lookupError.message, 500, "VEHICLE_LOOKUP_FAILED");
    }

    if (!vehicle) {
      throw new ApiError("Vehicle not found", 404, "VEHICLE_NOT_FOUND");
    }

    // Delete vehicle
    const { error: deleteError } = await supabase
      .from("vehicles")
      .delete()
      .eq("id", vehicle.id);

    if (deleteError) {
      throw new ApiError(deleteError.message, 500, "VEHICLE_DELETE_FAILED");
    }

    return res.json({
      message: "Vehicle deleted successfully",
      vehicleId: vehicle.id
    });
  })
);

module.exports = router;
