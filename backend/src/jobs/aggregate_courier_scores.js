const { getSupabase } = require("../supabase");

/**
 * Score = (Avg_Client_Stars * 0.4) + (Punctuality_Rate * 0.3) + (Route_Adherence_Rate * 0.3) - (Total_Incidents * 0.1)
 * Punctuality_Rate and Route_Adherence_Rate are on 0–1; stars on 1–5.
 */
async function aggregateCourierScores() {
  const supabase = getSupabase();
  if (!supabase) {
    return;
  }
  const { data: couriers, error: couriersError } = await supabase
    .from("users")
    .select("id")
    .in("role", ["courier", "COURIER"]);
  if (couriersError) {
    console.error("[CourierScore] couriers fetch failed:", couriersError.message);
    return;
  }
  const since = new Date(Date.now() - 120 * 24 * 60 * 60 * 1000).toISOString();

  for (const row of couriers || []) {
    const courierId = row.id;
    try {
      const { data: parcels } = await supabase
        .from("parcels")
        .select(
          "rating_value,rating_submitted,dropoff_verified_at,created_at,client_eta_minutes"
        )
        .eq("assigned_courier_id", courierId)
        .not("dropoff_verified_at", "is", null)
        .gte("created_at", since);

      const rated = (parcels || []).filter((p) => p.rating_submitted && p.rating_value);
      const avgStars =
        rated.length > 0
          ? rated.reduce((s, p) => s + Number(p.rating_value), 0) / rated.length
          : 3;

      let onTime = 0;
      let totalEta = 0;
      for (const p of parcels || []) {
        if (!p.dropoff_verified_at || !p.created_at) continue;
        totalEta += 1;
        const created = new Date(p.created_at).getTime();
        const done = new Date(p.dropoff_verified_at).getTime();
        const slackMin = Number(p.client_eta_minutes);
        const allowedMs = (Number.isFinite(slackMin) ? slackMin : 120) * 60 * 1000 + 15 * 60 * 1000;
        if (done <= created + allowedMs) {
          onTime += 1;
        }
      }
      const punctualityRate = totalEta > 0 ? onTime / totalEta : 0.5;

      const { count: incidentCount } = await supabase
        .from("route_deviation_events")
        .select("id", { count: "exact", head: true })
        .eq("courier_id", courierId)
        .gte("created_at", since);

      const incidents = incidentCount || 0;
      const adherenceRate = Math.max(0, 1 - Math.min(1, incidents / 25));

      const score =
        avgStars * 0.4 +
        punctualityRate * 0.3 +
        adherenceRate * 0.3 -
        incidents * 0.1;

      const clamped = Math.max(0, Math.min(5, score));
      await supabase
        .from("users")
        .update({
          courier_score: Math.round(clamped * 100) / 100,
          courier_score_updated_at: new Date().toISOString()
        })
        .eq("id", courierId);
    } catch (err) {
      console.error(`[CourierScore] courier ${courierId}:`, err.message);
    }
  }
  console.log("[CourierScore] aggregation finished");
}

module.exports = {
  aggregateCourierScores
};
