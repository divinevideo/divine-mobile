// ABOUTME: Resolves the Divine moderation labeler's pubkey via NIP-05
// ABOUTME: Caches the resolution and refuses any key this build lists as retired

import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Looks up the pubkey published at a NIP-05 address, returning `null` when
/// none is published or the lookup fails.
typedef Nip05PubkeyLookup = Future<String?> Function(String nip05Address);

/// Resolves and caches the Divine moderation labeler's pubkey.
///
/// Strategy: SharedPreferences cache (24h TTL) → NIP-05 → the pinned
/// [kModerationPubkeyHex]. A cached or NIP-05-resolved value that this build
/// lists as retired ([isRetiredModerationAccount]) is refused rather than
/// adopted — see [_refuseRetired] for why.
///
/// Extracted from `ModerationLabelService` (#7851) to keep that file under
/// the service-layer line ceiling. `ModerationLabelService` owns a private
/// instance and calls [resolve] / [cached] where it used to call the
/// now-moved private methods.
class ModerationPubkeyResolver {
  ModerationPubkeyResolver({Nip05PubkeyLookup? lookupPubkey})
    : _lookupPubkey = lookupPubkey ?? Nip05Validor.getPubkey;

  final Nip05PubkeyLookup _lookupPubkey;

  /// (pubkey, source) pairs already logged by [_refuseRetired] on this
  /// instance. `cached()` at load and `resolve()` at refresh both check the
  /// same cached value under the same source string, so without this a
  /// refused cached key logs twice, milliseconds apart, for one fact.
  final Set<(String, String)> _loggedRefusals = {};

  /// SharedPreferences key for the NIP-05 resolved moderation pubkey.
  static const String _resolvedPubkeyKey = 'divine_moderation_resolved_pubkey';

  /// SharedPreferences key for when the moderation pubkey was last resolved.
  static const String _resolvedAtKey = 'divine_moderation_resolved_at';

  /// Cache TTL for NIP-05 resolved pubkey (24 hours).
  static const Duration _resolvedPubkeyTtl = Duration(hours: 24);

  /// Canonical form of a labeler identity: lowercase hex, no surrounding
  /// whitespace.
  ///
  /// NIP-05 mandates lowercase hex and event authors arrive lowercase on the
  /// wire, so canonicalizing at the point that produces an identity keeps the
  /// adopted pubkey, subscribed labelers and the pin comparison on one form.
  /// Without it a non-lowercase answer would read as identical to the pin yet
  /// fail to match the labeler's own events in the subscription filter.
  static String _normalizedPubkey(String pubkey) => pubkey.trim().toLowerCase();

  /// Whether [pubkey] is a key this build lists as retired, logging the
  /// refusal at most once per (pubkey, source) pair on this instance —
  /// `cached()` and `resolve()` both check the cache under the same source,
  /// and without the dedup that logs the identical fact twice. Adopting a
  /// retired key would aim labels and report DMs at an account nobody reads,
  /// and after a compromise at one someone else controls.
  bool _refuseRetired(String pubkey, {required String source}) {
    if (!isRetiredModerationAccount(pubkey)) return false;
    if (_loggedRefusals.add((pubkey, source))) {
      Log.warning(
        'Refusing moderation pubkey ${pubkeyForLogs(pubkey)} from $source: '
        'this build lists it as retired. Using the pinned key '
        '${pubkeyForLogs(kModerationPubkeyHex)} instead.',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
    return true;
  }

  /// Resolve the Divine moderation pubkey via cached value or NIP-05 lookup.
  ///
  /// Strategy: SharedPreferences cache (24h TTL) → NIP-05 → fallback constant.
  /// Every path returns a [_normalizedPubkey]. A cached or NIP-05-resolved
  /// value that this build lists as retired is refused via [_refuseRetired]
  /// rather than adopted — see its doc for why.
  Future<String> resolve(SharedPreferences prefs) async {
    // Check cached resolution
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    final usableCache =
        cachedPubkey.isNotEmpty &&
        !_refuseRetired(cachedPubkey, source: 'the cached NIP-05 answer');
    final cachedAtStr = prefs.getString(_resolvedAtKey);
    if (usableCache && cachedAtStr != null) {
      final cachedAt = DateTime.tryParse(cachedAtStr);
      if (cachedAt != null &&
          DateTime.now().difference(cachedAt) < _resolvedPubkeyTtl) {
        return cachedPubkey;
      }
    }

    // Resolve via NIP-05
    try {
      final resolved = await _lookupPubkey(kModerationNip05);
      final normalized = _normalizedPubkey(resolved ?? '');
      if (_refuseRetired(normalized, source: 'NIP-05')) {
        return kModerationPubkeyHex;
      }
      if (normalized.isNotEmpty) {
        await prefs.setString(_resolvedPubkeyKey, normalized);
        await prefs.setString(_resolvedAtKey, DateTime.now().toIso8601String());
        Log.info(
          'Resolved moderation pubkey via NIP-05: ${pubkeyForLogs(normalized)}',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return normalized;
      }
    } catch (e) {
      Log.warning(
        'NIP-05 resolution failed for $kModerationNip05: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }

    // Use stale cache if available, otherwise fallback
    if (usableCache) {
      return cachedPubkey;
    }
    return kModerationPubkeyHex;
  }

  /// The cached moderation pubkey, without querying NIP-05 or checking its
  /// freshness — for warm-start paths that must not touch the network.
  ///
  /// Returns the pinned [kModerationPubkeyHex] when nothing is cached, or
  /// when the cached value is a retired key ([_refuseRetired]).
  String cached(SharedPreferences prefs) {
    final cachedPubkey = _normalizedPubkey(
      prefs.getString(_resolvedPubkeyKey) ?? '',
    );
    if (cachedPubkey.isNotEmpty &&
        !_refuseRetired(cachedPubkey, source: 'the cached NIP-05 answer')) {
      return cachedPubkey;
    }
    return kModerationPubkeyHex;
  }
}
