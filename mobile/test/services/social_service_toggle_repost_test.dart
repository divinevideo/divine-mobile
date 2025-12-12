// ABOUTME: TDD tests for toggleRepost functionality
// ABOUTME: Verifies repost/unrepost toggle behavior with NIP-18 and NIP-09 events

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/subscription_manager.dart';

// Generate mocks
@GenerateMocks([NostrClient, AuthService, SubscriptionManager])
import 'social_service_toggle_repost_test.mocks.dart';

void main() {
  group('SocialService - toggleRepost()', () {
    late SocialService socialService;
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late MockSubscriptionManager mockSubscriptionManager;

    const testUserPubkey = 'test_user_pubkey_789';
    const testAuthorPubkey = 'test_author_pubkey_456';
    const testVideoId = 'test_video_id_123';
    const testDTag = 'test_d_tag';

    late VideoEvent testVideo;

    setUp(() {
      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Set up default stubs
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testUserPubkey);
      when(
        mockNostrService.subscribe(argThat(anything)),
      ).thenAnswer((_) => Stream.fromIterable([]));
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

      // Create test video with d tag in rawTags
      testVideo = VideoEvent(
        id: testVideoId,
        pubkey: testAuthorPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        rawTags: {'d': testDTag}, // d-tag required for addressable events
      );
    });

    tearDown(() {
      socialService.dispose();
      resetMockitoState();
      reset(mockNostrService);
      reset(mockAuthService);
      reset(mockSubscriptionManager);
    });

    test(
      'should create NIP-18 repost event (Kind 6) when toggling repost on',
      () async {
        // Mock event creation for repost
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);
        final mockRepostEvent = Event(
          publicKey,
          6, // Kind 6 = Repost
          [
            [
              'a',
              '32222:$testAuthorPubkey:$testDTag',
            ], // Addressable event reference
            ['p', testAuthorPubkey],
          ],
          '', // Repost content is empty
        );
        mockRepostEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 16,
            content: '',
            tags: [
              ['k', '34236'],
              ['a', '32222:$testAuthorPubkey:$testDTag'],
              ['p', testAuthorPubkey],
            ],
          ),
        ).thenAnswer((_) async => mockRepostEvent);

        // Mock successful broadcast
        when(mockNostrService.broadcast(mockRepostEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockRepostEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Initially not reposted
        expect(
          socialService.hasReposted(
            testVideoId,
            pubkey: testAuthorPubkey,
            dTag: testDTag,
          ),
          false,
        );

        // Test toggling repost ON
        await socialService.toggleRepost(testVideo);

        // Verify repost event was created
        verify(
          mockAuthService.createAndSignEvent(
            kind: 16,
            content: '',
            tags: [
              ['k', '34236'],
              ['a', '32222:$testAuthorPubkey:$testDTag'],
              ['p', testAuthorPubkey],
            ],
          ),
        ).called(1);

        // Verify broadcast was called
        verify(mockNostrService.broadcast(mockRepostEvent)).called(1);

        // Verify video is now reposted locally
        expect(
          socialService.hasReposted(
            testVideoId,
            pubkey: testAuthorPubkey,
            dTag: testDTag,
          ),
          true,
        );
      },
    );

    test(
      'should create NIP-09 deletion event (Kind 5) when toggling repost off',
      () async {
        // Setup: First repost the video
        const privateKey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final publicKey = getPublicKey(privateKey);

        final mockRepostEvent = Event(publicKey, 16, [
          ['k', '34236'],
          ['a', '32222:$testAuthorPubkey:$testDTag'],
          ['p', testAuthorPubkey],
        ], '');
        mockRepostEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 16,
            content: '',
            tags: [
              ['k', '34236'],
              ['a', '32222:$testAuthorPubkey:$testDTag'],
              ['p', testAuthorPubkey],
            ],
          ),
        ).thenAnswer((_) async => mockRepostEvent);

        when(mockNostrService.broadcast(mockRepostEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockRepostEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // First toggle: repost the video
        await socialService.toggleRepost(testVideo);
        expect(
          socialService.hasReposted(
            testVideoId,
            pubkey: testAuthorPubkey,
            dTag: testDTag,
          ),
          true,
        );

        // Mock deletion event creation
        final mockDeletionEvent = Event(
          publicKey,
          5, // Kind 5 = Deletion
          [
            ['e', mockRepostEvent.id], // Delete the repost event
          ],
          'Unreposted',
        );
        mockDeletionEvent.sign(privateKey);

        when(
          mockAuthService.createAndSignEvent(
            kind: 5,
            content: 'Unreposted',
            tags: [
              ['e', mockRepostEvent.id],
            ],
          ),
        ).thenAnswer((_) async => mockDeletionEvent);

        when(mockNostrService.broadcast(mockDeletionEvent)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: mockDeletionEvent,
            successCount: 1,
            totalRelays: 1,
            results: const {'relay1': true},
            errors: const {},
          ),
        );

        // Second toggle: unrepost the video
        await socialService.toggleRepost(testVideo);

        // Verify deletion event was created
        verify(
          mockAuthService.createAndSignEvent(
            kind: 5,
            content: 'Unreposted',
            tags: [
              ['e', mockRepostEvent.id],
            ],
          ),
        ).called(1);

        // Verify deletion broadcast
        verify(mockNostrService.broadcast(mockDeletionEvent)).called(1);

        // Verify video is no longer reposted locally
        expect(
          socialService.hasReposted(
            testVideoId,
            pubkey: testAuthorPubkey,
            dTag: testDTag,
          ),
          false,
        );
      },
    );

    test('should throw exception when user is not authenticated', () async {
      when(mockAuthService.isAuthenticated).thenReturn(false);

      expect(
        () => socialService.toggleRepost(testVideo),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw exception when video has no d tag', () async {
      final videoWithoutDTag = VideoEvent(
        id: testVideoId,
        pubkey: testAuthorPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        rawTags: {}, // No d-tag!
      );

      expect(
        () => socialService.toggleRepost(videoWithoutDTag),
        throwsA(isA<Exception>()),
      );
    });
  });
}
