// ABOUTME: Unit tests for SoundsRepository
// ABOUTME: Tests fetching, caching, and querying Kind 1063 audio events

import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

    /// A read of the newest sounds, or the newest by some creators: one
    /// filter for sounds, with no ids, words or tags to match.
    final isNewestRead = predicate<List<Filter>>(
      (filters) =>
          filters.length == 1 &&
          filters.single.ids == null &&
          filters.single.search == null &&
          filters.single.t == null &&
          (filters.single.kinds?.contains(audioEventKind) ?? false),
      'a read of the newest sounds',
    );

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(<int>[]);
      registerFallbackValue(SoundKind.music);
      registerFallbackValue(SoundListSort.recent);
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
        () => mockNostrClient.queryEventsDetailed(
          any(that: isNewestRead),
          useCache: any(named: 'useCache'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      when(
        () => mockNostrClient.countEvents(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          relayTypes: any(named: 'relayTypes'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer((_) async => const CountResult(isComplete: true, count: 0));

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

    /// The lookup, by id, of the sounds a ranking or a search named.
    final isIdLookup = predicate<List<Filter>>(
      (filters) => filters.any((filter) => filter.ids != null),
      'the lookup by id',
    );

    /// Answers the lookup by id on the shared connections with [events],
    /// ended as [timedOut] says.
    void answerIdLookup(List<Event> events, {bool timedOut = false}) {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(that: isIdLookup),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: false),
      );
    }

    /// The ids each lookup on the shared connections asked for.
    List<List<String>?> idLookups() => [
      for (final filters in verify(
        () => mockNostrClient.queryEventsDetailed(
          captureAny(that: isIdLookup),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).captured)
        (filters as List<Filter>).single.ids,
    ];

    /// Answers the reads of the newest sounds on the shared connections with
    /// [events], ended as [timedOut] says.
    void answerNewest(List<Event> events, {bool timedOut = false}) {
      when(
        () => mockNostrClient.queryEventsDetailed(
          any(that: isNewestRead),
          useCache: any(named: 'useCache'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).thenAnswer(
        (_) async => (events: events, timedOut: timedOut, noRelays: false),
      );
    }

    /// The filter of each read of the newest sounds on the shared
    /// connections.
    List<Filter> newestReads() => [
      for (final filters in verify(
        () => mockNostrClient.queryEventsDetailed(
          captureAny(that: isNewestRead),
          useCache: any(named: 'useCache'),
          timeout: any(named: 'timeout'),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        ),
      ).captured)
        (filters as List<Filter>).single,
    ];

    void verifyNoIdLookup() => verifyNever(
      () => mockNostrClient.queryEventsDetailed(
        any(that: isIdLookup),
        timeout: any(named: 'timeout'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    );

    group('initialization', () {
      test('initializes with empty cache', () async {
        await repository.initialize();

        expect(repository.isInitialized, isTrue);
        expect(repository.cachedSoundCount, 0);
        expect(repository.cachedSounds, isEmpty);
      });

      test('does not reinitialize if already initialized', () async {
        answerNewest([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Test Sound',
          ),
        ]);

        await repository.initialize();
        expect(repository.isInitialized, isTrue);
        expect(repository.cachedSoundCount, 1);

        // Second call should return immediately
        await repository.initialize();
        expect(repository.isInitialized, isTrue);

        expect(newestReads(), hasLength(1));
      });
    });

    group('fetchTrendingSounds', () {
      test('returns empty list when no sounds exist', () async {
        answerNewest([]);

        final sounds = await repository.fetchTrendingSounds();

        expect(sounds, isEmpty);
      });

      test('asks only for sounds up to until', () async {
        answerNewest([]);

        await repository.fetchTrendingSounds(limit: 100, until: 1500);

        final filter = newestReads().single;
        expect(filter.until, 1500);
        expect(filter.limit, 100);
      });

      test(
        'reads what the device holds when no relay can be reached',
        () async {
          final cached = createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Cached',
          );
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(that: isNewestRead),
              useCache: any(named: 'useCache'),
              timeout: any(named: 'timeout'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer(
            (_) async => (events: <Event>[], timedOut: false, noRelays: true),
          );
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [cached]);

          final sounds = await repository.fetchTrendingSounds(until: 1500);

          expect(sounds.map((sound) => sound.id), [testEventId1]);
          final filter =
              (verify(
                        () => mockNostrClient.queryEvents(captureAny()),
                      ).captured.single
                      as List<Filter>)
                  .single;
          expect(filter.until, 1500);
        },
      );

      test('waits for every relay to answer', () async {
        await repository.fetchTrendingSounds();

        verify(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isNewestRead),
            useCache: false,
            timeout: SoundsRepository.newestSoundsTimeout,
            requireAllRelaysSettled: true,
          ),
        ).called(1);
        verifyNever(
          () => mockNostrClient.queryEventsOnFreshConnections(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('asks again on connections of its own when a relay is still busy '
          'and keeps the newest of both answers', () async {
        // The shared connection ended on what the local cache held, as it
        // does while the relay works through the requests queued ahead.
        final cached = createAudioEvent(
          id: testEventId1,
          pubkey: testPubkey1,
          title: 'Cached',
          createdAt: 3000,
        );
        answerNewest([cached], timedOut: true);
        when(
          () => mockNostrClient.queryEventsOnFreshConnections(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (
            events: [
              cached,
              createAudioEvent(
                id: testEventId2,
                pubkey: testPubkey2,
                title: 'Newest',
                createdAt: 4000,
              ),
              createAudioEvent(
                id: testVideoEventId,
                pubkey: testPubkey2,
                title: 'Oldest',
                createdAt: 1000,
              ),
            ],
            timedOut: false,
            noRelays: false,
          ),
        );

        final sounds = await repository.fetchTrendingSounds(
          limit: 2,
          until: 5000,
        );

        expect(sounds.map((sound) => sound.id), [testEventId2, testEventId1]);
        final filter =
            (verify(
                      () => mockNostrClient.queryEventsOnFreshConnections(
                        captureAny(),
                        timeout: SoundsRepository.freshSoundLookupTimeout,
                      ),
                    ).captured.single
                    as List<Filter>)
                .single;
        expect(filter.until, 5000);
        expect(filter.limit, 2);
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

        answerNewest([event1, event2]);

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
        answerNewest([]);

        await repository.fetchTrendingSounds(limit: 25);

        final filter = newestReads().single;
        expect(filter.limit, 25);
        expect(filter.kinds, contains(audioEventKind));
      });

      test('asks the relay for audio MIME types only', () async {
        // Kind 1063 is generic file metadata, so without `#m` the relay
        // spends the limit on whatever files other clients published last.
        await repository.fetchTrendingSounds();

        expect(
          newestReads().single.m,
          equals(SoundsRepository.audioMimeTypes),
        );
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

        answerNewest([sound, pdf, untyped]);

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

        answerNewest([audioEvent, wrongKindEvent]);

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
          (filter) =>
              (filter.kinds?.contains(audioEventKind) ?? false) &&
              filter.ids == null,
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
        answerNewest(events);
        await repository.fetchTrendingSounds();
      }

      test('returns nothing and does not query for a blank query', () async {
        final results = await repository.searchSounds('  #  ');

        expect(results.sounds, isEmpty);
        expect(results.relays, SoundSearchRelays.notAsked);
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
          final sounds = (await repository.searchSounds('still snacks')).sounds;

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

        final results = await repository.searchSounds('hooves');

        expect(results.sounds.map((sound) => sound.id), equals([testEventId1]));
        expect(results.relays, SoundSearchRelays.answered);
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

        final sounds = (await repository.searchSounds('horses hooves')).sounds;

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

        final sounds = (await repository.searchSounds('wind')).sounds;

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

        final sounds = (await repository.searchSounds('crowd')).sounds;

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

        final sounds = (await repository.searchSounds('crowd')).sounds;

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

          final sounds = (await repository.searchSounds('crowd')).sounds;

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

        final results = await repository.searchSounds('wind');

        expect(results.sounds.map((sound) => sound.id), equals([testEventId1]));
        expect(
          results.relays,
          SoundSearchRelays.failed,
          reason: 'the cached matches stand in for the relays, and say so',
        );
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

        Future<void> expectUnnamedLastWithoutLookup(
          SoundSearchRelays expectedRelays,
        ) async {
          final results = await repository.searchSounds('wind');

          expect(
            results.sounds.map((sound) => sound.id),
            equals([testEventId1, testEventId3]),
          );
          expect(results.relays, expectedRelays);
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

          await expectUnnamedLastWithoutLookup(SoundSearchRelays.failed);
        });

        test('lists unnamed sounds last without a reuse lookup when it '
            'times out', () async {
          await primeUnnamedAndNamed();
          answerTagQuery(const [], timedOut: true);

          await expectUnnamedLastWithoutLookup(SoundSearchRelays.timedOut);
        });

        test('lists unnamed sounds last without a reuse lookup when it '
            'reaches no relay', () async {
          await primeUnnamedAndNamed();
          answerTagQuery(const [], noRelays: true);

          await expectUnnamedLastWithoutLookup(SoundSearchRelays.noRelays);
        });

        test('reports no relays when no relay took the query, even if the '
            'read also ran out of time', () async {
          await primeUnnamedAndNamed();
          answerTagQuery(const [], timedOut: true, noRelays: true);

          await expectUnnamedLastWithoutLookup(SoundSearchRelays.noRelays);
        });

        test('keeps what arrived before the deadline', () async {
          answerTagQuery([
            createAudioEvent(
              id: testEventId2,
              pubkey: testPubkey2,
              title: 'Wind chimes',
              createdAt: 3000,
            ),
          ], timedOut: true);

          final results = await repository.searchSounds('wind');

          expect(
            results.sounds.map((sound) => sound.id),
            equals([testEventId2]),
          );
          expect(results.relays, SoundSearchRelays.timedOut);
        });
      });

      test('narrows the relay results to the followed accounts', () async {
        answerTagQuery([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Rain followed',
          ),
          createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey2,
            title: 'Rain stranger',
          ),
        ]);

        final results = await repository.searchSounds(
          'rain',
          followedBy: const [testPubkey1],
        );

        expect(results.sounds.map((sound) => sound.id), [testEventId1]);
        final filters =
            verify(
                  () => mockNostrClient.queryEventsDetailed(
                    captureAny(that: isTagQuery),
                  ),
                ).captured.single
                as List<Filter>;
        expect(
          filters.map((filter) => filter.authors),
          everyElement([testPubkey1]),
        );
      });

      test('narrows the relay results to a kind by their tags', () async {
        answerTagQuery([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Rain boom',
            publicTags: const ['sfx'],
          ),
          createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey1,
            title: 'Rain song',
            publicTags: const ['music'],
          ),
          createAudioEvent(
            id: testEventId3,
            pubkey: testPubkey1,
            title: 'Rain on a roof',
          ),
        ]);

        final effects = await repository.searchSounds(
          'rain',
          kind: SoundKind.effect,
        );
        final every = await repository.searchSounds('rain');

        expect(effects.sounds.map((sound) => sound.id), [testEventId1]);
        expect(every.sounds, hasLength(3));
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

      group('through Funnelcake', () {
        late _MockFunnelcakeApiClient funnelcake;
        late SoundsRepository searching;

        setUp(() {
          funnelcake = _MockFunnelcakeApiClient();
          when(() => funnelcake.isAvailable).thenReturn(true);
          searching = SoundsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: funnelcake,
          );
          addTearDown(searching.dispose);
        });

        SoundStats found(String id, int usageCount) => SoundStats(
          id: id,
          pubkey: testPubkey1,
          title: 'Sound',
          createdAt: DateTime.utc(2026),
          usageCount: usageCount,
        );

        void answerSearch(
          List<SoundStats> sounds, {
          String? nextCursor,
        }) {
          when(
            () => funnelcake.searchSounds(
              query: any(named: 'query'),
              kind: any(named: 'kind'),
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          ).thenAnswer(
            (_) async =>
                SoundSearchResponse(sounds: sounds, nextCursor: nextCursor),
          );
        }

        void failSearch(Exception error) {
          when(
            () => funnelcake.searchSounds(
              query: any(named: 'query'),
              kind: any(named: 'kind'),
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          ).thenThrow(error);
        }

        test(
          'keeps the Funnelcake ranking and loads the events from relays',
          () async {
            answerSearch([
              found(testEventId2, 28),
              found(testEventId1, 60),
              found(testEventId3, 5),
            ], nextCursor: '50');
            // Returned newest first and missing the third sound found.
            answerIdLookup([
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
            ]);

            final results = await searching.searchSounds('wind', limit: 20);

            expect(results.sounds.map((sound) => sound.id), [
              testEventId2,
              testEventId1,
            ]);
            expect(results.source, SoundSearchSource.funnelcake);
            expect(results.relays, SoundSearchRelays.notAsked);
            expect(results.usageCounts, {
              testEventId2: 28,
              testEventId1: 60,
              testEventId3: 5,
            });
            expect(results.nextCursor, '50');
            verify(
              () => funnelcake.searchSounds(query: 'wind', limit: 20),
            ).called(1);
            expect(idLookups(), [
              [testEventId2, testEventId1, testEventId3],
            ]);
            verifyNever(
              () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
            );
          },
        );

        test('keeps a sound only a typo-tolerant search finds', () async {
          answerSearch([found(testEventId1, 1)]);
          answerIdLookup([
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Coolness lol',
            ),
          ]);

          final results = await searching.searchSounds('coalness');

          expect(results.sounds.single.title, 'Coolness lol');
          expect(results.sounds.single.matchesSearch('coalness'), isFalse);
          expect(results.nextCursor, isNull);
        });

        test('sends the search terms, not the raw query', () async {
          answerSearch(const []);

          await searching.searchSounds('  Horses #Hooves horses ');

          verify(
            () => funnelcake.searchSounds(query: 'horses hooves'),
          ).called(1);
        });

        test('asks Funnelcake for the kind picked', () async {
          answerSearch(const []);

          await searching.searchSounds('rain', kind: SoundKind.effect);

          verify(
            () => funnelcake.searchSounds(
              query: 'rain',
              kind: SoundKind.effect,
            ),
          ).called(1);
        });

        test('searches only the followed accounts it can ask about', () async {
          answerSearch(const []);

          await searching.searchSounds(
            'rain',
            followedBy: const [testPubkey1, 'not-a-key'],
          );

          verify(
            () => funnelcake.searchSounds(
              query: 'rain',
              authors: [testPubkey1],
            ),
          ).called(1);
        });

        test('finds nothing, without asking, when no followed account is '
            'left', () async {
          final results = await searching.searchSounds(
            'rain',
            followedBy: const ['not-a-key'],
          );

          expect(results.sounds, isEmpty);
          expect(results.relays, SoundSearchRelays.notAsked);
          verifyNever(
            () => funnelcake.searchSounds(
              query: any(named: 'query'),
              kind: any(named: 'kind'),
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          );
          verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
        });

        test('asks Funnelcake for the page after cursor', () async {
          answerSearch(const []);

          final results = await searching.searchSounds('wind', cursor: '50');

          expect(results.source, SoundSearchSource.funnelcake);
          verify(
            () => funnelcake.searchSounds(query: 'wind', cursor: '50'),
          ).called(1);
        });

        for (final (name, failure, reason) in <(String, Exception, String)>[
          (
            'an error status',
            const FunnelcakeApiException(
              message: 'unavailable',
              statusCode: 503,
              url: 'https://example.com/api/v2/search/sounds?q=wind',
            ),
            'status 503',
          ),
          (
            'a timeout',
            const FunnelcakeTimeoutException(
              'https://example.com/api/v2/search/sounds?q=wind',
            ),
            'FunnelcakeTimeoutException',
          ),
        ]) {
          test('throws for a later page that fails with $name, naming only '
              'why, without the relays', () async {
            failSearch(failure);

            final error = await searching
                .searchSounds('wind', cursor: '50')
                .then<Object?>((_) => null, onError: (Object e) => e);

            expect(
              error,
              isA<SoundSearchPageException>().having(
                (e) => e.reason,
                'reason',
                reason,
              ),
            );
            expect('$error', isNot(contains('wind')));
            verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
          });
        }

        test('throws for a later page without a Funnelcake client', () async {
          await expectLater(
            repository.searchSounds('wind', cursor: '50'),
            throwsA(isA<FunnelcakeNotConfiguredException>()),
          );
          verifyNever(() => mockNostrClient.queryEventsDetailed(any()));
        });

        for (final (name, failure) in <(String, Exception)>[
          (
            'unavailable',
            const FunnelcakeApiException(
              message: 'unavailable',
              statusCode: 503,
              url: 'https://example.com',
            ),
          ),
          (
            'refusing the query',
            const FunnelcakeApiException(
              message: 'bad request',
              statusCode: 400,
              url: 'https://example.com',
            ),
          ),
          ('timing out', const FunnelcakeTimeoutException()),
          ('answering nonsense', const FunnelcakeException('malformed')),
        ]) {
          test('searches the relays when Funnelcake is $name', () async {
            failSearch(failure);
            answerTagQuery([
              createAudioEvent(
                id: testEventId1,
                pubkey: testPubkey1,
                title: 'Wind chimes',
              ),
            ]);

            final results = await searching.searchSounds('wind');

            expect(results.sounds.map((sound) => sound.id), [testEventId1]);
            expect(results.source, SoundSearchSource.relays);
            expect(results.relays, SoundSearchRelays.answered);
            expect(results.usageCounts, isEmpty);
            expect(results.nextCursor, isNull);
          });
        }

        test(
          'searches the relays when they cannot load what Funnelcake found',
          () async {
            answerSearch([found(testEventId1, 1)]);
            when(
              () => mockNostrClient.queryEventsDetailed(
                any(that: isIdLookup),
                timeout: any(named: 'timeout'),
                requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
              ),
            ).thenThrow(Exception('relay down'));

            final results = await searching.searchSounds('wind');

            expect(results.source, SoundSearchSource.relays);
            verify(
              () => mockNostrClient.queryEventsDetailed(any(that: isTagQuery)),
            ).called(1);
          },
        );

        test(
          'searches only the relays while Funnelcake is not configured',
          () async {
            when(() => funnelcake.isAvailable).thenReturn(false);

            final results = await searching.searchSounds('wind');

            expect(results.source, SoundSearchSource.relays);
            verifyNever(
              () => funnelcake.searchSounds(
                query: any(named: 'query'),
                kind: any(named: 'kind'),
                authors: any(named: 'authors'),
                limit: any(named: 'limit'),
                cursor: any(named: 'cursor'),
              ),
            );
          },
        );

        test('answers a blank query without asking Funnelcake', () async {
          final results = await searching.searchSounds('  #  ');

          expect(results.sounds, isEmpty);
          expect(results.relays, SoundSearchRelays.notAsked);
          verifyNever(
            () => funnelcake.searchSounds(
              query: any(named: 'query'),
              kind: any(named: 'kind'),
              authors: any(named: 'authors'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          );
        });
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

    for (final failure in ['missing', 'offline', 'unconfigured']) {
      test(
        'legacy link stays closed when its current source is $failure',
        () async {
          final api = _MockFunnelcakeApiClient();
          when(() => api.isAvailable).thenReturn(failure != 'unconfigured');
          when(() => api.getVideoEvent(testVideoEventId)).thenAnswer((_) async {
            if (failure == 'offline') throw Exception('offline');
            return null;
          });
          final oldVideo = Event.fromJson({
            'id': testVideoEventId,
            'pubkey': testPubkey1,
            'kind': 34236,
            'created_at': 1000,
            'content': 'An obsolete caption',
            'tags': [
              ['d', 'puppet-show'],
              ['platform', 'vine'],
            ],
            'sig': '',
          });
          when(
            () => mockNostrClient.fetchEventById(testVideoEventId),
          ).thenAnswer((_) async => oldVideo);
          final sounds = SoundsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: api,
          );
          addTearDown(sounds.dispose);

          expect(
            await sounds.fetchSoundById('video_$testVideoEventId'),
            isNull,
          );
          verifyNever(() => mockNostrClient.fetchEventById(testVideoEventId));
        },
      );
    }

    test(
      'a current classic awaiting backfill resolves its named original sound',
      () async {
        final api = _MockFunnelcakeApiClient();
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getVideoEvent(testVideoEventId)).thenAnswer(
          (_) async => Event.fromJson({
            'id': testEventId2,
            'pubkey': testPubkey1,
            'kind': 34236,
            'created_at': 2000,
            'content': 'A tiny puppet show',
            'tags': [
              ['d', 'puppet-show'],
              ['platform', 'vine'],
              ['author', 'Alex'],
              ['imeta', 'url https://example.com/classic.mp4', 'm video/mp4'],
            ],
            'sig': '',
          }),
        );
        final sounds = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: api,
        );
        addTearDown(sounds.dispose);

        final sound = await sounds.fetchSoundById('video_$testVideoEventId');

        expect(sound?.id, 'video_$testEventId2');
        expect(sound?.title, 'A tiny puppet show');
        expect(sound?.sourceVideoReference, '34236:$testPubkey1:puppet-show');
        expect(sound?.url, 'https://example.com/classic.mp4');
        expect(
          sound?.allowsReuse,
          isFalse,
          reason: 'reuse requires separate current server policy',
        );
      },
    );

    group('the sounds a ranking names', () {
      late _MockFunnelcakeApiClient funnelcake;
      late SoundsRepository ranking;
      final first = createAudioEvent(
        id: testEventId1,
        pubkey: testPubkey1,
        title: 'First',
      );
      final second = createAudioEvent(
        id: testEventId2,
        pubkey: testPubkey1,
        title: 'Second',
      );

      setUp(() {
        funnelcake = _MockFunnelcakeApiClient();
        when(() => funnelcake.isAvailable).thenReturn(true);
        when(
          () => funnelcake.listSounds(
            sort: any(named: 'sort'),
            authors: any(named: 'authors'),
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => SoundSearchResponse(
            sounds: [
              for (final id in [testEventId1, testEventId2])
                SoundStats(
                  id: id,
                  pubkey: testPubkey1,
                  title: 'Sound',
                  createdAt: DateTime.utc(2026),
                  usageCount: 1,
                ),
            ],
          ),
        );
        ranking = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
        );
        addTearDown(ranking.dispose);
      });

      void answerFreshLookup(List<Event> events) {
        when(
          () => mockNostrClient.queryEventsOnFreshConnections(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).thenAnswer(
          (_) async => (events: events, timedOut: false, noRelays: false),
        );
      }

      test('waits for every relay to answer, within its timeout', () async {
        answerIdLookup([first, second]);

        final popular = await ranking.fetchPopularSounds();

        expect(popular.sounds.map((sound) => sound.id), [
          testEventId1,
          testEventId2,
        ]);
        verify(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isIdLookup),
            timeout: SoundsRepository.soundLookupTimeout,
            requireAllRelaysSettled: true,
          ),
        ).called(1);
      });

      test('does not ask again for the sounds it holds', () async {
        answerNewest([first]);
        await ranking.fetchTrendingSounds();
        answerIdLookup([second]);

        final popular = await ranking.fetchPopularSounds();

        expect(popular.sounds.map((sound) => sound.id), [
          testEventId1,
          testEventId2,
        ]);
        expect(idLookups(), [
          [testEventId2],
        ]);
      });

      test('asks for what a busy relay left out on connections of its '
          'own', () async {
        // The relay was still busy with requests queued ahead of this one,
        // so the read ran out of time holding only the cached sound.
        answerIdLookup([first], timedOut: true);
        answerFreshLookup([second]);

        final popular = await ranking.fetchPopularSounds();

        expect(popular.sounds.map((sound) => sound.id), [
          testEventId1,
          testEventId2,
        ]);
        final retried =
            verify(
                  () => mockNostrClient.queryEventsOnFreshConnections(
                    captureAny(),
                    timeout: SoundsRepository.freshSoundLookupTimeout,
                  ),
                ).captured.single
                as List<Filter>;
        expect(retried.single.ids, [testEventId2]);
      });

      test('does not ask again when every relay answered', () async {
        answerIdLookup([first]);

        final popular = await ranking.fetchPopularSounds();

        expect(popular.sounds.map((sound) => sound.id), [testEventId1]);
        verifyNever(
          () => mockNostrClient.queryEventsOnFreshConnections(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });
    });

    group('the picker lists', () {
      late _MockFunnelcakeApiClient funnelcake;
      late SoundsRepository lists;
      const followedA =
          'aa00000000000000000000000000000000000000000000000000000000000001';
      const followedB =
          'aa00000000000000000000000000000000000000000000000000000000000002';
      const blockedAuthor =
          'aa00000000000000000000000000000000000000000000000000000000000003';
      const divineAuthor =
          'aa00000000000000000000000000000000000000000000000000000000000004';

      SoundStats indexed(String id, {int usageCount = 3}) => SoundStats(
        id: id,
        pubkey: testPubkey1,
        title: 'Sound',
        createdAt: DateTime.utc(2026),
        usageCount: usageCount,
      );

      void answerIndex(List<SoundStats> sounds, {String? nextCursor}) {
        when(
          () => funnelcake.listSounds(
            sort: any(named: 'sort'),
            authors: any(named: 'authors'),
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async =>
              SoundSearchResponse(sounds: sounds, nextCursor: nextCursor),
        );
      }

      void verifyIndexNotAsked() => verifyNever(
        () => funnelcake.listSounds(
          sort: any(named: 'sort'),
          authors: any(named: 'authors'),
          kind: any(named: 'kind'),
          limit: any(named: 'limit'),
          cursor: any(named: 'cursor'),
        ),
      );

      setUp(() {
        funnelcake = _MockFunnelcakeApiClient();
        when(() => funnelcake.isAvailable).thenReturn(true);
        answerIndex([
          indexed(testEventId2),
          indexed(testEventId1, usageCount: 7),
        ], nextCursor: 'o:100');
        answerIdLookup([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Boom',
          ),
          createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey2,
            title: 'Crash',
          ),
        ]);
        lists = SoundsRepository(
          nostrClient: mockNostrClient,
          funnelcakeApiClient: funnelcake,
          divineSoundPublishers: const {divineAuthor},
          blockFilter: (pubkey) => pubkey == blockedAuthor,
        );
        addTearDown(lists.dispose);
      });

      group('with the events Funnelcake sent along', () {
        const videoPubkey =
            'ee00000000000000000000000000000000000000000000000000000000000001';
        const otherVideoPubkey =
            'ee00000000000000000000000000000000000000000000000000000000000002';
        const reference = '34236:$videoPubkey:clip';

        /// A sound event with a playable URL, named after [videoTags], the
        /// `a` tags it carries in order.
        Event soundEvent(
          String id, {
          List<String> videoTags = const [reference],
          String? url = 'https://example.com/audio.mp3',
        }) => Event.fromJson({
          'id': id,
          'pubkey': testPubkey1,
          'created_at': 1780000000,
          'kind': audioEventKind,
          'tags': [
            ?(url == null ? null : ['url', url]),
            ['m', 'audio/mpeg'],
            ['title', 'Boom'],
            for (final tag in videoTags) ['a', tag],
          ],
          'content': '',
          'sig': 'b' * 128,
        });

        Event videoEvent({
          String pubkey = videoPubkey,
          String dTag = 'clip',
          int kind = 34236,
        }) => Event.fromJson({
          'id': testVideoEventId,
          'pubkey': pubkey,
          'created_at': 1780000000,
          'kind': kind,
          'tags': [
            ['d', dTag],
            ['url', 'https://example.com/video.mp4'],
          ],
          'content': '',
          'sig': 'c' * 128,
        });

        SoundStats sent(
          String id, {
          Event? event,
          bool sourceEventKnown = true,
          Event? sourceEvent,
        }) => SoundStats(
          id: id,
          pubkey: testPubkey1,
          title: 'Boom',
          createdAt: DateTime.utc(2026),
          usageCount: 3,
          event: event ?? soundEvent(id),
          sourceEventKnown: sourceEventKnown,
          sourceEvent: sourceEvent,
        );

        void verifyNoIdLookup() => verifyNever(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isIdLookup),
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );

        test('takes those sounds from their events and asks the relays only '
            'for the rest', () async {
          answerIndex([sent(testEventId2), indexed(testEventId1)]);
          answerIdLookup([
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Crash',
            ),
          ]);

          final page = await lists.fetchNewestSounds();

          expect(page.sounds.map((sound) => sound.id), [
            testEventId2,
            testEventId1,
          ]);
          expect(page.sounds.first.sourceVideoReference, reference);
          expect(idLookups(), [
            [testEventId1],
          ]);
        });

        test('asks the relays nothing when every sound came with its '
            'event', () async {
          answerIndex([sent(testEventId1), sent(testEventId2)]);

          final page = await lists.fetchNewestSounds();

          expect(page.sounds, hasLength(2));
          verifyNoIdLookup();
        });

        test('leaves out a sent event that is no playable sound without '
            'asking the relays for it', () async {
          answerIndex([
            sent(testEventId1, event: soundEvent(testEventId1, url: null)),
          ]);

          final page = await lists.fetchNewestSounds();

          expect(page.sounds, isEmpty);
          verifyNoIdLookup();
        });

        test(
          "asks the relays for a sound whose sent event is another's",
          () async {
            answerIndex([
              sent(testEventId1, event: soundEvent(testEventId2)),
            ]);

            await lists.fetchNewestSounds();

            expect(idLookups(), [
              [testEventId1],
            ]);
          },
        );

        group('sourceVideosFromIndex', () {
          test('keeps the video Funnelcake found, and the one it shows no '
              'one', () async {
            const goneReference = '34236:$otherVideoPubkey:gone';
            final video = videoEvent();
            answerIndex([
              sent(testEventId1, sourceEvent: video),
              sent(
                testEventId2,
                event: soundEvent(
                  testEventId2,
                  videoTags: const [goneReference],
                ),
              ),
            ]);

            await lists.fetchNewestSounds();

            final answers = lists.sourceVideosFromIndex([
              reference,
              goneReference,
              '34236:$videoPubkey:never-listed',
            ]);
            expect(answers.keys, [reference, goneReference]);
            expect(answers[reference]?.id, video.id);
            expect(answers[goneReference], isNull);
          });

          test('says nothing when Funnelcake did not', () async {
            answerIndex([
              sent(
                testEventId1,
                sourceEventKnown: false,
                sourceEvent: videoEvent(),
              ),
            ]);

            await lists.fetchNewestSounds();

            expect(lists.sourceVideosFromIndex([reference]), isEmpty);
          });

          test(
            'says nothing about a sound Funnelcake sent no event for',
            () async {
              answerIndex([
                SoundStats(
                  id: testEventId1,
                  pubkey: testPubkey1,
                  title: 'Boom',
                  createdAt: DateTime.utc(2026),
                  usageCount: 3,
                  sourceEventKnown: true,
                ),
              ]);
              answerIdLookup([soundEvent(testEventId1)]);

              await lists.fetchNewestSounds();

              expect(lists.sourceVideosFromIndex([reference]), isEmpty);
            },
          );

          test('says nothing when Funnelcake may have read another a '
              'tag', () async {
            const lastReference = '34236:$otherVideoPubkey:last';
            answerIndex([
              sent(
                testEventId1,
                event: soundEvent(
                  testEventId1,
                  videoTags: const [reference, lastReference],
                ),
              ),
              sent(
                testEventId2,
                event: soundEvent(
                  testEventId2,
                  videoTags: const ['30023:$videoPubkey:article'],
                ),
              ),
            ]);

            await lists.fetchNewestSounds();

            expect(
              lists.sourceVideosFromIndex([
                reference,
                lastReference,
                '30023:$videoPubkey:article',
              ]),
              isEmpty,
            );
          });

          for (final (part, lastReference) in const [
            ('d tag', '34236:$videoPubkey:last'),
            ('public key', '34236:$otherVideoPubkey:clip'),
            ('kind', '34235:$videoPubkey:clip'),
          ]) {
            test('says nothing when the last a tag differs from the first '
                'only in its $part', () async {
              answerIndex([
                sent(
                  testEventId1,
                  event: soundEvent(
                    testEventId1,
                    videoTags: [reference, lastReference],
                  ),
                  sourceEvent: videoEvent(),
                ),
              ]);

              await lists.fetchNewestSounds();

              expect(lists.sourceVideosFromIndex([lastReference]), isEmpty);
            });
          }

          test('says nothing when the video sent is another one', () async {
            answerIndex([
              sent(testEventId1, sourceEvent: videoEvent(dTag: 'other')),
            ]);

            await lists.fetchNewestSounds();

            expect(lists.sourceVideosFromIndex([reference]), isEmpty);
          });

          test('matches a public key the a tag spells in capitals', () async {
            final spelled = '34236:${videoPubkey.toUpperCase()}:clip';
            answerIndex([
              sent(
                testEventId1,
                event: soundEvent(testEventId1, videoTags: [spelled]),
                sourceEvent: videoEvent(),
              ),
            ]);

            await lists.fetchNewestSounds();

            expect(
              lists.sourceVideosFromIndex([spelled])[spelled]?.id,
              testVideoEventId,
            );
          });

          test('keeps the newest answers', () async {
            String id(int i) => i.toRadixString(16).padLeft(64, '0');
            String clip(int i) => '34236:$videoPubkey:clip-$i';
            const count = SoundsRepository.maxIndexedSourceVideos + 1;
            answerIndex([
              for (var i = 0; i < count; i++)
                sent(
                  id(i),
                  event: soundEvent(id(i), videoTags: [clip(i)]),
                ),
            ]);

            await lists.fetchNewestSounds();

            final answers = lists.sourceVideosFromIndex([
              for (var i = 0; i < count; i++) clip(i),
            ]);
            expect(answers, hasLength(SoundsRepository.maxIndexedSourceVideos));
            expect(answers.containsKey(clip(0)), isFalse);
            expect(answers.containsKey(clip(count - 1)), isTrue);
          });
        });
      });

      group('fetchNewestSounds', () {
        test('lists the newest sounds in the index order', () async {
          final page = await lists.fetchNewestSounds();

          expect(page.sounds.map((sound) => sound.id), [
            testEventId2,
            testEventId1,
          ]);
          expect(page.usageCounts, {testEventId2: 3, testEventId1: 7});
          expect(page.nextCursor, 'o:100');
          verify(
            () => funnelcake.listSounds(
              limit: SoundsRepository.newestListPageSize,
            ),
          ).called(1);
        });

        test('lists those of a kind from where the cursor points', () async {
          await lists.fetchNewestSounds(kind: SoundKind.effect, cursor: 'o:0');

          verify(
            () => funnelcake.listSounds(
              kind: SoundKind.effect,
              limit: SoundsRepository.newestListPageSize,
              cursor: 'o:0',
            ),
          ).called(1);
        });

        test("leaves out a video's own sound until a second video uses "
            'it', () async {
          answerIndex([
            indexed(testEventId1, usageCount: 1),
            indexed(testEventId2, usageCount: 2),
            indexed(testVideoEventId, usageCount: 1),
          ]);
          answerIdLookup([
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Original sound - Funny God',
            ),
            createAudioEvent(
              id: testEventId2,
              pubkey: testPubkey1,
              title: 'Original sound',
            ),
            createAudioEvent(
              id: testVideoEventId,
              pubkey: testPubkey1,
              title: 'Named on its own',
            ),
          ]);

          final page = await lists.fetchNewestSounds();

          expect(page.sounds.map((sound) => sound.id), [
            testEventId2,
            testVideoEventId,
          ]);
        });

        test('leaves out sounds by blocked authors', () async {
          final blocking = SoundsRepository(
            nostrClient: mockNostrClient,
            funnelcakeApiClient: funnelcake,
            blockFilter: (pubkey) => pubkey == testPubkey2,
          );
          addTearDown(blocking.dispose);

          final page = await blocking.fetchNewestSounds();

          expect(page.sounds.map((sound) => sound.id), [testEventId1]);
        });

        group('from the relays', () {
          final rain = createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Rain',
            createdAt: 2000,
            publicTags: const ['sfx'],
          );
          final song = createAudioEvent(
            id: testEventId2,
            pubkey: testPubkey2,
            title: 'Song',
            createdAt: 1500,
            publicTags: const ['music'],
          );

          setUp(() => answerNewest([rain, song]));

          test('lists the newest when Funnelcake is not configured', () async {
            when(() => funnelcake.isAvailable).thenReturn(false);

            final page = await lists.fetchNewestSounds();

            expect(page.sounds.map((sound) => sound.id), [
              testEventId1,
              testEventId2,
            ]);
            expect(page.usageCounts, isEmpty);
            expect(page.nextCursor, 'relays:1500');
            expect(
              newestReads().single.limit,
              SoundsRepository.newestListPageSize,
            );
            verifyIndexNotAsked();
          });

          test('lists the newest when the index fails', () async {
            when(
              () => funnelcake.listSounds(
                sort: any(named: 'sort'),
                authors: any(named: 'authors'),
                kind: any(named: 'kind'),
                limit: any(named: 'limit'),
                cursor: any(named: 'cursor'),
              ),
            ).thenThrow(
              const FunnelcakeApiException(
                message: 'Search index unavailable',
                statusCode: 503,
                url: 'https://api.example/api/v2/search/sounds',
              ),
            );

            final page = await lists.fetchNewestSounds(kind: SoundKind.music);

            expect(page.sounds.map((sound) => sound.id), [testEventId2]);
          });

          test(
            'lists the newest when the index does not answer in time',
            () async {
              when(
                () => funnelcake.listSounds(
                  sort: any(named: 'sort'),
                  authors: any(named: 'authors'),
                  kind: any(named: 'kind'),
                  limit: any(named: 'limit'),
                  cursor: any(named: 'cursor'),
                ),
              ).thenThrow(const FunnelcakeTimeoutException());

              final page = await lists.fetchNewestSounds();

              expect(page.sounds.map((sound) => sound.id), [
                testEventId1,
                testEventId2,
              ]);
            },
          );

          test('lists from a relay cursor on, ending when nothing older '
              'is left', () async {
            final page = await lists.fetchNewestSounds(cursor: 'relays:2000');

            expect(newestReads().single.until, 2000);
            expect(page.nextCursor, 'relays:1500');

            answerNewest([song]);
            final last = await lists.fetchNewestSounds(cursor: 'relays:1500');

            expect(last.nextCursor, isNull);
            verifyIndexNotAsked();
          });

          test('pages on past sounds it cannot use', () async {
            answerNewest([
              rain,
              createAudioEvent(
                id: testEventId2,
                pubkey: testPubkey2,
                title: 'No file',
                url: null,
                createdAt: 900,
              ),
            ]);
            when(() => funnelcake.isAvailable).thenReturn(false);

            final page = await lists.fetchNewestSounds();

            expect(page.sounds.map((sound) => sound.id), [testEventId1]);
            expect(page.nextCursor, 'relays:900');
          });

          test('lists nothing more when the relays return nothing', () async {
            answerNewest([]);
            when(() => funnelcake.isAvailable).thenReturn(false);

            final page = await lists.fetchNewestSounds();

            expect(page.sounds, isEmpty);
            expect(page.nextCursor, isNull);
          });
        });

        test('does not switch to the relays on a later page', () async {
          when(
            () => funnelcake.listSounds(
              sort: any(named: 'sort'),
              authors: any(named: 'authors'),
              kind: any(named: 'kind'),
              limit: any(named: 'limit'),
              cursor: any(named: 'cursor'),
            ),
          ).thenThrow(const FunnelcakeTimeoutException());

          await expectLater(
            lists.fetchNewestSounds(cursor: 'o:100'),
            throwsA(isA<FunnelcakeTimeoutException>()),
          );
          expect(newestReads, throwsA(isA<TestFailure>()));
        });

        test('throws for an index cursor without a Funnelcake client', () {
          final offline = SoundsRepository(nostrClient: mockNostrClient);
          addTearDown(offline.dispose);

          expect(
            () => offline.fetchNewestSounds(cursor: 'o:100'),
            throwsA(isA<FunnelcakeNotConfiguredException>()),
          );
        });
      });

      group('fetchPopularSounds', () {
        test('lists them by trend in the index order', () async {
          final page = await lists.fetchPopularSounds();

          expect(page.sounds.map((sound) => sound.id), [
            testEventId2,
            testEventId1,
          ]);
          expect(page.usageCounts, {testEventId2: 3, testEventId1: 7});
          expect(page.nextCursor, 'o:100');
          verify(
            () => funnelcake.listSounds(sort: SoundListSort.trending),
          ).called(1);
        });

        test('lists those of a kind from where the cursor points', () async {
          await lists.fetchPopularSounds(kind: SoundKind.music, cursor: 'o:50');

          verify(
            () => funnelcake.listSounds(
              sort: SoundListSort.trending,
              kind: SoundKind.music,
              cursor: 'o:50',
            ),
          ).called(1);
        });

        test("keeps a video's own sound", () async {
          answerIndex([indexed(testEventId1, usageCount: 1)]);
          answerIdLookup([
            createAudioEvent(
              id: testEventId1,
              pubkey: testPubkey1,
              title: 'Original sound',
            ),
          ]);

          final page = await lists.fetchPopularSounds();

          expect(page.sounds.map((sound) => sound.id), [testEventId1]);
        });

        test('lists nothing, without asking, while Funnelcake is not '
            'configured', () async {
          when(() => funnelcake.isAvailable).thenReturn(false);

          final page = await lists.fetchPopularSounds(kind: SoundKind.effect);

          expect(page.sounds, isEmpty);
          expect(page.nextCursor, isNull);
          verifyNoIdLookup();
        });
      });

      group('fetchFollowedSounds', () {
        test('asks the index about the most recently followed creators, '
            'passing over blocked ones, Divine and malformed keys', () async {
          await lists.fetchFollowedSounds(const [
            followedA,
            blockedAuthor,
            'not-a-key',
            divineAuthor,
            'AA00000000000000000000000000000000000000000000000000000000000002',
          ], kind: SoundKind.effect);

          verify(
            () => funnelcake.listSounds(
              authors: [followedB, followedA],
              kind: SoundKind.effect,
              limit: SoundsRepository.newestListPageSize,
            ),
          ).called(1);
        });

        test(
          'asks the index about at most as many creators as it takes',
          () async {
            final following = [
              for (
                var i = 0;
                i < FunnelcakeApiClient.maxSoundListAuthors + 5;
                i++
              )
                i.toRadixString(16).padLeft(64, '0'),
            ];

            await lists.fetchFollowedSounds(following);

            final authors =
                verify(
                      () => funnelcake.listSounds(
                        authors: captureAny(named: 'authors'),
                        limit: SoundsRepository.newestListPageSize,
                      ),
                    ).captured.single
                    as List<String>;
            expect(
              authors,
              hasLength(FunnelcakeApiClient.maxSoundListAuthors),
            );
            expect(authors.first, following.last);
          },
        );

        test('asks the relays about the same creators when the index '
            'cannot answer', () async {
          when(() => funnelcake.isAvailable).thenReturn(false);

          await lists.fetchFollowedSounds(const [followedA, blockedAuthor]);

          expect(newestReads().single.authors, [followedA]);
        });

        test('asks nothing when no followed creator is left', () async {
          final page = await lists.fetchFollowedSounds(const [
            blockedAuthor,
            divineAuthor,
          ]);

          expect(page.sounds, isEmpty);
          expect(page.nextCursor, isNull);
          verifyIndexNotAsked();
          expect(newestReads, throwsA(isA<TestFailure>()));
        });
      });
    });

    group('fetchSoundsByCreators', () {
      test('returns nothing without querying for no pubkeys', () async {
        final sounds = await repository.fetchSoundsByCreators(const ['']);

        expect(sounds, isEmpty);
        verifyNever(
          () => mockNostrClient.queryEventsDetailed(
            any(),
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        );
      });

      test('asks for the audio of every creator at once', () async {
        answerNewest([
          createAudioEvent(
            id: testEventId1,
            pubkey: testPubkey1,
            title: 'Followed sound',
          ),
        ]);

        final sounds = await repository.fetchSoundsByCreators(
          const [testPubkey1, testPubkey2, testPubkey1],
          limit: 30,
          until: 1500,
        );

        expect(sounds.single.id, testEventId1);
        final filter = newestReads().single;
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
        final beats = [
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
        ];
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => beats);
        answerNewest(beats);
        answerIdLookup([
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
        ]);
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
          () => funnelcake.listSounds(
            sort: any(named: 'sort'),
            authors: any(named: 'authors'),
            kind: any(named: 'kind'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => SoundSearchResponse(
            sounds: [
              for (final id in [testEventId1, testEventId2])
                SoundStats(
                  id: id,
                  pubkey: testPubkey1,
                  title: 'Sound',
                  createdAt: DateTime.utc(2026),
                  usageCount: 3,
                ),
            ],
          ),
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

      test('leaves them out of Funnelcake searches', () async {
        when(
          () => funnelcake.searchSounds(
            query: any(named: 'query'),
            kind: any(named: 'kind'),
            authors: any(named: 'authors'),
            limit: any(named: 'limit'),
            cursor: any(named: 'cursor'),
          ),
        ).thenAnswer(
          (_) async => SoundSearchResponse(
            sounds: [
              for (final id in [testEventId2, testEventId1])
                SoundStats(
                  id: id,
                  pubkey: testPubkey1,
                  title: 'Sound',
                  createdAt: DateTime.utc(2026),
                  usageCount: 3,
                ),
            ],
          ),
        );

        final results = await blocking.searchSounds('beat');

        expect(ids(results.sounds), [testEventId1]);
        expect(results.usageCounts.keys, [testEventId2, testEventId1]);
      });

      test('leaves them out of relay searches', () async {
        when(() => funnelcake.isAvailable).thenReturn(false);
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

        expect(ids((await blocking.searchSounds('beat')).sounds), [
          testEventId1,
        ]);
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

        answerNewest([event]);

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

        answerNewest([event]);

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
        ).thenAnswer(
          (_) async => const CountResult(isComplete: true, count: 5),
        );

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

        answerNewest([event]);

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

        answerNewest([event]);

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
        answerNewest([kept, deleted]);
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
        answerNewest([event1]);

        await repository.fetchTrendingSounds();
        expect(repository.cachedSoundCount, 1);
        expect(repository.getSoundFromCache(testEventId1), isNotNull);

        // Refresh returns event2 only
        answerNewest([event2]);

        await repository.refresh();

        expect(repository.cachedSoundCount, 1);
        expect(repository.getSoundFromCache(testEventId1), isNull);
        expect(repository.getSoundFromCache(testEventId2), isNotNull);
      });
    });

    group('dispose', () {
      test(
        'does not open a subscription after disposal during startup',
        () async {
          final read =
              Completer<({List<Event> events, bool timedOut, bool noRelays})>();
          when(
            () => mockNostrClient.queryEventsDetailed(
              any(that: isNewestRead),
              useCache: any(named: 'useCache'),
              timeout: any(named: 'timeout'),
              requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
            ),
          ).thenAnswer((_) => read.future);
          final initialized = repository.initialize();

          await repository.dispose();
          read.complete((events: <Event>[], timedOut: false, noRelays: false));
          await initialized;

          verifyNever(
            () => mockNostrClient.subscribe(
              any(),
              subscriptionId: any(named: 'subscriptionId'),
            ),
          );
        },
      );

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

      test('subscribes again after every relay refuses the audio feed', () {
        fakeAsync((async) {
          var subscribes = 0;
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
          ).thenAnswer((_) {
            if (++subscribes == 1) {
              return Stream<Event>.error(
                const RelaySubscriptionRefusedException(
                  'error: could not complete query',
                ),
              );
            }
            return streamController.stream;
          });

          unawaited(repository.initialize());
          async.flushMicrotasks();
          expect(subscribes, equals(1));

          async.elapse(const Duration(minutes: 10));

          expect(subscribes, greaterThan(1));
        });
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
          () => mockNostrClient.queryEventsDetailed(
            any(that: isNewestRead),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          ),
        ).thenThrow(Exception('Network error'));

        await repository.initialize();

        // Should not be marked as initialized on error
        expect(repository.isInitialized, isFalse);
      });

      test('fetchTrendingSounds rethrows on error', () async {
        when(
          () => mockNostrClient.queryEventsDetailed(
            any(that: isNewestRead),
            useCache: any(named: 'useCache'),
            timeout: any(named: 'timeout'),
            requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
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
