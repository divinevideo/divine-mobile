// ABOUTME: Riverpod-backed FeedRepository delegating to existing feed providers.
// ABOUTME: Resolves global feeds (For You/Popular/Classics/New) + static sources.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:rxdart/rxdart.dart';

/// Identifies one of the four global, keepAlive Riverpod feed providers that
/// [RiverpodFeedRepository] can resolve directly.
enum _GlobalFeed { forYou, popular, classicVines, newVideos }

/// A [FeedRepository] that delegates to the app's existing feed providers and
/// blocs instead of re-implementing pagination.
///
/// It owns the variants that are globally resolvable from a keepAlive [Ref]:
///
/// * the four home tabs ([ForYouViewSource], [PopularViewSource],
///   [ClassicVinesViewSource], [NewVideosViewSource]) — delegated to their
///   keepAlive feed providers, which already apply the block / platform
///   boundary filter in `build()`;
/// * the aggregated Explore feed ([ExploreViewSource]) — backed reactively by
///   `exploreTabVideosProvider`;
/// * hashtag feeds ([HashtagViewSource]) — a boundary-filtered snapshot built
///   from `HashtagService` + the Funnelcake REST interleave;
/// * static sources ([SingleVideoViewSource], [VideoListViewSource]) —
///   delegated to a [StaticFeedRepository].
///
/// Scoped, per-widget sources (profile feed and the liked / reposts / saved /
/// collabs sub-feeds, search, category, ...) are owned by their existing blocs.
/// Those surfaces wrap their bloc's stream in a [StreamFeedRepository] at the
/// call site rather than routing through this global repository, because the
/// underlying blocs are constructed per-widget with per-call dependencies and
/// are not reachable from a global [Ref]. Calling [watchView] with one of
/// those sources throws [UnsupportedError]. See issue #3383.
class RiverpodFeedRepository implements FeedRepository {
  RiverpodFeedRepository(this._ref);

  final Ref _ref;

  /// One replayable bridge per global feed, created lazily on first watch and
  /// disposed with the (keepAlive) provider.
  final Map<_GlobalFeed, _GlobalFeedBridge> _bridges = {};

  late final StaticFeedRepository _static = StaticFeedRepository(
    // Static snapshots bypass each feed provider's `build()` filter, so apply
    // the platform boundary here. Block / mute is enforced downstream by the
    // FullscreenFeedBloc's VideoHideFilter + the removedVideoIds bus.
    filter: (videos) =>
        videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
  );

  _GlobalFeed? _globalFeedFor(ViewSource source) => switch (source) {
    ForYouViewSource() => _GlobalFeed.forYou,
    PopularViewSource() => _GlobalFeed.popular,
    ClassicVinesViewSource() => _GlobalFeed.classicVines,
    NewVideosViewSource() => _GlobalFeed.newVideos,
    _ => null,
  };

  bool _isStatic(ViewSource source) =>
      source is SingleVideoViewSource || source is VideoListViewSource;

  /// Applies the standard feed boundary filter (platform support + shared
  /// VideoEventService policy)
  /// used by every feed surface.
  List<VideoEvent> _applyBoundaryFilter(List<VideoEvent> videos) {
    final videoEventService = _ref.read(videoEventServiceProvider);
    return videoEventService.filterVideoList(
      videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );
  }

  /// Live stream of the aggregated Explore tab feed.
  ///
  /// Backed by [exploreTabVideosProvider] (a `StateProvider`) so the open
  /// fullscreen route reflects later Explore updates without a widget-owned
  /// `StreamController`.
  Stream<List<VideoEvent>> _watchExplore() {
    final controller = StreamController<List<VideoEvent>>();
    final subscription = _ref.listen<List<VideoEvent>?>(
      exploreTabVideosProvider,
      (_, next) {
        if (controller.isClosed) return;
        controller.add(_applyBoundaryFilter(next ?? const []));
      },
      fireImmediately: true,
    );
    controller.onCancel = () {
      subscription.close();
      return controller.close();
    };
    return controller.stream;
  }

  /// One-shot snapshot of a hashtag feed.
  ///
  /// Combines the cached WebSocket hashtag bucket with the Funnelcake REST
  /// interleave, filtered at the boundary. A snapshot (not a live stream) is
  /// the right shape here because [HashtagService] is pulled imperatively and
  /// exposes no reactive stream; the removal bus still drops deleted / blocked
  /// videos from the open fullscreen route.
  Stream<List<VideoEvent>> _watchHashtag(String hashtag) {
    return Stream<List<VideoEvent>>.fromFuture(_loadHashtag(hashtag));
  }

  Future<List<VideoEvent>> _loadHashtag(String hashtag) async {
    final hashtagService = _ref.read(hashtagServiceProvider);
    final videosRepository = _ref.read(videosRepositoryProvider);

    final webSocketVideos = List<VideoEvent>.from(
      hashtagService.getVideosByHashtags([hashtag]),
    );

    List<VideoEvent> popular = const [];
    try {
      final result = await videosRepository.getHashtagFeedVideos(
        hashtag: hashtag,
      );
      if (result.succeeded) popular = result.videos;
    } on Exception {
      // Fall back to the WebSocket bucket only — matches the screen's
      // preserve-cached-on-failure behaviour.
    }

    final List<VideoEvent> combined;
    if (popular.isEmpty) {
      combined = webSocketVideos..sort(VideoEvent.compareByLoopsThenTime);
    } else {
      final knownIds = <String>{};
      for (final v in popular) {
        if (v.id.isNotEmpty) knownIds.add(v.id.toLowerCase());
        final vineId = v.vineId;
        if (vineId != null && vineId.isNotEmpty) {
          knownIds.add(vineId.toLowerCase());
        }
      }
      final extra = webSocketVideos.where((v) {
        final vineId = v.vineId;
        return !knownIds.contains(v.id.toLowerCase()) &&
            (vineId == null || !knownIds.contains(vineId.toLowerCase()));
      }).toList()..sort(VideoEvent.compareByLoopsThenTime);
      combined = [...popular, ...extra];
    }

    return _applyBoundaryFilter(combined);
  }

