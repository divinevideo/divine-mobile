// ABOUTME: Verifies the hashtag feed hands a tapped video to its embedding host,
// ABOUTME: pushes an anchored reel that pages through the grid's feed when it
// ABOUTME: owns the screen, and logs a rejected push instead of leaking it.

import 'dart:async';

import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/go_router.dart';
import '../helpers/test_provider_overrides.dart';

class _MockHashtagService extends Mock implements HashtagService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

VideoEvent _video(String id) {
  const pubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    content: 'Test video',
    createdAt: 1,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}

/// The tappable tile the grid renders for [index].
///
/// Resolved through the semantics identifier the grid stamps on each
/// thumbnail, so the test exercises the same tap-to-index plumbing a user
/// does instead of positionally guessing a `GestureDetector`.
Finder _tile(int index) => find
    .descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.identifier == 'video_thumbnail_$index',
      ),
      matching: find.byType(GestureDetector),
    )
    .first;

void main() {
  setUpAll(() {
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(_video('fallback'));
  });

  late _MockHashtagService hashtagService;
  late _MockVideoEventService videoEventService;
  late _MockVideosRepository videosRepository;

  setUp(() {
    hashtagService = _MockHashtagService();
    videoEventService = _MockVideoEventService();
    videosRepository = _MockVideosRepository();
    final testVideos = [_video('video-1'), _video('video-2')];

    when(
      () => hashtagService.getVideosByHashtags(['funny']),
    ).thenReturn(const []);
    when(() => hashtagService.getHashtagStats(any())).thenReturn(null);
    when(
      () => hashtagService.subscribeToHashtagVideos(['funny']),
    ).thenAnswer((_) async {});
    when(
      () => videoEventService.isVideoEventKnownDeleted(any()),
    ).thenReturn(false);
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(
      () => videosRepository.getHashtagFeedVideos(hashtag: 'funny'),
    ).thenAnswer((_) async => HashtagFeedVideosResult.success(testVideos));
  });

  List<Override> screenOverrides() => [
    hashtagServiceProvider.overrideWithValue(hashtagService),
    videoEventServiceProvider.overrideWithValue(videoEventService),
    videosRepositoryProvider.overrideWithValue(videosRepository),
    subscribedListVideoCacheProvider.overrideWithValue(null),
  ];

  // A hand-rolled harness rather than testMaterialApp: the screen that owns
  // its route needs MaterialApp.router so context.push has a GoRouter to reach.
  Future<GoRouter> pumpRoutedScreen(
    WidgetTester tester, {
    required String hashtag,
    required void Function(PooledFullscreenVideoFeedArgs args) onPushed,
  }) async {
    final router = GoRouter(
      initialLocation: '/hashtag/$hashtag',
      routes: [
        GoRoute(
          path: '/hashtag/:hashtag',
          builder: (_, state) => HashtagFeedScreen(
            hashtag: state.pathParameters['hashtag'] ?? '',
          ),
        ),
        GoRoute(
          path: PooledFullscreenVideoFeedScreen.path,
          builder: (_, state) {
            onPushed(state.extra! as PooledFullscreenVideoFeedArgs);
            return const Scaffold(body: Text('fullscreen feed'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [...getStandardTestOverrides(), ...screenOverrides()],
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return router;
  }

  group(HashtagFeedScreen, () {
    testWidgets('embedded feed delegates the selected video to its host', (
      tester,
    ) async {
      List<VideoEvent>? hostVideos;
      int? hostIndex;

      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: screenOverrides(),
          home: HashtagFeedScreen(
            hashtag: 'funny',
            embedded: true,
            onVideoTap: (videos, index) {
              hostVideos = videos;
              hostIndex = index;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(_tile(1));
      await tester.pump();

      expect(hostIndex, equals(1));
      expect(hostVideos, isNotNull);
      expect(hostVideos![hostIndex!].id, equals('video-2'));
    });

    testWidgets('feed that owns the screen pushes the tapped video route', (
      tester,
    ) async {
      PooledFullscreenVideoFeedArgs? args;
      final router = await pumpRoutedScreen(
        tester,
        hashtag: 'funny',
        onPushed: (pushed) => args = pushed,
      );

      await tester.tap(_tile(1));
      await tester.pumpAndSettle();

      expect(find.text('fullscreen feed'), findsOneWidget);
      expect(
        router.state.uri.toString(),
        equals('/pooled-video-feed?video=video-2'),
      );
      addTearDown(() => args?.tileOrigin?.takeImage()?.dispose());
      expect(args?.tileOrigin?.videoId, equals('video-2'));
    });

    testWidgets('pushed reel continues the grid feed and loads its next page', (
      tester,
    ) async {
      const hashtag = 'skate';
      final firstPage = [_video('video-1'), _video('video-2')];
      final nextPage = [_video('video-3')];
      when(
        () => hashtagService.getVideosByHashtags([hashtag]),
      ).thenReturn(const []);
      when(
        () => hashtagService.subscribeToHashtagVideos([hashtag]),
      ).thenAnswer((_) async {});
      when(
        () => videosRepository.getHashtagFeedVideos(hashtag: hashtag),
      ).thenAnswer(
        (_) async =>
            HashtagFeedVideosResult.success(firstPage, nextCursor: 'o:50'),
      );
      when(
        () => videosRepository.getHashtagFeedVideos(
          hashtag: hashtag,
          cursor: 'o:50',
        ),
      ).thenAnswer((_) async => HashtagFeedVideosResult.success(nextPage));
      PooledFullscreenVideoFeedArgs? pushed;
      await pumpRoutedScreen(
        tester,
        hashtag: hashtag,
        onPushed: (args) => pushed = args,
      );

      await tester.tap(_tile(0));
      await tester.pumpAndSettle();
      final args = pushed!;
      addTearDown(() => args.tileOrigin?.takeImage()?.dispose());

      expect(args.source, equals(const HashtagViewSource(hashtag)));
      final views = <List<VideoEvent>>[];
      final hasMore = <bool>[];
      final viewsSubscription = args.feedRepository
          .watchView(args.source)
          .listen(views.add);
      final hasMoreSubscription = args.feedRepository
          .watchHasMore(args.source)
          .listen(hasMore.add);
      await tester.pump();

      expect(views.first, equals(firstPage));
      expect(hasMore.first, isTrue);
      verifyNever(
        () => videosRepository.getHashtagFeedVideos(
          hashtag: hashtag,
          cursor: 'o:50',
        ),
      );

      await args.feedRepository.loadMore(args.source);
      await tester.pump();

      expect(views.last, equals([...firstPage, ...nextPage]));
      expect(hasMore.last, isFalse);
      verify(
        () => videosRepository.getHashtagFeedVideos(
          hashtag: hashtag,
          cursor: 'o:50',
        ),
      ).called(1);
      // Not awaited: these cancels settle on the root zone, which the test's
      // fake-async zone never drains, so awaiting them stalls the test.
      unawaited(viewsSubscription.cancel());
      unawaited(hasMoreSubscription.cancel());
    });

    testWidgets('logs a rejected fullscreen route push instead of leaking it', (
      tester,
    ) async {
      final logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      addTearDown(logCapture.clearAllLogs);
      final router = MockGoRouter();
      when(() => router.push<void>(any(), extra: any(named: 'extra')))
          .thenAnswer((_) => Future<void>.error(Exception('route failed')));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...getStandardTestOverrides(), ...screenOverrides()],
          child: MockGoRouterProvider(
            goRouter: router,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: HashtagFeedScreen(hashtag: 'funny'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(_tile(1));
      await tester.pump();

      verify(
        () => router.push<void>(
          '/pooled-video-feed?video=video-2',
          extra: any(named: 'extra'),
        ),
      ).called(1);
      expect(tester.takeException(), isNull);
      final failures = logCapture
          .getRecentLogs()
          .where(
            (entry) =>
                entry.name == 'HashtagFeedScreen' &&
                entry.level == LogLevel.error,
          )
          .toList();
      expect(failures, hasLength(1));
      expect(failures.single.category, LogCategory.video);
      expect(
        failures.single.message,
        'Failed to open hashtag video: Exception: route failed',
      );
    });
  });
}
