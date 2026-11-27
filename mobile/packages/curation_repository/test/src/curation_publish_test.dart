// ABOUTME: Tests for CurationRepository Nostr publishing functionality
// ABOUTME: (kind 30005). Verifies curation sets are correctly published
// ABOUTME: to Nostr relays with retry logic.

import 'dart:async';

import 'package:curation_repository/curation_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show CurationPublishResult;
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

/// Creates a test Event with a valid 64-char hex pubkey.
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
    registerFallbackValue(<List<String>>[]);
  });

  group('CurationRepository Publishing', () {
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

      // Mock NostrSigner
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

      // Mock NostrClient
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay1.example.com']);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => const Stream.empty());

      // Mock empty video events initially
      when(() => mockVideoEventCache.discoveryVideos).thenReturn([]);

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

    group('buildCurationEvent', () {
      test(
        'should create kind 30005 event with correct '
        'structure',
        () async {
          final event = await curationRepository.buildCurationEvent(
            id: 'test_curation_1',
            title: 'Test Curation',
            videoIds: ['video1', 'video2', 'video3'],
            description: 'A test curation set',
            imageUrl: 'https://example.com/image.jpg',
          );

          expect(event, isNotNull);
          expect(event!.kind, equals(30005));
        },
      );

      test(
        'should handle optional fields correctly',
        () async {
          final event = await curationRepository.buildCurationEvent(
            id: 'minimal_curation',
            title: 'Minimal Curation',
            videoIds: ['video1'],
          );

          expect(event, isNotNull);
          expect(event!.kind, equals(30005));
        },
      );

      test('should handle empty video list', () async {
        final event = await curationRepository.buildCurationEvent(
          id: 'empty_curation',
          title: 'Empty Curation',
          videoIds: [],
        );

        expect(event, isNotNull);
        expect(event!.kind, equals(30005));
        expect(
          event.tags.where((tag) => tag[0] == 'e'),
          isEmpty,
        );
      });
    });

    group('publishCuration', () {
      test(
        'should publish event to Nostr and return success',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer(
            (_) async => PublishSuccess(
              event: _testEvent(
                tags: [
                  ['d', 'test_id'],
                ],
                content: 'Test content',
              ),
            ),
          );

          final result = await curationRepository.publishCuration(
            id: 'test_curation',
            title: 'Test Curation',
            videoIds: ['video1', 'video2'],
            description: 'Test description',
          );

          expect(result.success, isTrue);
          expect(result.successCount, equals(1));
          expect(result.totalRelays, equals(1));
          expect(result.eventId, isNotNull);

          verify(
            () => mockNostrService.publishEvent(any()),
          ).called(1);
        },
      );

      test(
        'should handle complete failure gracefully',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final result = await curationRepository.publishCuration(
            id: 'test_curation',
            title: 'Test',
            videoIds: [],
          );

          expect(result.success, isFalse);
          expect(result.successCount, equals(0));
          expect(result.errors, isNotEmpty);
          expect(
            result.errors.containsKey('publish'),
            isTrue,
          );
        },
      );

      test('should timeout after 5 seconds', () {
        fakeAsync((async) {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async {
            await Future<void>.delayed(
              const Duration(seconds: 10),
            );
            return PublishSuccess(event: _testEvent());
          });

          CurationPublishResult? result;
          unawaited(
            curationRepository
                .publishCuration(
                  id: 'test_curation',
                  title: 'Test',
                  videoIds: [],
                )
                .then((r) => result = r),
          );

          // Advance past the 5-second timeout
          async
            ..elapse(const Duration(seconds: 6))
            ..flushMicrotasks();

          expect(result!.success, isFalse);
          expect(result!.errors['timeout'], isNotNull);
        });
      });

      test(
        'should prevent duplicate concurrent publishes',
        () {
          fakeAsync((async) {
            final completer = Completer<PublishResult>();
            when(
              () => mockNostrService.publishEvent(any()),
            ).thenAnswer((_) => completer.future);

            // Start first publish (will block on completer)
            CurationPublishResult? firstResult;
            unawaited(
              curationRepository
                  .publishCuration(
                    id: 'rapid_curation',
                    title: 'Test',
                    videoIds: [],
                  )
                  .then((r) => firstResult = r),
            );

            // Allow async code to start
            async.flushMicrotasks();

            // Second publish of same ID should be rejected
            CurationPublishResult? secondResult;
            unawaited(
              curationRepository
                  .publishCuration(
                    id: 'rapid_curation',
                    title: 'Test',
                    videoIds: [],
                  )
                  .then((r) => secondResult = r),
            );

            async.flushMicrotasks();

            expect(secondResult!.success, isFalse);
            expect(
              secondResult!.errors.containsKey('duplicate'),
              isTrue,
            );

            // Complete the first publish
            completer.complete(PublishSuccess(event: _testEvent()));
            async.flushMicrotasks();
            expect(firstResult!.success, isTrue);
          });
        },
      );
    });

    group('Local Persistence', () {
      test(
        'should mark curation as published locally after '
        'success',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _testEvent()));

          await curationRepository.publishCuration(
            id: 'test_curation',
            title: 'Test',
            videoIds: [],
          );

          final publishStatus = curationRepository.getCurationPublishStatus(
            'test_curation',
          );
          expect(publishStatus.isPublished, isTrue);
          expect(
            publishStatus.lastPublishedAt,
            isNotNull,
          );
          expect(publishStatus.isPublishing, isFalse);
        },
      );

      test(
        'should track failed publish attempts',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          await curationRepository.publishCuration(
            id: 'failed_curation',
            title: 'Test',
            videoIds: [],
          );

          final publishStatus = curationRepository.getCurationPublishStatus(
            'failed_curation',
          );
          expect(publishStatus.isPublished, isFalse);
          expect(
            publishStatus.failedAttempts,
            greaterThan(0),
          );
          expect(
            publishStatus.lastFailureReason,
            isNotNull,
          );
        },
      );

      test(
        'should return default status for unknown curation',
        () {
          final status = curationRepository.getCurationPublishStatus(
            'unknown_curation',
          );
          expect(status.isPublished, isFalse);
          expect(status.isPublishing, isFalse);
          expect(status.failedAttempts, equals(0));
        },
      );
    });

    group('Background Retry Worker', () {
      test(
        'should use exponential backoff timing',
        () async {
          final delay1 = curationRepository.getRetryDelay(1);
          final delay2 = curationRepository.getRetryDelay(2);
          final delay3 = curationRepository.getRetryDelay(3);

          expect(delay1.inSeconds, equals(2));
          expect(delay2.inSeconds, equals(4));
          expect(delay3.inSeconds, equals(8));

          expect(
            delay2.inSeconds,
            greaterThan(delay1.inSeconds),
          );
          expect(
            delay3.inSeconds,
            greaterThan(delay2.inSeconds),
          );
        },
      );

      test(
        'should cap retry delay at a reasonable maximum',
        () {
          final maxDelay = curationRepository.getRetryDelay(100);
          expect(maxDelay.inSeconds, equals(1024));
        },
      );

      test(
        'should coalesce rapid updates to same curation',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => PublishSuccess(event: _testEvent()));

          final futures = <Future<dynamic>>[];
          for (var i = 0; i < 5; i++) {
            futures.add(
              curationRepository.publishCuration(
                id: 'rapid_curation',
                title: 'Test $i',
                videoIds: [],
              ),
            );
          }
          await Future.wait(futures);

          verify(
            () => mockNostrService.publishEvent(any()),
          ).called(1);
        },
      );
    });

    group('Publishing Status UI', () {
      test(
        'should report "Publishing..." status during '
        'publish',
        () {
          fakeAsync((async) {
            final completer = Completer<PublishResult>();
            when(
              () => mockNostrService.publishEvent(any()),
            ).thenAnswer((_) => completer.future);

            unawaited(
              curationRepository.publishCuration(
                id: 'publishing_curation',
                title: 'Test',
                videoIds: [],
              ),
            );

            // Allow async code to start
            async.flushMicrotasks();

            final status = curationRepository.getCurationPublishStatus(
              'publishing_curation',
            );
            expect(status.isPublishing, isTrue);
            expect(
              status.statusText,
              equals('Publishing...'),
            );

            // Complete the publish
            completer.complete(PublishSuccess(event: _testEvent()));
            async.flushMicrotasks();

            final finalStatus = curationRepository.getCurationPublishStatus(
              'publishing_curation',
            );
            expect(finalStatus.isPublishing, isFalse);
            expect(finalStatus.isPublished, isTrue);
            expect(
              finalStatus.statusText,
              contains('Published'),
            );
          });
        },
      );

      test(
        'should show error status for failed publishes',
        () async {
          when(
            () => mockNostrService.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          await curationRepository.publishCuration(
            id: 'error_curation',
            title: 'Test',
            videoIds: [],
          );

          final status = curationRepository.getCurationPublishStatus(
            'error_curation',
          );
          expect(
            status.statusText,
            contains('Error'),
          );
          expect(status.isError, isTrue);
        },
      );
    });
  });
}
