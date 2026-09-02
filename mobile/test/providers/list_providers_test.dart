// ABOUTME: Tests for userListsProvider reactivity to authentication transitions
// ABOUTME: Covers sign-in, sign-out, and active-account switches.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

// Full-length 64-char Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _blockedAuthor =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
// Full-length 64-char hex event ids — the plain-event-ID branch requires them.
const String _blockedVideoId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const String _allowedVideoId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);

VideoEvent _video({
  required String id,
  required String pubkey,
  String? dTag,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: _frozenNow.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: _frozenNow,
    title: id,
    videoUrl: 'https://example.com/$id.mp4',
    rawTags: dTag == null ? const {} : {'d': dTag},
  );
}

void main() {
  group(videoEventsByIdsProvider, () {
    test('uses an EOSE-bounded relay read for missing videos', () async {
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(null);
      when(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
        ],
      );
      addTearDown(container.dispose);
      final provider = videoEventsByIdsProvider([_allowedVideoId]);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(container.read(provider.future), completion(isEmpty));
      verify(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).called(1);
    });

    test('keeps cached videos when every relay refuses the read', () async {
      final cachedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(cachedVideo);
      when(
        () => videoEventService.getVideoById(_blockedVideoId),
      ).thenReturn(null);
      when(
        () => videoEventService.shouldHideVideo(cachedVideo),
      ).thenReturn(false);
      when(() => nostrClient.subscribe(any(), closeOnEose: true)).thenAnswer(
        (_) => Stream<Event>.error(
          const RelaySubscriptionRefusedException(
            'error: too many subscriptions',
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
        ],
      );
      addTearDown(container.dispose);
      final provider = videoEventsByIdsProvider([
        _allowedVideoId,
        _blockedVideoId,
      ]);
      final states = <AsyncValue<List<VideoEvent>>>[];
      final subscription = container.listen(
        provider,
        (_, next) => states.add(next),
      );
      addTearDown(subscription.close);

      await container.read(provider.future);
      await pumpEventQueue();

      expect(
        states.where((state) => state.hasError),
        isEmpty,
        reason: 'a refused relay read must not fail the provider',
      );
      expect(states.last.value?.map((v) => v.id), [_allowedVideoId]);
    });

    test(
      'filters hidden addressable videos found in the local cache',
      () async {
        const dTag = 'blocked-video';
        const coord = '34236:$_blockedAuthor:$dTag';
        final blockedVideo = _video(
          id: 'blocked-video-event',
          pubkey: _blockedAuthor,
          dTag: dTag,
        );
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn([blockedVideo]);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);
        final provider = videoEventsByIdsProvider([coord]);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        await expectLater(
          container.read(provider.future),
          completion(isEmpty),
        );
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test(
      'filters hidden videos found by plain event id in the local cache',
      () async {
        final blockedVideo = _video(
          id: _blockedVideoId,
          pubkey: _blockedAuthor,
        );
        final allowedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn(const []);
        when(
          () => videoEventService.getVideoById(_blockedVideoId),
        ).thenReturn(blockedVideo);
        when(
          () => videoEventService.getVideoById(_allowedVideoId),
        ).thenReturn(allowedVideo);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);
        when(
          () => videoEventService.shouldHideVideo(allowedVideo),
        ).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);
        final provider = videoEventsByIdsProvider([
          _blockedVideoId,
          _allowedVideoId,
        ]);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        final result = await container.read(provider.future);
        expect(result.map((v) => v.id), [_allowedVideoId]);
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test('re-runs and re-filters when the blocklist version changes', () async {
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      // Initially the author is visible.
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
        ],
      );
      addTearDown(container.dispose);

      final provider = videoEventsByIdsProvider([_allowedVideoId]);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first.map((v) => v.id), [_allowedVideoId]);

      // Block the author and bump the blocklist version (a broad change emits
      // no removed-id signal — only the version bump).
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(true);
      container.read(blocklistVersionProvider.notifier).increment();

      final second = await container.read(provider.future);
      expect(second, isEmpty);
    });
  });

  group(curatedListVideoEventsProvider, () {
    test('uses an EOSE-bounded relay read for missing videos', () async {
      const listId = 'relay-list';
      final videoEventService = _MockVideoEventService();
      final nostrClient = _MockNostrClient();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(null);
      when(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).thenAnswer((_) => const Stream.empty());

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          nostrServiceProvider.overrideWithValue(nostrClient),
          curatedListVideosProvider(
            listId,
          ).overrideWith((ref) => [_allowedVideoId]),
        ],
      );
      addTearDown(container.dispose);
      final provider = curatedListVideoEventsProvider(listId);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      await expectLater(container.read(provider.future), completion(isEmpty));
      verify(
        () => nostrClient.subscribe(any(), closeOnEose: true),
      ).called(1);
    });

    test(
      'filters hidden videos found by plain event id in the local cache',
      () async {
        const listId = 'curated-list-1';
        final blockedVideo = _video(
          id: _blockedVideoId,
          pubkey: _blockedAuthor,
        );
        final allowedVideo = _video(id: _allowedVideoId, pubkey: _ownerA);
        final videoEventService = _MockVideoEventService();
        when(() => videoEventService.discoveryVideos).thenReturn(const []);
        when(() => videoEventService.homeFeedVideos).thenReturn(const []);
        when(() => videoEventService.profileVideos).thenReturn(const []);
        when(
          () => videoEventService.getVideoById(_blockedVideoId),
        ).thenReturn(blockedVideo);
        when(
          () => videoEventService.getVideoById(_allowedVideoId),
        ).thenReturn(allowedVideo);
        when(
          () => videoEventService.shouldHideVideo(blockedVideo),
        ).thenReturn(true);
        when(
          () => videoEventService.shouldHideVideo(allowedVideo),
        ).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
            curatedListVideosProvider(
              listId,
            ).overrideWith((ref) => [_blockedVideoId, _allowedVideoId]),
          ],
        );
        addTearDown(container.dispose);
        final provider = curatedListVideoEventsProvider(listId);
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        final result = await container.read(provider.future);
        expect(result.map((v) => v.id), [_allowedVideoId]);
        verify(() => videoEventService.shouldHideVideo(blockedVideo)).called(1);
      },
    );

    test('re-runs and re-filters when the blocklist version changes', () async {
      const listId = 'curated-list-2';
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);

      final container = ProviderContainer(
        overrides: [
          videoEventServiceProvider.overrideWithValue(videoEventService),
          curatedListVideosProvider(
            listId,
          ).overrideWith((ref) => [_allowedVideoId]),
        ],
      );
      addTearDown(container.dispose);

      final provider = curatedListVideoEventsProvider(listId);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);

      final first = await container.read(provider.future);
      expect(first.map((v) => v.id), [_allowedVideoId]);

      when(() => videoEventService.shouldHideVideo(video)).thenReturn(true);
      container.read(blocklistVersionProvider.notifier).increment();

      final second = await container.read(provider.future);
      expect(second, isEmpty);
    });
  });

  // Regression: an `async*` provider body does not start until the returned
  // stream is listened to, so a provider that is invalidated (pull-to-refresh)
  // or unmounted (screen dismissed) first would reach its `ref.watch` /
  // `ref.read` on an already-disposed Ref and throw
  // "Cannot use the Ref … after it has been disposed" (#6274, #7294).
  group('Ref lifecycle on immediate disposal (#7294)', () {
    _MockVideoEventService buildVideoEventService() {
      final video = _video(id: _allowedVideoId, pubkey: _ownerA);
      final videoEventService = _MockVideoEventService();
      when(() => videoEventService.discoveryVideos).thenReturn(const []);
      when(() => videoEventService.homeFeedVideos).thenReturn(const []);
      when(() => videoEventService.profileVideos).thenReturn(const []);
      when(
        () => videoEventService.getVideoById(_allowedVideoId),
      ).thenReturn(video);
      when(() => videoEventService.shouldHideVideo(video)).thenReturn(false);
      return videoEventService;
    }

    test(
      '$videoEventsByIdsProvider abandons its fetch without touching Ref',
      () async {
        final videoEventService = buildVideoEventService();
        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
          ],
        );
        addTearDown(container.dispose);

        final provider = videoEventsByIdsProvider([_allowedVideoId]);

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final subscription = container.listen(provider, (_, _) {});
          container.invalidate(provider);
          subscription.close();
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
        // The work is abandoned, not merely silent: nothing reads the cache
        // on behalf of a provider that no longer exists.
        verifyNever(() => videoEventService.getVideoById(any()));
      },
    );

    test(
      '$curatedListVideoEventsProvider abandons its fetch without touching Ref',
      () async {
        const listId = 'curated-list-disposed';
        final videoEventService = buildVideoEventService();
        final container = ProviderContainer(
          overrides: [
            videoEventServiceProvider.overrideWithValue(videoEventService),
            curatedListVideosProvider(
              listId,
            ).overrideWith((ref) => [_allowedVideoId]),
          ],
        );
        addTearDown(container.dispose);

        final provider = curatedListVideoEventsProvider(listId);

        final uncaughtErrors = await _captureUncaughtErrors(() async {
          final subscription = container.listen(provider, (_, _) {});
          container.invalidate(provider);
          subscription.close();
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
        });

        expect(uncaughtErrors, isEmpty);
        verifyNever(() => videoEventService.getVideoById(any()));
      },
    );
  });

  group(publicPeopleListProvider, () {
    test('resolves through the people repository', () async {
      final repository = _MockPeopleListsRepository();
      final crew = UserList(
        id: 'crew',
        name: 'Crew',
        pubkeys: const [_ownerB],
        createdAt: _frozenNow,
        updatedAt: _frozenNow,
        isEditable: false,
      );
      when(
        () => repository.fetchPublicList(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
        ),
      ).thenAnswer((_) async => crew);

      final container = ProviderContainer(
        overrides: [
          peopleListsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final list = await container.read(
        publicPeopleListProvider(
          ownerPubkey: _ownerA,
          listId: 'crew',
        ).future,
      );

      expect(list, same(crew));
      verify(
        () => repository.fetchPublicList(ownerPubkey: _ownerA, listId: 'crew'),
      ).called(1);
    });
  });

  group(publicCuratedListProvider, () {
    test(
      'fetches once and does not re-run when the lists state re-emits',
      () async {
        final mockService = _MockCuratedListService();
        when(
          () => mockService.fetchPublicList(
            authorPubkey: any(named: 'authorPubkey'),
            listId: any(named: 'listId'),
          ),
        ).thenAnswer((_) async => null);

        late _StubCuratedListsState notifier;
        final container = ProviderContainer(
          overrides: [
            curatedListsStateProvider.overrideWith(
              () => notifier = _StubCuratedListsState(mockService),
            ),
          ],
        );
        addTearDown(container.dispose);

        final provider = publicCuratedListProvider(
          authorPubkey: _ownerA,
          listId: 'my-vines',
        );
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        await container.read(provider.future);
        verify(
          () => mockService.fetchPublicList(
            authorPubkey: _ownerA,
            listId: 'my-vines',
          ),
        ).called(1);

        // Background relay sync and list add/remove fire
        // CuratedListService.notifyListeners, which re-emits the lists
        // state. The deep-link fetch must not re-run (and reset its screen
        // to loading) on those emissions.
        notifier.reEmit();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockService.fetchPublicList(
            authorPubkey: _ownerA,
            listId: 'my-vines',
          ),
        );
      },
    );
  });
}

class _MockCuratedListService extends Mock implements CuratedListService {}

class _StubCuratedListsState extends CuratedListsState {
  _StubCuratedListsState(this._mockService);

  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [];

  void reEmit() => state = const AsyncValue.data(<CuratedList>[]);
}

/// Collects everything that escapes [body] as an unhandled error — both
/// zone-level async errors and `FlutterError.onError` reports.
///
/// A disposed-Ref access surfaces this way rather than as a thrown exception
/// at the call site, so an `expect(..., isEmpty)` on the result is what makes
/// the lifecycle regression above visible.
Future<List<Object>> _captureUncaughtErrors(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  final previousFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details.exception);
  };

  try {
    await runZonedGuarded(body, (error, _) {
      errors.add(error);
    });
  } finally {
    FlutterError.onError = previousFlutterError;
  }

  return errors;
}
