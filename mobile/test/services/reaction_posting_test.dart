import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';

@GenerateMocks([NostrClient, AuthService, SubscriptionManager])
import 'reaction_posting_test.mocks.dart';

void main() {
  group('Reaction Posting - Relay Closed Issue', () {
    late SocialService socialService;
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Set up default stubs for AuthService
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn('test_user_pubkey');

      // Set up default stubs for NostrService
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.fromIterable([]));

      socialService = SocialService(
        mockNostrService,
        mockAuthService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      socialService.dispose();
    });

    test(
      'should handle relay closed state error when posting reaction',
      () async {
        const testEventId = 'test_event_id_123';
        const testAuthorPubkey = 'test_author_pubkey_456';

        // Mock event creation success
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);
        final mockEvent = Event(publicKey, 7, [
          ['e', testEventId],
          ['p', testAuthorPubkey],
        ], '+');
        mockEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 7,
            content: '+',
            tags: [
              ['e', testEventId],
              ['p', testAuthorPubkey],
            ],
          ),
        ).thenAnswer((_) async => mockEvent);

        // Mock broadcast failure with "relay closed" error
        when(mockNostrService.broadcast(mockEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockEvent,
            successCount: 0,
            totalRelays: 1,
            results: const {'relay1': false},
            errors: const {
              'relay1': 'Bad state: Cannot add new events after calling close',
            },
          ),
        );

        // Test should throw exception with relay closed error
        await expectLater(
          () => socialService.toggleLike(testEventId, testAuthorPubkey),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Cannot add new events after calling close'),
            ),
          ),
        );
      },
    );

    test('should successfully post reaction when relay is open', () async {
      const testEventId = 'test_event_id_123';
      const testAuthorPubkey = 'test_author_pubkey_456';

      // Mock event creation success
      const privateKey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final publicKey = getPublicKey(privateKey);
      final mockEvent = Event(publicKey, 7, [
        ['e', testEventId],
        ['p', testAuthorPubkey],
      ], '+');
      mockEvent.sign(privateKey);

      when(
        mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        ),
      ).thenAnswer((_) async => mockEvent);

      // Mock successful broadcast
      when(mockNostrService.broadcast(mockEvent)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: mockEvent,
          successCount: 1,
          totalRelays: 1,
          results: const {'relay1': true},
          errors: const {},
        ),
      );

      // Test toggling like should succeed
      await socialService.toggleLike(testEventId, testAuthorPubkey);

      // Verify event creation was called
      verify(
        mockAuthService.createAndSignEvent(
          kind: 7,
          content: '+',
          tags: [
            ['e', testEventId],
            ['p', testAuthorPubkey],
          ],
        ),
      ).called(1);

      // Verify broadcast was called
      verify(mockNostrService.broadcast(mockEvent)).called(1);

      // Verify event is now liked locally
      expect(socialService.isLiked(testEventId), true);
    });
  });
}
