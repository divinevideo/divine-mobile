// ABOUTME: Service for managing video upload state and local persistence
// ABOUTME: Handles upload queue, retries, and coordination between UI and Blossom upload service

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

import 'package:upload_repository/src/pending_upload.dart';
import 'package:upload_repository/src/pending_upload_store.dart';
import 'package:upload_repository/src/upload_config.dart';
import 'package:upload_repository/src/upload_ports.dart';
import 'package:upload_repository/src/upload_progress_reporter.dart';
import 'package:upload_repository/src/upload_retry_policy.dart';
import 'package:upload_repository/src/upload_session_errors.dart';
import 'package:upload_repository/src/video_circuit_breaker.dart';

abstract final class UploadPhases {
  static const uploadTransfer = 'upload.transfer';
  static const uploadThumbnail = 'upload.thumbnail';
  static const uploadThumbnailExtract = 'upload.thumbnail.extract';
  static const uploadThumbnailBlurhash = 'upload.thumbnail.blurhash';
  static const uploadThumbnailPut = 'upload.thumbnail.put';
  static const reusedDetail = 'reused';
}

/// What the thumbnail leg produces: the CDN URL of the uploaded frame, and the
/// blurhash derived from that same frame.
typedef ThumbnailLegResult = ({String? cdnUrl, String? blurhash});

/// Manages video uploads and their persistent state with enhanced reliability
class UploadRepository {
  UploadRepository({
    required BlossomUploadService blossomService,
    required PendingUploadBoxOpener openPendingUploadsBox,
    required UploadCrashReporter crashReporter,
    required ThumbnailExtractor thumbnailExtractor,
    required UploadBlurhashGenerator blurhashGenerator,
    required TransientRenderCleaner transientRenderCleaner,
    required UploadConnectivityProvider connectivityProvider,
    required Map<String, Object?> Function() debugStateProvider,
    required String platformName,
    required bool isWeb,
    required Duration defaultThumbnailTimestamp,
    UploadTelemetry? telemetry,
    String? defaultBlossomUrl,
    String? currentNostrPubkey,
    bool scopeUploadsToCurrentUser = false,
    VideoCircuitBreaker? circuitBreaker,
    UploadRetryConfig? retryConfig,
    this.useBackgroundUpload = false,
  }) : _blossomService = blossomService,
       _extractThumbnail = thumbnailExtractor,
       _blurhashGenerator = blurhashGenerator,
       _transientRenderCleaner = transientRenderCleaner,
       _debugStateProvider = debugStateProvider,
       _isWeb = isWeb,
       _defaultThumbnailTimestamp = defaultThumbnailTimestamp,
       _telemetry = telemetry ?? _ignoreTelemetry,
       _defaultBlossomUrl =
           defaultBlossomUrl ?? BlossomUploadService.defaultBlossomServer,
       _circuitBreaker = circuitBreaker ?? VideoCircuitBreaker(),
       _retryConfig = retryConfig ?? const UploadRetryConfig(),
       _store = PendingUploadStore(
         scopeUploadsToCurrentUser: scopeUploadsToCurrentUser,
         currentNostrPubkey: currentNostrPubkey,
         openBox: openPendingUploadsBox,
         isWeb: isWeb,
       ),
       _platformName = platformName {
    _retryPolicy = UploadRetryPolicy(store: _store, retryConfig: _retryConfig);
    _reporter = UploadProgressReporter(
      store: _store,
      circuitBreaker: _circuitBreaker,
      retryConfig: _retryConfig,
      crashReporter: crashReporter,
      connectivityProvider: connectivityProvider,
      platformName: _platformName,
      isWeb: _isWeb,
    );
  }

  static void _ignoreTelemetry(
    String phase,
    Duration elapsed, {
    int? bytes,
    String? detail,
  }) {}

  /// Attempts the OS background uploader
  /// ([BlossomUploadService.uploadVideoInBackground]) *first* for a fresh
  /// publish — it survives app suspension and is fastest on a healthy
  /// connection — then falls back to the in-process chunked resumable path if
  /// that OS attempt fails (a user cancel is treated as terminal and does NOT
  /// fall back). Set to `false` to skip the OS attempt and go straight to the
  /// in-process path. Requires the blossom service to have been built with a
  /// background transport.
  final bool useBackgroundUpload;

  // Core services
  final PendingUploadStore _store;
  final BlossomUploadService _blossomService;

  /// Pulls the thumbnail frame out of the local video. Injectable so the
  /// thumbnail leg can be exercised without a decodable video and the native
  /// plugin behind [VideoThumbnailService].
  final ThumbnailExtractor _extractThumbnail;
  final UploadBlurhashGenerator _blurhashGenerator;
  final Map<String, Object?> Function() _debugStateProvider;
  final UploadTelemetry _telemetry;
  final bool _isWeb;
  final String _platformName;
  final Duration _defaultThumbnailTimestamp;

  final String _defaultBlossomUrl;
  final VideoCircuitBreaker _circuitBreaker;
  final UploadRetryConfig _retryConfig;
  final Dio _dio = Dio();

  // Extracted concerns
  late final UploadRetryPolicy _retryPolicy;
  late final UploadProgressReporter _reporter;
  final Map<String, Set<String>> _transientRenderPathsByUploadId = {};
  final TransientRenderCleaner _transientRenderCleaner;

  // Processing-completion polls keyed by upload id, so dispose() can
  // cancel them — an untracked periodic timer would keep firing against
  // a disposed manager for up to 5 minutes.
  final Map<String, Timer> _processingPollTimers = {};

  // Uploads the user cancelled while their transfer was still in
  // flight. Cancelling an OS background transfer emits a `cancelled` terminal
  // event that resolves the in-flight [_performUpload] future as a failure; a
  // marker here lets that path recognise a user-initiated stop and skip
  // [_handleUploadFailure], so a pause is not overwritten with `failed` and
  // a cancel does not emit a spurious failure crash report. Cleared when the
  // owning [_performUpload] run settles.
  final Set<String> _userStoppedUploadIds = <String>{};

  // In-process single-flight guard. Every entry point that can drive an upload
  // shares this map, so a sweep and a user retry cannot start overlapping Dart
  // upload pipelines for the same PendingUpload.
  final Map<String, Future<void>> _inFlightUploads = <String, Future<void>>{};

  // Owners whose local pending-upload state was destructively purged during
  // account cleanup. Late callbacks from already-started uploads must not
  // recreate rows for accounts that have just been removed.
  final Set<String> _purgedUploadOwners = <String>{};

  // Re-entrancy latch for [_recoverStuckUploads]; startup and app-resume
  // recovery can run close together while missing-file updates are awaiting.
  bool _isRecovering = false;

