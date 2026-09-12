// ABOUTME: Persistence layer for PendingUpload records – owns the Hive box,
// ABOUTME: the save-queue fallback, and all query/cleanup operations.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:openvine/services/upload_publishability.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the Hive persistence layer for [PendingUpload] records.
///
/// [UploadManager] constructs exactly one instance and delegates all
/// storage reads and writes here.  The two scoping params mirror the
/// corresponding fields that previously lived on [UploadManager].
class PendingUploadStore {
  PendingUploadStore({
    required this.scopeUploadsToCurrentUser,
    required this.currentNostrPubkey,
  });

  final bool scopeUploadsToCurrentUser;
  final String? currentNostrPubkey;

  Box<PendingUpload>? _box;

  /// Deferred-save retry queue, keyed by [PendingUpload.id] so re-enqueuing the
  /// same upload is idempotent (the queue can never hold the same upload twice).
  final Map<String, PendingUpload> _pendingSaveQueue = {};
  Timer? _saveQueueTimer;

  /// True while [_processSaveQueue] is draining; guards against a re-entrant
  /// drain started by a retry timer firing mid-drain.
  bool _isDraining = false;

  /// Latched true by [disposeStore]; gates every queue mutation, timer-arm, and
  /// box revival so a drain suspended on `await save()` at disposal cannot
  /// repopulate the queue, schedule a retry that outlives the store, or reopen
  /// the box via [ensureOpen]. Cleared only by [open] — the deliberate
  /// re-initialization entrypoint, which is never reached from the drain's own
  /// `save() -> ensureOpen()` path, so a storage recovery mid-drain can't
  /// silently revive a disposed store.
  bool _disposed = false;

  // ---------------------------------------------------------------------------
  // Status accessors
  // ---------------------------------------------------------------------------

  /// True when the Hive box is open and ready for reads/writes.
  bool get isReady => _box != null && _box!.isOpen;

  /// Total number of records currently in the box (0 when not ready).
  int get length => _box?.length ?? 0;

  /// Number of uploads waiting in the deferred-save queue.
  int get queuedCount => _pendingSaveQueue.length;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Open the Hive box for the first time (called from [UploadManager.initialize]).
  ///
  /// On failure the box pointer is reset to null so [isReady] reports false –
  /// mirroring the original `initialize()` catch that nulled the box – before
  /// the error propagates to the manager's initialization error handler.
  Future<void> open() async {
    // A fresh lifecycle: clear the disposed latch so a reused store can queue
    // and retry again. open() is unreachable from the drain (which only calls
    // ensureOpen), so clearing here can't revive a store mid-drain.
    _disposed = false;
    try {
      _box = await UploadInitializationHelper.initializeUploadsBox(
        forceReinit: true,
      );
    } catch (_) {
      _box = null;
      rethrow;
    }
  }

  /// Force-reopen the box (called from re-init-when-closed paths).
  Future<void> ensureOpen() async {
    // Stay inert once disposed. A drain suspended on `await save()` resumes into
    // this via save()'s slow path; reviving _box here would leave a disposed
    // store with a live, open box (isReady → true while _disposed). open() — the
    // deliberate re-init entrypoint — clears the latch and is the only revival.
    if (_disposed) return;
    final box = await UploadInitializationHelper.initializeUploadsBox(
      forceReinit: true,
    );
    // disposeStore() can land while the open above is suspended. The entry check
    // is before the await, so re-check before reviving _box, or a disposed store
    // comes back alive (isReady → true while _disposed).
    if (_disposed) return;
    _box = box;
  }

  /// Cancel timers, drain the queue reference, and null the box pointer.
  ///
  /// Does NOT close the box – closing is Hive's responsibility and closing
  /// here causes "File closed" errors in tests that share the box instance.
  void disposeStore() {
    // Latch disposed first: a drain may be suspended on `await save()` right
    // now, and must see this the instant it resumes so it can't re-enqueue or
    // re-arm a timer past disposal.
    _disposed = true;
    _saveQueueTimer?.cancel();
    _saveQueueTimer = null;
    _pendingSaveQueue.clear();
    _isDraining = false;
    // Null the reference so isReady → false without actually closing.
    _box = null;
  }

  // ---------------------------------------------------------------------------
  // Persistence – write paths
  // ---------------------------------------------------------------------------

