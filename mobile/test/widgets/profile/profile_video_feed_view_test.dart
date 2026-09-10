import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/profile/profile_video_feed_view.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _FakeSystemVolumeListener implements SystemVolumeListener {
  @override
  void hideSystemUI() {}

  @override
  StreamSubscription<double> listen(void Function(double volume) onData) {
    return const Stream<double>.empty().listen(onData);
  }
}

class _FakeVideoEvent extends Fake implements VideoEvent {}

/// In-memory [CacheDao] so the [ProfileFeedCubit]'s [CacheSync] reads/writes
/// are isolated per test. Without it, the shared global [CacheSync] (which
/// other test files initialize) leaks one test's persisted snapshot into the
/// next under the same author key — only visible under `very_good test
/// --optimization`, which runs every test file in a single isolate.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

const _profilePubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video(String id, {required int createdAt, String? stableId}) {
  return VideoEvent(
    id: id,
    pubkey: _profilePubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    title: 'Video $id',
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: stableId == null ? const {} : {'d': stableId},
  );
}

void main() {
  group(ProfileVideoFeedView, () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUpAll(() {
      registerFallbackValue(_FakeVideoEvent());
    });

    setUp(() async {
      // Fresh per-test cache so the ProfileFeedCubit's snapshot persistence
      // can't leak across tests in the shared --optimization isolate.
      await CacheSync.init(dao: _InMemoryCacheDao());

      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(
        () => videoEventService.authorVideos(any()),
      ).thenReturn(const <VideoEvent>[]);
      when(
        () => videoEventService.filterVideoList(any()),
      ).thenAnswer((i) => i.positionalArguments.first as List<VideoEvent>);
      when(() => videoEventService.shouldHideVideo(any())).thenReturn(false);
      when(
        () => videoEventService.isVideoEventKnownDeleted(any()),
      ).thenReturn(false);
      when(
        () => videoEventService.subscribeToUserVideos(any()),
      ).thenAnswer((_) async {});
      when(() => videoEventService.addListener(any())).thenReturn(null);
      when(() => videoEventService.removeListener(any())).thenReturn(null);
      when(
        () => videoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(
        () => videoEventService.removedVideoIds,
      ).thenAnswer((_) => const Stream<String>.empty());
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => blocklistRepository.currentState,
      ).thenReturn(ContentPolicyState.empty());
    });

    Future<FullscreenFeedBloc> pumpProfileVideoFeed(
      WidgetTester tester, {
      required List<VideoEvent> seedVideos,
      required int videoIndex,
      required String? initialVideoId,
      required String? initialStableId,
    }) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider(
              create: (_) => VideoVolumeCubit(
                sharedPreferences: createMockSharedPreferences(),
                systemVolumeListener: _FakeSystemVolumeListener(),
              ),
              child: ProfileVideoFeedView(
                npub: 'npub1profile',
                userIdHex: _profilePubkey,
                videoIndex: videoIndex,
                videos: seedVideos,
                initialVideoId: initialVideoId,
                initialStableId: initialStableId,
                contextTitleOverride: 'Profile',
                onPageChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });

      final contentContext = tester.element(find.byType(FullscreenFeedContent));
      return contentContext.read<FullscreenFeedBloc>();
    }

    testWidgets(
      'seeds fullscreen with the tapped video before live profile videos load',
      (tester) async {
        const targetStableId = 'stable-target';
        final newest = _video('newest-video', createdAt: 3000);
        final target = _video(
          'target-video',
          createdAt: 2000,
          stableId: targetStableId,
        );
        final oldest = _video('oldest-video', createdAt: 1000);
        final seedVideos = [newest, target, oldest];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => const AuthorFeedResult(
            authorPubkey: _profilePubkey,
            hasMore: false,
          ),
        );

        final fullscreenBloc = await pumpProfileVideoFeed(
          tester,
          seedVideos: seedVideos,
          videoIndex: 0,
          initialVideoId: target.id,
          initialStableId: targetStableId,
        );

        expect(fullscreenBloc.state.status, FullscreenFeedStatus.ready);
        expect(fullscreenBloc.state.videos, seedVideos);
        expect(fullscreenBloc.state.currentIndex, 1);
        expect(fullscreenBloc.state.currentVideo?.id, target.id);
      },
    );

    testWidgets(
      'keeps the tapped seed video when the live profile page is shorter',
      (tester) async {
        const targetStableId = 'stable-target';
        final seedVideos = [
          _video('seed-0', createdAt: 6000),
          _video('seed-1', createdAt: 5000),
          _video('seed-2', createdAt: 4000),
          _video('seed-3', createdAt: 3000),
          _video('target-video', createdAt: 2000, stableId: targetStableId),
          _video('seed-5', createdAt: 1000),
        ];
        final liveFirstPage = [
          _video('live-0', createdAt: 8000),
          _video('live-1', createdAt: 7000),
        ];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => AuthorFeedResult(
            authorPubkey: _profilePubkey,
            videos: liveFirstPage,
            hasMore: true,
            nextOffset: liveFirstPage.length,
          ),
        );

        final fullscreenBloc = await pumpProfileVideoFeed(
          tester,
          seedVideos: seedVideos,
          videoIndex: 4,
          initialVideoId: 'target-video',
          initialStableId: targetStableId,
        );

        expect(fullscreenBloc.state.status, FullscreenFeedStatus.ready);
        expect(fullscreenBloc.state.videos, containsAll(seedVideos));
        expect(fullscreenBloc.state.videos, containsAll(liveFirstPage));
        expect(fullscreenBloc.state.currentVideo?.id, 'target-video');
      },
    );

    testWidgets(
      'switches back to the live profile page once load-more finds the target',
      (tester) async {
        const targetStableId = 'stable-target';
        final seedOnly = _video('seed-only', createdAt: 1000);
        final seedVideos = [
          _video('seed-0', createdAt: 6000),
          _video('seed-1', createdAt: 5000),
          _video('target-video', createdAt: 2000, stableId: targetStableId),
          seedOnly,
        ];
        final liveFirstPage = List.generate(
          50,
          (index) => _video('live-$index', createdAt: 8000 - index),
        );
        final liveSecondPage = [
          _video('target-video', createdAt: 2000, stableId: targetStableId),
        ];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => AuthorFeedResult(
            authorPubkey: _profilePubkey,
            videos: liveFirstPage,
            hasMore: true,
            nextOffset: liveFirstPage.length,
          ),
        );
        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: liveFirstPage.length,
          ),
        ).thenAnswer(
          (_) async => AuthorFeedResult(
            authorPubkey: _profilePubkey,
            videos: liveSecondPage,
            hasMore: false,
          ),
        );

        final fullscreenBloc = await pumpProfileVideoFeed(
          tester,
          seedVideos: seedVideos,
          videoIndex: 2,
          initialVideoId: 'target-video',
          initialStableId: targetStableId,
        );

        expect(fullscreenBloc.state.videos, contains(seedOnly));
        expect(fullscreenBloc.state.currentVideo?.id, 'target-video');

        fullscreenBloc.add(const FullscreenFeedLoadMoreRequested());
        await tester.runAsync(() async {
          await Future<void>.delayed(Duration.zero);
        });

        expect(fullscreenBloc.state.videos, containsAll(liveFirstPage));
        expect(fullscreenBloc.state.videos, containsAll(liveSecondPage));
        expect(fullscreenBloc.state.videos, isNot(contains(seedOnly)));
        expect(fullscreenBloc.state.currentVideo?.id, 'target-video');
      },
    );

    testWidgets(
      'uses live profile videos when the seed lacks the tapped target',
      (tester) async {
        const targetStableId = 'stable-target';
        final seedOnly = _video('seed-only', createdAt: 1000);
        final liveTarget = _video(
          'target-video',
          createdAt: 2000,
          stableId: targetStableId,
        );
        final liveVideos = [
          _video('live-0', createdAt: 3000),
          liveTarget,
        ];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => AuthorFeedResult(
            authorPubkey: _profilePubkey,
            videos: liveVideos,
            hasMore: false,
          ),
        );

        final fullscreenBloc = await pumpProfileVideoFeed(
          tester,
          seedVideos: [seedOnly],
          videoIndex: 0,
          initialVideoId: liveTarget.id,
          initialStableId: targetStableId,
        );

        expect(fullscreenBloc.state.videos, liveVideos);
        expect(fullscreenBloc.state.videos, isNot(contains(seedOnly)));
        expect(fullscreenBloc.state.currentVideo?.id, liveTarget.id);
      },
    );

    testWidgets(
      'uses live profile videos when the live page already has the target',
      (tester) async {
        const targetStableId = 'stable-target';
        final seedOnly = _video('seed-only', createdAt: 1000);
        final liveTarget = _video(
          'target-video',
          createdAt: 2000,
          stableId: targetStableId,
        );
        final liveVideos = [
          _video('live-0', createdAt: 3000),
          liveTarget,
        ];
        final seedVideos = [
          seedOnly,
          _video('target-video', createdAt: 2000, stableId: targetStableId),
        ];

        when(
          () => videosRepository.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer(
          (_) async => AuthorFeedResult(
            authorPubkey: _profilePubkey,
            videos: liveVideos,
            hasMore: false,
          ),
        );

        final fullscreenBloc = await pumpProfileVideoFeed(
          tester,
          seedVideos: seedVideos,
          videoIndex: 1,
          initialVideoId: liveTarget.id,
          initialStableId: targetStableId,
        );

        expect(fullscreenBloc.state.videos, liveVideos);
        expect(fullscreenBloc.state.videos, isNot(contains(seedOnly)));
        expect(fullscreenBloc.state.currentVideo?.id, liveTarget.id);
      },
    );
  });
}
