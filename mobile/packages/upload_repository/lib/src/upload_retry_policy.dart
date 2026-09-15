// ABOUTME: Retry policy for video uploads — owns exponential backoff, session
// ABOUTME: persistence, and manual/automatic retry lifecycle for UploadManager.

import 'dart:async';
import 'dart:math' as math;

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:unified_logger/unified_logger.dart';

import 'package:upload_repository/src/pending_upload.dart';
import 'package:upload_repository/src/pending_upload_store.dart';
import 'package:upload_repository/src/upload_config.dart';
import 'package:upload_repository/src/upload_session_errors.dart';

/// Owns retry and session persistence for [UploadRepository].
class UploadRetryPolicy {
  UploadRetryPolicy({
    required PendingUploadStore store,
    required UploadRetryConfig retryConfig,
  }) : _store = store,
       _retryConfig = retryConfig;

  final PendingUploadStore _store;
  final UploadRetryConfig _retryConfig;

  final Map<String, Future<void>> _sessionPersistFutures = {};
  final Map<String, Completer<void>> _backoffWakeCompleters = {};
  final Set<String> _discardedUploadIds = <String>{};
  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> performWithRetry(
    PendingUpload upload,
    Future<void> Function() executeUpload, {
    required bool Function(dynamic) isRetriable,
  }) async {
    if (_isDisposed) return;
    if (_discardedUploadIds.contains(upload.id)) return;

    // Local-only counter for how many auto-attempts have been made in this
    // call. Must NOT be persisted to Hive: PendingUpload.retryCount is the
    // manual-retry budget (canRetry gates on retryCount < 3). Writing
    // auto-attempt counts there would exhaust the budget and prevent the user
    // from calling retryUpload() after a failed session.
    var autoAttempt = 0;

    try {
      while (!_isDisposed && autoAttempt <= _retryConfig.maxRetries) {
        if (_discardedUploadIds.contains(upload.id)) return;
        try {
          await drainSessionPersist(upload.id);
          if (_discardedUploadIds.contains(upload.id)) return;
          final currentUpload = _store.getUpload(upload.id) ?? upload;

          // autoAttempt is local to this performWithRetry invocation and is
          // never written to Hive, so the manual-retry budget is preserved.
          autoAttempt++;
          Log.warning(
            'Upload attempt $autoAttempt/${_retryConfig.maxRetries + 1} for ${currentUpload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );

          if (_discardedUploadIds.contains(upload.id)) return;
          await _store.update(
            currentUpload.copyWith(
              status: autoAttempt == 1
                  ? UploadStatus.uploading
                  : UploadStatus.retrying,
              // retryCount is intentionally left unchanged here — it is the
              // manual-retry budget managed exclusively by retryUpload().
            ),
          );

          await executeUpload();
          if (autoAttempt > 1) {
            Log.warning(
              'Upload retry succeeded after ${autoAttempt - 1} retries: ${upload.id}',
              name: 'UploadManager',
              category: LogCategory.video,
            );
          }
          return;
        } catch (error) {
          if (!isRetriable(error)) {
            Log.error(
              'Upload retry policy not retrying error for ${upload.id}: $error',
              name: 'UploadManager',
              category: LogCategory.video,
            );
            rethrow;
          }

          if (autoAttempt > _retryConfig.maxRetries) {
            Log.error(
              'Upload retry policy max retries exceeded for ${upload.id}: $error',
              name: 'UploadManager',
              category: LogCategory.video,
            );
            rethrow;
          }

          final delayMs = math
              .min(
                _retryConfig.initialDelay.inMilliseconds *
                    math.pow(_retryConfig.backoffMultiplier, autoAttempt - 1),
                _retryConfig.maxDelay.inMilliseconds.toDouble(),
              )
              .round();
          final delay = Duration(milliseconds: delayMs);
          Log.error(
            'Upload attempt $autoAttempt failed, retrying in ${delay.inMilliseconds}ms: ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );

          await _waitForBackoff(upload.id, delay);
          if (_isDisposed || _discardedUploadIds.contains(upload.id)) return;
        }
      }
    } catch (e) {
      Log.error(
        'Upload failed after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  bool wakeBackoff(String uploadId) {
    if (_isDisposed) return false;
    final completer = _backoffWakeCompleters.remove(uploadId);
    if (completer == null) return false;
    if (!completer.isCompleted) {
      completer.complete();
    }
    return true;
  }

  bool isWaitingForBackoff(String uploadId) =>
      _backoffWakeCompleters.containsKey(uploadId);

  void discardUploads(Iterable<String> uploadIds) {
    for (final uploadId in uploadIds) {
      _discardedUploadIds.add(uploadId);
      final completer = _backoffWakeCompleters.remove(uploadId);
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
      final _ = _sessionPersistFutures.remove(uploadId);
    }
  }

  void enqueueSessionPersist(
    String uploadId,
    BlossomResumableUploadSession session,
    int fileSizeBytes,
  ) {
    if (_discardedUploadIds.contains(uploadId)) return;
    final previous = _sessionPersistFutures[uploadId] ?? Future<void>.value();
    final persistFuture = previous.then((_) async {
      try {
        if (_discardedUploadIds.contains(uploadId)) return;
        await _storeResumableSessionProgress(uploadId, session, fileSizeBytes);
      } catch (e, s) {
        Log.error(
          'Failed to persist resumable session progress for $uploadId: $e',
          name: 'UploadManager',
          category: LogCategory.video,
          error: e,
          stackTrace: s,
        );
      }
    });
    _sessionPersistFutures[uploadId] = persistFuture;
    unawaited(
      persistFuture.whenComplete(() {
        if (identical(_sessionPersistFutures[uploadId], persistFuture)) {
          final _ = _sessionPersistFutures.remove(uploadId);
        }
      }),
    );
  }

  Future<void> drainSessionPersist(String uploadId) async {
    if (_discardedUploadIds.contains(uploadId)) return;
    await (_sessionPersistFutures[uploadId] ?? Future<void>.value());
  }

  Future<void> retryUpload(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) async {
    final upload = _store.getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for retry: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (!upload.canRetry) {
      Log.error(
        'Upload cannot be retried: $uploadId (retries: ${upload.retryCount})',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.warning(
      'Retrying upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final nextRetryCount = (upload.retryCount ?? 0) + 1;
    final resetUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: nextRetryCount,
    );

    await _store.update(resetUpload);
    await performUpload(resetUpload);
  }

  void resumeInterruptedUpload(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) {
    if (_discardedUploadIds.contains(uploadId)) return;
    final upload = _store.getUpload(uploadId);
    if (upload == null) return;
    if (upload.status != UploadStatus.uploading &&
        upload.status != UploadStatus.retrying) {
      return;
    }

    Log.info(
      'Resuming interrupted upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final resumed = upload.copyWith(status: UploadStatus.uploading);
    unawaited(_store.update(resumed));
    unawaited(performUpload(resumed));
  }

  /// Re-run a failed upload, resetting the manual-retry budget when the last
  /// attempt is at least an hour old and otherwise incrementing it.
  ///
  /// Despite the name there is no backoff *timer* — the budget is the
  /// "backoff": [performUpload] is invoked immediately and the 1-hour reset
  /// window is what spaces out repeated manual retries.
  Future<void> retryUploadWithBackoff(
    String uploadId, {
    required Future<void> Function(PendingUpload) performUpload,
  }) async {
    final upload = _store.getUpload(uploadId);
    if (upload == null) {
      Log.warning(
        'Upload not found for retry: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.failed) {
      Log.error(
        'Upload is not in failed state: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.warning(
      'Retrying upload with backoff: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final now = DateTime.now();
    final timeSinceLastAttempt = upload.completedAt != null
        ? now.difference(upload.completedAt!)
        : now.difference(upload.createdAt);

    final shouldResetRetries = timeSinceLastAttempt.inHours >= 1;
    final newRetryCount = shouldResetRetries ? 1 : (upload.retryCount ?? 0) + 1;

    final updatedUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: newRetryCount,
    );

    await _store.update(updatedUpload);
    await performUpload(updatedUpload);
  }

  bool isRetriableError(dynamic error) {
    if (isExpiredResumableSessionError(error)) {
      return false;
    }

    if (error is BlossomResumableUploadException) {
      final reason = error.failureReason;
      if (reason == BlossomUploadFailureReason.authUnavailable ||
          reason == BlossomUploadFailureReason.network ||
          error.isRecoverableResumableFailure) {
        return true;
      }
      if (reason == BlossomUploadFailureReason.auth ||
          reason == BlossomUploadFailureReason.fileTooLarge ||
          reason == BlossomUploadFailureReason.cancelled) {
        return false;
      }

      final code = error.statusCode;
      if (code != null) {
        if (code == 408) return true;
        if (code == 429) return true;
        if (code == 500 || code == 502 || code == 503 || code == 504) {
          return true;
        }
        if (code >= 500) return false;
        if (code >= 400) return false;
      }
    }

    // Use structured classification when available.
    if (error is BlossomUploadFailureException) {
      // A transient inability to *produce* a signed auth header (the remote
      // signer or its network path was briefly unreachable) is retriable —
      // distinct from a permanent 401/403 rejection handled below. This is
      // the fix for uploads that died on a momentary signer DNS blip.
      final reason = error.failureReason;
      if (reason == BlossomUploadFailureReason.authUnavailable ||
          reason == BlossomUploadFailureReason.network) {
        return true;
      }
      // A user pause/cancel is a deliberate, terminal stop — never retry it,
      // or the retry loop would re-upload the file the user just stopped.
      if (reason == BlossomUploadFailureReason.cancelled ||
          reason == BlossomUploadFailureReason.auth ||
          reason == BlossomUploadFailureReason.fileTooLarge) {
        return false;
      }

      final code = error.statusCode;
      if (code != null) {
        // 408 request timeout — retriable
        if (code == 408) return true;
        // 429 rate limited — retriable after backoff
        if (code == 429) return true;
        // Transient server errors — retriable
        if (code == 500 || code == 502 || code == 503 || code == 504) {
          return true;
        }
        // Other 5xx (501, 505, etc.) are permanent — not retriable
        if (code >= 500) return false;
        // 4xx client errors are not retriable
        if (code >= 400) return false;
      }
    }

    // Fall back to string matching for non-HTTP errors
    final errorStr = error.toString().toLowerCase();

    // A missing required thumbnail already exhausted the image upload's own
    // retry path; retrying here would re-upload the full video.
    if (errorStr.contains('thumbnail upload failed')) {
      return false;
    }

    // Network and timeout errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('cannot connect') ||
        errorStr.contains('network error') ||
        errorStr.contains('connection') ||
        errorStr.contains('socket')) {
      return true;
    }

    // File not found errors are not retriable
    if (errorStr.contains('file not found') ||
        errorStr.contains('does not exist')) {
      return false;
    }

    // Permission and cancellation failures are permanent. Authentication is
    // classified structurally above (failureReason / 401-403 statusCode): a
    // failed auth-header *creation* is transient while a server *rejection*
    // is not, and the bare substring 'auth' cannot tell them apart — so it
    // no longer gates retries here.
    if (errorStr.contains('permission') || errorStr.contains('cancelled')) {
      return false;
    }

    // Unknown errors are retriable by default
    return true;
  }

  void dispose() {
    _isDisposed = true;
    for (final completer in _backoffWakeCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _backoffWakeCompleters.clear();
    _sessionPersistFutures.clear();
    _discardedUploadIds.clear();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _waitForBackoff(String uploadId, Duration delay) async {
    final completer = Completer<void>();
    _backoffWakeCompleters[uploadId] = completer;
    final timer = Timer(delay, () {
      if (identical(_backoffWakeCompleters[uploadId], completer)) {
        _backoffWakeCompleters.remove(uploadId);
      }
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future;
    } finally {
      timer.cancel();
      if (identical(_backoffWakeCompleters[uploadId], completer)) {
        _backoffWakeCompleters.remove(uploadId);
      }
    }
  }

  Future<void> _storeResumableSessionProgress(
    String uploadId,
    BlossomResumableUploadSession session,
    int fileSizeBytes,
  ) async {
    if (_discardedUploadIds.contains(uploadId)) return;
    final upload = _store.getUpload(uploadId);
    if (upload == null) return;

    // The live transfer callback persists progress on every tick and owns the
    // bar; this checkpoint exists so a restart resumes from a sane mark. The
    // two run on different curves, so the checkpoint may only ever raise the
    // stored value — otherwise it drags the publish bar backwards mid-upload.
    final checkpoint = fileSizeBytes <= 0
        ? upload.uploadProgress
        : ((session.nextOffset / fileSizeBytes) * videoProgressShare).clamp(
            0.0,
            videoProgressShare,
          );
    final persistedProgress = checkpoint == null
        ? upload.uploadProgress
        : math.max(checkpoint, upload.uploadProgress ?? 0.0);

    if (_discardedUploadIds.contains(uploadId)) return;
    await _store.update(
      upload.copyWith(
        resumableSession: session,
        uploadProgress: persistedProgress,
      ),
    );
  }
}
