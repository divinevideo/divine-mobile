// ABOUTME: CacheSync I/O for the profile Videos tab's offset snapshot.
// ABOUTME: Best-effort read/write — a cache failure must never break a load or
// ABOUTME: block an emit (stale-while-revalidate, #5279 extended to Videos).

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_shared/profile_video_offset_snapshot.dart';
import 'package:unified_logger/unified_logger.dart';

/// Reads and writes the persisted Videos-tab window for one author via
/// [CacheSync].
class ProfileVideoSnapshotCache {
  ProfileVideoSnapshotCache(this._authorPubkey);

  final String _authorPubkey;

  /// Scoped to the author: the persisted videos are the unfiltered public feed
  /// (blocklist/content filters are re-applied on every emit, so the payload is
  /// viewer-independent). Follows the `${pubkey}:${operation}` convention so
  /// sign-out's `invalidatePrefix(currentPubkey)` clears the signed-out user's
  /// own-profile entry.
  String get _key => '$_authorPubkey:profile_videos';

  /// Reads the persisted snapshot once; `null` on miss or failure (a cache
  /// problem must never break an otherwise-fine cold load).
  Future<ProfileVideoOffsetSnapshot?> read() async {
    try {
      return await CacheSync.read<ProfileVideoOffsetSnapshot>(
        key: _key,
        fromJson: ProfileVideoOffsetSnapshot.fromJson,
      );
    } on Object catch (error) {
      Log.warning(
        'Failed to read cached profile-videos snapshot - $error',
        name: 'ProfileVideoSnapshotCache',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Persists the current source window + cursor (capped to
  /// [ProfileSnapshotWindow]) so a reopen restores it.
  ///
  /// Fire-and-forget: cache writes are best-effort and must never block or fail
  /// an emit. Capping bounds the serialized payload.
  void write({
    required List<VideoEvent> videos,
    required int? nextOffset,
    required int? totalVideoCount,
    required bool hasMoreContent,
  }) => writeSnapshot(
    ProfileVideoOffsetSnapshot.capped(
      videos: videos,
      nextOffset: nextOffset,
      totalVideoCount: totalVideoCount,
      hasMoreContent: hasMoreContent,
    ),
  );

  /// Persists a pre-built snapshot. Used when callers coalesce writes and keep
  /// the latest capped payload outside this helper.
  void writeSnapshot(ProfileVideoOffsetSnapshot snapshot) {
    unawaited(
      CacheSync.write<ProfileVideoOffsetSnapshot>(
        key: _key,
        value: snapshot,
        toJson: (s) => s.toJson(),
      ).catchError((Object error) {
        Log.warning(
          'Failed to persist profile-videos snapshot - $error',
          name: 'ProfileVideoSnapshotCache',
          category: LogCategory.video,
        );
      }),
    );
  }
}
