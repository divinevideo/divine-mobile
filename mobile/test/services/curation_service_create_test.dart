// ABOUTME: Tests for CurationService.createCurationSet() method
// ABOUTME: Validates creation and publishing of NIP-51 video curation sets to Nostr

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';

import 'curation_service_create_test.mocks.dart';

@GenerateMocks([
  INostrService,
  VideoEventService,
  SocialService,
  NostrKeyManager,
  AuthService,
])
void main() {
  group('CurationService.createCurationSet()', () {
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockNostrKeyManager mockKeyManager;
    late MockAuthService mockAuthService;
    late CurationService curationService;
    late Keychain testKeychain;

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockKeyManager = MockNostrKeyManager();
      mockAuthService = MockAuthService();

      // Setup default mock behaviors
      when(mockVideoEventService.videoEvents).thenReturn([]);
      when(mockVideoEventService.discoveryVideos).thenReturn([]);
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
      when(mockNostrService.keyManager).thenReturn(mockKeyManager);

      // Create test keypair
      testKeychain = Keychain.generate();

      curationService = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );
    });

    test('successfully creates and publishes curation set', () async {
      // Setup: Mock successful broadcast
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 3,
          totalRelays: 3,
          results: {
            'wss://relay1.example.com': true,
            'wss://relay2.example.com': true,
            'wss://relay3.example.com': true,
          },
          errors: {},
        );
      });

      // Execute
      final result = await curationService.createCurationSet(
        id: 'test_list',
        title: 'Test Curation List',
        videoIds: ['video1', 'video2', 'video3'],
        description: 'A test curation set',
        imageUrl: 'https://example.com/image.jpg',
      );

      // Verify: Returns true on success
      expect(result, isTrue);

      // Verify: Broadcast was called
      verify(mockNostrService.broadcastEvent(any)).called(1);

      // Verify: Local state was updated
      final storedSet = curationService.getCurationSet('test_list');
      expect(storedSet, isNotNull);
      expect(storedSet!.id, 'test_list');
      expect(storedSet.title, 'Test Curation List');
      expect(storedSet.videoIds, ['video1', 'video2', 'video3']);
      expect(storedSet.description, 'A test curation set');
      expect(storedSet.imageUrl, 'https://example.com/image.jpg');
    });

    test('creates event with correct kind 30005', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );
      });

      await curationService.createCurationSet(
        id: 'test',
        title: 'Test',
        videoIds: ['video1'],
      );

      // Verify: Event has correct kind
      final capturedEvent =
          verify(mockNostrService.broadcastEvent(captureAny)).captured.single
              as Event;
      expect(capturedEvent.kind, 30005);
    });

    test('creates event with correct tags', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );
      });

      await curationService.createCurationSet(
        id: 'my_list',
        title: 'My List',
        videoIds: ['vid1', 'vid2'],
        description: 'Test description',
        imageUrl: 'https://example.com/img.jpg',
      );

      // Verify: Event has correct tags
      final capturedEvent =
          verify(mockNostrService.broadcastEvent(captureAny)).captured.single
              as Event;

      // Find specific tags
      final dTag = capturedEvent.tags.firstWhere((tag) => tag[0] == 'd');
      final titleTag = capturedEvent.tags.firstWhere(
        (tag) => tag[0] == 'title',
      );
      final descTag = capturedEvent.tags.firstWhere(
        (tag) => tag[0] == 'description',
      );
      final imageTag = capturedEvent.tags.firstWhere(
        (tag) => tag[0] == 'image',
      );

      expect(dTag[1], 'my_list');
      expect(titleTag[1], 'My List');
      expect(descTag[1], 'Test description');
      expect(imageTag[1], 'https://example.com/img.jpg');

      // Verify video references
      final aTags = capturedEvent.tags.where((tag) => tag[0] == 'a').toList();
      expect(aTags.length, 2);
    });

    test('returns false when broadcast fails', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 0,
          totalRelays: 3,
          results: {
            'wss://relay1.example.com': false,
            'wss://relay2.example.com': false,
            'wss://relay3.example.com': false,
          },
          errors: {
            'wss://relay1.example.com': 'Connection failed',
            'wss://relay2.example.com': 'Timeout',
            'wss://relay3.example.com': 'Rejected',
          },
        );
      });

      // Execute
      final result = await curationService.createCurationSet(
        id: 'test_list',
        title: 'Test List',
        videoIds: ['video1'],
      );

      // Verify: Returns false on failure
      expect(result, isFalse);
    });

    test('handles missing keypair gracefully', () async {
      // Setup: No keypair available
      when(mockKeyManager.keyPair).thenReturn(null);

      // Execute
      final result = await curationService.createCurationSet(
        id: 'test_list',
        title: 'Test List',
        videoIds: ['video1'],
      );

      // Verify: Returns false when no keys
      expect(result, isFalse);

      // Verify: Does not attempt to broadcast
      verifyNever(mockNostrService.broadcastEvent(any));
    });

    test('does not update local state when broadcast fails', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 0,
          totalRelays: 1,
          results: {'wss://relay1.example.com': false},
          errors: {'wss://relay1.example.com': 'Failed'},
        );
      });

      await curationService.createCurationSet(
        id: 'failed_list',
        title: 'Failed List',
        videoIds: ['video1'],
      );

      // Verify: Local state not updated on failure
      final storedSet = curationService.getCurationSet('failed_list');
      expect(storedSet, isNull);
    });

    test('uses curator pubkey from keyManager', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );
      });

      await curationService.createCurationSet(
        id: 'test',
        title: 'Test',
        videoIds: ['video1'],
      );

      // Verify: Event pubkey matches keypair
      final capturedEvent =
          verify(mockNostrService.broadcastEvent(captureAny)).captured.single
              as Event;
      expect(capturedEvent.pubkey, testKeychain.public);

      // Verify: Stored curation set has correct curator pubkey
      final storedSet = curationService.getCurationSet('test');
      expect(storedSet!.curatorPubkey, testKeychain.public);
    });

    test('handles partial broadcast success', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 3,
          results: {
            'wss://relay1.example.com': true,
            'wss://relay2.example.com': false,
            'wss://relay3.example.com': false,
          },
          errors: {
            'wss://relay2.example.com': 'Failed',
            'wss://relay3.example.com': 'Timeout',
          },
        );
      });

      // Execute
      final result = await curationService.createCurationSet(
        id: 'partial_list',
        title: 'Partial Success',
        videoIds: ['video1'],
      );

      // Verify: Returns true if at least one relay succeeded
      expect(result, isTrue);

      // Verify: Local state updated even with partial success
      final storedSet = curationService.getCurationSet('partial_list');
      expect(storedSet, isNotNull);
    });

    test('handles broadcast exception', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(
        mockNostrService.broadcastEvent(any),
      ).thenThrow(Exception('Network error'));

      // Execute - should not throw
      final result = await curationService.createCurationSet(
        id: 'error_list',
        title: 'Error Test',
        videoIds: ['video1'],
      );

      // Verify: Returns false on exception
      expect(result, isFalse);

      // Verify: Local state not updated
      final storedSet = curationService.getCurationSet('error_list');
      expect(storedSet, isNull);
    });

    test('creates curation set with empty video list', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );
      });

      // Execute: Create with no videos
      final result = await curationService.createCurationSet(
        id: 'empty_list',
        title: 'Empty List',
        videoIds: [],
      );

      // Verify: Succeeds even with empty video list
      expect(result, isTrue);

      final storedSet = curationService.getCurationSet('empty_list');
      expect(storedSet, isNotNull);
      expect(storedSet!.videoIds, isEmpty);
    });

    test('creates curation set with minimal parameters', () async {
      when(mockKeyManager.keyPair).thenReturn(testKeychain);
      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'wss://relay1.example.com': true},
          errors: {},
        );
      });

      // Execute: Create with only required params
      final result = await curationService.createCurationSet(
        id: 'minimal',
        title: 'Minimal',
        videoIds: ['video1'],
      );

      expect(result, isTrue);

      final storedSet = curationService.getCurationSet('minimal');
      expect(storedSet, isNotNull);
      expect(storedSet!.description, isNull);
      expect(storedSet.imageUrl, isNull);
    });
  });
}
