// ABOUTME: Tests for CurationRepository getter methods and simple
// ABOUTME: accessors (isLoading, error, curation set lookups)

import 'package:curation_repository/curation_repository.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
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
    registerFallbackValue(Event('0' * 64, 1, <List<String>>[], ''));
    registerFallbackValue(<String>[]);
  });

  group(CurationRepository, () {
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

      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);
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

    tearDown(() {
      curationRepository.dispose();
    });

    group('isLoading', () {
      test('returns false after initialization completes', () {
        expect(curationRepository.isLoading, isFalse);
      });
    });

    group('error', () {
      test('returns null when no error has occurred', () {
        expect(curationRepository.error, isNull);
      });
    });

    group('getVideosForSet', () {
      test('returns empty list for unknown set ID', () {
        expect(curationRepository.getVideosForSet('nonexistent'), isEmpty);
      });
    });

    group('getCurationSet', () {
      test('returns null for unknown set ID', () {
        expect(curationRepository.getCurationSet('nonexistent'), isNull);
      });

      test('returns sample curation set for editors picks', () {
        final set = curationRepository.getCurationSet(
          CurationSetType.editorsPicks.id,
        );
        expect(set, isNotNull);
        expect(set!.title, CurationSetType.editorsPicks.displayName);
      });
    });

    group('getCurationSetByType', () {
      test('returns curation set for known type', () {
        final set = curationRepository.getCurationSetByType(
          CurationSetType.trending,
        );
        expect(set, isNotNull);
        expect(set!.title, CurationSetType.trending.displayName);
      });
    });

    group('curationSets', () {
      test('returns sample curation sets after initialization', () {
        final sets = curationRepository.curationSets;
        expect(sets, isNotEmpty);
        expect(
          sets.any((s) => s.id == CurationSetType.editorsPicks.id),
          isTrue,
        );
        expect(sets.any((s) => s.id == CurationSetType.trending.id), isTrue);
      });
    });
  });
}
