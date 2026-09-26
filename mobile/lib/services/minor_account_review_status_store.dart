// ABOUTME: Persists whether each account has been found restricted for minor
// ABOUTME: review, so routing need not wait on the next fetch (#9495).

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether each account on this device has been found restricted for review.
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

  /// `true` once a fetch has found [pubkeyHex] restricted, `false` when every
  /// fetch found it active, or `null` when this device has never fetched a
  /// status for it.
  bool? lastKnownRestrictedFor(String? pubkeyHex) {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return null;
    return _prefs.getBool(storageKey(pubkeyHex));
  }

  /// Records [status] as fetched for [pubkeyHex].
  ///
  /// An `active` answer never clears a saved restriction: the server also
  /// answers `active` when it cannot check, which is no proof it was lifted.
  Future<void> remember(
    String? pubkeyHex,
    MinorAccountReviewStatus status,
  ) async {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return;
    final key = storageKey(pubkeyHex);
    final saved = _prefs.getBool(key);
    if (saved == true || saved == status.isRestricted) return;
    await _prefs.setBool(key, status.isRestricted);
  }
}
