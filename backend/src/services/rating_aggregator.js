/**
 * Rating Aggregation Service
 * 
 * Score = (Client_Stars * 0.4) + (Route_Adherence * 0.3) + (Punctuality * 0.2) + (Total_Trips * 0.1)
 * Penalty: Subtract points for "Incidents" or "Unjustified Deviations"
 */

const { getSupabase } = require("../supabase");

const RATING_WEIGHTS = {
  CLIENT_RATING: 0.4,      // 0-5 stars from client
  ROUTE_ADHERENCE: 0.3,    // 0-100% how well courier stayed on route
  PUNCTUALITY: 0.2,        // 0-100% based on ETA accuracy
  TRIP_FREQUENCY: 0.1      // normalized 0-100 based on total trips
};

const MAX_SCORE = 100;
const INCIDENT_PENALTY = 5; // Points lost per incident

/**
 * Calculate route adherence percentage
 * Based on deviation from assigned corridor
 */
function calculateRouteAdherence(deviationMeters, corridorLengthKm = 10) {
  // Maximum acceptable deviation: 20% of corridor length
  const maxAcceptableDeviation = (corridorLengthKm * 1000) * 0.2;
  
  if (deviationMeters <= 0) return 100;
  if (deviationMeters >= maxAcceptableDeviation) return 0;
  
  // Linear scale: 0 deviation = 100%, max deviation = 0%
  const adherence = Math.max(0, 100 - (deviationMeters / maxAcceptableDeviation) * 100);
  return Math.round(adherence);
}

/**
 * Calculate punctuality score based on ETA accuracy
 * Perfect if within ±5 minutes of estimate
 */
function calculatePunctuality(estimatedMinutes, actualMinutes) {
  if (!estimatedMinutes || !actualMinutes) return 50; // Neutral if no data
  
  const deltaMins = Math.abs(estimatedMinutes - actualMinutes);
  const tolerance = 5; // ±5 minutes is acceptable
  
  if (deltaMins <= tolerance) return 100;
  if (deltaMins > 60) return 0;
  
  // Linear scale: 0 delta = 100%, 60+ delta = 0%
  const punctuality = Math.max(0, 100 - ((deltaMins - tolerance) / (60 - tolerance)) * 100);
  return Math.round(punctuality);
}

/**
 * Normalize trip count to 0-100 score
 * Based on industry benchmarks: 50+ trips = 100%
 */
function calculateTripFrequencyScore(totalTrips) {
  // 0 trips = 0%, 50+ trips = 100%
  const normalizedScore = Math.min(100, (totalTrips / 50) * 100);
  return Math.round(normalizedScore);
}

/**
 * Aggregate courier rating
 * @param {string} courierId
 * @returns {Promise<{score: number, breakdown: object, metadata: object}>}
 */
