// ABOUTME: Covers the chrome the hashtag feed owns when it is not embedded:
// ABOUTME: its app-bar title and the pull-to-refresh wiring on its grid.

import 'dart:async';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
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

void main() {
  setUpAll(() {
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(() {});
  });

  late _MockHashtagService hashtagService;
  late _MockVideoEventService videoEventService;
  late _MockVideosRepository videosRepository;

  setUp(() {
    hashtagService = _MockHashtagService();
    videoEventService = _MockVideoEventService();
    videosRepository = _MockVideosRepository();
    final testVideos = [_video('video-1'), _video('video-2')];

    when(() => hashtagService.getVideosByHashtags(any())).thenReturn(const []);
    when(() => hashtagService.getHashtagStats(any())).thenReturn(null);
    when(
      () => hashtagService.subscribeToHashtagVideos(any()),
    ).thenAnswer((_) async {});
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(
      () =>
          videosRepository.getHashtagFeedVideos(hashtag: any(named: 'hashtag')),
    ).thenAnswer((_) async => HashtagFeedVideosResult.success(testVideos));
  });

  List<Override> screenOverrides() => [
    hashtagServiceProvider.overrideWithValue(hashtagService),
    videoEventServiceProvider.overrideWithValue(videoEventService),
    videosRepositoryProvider.overrideWithValue(videosRepository),
    subscribedListVideoCacheProvider.overrideWithValue(null),
  ];

  Future<void> pumpScreen(WidgetTester tester, String hashtag) async {
    await tester.pumpWidget(
      testMaterialApp(
        additionalOverrides: screenOverrides(),
        home: HashtagFeedScreen(hashtag: hashtag),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('relay arrivals render while the REST request is still pending', (
    tester,
  ) async {
    final pending = Completer<HashtagFeedVideosResult>();
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete(const HashtagFeedVideosResult.success([]));
      }
    });
    when(
      () => videosRepository.getHashtagFeedVideos(
        hashtag: any(named: 'hashtag'),
      ),
    ).thenAnswer((_) => pending.future);
    void Function()? videoChanged;
    when(() => videoEventService.addListener(any())).thenAnswer((invocation) {
      videoChanged = invocation.positionalArguments.first as void Function();
    });
    await pumpScreen(tester, 'fast');
    when(() => hashtagService.getVideosByHashtags(any()))
        .thenReturn([_video('relay-video')]);
    videoChanged!();
    await tester.pump();
    expect(
      tester
          .widget<ComposableVideoGrid>(find.byType(ComposableVideoGrid))
          .videos
          .single
          .id,
      'relay-video',
    );
    expect(pending.isCompleted, isFalse);
  });

  group(HashtagFeedScreen, () {
    testWidgets('titles its app bar with the hashtag', (tester) async {
      await pumpScreen(tester, 'bitcoin');

      expect(find.text('#bitcoin'), findsOneWidget);
    });

    testWidgets('offers pull-to-refresh over the results', (tester) async {
      await pumpScreen(tester, 'bitcoin');

      // FeedRefreshControl is only inserted when the grid is given an
      // onRefresh, so its presence is what proves the screen wired one.
      expect(find.byType(FeedRefreshControl), findsOneWidget);
    });

    testWidgets('cuts an over-long hashtag off in the empty state', (
      tester,
    ) async {
      when(
        () => videosRepository.getHashtagFeedVideos(
          hashtag: any(named: 'hashtag'),
        ),
      ).thenAnswer((_) async => const HashtagFeedVideosResult.success([]));
      final pastedList = 'VineHashtagsMasterList' * 40;

      await pumpScreen(tester, pastedList);

      final title = find.text(
        lookupAppLocalizations(
          const Locale('en'),
        ).hashtagFeedEmptyTitle(pastedList),
      );
      expect(title, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(title);
      expect(paragraph.didExceedMaxLines, isTrue);
    });
  });
}
