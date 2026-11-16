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

/// Which half of an upload's thumbnail leg failed.
enum ThumbnailUploadFailureStage {
  /// Making the thumbnail on the device: the extractor returned no frame,
  /// its file was gone, or it threw.
  extraction,

  /// Sending the extracted image to the Blossom server.
  upload,
}

/// The thumbnail leg of an upload ended without a CDN URL.
///
/// Divine relays require a CDN thumbnail, so the publish cannot go ahead
/// without one. The exception keeps the leg's actual cause, so
/// [UploadProgressReporter] can tell an expected network or server failure
/// from a local one, and [isTransient] tells the repository whether
/// uploading the thumbnail again can work.
class ThumbnailUploadException implements Exception {
  const ThumbnailUploadException(
    this.stage,
    this.cause, {
    this.statusCode,
    this.failureReason,
    this.isTransientNetworkFailure = false,
  });

  /// The failure carried by an image upload that returned no CDN URL.
  factory ThumbnailUploadException.fromUploadResult(
    BlossomUploadResult result,
  ) => ThumbnailUploadException(
    ThumbnailUploadFailureStage.upload,
    result.errorMessage ?? 'the server returned no URL',
    statusCode: result.statusCode,
    failureReason: result.failureReason,
    isTransientNetworkFailure: result.isTransientNetworkFailure,
  );

  /// HTTP statuses worth another thumbnail upload; the same set
  /// `UploadRetryPolicy.isRetriableError` retries for the video.
  static const _transientStatusCodes = {408, 429, 500, 502, 503, 504};

  final ThumbnailUploadFailureStage stage;

  /// What went wrong, as reported by the extractor or the Blossom service.
  final String cause;

  final int? statusCode;
  final BlossomUploadFailureReason? failureReason;
  final bool isTransientNetworkFailure;

  /// Whether another upload of the thumbnail can succeed: a dropped
  /// connection, a signer that was briefly unreachable, or a status the
  /// server sends while it is overloaded or restarting. An extraction failure
  /// is local and never transient.
  bool get isTransient {
    if (stage != ThumbnailUploadFailureStage.upload) return false;
    if (isTransientNetworkFailure) return true;
    if (failureReason == BlossomUploadFailureReason.network ||
        failureReason == BlossomUploadFailureReason.authUnavailable) {
      return true;
    }
    return _transientStatusCodes.contains(statusCode);
  }

  @override
  String toString() => 'Thumbnail upload failed (${stage.name}): $cause';
}
