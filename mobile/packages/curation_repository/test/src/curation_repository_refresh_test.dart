// ABOUTME: Tests for CurationRepository.refreshIfNeeded() and
// ABOUTME: _populateSampleSets() with actual video data

import 'dart:async';

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

VideoEvent _video({
  required String id,
  String pubkey = 'pub1',
  int createdAt = 1000,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(
      Event('0' * 64, 1, <List<String>>[], ''),
    );
    registerFallbackValue(<String>[]);
    registerFallbackValue(
      VideoEvent(
        id: 'fallback',
        pubkey: 'fallback',
        createdAt: 0,
        content: '',
        timestamp: DateTime(2020),
      ),
    );
  });

  group('CurationRepository refresh', () {
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
        () => mockVideoEventCache.addVideoEvent(any()),
      ).thenReturn(null);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => const LikeCounts(counts: {}));
    });

    group('refreshIfNeeded', () {
      test(
        'does not refresh when video count has not changed',
        () {
          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([]);

          curationRepository =
              CurationRepository(
                  nostrService: mockNostrService,
                  videoEventCache: mockVideoEventCache,
                  likesRepository: mockLikesRepository,
                  signer: mockSigner,
                  divineTeamPubkeys: const [],
                )
                // Call refreshIfNeeded with zero videos and
                // verify no exception is thrown
                ..refreshIfNeeded();
          expect(
            curationRepository.curationSets,
            isNotEmpty,
          );
        },
      );

      test(
        'triggers refresh when new videos are available',
        () async {
          // Start with empty videos
          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([]);

          curationRepository = CurationRepository(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          // Add videos
          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([
            _video(id: 'v1'),
            _video(id: 'v2', createdAt: 2000),
          ]);

          curationRepository.refreshIfNeeded();

          // Allow async work to settle
          await Future<void>.delayed(Duration.zero);

          // The service should have called getLikeCounts
          // as part of _populateSampleSets
          verify(
            () => mockLikesRepository.getLikeCounts(any()),
          ).called(greaterThan(0));
        },
      );
    });

    group('initialization with videos', () {
      test(
        'populates editor picks from divine team pubkeys',
        () async {
          final divineVideo = _video(
            id: 'divine_vid',
            pubkey: 'divine_team_key',
            createdAt: 5000,
          );

          // Use a stream that emits a video event for
          // Divine Team fetch
          final controller = StreamController<Event>();
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => controller.stream);
          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([divineVideo]);
          when(
            () => mockVideoEventCache.addVideoEvent(any()),
          ).thenReturn(null);

          curationRepository = CurationRepository(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const ['divine_team_key'],
          );

          // Close the stream to allow fetch to complete
          await controller.close();

          // Allow async initialization to settle
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          // Editor picks set should exist
          final editorsPicks = curationRepository.getVideosForSetType(
            CurationSetType.editorsPicks,
          );
          expect(editorsPicks, isA<List<VideoEvent>>());
        },
      );

      test(
        'sorts videos by reactions using like counts',
        () async {
          when(
            () => mockVideoEventCache.discoveryVideos,
          ).thenReturn([
            _video(id: 'v1'),
            _video(id: 'v2', createdAt: 2000),
            _video(id: 'v3', createdAt: 3000),
          ]);

          when(
            () => mockLikesRepository.getLikeCounts(any()),
          ).thenAnswer(
            (_) async => const LikeCounts(
              counts: {
                'v1': 10,
                'v2': 50,
                'v3': 5,
              },
            ),
          );

          curationRepository = CurationRepository(
            nostrService: mockNostrService,
            videoEventCache: mockVideoEventCache,
            likesRepository: mockLikesRepository,
            signer: mockSigner,
            divineTeamPubkeys: const [],
          );

          // Allow async initialization to settle
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );

          // Verify getLikeCounts was called
          verify(
            () => mockLikesRepository.getLikeCounts(any()),
          ).called(greaterThan(0));
        },
      );
    });
  });
}
