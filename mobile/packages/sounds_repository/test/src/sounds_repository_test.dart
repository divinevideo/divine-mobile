// ABOUTME: Unit tests for SoundsRepository
// ABOUTME: Tests fetching, caching, and querying Kind 1063 audio events

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

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
      String? title,
      double? duration,
    }) {
      final tags = <List<dynamic>>[];
      if (url != null) tags.add(['url', url]);
      if (title != null) tags.add(['title', title]);
      if (duration != null) tags.add(['duration', duration.toString()]);

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