async function aggregateCourierRating(courierId) {
  try {
    const supabase = getSupabase();
    
    // Get all completed parcels with ratings for this courier
    const { data: parcels, error: parcelError } = await supabase
      .from("parcels")
      .select("rating_value,route_adherence_percent,punctuality_minutes_delta,client_eta_minutes,dropoff_verified_at")
      .eq("assigned_courier_id", courierId)
      .eq("rating_submitted", true)
      .not("rating_value", "is", null)
      .order("rated_at", { ascending: false })
      .limit(100);

    if (parcelError) {
      console.error("[RatingAgg] Error fetching parcels:", parcelError);
      return null;
    }

    if (!parcels || parcels.length === 0) {
      return {
        score: 0,
        breakdown: { clientRating: 0, routeAdherence: 0, punctuality: 0, tripFrequency: 0 },
        metadata: { totalRatings: 0, recentRatings: 0, incidentCount: 0 }
      };
    }

    // Calculate components
    let totalClientScore = 0;
    let totalAdherence = 0;
    let totalPunctuality = 0;
    let incidentCount = 0;

    parcels.forEach((parcel) => {
      // Client rating (1-5 stars)
      if (parcel.rating_value) {
        totalClientScore += (parcel.rating_value / 5) * 100; // Convert to 0-100
      }

      // Route adherence
      if (typeof parcel.route_adherence_percent === "number") {
        totalAdherence += parcel.route_adherence_percent;
      }

      // Punctuality
      if (typeof parcel.punctuality_minutes_delta === "number") {
        const punctuality = calculatePunctuality(parcel.client_eta_minutes, parcel.punctuality_minutes_delta);
        totalPunctuality += punctuality;
      }

      // Incident detection: ratings below 2 stars or deviation > 30 mins
      if ((parcel.rating_value && parcel.rating_value < 2) || 
          (parcel.punctuality_minutes_delta && parcel.punctuality_minutes_delta > 30)) {
        incidentCount++;
      }
    });

    const ratingCount = parcels.length;
    const recentRatingCount = parcels.slice(0, 20).length;

    // Calculate averages (0-100 scale)
    const avgClientRating = totalClientScore / ratingCount;
    const avgAdherence = totalAdherence / ratingCount;
    const avgPunctuality = totalPunctuality / ratingCount;
    const tripFrequencyScore = calculateTripFrequencyScore(ratingCount);

    // Get total trip count (including unrated)
    const { data: allParcels, error: allError } = await supabase
      .from("parcels")
      .select("id", { count: "exact" })
      .eq("assigned_courier_id", courierId)
      .eq("status", "COMPLETED");

    const totalTrips = allError ? ratingCount : (allParcels?.length || ratingCount);

    // Calculate weighted score
    let aggregatedScore = 
      (avgClientRating * RATING_WEIGHTS.CLIENT_RATING) +
      (avgAdherence * RATING_WEIGHTS.ROUTE_ADHERENCE) +
      (avgPunctuality * RATING_WEIGHTS.PUNCTUALITY) +
      (tripFrequencyScore * RATING_WEIGHTS.TRIP_FREQUENCY);

    // Apply incident penalty
    aggregatedScore = Math.max(0, aggregatedScore - (incidentCount * INCIDENT_PENALTY));
    aggregatedScore = Math.round(aggregatedScore);

    return {
      score: aggregatedScore,
      breakdown: {
        clientRating: Math.round(avgClientRating),
        routeAdherence: Math.round(avgAdherence),
        punctuality: Math.round(avgPunctuality),
        tripFrequency: Math.round(tripFrequencyScore)
      },
      metadata: {
        totalRatings: ratingCount,
        recentRatings: recentRatingCount,
        totalTrips: totalTrips,
        incidentCount: incidentCount,
        avgClientStars: Math.round((avgClientRating / 100) * 5 * 10) / 10, // Back to 1-5 scale
        lastUpdated: new Date().toISOString()
      }
    };
  } catch (error) {
    console.error("[RatingAgg] Error aggregating rating:", error.message);
    return null;
  }
}

/**
 * Submit rating for a completed parcel
 */
async function submitParcelRating(parcelId, courierId, clientStars, feedback, routeAdherence = null, punctualityDelta = null) {
  try {
    const supabase = getSupabase();

    // Validate inputs
    if (!parcelId || !courierId || !clientStars) {
      throw new Error("parcelId, courierId, and clientStars required");
    }

    if (clientStars < 1 || clientStars > 5) {
      throw new Error("clientStars must be 1-5");
    }

    // Update parcel with rating
    const { error: updateError } = await supabase
      .from("parcels")
      .update({
        rating_value: clientStars,
        rating_feedback: feedback || null,
        rating_submitted: true,
        rated_at: new Date().toISOString(),
        route_adherence_percent: routeAdherence,
        punctuality_minutes_delta: punctualityDelta
      })
      .eq("id", parcelId)
      .eq("assigned_courier_id", courierId);

    if (updateError) {
      throw updateError;
    }

    // Re-aggregate courier rating
    const newRating = await aggregateCourierRating(courierId);

    return {
      status: "ok",
      parcelId,
      rating: newRating
    };
  } catch (error) {
    console.error("[RatingAgg] Error submitting rating:", error.message);
    throw error;
  }
}

module.exports = {
  aggregateCourierRating,
  submitParcelRating,
  calculateRouteAdherence,
  calculatePunctuality,
  calculateTripFrequencyScore,
  RATING_WEIGHTS
};
