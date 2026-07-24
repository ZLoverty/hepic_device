// Rolling-window force evaluation — mirrors HEPiC's quality_check/evaluator.py
// (evaluate_force_window): last 200 samples, minimum 10 before reporting.
export const FORCE_WINDOW_SIZE = 200;
export const FORCE_WINDOW_MIN  = 10;

/** @param {number[]} samples @returns {{mean: number, std: number} | null} */
export function evaluateForceWindow(samples) {
  const pts = samples.filter(v => v !== null && isFinite(v)).slice(-FORCE_WINDOW_SIZE);
  if (pts.length < FORCE_WINDOW_MIN) return null;
  const mean     = pts.reduce((a, b) => a + b, 0) / pts.length;
  const variance = pts.reduce((s, v) => s + (v - mean) ** 2, 0) / pts.length;
  return { mean, std: Math.sqrt(variance) };
}
