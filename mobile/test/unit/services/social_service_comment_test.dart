// ABOUTME: Unit tests for SocialService comment functionality
// ABOUTME: Tests comment posting, event creation, and error handling in isolation

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';

// Generate mocks
@GenerateMocks([NostrClient, AuthService, SubscriptionManager])
import 'social_service_comment_test.mocks.dart';

void main() {
  group('SocialService Comment Unit Tests', () {
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;
    late SocialService socialService;

    // Valid 64-character hex pubkeys for testing
    const testVideoEventId =
        'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
    const testVideoAuthorPubkey =
        'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';
    const testCurrentUserPubkey =
        'c3d4e5f6789012345678901234567890abcdef123456789012345678901234ab';
    const testCommentContent = 'This is a test comment';

    setUp(() {
      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Mock isAuthenticated to return false by default (tests override as needed)
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Mock subscribeToEvents to prevent initialization calls
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => const Stream<Event>.empty());

      // Mock createSubscription for fetchCommentsForEvent
      when(
        mockSubscriptionManager.createSubscription(
          name: anyNamed('name'),
          filters: anyNamed('filters'),
          onEvent: anyNamed('onEvent'),
          onError: anyNamed('onError'),
          onComplete: anyNamed('onComplete'),
          timeout: anyNamed('timeout'),
          priority: anyNamed('priority'),
        ),
      ).thenAnswer((_) async => 'test_subscription_id');

      socialService = SocialService(
        mockNostrService,
        mockAuthService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      socialService.dispose();
      resetMockitoState(); // Clear any pending verification state
      reset(mockNostrService);
      reset(mockAuthService);
      reset(mockSubscriptionManager);
    });

    group('postComment method', () {
      test('should throw exception when user not authenticated', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(false);

        // Act & Assert
        expect(
          () => socialService.postComment(
            content: testCommentContent,
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('User not authenticated'),
            ),
          ),
        );
      });

      test('should throw exception when comment content is empty', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(true);

        // Act & Assert
        expect(
          () => socialService.postComment(
            content: '',
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Comment content cannot be empty'),
            ),
          ),
        );
      });

      test(
        'should create event with correct tags for top-level comment',
        () async {
          // Arrange
          when(mockAuthService.isAuthenticated).thenReturn(true);

          final testEvent = Event(
            testCurrentUserPubkey,
            1,
            [
              ['e', testVideoEventId, '', 'root'],
              ['p', testVideoAuthorPubkey],
              [
                'expiration',
                '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
              ],
            ],
            testCommentContent,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );

          when(
            mockAuthService.createAndSignEvent(
              kind: 1,
              tags: [
                ['e', testVideoEventId, '', 'root'],
                ['p', testVideoAuthorPubkey],
              ],
              content: testCommentContent,
            ),
          ).thenAnswer((_) async => testEvent);

          when(mockNostrService.broadcast(testEvent)).thenAnswer(
            (_) async => NostrBroadcastResult(
              event: testEvent,
              successCount: 1,
              totalRelays: 1,
              results: const {'relay1': true},
              errors: const {},
            ),
          );

          // Act
          await socialService.postComment(
            content: testCommentContent,
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
          );

          // Assert
          verify(
            mockAuthService.createAndSignEvent(
              kind: 1,
              tags: [
                ['e', testVideoEventId, '', 'root'],
                ['p', testVideoAuthorPubkey],
              ],
              content: testCommentContent,
            ),
          ).called(1);
        },
      );

      test('should create event with correct tags for reply comment', () async {
        // Arrange
        const replyToEventId =
            'd4e5f6789012345678901234567890abcdef123456789012345678901234abc';
        const replyToAuthorPubkey =
            'e5f6789012345678901234567890abcdef123456789012345678901234abcd';

        when(mockAuthService.isAuthenticated).thenReturn(true);

        final testEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            ['e', replyToEventId, '', 'reply'],
            ['p', replyToAuthorPubkey],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: 1,
            tags: [
              ['e', testVideoEventId, '', 'root'],
              ['p', testVideoAuthorPubkey],
              ['e', replyToEventId, '', 'reply'],
              ['p', replyToAuthorPubkey],
            ],
            content: testCommentContent,
          ),
        ).thenAnswer((_) async => testEvent);

        when(mockNostrService.broadcast(testEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Act
        await socialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
          replyToEventId: replyToEventId,
          replyToAuthorPubkey: replyToAuthorPubkey,
        );

        // Assert
        verify(
          mockAuthService.createAndSignEvent(
            kind: 1,
            tags: [
              ['e', testVideoEventId, '', 'root'],
              ['p', testVideoAuthorPubkey],
              ['e', replyToEventId, '', 'reply'],
              ['p', replyToAuthorPubkey],
            ],
            content: testCommentContent,
          ),
        ).called(1);
      });

      test('should broadcast event to relays', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(true);

        final testEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            tags: anyNamed('tags'),
            content: anyNamed('content'),
          ),
        ).thenAnswer((_) async => testEvent);

        when(mockNostrService.broadcast(testEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Act
        await socialService.postComment(
          content: testCommentContent,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        );

        // Assert
        verify(mockNostrService.broadcast(testEvent)).called(1);
      });

      test('should throw exception when event creation fails', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(true);
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            tags: anyNamed('tags'),
            content: anyNamed('content'),
          ),
        ).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => socialService.postComment(
            content: testCommentContent,
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to create comment event'),
            ),
          ),
        );
      });

      test('should throw exception when broadcast fails', () async {
        // Arrange
        when(mockAuthService.isAuthenticated).thenReturn(true);

        final testEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            tags: anyNamed('tags'),
            content: anyNamed('content'),
          ),
        ).thenAnswer((_) async => testEvent);

        when(mockNostrService.broadcast(testEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 0,
            totalRelays: 1,
            results: const {'relay1': false},
            errors: const {'relay1': 'Connection failed'},
          ),
        );

        // Act & Assert
        expect(
          () => socialService.postComment(
            content: testCommentContent,
            rootEventId: testVideoEventId,
            rootEventAuthorPubkey: testVideoAuthorPubkey,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to broadcast comment'),
            ),
          ),
        );
      });

      test('should trim whitespace from comment content', () async {
        // Arrange
        const contentWithWhitespace = '  This is a test comment  \n\t';
        const trimmedContent = 'This is a test comment';

        when(mockAuthService.isAuthenticated).thenReturn(true);

        final testEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          trimmedContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: 1,
            tags: anyNamed('tags'),
            content: trimmedContent,
          ),
        ).thenAnswer((_) async => testEvent);

        when(mockNostrService.broadcast(testEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: testEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Act
        await socialService.postComment(
          content: contentWithWhitespace,
          rootEventId: testVideoEventId,
          rootEventAuthorPubkey: testVideoAuthorPubkey,
        );

        // Assert
        verify(
          mockAuthService.createAndSignEvent(
            kind: 1,
            tags: anyNamed('tags'),
            content: trimmedContent,
          ),
        ).called(1);
      });
    });

    group('fetchCommentsForEvent method', () {
      test('should return stream of comment events', () async {
        // Arrange
        final testCommentEvent = Event(
          testCurrentUserPubkey,
          1,
          [
            ['e', testVideoEventId, '', 'root'],
            ['p', testVideoAuthorPubkey],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          testCommentContent,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        // Mock createSubscription to call onEvent callback with test event
        when(
          mockSubscriptionManager.createSubscription(
            name: anyNamed('name'),
            filters: anyNamed('filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            timeout: anyNamed('timeout'),
            priority: anyNamed('priority'),
          ),
        ).thenAnswer((invocation) async {
          // Get the onEvent callback and call it with our test event
          final onEvent =
              invocation.namedArguments[Symbol('onEvent')] as Function(Event);
          onEvent(testCommentEvent);
          return 'test_subscription_id';
        });

        // Act
        final stream = socialService.fetchCommentsForEvent(testVideoEventId);

        // Assert
        await expectLater(stream, emits(testCommentEvent));

        // Verify subscription was created
        verify(
          mockSubscriptionManager.createSubscription(
            name: anyNamed('name'),
            filters: anyNamed('filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            timeout: anyNamed('timeout'),
            priority: anyNamed('priority'),
          ),
        ).called(1);
      });

      test('should subscribe with correct filter for comments', () {
        // Act
        socialService.fetchCommentsForEvent(testVideoEventId);

        // Assert - Verify createSubscription was called with correct filters
        final captured = verify(
          mockSubscriptionManager.createSubscription(
            name: anyNamed('name'),
            filters: captureAnyNamed('filters'),
            onEvent: anyNamed('onEvent'),
            onError: anyNamed('onError'),
            onComplete: anyNamed('onComplete'),
            timeout: anyNamed('timeout'),
            priority: anyNamed('priority'),
          ),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.length, equals(1));

        final filter = filters.first;
        expect(filter.kinds, contains(1)); // Kind 1 for text notes
        expect(filter.e, contains(testVideoEventId)); // Filter by root event
      });
    });
  });
}
