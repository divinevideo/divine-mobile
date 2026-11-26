// ABOUTME: Tests for CurationRepository.retryUnpublishedCurations()
// ABOUTME: and retry-related edge cases

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

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
    'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

Event _testEvent({
  int kind = 30005,
  List<List<String>> tags = const [],
  String content = '',
}) {
  return Event(_testPubkey, kind, tags, content);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_testEvent());
    registerFallbackValue(<String>[]);
  });

  group('CurationRepository Retry Logic', () {
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
        () => mockSigner.getPublicKey(),
      ).thenAnswer((_) async => _testPubkey);
      when(
        () => mockSigner.signEvent(any()),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return Event(
          event.pubkey,
          event.kind,
          event.tags,
          event.content,
        );
      });

      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay1.example.com']);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      when(
        () => mockVideoEventCache.discoveryVideos,
      ).thenReturn([]);
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

    group('retryUnpublishedCurations', () {
      test(
        'does nothing when no publish statuses exist',
        () async {
          await curationRepository.retryUnpublishedCurations();
          // No publishEvent calls should be made
          verifyNever(
            () => mockNostrService.publishEvent(any()),
          );
        },
      );

      test(
        'skips curations that are already published',
        () async {
          // Publish a curation successfully first
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _testEvent()));

          await curationRepository.publishCuration(
            id: 'published_one',
            title: 'Published',
            videoIds: [],
          );

          // Reset mock to track new calls
          reset(mockNostrService);
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => mockNostrService.connectedRelays,
          ).thenReturn(['wss://relay1.example.com']);

          await curationRepository.retryUnpublishedCurations();

          verifyNever(
            () => mockNostrService.publishEvent(any()),
          );
        },
      );

      test(
        'skips curations that have not passed the backoff '
        'period',
        () async {
          // Fail a publish to create a failed status
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          await curationRepository.publishCuration(
            id: 'failed_one',
            title: 'Failed',
            videoIds: [],
          );

          // Reset mock
          reset(mockNostrService);
          when(
            () => mockNostrService.subscribe(any()),
          ).thenAnswer((_) => const Stream.empty());
          when(
            () => mockNostrService.connectedRelays,
          ).thenReturn(['wss://relay1.example.com']);

          // Retry immediately - backoff not elapsed
          await curationRepository.retryUnpublishedCurations();

          verifyNever(
            () => mockNostrService.publishEvent(any()),
          );
        },
      );

      test(
        'records failed attempt after publish failure',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          await curationRepository.publishCuration(
            id: 'failed_once',
            title: 'Failed Once',
            videoIds: [],
          );

          final status = curationRepository.getCurationPublishStatus(
            'failed_once',
          );
          // Each publish resets then increments, so
          // failedAttempts is 1
          expect(status.failedAttempts, equals(1));
          expect(status.isPublished, isFalse);
          expect(status.shouldRetry, isTrue);
        },
      );
    });
  });
}
