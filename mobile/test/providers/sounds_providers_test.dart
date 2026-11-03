// ABOUTME: Tests for sounds_providers.dart Riverpod state management
// ABOUTME: Verifies SoundsRepository provider, trending sounds, and selected sound state

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:videos_repository/videos_repository.dart';

// Mock classes
class MockNostrClient extends Mock implements NostrClient {}

class MockSoundsRepository extends Mock implements SoundsRepository {}

/// Lets [repository] keep every sound, as it does each one its publisher
/// named.
void _keepEverySound(MockSoundsRepository repository) {
  when(() => repository.withoutUnusedOriginals(any())).thenAnswer(
    (invocation) async =>
        invocation.positionalArguments.single as List<AudioEvent>,
  );
  when(() => repository.withoutBlockedAuthors(any())).thenAnswer(
    (invocation) => invocation.positionalArguments.single as List<AudioEvent>,
  );
}

class MockSoundLibraryService extends Mock implements SoundLibraryService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _StubAuthService extends Mock implements AuthService {
  _StubAuthService(this._pubkey);

  final String? _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;

  @override
  Stream<AuthState> get authStateStream => const Stream<AuthState>.empty();

  @override
  AuthState get authState =>
      _pubkey == null ? AuthState.unauthenticated : AuthState.authenticated;
}

/// Helper to create test AudioEvent instances
AudioEvent createTestAudioEvent({
  required String id,
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title ?? 'Test Sound $id',
    duration: duration ?? 5.0,
    mimeType: 'audio/mpeg',
  );
}

