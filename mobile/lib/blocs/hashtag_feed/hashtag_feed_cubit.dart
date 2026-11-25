// ABOUTME: Loads ranked hashtag pages for both the grid and fullscreen reel.
// ABOUTME: Keeps the server cursor even when local filters shrink a page.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:rxdart/rxdart.dart';
import 'package:videos_repository/videos_repository.dart';

typedef HashtagFeedState = ({
  List<VideoEvent> videos,
  String? nextCursor,
  bool isLoading,
  bool failed,
});

class HashtagFeedCubit extends Cubit<HashtagFeedState> {
  HashtagFeedCubit({
    required Future<HashtagFeedVideosResult> Function(String?) fetchPage,
    required List<VideoEvent> Function(List<VideoEvent>) filterVideos,
  }) : _fetchPage = fetchPage,
       _filterVideos = filterVideos,
       super((
         videos: const [],
         nextCursor: null,
         isLoading: true,
         failed: false,
       ));

  // A request can encounter pages made entirely of hidden or duplicate
  // videos. Follow the cursor a few times without an unbounded network loop.
  static const _maxPagesPerLoad = 3;

  final Future<HashtagFeedVideosResult> Function(String?) _fetchPage;
  final List<VideoEvent> Function(List<VideoEvent>) _filterVideos;
  int _request = 0;

  /// Emits the reel without reordering it, so a new page never lands ahead of
  /// the video being watched. A refresh can return fewer pages than the reel
  /// holds; videos it no longer returns stay unless the filters now hide them.
  Stream<List<VideoEvent>> watchPlaybackVideos({
    required List<VideoEvent> initialVideos,
    required List<VideoEvent> Function(List<VideoEvent>) visibleVideos,
  }) => Rx.defer(() {
    var playback = initialVideos;

    List<VideoEvent> appendNewVideos(HashtagFeedState state) {
      final latest = {
        for (final video in visibleVideos(state.videos))
          _playbackKey(video): video,
      };
      final missing = [
        for (final video in playback)
          if (!latest.containsKey(_playbackKey(video))) video,
      ];
      final allowed = {
        for (final video in _filterVideos(missing)) _playbackKey(video): video,
      };
      return playback = [
        for (final video in playback)
          if (latest.remove(_playbackKey(video)) ?? allowed[_playbackKey(video)]
              case final VideoEvent kept)
            kept,
        ...latest.values,
      ];
    }

    return stream
        .where((state) => !state.isLoading)
        .map(appendNewVideos)
        .startWith(appendNewVideos(state));
  });

  String _playbackKey(VideoEvent video) =>
      video.vineId?.toLowerCase() ?? video.feedDedupKey;

  Future<void> refresh() => _load(replace: true);

  Future<void> loadMore() async {
    if (state.isLoading || state.nextCursor == null) return;
    await _load(replace: false);
  }

  Future<void> _load({required bool replace}) async {
    final request = ++_request;
    final previous = state;
    emit((
      videos: previous.videos,
      nextCursor: previous.nextCursor,
      isLoading: true,
      failed: false,
    ));

    var cursor = replace ? null : previous.nextCursor;
    var videos = replace ? const <VideoEvent>[] : previous.videos;
    final seenCursors = <String?>{cursor};
    var succeeded = false;
    var failed = false;
    try {
      final visibleIds = _filterVideos(videos)
          .map((v) => v.feedDedupKey)
          .toSet();
      for (var page = 0; page < _maxPagesPerLoad; page++) {
        final result = await _fetchPage(cursor);
        if (isClosed || request != _request) return;
        if (!result.succeeded) {
          failed = true;
          break;
        }
        succeeded = true;
        videos = _appendUnique(videos, result.videos);
        cursor = result.nextCursor;
        if (cursor == null || !seenCursors.add(cursor)) {
          cursor = null;
          break;
        }
        if (_filterVideos(videos).any(
          (video) => !visibleIds.contains(video.feedDedupKey),
        )) {
          break;
        }
      }
    } catch (error, stackTrace) {
      failed = true;
      if (replace) rethrow;
      addError(error, stackTrace);
    } finally {
      if (!isClosed && request == _request) {
        emit((
          videos: succeeded ? videos : previous.videos,
          nextCursor: succeeded ? cursor : previous.nextCursor,
          isLoading: false,
          failed: failed,
        ));
      }
    }
  }

  List<VideoEvent> _appendUnique(
    List<VideoEvent> previous,
    List<VideoEvent> page,
  ) {
    final keys = previous.map((video) => video.feedDedupKey).toSet();
    final vineIds = previous
        .map((video) => video.vineId?.toLowerCase())
        .toSet();
    final videos = [...previous];
    for (final video in page) {
      final vineId = video.vineId?.toLowerCase();
      if (keys.contains(video.feedDedupKey) ||
          (vineId != null && vineIds.contains(vineId))) {
        continue;
      }
      keys.add(video.feedDedupKey);
      if (vineId != null) vineIds.add(vineId);
      videos.add(video);
    }
    return List.unmodifiable(videos);
  }
}
