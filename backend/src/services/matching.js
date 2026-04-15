/**
 * Matching Service
 * Handles parcel-to-corridor matching and assignment queue management
 */

const { getSupabase } = require("../supabase");
const { parseWktPoint } = require("../utils/geo");

/**
 * Match pending parcels with available corridors
 * This function should be called periodically by the scheduler
 */
async function matchPendingParcels() {
  const supabase = getSupabase();

  try {
    // Get all parcels that are REQUESTED and not yet assigned
    const { data: parcels, error: parcelError } = await supabase
      .from("parcels")
      .select("id, origin_point, destination_point, origin, destination")
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

    console.log(`[Matching] Found ${parcels.length} pending parcels to match`);

    // Also get all corridors with lines for debugging
    const { data: corridors, error: corridorError } = await supabase
      .from("corridors")
      .select("id, created_by, corridor_line")
      .not("corridor_line", "is", null);

    if (!corridorError && corridors) {
      console.log(`[Matching] Found ${corridors.length} corridors with lines available`);
    }

    let matchedCount = 0;
    let queuedCount = 0;

    for (const parcel of parcels) {
      try {
        // Check if parcel already has queue entries
        const { data: existing, error: existingError } = await supabase
          .from("parcel_assignment_queue")
          .select("id")
          .eq("parcel_id", parcel.id);

        if (existingError) {
          console.error(`[Matching] Error checking existing queue for parcel ${parcel.id}:`, existingError);
          continue;
        }

        if (existing && existing.length > 0) {
          console.log(`[Matching] Parcel ${parcel.id} already has queue entries, skipping`);
          continue;
        }

        // Call the matching function to find corridors for this parcel
        const { data: matches, error: matchError } = await supabase.rpc(
          "match_corridors_for_parcel",
          {
            p_origin: parcel.origin_point,
            p_destination: parcel.destination_point,
            p_max_detour_m: 50000 // 50km default
          }
        );

        if (matchError) {
          console.error(`[Matching] Error matching parcel ${parcel.id}:`, matchError);
          continue;
        }

        if (!matches || matches.length === 0) {
          console.log(`[Matching] No matching corridors found for parcel ${parcel.id} (${parcel.origin} → ${parcel.destination})`);
          continue;
        }

        console.log(`[Matching] Found ${matches.length} matching corridors for parcel ${parcel.id}`);
        matchedCount++;

        // Insert queue entries for each matching corridor
        const queueEntries = matches.map((match, index) => ({
          parcel_id: parcel.id,
          corridor_id: match.corridor_id,
          rank: index + 1,
          status: "PENDING"
        }));

        const { error: insertError } = await supabase
          .from("parcel_assignment_queue")
          .insert(queueEntries);

        if (insertError) {
          console.error(`[Matching] Error inserting queue entries for parcel ${parcel.id}:`, insertError);
          continue;
        }

        queuedCount += queueEntries.length;
      } catch (err) {
        console.error(`[Matching] Unexpected error processing parcel ${parcel.id}:`, err);
      }
    }

    console.log(`[Matching] ✓ Matched ${matchedCount} parcels with ${queuedCount} queue entries`);
  } catch (error) {
    console.error("[Matching] Fatal error in matching service:", error);
  }
}

module.exports = {
  matchPendingParcels
};
