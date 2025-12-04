// ABOUTME: Models for curation publishing status and results
// ABOUTME: Tracks publish state, retry logic, and relay success/failure for NIP-51 curations

/// Status of a curation publish attempt
class CurationPublishStatus {
  const CurationPublishStatus({
    required this.curationId,
    required this.isPublishing,
    required this.isPublished,
    this.lastPublishedAt,
    this.publishedEventId,
    this.failedAttempts = 0,
    this.lastAttemptAt,
    this.lastFailureReason,
    this.successfulRelays = const [],
  });

  final String curationId;
  final bool isPublishing;
  final bool isPublished;
  final DateTime? lastPublishedAt;
  final String? publishedEventId;
  final int failedAttempts;
  final DateTime? lastAttemptAt;
  final String? lastFailureReason;
  final List<String> successfulRelays;

  /// Maximum number of retry attempts
  static const int maxRetries = 5;

  /// Whether this curation should be retried
  bool get shouldRetry => failedAttempts < maxRetries && !isPublished;

  /// UI-friendly status text
  String get statusText {
    if (isPublishing) return 'Publishing...';
    if (isPublished) {
      if (successfulRelays.isNotEmpty) {
        return 'Published (${successfulRelays.length} relays)';
      }
      return 'Published';
    }
    if (failedAttempts > 0) {
      return 'Error publishing';
    }
    return 'Not published';
  }

  /// Whether this status represents an error state
  bool get isError => !isPublished && !isPublishing && failedAttempts > 0;
}

/// Result of a curation publish operation
class CurationPublishResult {
  const CurationPublishResult({
    required this.success,
    required this.successCount,
    required this.totalRelays,
    this.eventId,
    this.errors = const {},
    this.failedRelays = const [],
  });

  final bool success;
  final int successCount;
  final int totalRelays;
  final String? eventId;
  final Map<String, String> errors;
  final List<String> failedRelays;

  @override
  String toString() =>
      'CurationPublishResult(success: $success, $successCount/$totalRelays relays)';
}
