// ABOUTME: Verifies embedded hashtag feeds delegate video selection to their host.
// ABOUTME: Keeps embedded navigation separate from the full-screen route path.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
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

  testWidgets('embedded feed delegates the selected video to its host', (
    tester,
  ) async {
    final hashtagService = _MockHashtagService();
    final videoEventService = _MockVideoEventService();
    final videosRepository = _MockVideosRepository();
    final testVideos = [_video('video-1'), _video('video-2')];

    when(
      () => hashtagService.getVideosByHashtags(['funny']),
    ).thenReturn(const []);
    when(
      () => hashtagService.subscribeToHashtagVideos(['funny']),
    ).thenAnswer((_) async {});
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(
      () => videosRepository.getHashtagFeedVideos(hashtag: 'funny'),
    ).thenAnswer((_) async => HashtagFeedVideosResult.success(testVideos));

    List<VideoEvent>? callbackVideos;
    int? callbackIndex;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          hashtagServiceProvider.overrideWithValue(hashtagService),
          videoEventServiceProvider.overrideWithValue(videoEventService),
          videosRepositoryProvider.overrideWithValue(videosRepository),
          subscribedListVideoCacheProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HashtagFeedScreen(
            hashtag: 'funny',
            embedded: true,
            onVideoTap: (videos, index) {
              callbackVideos = videos;
              callbackIndex = index;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final grid = tester.widget<ComposableVideoGrid>(
      find.byType(ComposableVideoGrid),
    );
    grid.onVideoTap(grid.videos, 1);

    expect(callbackVideos, same(grid.videos));
    expect(callbackVideos![1].id, 'video-2');
    expect(callbackIndex, 1);
  });
}
