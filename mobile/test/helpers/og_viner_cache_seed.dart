// ABOUTME: Builds the stored value that marks pubkeys as OG Viners in tests.
// ABOUTME: Matches OgVinerCacheService's shape: {pubkey: last-seen UTC day}.

import 'dart:convert';

/// The `og_viner_pubkeys_v2` preference value that badges [pubkeys] as seen
/// today.
String ogVinerCacheValue(Iterable<String> pubkeys) {
  final today =
      DateTime.now().toUtc().millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return jsonEncode({for (final pubkey in pubkeys) pubkey: today});
}
