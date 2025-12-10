// ABOUTME: Service for sending encrypted NIP-17 (gift-wrapped) private messages
// ABOUTME: Handles three-layer encryption (kind 14 rumor → kind 13 seal → kind 1059 gift wrap)

import 'package:models/models.dart' show NIP17SendResult;
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for sending encrypted private messages using NIP-17 gift wrapping
class NIP17MessageService {
  NIP17MessageService({
    required NostrKeyManager keyManager,
    required INostrService nostrService,
  }) : _keyManager = keyManager,
       _nostrService = nostrService;

  final NostrKeyManager _keyManager;
  final INostrService _nostrService;

  /// Access to the underlying NostrService for relay management
  INostrService get nostrService => _nostrService;

  /// Send a private encrypted message to a recipient
  ///
  /// Uses NIP-17 three-layer encryption:
  /// 1. Kind 14 (unsigned rumor) - the actual message content
  /// 2. Kind 13 (seal) - signed and encrypted by sender
  /// 3. Kind 1059 (gift wrap) - wrapped with random ephemeral key for anonymity
  ///
  /// Parameters:
  /// - [recipientPubkey]: Recipient's public key (hex format)
  /// - [content]: Message content (will be encrypted)
  /// - [additionalTags]: Optional tags to include in the rumor event
  Future<NIP17SendResult> sendPrivateMessage({
    required String recipientPubkey,
    required String content,
    List<List<String>> additionalTags = const [],
  }) async {
    try {
      Log.info(
        'Sending NIP-17 encrypted message to recipient',
        category: LogCategory.system,
      );

      // Validate we have keys
      if (!_keyManager.hasKeys || _keyManager.privateKey == null) {
        return NIP17SendResult.failure('No private key available');
      }

      final senderPrivateKey = _keyManager.privateKey!;
      final senderPublicKey = _keyManager.publicKey!;

      // Create LocalNostrSigner for encryption and signing
      final signer = LocalNostrSigner(senderPrivateKey);

      // Create a minimal Nostr instance for GiftWrapUtil
      // We only need it for signing/encryption, not for relay communication
      final nostr = Nostr(
        signer,
        senderPublicKey,
        [], // Empty filters - not using for subscriptions
        _dummyRelayGenerator, // Dummy relay generator - not using relays
      );

      // Create kind 14 rumor event (unsigned, will be encrypted)
      final rumorTags = <List<String>>[
        ['p', recipientPubkey],
        ...additionalTags,
      ];

      final rumorEvent = Event(
        senderPublicKey,
        EventKind.privateDirectMessage, // Kind 14
        rumorTags,
        content,
      );

      Log.debug('Created kind 14 rumor event', category: LogCategory.system);

      // Use GiftWrapUtil to create the three-layer encrypted gift wrap
      final giftWrapEvent = await GiftWrapUtil.getGiftWrapEvent(
        nostr,
        rumorEvent,
        recipientPubkey,
      );

      if (giftWrapEvent == null) {
        return NIP17SendResult.failure('Failed to create gift wrap event');
      }

      Log.debug(
        'Created kind 1059 gift wrap event with ephemeral key: ${giftWrapEvent.pubkey}',
        category: LogCategory.system,
      );

      // Broadcast the gift wrap event
      final broadcastResult = await _nostrService.broadcastEvent(giftWrapEvent);

      if (broadcastResult.successCount > 0) {
        Log.info(
          'Successfully broadcast NIP-17 message',
          category: LogCategory.system,
        );
        return NIP17SendResult.success(
          messageEventId: giftWrapEvent.id,
          recipientPubkey: recipientPubkey,
        );
      } else {
        final errorMsg =
            'Message broadcast failed: ${broadcastResult.errors.values.join(", ")}';
        Log.error(errorMsg, category: LogCategory.system);
        return NIP17SendResult.failure(errorMsg);
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to send NIP-17 message: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return NIP17SendResult.failure('Failed to send message: $e');
    }
  }

  /// Dummy relay generator - we don't use relays in this Nostr instance
  /// Only needed for Nostr constructor, but not actually called
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for signing-only Nostr instance',
    );
  }
}
