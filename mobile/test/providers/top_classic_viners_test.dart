// ABOUTME: Pins that ClassicViner.authorName reaches the viner slider as
// ABOUTME: well-formed UTF-16, inherited from the VideoEvent boundary.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

import '../helpers/test_provider_overrides.dart';

class _TestCurrentAuth extends CurrentAuthState {
  @override
  AuthState build() => AuthState.unauthenticated;
}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _TestFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

void main() {
  group('topClassicViners', () {
    late _MockVideosRepository mockVideosRepository;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late SharedPreferences sharedPreferences;
    late TestAnalyticsService analytics;

    setUp(() async {
      analytics = TestAnalyticsService();
      addTearDown(analytics.dispose);
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockVideosRepository = _MockVideosRepository();
      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      when(() => mockVideoEventService.discoveryVideos).thenReturn(const []);
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<VideoEvent>,
      );
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer() => ProviderContainer(
      overrides: [
        appReadyProvider.overrideWithValue(true),
        analyticsServiceProvider.overrideWithValue(analytics),
        currentAuthStateProvider.overrideWith(_TestCurrentAuth.new),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        videosRepositoryProvider.overrideWithValue(mockVideosRepository),
        videoEventServiceProvider.overrideWithValue(mockVideoEventService),
        contentBlocklistRepositoryProvider.overrideWithValue(
          mockBlocklistRepository,
        ),
        funnelcakeAvailableProvider.overrideWith(_TestFunnelcakeAvailable.new),
      ],
    );

    // The archive's author names are free text, and the slider renders them
    // straight into a Text. VideoEvent's constructor is the sanitizing
    // boundary — this pins that ClassicViner inherits it, so nothing between
    // the repository and the slider has to repeat the guard. The headless
    // flutter_tester does not throw on a lone surrogate (only the real engine
    // does), so the assertion is on the value rather than on a rendered frame.
    test('carries a sanitized authorName through from the video', () async {
      when(
        () => mockVideosRepository.getClassicVideos(
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer(
        (_) async => HomeFeedResult(
          videos: [
            _classicVideo(authorName: 'Zach${String.fromCharCode(0xD83D)}'),
          ],
          hasMore: false,
        ),
      );

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      // topClassicViners auto-disposes; without a listener it is torn down
      // mid-load and never emits.
      final subscription = container.listen(
        topClassicVinersProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(classicVinesFeedProvider.future);
      final viners = await container.read(topClassicVinersProvider.future);

      expect(viners.single.authorName, equals('Zach�'));
    });
  });
}

VideoEvent _classicVideo({required String authorName}) => VideoEvent(
  id: 'classic-1',
  pubkey: 'author-classic-1',
  createdAt: DateTime(2026, 3, 17).millisecondsSinceEpoch ~/ 1000,
  content: 'classic-1',
  timestamp: DateTime(2026, 3, 17),
  title: 'classic-1',
  videoUrl: 'https://example.com/classic-1.mp4',
  thumbnailUrl: 'https://example.com/classic-1.jpg',
  originalLoops: 100,
  authorName: authorName,
  // Non-null so the provider skips its profile prefetch side effect.
  authorAvatar: 'https://example.com/classic-1-avatar.jpg',
);
