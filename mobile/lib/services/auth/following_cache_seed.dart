// ABOUTME: Seeds the synchronous following cache for newly created accounts.
// ABOUTME: Lets authentication route without a network prefetch for new keys.

import 'package:follow_repository/follow_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records that a newly created account is known to follow nobody.
Future<void> seedEmptyFollowingCache(String pubkeyHex) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    FollowingCacheRecord.storageKey(pubkeyHex),
    FollowingCacheRecord(pubkeys: const []).encode(),
  );
}
