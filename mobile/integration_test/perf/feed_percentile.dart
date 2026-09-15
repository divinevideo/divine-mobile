// ABOUTME: Nearest-rank percentile shared by the feed perf measurements so
// ABOUTME: every p90 in the feed reports means the same observation.

/// Returns the nearest-rank percentile of [values].
///
/// The rank is `ceil(percentile/100 * n)`, so the p90 of ten samples is the
/// ninth smallest and the p90 of 318 samples is the 287th. The feed frame
/// windows and the TTFF budget both report through this function, which is
/// what keeps their `p90` labels comparable.
///
/// [percentile] must be in 1..100, [values] must not be empty, and the input
/// order does not matter: the list is copied before sorting.
T feedPercentile<T extends Comparable<Object>>(List<T> values, int percentile) {
  if (percentile < 1 || percentile > 100) {
    throw RangeError.range(percentile, 1, 100, 'percentile');
  }
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'must not be empty');
  }
  final sorted = [...values]..sort();
  final rank = (percentile * sorted.length + 99) ~/ 100;
  return sorted[rank - 1];
}
