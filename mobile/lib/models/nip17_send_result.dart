// ABOUTME: Result model for NIP-17 encrypted message sending operations
// ABOUTME: Indicates success/failure with message event ID and recipient info

/// Result of NIP-17 encrypted message sending
class NIP17SendResult {
  const NIP17SendResult({
    required this.success,
    this.messageEventId,
    this.recipientPubkey,
    this.error,
    this.timestamp,
  });

  final bool success;
  final String? messageEventId; // Gift wrap event ID (kind 1059)
  final String? recipientPubkey;
  final String? error;
  final DateTime? timestamp;

  /// Create success result
  static NIP17SendResult createSuccess({
    required String messageEventId,
    required String recipientPubkey,
  }) => NIP17SendResult(
    success: true,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    timestamp: DateTime.now(),
  );

  /// Create failure result
  static NIP17SendResult failure(String error) =>
      NIP17SendResult(success: false, error: error);

  @override
  String toString() {
    if (success) {
      return 'NIP17SendResult(success: true, messageEventId: $messageEventId, recipient: $recipientPubkey)';
    } else {
      return 'NIP17SendResult(success: false, error: $error)';
    }
  }
}