  bool _isInitialized = false;

  /// Check if the upload manager is initialized
  bool get isInitialized => _isInitialized && _store.isReady;

  /// Whether an upload's [_performUpload] future is currently on the event
  /// loop. Visible for testing the recovery sweep's in-flight skip logic.
  @visibleForTesting
  bool isUploadInFlight(String uploadId) =>
      _inFlightUploads.containsKey(uploadId);

  @visibleForTesting
  bool isUploadWaitingForRetryBackoff(String uploadId) =>
      _retryPolicy.isWaitingForBackoff(uploadId);

  /// Initialize the upload manager and load persisted uploads
  /// Uses robust initialization with retry logic and recovery strategies
  Future<void> initialize() async {
    if (_isInitialized && _store.isReady) {
      Log.info(
        'UploadManager already initialized',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🚀 Initializing UploadManager with robust retry logic',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      // Delegate box open to the store.
      await _store.open();

      if (!_store.isReady) {
        throw Exception(
          'Failed to initialize uploads box after all recovery attempts',
        );
      }

      _isInitialized = true;

      Log.info(
        '✅ UploadManager initialized successfully with ${_store.length} existing uploads',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Clean up any problematic uploads first
      await cleanupProblematicUploads();

      // Clean up old completed/published uploads to prevent accumulation
      await cleanupCompletedUploads();

      // Re-drive uploads left in `uploading`/`retrying` by a prior crash or
      // background freeze. Fire-and-forget: this runs on the event loop and
      // must not block startup. `failed` uploads are intentionally left to the
      // user-driven retry flow (they carry a manual retry budget).
      unawaited(recoverInterruptedUploads());
    } catch (e, stackTrace) {
      _isInitialized = false;

      // Log the error but don't rethrow immediately - the helper already retried
      Log.error(
        '❌ Failed to initialize UploadManager after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Send crash report for initialization failure
      await _reporter.sendInitializationFailureCrashReport(e, stackTrace);

      // Don't rethrow - allow the app to continue and retry on demand
      // rethrow;
    }
  }

  /// Get pending uploads visible to the current owner.
  ///
  /// Production providers opt into owner scoping so account switches do not
  /// surface another user's persisted Hive uploads. Tests and maintenance
  /// harnesses that construct [UploadRepository] directly keep the historical
  /// unscoped view unless they pass [scopeUploadsToCurrentUser].
  List<PendingUpload> get pendingUploads => _store.pendingUploads;

  /// Get a specific upload by ID
  PendingUpload? getUpload(String id) => _store.getUpload(id);

  /// Get an upload by file path
  PendingUpload? getUploadByFilePath(String filePath) =>
      _store.getUploadByFilePath(filePath);

  /// Delete all persisted uploads belonging to [ownerPubkey].
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    _purgedUploadOwners.add(ownerPubkey);
    final uploads = _store.uploadsForOwner(ownerPubkey);
    final uploadIds = uploads.map((upload) => upload.id).toSet();

    _retryPolicy.discardUploads(uploadIds);
    for (final uploadId in uploadIds) {
      _userStoppedUploadIds.add(uploadId);
      _reporter.cancelAndRemoveSubscription(uploadId);
      _processingPollTimers.remove(uploadId)?.cancel();
    }

    if (useBackgroundUpload) {
      for (final uploadId in uploadIds) {
        try {
          await _blossomService.cancelBackgroundUpload(uploadId);
        } catch (e) {
          Log.warning(
            'Failed to cancel upload $uploadId during owner cleanup: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      }
    }

    return _store.deleteAllForOwner(ownerPubkey);
  }

  bool _isPurgedOwnerUpload(PendingUpload upload) =>
      _purgedUploadOwners.contains(upload.nostrPubkey);

  /// Finds a reusable upload for the given video file path.
  ///
  /// Returns the most recent upload matching [filePath] that is in a
  /// resumable state (uploading, retrying, processing, readyToPublish,
  /// or failed with a resumable session). Skips published, pending, and
  /// paused uploads.
  ///
  /// Relies on [pendingUploads] being sorted newest-first (by
  /// [PendingUpload.createdAt] descending) so the first match is the
  /// most recent candidate.
  PendingUpload? findReusableUpload(String filePath) =>
      _store.findReusableUpload(filePath);

  /// Start a new video upload.
  Future<PendingUpload> startUpload({
    required File videoFile,
    required String nostrPubkey,
    Duration? thumbnailTimestamp,
    void Function(double)? onProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    NativeProofData? nativeProof,
    String? proofManifestJson,
  }) async {
    // Convert NativeProofData to JSON if present. An explicit
    // [proofManifestJson] (as carried by a draft) wins.
    var resolvedProofManifestJson = proofManifestJson;
    if (resolvedProofManifestJson == null && nativeProof != null) {
      try {
        resolvedProofManifestJson = jsonEncode(nativeProof.toJson());
        Log.info(
          '📜 Native ProofMode data attached to upload',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.error(
          'Failed to serialize NativeProofData: $e',
          name: 'UploadManager',
          category: LogCategory.system,
        );
      }
    }

    return _startUploadInternal(
      videoFile: videoFile,
      nostrPubkey: nostrPubkey,
      title: title,
      description: description,
      hashtags: hashtags,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: videoDuration,
      proofManifestJson: resolvedProofManifestJson,
      onProgress: onProgress,
      thumbnailTimestamp: thumbnailTimestamp,
    );
  }

  /// Internal upload method - handles actual upload logic
  Future<PendingUpload> _startUploadInternal({
    required File videoFile,
    required String nostrPubkey,
    Duration? thumbnailTimestamp,
    void Function(double)? onProgress,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    String? proofManifestJson,
  }) async {
    Log.info(
      '🚀 === STARTING UPLOAD ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Ensure initialization with robust retry
    if (!isInitialized || !_store.isReady) {
      Log.warning(
        'UploadManager not ready, attempting robust initialization...',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      try {
        // Delegate force-reinit to the store.
        await _store.ensureOpen();

        if (_store.isReady) {
          _isInitialized = true;
          Log.info(
            '✅ Robust initialization successful',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } else {
          throw Exception('Box initialization returned null or closed box');
        }
      } catch (e) {
        Log.error(
          '❌ Robust initialization failed: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // Check if circuit breaker is active
        final debugState = _debugStateProvider();
        if (debugState['circuitBreakerActive'] == true) {
          throw Exception(
            'Upload service temporarily unavailable - too many failures. Please try again later.',
          );
        }

        throw Exception(
          'Failed to initialize upload storage after multiple retries: $e',
        );
      }
    }

    Log.info(
      '📁 Video path: ${videoFile.path}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📊 File exists: ${videoFile.existsSync()}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    if (videoFile.existsSync()) {
      Log.info(
        '📊 File size: ${videoFile.lengthSync()} bytes',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    // Validate file format - reject WebM videos (not supported on iOS/macOS)
    final fileName = videoFile.path.toLowerCase();
    if (fileName.endsWith('.webm')) {
      Log.error(
        '❌ WebM format not supported - rejecting upload',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      throw Exception(
        'WebM video format is not supported. Please use MP4 format instead.',
      );
    }
    Log.info(
      '👤 Nostr pubkey: ${pubkeyForLogs(nostrPubkey)}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📝 Title: $title',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '🏷️ Hashtags: $hashtags',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Create pending upload record
    Log.info(
      '📦 Creating PendingUpload record...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Log ProofMode status
    if (proofManifestJson != null && proofManifestJson.isNotEmpty) {
      Log.info(
        '📜 Native ProofMode data attached to upload (${proofManifestJson.length} characters)',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } else {
      Log.info(
        '📜 No native ProofMode data provided to upload',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    final upload = PendingUpload.create(
      localVideoPath: videoFile.path,
      nostrPubkey: nostrPubkey,
      thumbnailPath: thumbnailPath,
      title: title,
      description: description,
      hashtags: hashtags,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      videoDuration: videoDuration,
      proofManifestJson: proofManifestJson,
      thumbnailTimestamp: thumbnailTimestamp ?? _defaultThumbnailTimestamp,
    );
    Log.info(
      '✅ Created upload with ID: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Save to local storage
    Log.info(
      '💾 Saving upload to local storage...',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    await _store.save(upload);
    Log.info(
      '✅ Upload saved to storage',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Start the upload process and WAIT for it to complete
    Log.info(
      '🔄 Starting upload process...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // CRITICAL FIX: Await upload completion before returning
    // This ensures videoId and cdnUrl are populated before publishing
    try {
      await _performUpload(upload, onProgress: onProgress);

      if (_isPurgedOwnerUpload(upload)) {
        throw StateError(
          'Upload was purged during account cleanup: ${upload.id}',
        );
      }

      // Fetch the updated upload with videoId and cdnUrl populated
      final completedUpload = getUpload(upload.id);
      if (completedUpload == null) {
        throw Exception('Upload not found after completion: ${upload.id}');
      }
      if (completedUpload.status == UploadStatus.failed) {
        throw Exception(
          completedUpload.errorMessage ?? 'Upload failed: ${upload.id}',
        );
      }

      Log.info(
        '✅ Upload completed with ID: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return completedUpload;
    } catch (error) {
      Log.error(
        '❌ Upload failed: $error',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Perform upload with circuit breaker and retry logic
  Future<void> _performUpload(
    PendingUpload upload, {
    void Function(double)? onProgress,
  }) async {
    if (_isPurgedOwnerUpload(upload)) return;
    final existing = _inFlightUploads[upload.id];
    if (existing != null) {
      Log.info(
        'Upload ${upload.id} already in flight; joining existing upload',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return existing;
    }

    late final Future<void> uploadFuture;
    uploadFuture = _performUploadInternal(upload, onProgress: onProgress)
        .whenComplete(() {
          if (identical(_inFlightUploads[upload.id], uploadFuture)) {
            _inFlightUploads.remove(upload.id);
          }
        });
    _inFlightUploads[upload.id] = uploadFuture;
    return uploadFuture;
  }

  Future<void> _performUploadInternal(
    PendingUpload upload, {
    void Function(double)? onProgress,
  }) async {
    Log.info(
      '🏃 === PERFORM UPLOAD STARTED ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '🆔 Upload ID: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Web platform uses different upload flow (File picker -> Blob upload)
    if (_isWeb) {
      Log.warning(
        'Web platform upload not yet implemented - skipping',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(
        upload,
        Exception('Web platform uploads not yet implemented'),
        StackTrace.current,
      );
      return;
    }

    final startTime = DateTime.now();
    final videoFile = File(upload.localVideoPath);

    Log.info(
      '📁 Checking video file: ${upload.localVideoPath}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📊 File exists: ${videoFile.existsSync()}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    if (!videoFile.existsSync()) {
      Log.error(
        '❌ VIDEO FILE DOES NOT EXIST!',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(
        upload,
        Exception('Video file not found'),
        StackTrace.current,
      );
      return;
    }

    // Initialize metrics
    final fileSizeMB = videoFile.lengthSync() / (1024 * 1024);
    Log.info(
      '📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    _reporter.recordStart(
      upload.id,
      UploadMetrics(
        uploadId: upload.id,
        startTime: startTime,
        retryCount: upload.retryCount ?? 0,
        fileSizeMB: fileSizeMB,
        wasSuccessful: false,
      ),
    );

    try {
      Log.info(
        '🔁 Starting upload with retry logic...',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _performUploadWithRetry(upload, videoFile, onProgress);
    } catch (e, stackTrace) {
      // A user-initiated cancel tears down the in-flight transfer, which
      // surfaces here as a failure. cancelUpload already wrote the
      // authoritative status, so don't overwrite it or report the stop as a
      // crash — see [_userStoppedUploadIds].
      if (_userStoppedUploadIds.contains(upload.id)) {
        Log.info(
          'Upload ${upload.id} stopped by user; skipping failure handling',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return;
      }
      Log.error(
        '❌ Upload failed: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(upload, e, stackTrace);
    } finally {
      _userStoppedUploadIds.remove(upload.id);
    }
  }

  /// Perform upload with exponential backoff retry using proper async patterns.
  ///
  /// Delegates retry orchestration to [UploadRetryPolicy]. The execute callback
  /// re-fetches the current upload from the store on each attempt so resumable
  /// session updates from prior chunk callbacks are picked up automatically.
  Future<void> _performUploadWithRetry(
    PendingUpload upload,
    File videoFile,
    void Function(double)? onProgress,
  ) async {
    await _retryPolicy.performWithRetry(upload, () async {
      if (_isPurgedOwnerUpload(upload)) return;
      final currentUpload = _store.getUpload(upload.id) ?? upload;
      if (_isPurgedOwnerUpload(currentUpload)) return;

      // Validate file still exists
      if (!videoFile.existsSync()) {
        throw Exception('Video file not found: ${upload.localVideoPath}');
      }

      // Execute upload with timeout
      final result = await _executeUploadWithTimeout(
        currentUpload,
        videoFile,
        onProgress,
      );

      if (_userStoppedUploadIds.contains(upload.id)) {
        Log.info(
          'Upload ${upload.id} stopped by user; skipping success handling',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return;
      }

      // Success - record metrics and complete
      await _handleUploadSuccess(currentUpload, result);
    }, isRetriable: _retryPolicy.isRetriableError);
  }

  /// Execute upload with timeout and progress tracking
  Future<dynamic> _executeUploadWithTimeout(
    PendingUpload upload,
    File videoFile,
    void Function(double)? onProgress,
  ) async {
    // One entry, not five: these describe a single upload attempt, and as
    // separate entries they interleave with other work in the captured log
    // that support reads.
    Log.info(
      '📤 === EXECUTING UPLOAD ===\n'
      '📁 Video: ${videoFile.path}\n'
      '👤 Pubkey: ${pubkeyForLogs(upload.nostrPubkey)}\n'
      '📝 Title: ${upload.title}\n'
      '⏱️ Timeout: ${_retryConfig.networkTimeout.inMinutes} minutes',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Start the thumbnail beside the video transfer rather than after it. It
    // only needs the local file, never the transfer's result, and running it
    // sequentially put 3.2-4.1s of extract + sign + PUT on the critical path
    // for a 16KB payload — a fifth to a quarter of the whole publish. It is
    // reliably the shorter leg (measured against 6.8-16.8s for the video), so
    // it lands before the transfer does and costs nothing extra.
    final thumbnailFuture = _startThumbnailUpload(
      videoFile: videoFile,
      upload: upload,
    );

    try {
      // Use Blossom upload service exclusively
      Log.info(
        '🌸 Using Blossom upload service',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Check if custom server is enabled, otherwise use default Divine server
      final isCustomServerEnabled = await _blossomService.isBlossomEnabled();
      String blossomServer;

      if (isCustomServerEnabled) {
        final customServer = await _blossomService.getBlossomServer();
        if (customServer == null || customServer.isEmpty) {
          throw Exception(
            'Custom Blossom server enabled but not configured. Please configure a server in settings.',
          );
        }
        blossomServer = customServer;
        Log.info(
          '🌸 Uploading to custom Blossom server: $blossomServer',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } else {
        blossomServer = _defaultBlossomUrl;
        Log.info(
          '🌸 Uploading to default Divine Blossom server: $blossomServer',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      // The video transfer owns the bar on its own. The thumbnail runs beside
      // it and deliberately reports nothing: two legs writing progress
      // concurrently would make the bar jump backwards. The reserved top slice
      // covers joining the thumbnail, so the bar never claims 100% while work
      // is still outstanding.
      void reportProgress(double value) {
        final progress = value * videoProgressShare;
        _reporter.updateProgress(upload.id, progress);
        onProgress?.call(progress);
      }

      // Combined upload path: a fresh publish attempts the OS-owned whole-file
      // PUT first (it survives app suspension and is fastest on a healthy
      // connection); on failure, or when a resumable session already exists
      // from a prior attempt, the request falls through to the chunked
      // resumable protocol so retries resume from the server's last committed
      // offset instead of byte 0.
      //
      // The OS transfer applies its own generous safety timeout internally and
      // must NOT be cut by the in-process network timeout — doing so would
      // defeat the suspension survival that is the whole point of the OS path.
      // Only the in-process chunked-resumable leg is bounded by networkTimeout
      // (passed as resumableTimeout), so a stalled socket does not hang
      // forever. `useBackgroundUpload` is the kill-switch for the OS-first
      // attempt: flip it to false to go straight to chunked resumable.
      // Bytes are read before the transfer so the timing line can report
      // throughput even if the file is gone by the time the phase ends.
      final videoBytes = videoFile.existsSync() ? videoFile.lengthSync() : null;
      final transferWatch = Stopwatch()..start();

      BlossomUploadResult result;
      try {
        result = await _blossomService.uploadVideoWithResume(
          videoFile: videoFile,
          nostrPubkey: upload.nostrPubkey,
          taskId: upload.id,
          title: upload.title ?? '',
          description: upload.description,
          hashtags: upload.hashtags,
          proofManifestJson: upload.proofManifestJson,
          useBackgroundFirst: useBackgroundUpload,
          resumableTimeout: _retryConfig.networkTimeout,
          resumableSession: upload.resumableSession,
          onResumableSessionUpdated: (session) {
            _retryPolicy.enqueueSessionPersist(
              upload.id,
              session,
              videoFile.lengthSync(),
            );
          },
          onProgress: reportProgress,
        );
      } on TimeoutException catch (_) {
        Log.error(
          '⏱️ Upload timed out!',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        final timeoutError = TimeoutException(
          'Upload timed out after '
          '${_retryConfig.networkTimeout.inMinutes} minutes',
        );

        // Send timeout crash report asynchronously
        _reporter.sendTimeoutCrashReport(upload, timeoutError).catchError((e) {
          Log.error(
            'Failed to send timeout crash report: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        });

        rethrow;
      } finally {
        transferWatch.stop();
        _telemetry(
          UploadPhases.uploadTransfer,
          transferWatch.elapsed,
          bytes: videoBytes,
        );
      }

      // Join the parallel leg before any early return below, so it can never
      // outlive this call.
      final thumbnailResult = await thumbnailFuture;
      final thumbnailCdnUrl = thumbnailResult.cdnUrl;

      if (_userStoppedUploadIds.contains(upload.id)) {
        Log.info(
          'Upload ${upload.id} stopped by user after video transfer; '
          'skipping success handling',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return result;
      }

      if (result.success && result.cdnUrl != null) {
        Log.info(
          '✅ Video uploaded successfully',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        if (thumbnailCdnUrl != null) {
          Log.info(
            '✅ Thumbnail uploaded to CDN: $thumbnailCdnUrl',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } else {
          Log.error(
            '❌ Failed to upload required thumbnail to CDN',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      }

      if (result.success &&
          !_hasHttpThumbnailUrl(
            result: result,
            generatedThumbnailUrl: thumbnailCdnUrl,
            existingThumbnailUrl: upload.thumbnailPath,
          )) {
        throw StateError('Thumbnail upload failed');
      }

      if (result.success) {
        _reporter.updateProgress(upload.id, 1.0);
        onProgress?.call(1.0);
      }

      Log.info(
        '✅ Upload execution completed',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return result;
    } catch (e) {
      // A transfer failure must not strand the parallel thumbnail leg: settle
      // it before propagating so it cannot still be running when the retry
      // policy starts the next attempt. [_startThumbnailUpload] guarantees it
      // never throws, so this cannot mask the original error.
      await thumbnailFuture;
      Log.error(
        '❌ Upload execution failed: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Handle successful upload
  Future<void> _handleUploadSuccess(
    PendingUpload upload,
    dynamic result,
  ) async {
    final endTime = DateTime.now();
    final metrics = _reporter.metricsFor(upload.id);

    if (result.success == true) {
      if (_isPurgedOwnerUpload(upload)) return;
      if (_userStoppedUploadIds.contains(upload.id)) {
        Log.info(
          'Upload ${upload.id} stopped by user; ignoring late success result',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return;
      }

      // Get the LATEST upload record from Hive (may have been updated with thumbnail URL)
      final latestUpload = getUpload(upload.id) ?? upload;
      if (_isPurgedOwnerUpload(latestUpload)) return;

      // Create updated upload with success metadata
      final updatedUpload = createSuccessfulUpload(latestUpload, result);
      await _store.update(updatedUpload);

      // Record successful metrics
      if (metrics != null) {
        final updatedMetrics = _reporter.createSuccessMetrics(
          metrics,
          endTime,
          upload.retryCount ?? 0,
        );
        _reporter.recordSuccess(upload.id, updatedMetrics);

        // Log success with formatted output
        _reporter.logUploadSuccess(result, updatedMetrics);
      }

      // If upload is in processing state, start polling for completion
      if (updatedUpload.status == UploadStatus.processing) {
        startProcessingPoll(updatedUpload);
      }
    } else {
      throw BlossomUploadFailureException(
        (result.errorMessage as String?) ?? 'Upload failed with unknown error',
        statusCode: result.statusCode as int?,
        failureReason: result.failureReason as BlossomUploadFailureReason?,
      );
    }
  }

  /// Handle upload failure with comprehensive crash reporting
  Future<void> _handleUploadFailure(
    PendingUpload upload,
    Object error,
    StackTrace stackTrace,
  ) async {
    final endTime = DateTime.now();
    final metrics = _reporter.metricsFor(upload.id);
    final latestUpload = getUpload(upload.id) ?? upload;
    if (_isPurgedOwnerUpload(latestUpload)) return;

    // Check network connectivity and categorize error
    final connectivity = await _reporter.checkNetworkConnectivity();
    final errorCategory = await _reporter.categorizeError(error);
    final userMessage = UploadProgressReporter.userFriendlyErrorMessage(
      errorCategory,
      connectivity,
    );

    Log.error(
      'Upload failed for ${upload.id}: $error',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'Error category: $errorCategory',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'Network: ${UploadProgressReporter.networkTypeString(connectivity)}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'User message: $userMessage',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Send comprehensive crash report to Crashlytics with network state
    await _reporter.sendUploadFailureCrashReport(
      upload,
      error,
      errorCategory,
      metrics,
      connectivity,
      stackTrace: stackTrace,
      isManagerInitialized: _isInitialized,
    );

    // Store user-friendly error message instead of raw exception
    await _store.update(
      latestUpload.copyWith(
        status: UploadStatus.failed,
        errorMessage: userMessage,
        retryCount: latestUpload.retryCount ?? 0,
        resumableSession: isExpiredResumableSessionError(error)
            ? null
            : latestUpload.resumableSession,
      ),
    );

    // Record failure metrics
    if (metrics != null) {
      _reporter.recordFailure(
        upload.id,
        UploadMetrics(
          uploadId: upload.id,
          startTime: metrics.startTime,
          endTime: endTime,
          uploadDuration: endTime.difference(metrics.startTime),
          retryCount: latestUpload.retryCount ?? 0,
          fileSizeMB: metrics.fileSizeMB,
          errorCategory: errorCategory,
          wasSuccessful: false,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Thin delegators for moved methods (keep @visibleForTesting annotations)
  // ---------------------------------------------------------------------------

  /// Delegates to [UploadRetryPolicy.isRetriableError].
  @visibleForTesting
  bool isRetriableError(dynamic error) => _retryPolicy.isRetriableError(error);

  /// Delegates to [UploadProgressReporter.categorizeError].
  @visibleForTesting
  Future<String> categorizeError(dynamic error) =>
      _reporter.categorizeError(error);

  /// Retry a failed upload. Delegates to [UploadRetryPolicy.retryUpload].
  Future<void> retryUpload(String uploadId) async {
    await _retryPolicy.retryUpload(uploadId, performUpload: _performUpload);
  }

  /// Resumes a single interrupted upload.
  ///
  /// For uploads left in [UploadStatus.uploading] or
  /// [UploadStatus.retrying] after an app restart. Delegates to
  /// [UploadRetryPolicy.resumeInterruptedUpload].
  void resumeInterruptedUpload(String uploadId) {
    _retryPolicy.resumeInterruptedUpload(
      uploadId,
      performUpload: _performUpload,
    );
  }

  // ============================================================
  // Background recovery
  // ============================================================

  /// Recovers uploads stuck in [UploadStatus.uploading] or
  /// [UploadStatus.retrying] after a crash, force-quit, or suspended retry
  /// backoff.
  ///
  /// iOS suspends the app on background and Dart [Timer]s do not fire while
  /// suspended. If an upload is still alive but parked in retry backoff, the
  /// sweep wakes that wait so the existing [_performUpload] future continues.
  /// If no live future exists, the sweep re-drives the persisted row.
  ///
  /// Only `uploading`/`retrying` are re-driven — those states are
  /// unambiguously interrupted and have consumed no manual-retry budget.
  /// `failed` uploads are left to the user-driven retry flow (they carry a
  /// `retryCount < 3` budget surfaced via the publish bottom sheet).
  ///
  /// Called once at startup and by the app facade on resume. Re-entrancy is
  /// guarded by [_isRecovering].
  Future<void> recoverInterruptedUploads() async {
    if (_isRecovering) return;
    if (!_isInitialized || !_store.isReady) return;
    _isRecovering = true;
    try {
      final stuck = _store.pendingUploads
          .where(
            (u) =>
                u.status == UploadStatus.uploading ||
                u.status == UploadStatus.retrying,
          )
          .toList();

      if (stuck.isEmpty) return;

      var recovered = 0;
      var wokeBackoff = 0;
      var markedMissingFile = 0;
      for (final upload in stuck) {
        if (_inFlightUploads.containsKey(upload.id)) {
          if (_retryPolicy.wakeBackoff(upload.id)) {
            wokeBackoff++;
          }
          continue;
        }
        // A user just paused/cancelled; leave the authoritative status alone.
        if (_userStoppedUploadIds.contains(upload.id)) continue;
        if (_isPurgedOwnerUpload(upload)) continue;

        if (!File(upload.localVideoPath).existsSync()) {
          // The source file is gone (e.g. temp cleared by the OS), so resume
          // is impossible — mark it failed so the publish flow can tell the
          // user instead of silently spinning.
          await _store.update(
            upload.copyWith(
              status: UploadStatus.failed,
              errorMessage:
                  'Video file missing after restart: '
                  '${upload.localVideoPath}',
            ),
          );
          markedMissingFile++;
          continue;
        }

        resumeInterruptedUpload(upload.id);
        recovered++;
      }

      Log.info(
        '🔄 Recovery sweep: re-drove $recovered stuck upload(s), '
        'woke $wokeBackoff retry backoff wait(s), '
        'marked $markedMissingFile failed (missing file), '
        'skipped ${stuck.length - recovered - wokeBackoff - markedMissingFile} active',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } finally {
      _isRecovering = false;
    }
  }

  /// Cancel an upload (stops the upload but keeps it for retry)
  Future<void> cancelUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;

    Log.debug(
      'Cancelling upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Only mark an in-flight transfer: tearing it down emits a terminal event
    // that would otherwise reach [_handleUploadFailure] and report a spurious
    // failure for this user-initiated cancel. A marker for an already-terminal
    // upload would never be cleared (no [_performUpload] run owns it).
    final isInFlight =
        upload.status == UploadStatus.uploading ||
        upload.status == UploadStatus.retrying;
    if (isInFlight) {
      _userStoppedUploadIds.add(uploadId);
    }

    // Stop the OS-owned background transfer if this upload used one; the
    // in-process path is torn down by its request timeout. Without this the OS
    // keeps uploading a video the user already cancelled.
    if (useBackgroundUpload) {
      await _blossomService.cancelBackgroundUpload(uploadId);
    }

    // Update status to failed so it can be retried later
    final cancelledUpload = upload.copyWith(
      status: UploadStatus.failed,
      errorMessage: 'Upload cancelled by user',
    );

    await _store.update(cancelledUpload);

    // Cancel progress subscription
    _reporter.cancelAndRemoveSubscription(uploadId);

    Log.warning(
      'Upload cancelled and available for retry: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Remove completed, published, or unrecoverable failed uploads.
  Future<void> cleanupCompletedUploads() async {
    await _cleanupTransientRendersForDiscardedUploads();
    await _store.cleanupCompletedUploads();
  }

  /// Update upload status (public method for VideoEventPublisher)
  Future<void> updateUploadStatus(
    String uploadId,
    UploadStatus status, {
    String? nostrEventId,
  }) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.warning(
        'Upload not found for status update: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    final updatedUpload = upload.copyWith(
      status: status,
      nostrEventId: nostrEventId ?? upload.nostrEventId,
      completedAt: status == UploadStatus.published
          ? DateTime.now()
          : upload.completedAt,
    );

    await _store.update(updatedUpload);
    if (status == UploadStatus.published) {
      await _cleanupTransientRendersForUpload(uploadId);
    }
    Log.info(
      'Updated upload status: $uploadId -> $status',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Records transient editor renders produced for [uploadId] so they are
  /// reaped once the upload is published or discarded.
  ///
  /// Produced by `DraftUploadMaterializer`; the upload pipeline owns only the
  /// bookkeeping, not the cleanup policy (see [TransientRenderCleaner]).
  void registerTransientRenderPaths(String uploadId, Set<String> paths) {
    if (paths.isEmpty) return;
    _transientRenderPathsByUploadId[uploadId] = paths;
  }

  Future<void> _cleanupTransientRendersForUpload(String uploadId) async {
    final paths = _transientRenderPathsByUploadId.remove(uploadId);
    if (paths == null) {
      final upload = getUpload(uploadId);
      if (upload != null &&
          _transientRenderCleaner.isMaterializedOutputPath(
            upload.localVideoPath,
          )) {
        await _transientRenderCleaner.cleanupMaterializedOutputPath(
          upload.localVideoPath,
        );
      }
      return;
    }
    for (final path in paths) {
      await _transientRenderCleaner.cleanupMaterializedOutputPath(path);
    }
  }

  Future<void> _cleanupTransientRendersForDiscardedUploads() async {
    for (final upload in pendingUploads) {
      if (upload.status != UploadStatus.failed ||
          upload.resumableSession != null ||
          !_transientRenderCleaner.isMaterializedOutputPath(
            upload.localVideoPath,
          )) {
        continue;
      }
      await _transientRenderCleaner.cleanupMaterializedOutputPath(
        upload.localVideoPath,
      );
    }
  }

  /// Get upload statistics
  Map<String, int> get uploadStats => _store.uploadStats;

  /// Fix uploads stuck in readyToPublish without proper data (debug method)
  Future<void> cleanupProblematicUploads() =>
      _store.cleanupProblematicUploads();

  /// Delegates to [UploadProgressReporter.getPerformanceMetrics].
  Map<String, dynamic> getPerformanceMetrics() =>
      _reporter.getPerformanceMetrics();

  /// Create successful upload with metadata.
  ///
  /// Visible for testing so the thumbnail-precedence contract — a custom
  /// cover already uploaded onto [upload] wins over the server-derived
  /// poster carried by [result] — can be exercised directly.
  @visibleForTesting
  PendingUpload createSuccessfulUpload(PendingUpload upload, dynamic result) {
    final resultThumbnailUrl = _resultThumbnailUrl(result);

    final existingThumbnailUrl = upload.thumbnailPath;
    // Prefer the custom cover we uploaded from the user's chosen frame
    // (already stored on the upload) over the server's derived poster —
    // otherwise a picked cover is silently replaced by {videoHash}.jpg.
    String? thumbnailUrl;
    if (_isHttpUrl(existingThumbnailUrl)) {
      thumbnailUrl = existingThumbnailUrl;
    } else if (_isHttpUrl(resultThumbnailUrl)) {
      thumbnailUrl = resultThumbnailUrl;
    }

    if (resultThumbnailUrl != null && !_isHttpUrl(resultThumbnailUrl)) {
      Log.error(
        '⚠️ thumbnailUrl is not an HTTP URL: $resultThumbnailUrl',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    Log.info(
      '📸 Upload result type: ${result.runtimeType}',
      name: 'UploadManager',
      category: LogCategory.system,
    );
    Log.info(
      '📸 Upload result thumbnail URL: $resultThumbnailUrl',
      name: 'UploadManager',
      category: LogCategory.system,
    );
    Log.info(
      '📸 Storing thumbnail URL in PendingUpload: $thumbnailUrl',
      name: 'UploadManager',
      category: LogCategory.system,
    );

    // Check if video is still processing (Blossom 202 response)
    final isProcessing = result.errorMessage == 'processing';

    // For Cloudflare Stream integration via Blossom, we have the final CDN URLs immediately
    // Skip processing state since cdn.divine.video URLs are available right away
    final skipProcessing = isProcessing && result.cdnUrl != null;

    if (skipProcessing) {
      Log.info(
        '🎬 Skipping processing state - CDN URL already available: ${result.cdnUrl}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    // Validate all URLs are HTTP/HTTPS before storing
    // This prevents local file paths from being persisted and later published
    String? validatedCdnUrl = result.cdnUrl as String?;
    String? validatedStreamingMp4 = result.streamingMp4Url as String?;
    String? validatedStreamingHls = result.streamingHlsUrl as String?;
    String? validatedFallback = result.fallbackUrl as String?;

    if (validatedCdnUrl != null && !_isHttpUrl(validatedCdnUrl)) {
      Log.error(
        '⚠️ cdnUrl is not an HTTP URL (possible local path): $validatedCdnUrl',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedCdnUrl = null;
    }
    if (validatedStreamingMp4 != null && !_isHttpUrl(validatedStreamingMp4)) {
      Log.error(
        '⚠️ streamingMp4Url is not an HTTP URL: $validatedStreamingMp4',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedStreamingMp4 = null;
    }
    if (validatedStreamingHls != null && !_isHttpUrl(validatedStreamingHls)) {
      Log.error(
        '⚠️ streamingHlsUrl is not an HTTP URL: $validatedStreamingHls',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedStreamingHls = null;
    }
    if (validatedFallback != null && !_isHttpUrl(validatedFallback)) {
      Log.error(
        '⚠️ fallbackUrl is not an HTTP URL: $validatedFallback',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      validatedFallback = null;
    }

    return upload.copyWith(
      status: (isProcessing && !skipProcessing)
          ? UploadStatus.processing
          : UploadStatus.readyToPublish,
      cloudinaryPublicId:
          result.videoId as String?, // Use videoId for existing systems
      videoId:
          result.videoId as String?, // Store videoId for new publishing system
      cdnUrl: validatedCdnUrl, // Store CDN URL (validated HTTP only)
      streamingMp4Url: validatedStreamingMp4, // Store BunnyStream MP4 URL
      streamingHlsUrl: validatedStreamingHls, // Store BunnyStream HLS URL
      fallbackUrl: validatedFallback, // Store R2 fallback MP4 URL
      thumbnailPath: thumbnailUrl, // Store thumbnail URL
      uploadProgress: (isProcessing && !skipProcessing)
          ? 0.9
          : 1.0, // Skip processing = 100% ready
      completedAt: (isProcessing && !skipProcessing)
          ? null
          : DateTime.now(), // Mark as completed if skipping processing
      resumableSession: null,
    );
  }

  /// Check if a URL is a valid HTTP/HTTPS URL (not a local file path)
  static bool _isHttpUrl(String? url) {
    final value = url?.trim();
    if (value == null || value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  static String? _resultThumbnailUrl(dynamic result) {
    try {
      return result.thumbnailUrl as String?;
    } catch (_) {
      return null;
    }
  }

  static bool _hasHttpThumbnailUrl({
    required dynamic result,
    required String? generatedThumbnailUrl,
    required String? existingThumbnailUrl,
  }) {
    return _isHttpUrl(_resultThumbnailUrl(result)) ||
        _isHttpUrl(generatedThumbnailUrl) ||
        _isHttpUrl(existingThumbnailUrl);
  }

  /// Runs the thumbnail leg for [upload], or short-circuits when a previous
  /// attempt already landed one on the CDN.
  ///
  /// Never throws: [_generateAndUploadThumbnail] reports failure as `null` and
  /// the persist swallows its own errors, so the caller turns a missing
  /// thumbnail into the publish-level error. That matters here because this
  /// future is started before the video transfer and awaited after it — an
  /// escaping error would spend the whole transfer with no listener, and would
  /// then replace the transfer's own failure at the join.
  Future<ThumbnailLegResult> _startThumbnailUpload({
    required File videoFile,
    required PendingUpload upload,
  }) async {
    final existing = upload.thumbnailPath;
    if (existing != null && existing.startsWith('http')) {
      // A prior attempt in this retry chain already uploaded it. The blob is
      // content-addressed, so re-uploading would land on the same hash. The
      // zero-duration line keeps the PUBTIME timeline honest on retries —
      // without it an export reads as "the leg never ran".
      _telemetry(
        UploadPhases.uploadThumbnail,
        Duration.zero,
        detail: UploadPhases.reusedDetail,
      );
      return (cdnUrl: existing, blurhash: upload.blurhash);
    }

    final watch = Stopwatch()..start();
    try {
      final result = await _generateAndUploadThumbnail(
        videoFile: videoFile,
        nostrPubkey: upload.nostrPubkey,
        upload: upload,
      );

      // Persist as soon as the leg lands, not once the whole attempt
      // succeeds. A failing video transfer aborts this method's caller before
      // its own store write, so deferring would make every retry re-extract
      // and re-upload a thumbnail that is already on the CDN — and the
      // short-circuit above would never fire.
      if (result.cdnUrl != null || result.blurhash != null) {
        try {
          final current = _store.getUpload(upload.id) ?? upload;
          if (_isPurgedOwnerUpload(current)) return result;
          await _store.update(
            current.copyWith(
              thumbnailPath: result.cdnUrl ?? current.thumbnailPath,
              blurhash: result.blurhash,
            ),
          );
        } catch (e) {
          // The persist is an optimization — without it the next attempt just
          // re-extracts. A closed box or a full disk must not escape: this
          // future is unlistened for the length of the transfer, so it would
          // surface as an uncaught error, and at the join it would replace the
          // transfer's real failure with a storage one.
          Log.error(
            'Failed to persist thumbnail result for ${upload.id}: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      }

      return result;
    } finally {
      watch.stop();
      _telemetry(UploadPhases.uploadThumbnail, watch.elapsed);
    }
  }

  /// Extracts a thumbnail from [videoFile], uploads it to Blossom, and derives
  /// the blurhash from the same decoded frame.
  ///
  /// Reports no progress: it runs in parallel with the video transfer, which
  /// owns the bar alone. See [videoProgressShare].
  Future<ThumbnailLegResult> _generateAndUploadThumbnail({
    required File videoFile,
    required String nostrPubkey,
    required PendingUpload upload,
  }) async {
    try {
      Log.info(
        '📸 Extracting thumbnail from video: ${videoFile.path}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Generate thumbnail at optimal timestamp
      final extractWatch = Stopwatch()..start();
      final thumbnailExtraction = await _extractThumbnail(
        videoPath: videoFile.path,
        quality: 85,
        targetTimestamp:
            upload.thumbnailTimestamp ?? _defaultThumbnailTimestamp,
      );
      extractWatch.stop();
      _telemetry(UploadPhases.uploadThumbnailExtract, extractWatch.elapsed);

      if (thumbnailExtraction == null) {
        Log.warning(
          '❌ Failed to extract thumbnail from video',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return (cdnUrl: null, blurhash: null);
      }

      final thumbnailFile = File(thumbnailExtraction.path);
      if (!thumbnailFile.existsSync()) {
        Log.warning(
          '❌ Thumbnail file not found after extraction',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return (cdnUrl: null, blurhash: null);
      }

      Log.info(
        '✅ Thumbnail extracted, uploading to Blossom server',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Derive the blurhash from the frame we just decoded. Publishing used to
      // decode the video a second time for this, on the critical path.
      final blurhashWatch = Stopwatch()..start();
      final blurhash = await _blurhashGenerator(
        thumbnailFile.readAsBytesSync(),
      );
      blurhashWatch.stop();
      _telemetry(UploadPhases.uploadThumbnailBlurhash, blurhashWatch.elapsed);

      // Upload thumbnail to Blossom server. Divine relay publishing requires
      // a CDN thumbnail, so keep the image upload's own retry enabled here.
      // If no HTTP thumbnail URL is available after that, the outer video
      // pipeline treats it as terminal to avoid re-uploading the whole video.
      final thumbnailBytes = thumbnailFile.lengthSync();
      final putWatch = Stopwatch()..start();
      final uploadResult = await _blossomService.uploadImage(
        imageFile: thumbnailFile,
        nostrPubkey: nostrPubkey,
        // A thumbnail is a few KB — a single PUT avoids the resumable
        // init/chunk/complete handshake (two extra round-trips plus extra auth
        // signings) that otherwise dominated short-clip publish time.
        allowResumable: false,
      );
      putWatch.stop();
      _telemetry(
        UploadPhases.uploadThumbnailPut,
        putWatch.elapsed,
        bytes: thumbnailBytes,
      );

      // Clean up local thumbnail file
      try {
        await thumbnailFile.delete();
        Log.debug(
          '🧹 Cleaned up local thumbnail file',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          'Failed to clean up thumbnail file: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      if (uploadResult.success && uploadResult.cdnUrl != null) {
        return (cdnUrl: uploadResult.cdnUrl, blurhash: blurhash);
      }

      return (cdnUrl: null, blurhash: blurhash);
    } catch (e) {
      Log.error(
        'Error generating/uploading thumbnail: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return (cdnUrl: null, blurhash: null);
    }
  }

  void dispose() {
    // Delegate to extracted policy/reporter (handles subscriptions, timers,
    // session futures, and metrics cleanup).
    _retryPolicy.dispose();
    _reporter.dispose();

    // Cancel all processing-completion polls
    for (final timer in _processingPollTimers.values) {
      timer.cancel();
    }
    _processingPollTimers.clear();

    // Delegate storage teardown (timer, queue, box pointer) to the store.
    _store.disposeStore();
    _isInitialized = false;

    Log.info(
      'UploadManager disposed',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Start polling for processing upload completion.
  ///
  /// Visible for testing so the timer lifecycle (cancellation on
  /// completion, timeout, and [dispose]) can be exercised directly.
  @visibleForTesting
  void startProcessingPoll(PendingUpload upload) {
    Log.info(
      '🔄 Starting processing poll for upload: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    void stopPoll(Timer timer) {
      timer.cancel();
      if (identical(_processingPollTimers[upload.id], timer)) {
        _processingPollTimers.remove(upload.id);
      }
    }

    // Poll every 10 seconds for up to 5 minutes
    _processingPollTimers[upload.id]?.cancel();
    _processingPollTimers[upload.id] = Timer.periodic(
      const Duration(seconds: 10),
      (timer) async {
        try {
          // Check if upload still exists and is still processing
          final currentUpload = getUpload(upload.id);
          if (currentUpload == null ||
              currentUpload.status != UploadStatus.processing) {
            stopPoll(timer);
            return;
          }

          // Check processing status using Blossom service
          final isReady = await _checkVideoProcessingStatus(currentUpload);
          if (isReady) {
            // Update upload to ready state
            final readyUpload = currentUpload.copyWith(
              status: UploadStatus.readyToPublish,
              uploadProgress: 1.0,
              completedAt: DateTime.now(),
            );
            await _store.update(readyUpload);

            Log.info(
              '✅ Video processing complete: ${upload.id}',
              name: 'UploadManager',
              category: LogCategory.video,
            );
            stopPoll(timer);
          }
        } catch (e) {
          Log.warning(
            'Error checking processing status: $e',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }

        // Cancel after 5 minutes to avoid infinite polling
        if (timer.tick > 30) {
          // 30 * 10 seconds = 5 minutes
          stopPoll(timer);
          Log.warning(
            'Processing poll timeout for upload: ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }
      },
    );
  }

  /// Check if video processing is complete
  Future<bool> _checkVideoProcessingStatus(PendingUpload upload) async {
    if (upload.videoId == null) return false;

    // Use Blossom service to check video status
    final serverUrl = await _blossomService.getBlossomServer();
    if (serverUrl == null) return false;

    try {
      // For Cloudflare Stream integration, try status endpoint first
      final statusResponse = await _dio.get(
        '$serverUrl/status/${upload.videoId}',
      );

      if (statusResponse.statusCode == 200) {
        Log.info(
          '📹 Video processing complete via status endpoint',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return true;
      }
    } catch (statusError) {
      Log.info(
        'Status endpoint not available, trying blob descriptor: $statusError',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Fallback to blob descriptor endpoint
      try {
        final response = await _dio.get('$serverUrl/${upload.videoId}');

        // If we get 200, the video is ready with full metadata
        if (response.statusCode == 200) {
          Log.info(
            '📹 Video processing complete, full metadata available',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          return true;
        }

        // If still 202, keep polling
        if (response.statusCode == 202) {
          Log.info(
            '🔄 Video still processing...',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          return false;
        }

        return false;
      } catch (e) {
        Log.warning(
          'Error checking video status: $e',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // For Cloudflare Stream, assume it's ready after a few attempts
        // since CF Stream processes very quickly (usually < 30 seconds)
        Log.info(
          '⚡ Assuming Cloudflare Stream video is ready due to polling errors',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return true;
      }
    }

    return false;
  }
}
