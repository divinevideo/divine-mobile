// ABOUTME: Account deletion service implementing NIP-62 Request to Vanish
// ABOUTME: Handles network-wide account deletion by publishing kind 62 events to all relays

import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result of account deletion operation
class DeleteAccountResult {
  const DeleteAccountResult({
    required this.success,
    this.error,
    this.deleteEventId,
  });

  final bool success;
  final String? error;
  final String? deleteEventId;

  static DeleteAccountResult createSuccess(String deleteEventId) =>
      DeleteAccountResult(success: true, deleteEventId: deleteEventId);

  static DeleteAccountResult failure(String error) =>
      DeleteAccountResult(success: false, error: error);
}

/// Service for deleting user's entire Nostr account via NIP-62
class AccountDeletionService {
  AccountDeletionService({
    required NostrClient nostrService,
    required NostrKeyManager keyManager,
    required AuthService authService,
  }) : _nostrService = nostrService,
       _keyManager = keyManager,
       _authService = authService;

  final NostrClient _nostrService;
  final NostrKeyManager _keyManager;
  final AuthService _authService;

  /// Delete user's account using NIP-62 Request to Vanish
  Future<DeleteAccountResult> deleteAccount({String? customReason}) async {
    try {
      if (!_nostrService.hasKeys) {
        return DeleteAccountResult.failure('No keys available for signing');
      }

      // Create NIP-62 event
      final event = await createNip62Event(
        reason:
            customReason ?? 'User requested account deletion via diVine app',
      );

      if (event == null) {
        return DeleteAccountResult.failure('Failed to create deletion event');
      }

      // Broadcast to all configured relays
      final broadcastResult = await _nostrService.broadcast(event);

      if (broadcastResult.successCount == 0) {
        Log.error(
          'Failed to broadcast NIP-62 deletion request to any relay',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return DeleteAccountResult.failure(
          'Failed to broadcast deletion request to relays',
        );
      }

      Log.info(
        'NIP-62 deletion request broadcast to ${broadcastResult.successCount} relay(s)',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return DeleteAccountResult.createSuccess(event.id);
    } catch (e) {
      Log.error(
        'Account deletion failed: $e',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return DeleteAccountResult.failure('Account deletion failed: $e');
    }
  }

  /// Create NIP-62 kind 62 event with ALL_RELAYS tag
  Future<Event?> createNip62Event({required String reason}) async {
    try {
      if (!_nostrService.hasKeys) {
        Log.error(
          'Cannot create NIP-62 event: no keys available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // Get keyManager
      final keyManager = _keyManager;

      // Check keyPair exists
      final keyPair = keyManager.keyPair;
      if (keyPair == null) {
        Log.error(
          'Cannot create NIP-62 event: keyPair is null',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      final pubkey = _authService.currentPublicKeyHex;
      if (pubkey == null) {
        Log.error(
          'Cannot create NIP-62 event: no pubkey available',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // Verify pubkey matches keyPair (sanity check)
      if (pubkey != keyPair.public) {
        Log.error(
          'Cannot create NIP-62 event: pubkey mismatch (authService: $pubkey, keyPair: ${keyPair.public})',
          name: 'AccountDeletionService',
          category: LogCategory.system,
        );
        return null;
      }

      // NIP-62 requires relay tag with ALL_RELAYS for network-wide deletion
      final tags = <List<String>>[
        ['relay', 'ALL_RELAYS'],
      ];

      Log.info(
        'Creating NIP-62 event with pubkey: $pubkey, kind: 62, reason: $reason',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Create kind 62 event using nostr_sdk (same pattern as other events)
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        keyPair.public,
        62, // NIP-62 account deletion kind
        tags,
        reason,
        createdAt: createdAt,
      );

      Log.info(
        'Event created, now signing with private key',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      // Sign the event
      event.sign(keyPair.private);

      Log.info(
        'Created NIP-62 deletion event (kind 62): ${event.id}',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );

      return event;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to create NIP-62 event: $e\nStack trace: $stackTrace',
        name: 'AccountDeletionService',
        category: LogCategory.system,
      );
      return null;
    }
  }
}
