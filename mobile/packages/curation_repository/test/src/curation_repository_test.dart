// ABOUTME: Tests for CurationRepository analytics integration and
// ABOUTME: on-demand trending fetch

import 'package:curation_repository/curation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

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

      // Mock discoveryVideos to avoid MissingStubError
      // during CurationRepository initialization
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);
      // Mock subscribe to avoid MissingStubError when
      // fetching Editor's Picks list
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

    tearDown(() {
      curationRepository.dispose();
    });

    test('should get videos for different curation set types', () {
      final editorsPicks = curationRepository.getVideosForSetType(
        CurationSetType.editorsPicks,
      );
      final trending = curationRepository.getVideosForSetType(
        CurationSetType.trending,
      );
      expect(editorsPicks, isA<List<VideoEvent>>());
      expect(trending, isA<List<VideoEvent>>());
    });

    test('should handle empty video events gracefully', () {
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [],
      );

      final trending = service.getVideosForSetType(CurationSetType.trending);

      expect(trending, isEmpty);

      service.dispose();
    });
  });
}
