// ABOUTME: Tests for CurationRepository.buildCurationEvent() edge cases
// ABOUTME: Covers null pubkey and signing exception paths

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

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
    'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(
      Event(_testPubkey, 30005, <List<String>>[], ''),
    );
    registerFallbackValue(<String>[]);
  });

  group('CurationRepository.buildCurationEvent()', () {
    late CurationRepository curationRepository;
    late _MockNostrClient mockNostrService;
    late _MockVideoEventCache mockVideoEventCache;
    late _MockLikesRepository mockLikesRepository;
    late _MockNostrSigner mockSigner;

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
      ).thenAnswer((_) => const Stream<Event>.empty());
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

    test(
      'returns null when signer returns null public key',
      () async {
        when(
          () => mockSigner.getPublicKey(),
        ).thenAnswer((_) async => null);

        final event = await curationRepository.buildCurationEvent(
          id: 'test_id',
          title: 'Test',
          videoIds: ['video1'],
        );

        expect(event, isNull);
      },
    );

    test(
      'returns null when signer throws an exception',
      () async {
        when(
          () => mockSigner.getPublicKey(),
        ).thenThrow(Exception('Signer unavailable'));

        final event = await curationRepository.buildCurationEvent(
          id: 'test_id',
          title: 'Test',
          videoIds: ['video1'],
        );

        expect(event, isNull);
      },
    );

    test(
      'returns null when signEvent throws an exception',
      () async {
        when(
          () => mockSigner.getPublicKey(),
        ).thenAnswer((_) async => _testPubkey);
        when(
          () => mockSigner.signEvent(any()),
        ).thenThrow(Exception('Signing failed'));

        final event = await curationRepository.buildCurationEvent(
          id: 'test_id',
          title: 'Test',
          videoIds: ['video1'],
        );

        expect(event, isNull);
      },
    );
  });
}
