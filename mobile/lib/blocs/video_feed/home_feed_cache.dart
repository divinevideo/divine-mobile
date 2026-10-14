// ABOUTME: Disk-backed cache for the home feed, enabling instant cold start.
// ABOUTME: Stores a forward window of videos starting just past the user's
// last-viewed position, account-scoped, via CacheSync.

import 'dart:convert';

import 'package:cache_sync/cache_sync.dart';
import 'package:models/models.dart';

/// Maximum age of a cached home feed before it is considered stale.
///
/// A stale window is still served on cold start; the age only marks when the
/// entry is due a refresh, which the feed always runs after serving it.
const homeFeedCacheMaxAge = Duration(hours: 6);

/// Upper bound on how many videos are persisted per mode.
///
/// The cached window only has to bridge the gap until the parallel fresh
/// load lands (a few seconds), so it is deliberately small. It also bounds
/// the per-swipe write cost.
const _forwardWindowSize = 30;

/// Reads and writes the cached home-feed videos for instant cold start.
///
/// The cache stores a **forward window**: the videos starting just past the
/// user's last-viewed position (already-watched videos are intentionally
/// dropped — the user resumes at the top of the window and cannot scroll back
/// to content they have seen). On cold start the window is served at index 0
/// while fresh data loads in parallel.
///
/// Entries are keyed by account pubkey and feed mode and persisted through
/// [CacheSync], so signing out clears them via the account-scoped
/// `CacheSync.invalidatePrefix(pubkey)` call in `AuthService`.
///
/// Every method degrades to a no-op (read → `null`, write → nothing) when
/// [CacheSync] has not been initialised, so widget tests that don't boot the
/// cache are unaffected.
class HomeFeedCache {
  /// Creates a [HomeFeedCache].
  const HomeFeedCache();

  String _accountPrefix(String? pubkey) =>
      (pubkey == null || pubkey.isEmpty) ? 'anon' : pubkey;

  String _videosKey(String? pubkey, String mode) =>
      '${_accountPrefix(pubkey)}:home_feed:$mode';

  /// Returns the cached forward window for [mode], or `null` when absent.
  ///
  /// An entry older than [homeFeedCacheMaxAge] is still returned: the feed
  /// always loads fresh videos right after serving this window and splices
  /// them in, so an old window beats a blank screen.
  Future<List<VideoEvent>?> readVideos({
    required String? pubkey,
    required String mode,
  }) async {
    try {
      final entry = await CacheSync.readEntry<List<VideoEvent>>(
        key: _videosKey(pubkey, mode),
        fromJson: _decodeVideos,
      );
      return entry?.data;
    } on Object {
      return null;
    }
  }

  /// Persists [videos] (capped to [_forwardWindowSize]) as the cached home
  /// feed for [mode].
  ///
  /// The caller passes the forward slice (videos from the resume position
  /// onward); this stores the first [_forwardWindowSize] of them.
  Future<void> writeVideos({
    required String? pubkey,
    required String mode,
    required List<VideoEvent> videos,
  }) async {
    if (videos.isEmpty) return;
    final capped = videos.length > _forwardWindowSize
        ? videos.sublist(0, _forwardWindowSize)
        : videos;
    try {
      await CacheSync.write<List<VideoEvent>>(
        key: _videosKey(pubkey, mode),
        value: capped,
        toJson: _encodeVideos,
        ttl: homeFeedCacheMaxAge,
      );
    } on Object {
      // Caching is best-effort; ignore persistence failures.
    }
  }

  /// Drops the cached forward window for [mode].
  ///
  /// Used when the resume window is empty (the user reached the end of the
  /// stored window): leaving the previous entry in place would re-serve
  /// already-seen videos on the next cold start, so the key is invalidated.
  Future<void> clearVideos({
    required String? pubkey,
    required String mode,
  }) async {
    try {
      await CacheSync.invalidate(_videosKey(pubkey, mode));
    } on Object {
      // Best-effort; ignore failures.
    }
  }

  static String _encodeVideos(List<VideoEvent> videos) =>
      jsonEncode({'videos': videos.map((v) => v.toJson()).toList()});

  static List<VideoEvent> _decodeVideos(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final raw = data['videos'] as List<dynamic>? ?? const [];
    return raw
        .map((v) => VideoEvent.fromJson(v as Map<String, dynamic>))
        .toList();
  }
}
