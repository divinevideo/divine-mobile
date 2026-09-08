// ABOUTME: Tests curation provider lifecycle: build, keepAlive and auto-refresh
// ABOUTME: Verifies editor's picks survive navigating away from and back to tab

import 'dart:async';

import 'package:curation_repository/curation_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';

import '../helpers/test_helpers.dart';
import '../helpers/test_provider_overrides.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockCurationRepository extends Mock implements CurationRepository {}

/// Lets a test drive the `videoEventsProvider` that `Curation.build` listens
/// to, so the auto-refresh path can be exercised rather than left in
/// `AsyncError` by an unstubbed service.
class _ControllableVideoEvents extends VideoEvents {
  _ControllableVideoEvents(this.controller);

  final StreamController<List<VideoEvent>> controller;

  @override
  Stream<List<VideoEvent>> build() => controller.stream;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group('CurationProvider lifecycle', () {
    late _MockCurationRepository mockCurationRepository;
    late MockAuthService mockAuthService;
    late StreamController<List<VideoEvent>> videoEvents;

    setUp(() {
      mockCurationRepository = _MockCurationRepository();
      mockAuthService = createMockAuthService();
      videoEvents = StreamController<List<VideoEvent>>.broadcast();
      addTearDown(videoEvents.close);
    });

    void stubEditorsPicks(List<VideoEvent> videos) {
      when(
        () => mockCurationRepository.getVideosForSetType(
          CurationSetType.editorsPicks,
        ),
      ).thenReturn(videos);
    }

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
          curationRepositoryProvider.overrideWithValue(mockCurationRepository),
          videoEventsProvider.overrideWith(
            () => _ControllableVideoEvents(videoEvents),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('build publishes the repository cache on the first read', () {
      final cached = TestHelpers.createMockVideoEvents(23);
      stubEditorsPicks(cached);

      final container = createContainer();
      final state = container.read(curationProvider);

      expect(state.editorsPicks, hasLength(23));
      expect(
        state.editorsPicks.map((v) => v.title).toList(),
        cached.map((v) => v.title).toList(),
        reason: 'VideoEvent == compares id alone, so pin a carried field too',
      );
      expect(
        state.isLoading,
        isFalse,
        reason: 'the repository read is synchronous, so nothing stays pending',
      );
      expect(state.error, isNull);
      expect(container.read(curationLoadingProvider), isFalse);
      expect(container.read(editorsPicksProvider), hasLength(23));
    });

    test('a failing repository read leaves an error, not a stuck spinner', () {
      when(
        () => mockCurationRepository.getVideosForSetType(
          CurationSetType.editorsPicks,
        ),
      ).thenThrow(StateError('no signer'));

      final container = createContainer();
      final state = container.read(curationProvider);

      expect(state.error, contains('no signer'));
      expect(state.editorsPicks, isEmpty);
      expect(
        state.isLoading,
        isFalse,
        reason: 'a failed load must not leave the tab spinning forever',
      );
    });

    test('keepAlive holds the state after the last listener closes', () async {
      final cached = TestHelpers.createMockVideoEvents(23);
      stubEditorsPicks(cached);
      when(mockCurationRepository.refreshIfNeeded).thenReturn(null);

      final container = createContainer();
      final subscription = container.listen(curationProvider, (_, _) {});
      await container.read(curationProvider.notifier).refreshAll();
      final populatedState = container.read(curationProvider);
      expect(populatedState.editorsPicks, hasLength(23));

      subscription.close();
      await pumpEventQueue();

      expect(container.read(curationProvider), same(populatedState));
    });

    test(
      'a change in the video event count refreshes the curation sets',
      () async {
        stubEditorsPicks([]);
        when(mockCurationRepository.refreshIfNeeded).thenReturn(null);

        final container = createContainer();
        // Riverpod pauses a stream subscription while nothing is actively
        // listening, so a bare read would never see the emission below.
        final subscription = container.listen(curationProvider, (_, _) {});
        addTearDown(subscription.close);

        expect(container.read(curationProvider).editorsPicks, isEmpty);
        verifyNever(mockCurationRepository.refreshIfNeeded);

        final arrived = TestHelpers.createMockVideoEvents(3);
        stubEditorsPicks(arrived);
        videoEvents.add(TestHelpers.createMockVideoEvents(2));
        await pumpEventQueue();

        verify(mockCurationRepository.refreshIfNeeded).called(1);
        expect(container.read(curationProvider).editorsPicks, hasLength(3));
      },
    );

    test('CurationRepository reports no work pending once constructed', () {
      final mockNostrService = _MockNostrClient();
      when(
        () => mockNostrService.subscribe(any(), onEose: any(named: 'onEose')),
      ).thenAnswer((_) => const Stream.empty());
      final mockVideoEventCache = _MockVideoEventCache();
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: _MockLikesRepository(),
        signer: _MockNostrSigner(),
        divineTeamPubkeys: const [],
      );
      addTearDown(service.dispose);

      expect(service.isLoading, isFalse);
      expect(
        service.getVideosForSetType(CurationSetType.editorsPicks),
        isEmpty,
        reason: 'the Divine Team fetch has not returned, so nothing is curated',
      );
    });
  });
}
