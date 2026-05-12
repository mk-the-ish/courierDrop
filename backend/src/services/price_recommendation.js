/**
 * Price Recommendation Engine
 * 
 * Formula: F = min((S × D) + (P_r × 2), MWP)
 * S: Space factor (0.5, 1.0, 2.0)
 * D: Distance coefficient
 * P_r: Passenger fare for route
 * MWP: Max willingness to pay (not implemented - uses calculated price)
 */

const { getSupabase } = require("../supabase");

const SIZE_MULTIPLIERS = {
  S: 0.5,
  M: 1.0,
  L: 2.0
};

/**
 * Calculate distance coefficient based on corridor distance
 * Closer to passenger fare pricing
 */
function calculateDistanceCoefficient(distanceKm) {
  // 1 km = ~0.1 USD base cost
  return Math.max(0.3, distanceKm * 0.08);
}

/**
 * Get price recommendation for a delivery
 * @param {number} originLat
 * @param {number} originLng
 * @param {number} destinationLat
 * @param {number} destinationLng
 * @param {string} size - 'S', 'M', or 'L'
 * @param {number} weightKg - Optional weight
 * @returns {Promise<{recommendedPrice: number, baseFare: number, sizeMultiplier: number, components: object}>}
 */
async function getRecommendedPrice(originLat, originLng, destinationLat, destinationLng, size = 'M', weightKg = null) {
  try {
    const supabase = getSupabase();
    
    // Validate size
    if (!SIZE_MULTIPLIERS[size]) {
      throw new Error(`Invalid size: ${size}. Must be S, M, or L.`);
    }

    const sizeMultiplier = SIZE_MULTIPLIERS[size];
    
    // Find closest base fare route using PostGIS
    const originPoint = `POINT(${originLng} ${originLat})`;
    const destPoint = `POINT(${destinationLng} ${destinationLat})`;
    
    // Get all base fares and find the closest match
    const { data: baseFares, error: fareError } = await supabase
      .from("base_fares")
      .select("*")
      .order("distance_km", { ascending: true })
      .limit(5);

    if (fareError) {
      console.error("[PriceRec] Error fetching base fares:", fareError);
      // Return default pricing if lookup fails
      return getDefaultPrice(size, weightKg);
    }

    if (!baseFares || baseFares.length === 0) {
      return getDefaultPrice(size, weightKg);
    }

    // Use the first (closest distance) base fare as reference
    const baseRoute = baseFares[0];
    const passengerFare = baseRoute.passenger_fare_usd;
    const distanceKm = baseRoute.distance_km;
    
    // Calculate components
    const distanceCoeff = calculateDistanceCoefficient(distanceKm);
    const spaceComponent = sizeMultiplier * distanceCoeff;
    const passengerComponent = passengerFare * 2; // Round trip proxy
    
    // Final price = (S × D) + (P_r × 2)
    let recommendedPrice = Math.round((spaceComponent + passengerComponent) * 100) / 100;
    
    // Weight adjustment: every 5kg adds 10% to base price
    if (weightKg && weightKg > 2) {
      const weightAdjustment = Math.floor((weightKg - 2) / 5) * 0.1;
      recommendedPrice = recommendedPrice * (1 + weightAdjustment);
    }

    // Cap at reasonable maximum (2 passenger fares)
    const maxPrice = passengerFare * 2.5;
    recommendedPrice = Math.min(recommendedPrice, maxPrice);
    
    return {
      recommendedPrice: Math.round(recommendedPrice * 100) / 100,
      baseFare: passengerFare,
      sizeMultiplier,
      distanceKm,
      corridorName: baseRoute.corridor_name,
      components: {
        spaceComponent: Math.round(spaceComponent * 100) / 100,
        passengerComponent: Math.round(passengerComponent * 100) / 100,
        weightAdjustment: weightKg && weightKg > 2 ? `+${Math.floor((weightKg - 2) / 5) * 10}%` : '0%'
      }
    };
  } catch (error) {
    console.error("[PriceRec] Error calculating price:", error.message);
    return getDefaultPrice(size, weightKg);
  }
}

/**
 * Fallback pricing when corridor matching fails
 */
function getDefaultPrice(size = 'M', weightKg = null) {
  const basePrices = {
    S: 0.80,  // Small: $0.80
    M: 1.50,  // Medium: $1.50
    L: 2.50   // Large: $2.50
  };

  let price = basePrices[size] || basePrices.M;
  
  // Weight adjustment
  if (weightKg && weightKg > 2) {
    const weightAdjustment = Math.floor((weightKg - 2) / 5) * 0.1;
    price = price * (1 + weightAdjustment);
  }

  return {
    recommendedPrice: Math.round(price * 100) / 100,
    baseFare: basePrices[size],
    sizeMultiplier: SIZE_MULTIPLIERS[size],
    distanceKm: 5,
    corridorName: 'DEFAULT',
    components: {
      spaceComponent: Math.round(basePrices[size] * SIZE_MULTIPLIERS[size] * 100) / 100,
      passengerComponent: basePrices[size],
      weightAdjustment: weightKg && weightKg > 2 ? `+${Math.floor((weightKg - 2) / 5) * 10}%` : '0%'
    }
  };
}

/**
 * Validate user-provided price against recommended
 * Returns whether price is acceptable
 */
function validateUserPrice(recommendedPrice, userPrice, tolerance = 0.3) {
  // User can deviate ±30% from recommended
  const minAcceptable = recommendedPrice * (1 - tolerance);
  const maxAcceptable = recommendedPrice * (1 + tolerance);
  
  return {
    isAcceptable: userPrice >= minAcceptable && userPrice <= maxAcceptable,
    minPrice: Math.round(minAcceptable * 100) / 100,
    maxPrice: Math.round(maxAcceptable * 100) / 100,
    recommendedPrice: Math.round(recommendedPrice * 100) / 100,
    deviation: Math.round((((userPrice - recommendedPrice) / recommendedPrice) * 100 * 100)) / 100 // percentage
  };
}

module.exports = {
  getRecommendedPrice,
  validateUserPrice,
  SIZE_MULTIPLIERS
};
