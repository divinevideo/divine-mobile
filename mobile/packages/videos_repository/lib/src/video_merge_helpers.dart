/// Shared merge helpers for profile and Nostr enrichment code paths.
///
/// Keeps engagement parity with Funnelcake when relay/Nostr copies disagree
/// (#3384). Lives in `videos_repository` because both the package's author-feed
/// composition and the app-layer Nostr enrichment utility consume them — the
/// repository is the canonical owner of the merge policy.
library;

import 'dart:math' as math;

/// Merges raw video tags with primary-wins semantics on duplicate keys
/// (`{...secondary, ...primary}`), except `views` and distinct viewers: the
/// higher parsed non-negative count wins (#3384). Distinct viewers are read
/// from `unique_viewers` and `unique_views`, written back only as
/// `unique_viewers`. They are not summed across edits.
///
/// Used by profile relay/REST merge and by Nostr enrichment (#3384).
Map<String, String> mergeVideoRawTagsPrimaryWins(
  Map<String, String> primary,
  Map<String, String> secondary,
) {
  final merged = {...secondary, ...primary};
  final primaryViews = _parseNonNegativeIntTag(primary['views']);
  final secondaryViews = _parseNonNegativeIntTag(secondary['views']);
  if (primaryViews != null || secondaryViews != null) {
    merged['views'] = math
        .max(primaryViews ?? 0, secondaryViews ?? 0)
        .toString();
  }
  final uniqueViewers = _highestUniqueViewers(primary, secondary);
  if (uniqueViewers != null) {
    merged['unique_viewers'] = uniqueViewers.toString();
    merged.remove('unique_views');
  }
  return merged;
}

int? _highestUniqueViewers(
  Map<String, String> primary,
  Map<String, String> secondary,
) {
  int? highest;
  for (final raw in [
    primary['unique_viewers'],
    primary['unique_views'],
    secondary['unique_viewers'],
    secondary['unique_views'],
  ]) {
    final parsed = _parseNonNegativeIntTag(raw);
    if (parsed == null) continue;
    highest = highest == null ? parsed : math.max(highest, parsed);
  }
  return highest;
}

int? _parseNonNegativeIntTag(String? raw) {
  if (raw == null) return null;
  final n = raw.replaceAll(',', '').trim();
  if (n.isEmpty) return null;
  final asInt = int.tryParse(n);
  if (asInt != null) return asInt < 0 ? null : asInt;
  final asDouble = double.tryParse(n);
  if (asDouble == null) return null;
  final rounded = asDouble.round();
  return rounded < 0 ? null : rounded;
}

/// Higher of two nullable counters; null only when both are null (#3384).
int? mergeNullableEngagementMax(int? primary, int? secondary) {
  if (primary == null && secondary == null) return null;
  return math.max(primary ?? 0, secondary ?? 0);
}
