// ABOUTME: Shares canonical Funnelcake profile reads and eligibility answers.
// ABOUTME: Keeps server-owned decoration separate from publishable Kind 0 data.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

// A sparse/older response is not a permanent negative, but scrolling through
// unanswered authors must not request their full profile on every mount.
const _unknownEligibilityRetryDelay = Duration(minutes: 1);

/// Session-scoped REST read coordination shared by read/write profile handles.
/// It belongs to one Funnelcake environment and is replaced with its client.
class ProfileApiCache {
  /// Creates a read coordinator for the optional [client].
  ProfileApiCache({
    required FunnelcakeApiClient? client,
    DateTime Function()? now,
  }) : _client = client,
       _now = now ?? DateTime.now;

  final FunnelcakeApiClient? _client;
  final DateTime Function() _now;
  final _eligibility = <String, bool>{};
  final _unknownUntil = <String, DateTime>{};
  final _inFlight = <String, Future<UserProfileResult?>>{};

  /// Reuses a single/bulk response; fetches only if this session has no answer.
  Future<bool> isOgDiviner(String pubkey) async {
    final cached = _eligibility[pubkey];
    if (cached != null) return cached;
    final unknownUntil = _unknownUntil[pubkey];
    if (unknownUntil != null && _now().isBefore(unknownUntil)) return false;
    final result = await getProfile(pubkey);
    // Also throttle an unavailable client, which returns before _remember.
    if (result?.isOgDiviner == null) _remember(pubkey, result);
    return result?.isOgDiviner == true;
  }

  void _remember(String pubkey, UserProfileResult? result) {
    final eligible = result?.isOgDiviner;
    if (eligible == null) {
      _eligibility.remove(pubkey);
      _unknownUntil[pubkey] = _now().add(_unknownEligibilityRetryDelay);
    } else {
      _unknownUntil.remove(pubkey);
      _eligibility[pubkey] = eligible;
    }
  }

  /// Fetches a fresh profile response, sharing any already-running request.
  Future<UserProfileResult?> getProfile(String pubkey) async {
    final client = _client;
    if (client == null || !client.isAvailable) return null;
    final pending = _inFlight[pubkey];
    if (pending != null) return pending;
    final request = client.getUserProfile(pubkey).then((result) {
      _remember(pubkey, result);
      return result;
    });
    _inFlight[pubkey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[pubkey], request)) {
        _inFlight.remove(pubkey)?.ignore();
      }
    }
  }

  /// Fetches a bulk response and makes its pending rows available to lookups.
  Future<BulkProfilesResponse?> getBulkProfiles(List<String> pubkeys) async {
    final client = _client;
    if (client == null || !client.isAvailable) return null;
    final request = client.getBulkProfiles(pubkeys);
    final pending = <String, Future<UserProfileResult?>>{};
    for (final pubkey in pubkeys) {
      if (_inFlight.containsKey(pubkey)) continue;
      // Most rows have no individual waiter. Consume the derived error too.
      final result = request.then((response) => response.profiles[pubkey])
        ..ignore();
      pending[pubkey] = result;
      _inFlight[pubkey] = result;
    }
    try {
      final response = await request;
      for (final pubkey in pubkeys) {
        _remember(pubkey, response.profiles[pubkey]);
      }
      return response;
    } finally {
      for (final entry in pending.entries) {
        if (identical(_inFlight[entry.key], entry.value)) {
          _inFlight.remove(entry.key)?.ignore();
        }
      }
    }
  }
}
