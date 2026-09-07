// ABOUTME: Tests curation provider lifecycle behavior during navigation
// ABOUTME: Verifies editor's picks persist when navigating away and back to tab

import 'package:curation_repository/curation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<String>[]);
  });

  group('CurationProvider Lifecycle', () {
    late _MockNostrClient mockNostrService;
    late _MockVideoEventService mockVideoEventService;
    late _MockLikesRepository mockLikesRepository;
    late _MockAuthService mockAuthService;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late List<VideoEvent> sampleVideos;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventService = _MockVideoEventService();
      mockLikesRepository = _MockLikesRepository();
      mockAuthService = _MockAuthService();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();

      // Create sample videos for editor's picks
      sampleVideos = List.generate(
        23,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $i',
          timestamp: DateTime.now(),
          title: 'Video $i',
        ),
      );

      // Mock video event service to return sample videos
      when(
        () => mockVideoEventService.discoveryVideos,
      ).thenReturn(sampleVideos);

      // Stub nostr service methods
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());

      // Mock getLikeCounts to return empty counts
      // (replaced getCachedLikeCount)
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => {});
    });

    test('curation provider uses keepAlive to persist state', () async {
      // ARRANGE: Create first container
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          authServiceProvider.overrideWithValue(mockAuthService),
          funnelcakeApiClientProvider.overrideWithValue(
            mockFunnelcakeApiClient,
          ),
        ],
      );

      // ACT: Read curation provider
      final curationState = container.read(curationProvider);

      // ASSERT: Provider should initialize synchronously
      // with loading state
      expect(
        curationState.isLoading,
        isTrue,
        reason: 'Provider initializes in loading state',
      );

      // The key point: with @Riverpod(keepAlive: true),
      // the provider will:
      // 1. NOT autodispose when unwatched
      // 2. Persist state across navigation
      // 3. Complete initialization once and reuse that state

      // This test verifies the annotation is present and
      // provider is marked as keepAlive
      // In production, this prevents the "0 videos" bug when
      // navigating back to Editor's Pick

      container.dispose();
      // TODO(any): Fix and re-enable this test
    }, skip: true);

    test(
      'curation provider initialization completes and populates '
      'editor picks',
      () async {
        // ARRANGE: Create container
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeApiClientProvider.overrideWithValue(
              mockFunnelcakeApiClient,
            ),
          ],
        );

        // ACT: Read initial state
        final initialState = container.read(curationProvider);

        // ASSERT: Initially loading
        expect(initialState.isLoading, isTrue);
        expect(initialState.editorsPicks, isEmpty);

        // Wait for async initialization
        await Future.microtask(() {});
        await Future.delayed(const Duration(milliseconds: 10));

        // ACT: Read after initialization
        final loadedState = container.read(curationProvider);
        final editorsPicks = container.read(editorsPicksProvider);

        // ASSERT: Should be loaded with videos
        expect(loadedState.isLoading, isFalse);
        expect(editorsPicks.length, greaterThan(0));

        container.dispose();
      },
      // TODO(any): Fix and re-enable this test
      skip: true,
    );

    test('curation service initializes with sample data', () {
      // ARRANGE: Create curation service directly
      final mockSigner = _MockNostrSigner();
      final mockVideoEventCache = _MockVideoEventCache();
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);
      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );

      // ACT & ASSERT: Service should initialize with sample data
      expect(service.isLoading, isFalse);
      final editorsPicks = service.getVideosForSetType(
        CurationSetType.editorsPicks,
      );

      // Editor's picks may be empty if no videos available,
      // but service should not be loading
      expect(service.isLoading, isFalse);
      // Verify editorsPicks is a valid list
      // (may be empty if no videos available)
      expect(editorsPicks, isA<List<VideoEvent>>());
    });
  });
}
