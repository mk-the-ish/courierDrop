/**
 * Vector progress: compare current distance to destination vs previous pulse.
 * Positive delta means courier moved closer (meters gained toward destination).
 */
function calculateVectorProgress(currentDistanceM, previousDistanceM) {
  if (
    typeof currentDistanceM !== "number" ||
    !Number.isFinite(currentDistanceM) ||
    typeof previousDistanceM !== "number" ||
    !Number.isFinite(previousDistanceM)
  ) {
    return null;
  }
  return previousDistanceM - currentDistanceM;
}

module.exports = {
  calculateVectorProgress
};
