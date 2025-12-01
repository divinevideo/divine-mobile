// ABOUTME: Tests for CurationService Nostr publishing functionality (kind 30005)
// ABOUTME: Verifies curation sets are correctly published to Nostr relays with retry logic

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'curation_publish_test.mocks.dart';

@GenerateMocks([INostrService, VideoEventService, SocialService, AuthService])
void main() {
  group('CurationService Publishing', () {
    late CurationService curationService;
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();

      // Mock authenticated user with a valid 64-char hex pubkey
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2');

      // Mock empty video events initially
      when(mockVideoEventService.discoveryVideos).thenReturn([]);

      // Mock createAndSignEvent to return a properly signed event with captured tags
      when(mockAuthService.createAndSignEvent(
        kind: anyNamed('kind'),
        content: anyNamed('content'),
        tags: anyNamed('tags'),
      )).thenAnswer((invocation) async {
        final kind = invocation.namedArguments[#kind] as int;
        final content = invocation.namedArguments[#content] as String;
        final tags = invocation.namedArguments[#tags] as List<List<String>>;

        return Event(
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
          kind,
          tags,
          content,
        );
      });

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );
    });

    group('buildCurationEvent', () {
      test('should create kind 30005 event with correct structure', () async {
        // When: Building a curation event
        final event = await curationService.buildCurationEvent(
          id: 'test_curation_1',
          title: 'Test Curation',
          videoIds: ['video1', 'video2', 'video3'],
          description: 'A test curation set',
          imageUrl: 'https://example.com/image.jpg',
        );

        // Then: Event should be created and signed
        expect(event, isNotNull);

        // Event should have correct kind and tags
        expect(event!.kind, equals(30005));
        expect(event.tags, contains(['d', 'test_curation_1']));
        expect(event.tags, contains(['title', 'Test Curation']));
        expect(
            event.tags, contains(['description', 'A test curation set']));
        expect(event.tags,
            contains(['image', 'https://example.com/image.jpg']));

        // Verify video references as 'e' tags
        expect(event.tags, contains(['e', 'video1']));
        expect(event.tags, contains(['e', 'video2']));
        expect(event.tags, contains(['e', 'video3']));

        // Verify content contains description
        expect(event.content, equals('A test curation set'));
      });

      test('should handle optional fields correctly', () async {
        // When: Building event without optional fields
        final event = await curationService.buildCurationEvent(
          id: 'minimal_curation',
          title: 'Minimal Curation',
          videoIds: ['video1'],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should only have required tags
        expect(event!.kind, equals(30005));
        expect(event.tags, contains(['d', 'minimal_curation']));
        expect(event.tags, contains(['title', 'Minimal Curation']));
        expect(event.tags, contains(['e', 'video1']));

        // Optional tags should not be present
        expect(
            event.tags.where((tag) => tag[0] == 'description'), isEmpty);
        expect(event.tags.where((tag) => tag[0] == 'image'), isEmpty);
      });

      test('should handle empty video list', () async {
        // When: Building event with no videos
        final event = await curationService.buildCurationEvent(
          id: 'empty_curation',
          title: 'Empty Curation',
          videoIds: [],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should create event without video tags
        expect(event!.kind, equals(30005));
        expect(event.tags.where((tag) => tag[0] == 'e'), isEmpty);
      });

      test('should add client tag for attribution', () async {
        // When: Building any curation event
        final event = await curationService.buildCurationEvent(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be created
        expect(event, isNotNull);

        // Should include client tag
        expect(event!.tags, contains(['client', 'diVine']));
      });
    });

    group('publishCuration', () {
      test('should publish event to Nostr and return success', () async {
        // Given: Mock successful broadcast
        final mockEvent = Event(
          'test_pubkey',
          30005,
          [
            ['d', 'test_id']
          ],
          'Test content',
        );
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 2,
            totalRelays: 3,
            results: {'relay1': true, 'relay2': true, 'relay3': false},
            errors: {'relay3': 'Connection timeout'},
          ),
        );

        // When: Publishing a curation
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test Curation',
          videoIds: ['video1', 'video2'],
          description: 'Test description',
        );

        // Then: Should return success
        expect(result.success, isTrue);
        expect(result.successCount, equals(2));
        expect(result.totalRelays, equals(3));
        expect(result.eventId, isNotNull);

        // Verify broadcastEvent was called
        verify(mockNostrService.broadcastEvent(any)).called(1);
      });

      test('should handle complete failure gracefully', () async {
        // Given: Mock failed broadcast
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 0,
            totalRelays: 3,
            results: {
              'relay1': false,
              'relay2': false,
              'relay3': false
            },
            errors: {
              'relay1': 'Connection refused',
              'relay2': 'Timeout',
              'relay3': 'Rejected'
            },
          ),
        );

        // When: Publishing a curation
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should return failure
        expect(result.success, isFalse);
        expect(result.successCount, equals(0));
        expect(result.errors.length, equals(3));
      });

      test('should timeout after 5 seconds', () async {
        // Given: Mock slow broadcast
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async {
            await Future.delayed(const Duration(seconds: 10));
            return NostrBroadcastResult(
              event: Event('test', 30005, [], ''),
              successCount: 1,
              totalRelays: 1,
              results: {'relay1': true},
              errors: {},
            );
          },
        );

        // When: Publishing with timeout
        final stopwatch = Stopwatch()..start();
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );
        stopwatch.stop();

        // Then: Should timeout and fail
        expect(stopwatch.elapsed.inSeconds, lessThan(7)); // Allow some margin
        expect(result.success, isFalse);
        expect(result.errors['timeout'], isNotNull);
      });

      test('should handle partial relay success', () async {
        // Given: Mock partial success
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 1,
            totalRelays: 3,
            results: {'relay1': true, 'relay2': false, 'relay3': false},
            errors: {
              'relay2': 'Connection timeout',
              'relay3': 'Relay offline'
            },
          ),
        );

        // When: Publishing
        final result = await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be marked as success if at least one relay succeeded
        expect(result.success, isTrue);
        expect(result.successCount, equals(1));
        expect(result.failedRelays, contains('relay2'));
        expect(result.failedRelays, contains('relay3'));
      });
    });

    group('Local Persistence', () {
      test('should mark curation as published locally after success',
          () async {
        // Given: Mock successful publish
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 2,
            totalRelays: 2,
            results: {'relay1': true, 'relay2': true},
            errors: {},
          ),
        );

        // When: Publishing curation
        await curationService.publishCuration(
          id: 'test_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should be marked as published
        final publishStatus =
            curationService.getCurationPublishStatus('test_curation');
        expect(publishStatus.isPublished, isTrue);
        expect(publishStatus.lastPublishedAt, isNotNull);
        expect(publishStatus.publishedEventId, isNotNull);
      });

      test('should track failed publish attempts', () async {
        // Given: Mock failed publish
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 0,
            totalRelays: 2,
            results: {'relay1': false, 'relay2': false},
            errors: {'relay1': 'Error', 'relay2': 'Error'},
          ),
        );

        // When: Publishing fails
        await curationService.publishCuration(
          id: 'failed_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should track failed attempt
        final publishStatus =
            curationService.getCurationPublishStatus('failed_curation');
        expect(publishStatus.isPublished, isFalse);
        expect(publishStatus.failedAttempts, greaterThan(0));
        expect(publishStatus.lastFailureReason, isNotNull);
      });

      test('should persist publish status across service restarts',
          () async {
        // Given: Published curation
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        await curationService.publishCuration(
          id: 'persistent_curation',
          title: 'Test',
          videoIds: [],
        );

        // When: Creating new service instance
        final newService = CurationService(
          nostrService: mockNostrService,
          videoEventService: mockVideoEventService,
          socialService: mockSocialService,
          authService: mockAuthService,
        );

        // Then: Should retain publish status
        final publishStatus =
            newService.getCurationPublishStatus('persistent_curation');
        expect(publishStatus.isPublished, isTrue);
      });
    });

    group('Background Retry Worker', () {
      test('should retry unpublished curations with exponential backoff',
          () async {
        // Given: Failed initial publish
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 0,
            totalRelays: 1,
            results: {'relay1': false},
            errors: {'relay1': 'Temporary error'},
          ),
        );

        await curationService.publishCuration(
          id: 'retry_curation',
          title: 'Test',
          videoIds: [],
        );

        // Mock successful retry
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        // When: Background worker runs
        await curationService.retryUnpublishedCurations();

        // Then: Should successfully publish on retry
        final publishStatus =
            curationService.getCurationPublishStatus('retry_curation');
        expect(publishStatus.isPublished, isTrue);
      });

      test('should stop retrying after max attempts', () async {
        // Given: Persistent failures
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 0,
            totalRelays: 1,
            results: {'relay1': false},
            errors: {'relay1': 'Permanent error'},
          ),
        );

        // When: Retrying multiple times
        for (var i = 0; i < 10; i++) {
          await curationService.retryUnpublishedCurations();
        }

        // Then: Should stop retrying after max attempts
        final publishStatus = curationService
            .getCurationPublishStatus('max_retry_curation');
        expect(publishStatus.failedAttempts, lessThanOrEqualTo(5));
        expect(publishStatus.shouldRetry, isFalse);
      });

      test('should use exponential backoff timing', () async {
        // When: Getting retry delay for different attempt counts
        final delay1 = curationService.getRetryDelay(1);
        final delay2 = curationService.getRetryDelay(2);
        final delay3 = curationService.getRetryDelay(3);

        // Then: Delays should increase exponentially
        expect(delay2.inSeconds, greaterThan(delay1.inSeconds));
        expect(delay3.inSeconds, greaterThan(delay2.inSeconds));

        // Verify exponential growth (approx 2^n seconds)
        expect(delay1.inSeconds, closeTo(2, 1)); // ~2s
        expect(delay2.inSeconds, closeTo(4, 2)); // ~4s
        expect(delay3.inSeconds, closeTo(8, 3)); // ~8s
      });

      test('should coalesce rapid updates to same curation', () async {
        // Given: Mock successful broadcast
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 1,
            totalRelays: 1,
            results: {'relay1': true},
            errors: {},
          ),
        );

        // When: Publishing same curation multiple times rapidly
        final futures = <Future>[];
        for (var i = 0; i < 5; i++) {
          futures.add(curationService.publishCuration(
            id: 'rapid_curation',
            title: 'Test $i',
            videoIds: [],
          ));
        }
        await Future.wait(futures);

        // Then: Should coalesce into single publish (or very few)
        verify(mockNostrService.broadcastEvent(any))
            .called(lessThanOrEqualTo(2));
      });
    });

    group('Publishing Status UI', () {
      test('should report "Publishing..." status during publish', () async {
        // Given: Slow broadcast simulation
        final completer = Completer<NostrBroadcastResult>();
        when(mockNostrService.broadcastEvent(any))
            .thenAnswer((_) => completer.future);

        // When: Starting publish
        final publishFuture = curationService.publishCuration(
          id: 'publishing_curation',
          title: 'Test',
          videoIds: [],
        );

        // Wait a moment for async code to start
        await Future.delayed(const Duration(milliseconds: 10));

        // Then: Should show publishing status
        final status =
            curationService.getCurationPublishStatus('publishing_curation');
        expect(status.isPublishing, isTrue);
        expect(status.statusText, equals('Publishing...'));

        // Complete the publish
        completer.complete(NostrBroadcastResult(
          event: Event('test', 30005, [], ''),
          successCount: 1,
          totalRelays: 1,
          results: {'relay1': true},
          errors: {},
        ));
        await publishFuture;

        // Should now show published
        final finalStatus =
            curationService.getCurationPublishStatus('publishing_curation');
        expect(finalStatus.isPublishing, isFalse);
        expect(finalStatus.statusText, equals('Published'));
      });

      test('should show relay success count in status', () async {
        // Given: Partial success
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 2,
            totalRelays: 5,
            results: {
              'relay1': true,
              'relay2': true,
              'relay3': false,
              'relay4': false,
              'relay5': false,
            },
            errors: {
              'relay3': 'Error',
              'relay4': 'Error',
              'relay5': 'Error'
            },
          ),
        );

        // When: Publishing
        await curationService.publishCuration(
          id: 'partial_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Status should show relay count
        final status =
            curationService.getCurationPublishStatus('partial_curation');
        expect(status.statusText, contains('2/5'));
      });

      test('should show error status for failed publishes', () async {
        // Given: Failed publish
        when(mockNostrService.broadcastEvent(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: Event('test', 30005, [], ''),
            successCount: 0,
            totalRelays: 1,
            results: {'relay1': false},
            errors: {'relay1': 'Network error'},
          ),
        );

        // When: Publishing fails
        await curationService.publishCuration(
          id: 'error_curation',
          title: 'Test',
          videoIds: [],
        );

        // Then: Should show error status
        final status =
            curationService.getCurationPublishStatus('error_curation');
        expect(status.statusText, contains('Error'));
        expect(status.isError, isTrue);
      });
    });
  });
}
