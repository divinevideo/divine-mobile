// ABOUTME: Tests for sounds_providers.dart Riverpod state management
// ABOUTME: Verifies SoundsRepository provider, trending sounds, and selected sound state

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:unified_logger/unified_logger.dart';
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
  when(() => repository.withoutLibrarySounds(any())).thenAnswer(
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

/// A page of a sound search that found [sounds], answered by [source].
SoundSearchResults searchPage(
  List<AudioEvent> sounds, {
  SoundSearchSource source = SoundSearchSource.funnelcake,
  SoundSearchRelays relays = SoundSearchRelays.notAsked,
  Map<String, int> usageCounts = const {},
  String? nextCursor,
}) => (
  sounds: sounds,
  source: source,
  relays: relays,
  usageCounts: usageCounts,
  nextCursor: nextCursor,
);

/// A page of a list from Funnelcake's sound index holding [sounds].
SoundIndexPage indexPage(
  List<AudioEvent> sounds, {
  Map<String, int> usageCounts = const {},
  String? nextCursor,
}) => (sounds: sounds, usageCounts: usageCounts, nextCursor: nextCursor);

/// [sounds] followed by enough others to fill the screen, so a list whose
/// first page this is does not load more by itself.
List<AudioEvent> filledUp(List<AudioEvent> sounds) => [
  ...sounds,
  for (var i = sounds.length; i < 20; i++)
    createTestAudioEvent(id: 'filler-$i'),
];

void main() {
  _ownerExceptionTests();

  group('SoundsProviders', () {
    late MockNostrClient mockNostrClient;
    late MockSoundsRepository mockRepository;

    setUp(() {
      registerFallbackValue(const <String>[]);
      registerFallbackValue(const <AudioEvent>[]);
      registerFallbackValue(SoundKind.music);
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

      /// Answers each newest-sounds fetch with the next of [pages], each
      /// pointing at the one after it.
      void stubPages(List<List<AudioEvent>> pages) {
        var call = 0;
        when(
          () => mockRepository.fetchNewestSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async {
          final index = call++;
          return indexPage(pages[index], nextCursor: 'page-${index + 1}');
        });
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
        verify(() => mockRepository.fetchNewestSounds()).called(1);
      });

      test("keeps the index's usage counts", () async {
        when(
          () => mockRepository.fetchNewestSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => indexPage(
            filledUp([createTestAudioEvent(id: 'used')]),
            usageCounts: {'used': 4},
          ),
        );

        final result = await buildContainer().read(
          trendingSoundsProvider.future,
        );

        expect(result.usageCounts, {'used': 4});
        expect(result.hasMore, isFalse);
      });

      test('leaves out the imported library', () async {
        final community = createTestAudioEvent(id: 'community');
        final imported = createTestAudioEvent(id: 'imported');
        stubPages([
          [community, imported],
        ]);
        when(
          () => mockRepository.withoutLibrarySounds([community, imported]),
        ).thenReturn([community]);

        final result = await buildContainer().read(
          trendingSoundsProvider.future,
        );

        expect(result.sounds, [community]);
      });

      test('drops a newly blocked author from the loaded pages, '
          'without loading them again', () async {
        final kept = createTestAudioEvent(id: 'kept');
        final blockedLater = createTestAudioEvent(id: 'blocked-later');
        final page = filledUp([kept, blockedLater]);
        stubPages([page]);
        final container = buildContainer();
        final subscription = container.listen(
          trendingSoundsProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(trendingSoundsProvider.future);
        expect(
          container.read(trendingSoundsProvider).requireValue.sounds,
          page,
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
          [
            for (final sound in page)
              if (sound != blockedLater) sound,
          ],
        );
        verify(
          () => mockRepository.fetchNewestSounds(
            cursor: any(named: 'cursor'),
          ),
        ).called(1);
      });

      group('filling the screen', () {
        test(
          'loads on by itself while it holds less than a screenful',
          () async {
            final first = createTestAudioEvent(id: 'first', createdAt: 300);
            final second = createTestAudioEvent(id: 'second', createdAt: 200);
            final rest = [
              for (var i = 0; i < 20; i++)
                createTestAudioEvent(id: 'rest-$i', createdAt: 100),
            ];
            stubPages([
              [first],
              [second],
              rest,
            ]);
            final container = buildContainer();

            await container.read(trendingSoundsProvider.future);
            await pumpEventQueue();

            final result = container.read(trendingSoundsProvider).requireValue;
            expect(result.pages, [
              [first],
              [second],
              rest,
            ]);
            expect(result.hasMore, isTrue);
            verify(
              () => mockRepository.fetchNewestSounds(cursor: 'page-2'),
            ).called(1);
          },
        );

        test('stops after five pages that each kept little', () async {
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer((_) async {
            call++;
            return indexPage(
              [createTestAudioEvent(id: 'sound-$call', createdAt: -call)],
              nextCursor: 'page-$call',
            );
          });
          final container = buildContainer();

          await container.read(trendingSoundsProvider.future);
          await pumpEventQueue();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.pages, hasLength(5));
          expect(result.hasMore, isTrue);
          expect(call, 5);
        });
      });

      group('loadMore', () {
        final newest = createTestAudioEvent(id: 'newest', createdAt: 300);
        final older = createTestAudioEvent(id: 'older', createdAt: 200);
        final oldest = createTestAudioEvent(id: 'oldest', createdAt: 100);

        test('adds the page the cursor points at, without the sounds it '
            'has', () async {
          final first = filledUp([newest, older]);
          stubPages([
            first,
            [older, oldest],
          ]);
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);

          await container.read(trendingSoundsProvider.notifier).loadMore();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.pages, [
            first,
            [oldest],
          ]);
          expect(result.hasMore, isTrue);
          expect(result.isLoadingMore, isFalse);
          verify(
            () => mockRepository.fetchNewestSounds(cursor: 'page-1'),
          ).called(1);
        });

        test('keeps a block made while a page loaded', () async {
          final first = filledUp([newest, older]);
          final page = Completer<SoundIndexPage>();
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (_) async => call++ == 0
                ? indexPage(first, nextCursor: 'next')
                : page.future,
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
          page.complete(indexPage([oldest]));
          await loading;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            [
              for (final sound in first)
                if (sound != older) sound,
              oldest,
            ],
          );
        });

        test('ends the list with the last page', () async {
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (_) async => call++ == 0
                ? indexPage([newest], nextCursor: 'next')
                : indexPage([older]),
          );
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);
          await pumpEventQueue();

          await container.read(trendingSoundsProvider.notifier).loadMore();

          final result = container.read(trendingSoundsProvider).requireValue;
          expect(result.sounds, [newest, older]);
          expect(result.hasMore, isFalse);
          expect(call, 2);
        });

        test('keeps what loaded and ends the list when a page fails', () async {
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer((_) async {
            if (call++ > 0) throw Exception('index down');
            return indexPage([newest], nextCursor: 'next');
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
          final first = filledUp([newest]);
          final page = Completer<SoundIndexPage>();
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (_) async => call++ == 0
                ? indexPage(first, nextCursor: 'next')
                : page.future,
          );
          final container = buildContainer();
          await container.read(trendingSoundsProvider.future);
          final notifier = container.read(trendingSoundsProvider.notifier);

          final loading = notifier.loadMore();
          expect(
            container.read(trendingSoundsProvider).requireValue.isLoadingMore,
            isTrue,
          );
          await notifier.loadMore();
          page.complete(indexPage([oldest]));
          await loading;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            [...first, oldest],
          );
          expect(call, 2);
        });

        test('drops a page that lands after the list started over', () async {
          final page = Completer<SoundIndexPage>();
          var call = 0;
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (_) async => switch (call++) {
              1 => page.future,
              _ => indexPage(filledUp([newest]), nextCursor: 'next'),
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
          page.complete(indexPage([oldest]));
          await loading;

          expect(
            container.read(trendingSoundsProvider).requireValue.sounds,
            filledUp([newest]),
          );
        });

        test('waits for the list to load anew before paging', () async {
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (invocation) async => invocation.namedArguments[#cursor] == null
                ? indexPage(filledUp([newest]), nextCursor: 'next')
                : indexPage([older]),
          );
          final container = buildContainer();
          final subscription = container.listen(
            trendingSoundsProvider,
            (_, _) {},
          );
          addTearDown(subscription.close);
          await container.read(trendingSoundsProvider.future);

          container.invalidate(trendingSoundsProvider);
          await container.read(trendingSoundsProvider.notifier).loadMore();
          final result = await container.read(trendingSoundsProvider.future);

          // Paged while it reloaded, the list would ask for its second page
          // before its first and end there.
          expect(result.sounds, filledUp([newest]));
          expect(result.hasMore, isTrue);
        });

        test('does nothing before the first page is in', () async {
          final first = Completer<SoundIndexPage>();
          when(
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
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
            () => mockRepository.fetchNewestSounds(
              cursor: any(named: 'cursor'),
            ),
          ).called(1);
          first.complete(indexPage(const []));
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

      /// A page of the ranking holding [sounds], each used once.
      SoundIndexPage rankedPage(
        List<AudioEvent> sounds, {
        String? nextCursor,
      }) => indexPage(
        sounds,
        usageCounts: {for (final sound in sounds) sound.id: 1},
        nextCursor: nextCursor,
      );

      test('loads further down the ranking as it is scrolled', () async {
        final first = createTestAudioEvent(id: 'first');
        final again = createTestAudioEvent(id: 'again');
        final second = createTestAudioEvent(id: 'second');
        when(
          () => mockRepository.fetchPopularSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (invocation) async => switch (invocation.namedArguments[#cursor]) {
            null => rankedPage([first, again], nextCursor: 'o:50'),
            _ => rankedPage([again, second]),
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
        expect(result.hasMore, isFalse);
        // The ranking moved, so a sound from the first page came round again.
        verify(
          () => mockRepository.fetchPopularSounds(cursor: 'o:50'),
        ).called(1);
      });

      test('pages on from the top after the list started over', () async {
        final first = createTestAudioEvent(id: 'first');
        final second = createTestAudioEvent(id: 'second');
        final stalePage = Completer<SoundIndexPage>();
        var call = 0;
        when(
          () => mockRepository.fetchPopularSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((invocation) {
          // The first loadMore, overtaken by the rebuild below.
          if (call++ == 1) return stalePage.future;
          return Future.value(switch (invocation.namedArguments[#cursor]) {
            null => rankedPage([first], nextCursor: 'o:50'),
            _ => rankedPage([second], nextCursor: 'o:100'),
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
        stalePage.complete(rankedPage([second], nextCursor: 'o:100'));
        await stale;
        await container.read(popularSoundsProvider.notifier).loadMore();

        expect(container.read(popularSoundsProvider).requireValue.pages, [
          [first],
          [second],
        ]);
        verify(
          () => mockRepository.fetchPopularSounds(cursor: 'o:50'),
        ).called(2);
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
          () => mockRepository.searchSounds(
            any(),
            kind: any(named: 'kind'),
            followedBy: any(named: 'followedBy'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => searchPage(
            [createTestAudioEvent(id: 'found')],
            source: SoundSearchSource.relays,
            relays: SoundSearchRelays.timedOut,
          ),
        );
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

        expect(result.sounds.map((s) => s.id), equals(['found']));
        expect(
          result.relays,
          SoundSearchRelays.timedOut,
          reason: 'the search telemetry tells a relay answer from a fallback',
        );
      });

      test('narrows the search to the kind it is given', () async {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          soundSearchResultsProvider('rain', kind: SoundKind.effect).future,
        );

        verify(
          () => mockRepository.searchSounds('rain', kind: SoundKind.effect),
        ).called(1);
      });

      test('searches within the followed accounts for For you', () async {
        final followRepository = _MockFollowRepository();
        when(
          () => followRepository.followingPubkeys,
        ).thenReturn(const ['alice', 'bob']);
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            followRepositoryProvider.overrideWithValue(followRepository),
          ],
        );
        addTearDown(container.dispose);

        await container.read(
          soundSearchResultsProvider('rain', followed: true).future,
        );

        verify(
          () => mockRepository.searchSounds(
            'rain',
            followedBy: const ['alice', 'bob'],
          ),
        ).called(1);
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

        expect(result.sounds, isEmpty);
        expect(result.relays, SoundSearchRelays.notAsked);
        verifyNever(
          () => mockRepository.searchSounds(any(), limit: any(named: 'limit')),
        );
      });
    });

    group('soundSearchPagesProvider with Funnelcake failing a later page', () {
      // The client's exceptions name the request's URL, and a search URL
      // holds the words typed. A page that fails after the first must not
      // put them in the captured logs.
      const query = 'rainy lullaby';

      for (final (name, failLater)
          in <(String, Future<http.Response> Function())>[
            ('an error status', () async => http.Response('down', 503)),
            ('a timeout', () async => throw TimeoutException('slow')),
          ]) {
        test('keeps the query out of the logs after $name', () async {
          var requests = 0;
          final client = FunnelcakeApiClient(
            baseUrl: 'https://api.example',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient((request) async {
              if (requests++ > 0) return failLater();
              return http.Response(
                jsonEncode({
                  'data': <Object>[],
                  'pagination': {'next_cursor': 'o:50', 'has_more': true},
                }),
                200,
              );
            }),
          );
          final repository = SoundsRepository(
            nostrClient: MockNostrClient(),
            funnelcakeApiClient: client,
          );
          addTearDown(repository.dispose);
          final container = ProviderContainer(
            overrides: [soundsRepositoryProvider.overrideWithValue(repository)],
          );
          addTearDown(container.dispose);
          final provider = soundSearchPagesProvider(query);
          final subscription = container.listen(provider, (_, _) {});
          addTearDown(subscription.close);
          final logsBefore =
              (await LogCaptureService().getAllLogsAsText()).length;

          expect((await container.read(provider.future)).hasMore, isTrue);
          await container.read(provider.notifier).loadMore();

          expect(container.read(provider).requireValue.hasMore, isFalse);
          expect(requests, greaterThan(1));
          final logs = (await LogCaptureService().getAllLogsAsText()).skip(
            logsBefore,
          );
          expect(
            logs.where((line) => line.contains('Could not load more sounds')),
            isNotEmpty,
          );
          expect(logs.where((line) => line.contains('rainy')), isEmpty);
        });
      }
    });

    group('soundSearchPagesProvider', () {
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

      void answerSearch(
        SoundSearchResults Function(String? cursor) pageAt,
      ) {
        when(
          () => mockRepository.searchSounds(
            any(),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (invocation) async =>
              pageAt(invocation.namedArguments[#cursor] as String?),
        );
      }

      test('follows the cursor as the list is scrolled', () async {
        final best = createTestAudioEvent(id: 'best');
        final again = createTestAudioEvent(id: 'again');
        final next = createTestAudioEvent(id: 'next');
        answerSearch(
          (cursor) => switch (cursor) {
            null => searchPage(
              [best, again],
              usageCounts: {'best': 9, 'again': 2},
              nextCursor: '50',
            ),
            _ => searchPage([again, next], usageCounts: {'next': 4}),
          },
        );
        final container = buildContainer();
        final subscription = container.listen(
          soundSearchPagesProvider('cool'),
          (_, _) {},
        );
        addTearDown(subscription.close);

        final first = await container.read(
          soundSearchPagesProvider('cool').future,
        );
        expect(first.sounds, [best, again]);
        expect(first.hasMore, isTrue);

        await container
            .read(soundSearchPagesProvider('cool').notifier)
            .loadMore();

        final result = container
            .read(soundSearchPagesProvider('cool'))
            .requireValue;
        // The ranking moved, so a sound from the first page came round again.
        expect(result.pages, [
          [best, again],
          [next],
        ]);
        expect(result.usageCounts, {'best': 9, 'again': 2, 'next': 4});
        expect(result.hasMore, isFalse);
        verify(() => mockRepository.searchSounds('cool', cursor: '50'))
            .called(1);
      });

      test('keeps loading past a page that found nothing', () async {
        final late = createTestAudioEvent(id: 'late');
        answerSearch(
          (cursor) => switch (cursor) {
            null => searchPage(const [], nextCursor: '25'),
            _ => searchPage([late]),
          },
        );
        final container = buildContainer();
        final subscription = container.listen(
          soundSearchPagesProvider('cool'),
          (_, _) {},
        );
        addTearDown(subscription.close);

        final first = await container.read(
          soundSearchPagesProvider('cool').future,
        );
        expect(first.sounds, isEmpty);
        expect(first.canLoadMore, isTrue);

        await container
            .read(soundSearchPagesProvider('cool').notifier)
            .loadMore();

        expect(
          container.read(soundSearchPagesProvider('cool')).requireValue.sounds,
          [late],
        );
      });

      test('holds a relay answer as its only page', () async {
        final found = createTestAudioEvent(id: 'found');
        answerSearch(
          (_) => searchPage(
            [found],
            source: SoundSearchSource.relays,
            relays: SoundSearchRelays.answered,
          ),
        );

        final result = await buildContainer().read(
          soundSearchPagesProvider('cool').future,
        );

        expect(result.sounds, [found]);
        expect(result.hasMore, isFalse);
      });

      test('reads no repository for a blank query', () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final result = await container.read(
          soundSearchPagesProvider('  ').future,
        );

        expect(result.sounds, isEmpty);
        expect(result.hasMore, isFalse);
      });
    });

    group('soundsOfKindProvider', () {
      late _MockFollowRepository followRepository;

      setUp(() {
        followRepository = _MockFollowRepository();
        when(() => followRepository.followingPubkeys).thenReturn(const []);
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
      });

      ProviderContainer buildContainer() {
        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            followRepositoryProvider.overrideWithValue(followRepository),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      SoundIndexPage indexPage(
        List<AudioEvent> sounds, {
        String? nextCursor,
      }) => (
        sounds: sounds,
        usageCounts: {for (final sound in sounds) sound.id: 1},
        nextCursor: nextCursor,
      );

      test('pages the popular sounds of a kind by their cursor', () async {
        final first = createTestAudioEvent(id: 'first');
        final again = createTestAudioEvent(id: 'again');
        final next = createTestAudioEvent(id: 'next');
        when(
          () => mockRepository.fetchPopularSounds(
            kind: SoundKind.effect,
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (invocation) async => switch (invocation.namedArguments[#cursor]) {
            null => indexPage([first, again], nextCursor: 'o:50'),
            _ => indexPage([again, next]),
          },
        );
        final container = buildContainer();
        final provider = soundsOfKindProvider(
          SoundKind.effect,
          SoundListOfKind.popular,
        );
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);

        final firstPage = await container.read(provider.future);
        expect(firstPage.hasMore, isTrue);
        await container.read(provider.notifier).loadMore();

        final result = container.read(provider).requireValue;
        expect(result.pages, [
          [first, again],
          [next],
        ]);
        expect(result.hasMore, isFalse);
        verify(
          () => mockRepository.fetchPopularSounds(
            kind: SoundKind.effect,
            cursor: 'o:50',
          ),
        ).called(1);
      });

      test('lists the newest sounds of a kind', () async {
        final newest = createTestAudioEvent(id: 'newest');
        when(
          () => mockRepository.fetchNewestSounds(
            kind: SoundKind.music,
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => indexPage([newest]));

        final result = await buildContainer().read(
          soundsOfKindProvider(SoundKind.music, SoundListOfKind.newest).future,
        );

        expect(result.sounds, [newest]);
        expect(result.usageCounts, {'newest': 1});
      });

      test(
        "lists the followed accounts' sounds without Divine's own",
        () async {
          when(
            () => followRepository.followingPubkeys,
          ).thenReturn(const ['alice', kHqPubkeyHex]);
          final followed = createTestAudioEvent(id: 'followed');
          final divine = createTestAudioEvent(
            id: 'divine',
            pubkey: kHqPubkeyHex,
          );
          when(
            () => mockRepository.fetchFollowedSounds(
              any(),
              kind: SoundKind.effect,
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer((_) async => indexPage([followed, divine]));

          final result = await buildContainer().read(
            soundsOfKindProvider(
              SoundKind.effect,
              SoundListOfKind.followed,
            ).future,
          );

          expect(result.sounds, [followed]);
          verify(
            () => mockRepository.fetchFollowedSounds(const [
              'alice',
              kHqPubkeyHex,
            ], kind: SoundKind.effect),
          ).called(1);
        },
      );
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
          () => mockRepository.fetchFollowedSounds(
            any(),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((invocation) async {
          final sounds = await answer(invocation);
          return indexPage(
            sounds,
            nextCursor: sounds.isEmpty ? null : 'next',
          );
        });
      }

      test('asks for the sounds of everyone the viewer follows', () async {
        final followed = createTestAudioEvent(id: 'followed-sound');
        stubCreatorSounds((_) async => [followed]);

        final container = buildContainer(const ['alice', 'bob']);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, [followed]);
        expect(result.hasMore, isTrue);
        verify(
          () => mockRepository.fetchFollowedSounds(const ['alice', 'bob']),
        ).called(1);
      });

      test('leaves out the imported library of a followed account', () async {
        final followed = createTestAudioEvent(id: 'followed-sound');
        final imported = createTestAudioEvent(id: 'imported');
        stubCreatorSounds((_) async => [followed, imported]);
        when(
          () => mockRepository.withoutLibrarySounds([followed, imported]),
        ).thenReturn([followed]);

        final container = buildContainer(const ['alice']);

        final result = await container.read(forYouSoundsProvider.future);
        expect(result.sounds, [followed]);
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

      test('loads older sounds as it is scrolled', () async {
        final newer = createTestAudioEvent(id: 'newer', createdAt: 200);
        final older = createTestAudioEvent(id: 'older', createdAt: 100);
        final first = filledUp([newer]);
        stubCreatorSounds(
          (invocation) async =>
              invocation.namedArguments[#cursor] == null ? first : [older],
        );
        final container = buildContainer(const ['alice']);
        await container.read(forYouSoundsProvider.future);

        await container.read(forYouSoundsProvider.notifier).loadMore();

        expect(container.read(forYouSoundsProvider).requireValue.pages, [
          first,
          [older],
        ]);
        verify(
          () => mockRepository.fetchFollowedSounds(const [
            'alice',
          ], cursor: 'next'),
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
            () => mockRepository.fetchFollowedSounds(
              any(),
              cursor: any(named: 'cursor'),
            ),
          ).called(1);

          async.elapse(const Duration(minutes: 2));
          container.read(forYouSoundsProvider.future).ignore();
          async.flushMicrotasks();
          verify(
            () => mockRepository.fetchFollowedSounds(
              any(),
              cursor: any(named: 'cursor'),
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
          () => mockRepository.fetchFollowedSounds(
            any(),
            cursor: any(named: 'cursor'),
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
        when(
          () => videosRepository.getVideosByAddressableIds(
            any(),
            includeFeedShape: false,
          ),
        ).thenAnswer((_) async => <VideoEvent>[]);
        when(
          () => videosRepository.refreshAudioReusePolicies(any()),
        ).thenAnswer((_) async => const {});
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

      void stubBothSourceVideos() {
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
      }

      List<AudioEvent> soundsFrom(List<String> references) => [
        for (final (index, reference) in references.indexed)
          createTestAudioEvent(
            id: 'sound-$index',
          ).copyWith(sourceVideoReference: reference),
      ];

      ProviderContainer buildContainer(
        List<AudioEvent> trending, {
        String? viewer,
      }) {
        when(
          () => mockRepository.fetchNewestSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer((_) async => indexPage(trending));
        _keepEverySound(mockRepository);
        when(() => mockRepository.initialize()).thenAnswer((_) async {});
        when(() => mockRepository.dispose()).thenAnswer((_) async {});
        when(
          () => mockRepository.sourceVideosFromIndex(any()),
        ).thenReturn(const {});

        final container = ProviderContainer(
          overrides: [
            soundsRepositoryProvider.overrideWithValue(mockRepository),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            authServiceProvider.overrideWithValue(_StubAuthService(viewer)),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      group('with the source videos Funnelcake sent', () {
        final sentVideo = Event.fromJson({
          'id': 'f' * 64,
          'pubkey': authorA,
          'created_at': 1704067200,
          'kind': 34236,
          'tags': [
            ['d', 'clip-a'],
          ],
          'content': '',
          'sig': 'c' * 128,
        });

        setUp(() => registerFallbackValue(sentVideo));

        test('takes them and asks the relays only about the rest', () async {
          final container = buildContainer(
            soundsFrom(const [
              verticalReference,
              normalReference,
              deletedReference,
            ]),
          );
          when(
            () => mockRepository.sourceVideosFromIndex(any()),
          ).thenReturn({verticalReference: sentVideo, deletedReference: null});
          when(
            () => videosRepository.visibleVideoFromEvent(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenReturn(sourceVideo(authorA, 'clip-a'));
          stubBothSourceVideos();

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
          verify(
            () => videosRepository.visibleVideoFromEvent(
              sentVideo,
              includeFeedShape: false,
            ),
          ).called(1);
          final asked = verify(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              captureAny(),
              includeFeedShape: false,
            ),
          ).captured;
          expect(asked, [
            [normalReference],
          ]);
        });

        test('marks one this viewer may not see as gone, without asking '
            'the relays', () async {
          final container = buildContainer(
            soundsFrom(const [verticalReference]),
          );
          when(
            () => mockRepository.sourceVideosFromIndex(any()),
          ).thenReturn({verticalReference: sentVideo});
          when(
            () => videosRepository.visibleVideoFromEvent(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenReturn(null);

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(covers, {verticalReference: null});
          verifyNever(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          );
        });
      });

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
          () => mockRepository.fetchNewestSounds(
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#cursor] == null
              ? indexPage([newer], nextCursor: 'next')
              : indexPage([older]),
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

      test(
        'keeps a source the action-time fallback finds after relays miss it',
        () async {
          when(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenAnswer((_) async => (videos: <VideoEvent>[], complete: true));
          when(
            () => videosRepository.getVideosByAddressableIds(
              any(),
              includeFeedShape: false,
            ),
          ).thenAnswer((_) async => [sourceVideo(authorA, 'clip-a')]);
          final container = buildContainer(soundsFrom([verticalReference]));

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(
            covers[verticalReference]?.imageUrl,
            'https://example.com/clip-a.jpg',
          );
        },
      );

      test(
        'does not mark a relay-missing source gone when fallback fails',
        () async {
          when(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          ).thenAnswer((_) async => (videos: <VideoEvent>[], complete: true));
          when(
            () => videosRepository.getVideosByAddressableIds(
              any(),
              includeFeedShape: false,
            ),
          ).thenThrow(Exception('fallback unavailable'));
          final container = buildContainer(soundsFrom([verticalReference]));

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(covers.containsKey(verticalReference), isFalse);
        },
      );

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

      test('hands the reuse check the source video a cover came from, so it '
          'asks only for the policy', () async {
        final source = sourceVideo(authorA, 'clip-a');
        when(
          () => videosRepository.getVideosFromRelaysByAddressableIds(
            any(),
            includeFeedShape: any(named: 'includeFeedShape'),
          ),
        ).thenAnswer((_) async => (videos: [source], complete: true));
        when(
          () => videosRepository.refreshAudioReusePolicy(source),
        ).thenAnswer(
          (_) async => const AudioReusePolicy(allowAudioReuse: true),
        );
        final sound = createTestAudioEvent(
          id: 'picked',
        ).copyWith(sourceVideoReference: verticalReference);
        final container = buildContainer([sound]);
        await container.read(trendingSoundCoversProvider.future);

        expect(
          await container.read(audioReuseTermsProvider(sound).future),
          isTrue,
        );
        verifyNever(() => videosRepository.getVideosByAddressableIds(any()));
      });

      test('covers the sounds of every page a search loaded', () async {
        stubBothSourceVideos();
        final [onFirstPage, onSecondPage] = soundsFrom(const [
          verticalReference,
          normalReference,
        ]);
        when(
          () => mockRepository.searchSounds(
            any(),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (invocation) async => invocation.namedArguments[#cursor] == null
              ? searchPage([onFirstPage], nextCursor: '50')
              : searchPage([onSecondPage]),
        );
        final container = buildContainer(const []);
        final subscription = container.listen(
          soundSearchCoversProvider('clip'),
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(soundSearchCoversProvider('clip').future);

        await container
            .read(soundSearchPagesProvider('clip').notifier)
            .loadMore();
        await pumpEventQueue();
        final covers = await container.read(
          soundSearchCoversProvider('clip').future,
        );

        expect(covers.keys, containsAll([verticalReference, normalReference]));
      });

      group('reuse', () {
        test('marks a video whose creator lets no one reuse its sound as '
            'gone, so its row is left out', () async {
          stubBothSourceVideos();
          when(
            () => videosRepository.refreshAudioReusePolicies(any()),
          ).thenAnswer(
            (_) async => {
              verticalReference: const AudioReusePolicy(allowAudioReuse: true),
              normalReference: const AudioReusePolicy(allowAudioReuse: false),
            },
          );
          final container = buildContainer(
            soundsFrom([verticalReference, normalReference]),
          );

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(covers[verticalReference], isNotNull);
          expect(covers.containsKey(normalReference), isTrue);
          expect(covers[normalReference], isNull);
          final asked = verify(
            () => videosRepository.refreshAudioReusePolicies(captureAny()),
          ).captured;
          expect((asked.single as Iterable<String>).toSet(), {
            verticalReference,
            normalReference,
          });
        });

        test("never asks about the viewer's own videos, whose sound they may "
            'always reuse', () async {
          stubBothSourceVideos();
          final container = buildContainer(
            soundsFrom([verticalReference, normalReference]),
            viewer: authorA,
          );

          await container.read(trendingSoundCoversProvider.future);

          final asked = verify(
            () => videosRepository.refreshAudioReusePolicies(captureAny()),
          ).captured;
          expect((asked.single as Iterable<String>).toList(), [
            normalReference,
          ]);
        });

        test('keeps the covers when the server cannot say', () async {
          stubBothSourceVideos();
          when(
            () => videosRepository.refreshAudioReusePolicies(any()),
          ).thenThrow(Exception('policy store down'));
          final container = buildContainer(
            soundsFrom([verticalReference, normalReference]),
          );

          final covers = await container.read(
            trendingSoundCoversProvider.future,
          );

          expect(covers[verticalReference], isNotNull);
          expect(covers[normalReference], isNotNull);
        });
      });

      group('savedSoundSourcesProvider', () {
        test('looks up the source videos of saved sounds', () async {
          stubBothSourceVideos();
          when(
            () => videosRepository.refreshAudioReusePolicies(any()),
          ).thenAnswer(
            (_) async => {
              normalReference: const AudioReusePolicy(allowAudioReuse: false),
            },
          );
          final container = buildContainer(const []);

          final sources = await container.read(
            savedSoundSourcesProvider(
              SoundSourceReferences(
                soundsFrom([verticalReference, normalReference]),
              ),
            ).future,
          );

          expect(sources[verticalReference], isNotNull);
          expect(sources.containsKey(normalReference), isTrue);
          expect(sources[normalReference], isNull);
        });

        test('asks nothing for saved sounds from no video', () async {
          final container = buildContainer(const []);

          final sources = await container.read(
            savedSoundSourcesProvider(
              SoundSourceReferences([createTestAudioEvent(id: 'imported')]),
            ).future,
          );

          expect(sources, isEmpty);
          verifyNever(
            () => videosRepository.getVideosFromRelaysByAddressableIds(
              any(),
              includeFeedShape: any(named: 'includeFeedShape'),
            ),
          );
        });

        test('takes sounds from the same videos for the same key', () {
          final sounds = soundsFrom([verticalReference, normalReference]);

          expect(
            SoundSourceReferences(sounds),
            SoundSourceReferences(sounds.reversed),
          );
          expect(
            SoundSourceReferences(sounds).hashCode,
            SoundSourceReferences(sounds.reversed).hashCode,
          );
          expect(
            SoundSourceReferences(sounds),
            isNot(SoundSourceReferences(sounds.take(1))),
          );
        });
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
