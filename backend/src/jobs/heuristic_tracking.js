const { runHeuristicTrackingSweep } = require("../services/heuristic_tracking");

async function runHeuristicTrackingJob() {
  try {
    const result = await runHeuristicTrackingSweep();
    console.log(`[HeuristicTracking] sweep complete: processed=${result.processed}`);
  } catch (error) {
    console.error("[HeuristicTracking] sweep failed:", error.message);
    throw error;
  }
}

module.exports = {
  runHeuristicTrackingJob
};