  _GlobalFeedBridge _bridge(_GlobalFeed feed) {
    return _bridges.putIfAbsent(feed, () {
      final bridge = _GlobalFeedBridge();
      void onState(AsyncValue<VideoFeedState> next) {
        // `value`, not `asData?.value`: a dependency-driven reload emits
        // AsyncLoading *carrying the previous value*, for which `asData` is
        // null. The tabs keep rendering tappable tiles through that window
        // (`hasValue && value != null` — see NewVideosTab.build), so dropping
        // it here left the bridge with no value at all. A tap landing in that
        // window created an unseeded BehaviorSubject, which replays nothing,
        // so the fullscreen feed sat on its loading placeholder until the
        // reload finished instead of showing the list the grid was already
        // showing. Matching the tabs' own predicate closes the window. #6949
        final feedState = next.value;
        if (feedState == null) return;
        bridge.update(
          videos: feedState.videos,
          hasMore: feedState.hasMoreContent,
        );
      }

      // Each feed provider has a distinct generated type, so the listen is
      // wired per-feed rather than through a shared provider-typed helper.
      final subscription = switch (feed) {
        _GlobalFeed.forYou => _ref.listen(
          forYouFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.popular => _ref.listen(
          popularVideosFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.classicVines => _ref.listen(
          classicVinesFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
        _GlobalFeed.newVideos => _ref.listen(
          newVideosFeedProvider,
          (_, next) => onState(next),
          fireImmediately: true,
        ),
      };
      _ref.onDispose(() {
        subscription.close();
        bridge.dispose();
      });
      return bridge;
    });
  }

  Future<void> _loadMoreFor(_GlobalFeed feed) => switch (feed) {
    _GlobalFeed.forYou => _ref.read(forYouFeedProvider.notifier).loadMore(),
    _GlobalFeed.popular =>
      _ref.read(popularVideosFeedProvider.notifier).loadMore(),
    _GlobalFeed.classicVines =>
      _ref.read(classicVinesFeedProvider.notifier).loadMore(),
    _GlobalFeed.newVideos =>
      _ref.read(newVideosFeedProvider.notifier).loadMore(),
  };

  @override
  Stream<List<VideoEvent>> watchView(ViewSource source) {
    if (_isStatic(source)) return _static.watchView(source);
    if (source is ExploreViewSource) return _watchExplore();
    if (source is HashtagViewSource) return _watchHashtag(source.hashtag);
    final feed = _globalFeedFor(source);
    if (feed != null) return _bridge(feed).videosStream;
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }

  @override
  Future<void> loadMore(ViewSource source) {
    if (_isStatic(source)) return _static.loadMore(source);
    // Explore + hashtag are non-paginating in the fullscreen surface.
    if (source is ExploreViewSource || source is HashtagViewSource) {
      return Future<void>.value();
    }
    final feed = _globalFeedFor(source);
    if (feed != null) return _loadMoreFor(feed);
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }

  @override
  Stream<bool> watchHasMore(ViewSource source) {
    if (_isStatic(source)) return _static.watchHasMore(source);
    if (source is ExploreViewSource || source is HashtagViewSource) {
      return Stream<bool>.value(false);
    }
    final feed = _globalFeedFor(source);
    if (feed != null) return _bridge(feed).hasMoreStream;
    throw UnsupportedError(
      'RiverpodFeedRepository cannot resolve $source globally; scoped sources '
      'must be wrapped in a StreamFeedRepository at the call site.',
    );
  }
}

/// Replayable bridge mirroring a single feed provider's latest state.
///
/// Uses [BehaviorSubject] so a fullscreen route that subscribes after the feed
/// has already loaded still receives the current list immediately.
class _GlobalFeedBridge {
  final BehaviorSubject<List<VideoEvent>> _videos =
      BehaviorSubject<List<VideoEvent>>();
  final BehaviorSubject<bool> _hasMore = BehaviorSubject<bool>();

  Stream<List<VideoEvent>> get videosStream => _videos.stream;

  Stream<bool> get hasMoreStream => _hasMore.stream;

  void update({required List<VideoEvent> videos, required bool hasMore}) {
    _videos.add(List<VideoEvent>.unmodifiable(videos));
    _hasMore.add(hasMore);
  }

  void dispose() {
    // close() fails only by throwing synchronously (during an addStream), so
    // each subject is guarded on its own and still closes if the other throws.
    runProviderDetached(
      Future.sync(_videos.close),
      'close global feed bridge videos stream',
      logName: 'RiverpodFeedRepository',
    );
    runProviderDetached(
      Future.sync(_hasMore.close),
      'close global feed bridge hasMore stream',
      logName: 'RiverpodFeedRepository',
    );
  }
}
