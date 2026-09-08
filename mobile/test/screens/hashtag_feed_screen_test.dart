// ABOUTME: Covers the chrome the hashtag feed owns when it is not embedded,
// ABOUTME: starting with the app-bar title that names the hashtag.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
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

  group(HashtagFeedScreen, () {
    testWidgets('titles its app bar with the hashtag', (tester) async {
      await pumpScreen(tester, 'bitcoin');

      expect(find.text('#bitcoin'), findsOneWidget);
    });
  });
}