  /// Persist a new [upload] to the Hive box.
  ///
  /// If the box is unavailable, falls back to robust re-init; on failure
  /// the upload is queued for a deferred retry (5 s / 30 s schedule).
  Future<void> save(PendingUpload upload) async {
    // Fast path – box is already open.
    if (_box != null && _box!.isOpen) {
      try {
        await _box!.put(upload.id, upload);
        Log.info(
          '✅ Upload saved to Hive box with ID: ${upload.id}',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return;
      } catch (e) {
        Log.warning(
          'Failed to save with existing box: $e, attempting recovery...',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }
    }

    // Slow path – box is null or save failed; try robust re-init.
    Log.warning(
      'Upload box not ready, using robust initialization...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      await ensureOpen();

      if (!isReady) {
        throw Exception('Failed to initialize box for saving upload');
      }

      await _box!.put(upload.id, upload);
      Log.info(
        '✅ Upload saved after robust initialization: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '❌ Failed to save upload after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Last resort – queue for a later retry attempt.
      _queueUploadForLater(upload);

      throw Exception(
        'Unable to save upload: Storage initialization failed after multiple attempts',
      );
    }
  }

  /// Overwrite an existing [upload] record (no-op when box is not ready).
  Future<void> update(PendingUpload upload) async {
    if (_box == null) return;
    await _box!.put(upload.id, upload);
  }

  /// Delete the record with [id] from the box (no-op when box is not ready).
  Future<void> delete(String id) async {
    if (_box == null) return;
    await _box!.delete(id);
  }

  /// Delete every upload persisted for [ownerPubkey].
  ///
  /// This is intentionally not owner-scoped to [currentNostrPubkey]: destructive
  /// account cleanup passes the departing account explicitly, and must work even
  /// after provider auth state has moved on.
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    final queueIds = _pendingSaveQueue.entries
        .where((entry) => entry.value.nostrPubkey == ownerPubkey)
        .map((entry) => entry.key)
        .toList();
    queueIds.forEach(_pendingSaveQueue.remove);
    if (_pendingSaveQueue.isEmpty) {
      _saveQueueTimer?.cancel();
      _saveQueueTimer = null;
    }

    if (_box == null || !_box!.isOpen) {
      try {
        await ensureOpen();
      } catch (e) {
        Log.warning(
          'Unable to open pending uploads box for owner cleanup: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return 0;
      }
    }
    if (_box == null || !_box!.isOpen) return 0;

    final uploadIds = _allUploads
        .where((upload) => upload.nostrPubkey == ownerPubkey)
        .map((upload) => upload.id)
        .toList();
    for (final id in uploadIds) {
      await _box!.delete(id);
    }
    return uploadIds.length;
  }

  // ---------------------------------------------------------------------------
  // Deferred-save queue
  // ---------------------------------------------------------------------------

  void _queueUploadForLater(PendingUpload upload) {
    // A disposed store must not requeue or re-arm a timer — this runs from the
    // failure slow path of save(), which a zombie drain re-enters after
    // disposeStore() nulls the box.
    if (_disposed) return;

    Log.warning(
      'Queueing upload ${upload.id} for later save attempt',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    _pendingSaveQueue[upload.id] = upload;

    // Schedule retry in 5 seconds.
    _saveQueueTimer?.cancel();
    _saveQueueTimer = Timer(const Duration(seconds: 5), _processSaveQueue);
  }

  Future<void> _processSaveQueue() async {
    // A disposed store never drains — defends the @visibleForTesting drain hook
    // and any retry that races disposal.
    if (_disposed) return;
    // A retry timer can fire while a drain is still awaiting save() (which can
    // take seconds during a storage outage). Don't start a second drain.
    if (_isDraining) return;
    if (_pendingSaveQueue.isEmpty) return;

    _isDraining = true;
    try {
      Log.info(
        'Processing ${_pendingSaveQueue.length} queued uploads',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      final queue = _pendingSaveQueue.values.toList();
      _pendingSaveQueue.clear();

      for (final upload in queue) {
        try {
          await save(upload);
          Log.info(
            'Successfully saved queued upload: ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            'Failed to save queued upload ${upload.id}: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          // Re-queue for another attempt. Keyed by id, so this is idempotent
          // with save()'s own _queueUploadForLater enqueue of the same upload.
          // Skip once disposed so a drain that resumes after disposeStore()
          // leaves the queue empty.
          if (!_disposed) _pendingSaveQueue[upload.id] = upload;
        }
      }
    } finally {
      _isDraining = false;
    }

    // If items remain, schedule a further retry in 30 seconds. Cancel first so
    // the 5 s timer set during this drain (via _queueUploadForLater) can't leak.
    // Never re-arm once disposed: a drain that resumed after disposeStore()
    // must not schedule a retry that outlives the store.
    if (!_disposed && _pendingSaveQueue.isNotEmpty) {
      _saveQueueTimer?.cancel();
      _saveQueueTimer = Timer(const Duration(seconds: 30), _processSaveQueue);
    }
  }

  /// Triggers the deferred-save drain. The drain is otherwise invoked only by
  /// the internal retry timer; tests use this to exercise it deterministically.
  @visibleForTesting
  Future<void> drainPendingSaves() => _processSaveQueue();

  /// True while a drain is in flight — test hook for the re-entrancy guard.
  @visibleForTesting
  bool get isDraining => _isDraining;

  /// True once [disposeStore] has latched the store closed and before any
  /// [open] revives it — test hook for the disposal latch.
  @visibleForTesting
  bool get isDisposed => _disposed;

  /// True when a deferred-save retry timer is currently scheduled — test hook to
  /// assert exactly one timer is live (no orphaned retry).
  @visibleForTesting
  bool get hasScheduledRetry => _saveQueueTimer?.isActive ?? false;

  // ---------------------------------------------------------------------------
  // Query helpers
  // ---------------------------------------------------------------------------

  /// All uploads sorted newest-first; not owner-scoped.
  List<PendingUpload> get _allUploads {
    if (_box == null) return [];
    return _box!.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Uploads visible to the configured owner (or all uploads when unscoped).
  List<PendingUpload> get pendingUploads {
    final uploads = _allUploads;
    if (!scopeUploadsToCurrentUser) return uploads;
    return uploads.where(_isVisibleToCurrentOwner).toList();
  }

  /// All uploads persisted for [ownerPubkey], ignoring current-user scoping.
  ///
  /// Destructive account cleanup passes the departing owner explicitly and can
  /// run after auth state has already moved to another account.
  List<PendingUpload> uploadsForOwner(String ownerPubkey) =>
      _allUploads.where((upload) => upload.nostrPubkey == ownerPubkey).toList();

  bool _isVisibleToCurrentOwner(PendingUpload upload) {
    if (!scopeUploadsToCurrentUser) return true;
    final currentPubkey = currentNostrPubkey;
    return currentPubkey != null &&
        currentPubkey.isNotEmpty &&
        upload.nostrPubkey == currentPubkey;
  }

  /// Retrieve a single upload by [id], applying owner-scope filter.
  PendingUpload? getUpload(String id) {
    final upload = _box?.get(id);
    if (upload == null || !_isVisibleToCurrentOwner(upload)) return null;
    return upload;
  }

  /// First upload in [pendingUploads] whose local path equals [filePath].
  PendingUpload? getUploadByFilePath(String filePath) {
    try {
      return pendingUploads.firstWhere(
        (upload) => upload.localVideoPath == filePath,
      );
    } catch (e) {
      return null;
    }
  }

  /// Most-recent upload for [filePath] that is in a resumable/reusable state.
  PendingUpload? findReusableUpload(String filePath) {
    for (final upload in pendingUploads) {
      if (upload.localVideoPath != filePath) continue;
      if (upload.status == UploadStatus.published) continue;
      if (upload.status == UploadStatus.pending) continue;
      if (upload.status == UploadStatus.paused) continue;
      if (upload.status == UploadStatus.readyToPublish &&
          !readyUploadIsPublishable(upload)) {
        continue;
      }
      if (upload.status == UploadStatus.failed &&
          upload.resumableSession == null) {
        continue;
      }
      return upload;
    }
    return null;
  }

  /// Count of uploads in each status bucket (owner-scoped).
  Map<String, int> get uploadStats {
    final uploads = pendingUploads;
    return {
      'total': uploads.length,
      'pending': uploads.where((u) => u.status == UploadStatus.pending).length,
      'uploading': uploads
          .where((u) => u.status == UploadStatus.uploading)
          .length,
      'processing': uploads
          .where((u) => u.status == UploadStatus.processing)
          .length,
      'ready': uploads
          .where((u) => u.status == UploadStatus.readyToPublish)
          .length,
      'published': uploads
          .where((u) => u.status == UploadStatus.published)
          .length,
      'failed': uploads.where((u) => u.status == UploadStatus.failed).length,
    };
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Delete published, stale-completed, and unrecoverable-failed uploads.
  ///
  /// Operates on ALL uploads (not owner-scoped) to avoid leaving orphaned
  /// records from previous accounts.
  Future<void> cleanupCompletedUploads() async {
    if (_box == null) return;

    final uploadsToClean = <PendingUpload>[];

    for (final upload in _allUploads) {
      // Published uploads are fully done – remove immediately.
      if (upload.status == UploadStatus.published) {
        uploadsToClean.add(upload);
        continue;
      }

      // Remove completed uploads after 1 day.
      if (upload.isCompleted &&
          upload.completedAt != null &&
          DateTime.now().difference(upload.completedAt!).inDays >= 1) {
        uploadsToClean.add(upload);
        continue;
      }

      // Remove failed uploads whose video file no longer exists (unrecoverable).
      if (upload.status == UploadStatus.failed && !kIsWeb) {
        final videoFile = File(upload.localVideoPath);
        if (!videoFile.existsSync()) {
          uploadsToClean.add(upload);
          continue;
        }
      }
    }

    for (final upload in uploadsToClean) {
      await _box!.delete(upload.id);
      Log.debug(
        '🗑️ Cleaned up upload: ${upload.id} (${upload.status.name})',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    if (uploadsToClean.isNotEmpty) {
      Log.info(
        '🧹 Cleaned up ${uploadsToClean.length} old/unrecoverable uploads',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Move readyToPublish uploads that are missing required CDN data to failed.
  ///
  /// Operates on owner-scoped [pendingUploads].
  Future<void> cleanupProblematicUploads() async {
    final uploads = pendingUploads;
    var fixedCount = 0;

    for (final upload in uploads) {
      if (upload.status == UploadStatus.readyToPublish &&
          !readyUploadIsPublishable(upload)) {
        Log.error(
          'Fixing stuck upload: ${upload.id} (missing publishable video data) - moving to failed',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        final fixedUpload = upload.copyWith(status: UploadStatus.failed);
        await update(fixedUpload);
        fixedCount++;
      }
    }

    if (fixedCount > 0) {
      Log.error(
        'Fixed $fixedCount stuck uploads - moved back to failed status',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }
}
