// ABOUTME: Shared upload configuration consumed by UploadManager and the
// ABOUTME: extracted upload helpers, so the helpers need not import the manager.

/// Upload retry configuration.
class UploadRetryConfig {
  const UploadRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.networkTimeout = const Duration(minutes: 10),
  });
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final Duration networkTimeout;
}

/// Share of the progress bar driven by the video transfer.
///
/// The remainder covers joining the thumbnail leg, which runs in parallel and
/// is virtually always finished first — so the bar reaches this mark and then
/// completes, rather than sitting at 100% while the publish is still working.
///
/// `UploadRetryPolicy` persists its resumable checkpoint on the same scale, so
/// the two writers of `uploadProgress` cannot disagree on the ceiling.
const double videoProgressShare = 0.95;

/// Names of the publish-timeline phases the upload pipeline reports.
abstract final class UploadPhases {
  static const uploadTransfer = 'upload.transfer';
  static const uploadThumbnail = 'upload.thumbnail';
  static const uploadThumbnailExtract = 'upload.thumbnail.extract';
  static const uploadThumbnailBlurhash = 'upload.thumbnail.blurhash';
  static const uploadThumbnailPut = 'upload.thumbnail.put';
  static const reusedDetail = 'reused';
}
