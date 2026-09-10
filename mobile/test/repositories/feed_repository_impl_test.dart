// ABOUTME: Tests for RiverpodFeedRepository source resolution and replay.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/state/video_feed_state.dart';

VideoEvent _video(String id, {String pubkey = 'author'}) => VideoEvent(
  id: id,
  pubkey: pubkey,
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
  videoUrl: 'https://media.divine.video/$id.mp4',
);

/// Stands in for the version providers the real feed watches
/// (`contentFilterVersionProvider`, `divineHostFilterVersionProvider`,
/// `blocklistVersionProvider`, `appReadyProvider`). Bumping it puts the feed
/// through a genuine dependency-driven reload rather than a hand-built
/// `AsyncValue`.
final _reloadTrigger = StateProvider<int>((ref) => 0);

/// Set to block the next `build()`, so the provider stays in the loading
/// phase of a reload while the test subscribes.
Completer<VideoFeedState>? _pendingBuild;

class _TestNewVideosFeed extends NewVideosFeed {
  @override
  Future<VideoFeedState> build() async {
    ref.watch(_reloadTrigger);
    final pending = _pendingBuild;
    if (pending != null) return pending.future;
    return const VideoFeedState(videos: [], hasMoreContent: true);
  }

  void emit(List<VideoEvent> videos, {required bool hasMore}) {
    state = AsyncValue.data(
      VideoFeedState(videos: videos, hasMoreContent: hasMore),
    );
  }
}

void main() {
  group('RiverpodFeedRepository', () {
    late ProviderContainer container;
    late FeedRepository repository;

    setUp(() {
      container = ProviderContainer();
      repository = container.read(feedRepositoryProvider);
    });

    tearDown(() => container.dispose());

    test('resolves SingleVideoViewSource to the single video', () {
      final source = SingleVideoViewSource(_video('1'));

      expect(
        repository.watchView(source),
        emits(isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1')),
      );
    });

    test('resolves VideoListViewSource to the provided list', () {
      final source = VideoListViewSource([_video('1'), _video('2')]);

      expect(
        repository.watchView(source),
        emits(isA<List<VideoEvent>>().having((l) => l.length, 'length', 2)),
      );
    });

    test('static sources never paginate', () async {
      final source = VideoListViewSource([_video('1')]);

      expect(repository.watchHasMore(source), emits(false));
      await expectLater(repository.loadMore(source), completes);
    });

    test(
      'global feed bridge replays latest state and re-emits updates',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            newVideosFeedProvider.overrideWith(_TestNewVideosFeed.new),
          ],
        );
        repository = container.read(feedRepositoryProvider);

        final feed = container.read(
          newVideosFeedProvider.notifier,
        ) as _TestNewVideosFeed;
        await container.read(newVideosFeedProvider.future);
        feed.emit([_video('1')], hasMore: true);

        final videosExpectation = expectLater(
          repository.watchView(const NewVideosViewSource()),
          emitsInOrder([
            isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1'),
            isA<List<VideoEvent>>().having((l) => l.last.id, 'last id', '2'),
          ]),
        );
        await expectLater(
          repository.watchHasMore(const NewVideosViewSource()),
          emits(true),
        );

        feed.emit([_video('1'), _video('2')], hasMore: false);
        await videosExpectation;
      },
    );

    // #6949. The bridge is created lazily on the first watchView, i.e. the
    // moment the user taps a grid tile. If that tap lands while the feed
    // provider is reloading, `asData` is null even though the grid is still
    // rendering the previous list from `value` — the bridge would then hold
    // no value, its BehaviorSubject would replay nothing, and the fullscreen
    // feed would sit on its loading placeholder instead of the list the user
    // just tapped in.
    test(
      'global feed bridge replays the previous list when the feed is '
      'reloading at subscribe time',
      () async {
        container.dispose();
        container = ProviderContainer(
          overrides: [
            newVideosFeedProvider.overrideWith(_TestNewVideosFeed.new),
          ],
        );
        repository = container.read(feedRepositoryProvider);

        final feed = container.read(
          newVideosFeedProvider.notifier,
        ) as _TestNewVideosFeed;
        await container.read(newVideosFeedProvider.future);
        feed.emit([_video('1')], hasMore: true);

        // Block the rebuild, then bump a watched dependency. Riverpod does
        // `onLoading(AsyncLoading(), seamless: !ref.isReload)`
        // (riverpod/src/core/element.dart:51) and `isReload` is true exactly
        // when a watched dependency changed, so this lands on the
        // non-seamless form: an AsyncLoading that still carries the value.
        _pendingBuild = Completer<VideoFeedState>();
        addTearDown(() => _pendingBuild = null);
        container.read(_reloadTrigger.notifier).state++;

        // Sanity: this is the state that used to be dropped — a reload that
        // still carries the value the grid is rendering.
        final reloading = container.read(newVideosFeedProvider);
        expect(reloading.isLoading, isTrue);
        expect(reloading.asData, isNull);
        expect(reloading.value?.videos.single.id, '1');

        await expectLater(
          repository.watchView(const NewVideosViewSource()),
          emits(isA<List<VideoEvent>>().having((l) => l.single.id, 'id', '1')),
        );
      },
    );

    test('throws for scoped sources that are not globally resolvable', () {
      expect(
        () => repository.watchView(const ProfileViewSource('x')),
        throwsUnsupportedError,
      );
      expect(
        () => repository.watchView(const SearchViewSource('cats')),
        throwsUnsupportedError,
      );
      expect(
        () => repository.watchView(const CategoryViewSource('animals')),
        throwsUnsupportedError,
      );
    });
  });
}
