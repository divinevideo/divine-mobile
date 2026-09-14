// ABOUTME: Pins that a content-language change refetches the For You and
// ABOUTME: Popular feeds in the new language (#9149).

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _AlwaysAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

void main() {
  // Both feeds reach the new language only because each one watches
  // languagePreferenceVersionProvider. That watch discards its value, so it
  // reads as an unused statement; without these tests, deleting it would
  // silently restore the bug #9149 fixed and leave CI green.
  //
  // The first request's language list includes the host's ambient locales, so
  // these tests pin the new language to the head of the second request rather
  // than asserting it was absent from the first.
  group('content language change refetches the feeds', () {
    late SharedPreferences sharedPreferences;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;

    setUpAll(() {
      registerFallbackValue(PopularVideosVariant.native);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockVideosRepository = _MockVideosRepository();
      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();

      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            List<VideoEvent>.from(invocation.positionalArguments.first as List),
      );
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('viewer-pubkey');
    });

    test('popular refetches with the newly chosen language', () async {
      final requestedLanguages = <List<String>?>[];

      when(
        () => mockVideosRepository.getPopularVideosPage(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          variant: any(named: 'variant'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) {
        requestedLanguages.add(
          invocation.namedArguments[#preferredLanguages] as List<String>?,
        );
        return Future.value(_popularPage([_video('popular')]));
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        popularVideosFeedProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);

      await container.read(popularVideosFeedProvider.future);
      expect(requestedLanguages, hasLength(1));

      await container
          .read(languagePreferenceServiceProvider)
          .setContentLanguage('es');
      await pumpEventQueue();
      await container.read(popularVideosFeedProvider.future);

      expect(
        requestedLanguages,
        hasLength(2),
        reason: 'the language change must trigger a second request',
      );
      expect(requestedLanguages.last?.first, 'es');
    });

    test('for you refetches with the newly chosen language', () async {
      final requestedLanguages = <List<String>?>[];

      when(
        () => mockVideosRepository.getRecommendedVideos(
          userPubkey: any(named: 'userPubkey'),
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
          skipCache: any(named: 'skipCache'),
          preferredLanguages: any(named: 'preferredLanguages'),
          viewerCountry: any(named: 'viewerCountry'),
        ),
      ).thenAnswer((invocation) {
        requestedLanguages.add(
          invocation.namedArguments[#preferredLanguages] as List<String>?,
        );
        return Future.value(_recommendedResult(['for-you']));
      });

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          authServiceProvider.overrideWithValue(mockAuthService),
          funnelcakeAvailableProvider.overrideWith(
            _AlwaysAvailableFunnelcake.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      final subscription = container.listen(forYouFeedProvider, (_, _) {});
      addTearDown(subscription.close);

      await container.read(forYouFeedProvider.future);
      expect(requestedLanguages, hasLength(1));

      await container
          .read(languagePreferenceServiceProvider)
          .setContentLanguage('es');
      await pumpEventQueue();
      await container.read(forYouFeedProvider.future);

      expect(
        requestedLanguages,
        hasLength(2),
        reason: 'the language change must trigger a second request',
      );
      expect(requestedLanguages.last?.first, 'es');
    });
  });
}

HomeFeedResult _recommendedResult(List<String> ids) {
  return HomeFeedResult(videos: ids.map(_video).toList(), hasMore: false);
}

PopularVideosPage _popularPage(List<VideoEvent> videos) {
  return PopularVideosPage(videos: videos, hasMore: false);
}

VideoEvent _video(String id, {int createdAt = 1_742_169_600}) {
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: const {'d': 'seed', 'x': '1', 'y': '2', 'z': '3'},
    originalLoops: AppConstants.paginationBatchSize,
  );
}
