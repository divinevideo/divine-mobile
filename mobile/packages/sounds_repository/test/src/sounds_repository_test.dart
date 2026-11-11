// ABOUTME: Unit tests for SoundsRepository
// ABOUTME: Tests fetching, caching, and querying Kind 1063 audio events

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group('SoundsRepository', () {
    late SoundsRepository repository;
    late _MockNostrClient mockNostrClient;

    // Valid 64-character hex event IDs and pubkeys for testing
    const testEventId1 =
        'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
    const testEventId2 =
        'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
    const testPubkey1 =
        'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';
    const testPubkey2 =
        'd4e5f6789012345678901234567890abcdef1234567890123456789012abc123';
    const testVideoEventId =
        'e5f6789012345678901234567890abcdef1234567890123456789012abcd1234';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(<int>[]);
    });

    setUp(() {
      mockNostrClient = _MockNostrClient();

      // Default mocks
      when(
        () => mockNostrClient.queryEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => []);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});
      when(
        () => mockNostrClient.countEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => const CountResult(count: 0));

      repository = SoundsRepository(nostrClient: mockNostrClient);
    });

    tearDown(() async {
      await repository.dispose();
    });

    Event createAudioEvent({
      required String id,
      required String pubkey,
      int? createdAt,
      String? url = 'https://example.com/audio.mp3',
      String? mimeType = 'audio/mpeg',
      String? title,
      double? duration,
      List<String> publicTags = const [],
    }) {
      final tags = <List<dynamic>>[];
      if (url != null) tags.add(['url', url]);
      if (mimeType != null) tags.add(['m', mimeType]);
      if (title != null) tags.add(['title', title]);
      if (duration != null) tags.add(['duration', duration.toString()]);
      for (final publicTag in publicTags) {
        tags.add(['t', publicTag]);
      }

      // Use Event.fromJson to create events with specific IDs
      return Event.fromJson({
        'id': id,
        'pubkey': pubkey,
        'kind': audioEventKind,
        'tags': tags,
        'content': '',
        'created_at':
            createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'sig': '',
      });
    }

    int unresolvedWarningCount(String eventId) => LogCaptureService()
        .getRecentLogs(minLevel: LogLevel.warning)
        .where(
          (entry) =>
              entry.name == 'SoundsRepository' &&
              entry.message.contains(eventId) &&
              (entry.message.startsWith('Sound not found') ||
                  entry.message.contains('is not a Kind')),
        )
        .length;

    group('initialization', () {
      test('initializes with empty cache', () async {
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.cachedSoundCount, 0);
        expect(repository.cachedSounds, isEmpty);
      });

      test('does not reinitialize if already initialized', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Test Sound',
            ),
          ],
        );

        await repository.initialize();
        expect(repository.isInitialized, isTrue);
        expect(repository.cachedSoundCount, 1);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        // Verify queryEvents was only called once
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });
    });

    group('fetchTrendingSounds', () {
      test('returns empty list when no sounds exist', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final sounds = await repository.fetchTrendingSounds();

        expect(sounds, isEmpty);
      });

      test('asks only for sounds up to until', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.fetchTrendingSounds(limit: 100, until: 1500);

        final filter =
            (verify(
                      () => mockNostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.until, 1500);
        expect(filter.limit, 100);
      });

      test('fetches and caches audio events', () async {
        final event1 = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Sound 1',
          createdAt: 1000,
        );
        final event2 = createAudioEvent(
          id: testEventId2,
          pubkey: testPubkey2,
          title: 'Sound 2',
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event1, event2]);

        final sounds = await repository.fetchTrendingSounds();

        expect(sounds, hasLength(2));
        // Should be sorted newest first
        expect(sounds.first.id, testEventId2);
        expect(sounds.last.id, testEventId1);

        // Check cache
        expect(repository.cachedSoundCount, 2);
        expect(repository.getSoundFromCache(testEventId1), isNotNull);
        expect(repository.getSoundFromCache(testEventId2), isNotNull);
      });

      test('respects limit parameter', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.fetchTrendingSounds(limit: 25);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, 25);
        expect(filters.first.kinds, contains(audioEventKind));
      });

      test('asks the relay for audio MIME types only', () async {
        // Kind 1063 is generic file metadata, so without `#m` the relay
        // spends the limit on whatever files other clients published last.
        await repository.fetchTrendingSounds();

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.m, equals(SoundsRepository.audioMimeTypes));
        expect(
          SoundsRepository.audioMimeTypes,
          containsAll(['audio/wav', 'audio/mpeg', 'audio/mp4']),
        );
      });

      test('skips Kind 1063 files that are not audio', () async {
        final sound = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Sound',
          mimeType: 'audio/wav',
        );
        final pdf = createAudioEvent(
          id: testEventId2,
          pubkey: testPubkey2,
          title: 'Flyer',
          url: 'https://example.com/flyer.pdf',
          mimeType: 'application/pdf',
        );
        final untyped = createAudioEvent(
          id: testVideoEventId,
          pubkey: testPubkey2,
          title: 'No m tag',
          mimeType: null,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [sound, pdf, untyped]);

        final sounds = await repository.fetchTrendingSounds();

        expect(sounds.map((s) => s.id), equals([testEventId1]));
        expect(repository.getSoundFromCache(testEventId2), isNull);
        expect(repository.getSoundFromCache(testVideoEventId), isNull);
      });

      test('skips events with wrong kind', () async {
        final audioEvent = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Audio',
        );
        final wrongKindEvent = Event.fromJson({
          'id': testEventId2,
          'pubkey': testPubkey2,
          'kind': 1, // Kind 1 = text note, not audio
          'tags': <List<dynamic>>[],
          'content': 'Not an audio event',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [audioEvent, wrongKindEvent]);

        final sounds = await repository.fetchTrendingSounds();

        expect(sounds, hasLength(1));
        expect(sounds.first.id, testEventId1);
      });
    });

    group('searchSounds', () {
      const testEventId3 =
          'f6789012345678901234567890abcdef1234567890123456789012abcde12345';

      /// The search's own `#t` query, as opposed to the reuse lookup that
      /// follows it; both go through `queryEventsDetailed`.
      final isTagQuery = predicate<List<Filter>>(
        (filters) => filters.any(
          (filter) => filter.kinds?.contains(audioEventKind) ?? false,
        ),
        'the tag query',
      );

      /// Answers the tag query with [events], ended as [timedOut] and
      /// [noRelays] say.
      void answerTagQuery(
        List<Event> events, {
        bool timedOut = false,
        bool noRelays = false,
      }) {
        when(
          () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
        ).thenAnswer(
          (_) async => (events: events, timedOut: timedOut, noRelays: noRelays),
        );
      }

      setUp(() {
        answerTagQuery(const []);
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isNot(isTagQuery)),
          ),
        ).thenAnswer(
          (_) async => (events: <Event>[], timedOut: false, noRelays: false),
        );
      });

      /// Loads [events] into the repository cache the way a trending fetch
      /// would, so a search can be asserted against a populated cache.
      Future<void> primeCache(List<Event> events) async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);
        await repository.fetchTrendingSounds();
      }

      test('returns nothing and does not query for a blank query', () async {
        final sounds = await repository.searchSounds('  #  ');

        expect(sounds, isEmpty);
        verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
      });

      test('asks the relay for every term as an audio tag', () async {
        await repository.searchSounds('Horses #Hooves');

        final filters =
            verify(
                  () => mockNostrClient.queryEventsDetailed(
                    captureAny(that: isTagQuery),
                  ),
                ).captured.single
                as List<Filter>;
        final tagged = filters.singleWhere((filter) => filter.t != null);
        expect(tagged.kinds, equals(const [audioEventKind]));
        expect(tagged.t, equals(const ['horses', 'hooves']));
        expect(tagged.m, equals(SoundsRepository.audioMimeTypes));
        expect(tagged.limit, SoundsRepository.maxSearchResults);
      });

      test(
        'cold full-text search finds untagged classic captions and aliases',
        () async {
          final classic = Event.fromJson({
            'id': testEventId1,
            'pubkey': testPubkey1,
            'kind': audioEventKind,
            'tags': [
              ['title', 'The tiny puppet show'],
              ['url', 'https://example.com/puppet.m4a'],
              ['m', 'audio/mp4'],
              ['creator', 'Alex'],
            ],
            'content':
                'Original caption: lunchtime\nAlso known as: still got snacks',
            'created_at': 1000,
            'sig': '',
          });
          when(
            () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
          ).thenAnswer((invocation) async {
            final filters =
                invocation.positionalArguments.single as List<Filter>;
            final fullText = filters.where((filter) => filter.search != null);
            // A full tag page can contain only partial matches; full-text must
            // independently ask for all words rather than filter that page.
            return (
              events: fullText.any((filter) => filter.search == 'still snacks')
                  ? [classic]
                  : <Event>[],
              timedOut: false,
              noRelays: false,
            );
          });

          expect(repository.cachedSoundCount, 0);
          final sounds = await repository.searchSounds('still snacks');

          expect(sounds.map((sound) => sound.id), [testEventId1]);
          expect(sounds.single.publicTags, isEmpty);
        },
      );

      test('returns and caches a tagged sound the cache never held', () async {
        answerTagQuery([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Field recording 04',
            publicTags: const ['horses', 'hooves'],
          ),
        ]);

        final sounds = await repository.searchSounds('hooves');

        expect(sounds.map((sound) => sound.id), equals([testEventId1]));
        expect(repository.getSoundFromCache(testEventId1), isNotNull);
      });

      test('drops a relay hit that carries only one of two terms', () async {
        answerTagQuery([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Hooves on gravel',
            publicTags: const ['hooves'],
          ),
          createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey2,
            title: 'Field recording 04',
            publicTags: const ['horses', 'hooves'],
          ),
        ]);

        final sounds = await repository.searchSounds('horses hooves');

        expect(
          sounds.map((sound) => sound.id),
          equals([testEventId2]),
          reason:
              'the relay is asked for either tag, so the AND narrowing '
              'has to happen here',
        );
      });

      test('includes a cached sound the tag query cannot reach', () async {
        await primeCache([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Wind blowing hard',
            createdAt: 1000,
          ),
        ]);

        final sounds = await repository.searchSounds('wind');

        expect(sounds.map((sound) => sound.id), equals([testEventId1]));
      });

      test('lists a sound once when cache and relay both hold it', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Crowd ambience',
          createdAt: 1000,
        );
        await primeCache([event]);
        answerTagQuery([event]);

        final sounds = await repository.searchSounds('crowd');

        expect(sounds.map((sound) => sound.id), equals([testEventId1]));
      });

      test('returns matches newest first', () async {
        await primeCache([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Crowd ambience',
            createdAt: 1000,
          ),
        ]);
        answerTagQuery([
          createAudioEvent(
            id: testEventId3,
            pubkey: testPubkey2,
            title: 'Crowd cheering',
            createdAt: 3000,
          ),
          createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey2,
            title: 'Crowd murmur',
            createdAt: 2000,
          ),
        ]);

        final sounds = await repository.searchSounds('crowd');

        expect(
          sounds.map((sound) => sound.id),
          equals([testEventId3, testEventId2, testEventId1]),
        );
      });

      test(
        'lists unnamed sounds no other account used after named ones',
        () async {
          answerTagQuery([
            createAudioEvent(
              id: testEventId3,
              pubkey: testPubkey2,
              title: AudioEvent.originalSoundTitle,
              publicTags: const ['crowd'],
              createdAt: 3000,
            ),
            createAudioEvent(
              id: testEventId2,
              pubkey: testPubkey2,
              title: 'Crowd murmur',
              createdAt: 2000,
            ),
          ]);

          final sounds = await repository.searchSounds('crowd');

          expect(
            sounds.map((sound) => sound.id),
            equals([testEventId2, testEventId3]),
          );
        },
      );

      test('lets an error from the reuse lookup propagate', () async {
        answerTagQuery([
          createAudioEvent(
            id: testEventId3,
            pubkey: testPubkey2,
            title: AudioEvent.originalSoundTitle,
            publicTags: const ['crowd'],
          ),
        ]);
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isNot(isTagQuery)),
          ),
        ).thenThrow(StateError('unexpected client state'));

        await expectLater(repository.searchSounds('crowd'), throwsStateError);
      });

      test('falls back to cached matches when the relay fails', () async {
        await primeCache([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Wind blowing hard',
            createdAt: 1000,
          ),
        ]);
        when(
          () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
        ).thenThrow(Exception('relay down'));

        final sounds = await repository.searchSounds('wind');

        expect(sounds.map((sound) => sound.id), equals([testEventId1]));
      });

      group('when the tag query does not finish', () {
        Future<void> primeUnnamedAndNamed() => primeCache([
          createAudioEvent(
            id: testEventId3,
            pubkey: testPubkey2,
            title: AudioEvent.originalSoundTitle,
            publicTags: const ['wind'],
            createdAt: 2000,
          ),
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Wind blowing hard',
            createdAt: 1000,
          ),
        ]);

        Future<void> expectUnnamedLastWithoutLookup() async {
          final sounds = await repository.searchSounds('wind');

          expect(
            sounds.map((sound) => sound.id),
            equals([testEventId1, testEventId3]),
          );
          verifyNever(
            () => mockNostrClient.queryEventsDetailed(
              any(that: isNot(isTagQuery)),
            ),
          );
        }

        test('lists unnamed sounds last without a reuse lookup when it '
            'throws', () async {
          await primeUnnamedAndNamed();
          when(
            () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
          ).thenThrow(Exception('relay down'));

          await expectUnnamedLastWithoutLookup();
        });

        test('lists unnamed sounds last without a reuse lookup when it '
            'times out', () async {
          await primeUnnamedAndNamed();
          answerTagQuery(const [], timedOut: true);

          await expectUnnamedLastWithoutLookup();
        });

        test('lists unnamed sounds last without a reuse lookup when it '
            'reaches no relay', () async {
          await primeUnnamedAndNamed();
          answerTagQuery(const [], noRelays: true);

          await expectUnnamedLastWithoutLookup();
        });
      });

      test('honours an explicit result limit', () async {
        await repository.searchSounds('wind', limit: 7);

        final filters =
            verify(
                  () => mockNostrClient.queryEventsDetailed(
                    captureAny(that: isTagQuery),
                  ),
                ).captured.single
                as List<Filter>;
        expect(filters.every((filter) => filter.limit == 7), isTrue);
      });
    });

    test(
      'legacy original sound links resolve the current published audio',
      () async {
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        final revision = Event.fromJson({
          'id': testEventId2,
          'pubkey': testPubkey1,
          'kind': 34236,
          'created_at': 2000,
          'content': 'The tiny puppet show',
          'tags': [
            ['d', 'puppet-show'],
            ['platform', 'vine'],
            ['e', testEventId1, '', 'audio'],
          ],
          'sig': '',
        });
        when(
          () => api.getVideoEvent(testVideoEventId),
        ).thenAnswer((_) async => revision);
        when(() => mockNostrClient.fetchEventById(testEventId1)).thenAnswer(
          (_) async => createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'The tiny puppet show',
          ),
        );
        final sounds = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: api,
        );
        addTearDown(sounds.dispose);

        final sound = await sounds.fetchSoundById('video_$testVideoEventId');

        expect(sound?.id, testEventId1);
        expect(sound?.title, 'The tiny puppet show');
        verifyNever(
          () => mockNostrClient.fetchEventById('video_$testVideoEventId'),
        );
      },
    );

    group('fetchPopularSounds', () {
      late _MockFunnelcakeApiClient funnelcake;

      setUp(() {
        funnelcake = _MockFunnelcakeApiClient();
        when(() => funnelcake.isAvailable).thenReturn(true);
      });

      SoundStats ranked(String id, int usageCount) => SoundStats(
        id: id,
        pubkey: testPubkey1,
        title: 'Sound',
        createdAt: DateTime.utc(2026),
        usageCount: usageCount,
      );

      test('returns nothing without a Funnelcake client', () async {
        final popular = await repository.fetchPopularSounds();

        expect(popular.sounds, isEmpty);
        expect(popular.usageCounts, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns nothing while Funnelcake is unavailable', () async {
        when(() => funnelcake.isAvailable).thenReturn(false);
        final popularRepository = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
        );
        addTearDown(popularRepository.dispose);

        final popular = await popularRepository.fetchPopularSounds();

        expect(popular.sounds, isEmpty);
        verifyNever(
          () => funnelcake.getTrendingSounds(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        );
      });

      test(
        'keeps the Funnelcake ranking and loads the events from relays',
        () async {
          when(
            () => funnelcake.getTrendingSounds(
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => [
              ranked(testEventId2, 28),
              ranked(testEventId1, 60),
              ranked(testVideoEventId, 5),
            ],
          );
          // Returned newest first and missing the third ranked sound.
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              createAudioEvent(
                id: testEventId1,
                pubkey: testPubkey1,
                title: 'Older but second',
                createdAt: 100,
              ),
              createAudioEvent(
                id: testEventId2,
                pubkey: testPubkey2,
                title: 'Newer but first',
                createdAt: 200,
              ),
            ],
          );
          final popularRepository = SoundsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: funnelcake,
          );
          addTearDown(popularRepository.dispose);

          final popular = await popularRepository.fetchPopularSounds(
            limit: 20,
          );

          expect(popular.sounds.map((sound) => sound.id), [
            testEventId2,
            testEventId1,
          ]);
          expect(popular.usageCounts, {
            testEventId2: 28,
            testEventId1: 60,
            testVideoEventId: 5,
          });
          verify(
            () => funnelcake.getTrendingSounds(
              limit: 20,
              offset: any(named: 'offset'),
            ),
          ).called(1);
          final filter =
              (verify(
                        () => mockNostrClient.queryEvents(captureAny()),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.ids, [testEventId2, testEventId1, testVideoEventId]);
          expect(filter.kinds, [audioEventKind]);
        },
      );

      test('asks Funnelcake for the ranking past offset', () async {
        when(
          () => funnelcake.getTrendingSounds(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => const []);
        final popularRepository = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
        );
        addTearDown(popularRepository.dispose);

        await popularRepository.fetchPopularSounds(offset: 100);

        verify(
          () => funnelcake.getTrendingSounds(
            limit: any(named: 'limit'),
            offset: 100,
          ),
        ).called(1);
      });

      test('skips the relay when Funnelcake ranks nothing', () async {
        when(
          () => funnelcake.getTrendingSounds(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => [ranked('', 3)]);
        final popularRepository = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
        );
        addTearDown(popularRepository.dispose);

        final popular = await popularRepository.fetchPopularSounds();

        expect(popular.sounds, isEmpty);
        expect(popular.usageCounts, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });
    });

    group('fetchSoundsByCreators', () {
      test('returns nothing without querying for no pubkeys', () async {
        final sounds = await repository.fetchSoundsByCreators(const ['']);

        expect(sounds, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('asks for the audio of every creator at once', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Followed sound',
            ),
          ],
        );

        final sounds = await repository.fetchSoundsByCreators(
          const [testPubkey1, testPubkey2, testPubkey1],
          limit: 30,
          until: 1500,
        );

        expect(sounds.single.id, testEventId1);
        final filter =
            (verify(
                      () => mockNostrClient.queryEvents(captureAny()),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.authors, [testPubkey1, testPubkey2]);
        expect(filter.kinds, [audioEventKind]);
        expect(filter.m, SoundsRepository.audioMimeTypes);
        expect(filter.limit, 30);
        expect(filter.until, 1500);
      });
    });

    group('fetchDivineSounds', () {
      test('asks nothing when no sound account is set', () async {
        expect(await repository.fetchDivineSounds(), isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test(
        "asks for the sound accounts' audio, without their videos'",
        () async {
          final divine = SoundsRepository(
            nostrClient: mockNostrClient,
            divineSoundPublishers: const {testPubkey1},
          );
          addTearDown(divine.dispose);
          final library = createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Wednesday My Dudes',
          );
          final fromVideo = Event.fromJson({
            ...createAudioEvent(
              id: testEventId2,
              pubkey: testPubkey1,
              title: 'Original sound',
            ).toJson(),
          })..tags.add(['a', '34236:$testPubkey1:clip']);
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [library, fromVideo]);

          final sounds = await divine.fetchDivineSounds(limit: 40);

          expect(sounds.map((sound) => sound.id), [testEventId1]);
          final filter =
              (verify(
                        () => mockNostrClient.queryEvents(captureAny()),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.authors, [testPubkey1]);
          expect(filter.kinds, [audioEventKind]);
          expect(filter.m, SoundsRepository.audioMimeTypes);
          expect(filter.limit, 40);
        },
      );
    });

    group('withoutLibrarySounds', () {
      test("drops the library accounts' sounds, not their videos'", () {
        final library = SoundsRepository(
          nostrClient: mockNostrClient,
          librarySoundPublishers: const {testPubkey1},
        );
        addTearDown(library.dispose);
        final imported = AudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          createdAt: 1,
        );
        final fromVideo = AudioEvent(
          id: testEventId2,
          pubkey: testPubkey1,
          createdAt: 1,
          sourceVideoReference: '34236:$testPubkey1:clip',
        );
        final community = AudioEvent(
          id: '3' * 64,
          pubkey: testPubkey2,
          createdAt: 1,
        );

        expect(library.withoutLibrarySounds([imported, fromVideo, community]), [
          fromVideo,
          community,
        ]);
      });

      test('keeps every sound when no library account is set', () {
        final sounds = [
          AudioEvent(id: testEventId1, pubkey: testPubkey1, createdAt: 1),
        ];

        expect(repository.withoutLibrarySounds(sounds), same(sounds));
      });
    });

    group('blocked authors', () {
      late _MockFunnelcakeApiClient funnelcake;
      late SoundsRepository blocking;

      setUp(() {
        funnelcake = _MockFunnelcakeApiClient();
        when(() => funnelcake.isAvailable).thenReturn(true);
        blocking = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
          divineSoundPublishers: const {testPubkey1, testPubkey2},
          blockFilter: (pubkey) => pubkey == testPubkey2,
        );
        addTearDown(blocking.dispose);
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Kept beat',
              publicTags: const ['beat'],
            ),
            createAudioEvent(
              id: testEventId2,
              pubkey: testPubkey2,
              title: 'Blocked beat',
              publicTags: const ['beat'],
            ),
          ],
        );
      });

      List<String> ids(List<AudioEvent> sounds) => [
        for (final sound in sounds) sound.id,
      ];

      test('withoutBlockedAuthors drops the sounds of blocked authors', () {
        final kept = AudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          createdAt: 1,
        );
        final blocked = AudioEvent(
          id: testEventId2,
          pubkey: testPubkey2,
          createdAt: 1,
        );

        expect(blocking.withoutBlockedAuthors([kept, blocked]), [kept]);
        expect(repository.withoutBlockedAuthors([kept, blocked]), [
          kept,
          blocked,
        ]);
      });

      test('leaves them out of Popular, keeping their counts', () async {
        when(
          () => funnelcake.getTrendingSounds(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer(
          (_) async => [
            for (final id in [testEventId1, testEventId2])
              SoundStats(
                id: id,
                pubkey: testPubkey1,
                title: 'Sound',
                createdAt: DateTime.utc(2026),
                usageCount: 3,
              ),
          ],
        );

        final popular = await blocking.fetchPopularSounds();

        expect(ids(popular.sounds), [testEventId1]);
        expect(popular.usageCounts.keys, [testEventId1, testEventId2]);
      });

      test("leaves them out of Divine's sounds", () async {
        expect(ids(await blocking.fetchDivineSounds()), [testEventId1]);
      });

      test("leaves them out of a creator's sounds", () async {
        expect(
          ids(await blocking.fetchSoundsByCreator(testPubkey2)),
          [testEventId1],
        );
      });

      test('leaves them out of searches', () async {
        when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
          (_) async => (
            events: [
              createAudioEvent(
                id: testEventId1,
                pubkey: testPubkey1,
                title: 'Kept beat',
                publicTags: const ['beat'],
              ),
              createAudioEvent(
                id: testEventId2,
                pubkey: testPubkey2,
                title: 'Blocked beat',
                publicTags: const ['beat'],
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        expect(ids(await blocking.searchSounds('beat')), [testEventId1]);
      });

      test('keeps them in the pages callers narrow themselves', () async {
        expect(ids(await blocking.fetchTrendingSounds()), hasLength(2));
        expect(
          ids(await blocking.fetchSoundsByCreators(const [testPubkey1])),
          hasLength(2),
        );
      });
    });

    group('unnamed video sounds', () {
      const sourceDTag = 'source-video';
      const namedSoundId =
          'f6789012345678901234567890abcdef1234567890123456789012abcde12345';
      const reuseVideoId =
          '06789012345678901234567890abcdef1234567890123456789012abcde12345';
      const secondUnusedId =
          '16789012345678901234567890abcdef1234567890123456789012abcde12345';
      const sourceAddress = '34236:$testPubkey1:$sourceDTag';

      AudioEvent sound(String id, {String? title, String? source}) =>
          AudioEvent(
            id: id,
            pubkey: testPubkey1,
            createdAt: 1700000000,
            title: title ?? AudioEvent.originalSoundTitle,
            source: source,
            sourceVideoReference: sourceAddress,
          );

      ({List<Event> events, bool timedOut, bool noRelays}) answered(
        List<Event> events,
      ) => (events: events, timedOut: false, noRelays: false);

      Event video({
        required String id,
        required String pubkey,
        required String dTag,
        required String usesSoundId,
      }) => Event.fromJson({
        'id': id,
        'pubkey': pubkey,
        'kind': 34236,
        'tags': [
          ['d', dTag],
          ['e', usesSoundId, '', 'audio'],
        ],
        'content': '',
        'created_at': 1700000000,
        'sig': '',
      });

      group('withoutUnusedOriginals', () {
        test('keeps an unnamed sound another video uses', () async {
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => answered([
              video(
                id: testVideoEventId,
                pubkey: testPubkey1,
                dTag: sourceDTag,
                usesSoundId: testEventId1,
              ),
              video(
                id: testEventId2,
                pubkey: testPubkey2,
                dTag: 'reuse',
                usesSoundId: testEventId1,
              ),
            ]),
          );

          final kept = await repository.withoutUnusedOriginals([
            sound(testEventId1),
          ]);

          expect(kept.map((s) => s.id), [testEventId1]);
        });

        test('drops an unnamed sound only its source video uses', () async {
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => answered([
              video(
                id: testVideoEventId,
                pubkey: testPubkey1,
                dTag: sourceDTag,
                usesSoundId: testEventId1,
              ),
            ]),
          );

          final kept = await repository.withoutUnusedOriginals([
            sound(testEventId1),
            sound(testEventId2, title: 'Named beat'),
          ]);

          expect(kept.map((s) => s.id), [testEventId2]);
        });

        test('asks only about the unnamed sounds, in one query', () async {
          when(
            () => mockNostrClient.queryEventsDetailed(any()),
          ).thenAnswer((_) async => answered([]));

          await repository.withoutUnusedOriginals([
            sound(testEventId1),
            sound(testEventId2, title: 'Named beat'),
          ]);

          final filters =
              verify(
                    () => mockNostrClient.queryEventsDetailed(captureAny()),
                  ).captured.single
                  as List<Filter>;
          expect(filters.single.kinds, [34236]);
          expect(filters.single.e, [testEventId1]);
        });

        test('returns named sounds without querying', () async {
          final named = [sound(testEventId1, title: 'Named beat')];

          expect(await repository.withoutUnusedOriginals(named), named);
          verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
        });

        test('keeps every sound when the lookup fails', () async {
          when(
            () => mockNostrClient.queryEventsDetailed(any()),
          ).thenThrow(Exception('relay down'));
          final sounds = [sound(testEventId1)];

          expect(await repository.withoutUnusedOriginals(sounds), sounds);
        });

        test('keeps every sound when the lookup runs out of time', () async {
          // The video reusing the sound had not arrived yet.
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => (events: <Event>[], timedOut: true, noRelays: false),
          );
          final sounds = [sound(testEventId1)];

          expect(await repository.withoutUnusedOriginals(sounds), sounds);
        });

        test('keeps every sound when no relay was asked', () async {
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => (events: <Event>[], timedOut: false, noRelays: true),
          );
          final sounds = [sound(testEventId1)];

          expect(await repository.withoutUnusedOriginals(sounds), sounds);
        });

        test('keeps every sound when the lookup fills its limit', () async {
          // A full answer may have stopped before the video reusing it.
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => answered([
              for (
                var i = 0;
                i < SoundsRepository.maxBatchedUsageCountScan;
                i++
              )
                video(
                  id: i.toRadixString(16).padLeft(64, '0'),
                  pubkey: testPubkey1,
                  dTag: 'own-video-$i',
                  usesSoundId: testEventId1,
                ),
            ]),
          );
          final sounds = [sound(testEventId1)];

          expect(await repository.withoutUnusedOriginals(sounds), sounds);
        });

        test('drops an unnamed sound only its creator uses', () async {
          when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
            (_) async => answered([
              video(
                id: testVideoEventId,
                pubkey: testPubkey1,
                dTag: sourceDTag,
                usesSoundId: testEventId1,
              ),
              video(
                id: testEventId2,
                pubkey: testPubkey1,
                dTag: 'another-video',
                usesSoundId: testEventId1,
              ),
            ]),
          );

          final kept = await repository.withoutUnusedOriginals([
            sound(testEventId1),
          ]);

          expect(kept, isEmpty);
        });

        test(
          'drops a sound titled after its creator that only its creator used',
          () async {
            when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
              (_) async => answered([
                video(
                  id: testVideoEventId,
                  pubkey: testPubkey1,
                  dTag: sourceDTag,
                  usesSoundId: testEventId1,
                ),
              ]),
            );

            final kept = await repository.withoutUnusedOriginals([
              sound(
                testEventId1,
                title: '${AudioEvent.originalSoundTitle} - @rabble',
              ),
            ]);

            expect(kept, isEmpty);
          },
        );

        test('keeps an unnamed sound credited to a source', () async {
          final credited = [
            sound(testEventId1, source: 'https://example.com/track'),
          ];

          expect(await repository.withoutUnusedOriginals(credited), credited);
          verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
        });
      });

      group('withUnusedOriginalsLast', () {
        test(
          'moves unnamed sounds no other account used after the rest',
          () async {
            when(() => mockNostrClient.queryEventsDetailed(any())).thenAnswer(
              (_) async => answered([
                video(
                  id: testVideoEventId,
                  pubkey: testPubkey1,
                  dTag: sourceDTag,
                  usesSoundId: testEventId2,
                ),
                video(
                  id: reuseVideoId,
                  pubkey: testPubkey2,
                  dTag: 'reuse',
                  usesSoundId: testEventId1,
                ),
              ]),
            );

            final ordered = await repository.withUnusedOriginalsLast([
              sound(testEventId2),
              sound(testEventId1),
              sound(secondUnusedId),
              sound(namedSoundId, title: 'Named beat'),
            ]);

            expect(ordered.map((s) => s.id), [
              testEventId1,
              namedSoundId,
              testEventId2,
              secondUnusedId,
            ]);
          },
        );

        test('moves every unnamed sound last when the lookup fails', () async {
          when(
            () => mockNostrClient.queryEventsDetailed(any()),
          ).thenThrow(Exception('relay down'));

          final ordered = await repository.withUnusedOriginalsLast([
            sound(testEventId1),
            sound(namedSoundId, title: 'Named beat'),
          ]);

          expect(ordered.map((s) => s.id), [namedSoundId, testEventId1]);
        });

        test('returns named sounds as given without querying', () async {
          final named = [
            sound(testEventId1, title: 'Named beat'),
            sound(testEventId2, title: 'Another beat'),
          ];

          expect(await repository.withUnusedOriginalsLast(named), named);
          verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
        });
      });
    });

    group('fetchSoundsByCreator', () {
      test('returns empty list for empty pubkey', () async {
        final sounds = await repository.fetchSoundsByCreator('');

        expect(sounds, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('queries with correct filter for creator', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.fetchSoundsByCreator(testPubkey1);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters.first.authors, contains(testPubkey1));
        expect(filters.first.kinds, contains(audioEventKind));
        expect(filters.first.m, equals(SoundsRepository.audioMimeTypes));
      });

      test('returns sounds by specific creator', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Creator Sound',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final sounds = await repository.fetchSoundsByCreator(testPubkey1);

        expect(sounds, hasLength(1));
        expect(sounds.first.pubkey, testPubkey1);
      });
    });

    group('fetchSoundById', () {
      test('returns null for empty eventId', () async {
        final sound = await repository.fetchSoundById('');

        expect(sound, isNull);
        verifyNever(() => mockNostrClient.fetchEventById(any()));
      });

      test('returns cached sound without network request', () async {
        // Pre-populate cache
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Cached Sound',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        await repository.fetchTrendingSounds();

        // Now fetch by ID - should use cache
        final sound = await repository.fetchSoundById(testEventId1);

        expect(sound, isNotNull);
        expect(sound!.id, testEventId1);
        verifyNever(() => mockNostrClient.fetchEventById(any()));
      });

      test('fetches from network when not in cache', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Network Sound',
        );

        when(
          () => mockNostrClient.fetchEventById(testEventId1),
        ).thenAnswer((_) async => event);

        final sound = await repository.fetchSoundById(testEventId1);

        expect(sound, isNotNull);
        expect(sound!.id, testEventId1);
        verify(() => mockNostrClient.fetchEventById(testEventId1)).called(1);
      });

      test('returns null when event is not found', () async {
        when(
          () => mockNostrClient.fetchEventById(testEventId1),
        ).thenAnswer((_) async => null);

        final sound = await repository.fetchSoundById(testEventId1);

        expect(sound, isNull);
      });

      test('warns once per missing event until the cache is cleared', () async {
        when(
          () => mockNostrClient.fetchEventById(any()),
        ).thenAnswer((_) async => null);
        final firstBaseline = unresolvedWarningCount(testEventId1);

        expect(await repository.fetchSoundById(testEventId1), isNull);
        expect(unresolvedWarningCount(testEventId1), firstBaseline + 1);

        expect(await repository.fetchSoundById(testEventId1), isNull);
        expect(unresolvedWarningCount(testEventId1), firstBaseline + 1);

        final secondBaseline = unresolvedWarningCount(testEventId2);
        expect(await repository.fetchSoundById(testEventId2), isNull);
        expect(unresolvedWarningCount(testEventId2), secondBaseline + 1);

        repository.clearCache();
        expect(await repository.fetchSoundById(testEventId1), isNull);
        expect(unresolvedWarningCount(testEventId1), firstBaseline + 2);
      });

      test('returns null when event is wrong kind', () async {
        final wrongKindEvent = Event.fromJson({
          'id': testEventId1,
          'pubkey': testPubkey1,
          'kind': 1, // Kind 1 = text note
          'tags': <List<dynamic>>[],
          'content': 'Not audio',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });

        when(
          () => mockNostrClient.fetchEventById(testEventId1),
        ).thenAnswer((_) async => wrongKindEvent);

        final sound = await repository.fetchSoundById(testEventId1);

        expect(sound, isNull);
      });

      test('warns once per unsupported event kind', () async {
        final wrongKindEvent = Event.fromJson({
          'id': testEventId1,
          'pubkey': testPubkey1,
          'kind': 1,
          'tags': <List<dynamic>>[],
          'content': 'Not audio',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });
        when(
          () => mockNostrClient.fetchEventById(testEventId1),
        ).thenAnswer((_) async => wrongKindEvent);
        final baseline = unresolvedWarningCount(testEventId1);

        expect(await repository.fetchSoundById(testEventId1), isNull);
        expect(unresolvedWarningCount(testEventId1), baseline + 1);

        expect(await repository.fetchSoundById(testEventId1), isNull);
        expect(unresolvedWarningCount(testEventId1), baseline + 1);
      });

      test(
        'synthesizes an original sound crediting the video creator when the '
        'reference is a Kind 34236 video',
        () async {
          final videoEvent = Event.fromJson({
            'id': testVideoEventId,
            'pubkey': testPubkey1,
            'kind': NIP71VideoKinds.addressableShortVideo,
            'tags': <List<dynamic>>[
              ['d', 'vine-abc'],
              ['url', 'https://example.com/video.mp4'],
            ],
            'content': 'reused original sound',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'sig': '',
          });

          when(
            () => mockNostrClient.fetchEventById(testVideoEventId),
          ).thenAnswer((_) async => videoEvent);

          final sound = await repository.fetchSoundById(testVideoEventId);

          expect(sound, isNotNull);
          // Credits the original video creator, not the reusing user.
          expect(sound!.pubkey, equals(testPubkey1));
          expect(sound.isOriginalSound, isTrue);
          // Title left null so the reader localizes "Original sound".
          expect(sound.title, isNull);
        },
      );
    });

    group('getSoundFromCache', () {
      test('returns null when sound is not cached', () {
        final sound = repository.getSoundFromCache(testEventId1);

        expect(sound, isNull);
      });

      test('returns sound when it is cached', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Cached',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        await repository.fetchTrendingSounds();

        final sound = repository.getSoundFromCache(testEventId1);

        expect(sound, isNotNull);
        expect(sound!.id, testEventId1);
      });
    });

    group('fetchVideosUsingSoundCount', () {
      test('returns 0 for empty audioEventId', () async {
        final count = await repository.fetchVideosUsingSoundCount('');

        expect(count, 0);
        verifyNever(() => mockNostrClient.countEvents(any()));
      });

      test('queries with correct filter for video references', () async {
        when(
          () => mockNostrClient.countEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer((_) async => const CountResult(count: 5));

        final count = await repository.fetchVideosUsingSoundCount(testEventId1);

        expect(count, 5);

        final captured = verify(
          () => mockNostrClient.countEvents(
            captureAny(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(34236));
        expect(filters.first.e, contains(testEventId1));
      });

      test('returns null when no relay answered the count', () async {
        when(
          () => mockNostrClient.countEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(
          const CountUnavailableException('No relay responded to COUNT'),
        );

        final count = await repository.fetchVideosUsingSoundCount(testEventId1);

        expect(count, isNull);
      });

      test('returns null rather than zero on error', () async {
        when(
          () => mockNostrClient.countEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        ).thenThrow(Exception('Network error'));

        final count = await repository.fetchVideosUsingSoundCount(testEventId1);

        expect(count, isNull);
      });
    });

    group('fetchVideosUsingSoundCounts', () {
      const otherAudioId =
          'f6789012345678901234567890abcdef1234567890123456789012abcd1234ef';
      const secondVideoEventId =
          '789012345678901234567890abcdef1234567890123456789012abcd1234ef56';

      Event createVideoEvent({
        required String id,
        required List<List<dynamic>> tags,
      }) {
        return Event.fromJson({
          'id': id,
          'pubkey': testPubkey1,
          'kind': 34236,
          'tags': tags,
          'content': '',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });
      }

      test(
        'returns an empty map without querying when no id is usable',
        () async {
          final counts = await repository.fetchVideosUsingSoundCounts(
            const ['', ''],
          );

          expect(counts, isEmpty);
          verifyNever(() => mockNostrClient.queryEvents(any()));
        },
      );

      test('resolves the whole batch with a single query', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createVideoEvent(
              id: testVideoEventId,
              tags: [
                ['e', testEventId1, '', 'audio'],
              ],
            ),
          ],
        );

        await repository.fetchVideosUsingSoundCounts(
          const [testEventId1, testEventId2],
          limit: 120,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        expect(captured, hasLength(1));
        final filters = captured.single as List<Filter>;
        expect(filters, hasLength(1));
        expect(filters.single.kinds, contains(34236));
        expect(filters.single.e, containsAll([testEventId1, testEventId2]));
        expect(filters.single.limit, 120);
        verifyNever(
          () => mockNostrClient.countEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('tallies each sound and reports 0 for unreferenced ones', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createVideoEvent(
              id: testVideoEventId,
              tags: [
                ['e', testEventId1, '', 'audio'],
              ],
            ),
            createVideoEvent(
              id: secondVideoEventId,
              tags: [
                ['e', testEventId1, '', 'audio'],
              ],
            ),
          ],
        );

        final counts = await repository.fetchVideosUsingSoundCounts(
          const [testEventId1, testEventId2],
        );

        expect(counts[testEventId1], 2);
        expect(counts[testEventId2], 0);
      });

      test(
        'counts one video toward every batched sound it references',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              createVideoEvent(
                id: testVideoEventId,
                tags: [
                  ['e', testEventId1, '', 'audio'],
                  ['e', testEventId2, '', 'audio'],
                ],
              ),
            ],
          );

          final counts = await repository.fetchVideosUsingSoundCounts(
            const [testEventId1, testEventId2],
          );

          expect(counts[testEventId1], 1);
          expect(counts[testEventId2], 1);
        },
      );

      test('counts a repeated reference once', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            createVideoEvent(
              id: testVideoEventId,
              tags: [
                ['e', testEventId1, '', 'audio'],
                ['e', testEventId1, 'wss://relay.example', 'audio'],
              ],
            ),
          ],
        );

        final counts = await repository.fetchVideosUsingSoundCounts(
          const [testEventId1],
        );

        expect(counts[testEventId1], 1);
      });

      test(
        'ignores tags that are not a reference to a batched sound',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              createVideoEvent(
                id: testVideoEventId,
                tags: [
                  ['e'],
                  ['p', testPubkey2],
                  ['e', otherAudioId, '', 'audio'],
                ],
              ),
            ],
          );

          final counts = await repository.fetchVideosUsingSoundCounts(
            const [testEventId1],
          );

          expect(counts, {testEventId1: 0});
        },
      );

      test('rethrows when the query fails', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        await expectLater(
          repository.fetchVideosUsingSoundCounts(const [testEventId1]),
          throwsException,
        );
      });
    });

    group('fetchVideosUsingSound', () {
      test('returns empty list for empty audioEventId', () async {
        final videos = await repository.fetchVideosUsingSound('');

        expect(videos, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns list of video event IDs', () async {
        final videoEvent = Event.fromJson({
          'id': testVideoEventId,
          'pubkey': testPubkey1,
          'kind': 34236,
          'tags': <List<dynamic>>[
            ['e', testEventId1],
          ],
          'content': '',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [videoEvent]);

        final videos = await repository.fetchVideosUsingSound(testEventId1);

        expect(videos, hasLength(1));
        expect(videos.first, testVideoEventId);
      });
    });

    group('soundsStream', () {
      test('is a broadcast stream', () {
        expect(repository.soundsStream.isBroadcast, isTrue);
      });

      test('emits updated list when sounds are fetched', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Streamed Sound',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final emittedLists = <List<AudioEvent>>[];
        final subscription = repository.soundsStream.listen(emittedLists.add);

        await repository.fetchTrendingSounds();
        await Future<void>.delayed(Duration.zero);

        expect(emittedLists.length, greaterThanOrEqualTo(1));
        expect(emittedLists.last, isNotEmpty);
        expect(emittedLists.last.first.id, testEventId1);

        await subscription.cancel();
      });
    });

    group('clearCache', () {
      test('clears all cached sounds', () async {
        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'To Be Cleared',
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        await repository.fetchTrendingSounds();
        expect(repository.cachedSoundCount, 1);

        repository.clearCache();

        expect(repository.cachedSoundCount, 0);
        expect(repository.getSoundFromCache(testEventId1), isNull);
      });
    });

    group('removeCachedSound', () {
      test('drops the sound and emits the remaining list', () async {
        final kept = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Kept',
        );
        final deleted = createAudioEvent(
          id: testEventId2,
          pubkey: testPubkey1,
          title: 'Deleted',
        );
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [kept, deleted]);
        await repository.fetchTrendingSounds();
        expect(repository.cachedSoundCount, 2);
        final emittedLists = <List<AudioEvent>>[];
        final subscription = repository.soundsStream.listen(emittedLists.add);

        repository.removeCachedSound(testEventId2);
        await pumpEventQueue();

        expect(repository.cachedSoundCount, 1);
        expect(repository.getSoundFromCache(testEventId2), isNull);
        expect(emittedLists.last.map((sound) => sound.id), [testEventId1]);
        await subscription.cancel();
      });

      test('emits nothing for an id that is not cached', () async {
        final emittedLists = <List<AudioEvent>>[];
        final subscription = repository.soundsStream.listen(emittedLists.add);
        await pumpEventQueue();
        // The seeded subject replays its current value on subscribe, so the
        // count starts at one; a spurious emit would make it two.
        expect(emittedLists, hasLength(1));

        repository.removeCachedSound(testEventId1);
        await pumpEventQueue();

        expect(emittedLists, hasLength(1));
        await subscription.cancel();
      });
    });

    group('refresh', () {
      test('clears cache and fetches fresh data', () async {
        final event1 = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Old Sound',
        );
        final event2 = createAudioEvent(
          id: testEventId2,
          pubkey: testPubkey2,
          title: 'Fresh Sound',
        );

        // First fetch returns event1
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event1]);

        await repository.fetchTrendingSounds();
        expect(repository.cachedSoundCount, 1);
        expect(repository.getSoundFromCache(testEventId1), isNotNull);

        // Refresh returns event2 only
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event2]);

        await repository.refresh();

        expect(repository.cachedSoundCount, 1);
        expect(repository.getSoundFromCache(testEventId1), isNull);
        expect(repository.getSoundFromCache(testEventId2), isNotNull);
      });
    });

    group('dispose', () {
      test('closes resources without error', () async {
        await repository.initialize();

        expect(() => repository.dispose(), returnsNormally);
      });
    });

    group('real-time subscription', () {
      late StreamController<Event> streamController;

      setUp(() {
        streamController = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).thenAnswer((_) => streamController.stream);
      });

      tearDown(() async {
        await streamController.close();
      });

      test('caches events from real-time subscription', () async {
        await repository.initialize();

        final event = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Real-time Sound',
        );

        streamController.add(event);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.getSoundFromCache(testEventId1), isNotNull);
      });

      test('subscribes to audio MIME types only', () async {
        await repository.initialize();

        final captured = verify(
          () => mockNostrClient.subscribe(
            captureAny(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            onEose: any(named: 'onEose'),
          ),
        ).captured;

        final filters = captured.single as List<Filter>;
        expect(filters.single.kinds, equals([audioEventKind]));
        expect(filters.single.m, equals(SoundsRepository.audioMimeTypes));
      });

      test('ignores Kind 1063 files that are not audio', () async {
        await repository.initialize();

        streamController.add(
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Flyer',
            url: 'https://example.com/flyer.pdf',
            mimeType: 'application/pdf',
          ),
        );
        await pumpEventQueue();

        expect(repository.getSoundFromCache(testEventId1), isNull);
      });

      test('ignores non-audio events from subscription', () async {
        await repository.initialize();

        final textEvent = Event.fromJson({
          'id': testEventId1,
          'pubkey': testPubkey1,
          'kind': 1, // Kind 1 = text note
          'tags': <List<dynamic>>[],
          'content': 'Not audio',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'sig': '',
        });

        streamController.add(textEvent);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(repository.getSoundFromCache(testEventId1), isNull);
      });

      test('handles subscription stream errors gracefully', () async {
        await repository.initialize();

        streamController.addError(Exception('Relay disconnected'));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Repository should still be functional after stream error
        expect(repository.isInitialized, isTrue);
      });
    });

    group('error handling', () {
      test('initialize catches error from fetchTrendingSounds', () async {
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Network error'));

        await repository.initialize();

        // Should not be marked as initialized on error
        expect(repository.isInitialized, isFalse);
      });

      test('fetchTrendingSounds rethrows on error', () async {
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.fetchTrendingSounds(),
          throwsA(isA<Exception>()),
        );
      });

      test('fetchSoundsByCreator rethrows on error', () async {
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.fetchSoundsByCreator(testPubkey1),
          throwsA(isA<Exception>()),
        );
      });

      test('fetchSoundById rethrows on error', () async {
        when(
          () => mockNostrClient.fetchEventById(testEventId1),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.fetchSoundById(testEventId1),
          throwsA(isA<Exception>()),
        );
      });

      test('fetchVideosUsingSound rethrows on error', () async {
        when(
          () => mockNostrClient.queryEvents(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
            useCache: any(named: 'useCache'),
          ),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.fetchVideosUsingSound(testEventId1),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
