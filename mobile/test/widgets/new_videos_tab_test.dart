import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/new_videos_tab.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('NewVideosTab', () {
    late _MockVideosRepository videosRepository;
    late _MockVideoEventService videoEventService;
    late _MockContentBlocklistRepository blocklistRepository;

    setUp(() {
      videosRepository = _MockVideosRepository();
      videoEventService = _MockVideoEventService();
      blocklistRepository = _MockContentBlocklistRepository();

      when(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(videos: [_video('new-video')]),
      );
      when(
        () => videosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => [_video('popular-video')]);
      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => blocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    testWidgets('loads newest videos instead of popular videos', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: const Scaffold(body: NewVideosTab()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No videos in New Videos'), findsNothing);
      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: any(named: 'skipCache'),
        ),
      ).called(1);
      verifyNever(
        () => videosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    testWidgets('pull-to-refresh bypasses repository cache on retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          additionalOverrides: [
            appReadyProvider.overrideWithValue(true),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              blocklistRepository,
            ),
          ],
          home: const Scaffold(body: NewVideosTab()),
        ),
      );

      await tester.pumpAndSettle();

      final refreshIndicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refreshIndicator.onRefresh();
      await tester.pumpAndSettle();

      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
        ),
      ).called(1);
      verify(
        () => videosRepository.getNewVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          skipCache: true,
        ),
      ).called(1);
    });
  });
}

VideoEvent _video(String id) {
  return VideoEvent(
    id: id,
    pubkey: 'test-pubkey',
    createdAt: DateTime(2026).millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: DateTime(2026),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
  );
}
