// ABOUTME: Persists whether each account's own review-status fetch last found
// ABOUTME: a restriction, so routing need not wait on the next fetch (#9495).

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known minor-account review restriction per account on this device.
///
/// Kept in SharedPreferences rather than `cache_sync` because the router
/// redirect reads it synchronously on every navigation and `CacheSync.read`
/// is async. It is only a routing hint; a settled fetch always wins.
class MinorAccountReviewStatusStore {
  MinorAccountReviewStatusStore({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  /// The preference holding [pubkeyHex]'s status, removed with the account's
  /// data.
  static String storageKey(String pubkeyHex) =>
      'minor_account_review_restricted_$pubkeyHex';

  /// Whether [pubkeyHex]'s last fetch found a restriction, or `null` when this
  /// device has never fetched a status for it.
  bool? lastKnownRestrictedFor(String? pubkeyHex) {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return null;
    return _prefs.getBool(storageKey(pubkeyHex));
  }

  /// Records [status] as the last one fetched for [pubkeyHex].
  Future<void> remember(
    String? pubkeyHex,
    MinorAccountReviewStatus status,
  ) async {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return;
    final key = storageKey(pubkeyHex);
    if (_prefs.getBool(key) == status.isRestricted) return;
    await _prefs.setBool(key, status.isRestricted);
  }
}
