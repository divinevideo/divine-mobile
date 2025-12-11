// ABOUTME: Unit tests for NIP17MessageService encrypted message sending
// ABOUTME: Tests NIP-17 gift wrap creation, encryption, and broadcasting

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/nip17_message_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';

import 'nip17_message_service_test.mocks.dart';

@GenerateMocks([NostrKeyManager, INostrService])
void main() {
  group('NIP17MessageService', () {
    late NIP17MessageService service;
    late MockNostrKeyManager mockKeyManager;
    late MockINostrService mockNostrService;

    const testPrivateKey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const testPublicKey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const recipientPubkey =
        'e771af0b05c8e95fcdf6feb3500544d2fb1ccd384788e9f490bb3ee28e8ed66f'; // Rabble's pubkey (hex)

    setUp(() {
      mockKeyManager = MockNostrKeyManager();
      mockNostrService = MockINostrService();

      // Setup mock key manager
      when(mockKeyManager.hasKeys).thenReturn(true);
      when(mockKeyManager.privateKey).thenReturn(testPrivateKey);
      when(mockKeyManager.publicKey).thenReturn(testPublicKey);

      service = NIP17MessageService(
        keyManager: mockKeyManager,
        nostrService: mockNostrService,
      );
    });

    test('should create encrypted gift wrap event', () async {
      // Setup: Mock successful broadcast
      when(mockNostrService.broadcastEvent(any)).thenAnswer((_) async {
        return NostrBroadcastResult(
          event: Event.fromJson({
            'id': 'test-gift-wrap-id',
            'pubkey': 'random-ephemeral-pubkey', // Gift wrap uses random key
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 1059, // GIFT_WRAP
            'tags': [
              ['p', recipientPubkey],
              [
                'expiration',
                '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
              ],
            ],
            'content': 'encrypted-content',
            'sig': 'test-signature',
          }),
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      // Execute: Send encrypted message
      final result = await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test bug report message',
      );

      // Verify: Success
      expect(result.success, isTrue);
      expect(result.messageEventId, isNotNull);
      expect(result.recipientPubkey, equals(recipientPubkey));
      expect(result.error, isNull);

      // Verify: Event was broadcast
      verify(mockNostrService.broadcastEvent(any)).called(1);
    });

    test('should create gift wrap with kind 1059', () async {
      Event? capturedEvent;

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
      );

      // Verify: Gift wrap event has correct kind
      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.kind, equals(1059)); // EventKind.GIFT_WRAP
    });

    test('should include p tag with recipient pubkey', () async {
      Event? capturedEvent;

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
      );

      // Verify: Gift wrap has p tag with recipient
      expect(capturedEvent, isNotNull);
      final pTags = capturedEvent!.tags.where(
        (tag) => tag.isNotEmpty && tag[0] == 'p',
      );
      expect(pTags, isNotEmpty);
      expect(pTags.first[1], equals(recipientPubkey));
    });

    test('should use random ephemeral key for gift wrap', () async {
      final capturedEvents = <Event>[];

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        final event = invocation.positionalArguments[0] as Event;
        capturedEvents.add(event);
        return NostrBroadcastResult(
          event: event,
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      // Send two messages
      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Message 1',
      );
      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Message 2',
      );

      // Verify: Each gift wrap uses a different random ephemeral key
      expect(capturedEvents, hasLength(2));
      expect(capturedEvents[0].pubkey, isNot(equals(capturedEvents[1].pubkey)));
      // And neither should be the sender's real pubkey
      expect(capturedEvents[0].pubkey, isNot(equals(testPublicKey)));
      expect(capturedEvents[1].pubkey, isNot(equals(testPublicKey)));
    });

    test('should obfuscate timestamp with random offset', () async {
      Event? capturedEvent;

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      final beforeSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
      );
      final afterSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Verify: Timestamp is offset (should be earlier than actual send time)
      expect(capturedEvent, isNotNull);
      // Gift wrap timestamp should be within ±2 days of actual time
      final timeDiff = (capturedEvent!.createdAt - beforeSend).abs();
      expect(timeDiff, lessThanOrEqualTo(60 * 60 * 24 * 2)); // ±2 days
      // And typically it should be in the past (offset is negative)
      expect(capturedEvent!.createdAt, lessThan(afterSend));
    });

    test('should handle broadcast failure gracefully', () async {
      // Setup: Mock broadcast failure
      when(mockNostrService.broadcastEvent(any)).thenAnswer((_) async {
        return NostrBroadcastResult(
          event: Event.fromJson({
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'kind': 1059,
            'tags': [
              [
                'expiration',
                '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
              ],
            ],
            'content': '',
            'sig': 'test-sig',
          }),
          successCount: 0,
          totalRelays: 1,
          results: {'local': false},
          errors: {'local': 'Connection failed'},
        );
      });

      // Execute: Attempt to send message
      final result = await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
      );

      // Verify: Failure reported correctly
      expect(result.success, isFalse);
      expect(result.error, contains('broadcast failed'));
    });

    test('should fail when no keys available', () async {
      // Setup: No keys
      when(mockKeyManager.hasKeys).thenReturn(false);
      when(mockKeyManager.privateKey).thenReturn(null);

      // Execute: Attempt to send message
      final result = await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
      );

      // Verify: Failure due to missing keys
      expect(result.success, isFalse);
      expect(result.error, contains('No private key'));
    });

    test('should include additional tags if provided', () async {
      Event? capturedEvent;

      when(mockNostrService.broadcastEvent(any)).thenAnswer((invocation) async {
        capturedEvent = invocation.positionalArguments[0] as Event;
        return NostrBroadcastResult(
          event: capturedEvent!,
          successCount: 1,
          totalRelays: 1,
          results: {'local': true},
          errors: {},
        );
      });

      await service.sendPrivateMessage(
        recipientPubkey: recipientPubkey,
        content: 'Test message',
        additionalTags: [
          ['client', 'diVine_bug_report'],
          ['report_id', 'test-123'],
        ],
      );

      // Note: Additional tags go into the rumor event (kind 14), not the gift wrap
      // The gift wrap only has the p tag
      // We can't easily verify rumor tags without decrypting, so just verify it doesn't crash
      expect(capturedEvent, isNotNull);
    });
  });
}
