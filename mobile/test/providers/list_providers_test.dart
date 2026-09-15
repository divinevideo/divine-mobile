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
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockAuthService extends Mock implements AuthService {}

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

UserList _buildList({
  required String id,
  required String name,
  List<String> pubkeys = const [],
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: _frozenNow,
    updatedAt: _frozenNow,
  );
}

void main() {
  group(userListsProvider, () {
    late _MockAuthService mockAuthService;
    late _MockPeopleListsRepository mockRepository;
    late StreamController<AuthState> authStateController;
    late StreamController<List<UserList>> ownerAListsController;
    late StreamController<List<UserList>> ownerBListsController;

    setUp(() {
      mockAuthService = _MockAuthService();
      mockRepository = _MockPeopleListsRepository();
      authStateController = StreamController<AuthState>.broadcast();
      ownerAListsController = StreamController<List<UserList>>.broadcast();
      ownerBListsController = StreamController<List<UserList>>.broadcast();

      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => authStateController.stream);
      when(() => mockAuthService.authState).thenReturn(
        AuthState.unauthenticated,
      );
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

      when(
        () => mockRepository.watchLists(ownerPubkey: _ownerA),
      ).thenAnswer((_) => ownerAListsController.stream);
      when(
        () => mockRepository.watchLists(ownerPubkey: _ownerB),
      ).thenAnswer((_) => ownerBListsController.stream);
    });

    tearDown(() async {
      await authStateController.close();
      if (!ownerAListsController.isClosed) {
        await ownerAListsController.close();
      }
      if (!ownerBListsController.isClosed) {
        await ownerBListsController.close();
      }
    });

    ProviderContainer buildContainer() {
      return ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          peopleListsRepositoryProvider.overrideWithValue(mockRepository),
          isFeatureEnabledProvider(
            FeatureFlag.curatedLists,
          ).overrideWithValue(true),
        ],
      );
    }

    test(
      'emits empty list when auth state is unauthenticated',
      () async {
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        final container = buildContainer();
        addTearDown(container.dispose);

        // Trigger initial build by listening.
        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        // Flush the stream's first value.
        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, isEmpty);
        verifyNever(
          () => mockRepository.watchLists(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );
      },
    );

    test(
      'rebuilds and watches repository for new owner when auth '
      'transitions from unauthenticated to authenticated',
      () async {
        final container = buildContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await Future<void>.delayed(Duration.zero);

        // Initially unauthenticated — repo should not have been watched.
        verifyNever(
          () => mockRepository.watchLists(
            ownerPubkey: any(named: 'ownerPubkey'),
          ),
        );

        // Transition: user signs in. authService now reports ownerA.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerA);

        // Invalidating currentAuthStateProvider simulates an auth-state change.
        container.invalidate(currentAuthStateProvider);

        await Future<void>.delayed(Duration.zero);

        // Emit some lists from the repo stream.
        ownerAListsController.add([
          _buildList(id: 'list-a1', name: 'Friends'),
        ]);

        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, hasLength(1));
        expect(value.value!.first.id, equals('list-a1'));
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerA),
        ).called(1);
      },
    );

    test(
      'resubscribes to new owner repository after sign-out then sign-in '
      'as a different account',
      () async {
        // Start authenticated as owner A.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerA);

        final container = buildContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(
          userListsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await Future<void>.delayed(Duration.zero);

        ownerAListsController.add([
          _buildList(id: 'list-a1', name: 'Friends'),
        ]);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(userListsProvider).value,
          hasLength(1),
        );
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerA),
        ).called(1);

        // Sign out — auth service emits `unauthenticated`. The stream
        // event becomes `currentAuthStateProvider`'s new state, a genuinely
        // different enum value, so dependents rebuild.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.unauthenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(null);
        authStateController.add(AuthState.unauthenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(
          container.read(userListsProvider).value,
          isEmpty,
        );

        // Sign in as owner B.
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_ownerB);
        authStateController.add(AuthState.authenticated);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        ownerBListsController.add([
          _buildList(id: 'list-b1', name: 'Crew'),
          _buildList(id: 'list-b2', name: 'Inner Circle'),
        ]);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final value = container.read(userListsProvider);
        expect(value.hasValue, isTrue);
        expect(value.value, hasLength(2));
        expect(
          value.value!.map((l) => l.id),
          containsAll(<String>['list-b1', 'list-b2']),
        );
        verify(
          () => mockRepository.watchLists(ownerPubkey: _ownerB),
        ).called(1);
      },
    );
  });

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
