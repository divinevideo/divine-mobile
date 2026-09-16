// ABOUTME: Privacy-preserving lookup for server-computed OG Diviner eligibility.
// ABOUTME: Deduplicates requests in memory without persisting viewed accounts.

import 'package:keycast_flutter/keycast_flutter.dart';

class OgDivinerEligibilityService {
  OgDivinerEligibilityService({required KeycastOAuth keycast})
    : _keycast = keycast;

  final KeycastOAuth _keycast;
  final Map<String, bool> _eligibility = {};
  final Map<String, Future<bool>> _inFlight = {};

  Future<bool> isEligible(String pubkey) {
    final normalized = pubkey.trim().toLowerCase();
    if (normalized.isEmpty) return Future.value(false);

    final cached = _eligibility[normalized];
    if (cached != null) return Future.value(cached);

    return _inFlight.putIfAbsent(normalized, () async {
      try {
        final eligible = await _keycast.isOgDiviner(normalized);
        _eligibility[normalized] = eligible;
        return eligible;
      } finally {
        _inFlight.remove(normalized);
      }
    });
  }
}
