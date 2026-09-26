// ABOUTME: Persists whether each account's own review-status fetch last found
// ABOUTME: a restriction, so routing need not wait on the next fetch (#9495).

import 'package:openvine/models/minor_account_review_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-known minor-account review restriction per account on this device.
class MinorAccountReviewStatusStore {
  MinorAccountReviewStatusStore({required SharedPreferences prefs})
    : _prefs = prefs;

  final SharedPreferences _prefs;

  static String _key(String pubkeyHex) =>
      'minor_account_review_restricted_$pubkeyHex';

  /// Whether [pubkeyHex]'s last fetch found a restriction, or `null` when this
  /// device has never fetched a status for it.
  bool? lastKnownRestrictedFor(String? pubkeyHex) {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return null;
    return _prefs.getBool(_key(pubkeyHex));
  }

  /// Records [status] as the last one fetched for [pubkeyHex].
  Future<void> remember(
    String? pubkeyHex,
    MinorAccountReviewStatus status,
  ) async {
    if (pubkeyHex == null || pubkeyHex.isEmpty) return;
    final key = _key(pubkeyHex);
    if (_prefs.getBool(key) == status.isRestricted) return;
    await _prefs.setBool(key, status.isRestricted);
  }
}
