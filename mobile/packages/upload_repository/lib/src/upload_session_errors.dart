// ABOUTME: Shared upload failure types and the expired-resumable-session
// ABOUTME: predicate, used by UploadRetryPolicy, UploadProgressReporter and
// ABOUTME: UploadRepository.

import 'package:blossom_upload_service/blossom_upload_service.dart';

/// Returns true if [error] represents an expired resumable-upload session — the
/// server returned 401/403/404/410, or the message says the session is gone.
///
/// This predicate decides both whether the error is retriable *and* whether the
/// resumable session is nulled on failure, so the two used to drift between
/// independent copies in [UploadRetryPolicy] and [UploadProgressReporter]. It
/// lives here as a single source of truth to keep those callers in lockstep.
bool isExpiredResumableSessionError(dynamic error) {
  if (error is BlossomResumableUploadException) {
    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.statusCode == 404 ||
        error.statusCode == 410;
  }

  final errorMessage = error.toString().toLowerCase();
  return errorMessage.contains('session expired') ||
      errorMessage.contains('session is no longer available');
}

/// Exception thrown when a [BlossomUploadResult] indicates failure.
///
/// Carries the HTTP [statusCode] and the typed [failureReason] so that
/// [categorizeError] and [isRetriableError] can branch on them directly
/// instead of parsing error-message strings. The [failureReason]
/// distinguishes a transient inability to *produce* a signed auth header
/// ([BlossomUploadFailureReason.authUnavailable]) from a permanent
/// server-side auth rejection ([BlossomUploadFailureReason.auth]) — a
/// distinction the bare error string cannot carry.
class BlossomUploadFailureException implements Exception {
  const BlossomUploadFailureException(
    this.message, {
    this.statusCode,
    this.failureReason,
  });

  final String message;
  final int? statusCode;
  final BlossomUploadFailureReason? failureReason;

  @override
  String toString() => message;
}