void main() {
  _ownerExceptionTests();

  group('SoundsProviders', () {
    late MockNostrClient mockNostrClient;
    late MockSoundsRepository mockRepository;

    setUp(() {
      registerFallbackValue(const <String>[]);
      registerFallbackValue(const <AudioEvent>[]);
      mockNostrClient = MockNostrClient();
      mockRepository = MockSoundsRepository();

      // Default stubs for NostrClient (SoundsRepository.initialize uses these)
      when(() => mockNostrClient.hasKeys).thenReturn(false);
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
    });

    group('soundsRepositoryProvider', () {
      late _MockContentBlocklistRepository blocklist;

      setUp(() {
        blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.currentState).thenReturn(
          const ContentPolicyState(
            currentUserPubkey: 'viewer',
            mutedPubkeys: {'muted'},
            blockedPubkeys: {'blocked'},
            pubkeysBlockingUs: {},
            pubkeysMutingUs: {},
          ),
        );
      });

      ProviderContainer buildContainer() {
        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrClient),
            funnelcakeApiClientProvider.overrideWithValue(
              FunnelcakeApiClient(baseUrl: ''),
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(blocklist),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test('creates SoundsRepository with nostrClient', () {
        final repository = buildContainer().read(soundsRepositoryProvider);

        expect(repository, isA<SoundsRepository>());
      });

      test('leaves out the sounds of authors the viewer blocked or muted', () {
        final repository = buildContainer().read(soundsRepositoryProvider);

        final kept = repository.withoutBlockedAuthors([
          for (final pubkey in ['followed', 'blocked', 'muted'])
            createTestAudioEvent(id: pubkey).copyWith(pubkey: pubkey),
        ]);

        expect(kept.map((sound) => sound.pubkey), ['followed']);
      });

      test('repository is kept alive (not auto-disposed)', () async {
        final container = buildContainer();

        final repo1 = container.read(soundsRepositoryProvider);

        // Advance the provider disposal boundary without a listener.
        await container.pump();

        final repo2 = container.read(soundsRepositoryProvider);

        // Same instance should be returned (keepAlive: true)
        expect(identical(repo1, repo2), isTrue);
      });
    });

    group('selectedSoundProvider', () {
      test('initial state is null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final selectedSound = container.read(selectedSoundProvider);

        expect(selectedSound, isNull);
      });

      test('select() updates state to the selected sound', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final testSound = createTestAudioEvent(id: 'sound-1');

        container.read(selectedSoundProvider.notifier).select(testSound);

        final selectedSound = container.read(selectedSoundProvider);
        expect(selectedSound, equals(testSound));
        expect(selectedSound?.id, equals('sound-1'));
      });

      test('clear() sets state back to null', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final testSound = createTestAudioEvent(id: 'sound-1');
        final notifier = container.read(selectedSoundProvider.notifier);

        notifier.select(testSound);
        expect(container.read(selectedSoundProvider), isNotNull);

        notifier.clear();
        expect(container.read(selectedSoundProvider), isNull);
      });

      test('selecting different sound replaces previous', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final sound1 = createTestAudioEvent(id: 'sound-1');
        final sound2 = createTestAudioEvent(id: 'sound-2');
        final notifier = container.read(selectedSoundProvider.notifier);

        notifier.select(sound1);
        expect(container.read(selectedSoundProvider)?.id, equals('sound-1'));

        notifier.select(sound2);
        expect(container.read(selectedSoundProvider)?.id, equals('sound-2'));
      });
    });

    group('trendingSoundsProvider', () {
      setUp(() {
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
      });

      ProviderContainer buildContainer() {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      /// Answers each newest-sounds fetch with the next of [pages].
      void stubPages(List<List<AudioEvent>> pages) {
        var call = 0;
        when(
          () => mockRepository.fetchTrendingSounds(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => pages[call++]);
      }

      test('loads the newest page from the repository', () async {
        stubPages([
          [
            createTestAudioEvent(id: 'trend-1', createdAt: 1704067300),
            createTestAudioEvent(id: 'trend-2'),
          ],
        ]);

        final result = await buildContainer().read(
          trendingSoundsProvider.future,
        );

        expect(result.sounds.map((sound) => sound.id), ['trend-1', 'trend-2']);
        expect(result.hasMore, isTrue);
        verify(
          () => mockRepository.fetchTrendingSounds(limit: 100),
        ).called(1);
      });

      test('leaves out the unnamed sounds nobody reused', () async {
        final named = createTestAudioEvent(id: 'named');
        final unused = createTestAudioEvent(id: 'unused');
        stubPages([
          [named, unused],
        ]);
        when(
          () => mockRepository.withoutUnusedOriginals([named, unused]),
        ).thenAnswer((_) async => [named]);

        final result = await buildContainer().read(
          trendingSoundsProvider.future,
        );

        expect(result.sounds, [named]);
      });

      test('leaves out the sounds of authors the viewer blocked', () async {
        final kept = createTestAudioEvent(id: 'kept');
        final blocked = createTestAudioEvent(id: 'blocked');
        stubPages([
          [kept, blocked],
        ]);
        when(
          () => mockRepository.withoutBlockedAuthors([kept, blocked]),
        ).thenReturn([kept]);

        final result = await buildContainer().read(
          trendingSoundsProvider.future,
        );

        expect(result.sounds, [kept]);
      });

      test('drops a newly blocked author from the loaded pages, '
          'without loading them again', () async {
        final kept = createTestAudioEvent(id: 'kept');
        final blockedLater = createTestAudioEvent(id: 'blocked-later');
        stubPages([
          [kept, blockedLater],
        ]);
        final container = buildContainer();
        final subscription = container.listen(
          trendingSoundsProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(trendingSoundsProvider.future);
        expect(
          container.read(trendingSoundsProvider).requireValue.sounds,
          [kept, blockedLater],
        );

        when(() => mockRepository.withoutBlockedAuthors(any())).thenAnswer(
          (invocation) => [
            for (final sound
                in invocation.positionalArguments.single as List<AudioEvent>)
              if (sound != blockedLater) sound,
          ],
        );
        container.read(blocklistVersionProvider.notifier).increment();

        expect(
          container.read(trendingSoundsProvider).requireValue.sounds,
          [kept],
        );
        verify(
          () => mockRepository.fetchTrendingSounds(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).called(1);
      });

      group('loadMore', () {
        final newest = createTestAudioEvent(id: 'newest', createdAt: 300);
        final older = createTestAudioEvent(id: 'older', createdAt: 200);
        final oldest = createTestAudioEvent(id: 'oldest', createdAt: 100);

        test('adds the sounds published up to the oldest it has', () async {
          stubPages([
            [newest, older],
            // `until` takes in its own second, so the oldest comes again.
            [older, oldest],
          ]);
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);

          await container.read(trendingSoundsProvider.notifier).loadMore();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.pages, [
            [newest, older],
            [oldest],
          ]);
          expect(result.hasMore, isTrue);
          expect(result.isLoadingMore, isFalse);
          verify(
            () => mockRepository.fetchTrendingSounds(limit: 100, until: 200),
          ).called(1);
        });

        test('keeps a block made while a page loaded', () async {
          final page = Completer<List<AudioEvent>>();
          var call = 0;
          when(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => call++ == 0 ? [newest, older] : page.future,
          );
          final container = buildContainer();
          final subscription = container.listen(
            trendingSoundsProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          await container.read(trendingSoundsProvider.future);

          final loading = container
              .read(trendingSoundsProvider.notifier)
              .loadMore();
          when(() => mockRepository.withoutBlockedAuthors(any())).thenAnswer(
            (invocation) => [
              for (final sound
                  in invocation.positionalArguments.single as List<AudioEvent>)
                if (sound != older) sound,
            ],
          );
          container.read(blocklistVersionProvider.notifier).increment();
          page.complete([oldest]);
          await loading;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            [newest, oldest],
          );
        });

        test('ends the list once a page adds nothing new', () async {
          stubPages([
            [newest, older],
            [older],
          ]);
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);

          await container.read(trendingSoundsProvider.notifier).loadMore();
          await container.read(trendingSoundsProvider.notifier).loadMore();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.sounds, [newest, older]);
          expect(result.hasMore, isFalse);
          verify(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(2);
        });

        test('keeps what loaded and ends the list when a page fails', () async {
          var call = 0;
          when(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async {
            if (call++ > 0) throw Exception('relay down');
            return [newest];
          });
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);

          await container.read(trendingSoundsProvider.notifier).loadMore();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.sounds, [newest]);
          expect(result.hasMore, isFalse);
          expect(result.isLoadingMore, isFalse);
        });

        test('asks once while a page is loading', () async {
          final page = Completer<List<AudioEvent>>();
          var call = 0;
          when(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) async => call++ == 0 ? [newest] : page.future);
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);
          final notifier = container.read(trendingSoundsProvider.notifier);

          final first = notifier.loadMore();
          expect(
            container.read(trendingSoundsProvider).requireValue.isLoadingMore,
            isTrue,
          );
          await notifier.loadMore();
          page.complete([oldest]);
          await first;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            [newest, oldest],
          );
          expect(call, 2);
        });

        test('drops a page that lands after the list started over', () async {
          final page = Completer<List<AudioEvent>>();
          var call = 0;
          when(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => switch (call++) {
              1 => page.future,
              _ => [newest],
            },
          );
          final container = buildContainer();
          final subscription = container.listen(
            trendingSoundsProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          await container.read(trendingSoundsProvider.future);

          final loading = container
              .read(trendingSoundsProvider.notifier)
              .loadMore();
          container.invalidate(trendingSoundsProvider);
          await container.read(trendingSoundsProvider.future);
          page.complete([oldest]);
          await loading;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            [newest],
          );
        });

        test('does nothing before the first page is in', () async {
          final first = Completer<List<AudioEvent>>();
          when(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer((_) => first.future);
          final container = buildContainer();
          final subscription = container.listen(
            trendingSoundsProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);

          await container.read(trendingSoundsProvider.notifier).loadMore();

          verify(
            () => mockRepository.fetchTrendingSounds(
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
          first.complete(const []);
        });
      });
    });

    group('popularSoundsProvider', () {
      setUp(() {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
      });

      ProviderContainer buildContainer() {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      /// A full page of the ranking, of which the relays returned [sounds].
      RankedSounds rankedPage(List<AudioEvent> sounds, {int? ranked}) => (
        sounds: sounds,
        usageCounts: {
          for (var i = 0; i < (ranked ?? SoundsRepository.popularPageSize); i++)
            i < sounds.length ? sounds[i].id : 'ranked-$i': i,
        },
      );

      test('loads further down the ranking as it is scrolled', () async {
        final first = createTestAudioEvent(id: 'first');
        final again = createTestAudioEvent(id: 'again');
        final second = createTestAudioEvent(id: 'second');
        when(
          () => mockRepository.fetchPopularSounds(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (invocation) async => switch (invocation.namedArguments[#offset]) {
            50 => rankedPage([again, second]),
            _ => rankedPage([first, again]),
          },
        );
        final container = buildContainer();

        final firstPage = await container.read(popularSoundsProvider.future);
        expect(firstPage.sounds, [first, again]);
        expect(firstPage.hasMore, isTrue);

        await container.read(popularSoundsProvider.notifier).loadMore();

        final result = container.read(popularSoundsProvider).requireValue;
        expect(result.pages, [
          [first, again],
          [second],
        ]);
        expect(result.usageCounts['second'], 1);
        // The ranking moved, so a sound from the first page came round again.
        verify(() => mockRepository.fetchPopularSounds(offset: 50)).called(1);
      });

      test('pages on from the top after the list started over', () async {
        final first = createTestAudioEvent(id: 'first');
        final second = createTestAudioEvent(id: 'second');
        final stalePage = Completer<RankedSounds>();
        var call = 0;
        when(
          () => mockRepository.fetchPopularSounds(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((invocation) {
          // The first loadMore, overtaken by the rebuild below.
          if (call++ == 1) return stalePage.future;
          return Future.value(switch (invocation.namedArguments[#offset]) {
            50 => rankedPage([second]),
            _ => rankedPage([first]),
          });
        });
        final container = buildContainer();
        final subscription = container.listen(
          popularSoundsProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(popularSoundsProvider.future);

        final stale = container.read(popularSoundsProvider.notifier).loadMore();
        container.invalidate(popularSoundsProvider);
        await container.read(popularSoundsProvider.future);
        stalePage.complete(rankedPage([second]));
        await stale;
        await container.read(popularSoundsProvider.notifier).loadMore();

        expect(container.read(popularSoundsProvider).requireValue.pages, [
          [first],
          [second],
        ]);
        verify(() => mockRepository.fetchPopularSounds(offset: 50)).called(2);
      });

      test('ends where the ranking does', () async {
        final last = createTestAudioEvent(id: 'last');
        when(
          () => mockRepository.fetchPopularSounds(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => rankedPage([last], ranked: 3));

        final result = await buildContainer().read(
          popularSoundsProvider.future,
        );

        expect(result.sounds, [last]);
        expect(result.hasMore, isFalse);
      });
    });

    group('soundByIdProvider', () {
      test('returns sound from repository when found', () async {
        final testSound = createTestAudioEvent(id: 'specific-sound');

        when(
          () => mockRepository.fetchSoundById('specific-sound'),
        ).thenAnswer((_) async => testSound);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider('specific-sound').future,
        );

        expect(result, equals(testSound));
        expect(result?.id, equals('specific-sound'));
      });

      test('returns null for empty eventId', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(soundByIdProvider('').future);

        expect(result, isNull);
        verifyNever(() => mockRepository.fetchSoundById(any()));
      });

      test('returns null when sound not found', () async {
        when(
          () => mockRepository.fetchSoundById('nonexistent'),
        ).thenAnswer((_) async => null);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider('nonexistent').future,
        );

        expect(result, isNull);
      });

      test('returns AudioEvent for existing bundled sound', () async {
        final mockSoundService = MockSoundLibraryService();
        final testVineSound = VineSound(
          id: 'classic-vine-beat',
          title: 'Classic Vine Beat',
          assetPath: 'assets/sounds/classic_vine_beat.mp3',
          duration: const Duration(seconds: 6),
        );

        when(
          () => mockSoundService.getSoundById('classic-vine-beat'),
        ).thenReturn(testVineSound);

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            soundLibraryServiceProvider.overrideWith(
              (ref) async => mockSoundService,
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider(
            '${AudioEvent.bundledMarker}_classic-vine-beat',
          ).future,
        );

        expect(result, isNotNull);
        expect(
          result!.id,
          equals('${AudioEvent.bundledMarker}_classic-vine-beat'),
        );
        expect(result.pubkey, equals(AudioEvent.bundledMarker));
        expect(result.title, equals('Classic Vine Beat'));
        expect(result.isBundled, isTrue);
        verifyNever(() => mockRepository.fetchSoundById(any()));
      });

      test('returns null for nonexistent bundled sound', () async {
        final mockSoundService = MockSoundLibraryService();

        when(
          () => mockSoundService.getSoundById('nonexistent-sound'),
        ).thenReturn(null);

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            soundLibraryServiceProvider.overrideWith(
              (ref) async => mockSoundService,
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider(
            '${AudioEvent.bundledMarker}_nonexistent-sound',
          ).future,
        );

        expect(result, isNull);
        verifyNever(() => mockRepository.fetchSoundById(any()));
        verify(
          () => mockSoundService.getSoundById('nonexistent-sound'),
        ).called(1);
      });

      test('does not query repository for bundled sound IDs', () async {
        final mockSoundService = MockSoundLibraryService();
        final testVineSound = VineSound(
          id: 'test-sound',
          title: 'Test Sound',
          assetPath: 'assets/sounds/test.mp3',
          duration: const Duration(seconds: 3),
        );

        when(
          () => mockSoundService.getSoundById('test-sound'),
        ).thenReturn(testVineSound);

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            soundLibraryServiceProvider.overrideWith(
              (ref) async => mockSoundService,
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundByIdProvider('${AudioEvent.bundledMarker}_test-sound').future,
        );

        expect(result, isNotNull);
        expect(result!.isBundled, isTrue);
        verifyNever(() => mockRepository.fetchSoundById(any()));
        verify(() => mockSoundService.getSoundById('test-sound')).called(1);
      });
    });

    group('soundSearchResultsProvider', () {
      setUp(() {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
        when(
          () => mockRepository.searchSounds(any(), limit: any(named: 'limit')),
        ).thenAnswer((_) async => [createTestAudioEvent(id: 'found')]);
      });

      test('passes a query through to the repository', () async {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundSearchResultsProvider('drums').future,
        );

        expect(result.map((s) => s.id), equals(['found']));
      });

      test('does not search for a query holding a private key', () async {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundSearchResultsProvider(
            'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
          ).future,
        );

        expect(result, isEmpty);
        verifyNever(
          () => mockRepository.searchSounds(any(), limit: any(named: 'limit')),
        );
      });
    });

    group('soundsByCreatorProvider', () {
      test('returns sounds by creator pubkey', () async {
        const creatorPubkey = 'creator-pubkey-123';
        final creatorSounds = [
          createTestAudioEvent(id: 'creator-sound-1', pubkey: creatorPubkey),
          createTestAudioEvent(id: 'creator-sound-2', pubkey: creatorPubkey),
        ];

        when(
          () => mockRepository.fetchSoundsByCreator(creatorPubkey),
        ).thenAnswer((_) async => creatorSounds);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          soundsByCreatorProvider(creatorPubkey).future,
        );

        expect(result.length, equals(2));
        expect(result.every((s) => s.pubkey == creatorPubkey), isTrue);
      });

      test('returns empty list for empty pubkey', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(soundsByCreatorProvider('').future);

        expect(result, isEmpty);
        verifyNever(() => mockRepository.fetchSoundsByCreator(any()));
      });
    });

    group('soundUsageCountProvider', () {
      test('returns usage count from repository', () async {
        when(
          () => mockRepository.fetchVideosUsingSoundCount('audio-123'),
        ).thenAnswer((_) async => 42);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final count = await container.read(
          soundUsageCountProvider('audio-123').future,
        );

        expect(count, equals(42));
      });

      test('returns null when the repository cannot tell', () async {
        when(
          () => mockRepository.fetchVideosUsingSoundCount('audio-123'),
        ).thenAnswer((_) async => null);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final count = await container.read(
          soundUsageCountProvider('audio-123').future,
        );

        expect(count, isNull);
      });

      test('returns 0 for empty audioEventId', () async {
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        final count = await container.read(soundUsageCountProvider('').future);

        expect(count, equals(0));
        verifyNever(() => mockRepository.fetchVideosUsingSoundCount(any()));
      });
    });

    group('trendingSoundUsageCountsProvider', () {
      const audioEventId1 =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
      const audioEventId2 =
          'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';

      ProviderContainer buildContainer(List<AudioEvent> trending) {
        when(
          () => mockRepository.fetchTrendingSounds(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => trending);
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test('resolves the whole list through one repository call', () async {
        when(
          () => mockRepository.fetchVideosUsingSoundCounts(any()),
        ).thenAnswer((_) async => {audioEventId1: 7, audioEventId2: 0});

        final container = buildContainer([
          createTestAudioEvent(id: audioEventId1),
          createTestAudioEvent(id: audioEventId2),
        ]);

        final counts = await container.read(
          trendingSoundUsageCountsProvider.future,
        );

        expect(counts, {audioEventId1: 7, audioEventId2: 0});
        final captured = verify(
          () => mockRepository.fetchVideosUsingSoundCounts(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        expect(
          (captured.single as Iterable<String>).toSet(),
          {audioEventId1, audioEventId2},
        );
      });

      test('asks for the reused event id behind an original sound', () async {
        when(
          () => mockRepository.fetchVideosUsingSoundCounts(any()),
        ).thenAnswer((_) async => {audioEventId1: 3});

        final container = buildContainer([
          createTestAudioEvent(id: 'video_$audioEventId1'),
        ]);

        await container.read(trendingSoundUsageCountsProvider.future);

        final captured = verify(
          () => mockRepository.fetchVideosUsingSoundCounts(captureAny()),
        ).captured;
        expect((captured.single as Iterable<String>).toSet(), {audioEventId1});
      });

      test('never queries for sounds with no referenceable event', () async {
        final container = buildContainer([
          createTestAudioEvent(id: '${AudioEvent.bundledMarker}_wednesday'),
          createTestAudioEvent(id: 'local-import-not-published'),
        ]);

        final counts = await container.read(
          trendingSoundUsageCountsProvider.future,
        );

        expect(counts, isEmpty);
        verifyNever(() => mockRepository.fetchVideosUsingSoundCounts(any()));
      });
    });

    group('divineSoundsProvider', () {
      test("hands over the repository's Divine sounds", () async {
        final divine = createTestAudioEvent(id: 'divine-sound');
        when(
          () => mockRepository.fetchDivineSounds(),
        ).thenAnswer((_) async => [divine]);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        expect(await container.read(divineSoundsProvider.future), [divine]);
      });
    });

    group('forYouSoundsProvider', () {
      late _MockFollowRepository followRepository;

      setUp(() {
        followRepository = _MockFollowRepository();
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
      });

      ProviderContainer buildContainer(List<String> following) {
        when(() => followRepository.followingPubkeys).thenReturn(following);
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            followRepositoryProvider.overrideWithValue(followRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      void stubCreatorSounds(
        Future<List<AudioEvent>> Function(Invocation invocation) answer,
      ) {
        when(
          () => mockRepository.fetchSoundsByCreators(
            any(),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer(answer);
      }

      test('asks for the sounds of everyone the viewer follows', () async {
        final followed = createTestAudioEvent(id: 'followed-sound');
        stubCreatorSounds((_) async => [followed]);

        final container = buildContainer(const ['alice', 'bob']);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, [followed]);
        expect(result.hasMore, isTrue);
        verify(
          () => mockRepository.fetchSoundsByCreators(const [
            'alice',
            'bob',
          ], limit: 100),
        ).called(1);
      });

      test('leaves out the unnamed sounds nobody reused', () async {
        final named = createTestAudioEvent(id: 'named');
        final unused = createTestAudioEvent(id: 'unused');
        stubCreatorSounds((_) async => [named, unused]);
        when(
          () => mockRepository.withoutUnusedOriginals([named, unused]),
        ).thenAnswer((_) async => [named]);

        final container = buildContainer(const ['alice']);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, [named]);
      });

      test(
        "leaves out Divine's own sounds, which the picker lists already",
        () async {
          final library = createTestAudioEvent(id: 'divine-library-sound')
              .copyWith(pubkey: kHqPubkeyHex);
          final hqVideoSound = createTestAudioEvent(id: 'hq-video-sound')
              .copyWith(
                pubkey: kHqPubkeyHex,
                sourceVideoReference: '34236:$kHqPubkeyHex:clip',
              );
          stubCreatorSounds((_) async => [library, hqVideoSound]);

          final container = buildContainer(const [kHqPubkeyHex]);

          final result = await container.read(forYouSoundsProvider.future);
          expect(result.sounds, [hqVideoSound]);
        },
      );

      test('leaves out the sounds of authors the viewer blocked', () async {
        final kept = createTestAudioEvent(id: 'kept');
        final muted = createTestAudioEvent(id: 'muted');
        stubCreatorSounds((_) async => [kept, muted]);
        when(
          () => mockRepository.withoutBlockedAuthors([kept, muted]),
        ).thenReturn([kept]);

        final container = buildContainer(const ['alice']);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, [kept]);
      });

      test('loads older sounds as it is scrolled', () async {
        final newer = createTestAudioEvent(id: 'newer', createdAt: 200);
        final older = createTestAudioEvent(id: 'older', createdAt: 100);
        stubCreatorSounds(
          (invocation) async =>
              invocation.namedArguments[#until] == null ? [newer] : [older],
        );
        final container = buildContainer(const ['alice']);
        await container.read(forYouSoundsProvider.future);

        await container.read(forYouSoundsProvider.notifier).loadMore();

        expect(container.read(forYouSoundsProvider).requireValue.pages, [
          [newer],
          [older],
        ]);
        verify(
          () => mockRepository.fetchSoundsByCreators(
            const ['alice'],
            limit: 100,
            until: 200,
          ),
        ).called(1);
      });

      test('outlives the picker for five minutes, then asks again', () {
        fakeAsync((async) {
          stubCreatorSounds((_) async => const []);
          final container = buildContainer(const ['alice']);

          // Each read opens and closes the picker: nothing listens after it.
          container.read(forYouSoundsProvider.future).ignore();
          async.elapse(const Duration(minutes: 4));
          container.read(forYouSoundsProvider.future).ignore();
          async.flushMicrotasks();
          verify(
            () => mockRepository.fetchSoundsByCreators(
              any(),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);

          async.elapse(const Duration(minutes: 2));
          container.read(forYouSoundsProvider.future).ignore();
          async.flushMicrotasks();
          verify(
            () => mockRepository.fetchSoundsByCreators(
              any(),
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).called(1);
        });
      });

      test('queries nothing while the viewer follows nobody', () async {
        final container = buildContainer(const []);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, isEmpty);
        expect(result.hasMore, isFalse);
        verifyNever(
          () => mockRepository.fetchSoundsByCreators(
            any(),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        );
      });
    });

    group('trendingSoundCoversProvider', () {
      const authorA =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
      const authorB =
          'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
      const verticalReference = '34236:$authorA:clip-a';
      const normalReference = '34235:$authorB:clip-b';
      const deletedReference = '34236:$authorA:deleted-clip';

      late _MockVideosRepository videosRepository;

      setUp(() {
        videosRepository = _MockVideosRepository();
      });

      VideoEvent sourceVideo(String pubkey, String dTag) => VideoEvent(
        id: 'video-$dTag',
        pubkey: pubkey,
        createdAt: 1704067200,
        content: '',
        timestamp: DateTime.utc(2024),
        addressableDTag: dTag,
        thumbnailUrl: 'https://example.com/$dTag.jpg',
      );

      ProviderContainer buildContainer(List<AudioEvent> trending) {
        when(
          () => mockRepository.fetchTrendingSounds(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) async => trending);
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            videosRepositoryProvider.overrideWithValue(videosRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      test(
        'maps each sound to its source video through one lookup',
        () async {
          when(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenAnswer(
            (_) async => (
              videos: [
                sourceVideo(authorA, 'clip-a'),
                sourceVideo(authorB, 'clip-b'),
              ],
              complete: true,
            ),
          );

          final container = buildContainer([
            for (final (index, reference) in const [
              verticalReference,
              normalReference,
              deletedReference,
            ].indexed)
              createTestAudioEvent(
                id: 'sound-$index',
              ).copyWith(sourceVideoReference: reference),
          ]);

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(covers, {
            verticalReference: const SoundCover(
              imageUrl: 'https://example.com/clip-a.jpg',
            ),
            normalReference: const SoundCover(
              imageUrl: 'https://example.com/clip-b.jpg',
            ),
            deletedReference: null,
          });
          final captured = verify(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              captureAny(),
              includeFeedShape: false,
            ),
          ).captured;
          expect(captured, hasLength(1));
          expect((captured.single as List<String>).toSet(), {
            verticalReference,
            normalReference,
            deletedReference,
          });
        },
      );

      test('looks up only the sounds a new page added', () async {
        final newer = createTestAudioEvent(
          id: 'newer',
          createdAt: 200,
        ).copyWith(sourceVideoReference: verticalReference);
        final older = createTestAudioEvent(
          id: 'older',
          createdAt: 100,
        ).copyWith(sourceVideoReference: normalReference);
        final container = buildContainer([newer]);
        when(
          () => mockRepository.fetchTrendingSounds(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.namedArguments[#until] == null ? [newer] : [older],
        );
        when(
          () => videosRepository.getVideosFromRelaysByAddressableIds(
            any(),
            includeFeedShape: any(named: 'includeFeedShape'),
          ),
        ).thenAnswer(
          (invocation) async => (
            videos: [
              if ((invocation.positionalArguments.single as List<String>)
                  .contains(verticalReference))
                sourceVideo(authorA, 'clip-a'),
              sourceVideo(authorB, 'clip-b'),
            ],
            complete: true,
          ),
        );
        final subscription = container.listen(
          trendingSoundCoversProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(trendingSoundCoversProvider.future);

        await container.read(trendingSoundsProvider.notifier).loadMore();
        // The covers hear of the new page once its sounds have settled.
        await pumpEventQueue();
        final covers = await container.read(trendingSoundCoversProvider.future);

        expect(covers.keys, {verticalReference, normalReference});
        expect(covers[verticalReference], isNotNull);
        expect(covers[normalReference], isNotNull);
        final lookups = verify(
          () => videosRepository.getVideosFromRelaysByAddressableIds(
            captureAny(),
            includeFeedShape: false,
          ),
        ).captured;
        expect(lookups, [
          [verticalReference],
          [normalReference],
        ]);
      });

      test('leaves sounds out when the lookup fails, to ask again', () async {
        var lookups = 0;
        when(
          () => videosRepository.getVideosFromRelaysByAddressableIds(
            any(),
            includeFeedShape: any(named: 'includeFeedShape'),
          ),
        ).thenAnswer((_) async {
          if (lookups++ == 0) throw Exception('relay down');
          return (videos: [sourceVideo(authorA, 'clip-a')], complete: true);
        });
        final container = buildContainer([
          createTestAudioEvent(
            id: 'sound',
          ).copyWith(sourceVideoReference: verticalReference),
        ]);
        final subscription = container.listen(
          trendingSoundCoversProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        expect(await container.read(trendingSoundCoversProvider.future), {});

        container.invalidate(trendingSoundCoversProvider);
        final covers = await container.read(trendingSoundCoversProvider.future);
        expect(covers[verticalReference], isNotNull);
      });

      test(
        'does not take a video a relay never delivered for gone',
        () async {
          var lookups = 0;
          when(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenAnswer(
            (_) async => lookups++ == 0
                // A relay ran out of time before sending this video.
                ? (videos: <VideoEvent>[], complete: false)
                : (videos: [sourceVideo(authorA, 'clip-a')], complete: true),
          );
          final container = buildContainer([
            createTestAudioEvent(
              id: 'sound',
            ).copyWith(sourceVideoReference: verticalReference),
          ]);
          final subscription = container.listen(
            trendingSoundCoversProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);

          final unfinished = await container.read(
            trendingSoundCoversProvider.future,
          );
          expect(unfinished.containsKey(verticalReference), isFalse);

          container.invalidate(trendingSoundCoversProvider);
          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );
          expect(covers[verticalReference], isNotNull);
        },
      );

      test('never looks up videos when no sound came from one', () async {
        final container = buildContainer([
          createTestAudioEvent(id: '${AudioEvent.bundledMarker}_wednesday'),
        ]);

        final covers = await container.read(trendingSoundCoversProvider.future);

        expect(covers, isEmpty);
        verifyNever(
          () => videosRepository.getVideosFromRelaysByAddressableIds(
            any(),
            includeFeedShape: any(named: 'includeFeedShape'),
          ),
        );
      });
    });

    group('soundsStreamProvider', () {
      test('provides stream from repository', () async {
        final streamController = StreamController<List<AudioEvent>>.broadcast();
        final testSounds = [createTestAudioEvent(id: 'stream-sound-1')];

        when(
          () => mockRepository.soundsStream,
        ).thenAnswer((_) => streamController.stream);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await streamController.close();
        });

        // Start listening to provider
        final subscription = container.listen(soundsStreamProvider, (_, _) {});

        // Emit data through stream
        streamController.add(testSounds);

        // Allow stream to propagate
        await container.read(soundsStreamProvider.future);

        final state = container.read(soundsStreamProvider);
        expect(state.hasValue, isTrue);
        expect(state.value?.length, equals(1));
        expect(state.value?.first.id, equals('stream-sound-1'));

        subscription.close();
      });
    });
  });
}

void _ownerExceptionTests() {
  group('audioReuseConsent owner exception', () {
    const ownerPubkey = 'owner-pubkey-hex';

    ProviderContainer buildContainer(String? viewerPubkey) {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_StubAuthService(viewerPubkey)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'a creator may reuse their own sound even without a consent tag',
      () async {
        // The picker used to skip this check while the detail screen applied
        // it, so one creator was told the same private sound was both usable
        // and unusable. The provider is now the only place it lives.
        // No consent tag and no explicit denial — the "unknown, ask the
        // resolver" shape a legacy sound loads as.
        final ownSound = createTestAudioEvent(
          id: 'own',
          pubkey: ownerPubkey,
        ).copyWith(allowsReuse: false);
        expect(ownSound.allowsReuse, isFalse);
        expect(ownSound.hasExplicitReuseConsent, isFalse);

        final container = buildContainer(ownerPubkey);
        await expectLater(
          container.read(audioReuseConsentProvider(ownSound).future),
          completion(isTrue),
        );
      },
    );

    test('a signed-out viewer gets no owner exception', () async {
      final sound = createTestAudioEvent(
        id: 'own',
        pubkey: ownerPubkey,
      ).copyWith(allowsReuse: false, hasExplicitReuseConsent: true);
      final container = buildContainer(null);
      await expectLater(
        container.read(audioReuseConsentProvider(sound).future),
        completion(isFalse),
      );
    });

    test('an explicit decline still permits the sound owner', () async {
      final sound = createTestAudioEvent(
        id: 'own',
        pubkey: ownerPubkey,
      ).copyWith(allowsReuse: false, hasExplicitReuseConsent: true);
      final container = buildContainer(ownerPubkey);
      await expectLater(
        container.read(audioReuseConsentProvider(sound).future),
        completion(isTrue),
      );
    });

    test('a malformed marker still permits the sound owner', () async {
      final sound = createTestAudioEvent(
        id: 'own',
        pubkey: ownerPubkey,
      ).copyWith(allowsReuse: false, hasExplicitReuseConsent: false);
      final container = buildContainer(ownerPubkey);

      await expectLater(
        container.read(audioReuseConsentProvider(sound).future),
        completion(isTrue),
      );
    });

    test('a provisional grant still requires current verification', () async {
      final sound = createTestAudioEvent(
        id: 'theirs',
        pubkey: ownerPubkey,
      ).copyWith(allowsReuse: true, requiresCurrentReuseVerification: true);

      expect(audioReuseTermsFromEvent(sound), isNull);
    });

    test("another creator's sound does not get the owner exception", () async {
      final sound = createTestAudioEvent(
        id: 'theirs',
        pubkey: ownerPubkey,
      ).copyWith(allowsReuse: false, hasExplicitReuseConsent: true);
      final container = buildContainer('a-different-viewer-pubkey');
      await expectLater(
        container.read(audioReuseConsentProvider(sound).future),
        completion(isFalse),
      );
    });
  });
}
