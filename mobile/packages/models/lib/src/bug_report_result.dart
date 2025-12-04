// ABOUTME: Result model for bug report submission operations
// ABOUTME: Indicates success/failure with report ID and optional error message

/// Result of bug report submission
class BugReportResult {
  const BugReportResult({
    required this.success,
    this.reportId,
    this.messageEventId,
    this.error,
    this.timestamp,
  });

  final bool success;
  final String? reportId;
  final String? messageEventId; // NIP-17 gift wrap event ID
  final String? error;
  final DateTime? timestamp;

  /// Create success result
  static BugReportResult createSuccess({
    required String reportId,
    required String messageEventId,
  }) => BugReportResult(
    success: true,
    reportId: reportId,
    messageEventId: messageEventId,
    timestamp: DateTime.now(),
  );

  /// Create failure result
  static BugReportResult failure(String error, {String? reportId}) =>
      BugReportResult(
        success: false,
        error: error,
        reportId: reportId,
        timestamp: DateTime.now(),
      );

  @override
  String toString() {
    if (success) {
      return 'BugReportResult(success: true, reportId: $reportId, messageEventId: $messageEventId)';
    } else {
      return 'BugReportResult(success: false, error: $error)';
    }
  }
}
