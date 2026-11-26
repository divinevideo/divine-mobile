// ABOUTME: Tests for CurationRepository.subscribeToCurationSets()
// ABOUTME: error handling and edge cases

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

  group('subscribeToCurationSets error handling', () {
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

      when(
        () => mockVideoEventCache.discoveryVideos,
      ).thenReturn([]);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer(
        (_) => const Stream<Event>.empty(),
      );
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

    tearDown(() {
      curationRepository.dispose();
    });

    test(
      'handles subscribe throwing an exception',
      () async {
        when(
          () => mockNostrService.subscribe(any()),
        ).thenThrow(Exception('Connection refused'));

        // Should not throw
        await curationRepository.subscribeToCurationSets();

        expect(curationRepository.curationSets, isNotEmpty);
      },
    );

    test(
      'handles stream error in subscription',
      () async {
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await curationRepository.subscribeToCurationSets();

        // Emit an error on the stream
        controller.addError(Exception('Stream error'));

        // Allow processing
        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );

        // Should not crash
        expect(curationRepository.curationSets, isNotEmpty);

        await controller.close();
      },
    );

    test(
      'ignores non-30005 events in subscription',
      () async {
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await curationRepository.subscribeToCurationSets();

        // Emit a non-30005 event
        controller.add(
          Event.fromJson({
            'id': 'wrong_kind',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 1,
            'tags': <List<String>>[],
            'content': 'text note',
            'sig': 'sig',
          }),
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );

        // The wrong kind event should not be stored
        expect(
          curationRepository.getCurationSet('wrong_kind'),
          isNull,
        );

        await controller.close();
      },
    );

    test(
      'handles malformed event in subscription',
      () async {
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await curationRepository.subscribeToCurationSets();

        // Emit a kind 30005 event without a 'd' tag
        controller.add(
          Event.fromJson({
            'id': 'malformed',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': <List<String>>[],
            'content': '',
            'sig': 'sig',
          }),
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );

        // Should not crash - the malformed event is
        // handled by the catch block
        expect(curationRepository.curationSets, isNotEmpty);

        await controller.close();
      },
    );

    test(
      'updates video cache after receiving valid curation '
      'event',
      () async {
        final controller = StreamController<Event>();

        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        await curationRepository.subscribeToCurationSets();

        // Emit a valid curation event
        controller.add(
          Event.fromJson({
            'id': 'valid_event',
            'pubkey': 'curator',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 30005,
            'tags': [
              ['d', 'new_curation'],
              ['title', 'New Curation'],
              ['e', 'video_1'],
            ],
            'content': '',
            'sig': 'sig',
          }),
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 100),
        );

        final set = curationRepository.getCurationSet(
          'new_curation',
        );
        expect(set, isNotNull);
        expect(set!.title, equals('New Curation'));

        await controller.close();
      },
    );
  });
}
