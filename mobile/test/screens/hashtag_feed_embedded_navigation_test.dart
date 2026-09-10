// ABOUTME: Verifies the hashtag feed hands a tapped video to its embedding host,
// ABOUTME: and pushes the anchored fullscreen route when it owns the screen.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:videos_repository/videos_repository.dart';

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

    // Keeps a hand-rolled harness rather than testMaterialApp: this path needs
    // MaterialApp.router so the screen's context.push has a GoRouter to reach.
    testWidgets('feed that owns the screen pushes the tapped video route', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/hashtag/funny',
        routes: [
          GoRoute(
            path: '/hashtag/:hashtag',
            builder: (_, state) => HashtagFeedScreen(
              hashtag: state.pathParameters['hashtag'] ?? '',
            ),
          ),
          GoRoute(
            path: PooledFullscreenVideoFeedScreen.path,
            builder: (_, _) => const Scaffold(body: Text('fullscreen feed')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [...getStandardTestOverrides(), ...screenOverrides()],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(_tile(1));
      await tester.pumpAndSettle();

      expect(find.text('fullscreen feed'), findsOneWidget);
      expect(
        router.state.uri.toString(),
        equals(PooledFullscreenVideoFeedScreen.pathForVideoId('video-2')),
      );
    });
  });
}
