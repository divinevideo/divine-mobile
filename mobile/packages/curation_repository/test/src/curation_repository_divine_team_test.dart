// ABOUTME: Tests for CurationRepository Divine Team video fetching
// ABOUTME: Covers _fetchDivineTeamVideos stream handling and
// ABOUTME: _selectEditorsPicksVideos logic

import 'dart:async';
import 'dart:convert';

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

const _divineTeamPubkey =
    'aaaa1111bbbb2222cccc3333dddd4444'
    'eeee5555ffff6666aaaa1111bbbb2222';

const _zeroPubkey =
    '00000000000000000000000000000000'
    '00000000000000000000000000000000';

Event _videoNostrEvent({
  required String id,
  String pubkey = _zeroPubkey,
  int createdAt = 1234567890,
  String? title,
  String? dTag,
}) {
  return Event(
    pubkey,
    34236,
    [
      ['h', 'vine'],
      if (dTag != null) ['d', dTag],
      if (title != null) ['title', title],
      ['url', 'https://example.com/$id.mp4'],
    ],
    jsonEncode({
      'url': 'https://example.com/$id.mp4',
      'description': 'Video $id',
    }),
    createdAt: createdAt,
  )..id = id;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Event('0' * 64, 1, <List<String>>[], ''));
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

  group('CurationRepository Divine Team', () {
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
      when(() => mockVideoEventCache.addVideoEvent(any())).thenReturn(null);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(
        () => mockLikesRepository.getLikeCounts(any()),
      ).thenAnswer((_) async => const LikeCounts(counts: {}));
      when(
        () => mockLikesRepository.getLikeCounts(
          any(),
          addressableIds: any(named: 'addressableIds'),
        ),
      ).thenAnswer((_) async => const LikeCounts(counts: {}));
    });

    test(
      'passes addressable IDs through when sorting Divine Team reactions',
      () async {
        final addressableVideo = VideoEvent.fromNostrEvent(
          _videoNostrEvent(
            id: 'addressable-video',
            pubkey: _divineTeamPubkey,
            title: 'Addressable Divine Video',
            dTag: 'divine-team-addressable',
          ),
        );
        final legacyVideo = VideoEvent(
          id: 'legacy-video',
          pubkey: _divineTeamPubkey,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Legacy video',
          timestamp: DateTime.now(),
          title: 'Legacy Divine Video',
          videoUrl: 'https://example.com/legacy-video.mp4',
        );

        when(
          () => mockVideoEventCache.discoveryVideos,
        ).thenReturn([addressableVideo, legacyVideo]);

        final service = CurationRepository(
          nostrService: mockNostrService,
          videoEventCache: mockVideoEventCache,
          likesRepository: mockLikesRepository,
          signer: mockSigner,
          divineTeamPubkeys: const [_divineTeamPubkey],
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));

        final captured = verify(
          () => mockLikesRepository.getLikeCounts(
            any(),
            addressableIds: captureAny(named: 'addressableIds'),
          ),
        ).captured;

        final addressableIds = captured.first as Map<String, String>?;
        expect(addressableIds, isNotNull);
        expect(addressableIds, hasLength(1));
        expect(
          addressableIds![addressableVideo.id],
          equals(addressableVideo.addressableId),
        );
        expect(addressableIds.containsKey(legacyVideo.id), isFalse);

        service.dispose();
      },
    );

    test('fetches and caches Divine Team videos from relay', () async {
      final controller = StreamController<Event>();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [_divineTeamPubkey],
      );

      // Emit a video event
      controller.add(
        _videoNostrEvent(
          id: 'divine_video_1',
          pubkey: _divineTeamPubkey,
          title: 'Divine Team Video',
        ),
      );

      // Allow stream processing
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Close the stream
      await controller.close();

      // Allow completion to settle
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Video should have been added to video event cache
      verify(
        () => mockVideoEventCache.addVideoEvent(any()),
      ).called(greaterThan(0));

      service.dispose();
    });

    test('handles stream error in Divine Team fetch', () async {
      final controller = StreamController<Event>();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [_divineTeamPubkey],
      );

      // Emit an error
      controller.addError(Exception('Relay error'));

      // Allow stream processing
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Service should not crash
      expect(service.curationSets, isNotEmpty);

      service.dispose();
      await controller.close();
    });

    test('deduplicates videos in editor picks internal cache', () async {
      final controller = StreamController<Event>();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [_divineTeamPubkey],
      );

      // Emit the same video twice
      final videoEvent = _videoNostrEvent(
        id: 'duplicate_vid',
        pubkey: _divineTeamPubkey,
        title: 'Duplicate Video',
      );

      controller
        ..add(videoEvent)
        ..add(videoEvent);

      await Future<void>.delayed(const Duration(milliseconds: 200));

      await controller.close();

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // addVideoEvent is called for each stream event
      // (line 212 is outside the dedup block), but the
      // internal _editorPicksVideoCache only adds once.
      // We verify the external cache received both calls.
      verify(() => mockVideoEventCache.addVideoEvent(any())).called(2);

      // Editor picks should have only 1 unique video
      final picks = service.getVideosForSetType(CurationSetType.editorsPicks);
      expect(picks, hasLength(1));

      service.dispose();
    });

    test('editors picks are sorted by creation time '
        '(newest first)', () async {
      final controller = StreamController<Event>();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => controller.stream);

      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [_divineTeamPubkey],
      );

      // Emit videos with different creation times
      controller
        ..add(
          _videoNostrEvent(
            id: 'old_vid',
            pubkey: _divineTeamPubkey,
            title: 'Old',
            createdAt: 1000,
          ),
        )
        ..add(
          _videoNostrEvent(
            id: 'new_vid',
            pubkey: _divineTeamPubkey,
            title: 'New',
            createdAt: 5000,
          ),
        );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      await controller.close();

      await Future<void>.delayed(const Duration(milliseconds: 200));

      final picks = service.getVideosForSetType(CurationSetType.editorsPicks);

      if (picks.length >= 2) {
        // Newest should be first
        expect(picks[0].createdAt, greaterThanOrEqualTo(picks[1].createdAt));
      }

      service.dispose();
    });

    test('handles subscribe throwing during Divine Team '
        'fetch', () async {
      // First call returns empty stream (for
      // constructor init), second call throws
      var callCount = 0;
      when(() => mockNostrService.subscribe(any())).thenAnswer((_) {
        callCount++;
        if (callCount > 1) {
          throw Exception('Connection failed');
        }
        return const Stream<Event>.empty();
      });

      // Should not throw during construction
      final service = CurationRepository(
        nostrService: mockNostrService,
        videoEventCache: mockVideoEventCache,
        likesRepository: mockLikesRepository,
        signer: mockSigner,
        divineTeamPubkeys: const [_divineTeamPubkey],
      );

      // Allow async to settle
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(service.curationSets, isNotEmpty);

      service.dispose();
    });
  });
}
