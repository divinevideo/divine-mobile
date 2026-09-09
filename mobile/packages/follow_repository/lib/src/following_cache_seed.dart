// ABOUTME: Seeds the following cache from timestamp-free bootstrap sources.
// ABOUTME: Prevents stale snapshots from displacing records written later.

import 'package:follow_repository/src/following_cache_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seeds the following cache from a source that carries no `created_at`.
///
/// Mirrors the repository's NIP-01 ordering for a timestamp-free source:
/// it may seed an absent record but never displaces one. The auth-time REST
/// prefetch is concurrent with the repository's own writes, and the prefetch
/// only starts when the record is absent, so any record present here was
/// written while the request was pending.
///
/// Empty lists are represented by the auth prefetch completion marker rather
/// than a cache record, because an empty timestamp-free snapshot is not an
/// authoritative contact list.
///
/// Returns whether the record was written.
Future<bool> seedFollowingCacheIfAbsent({
  required SharedPreferences prefs,
  required String pubkeyHex,
  required List<String> pubkeys,
}) async {
  if (pubkeys.isEmpty) return false;

  final key = FollowingCacheRecord.storageKey(pubkeyHex);
  if (prefs.containsKey(key)) return false;

  // SharedPreferences updates its local cache when setString is invoked. Keep
  // this call adjacent to containsKey so same-isolate writers cannot interleave.
  return prefs.setString(key, FollowingCacheRecord(pubkeys: pubkeys).encode());
}
