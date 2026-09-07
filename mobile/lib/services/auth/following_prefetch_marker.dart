// ABOUTME: Tracks successful auth-time following prefetches separately from data.
// ABOUTME: Avoids fabricating an authoritative empty contact-list cache record.

import 'package:follow_repository/follow_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

String followingPrefetchMarkerKey(String pubkeyHex) =>
    'following_prefetch_complete_$pubkeyHex';

bool hasFollowingPrefetchMarker(SharedPreferences prefs, String pubkeyHex) =>
    prefs.getBool(followingPrefetchMarkerKey(pubkeyHex)) ?? false;

Future<void> markFollowingPrefetchComplete(
  SharedPreferences prefs,
  String pubkeyHex,
) => prefs.setBool(followingPrefetchMarkerKey(pubkeyHex), true);

Future<bool> prepareFollowingAuthRedirect(
  SharedPreferences prefs,
  String pubkeyHex,
  bool followingKnownEmpty,
) async {
  if (followingKnownEmpty) {
    await markFollowingPrefetchComplete(prefs, pubkeyHex);
  }
  return prefs.containsKey(FollowingCacheRecord.storageKey(pubkeyHex)) ||
      hasFollowingPrefetchMarker(prefs, pubkeyHex);
}
