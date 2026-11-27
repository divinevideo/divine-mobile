// ABOUTME: Tests for CurationRepository kind 30005 Nostr queries
// ABOUTME: Verifies fetching and subscribing to NIP-51 video
// ABOUTME: curation sets

import 'dart:async';

import 'package:curation_repository/curation_repository.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(
      Event('0' * 64, 1, <List<String>>[], ''),
    );
    registerFallbackValue(<String>[]);
  });

  group('CurationRepository - Kind 30005 Nostr Queries', () {
    late _MockNostrClient mockNostrService;
    late _MockVideoEventCache mockVideoEventCache;
    late _MockLikesRepository mockLikesRepository;
    late _MockNostrSigner mockSigner;
    late CurationRepository curationRepository;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockVideoEventCache = _MockVideoEventCache();
      mockLikesRepository = _MockLikesRepository();
      mockSigner = _MockNostrSigner();

      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

      // Stub subscribe so constructor initialization doesn't throw
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Mock getLikeCounts to return empty counts
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => const LikeCounts(counts: {}));

      curationRepository = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );
    });

    group('refreshCurationSets()', () {
      test(
        'parses and stores received kind 30005 events',
        () async {
          final testEvent = Event.fromJson({
            'id': 'test_event_123',
            'pubkey': 'curator_pubkey_abc',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'test_list'],
              ['title', 'Test Curation List'],
              ['description', 'Test description'],
              [
                'e',
                'video_event_1',
                '',
                'wss://relay.example.com',
              ],
              [
                'e',
                'video_event_2',
                '',
                'wss://relay.example.com',
              ],
            ],
            'content': '',
            'sig': 'test_signature',
          });

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationRepository.refreshCurationSets();

          controller.add(testEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );
          unawaited(controller.close());

          await future;

          final set = curationRepository.getCurationSet('test_list');
          expect(set, isNotNull);
          expect(set!.title, 'Test Curation List');
          expect(set.videoIds.length, 2);
          expect(
            set.videoIds,
            contains('video_event_1'),
          );
          expect(
            set.videoIds,
            contains('video_event_2'),
          );
        },
      );

      test(
        'handles multiple curation sets from different '
        'curators',
        () async {
          final event1 = Event.fromJson({
            'id': 'event1',
            'pubkey': 'curator1',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'list1'],
              ['title', 'Curator 1 List'],
              ['e', 'video1'],
            ],
            'content': '',
            'sig': 'sig1',
          });

          final event2 = Event.fromJson({
            'id': 'event2',
            'pubkey': 'curator2',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'list2'],
              ['title', 'Curator 2 List'],
              ['e', 'video2'],
            ],
            'content': '',
            'sig': 'sig2',
          });

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationRepository.refreshCurationSets();

          controller
            ..add(event1)
            ..add(event2);
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );
          unawaited(controller.close());

          await future;

          final set1 = curationRepository.getCurationSet('list1');
          final set2 = curationRepository.getCurationSet('list2');

          expect(set1, isNotNull);
          expect(set2, isNotNull);
          expect(set1!.title, 'Curator 1 List');
          expect(set2!.title, 'Curator 2 List');
        },
      );

      test(
        'falls back to sample data when no sets found',
        () async {
          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationRepository.refreshCurationSets();

          unawaited(controller.close());
          await future;

          expect(
            curationRepository.curationSets.isNotEmpty,
            isTrue,
          );
        },
      );

      test(
        'handles errors gracefully and falls back to '
        'sample data',
        () async {
          when(
            () => mockNostrService.subscribe(any()),
          ).thenThrow(Exception('Connection error'));

          await curationRepository.refreshCurationSets();

          expect(
            curationRepository.curationSets.isNotEmpty,
            isTrue,
          );
        },
      );

      test('times out after 10 seconds', () async {
        final controller = StreamController<Event>();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        final stopwatch = Stopwatch()..start();
        await curationRepository.refreshCurationSets();
        stopwatch.stop();

        expect(
          stopwatch.elapsed.inSeconds,
          lessThanOrEqualTo(12),
        );

        await controller.close();
      });

      test(
        'ignores non-30005 events in stream',
        () async {
          final wrongKindEvent = Event.fromJson({
            'id': 'wrong_kind',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 1,
            'tags': <List<String>>[],
            'content': 'Hello world',
            'sig': 'sig',
          });

          final correctEvent = Event.fromJson({
            'id': 'correct',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'list'],
              ['title', 'Valid List'],
              ['e', 'video1'],
            ],
            'content': '',
            'sig': 'sig',
          });

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationRepository.refreshCurationSets();

          controller
            ..add(wrongKindEvent)
            ..add(correctEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );
          unawaited(controller.close());

          await future;

          final validSet = curationRepository.getCurationSet('list');
          expect(validSet, isNotNull);
        },
      );

      test(
        'handles malformed events without crashing',
        () async {
          final malformedEvent = Event.fromJson({
            'id': 'malformed',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': <List<String>>[],
            'content': '',
            'sig': 'sig',
          });

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          final future = curationRepository.refreshCurationSets();

          controller.add(malformedEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );
          unawaited(controller.close());

          await expectLater(future, completes);
        },
      );
    });

    group('subscribeToCurationSets()', () {
      test(
        'subscribes to kind 30005 events',
        () async {
          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          await curationRepository.subscribeToCurationSets();

          verify(
            () => mockNostrService.subscribe(
              any(
                that: predicate<List<Filter>>((filters) {
                  if (filters.isEmpty) return false;
                  final kinds = filters[0].kinds;
                  return kinds != null && kinds.contains(30005);
                }),
              ),
            ),
          ).called(1);

          await controller.close();
        },
      );

      test(
        'processes incoming curation set events',
        () async {
          final testEvent = Event.fromJson({
            'id': 'streaming_event',
            'pubkey': 'streaming_curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'streaming_list'],
              ['title', 'Streaming List'],
              ['e', 'video_a'],
              ['e', 'video_b'],
            ],
            'content': '',
            'sig': 'sig',
          });

          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          await curationRepository.subscribeToCurationSets();

          controller.add(testEvent);
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          final set = curationRepository.getCurationSet('streaming_list');
          expect(set, isNotNull);
          expect(set!.title, 'Streaming List');
          expect(
            set.videoIds,
            ['video_a', 'video_b'],
          );

          await controller.close();
        },
      );
    });
  });
}
