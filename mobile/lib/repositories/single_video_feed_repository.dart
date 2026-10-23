// ABOUTME: Route-scoped feed that plays an opened video before discovery pages.
// ABOUTME: Keeps pagination and append order independent of the home feed.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:models/models.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

/// Loads a discovery page using its opaque cursor or legacy time boundary.
typedef DiscoveryPageLoader = Future<HomeFeedResult> Function({
  String? cursor,
  int? until,
});

/// A single-video route's independently paginated discovery feed.
///
/// The opened video is available synchronously. Recommendations append without
/// reordering existing items, and failures preserve playback and permit retry.
class SingleVideoFeedRepository implements FeedRepository {
  SingleVideoFeedRepository({
    required VideoEvent video,
    required DiscoveryPageLoader loadPage,
    List<VideoEvent> Function(List<VideoEvent>)? filter,
  }) : _video = video,
       _loadPage = loadPage,
       _filter = filter,
       _videos = BehaviorSubject.seeded([video]);

  static const _maxPagesPerLoad = 3;

  final VideoEvent _video;
  final DiscoveryPageLoader _loadPage;
  final List<VideoEvent> Function(List<VideoEvent>)? _filter;
  final BehaviorSubject<List<VideoEvent>> _videos;
  final BehaviorSubject<bool> _hasMore = BehaviorSubject.seeded(true);
  final List<VideoEvent> _recommendations = [];
  final Set<String> _cursors = {};
  String? _cursor;
  int? _until;
  bool _started = false;
  bool _loading = false;
  bool _disposed = false;

  void _validateSource(ViewSource source) {
    if (source is! SingleVideoViewSource || source.video.id != _video.id) {
      throw ArgumentError('This repository belongs to its opened video only.');
    }
  }

  @override
  Stream<List<VideoEvent>> watchView(ViewSource source) {
    _validateSource(source);
    if (!_started) {
      _started = true;
      unawaited(loadMore(source));
    }
    return _videos.stream;
  }

  @override
  Stream<bool> watchHasMore(ViewSource source) {
    _validateSource(source);
    return _hasMore.stream;
  }

  /// Reapplies current preferences without overriding filters for other videos
  /// when the viewer explicitly chose to show the opened video anyway.
  void refreshFilters() {
    if (_disposed) return;
    final filtered = _filter?.call(_recommendations) ?? _recommendations;
    _videos.add(List.unmodifiable([_video, ...filtered]));
  }

  @override
  Future<void> loadMore(ViewSource source) async {
    _validateSource(source);
    if (_disposed || _loading || !_hasMore.value) return;
    _started = true;
    _loading = true;
    try {
      final visibleBefore =
          (_filter?.call(_recommendations) ?? _recommendations).length;
      // A duplicate-only or filtered page provides no next item to swipe to.
      // Drain a bounded number of pages now instead of waiting for a page change.
      for (var page = 0; page < _maxPagesPerLoad; page++) {
        final result = await _loadPage(cursor: _cursor, until: _until);
        if (_disposed) return;

        final known = {
          _video.feedDedupKey,
          ..._recommendations.map((v) => v.feedDedupKey),
        };
        for (final video in result.videos) {
          if (video.videoUrl != null &&
              video.videoUrl!.isNotEmpty &&
              known.add(video.feedDedupKey)) {
            _recommendations.add(video);
          }
        }

        final cursor = result.paginationCursor;
        if (cursor != null && cursor.isNotEmpty) {
          _hasMore.add(result.hasMore != false && _cursors.add(cursor));
          _cursor = cursor;
          _until = null;
        } else if (result.hasMore == null && result.videos.isNotEmpty) {
          // Popular fallback has no cursor metadata. Derive its boundary from
          // the raw discovery page, never the potentially much older anchor.
          final oldest = result.videos
              .map((v) => v.createdAt)
              .reduce((a, b) => a < b ? a : b);
          _hasMore.add(_until == null || oldest < _until!);
          _until = oldest;
          _cursor = null;
        } else {
          _hasMore.add(false);
        }
        final visibleAfter =
            (_filter?.call(_recommendations) ?? _recommendations).length;
        if (!_hasMore.value || visibleAfter > visibleBefore) break;
      }
    } catch (error, stackTrace) {
      if (_disposed) return;
      Log.warning(
        'Could not load single-video discovery recommendations: $error',
        name: 'SingleVideoFeedRepository',
        category: LogCategory.video,
        stackTrace: stackTrace,
      );
    } finally {
      _loading = false;
      // Also clears the player's pagination spinner after a failed request.
      refreshFilters();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait([_videos.close(), _hasMore.close()]);
  }
}
