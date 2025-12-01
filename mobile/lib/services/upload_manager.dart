// ABOUTME: Service for managing video upload state and local persistence
// ABOUTME: Handles upload queue, retries, and coordination between UI and Blossom upload service

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/circuit_breaker_service.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Get platform name for logging (web-safe)
String _getPlatformName() {
  if (kIsWeb) return 'web';
  try {
    return Platform.operatingSystem;
  } catch (_) {
    return 'unknown';
  }
}

/// Upload retry configuration
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
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

/// Upload performance metrics
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UploadMetrics {
  const UploadMetrics({
    required this.uploadId,
    required this.startTime,
    required this.retryCount,
    required this.fileSizeMB,
    required this.wasSuccessful,
    this.endTime,
    this.uploadDuration,
    this.throughputMBps,
    this.errorCategory,
  });
  final String uploadId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? uploadDuration;
  final int retryCount;
  final double fileSizeMB;
  final double? throughputMBps;
  final String? errorCategory;
  final bool wasSuccessful;
}

/// Upload target options

/// Manages video uploads and their persistent state with enhanced reliability
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class UploadManager {
  UploadManager({
    required BlossomUploadService blossomService,
    VideoCircuitBreaker? circuitBreaker,
    UploadRetryConfig? retryConfig,
  }) : _blossomService = blossomService,
       _circuitBreaker = circuitBreaker ?? VideoCircuitBreaker(),
       _retryConfig = retryConfig ?? const UploadRetryConfig();
  // Removed unused _uploadsBoxName constant
  static const String _uploadTargetKey = 'upload_target';

  // Core services
  Box<PendingUpload>? _uploadsBox;
  final BlossomUploadService _blossomService;
  final VideoCircuitBreaker _circuitBreaker;
  final UploadRetryConfig _retryConfig;
  final Dio _dio = Dio();

  // State tracking
  final Map<String, StreamSubscription<double>> _progressSubscriptions = {};
  final Map<String, UploadMetrics> _uploadMetrics = {};
  final Map<String, Timer> _retryTimers = {};

  bool _isInitialized = false;

  /// Check if the upload manager is initialized
  bool get isInitialized => _isInitialized && _uploadsBox != null;

  /// Set the upload target (deprecated - only Blossom uploads supported)
  @Deprecated('Only Blossom uploads are supported')
  Future<void> setUploadTarget(dynamic target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uploadTargetKey, target.index);
    Log.info(
      'Upload target set to: ${target.name}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Check if Blossom is available and configured
  Future<bool> isBlossomAvailable() async {
    return await _blossomService.isBlossomEnabled();
  }

  /// Initialize the upload manager and load persisted uploads
  /// Uses robust initialization with retry logic and recovery strategies
  Future<void> initialize() async {
    if (_isInitialized && _uploadsBox != null && _uploadsBox!.isOpen) {
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
      // Use the robust initialization helper
      _uploadsBox = await UploadInitializationHelper.initializeUploadsBox(
        forceReinit: !_isInitialized,
      );

      if (_uploadsBox == null || !_uploadsBox!.isOpen) {
        throw Exception(
          'Failed to initialize uploads box after all recovery attempts',
        );
      }

      _isInitialized = true;

      Log.info(
        '✅ UploadManager initialized successfully with ${_uploadsBox!.length} existing uploads',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Clean up any problematic uploads first
      await cleanupProblematicUploads();

      // Resume any interrupted uploads
      await _resumeInterruptedUploads();
    } catch (e, stackTrace) {
      _isInitialized = false;
      _uploadsBox = null;

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
      await _sendInitializationFailureCrashReport(e, stackTrace);

      // Don't rethrow - allow the app to continue and retry on demand
      // rethrow;
    }
  }

  /// Get all pending uploads
  List<PendingUpload> get pendingUploads {
    if (_uploadsBox == null) return [];
    return _uploadsBox!.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  /// Get uploads by status
  List<PendingUpload> getUploadsByStatus(UploadStatus status) =>
      pendingUploads.where((upload) => upload.status == status).toList();

  /// Get a specific upload by ID
  PendingUpload? getUpload(String id) => _uploadsBox?.get(id);

  /// Get an upload by file path
  PendingUpload? getUploadByFilePath(String filePath) {
    try {
      return pendingUploads.firstWhere(
        (upload) => upload.localVideoPath == filePath,
      );
    } catch (e) {
      return null;
    }
  }

  /// Update an upload's status to published with Nostr event ID
  Future<void> markUploadPublished(String uploadId, String nostrEventId) async {
    final upload = getUpload(uploadId);
    if (upload != null) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.published,
        nostrEventId: nostrEventId,
        completedAt: DateTime.now(),
      );

      await _updateUpload(updatedUpload);
      Log.info(
        'Upload marked as published: $uploadId -> $nostrEventId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } else {
      Log.warning(
        'Could not find upload to mark as published: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Update an upload's status to ready for publishing
  Future<void> markUploadReadyToPublish(
    String uploadId,
    String cloudinaryPublicId,
  ) async {
    final upload = getUpload(uploadId);
    if (upload != null) {
      final updatedUpload = upload.copyWith(
        status: UploadStatus.readyToPublish,
        cloudinaryPublicId: cloudinaryPublicId,
      );

      await _updateUpload(updatedUpload);
      Log.debug(
        'Upload marked as ready to publish: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Get uploads that are ready for background processing
  List<PendingUpload> get uploadsReadyForProcessing =>
      getUploadsByStatus(UploadStatus.processing);

  /// Start upload from VineDraft (preferred method - single source of truth)
  Future<PendingUpload> startUploadFromDraft({
    required VineDraft draft,
    required String nostrPubkey,
    Duration? videoDuration,
  }) async {
    Log.info(
      '🚀 === STARTING UPLOAD FROM DRAFT ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📜 Draft ID: ${draft.id}, hasProofMode: ${draft.hasProofMode}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    if (draft.hasProofMode) {
      Log.info(
        '📜 Native ProofMode JSON length: ${draft.proofManifestJson?.length ?? 0} characters',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    return _startUploadInternal(
      videoFile: draft.videoFile,
      nostrPubkey: nostrPubkey,
      title: draft.title,
      description: draft.description,
      hashtags: draft.hashtags,
      videoDuration: videoDuration,
      proofManifestJson: draft.proofManifestJson,
    );
  }

  /// Start a new video upload (legacy method - prefer startUploadFromDraft)
  Future<PendingUpload> startUpload({
    required File videoFile,
    required String nostrPubkey,
    String? thumbnailPath,
    String? title,
    String? description,
    List<String>? hashtags,
    int? videoWidth,
    int? videoHeight,
    Duration? videoDuration,
    NativeProofData? nativeProof,
  }) async {
    Log.warning(
      '⚠️ Using legacy startUpload() - prefer startUploadFromDraft()',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Convert NativeProofData to JSON if present
    String? proofManifestJson;
    if (nativeProof != null) {
      try {
        proofManifestJson = jsonEncode(nativeProof.toJson());
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
      proofManifestJson: proofManifestJson,
    );
  }

  /// Internal upload method - handles actual upload logic
  Future<PendingUpload> _startUploadInternal({
    required File videoFile,
    required String nostrPubkey,
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
    if (!isInitialized || _uploadsBox == null || !_uploadsBox!.isOpen) {
      Log.warning(
        'UploadManager not ready, attempting robust initialization...',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      try {
        // Use the robust helper directly for immediate retry
        _uploadsBox = await UploadInitializationHelper.initializeUploadsBox(
          forceReinit: true,
        );

        if (_uploadsBox != null && _uploadsBox!.isOpen) {
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
        final debugState = UploadInitializationHelper.getDebugState();
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
      '👤 Nostr pubkey: $nostrPubkey',
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
    await _saveUpload(upload);
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
      await _performUpload(upload);

      // Fetch the updated upload with videoId and cdnUrl populated
      final completedUpload = getUpload(upload.id);
      if (completedUpload == null) {
        throw Exception('Upload not found after completion: ${upload.id}');
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
  Future<void> _performUpload(PendingUpload upload) async {
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
    if (kIsWeb) {
      Log.warning(
        'Web platform upload not yet implemented - skipping',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(
        upload,
        Exception('Web platform uploads not yet implemented'),
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
      await _handleUploadFailure(upload, Exception('Video file not found'));
      return;
    }

    // Initialize metrics
    final fileSizeMB = videoFile.lengthSync() / (1024 * 1024);
    Log.info(
      '📊 File size: ${fileSizeMB.toStringAsFixed(2)} MB',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    _uploadMetrics[upload.id] = UploadMetrics(
      uploadId: upload.id,
      startTime: startTime,
      retryCount: upload.retryCount ?? 0,
      fileSizeMB: fileSizeMB,
      wasSuccessful: false,
    );

    try {
      Log.info(
        '🔁 Starting upload with retry logic...',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _performUploadWithRetry(upload, videoFile);
    } catch (e) {
      Log.error(
        '❌ Upload failed: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      await _handleUploadFailure(upload, e);
    }
  }

  /// Perform upload with exponential backoff retry using proper async patterns
  Future<void> _performUploadWithRetry(
    PendingUpload upload,
    File videoFile,
  ) async {
    try {
      await AsyncUtils.retryWithBackoff(
        operation: () async {
          // NOTE: Circuit breaker removed from upload flow - it was blocking legitimate retries
          // Uploads already have proper retry logic with exponential backoff
          // Users should be able to retry uploads even if previous attempts failed

          // Update status based on current retry count
          final currentRetry = upload.retryCount ?? 0;
          Log.warning(
            'Upload attempt ${currentRetry + 1}/${_retryConfig.maxRetries + 1} for ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );

          await _updateUpload(
            upload.copyWith(
              status: currentRetry == 0
                  ? UploadStatus.uploading
                  : UploadStatus.retrying,
              retryCount: currentRetry,
            ),
          );

          // Validate file still exists
          if (!videoFile.existsSync()) {
            throw Exception('Video file not found: ${upload.localVideoPath}');
          }

          // Execute upload with timeout
          final result = await _executeUploadWithTimeout(upload, videoFile);

          // Success - record metrics and complete
          await _handleUploadSuccess(upload, result);
        },
        maxRetries: _retryConfig.maxRetries,
        baseDelay: _retryConfig.initialDelay,
        maxDelay: _retryConfig.maxDelay,
        backoffMultiplier: _retryConfig.backoffMultiplier,
        retryWhen: (error) {
          return _isRetriableError(error);
        },
        debugName: 'Upload-${upload.id}',
      );
    } catch (e) {
      Log.error(
        'Upload failed after all retries: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Execute upload with timeout and progress tracking
  Future<dynamic> _executeUploadWithTimeout(
    PendingUpload upload,
    File videoFile,
  ) async {
    Log.info(
      '📤 === EXECUTING UPLOAD ===',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📁 Video: ${videoFile.path}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '👤 Pubkey: ${upload.nostrPubkey}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '📝 Title: ${upload.title}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.info(
      '⏱️ Timeout: ${_retryConfig.networkTimeout.inMinutes} minutes',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      // Use Blossom upload service exclusively
      Log.info(
        '🌸 Using Blossom upload service',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Check if custom server is enabled, otherwise use default diVine server
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
        blossomServer = 'https://blossom.divine.video';
        Log.info(
          '🌸 Uploading to default diVine Blossom server: $blossomServer',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }

      final result = await _blossomService
          .uploadVideo(
            videoFile: videoFile,
            nostrPubkey: upload.nostrPubkey,
            title: upload.title ?? '',
            description: upload.description,
            hashtags: upload.hashtags,
            onProgress: (progress) {
              _updateUploadProgress(
                upload.id,
                progress * 0.8,
              ); // Reserve 20% for thumbnail
            },
          )
          .timeout(
            _retryConfig.networkTimeout,
            onTimeout: () {
              Log.error(
                '⏱️ Upload timed out!',
                name: 'UploadManager',
                category: LogCategory.video,
              );
              final timeoutError = TimeoutException(
                'Upload timed out after ${_retryConfig.networkTimeout.inMinutes} minutes',
              );

              // Send timeout crash report asynchronously
              _sendTimeoutCrashReport(upload, timeoutError).catchError((e) {
                Log.error(
                  'Failed to send timeout crash report: $e',
                  name: 'UploadManager',
                  category: LogCategory.video,
                );
              });

              throw timeoutError;
            },
          );

      // Generate and upload thumbnail after video upload succeeds
      String? thumbnailCdnUrl;
      if (result.success && result.cdnUrl != null) {
        Log.info(
          '✅ Video uploaded successfully',
          name: 'UploadManager',
          category: LogCategory.video,
        );

        // Generate and upload thumbnail to Blossom CDN
        thumbnailCdnUrl = await _generateAndUploadThumbnail(
          videoFile: videoFile,
          nostrPubkey: upload.nostrPubkey,
          upload: upload,
        );

        if (thumbnailCdnUrl != null) {
          Log.info(
            '✅ Thumbnail uploaded to CDN: $thumbnailCdnUrl',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        } else {
          Log.warning(
            '❌ Failed to upload thumbnail to CDN',
            name: 'UploadManager',
            category: LogCategory.video,
          );
        }

        _updateUploadProgress(upload.id, 1.0);
      }

      // Store thumbnail URL in upload for later use
      if (thumbnailCdnUrl != null) {
        await _updateUpload(upload.copyWith(thumbnailPath: thumbnailCdnUrl));
      }

      Log.info(
        '✅ Upload execution completed',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return result;
    } catch (e) {
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
    final metrics = _uploadMetrics[upload.id];

    if (result.success == true) {
      // Get the LATEST upload record from Hive (may have been updated with thumbnail URL)
      final latestUpload = getUpload(upload.id) ?? upload;

      // Create updated upload with success metadata
      final updatedUpload = _createSuccessfulUpload(latestUpload, result);
      await _updateUpload(updatedUpload);

      // Record successful metrics
      if (metrics != null) {
        final updatedMetrics = _createSuccessMetrics(
          metrics,
          endTime,
          upload.retryCount ?? 0,
        );
        _uploadMetrics[upload.id] = updatedMetrics;

        // Log success with formatted output
        _logUploadSuccess(result, updatedMetrics);
      }

      // If upload is in processing state, start polling for completion
      if (updatedUpload.status == UploadStatus.processing) {
        _startProcessingPoll(updatedUpload);
      }
    } else {
      throw Exception(
        result.errorMessage ?? 'Upload failed with unknown error',
      );
    }
  }

  /// Handle upload failure with comprehensive crash reporting
  Future<void> _handleUploadFailure(PendingUpload upload, dynamic error) async {
    final endTime = DateTime.now();
    final metrics = _uploadMetrics[upload.id];

    // Check network connectivity and categorize error
    final connectivity = await _checkNetworkConnectivity();
    final errorCategory = await _categorizeError(error);
    final userMessage = _getUserFriendlyErrorMessage(
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
      'Network: ${_getNetworkTypeString(connectivity)}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.error(
      'User message: $userMessage',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Send comprehensive crash report to Crashlytics with network state
    await _sendUploadFailureCrashReport(
      upload,
      error,
      errorCategory,
      metrics,
      connectivity,
    );

    // Store user-friendly error message instead of raw exception
    await _updateUpload(
      upload.copyWith(
        status: UploadStatus.failed,
        errorMessage: userMessage,
        retryCount: upload.retryCount ?? 0,
      ),
    );

    // Record failure metrics
    if (metrics != null) {
      _uploadMetrics[upload.id] = UploadMetrics(
        uploadId: upload.id,
        startTime: metrics.startTime,
        endTime: endTime,
        uploadDuration: endTime.difference(metrics.startTime),
        retryCount: upload.retryCount ?? 0,
        fileSizeMB: metrics.fileSizeMB,
        errorCategory: errorCategory,
        wasSuccessful: false,
      );
    }
  }

  /// Check if error is retriable
  bool _isRetriableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Network and timeout errors are retriable
    if (errorStr.contains('timeout') ||
        errorStr.contains('connection') ||
        errorStr.contains('network') ||
        errorStr.contains('socket')) {
      return true;
    }

    // Server errors (5xx) are retriable
    if (errorStr.contains('500') ||
        errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504')) {
      return true;
    }

    // Client errors (4xx) are generally not retriable
    if (errorStr.contains('400') ||
        errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('404')) {
      return false;
    }

    // File not found errors are not retriable
    if (errorStr.contains('file not found') ||
        errorStr.contains('does not exist')) {
      return false;
    }

    // Unknown errors are retriable by default
    return true;
  }

  /// Check network connectivity status
  Future<ConnectivityResult> _checkNetworkConnectivity() async {
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();

      // connectivity_plus 7.x returns List<ConnectivityResult>
      // Return first non-none result, or none if all are none
      final resultList = result.cast<ConnectivityResult>();
      // Prefer WiFi > Cellular > Ethernet > VPN > None
      if (resultList.contains(ConnectivityResult.wifi)) {
        return ConnectivityResult.wifi;
      }
      if (resultList.contains(ConnectivityResult.mobile)) {
        return ConnectivityResult.mobile;
      }
      if (resultList.contains(ConnectivityResult.ethernet)) {
        return ConnectivityResult.ethernet;
      }
      if (resultList.contains(ConnectivityResult.vpn)) {
        return ConnectivityResult.vpn;
      }
      return ConnectivityResult.none;
      // Older versions return single ConnectivityResult
      return result as ConnectivityResult;
    } catch (e) {
      Log.error(
        'Failed to check network connectivity: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return ConnectivityResult.none;
    }
  }

  /// Get human-readable network type
  String _getNetworkTypeString(ConnectivityResult connectivity) {
    switch (connectivity) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Cellular';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.none:
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  /// Categorize error for monitoring with network-aware detection
  Future<String> _categorizeError(dynamic error) async {
    final errorStr = error.toString().toLowerCase();

    // Check network connectivity for better categorization
    final connectivity = await _checkNetworkConnectivity();

    // No internet connection
    if (connectivity == ConnectivityResult.none) {
      return 'NO_INTERNET';
    }

    // Network-related errors
    if (errorStr.contains('timeout')) {
      // On cellular, timeout likely means slow connection
      if (connectivity == ConnectivityResult.mobile) {
        return 'SLOW_CONNECTION';
      }
      return 'TIMEOUT';
    }

    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'NETWORK_ERROR';
    }

    if (errorStr.contains('host') || errorStr.contains('dns')) {
      return 'DNS_ERROR';
    }

    // File errors
    if (errorStr.contains('file not found')) return 'FILE_NOT_FOUND';
    if (errorStr.contains('memory')) return 'OUT_OF_MEMORY';
    if (errorStr.contains('permission')) return 'PERMISSION_DENIED';

    // Authentication errors
    if (errorStr.contains('auth') || errorStr.contains('unauthorized')) {
      return 'AUTHENTICATION';
    }

    // Server errors
    if (errorStr.contains('5') || errorStr.contains('server error')) {
      return 'SERVER_ERROR';
    }

    // Client errors
    if (errorStr.contains('413')) return 'FILE_TOO_LARGE';
    if (errorStr.contains('4')) return 'CLIENT_ERROR';

    return 'UNKNOWN';
  }

  /// Get user-friendly error message based on category
  String _getUserFriendlyErrorMessage(
    String category,
    ConnectivityResult connectivity,
  ) {
    switch (category) {
      case 'NO_INTERNET':
        return 'No internet connection. Check your WiFi or cellular data and try again.';

      case 'SLOW_CONNECTION':
        return 'Upload timed out on cellular data. Try connecting to WiFi for faster uploads.';

      case 'TIMEOUT':
        return 'Upload timed out. Your connection might be slow. Try again or connect to WiFi.';

      case 'NETWORK_ERROR':
      case 'DNS_ERROR':
        final networkType = _getNetworkTypeString(connectivity);
        return 'Network error on $networkType. Check your connection and try again.';

      case 'FILE_NOT_FOUND':
        return 'Video file not found. Please record the video again.';

      case 'FILE_TOO_LARGE':
        return 'Video is too large to upload. Try recording a shorter video.';

      case 'OUT_OF_MEMORY':
        return 'Not enough memory to upload. Close other apps and try again.';

      case 'PERMISSION_DENIED':
        return 'Permission denied. Check app permissions in Settings.';

      case 'AUTHENTICATION':
        return 'Authentication failed. Please sign in again.';

      case 'SERVER_ERROR':
        return 'Upload server is having issues. Please try again later.';

      case 'CLIENT_ERROR':
        return 'Upload request failed. Please try again.';

      default:
        return 'Upload failed. Please check your connection and try again.';
    }
  }

  /// Update upload progress
  void _updateUploadProgress(String uploadId, double progress) {
    final upload = getUpload(uploadId);
    if (upload != null && upload.status == UploadStatus.uploading) {
      _updateUpload(upload.copyWith(uploadProgress: progress));
    }
  }

  /// Pause an active upload
  Future<void> pauseUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for pause: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.uploading) {
      Log.error(
        'Upload is not currently uploading: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.debug(
      'Pausing upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Cancel the active upload (Blossom uploads are canceled by stopping the request)
    // No additional cleanup needed for Blossom uploads

    // Update status to paused instead of failed
    final pausedUpload = upload.copyWith(
      status: UploadStatus.paused,
      // Keep current progress and don't set error message
    );

    await _updateUpload(pausedUpload);

    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);

    Log.info(
      'Upload paused: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Resume a paused upload
  Future<void> resumeUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.error(
        'Upload not found for resume: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    if (upload.status != UploadStatus.paused) {
      Log.error(
        'Upload is not paused: ${upload.status}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.debug(
      '▶️ Resuming upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Reset to pending to restart upload from beginning
    final resumedUpload = upload.copyWith(
      status: UploadStatus.pending,
      uploadProgress: 0, // Reset progress since we're starting over
      errorMessage: null,
    );

    await _updateUpload(resumedUpload);

    // Start upload process again
    _performUpload(resumedUpload);

    Log.info(
      'Upload resumed: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Retry a failed upload
  Future<void> retryUpload(String uploadId) async {
    final upload = getUpload(uploadId);
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

    // Reset status and error
    final resetUpload = upload.copyWith(
      status: UploadStatus.pending,
      errorMessage: null,
      uploadProgress: null,
    );

    await _updateUpload(resetUpload);

    // Start upload again
    _performUpload(resetUpload);
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

    // Cancel any active upload
    if (upload.cloudinaryPublicId != null) {
      // Blossom upload cancellation handled by request timeout
    }

    // Update status to failed so it can be retried later
    final cancelledUpload = upload.copyWith(
      status: UploadStatus.failed,
      errorMessage: 'Upload cancelled by user',
      uploadProgress: null,
    );

    await _updateUpload(cancelledUpload);

    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);

    Log.warning(
      'Upload cancelled and available for retry: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Delete an upload permanently (removes from storage)
  Future<void> deleteUpload(String uploadId) async {
    final upload = getUpload(uploadId);
    if (upload == null) return;

    Log.debug(
      '📱️ Deleting upload: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Cancel any active upload first
    if (upload.status == UploadStatus.uploading) {
      if (upload.cloudinaryPublicId != null) {
        // Blossom upload cancellation handled by request timeout
      }
    }

    // Cancel progress subscription
    _progressSubscriptions[uploadId]?.cancel();
    _progressSubscriptions.remove(uploadId);

    // Remove from storage
    await _uploadsBox?.delete(uploadId);

    Log.info(
      'Upload deleted permanently: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Remove completed or failed uploads
  Future<void> cleanupCompletedUploads() async {
    if (_uploadsBox == null) return;

    final completedUploads = pendingUploads
        .where((upload) => upload.isCompleted)
        .where((upload) => upload.completedAt != null)
        .where(
          (upload) => DateTime.now().difference(upload.completedAt!).inDays > 7,
        ) // Keep for 7 days
        .toList();

    for (final upload in completedUploads) {
      await _uploadsBox!.delete(upload.id);
      Log.debug(
        '📱️ Cleaned up old upload: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }

    if (completedUploads.isNotEmpty) {}
  }

  /// Resume any uploads that were interrupted
  Future<void> _resumeInterruptedUploads() async {
    final interruptedUploads = pendingUploads
        .where((upload) => upload.status == UploadStatus.uploading)
        .toList();

    for (final upload in interruptedUploads) {
      Log.debug(
        'Resuming interrupted upload: ${upload.id}',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      // Reset to pending and restart
      final resetUpload = upload.copyWith(
        status: UploadStatus.pending,
        uploadProgress: null,
      );

      await _updateUpload(resetUpload);
      _performUpload(resetUpload);
    }
  }

  /// Save upload to local storage with robust retry logic
  Future<void> _saveUpload(PendingUpload upload) async {
    // First attempt with existing box
    if (_uploadsBox != null && _uploadsBox!.isOpen) {
      try {
        await _uploadsBox!.put(upload.id, upload);
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

    // Box is null or save failed - use robust initialization
    Log.warning(
      'Upload box not ready, using robust initialization...',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    try {
      _uploadsBox = await UploadInitializationHelper.initializeUploadsBox(
        forceReinit: true,
      );

      if (_uploadsBox == null || !_uploadsBox!.isOpen) {
        throw Exception('Failed to initialize box for saving upload');
      }

      _isInitialized = true;

      // Retry save with new box
      await _uploadsBox!.put(upload.id, upload);
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

      // As a last resort, queue the upload for later
      _queueUploadForLater(upload);

      throw Exception(
        'Unable to save upload: Storage initialization failed after multiple attempts',
      );
    }
  }

  // Queue for uploads that couldn't be saved immediately
  final List<PendingUpload> _pendingSaveQueue = [];
  Timer? _saveQueueTimer;

  /// Queue upload for later save attempt
  void _queueUploadForLater(PendingUpload upload) {
    Log.warning(
      'Queueing upload ${upload.id} for later save attempt',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    _pendingSaveQueue.add(upload);

    // Schedule retry in 5 seconds
    _saveQueueTimer?.cancel();
    _saveQueueTimer = Timer(const Duration(seconds: 5), _processSaveQueue);
  }

  /// Process queued uploads
  Future<void> _processSaveQueue() async {
    if (_pendingSaveQueue.isEmpty) return;

    Log.info(
      'Processing ${_pendingSaveQueue.length} queued uploads',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final queue = List<PendingUpload>.from(_pendingSaveQueue);
    _pendingSaveQueue.clear();

    for (final upload in queue) {
      try {
        await _saveUpload(upload);
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
        // Re-queue for another attempt
        _pendingSaveQueue.add(upload);
      }
    }

    // If there are still pending uploads, schedule another retry
    if (_pendingSaveQueue.isNotEmpty) {
      _saveQueueTimer = Timer(const Duration(seconds: 30), _processSaveQueue);
    }
  }

  /// Update existing upload
  Future<void> _updateUpload(PendingUpload upload) async {
    if (_uploadsBox == null) return;

    await _uploadsBox!.put(upload.id, upload);
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

    await _updateUpload(updatedUpload);
    Log.info(
      'Updated upload status: $uploadId -> $status',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Update upload metadata (title, description, hashtags)
  Future<void> updateUploadMetadata(
    String uploadId, {
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    final upload = getUpload(uploadId);
    if (upload == null) {
      Log.warning(
        'Upload not found for metadata update: $uploadId',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return;
    }
    final updatedUpload = upload.copyWith(
      title: title ?? upload.title,
      description: description ?? upload.description,
      hashtags: hashtags ?? upload.hashtags,
    );
    await _updateUpload(updatedUpload);
    Log.info(
      'Updated upload metadata: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Get upload statistics
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

  /// Fix uploads stuck in readyToPublish without proper data (debug method)
  Future<void> cleanupProblematicUploads() async {
    final uploads = pendingUploads;
    var fixedCount = 0;

    for (final upload in uploads) {
      // Fix uploads that are ready to publish but missing required data
      // These should be moved back to failed status so user can retry
      if (upload.status == UploadStatus.readyToPublish &&
          (upload.videoId == null || upload.cdnUrl == null)) {
        Log.error(
          'Fixing stuck upload: ${upload.id} (missing videoId/cdnUrl) - moving to failed',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        final fixedUpload = upload.copyWith(status: UploadStatus.failed);
        await _updateUpload(fixedUpload);
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

  /// Get comprehensive performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final metrics = _uploadMetrics.values.toList();
    final successful = metrics.where((m) => m.wasSuccessful).toList();
    final failed = metrics.where((m) => !m.wasSuccessful).toList();

    return {
      'total_uploads': metrics.length,
      'successful_uploads': successful.length,
      'failed_uploads': failed.length,
      'success_rate': metrics.isNotEmpty
          ? (successful.length / metrics.length * 100)
          : 0,
      'average_throughput_mbps': successful.isNotEmpty
          ? successful
                    .map((m) => m.throughputMBps ?? 0)
                    .reduce((a, b) => a + b) /
                successful.length
          : 0,
      'average_retry_count': metrics.isNotEmpty
          ? metrics.map((m) => m.retryCount).reduce((a, b) => a + b) /
                metrics.length
          : 0,
      'error_categories': _getErrorCategoriesCount(failed),
      'circuit_breaker_state': _circuitBreaker.state.toString(),
      'circuit_breaker_failure_rate': _circuitBreaker.failureRate,
    };
  }

  /// Get error categories breakdown
  Map<String, int> _getErrorCategoriesCount(List<UploadMetrics> failedMetrics) {
    final categories = <String, int>{};
    for (final metric in failedMetrics) {
      final category = metric.errorCategory ?? 'UNKNOWN';
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return categories;
  }

  /// Get upload metrics for a specific upload
  UploadMetrics? getUploadMetrics(String uploadId) => _uploadMetrics[uploadId];

  /// Get recent upload metrics (last 24 hours)
  List<UploadMetrics> getRecentMetrics() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(hours: 24));

    return _uploadMetrics.values
        .where((m) => m.startTime.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  /// Clear old metrics to prevent memory bloat
  void _cleanupOldMetrics() {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(days: 7)); // Keep 1 week

    _uploadMetrics.removeWhere(
      (key, metric) => metric.startTime.isBefore(cutoff),
    );
  }

  /// Enhanced retry mechanism for manual retry
  Future<void> retryUploadWithBackoff(String uploadId) async {
    final upload = getUpload(uploadId);
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

    // Cancel any existing retry timer
    _retryTimers[uploadId]?.cancel();
    _retryTimers.remove(uploadId);

    Log.warning(
      'Retrying upload with backoff: $uploadId',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Reset retry count if it's been more than 1 hour since last attempt
    final now = DateTime.now();
    final timeSinceLastAttempt = upload.completedAt != null
        ? now.difference(upload.completedAt!)
        : now.difference(upload.createdAt);

    final shouldResetRetries = timeSinceLastAttempt.inHours >= 1;
    final newRetryCount = shouldResetRetries ? 0 : (upload.retryCount ?? 0);

    // Update upload with reset retry count if applicable
    final updatedUpload = upload.copyWith(
      status: UploadStatus.pending,
      retryCount: newRetryCount,
      errorMessage: null,
    );

    await _updateUpload(updatedUpload);

    // Start upload process
    await _performUpload(updatedUpload);
  }

  /// Create successful upload with metadata
  PendingUpload _createSuccessfulUpload(PendingUpload upload, dynamic result) {
    // Handle both BlossomUploadResult and DirectUploadResult structures
    String? thumbnailUrl;
    try {
      // Get thumbnailUrl from upload result (both services should provide it)
      thumbnailUrl = result.thumbnailUrl as String?;
    } catch (e) {
      // Fallback if thumbnailUrl is not available
      thumbnailUrl = null;
    }

    Log.info(
      '📸 Upload result type: ${result.runtimeType}',
      name: 'UploadManager',
      category: LogCategory.system,
    );
    Log.info(
      '📸 Upload result thumbnail URL: $thumbnailUrl',
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

    return upload.copyWith(
      status: (isProcessing && !skipProcessing)
          ? UploadStatus.processing
          : UploadStatus.readyToPublish,
      cloudinaryPublicId:
          result.videoId as String?, // Use videoId for existing systems
      videoId:
          result.videoId as String?, // Store videoId for new publishing system
      cdnUrl:
          result.cdnUrl
              as String?, // Store CDN URL directly (fallbackUrl ?? url via getter)
      streamingMp4Url: result.streamingMp4Url, // Store BunnyStream MP4 URL
      streamingHlsUrl: result.streamingHlsUrl, // Store BunnyStream HLS URL
      fallbackUrl: result.fallbackUrl, // Store R2 fallback MP4 URL
      thumbnailPath: thumbnailUrl, // Store thumbnail URL
      uploadProgress: (isProcessing && !skipProcessing)
          ? 0.9
          : 1.0, // Skip processing = 100% ready
      completedAt: (isProcessing && !skipProcessing)
          ? null
          : DateTime.now(), // Mark as completed if skipping processing
    );
  }

  /// Create success metrics with calculated values
  UploadMetrics _createSuccessMetrics(
    UploadMetrics currentMetrics,
    DateTime endTime,
    int retryCount,
  ) {
    final duration = endTime.difference(currentMetrics.startTime);
    final throughput = _calculateThroughput(
      currentMetrics.fileSizeMB,
      duration,
    );

    return UploadMetrics(
      uploadId: currentMetrics.uploadId,
      startTime: currentMetrics.startTime,
      endTime: endTime,
      uploadDuration: duration,
      retryCount: retryCount,
      fileSizeMB: currentMetrics.fileSizeMB,
      throughputMBps: throughput,
      wasSuccessful: true,
    );
  }

  /// Calculate upload throughput in MB/s
  double _calculateThroughput(double fileSizeMB, Duration duration) {
    // Handle zero duration edge case
    if (duration.inMicroseconds == 0) {
      return fileSizeMB * 1000; // Assume instant = 1ms
    }
    return fileSizeMB / (duration.inMicroseconds / 1000000.0);
  }

  /// Log upload success with formatted details
  void _logUploadSuccess(dynamic result, UploadMetrics metrics) {
    Log.info(
      'Direct upload successful: ${result.videoId}',
      name: 'UploadManager',
      category: LogCategory.video,
    );
    Log.debug(
      '🎬 CDN URL: ${result.cdnUrl}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    final durationStr = metrics.uploadDuration?.inSeconds ?? 0;
    final throughputStr = metrics.throughputMBps?.toStringAsFixed(2) ?? '0.00';

    Log.debug(
      'Upload metrics: ${metrics.fileSizeMB.toStringAsFixed(1)}MB in ${durationStr}s ($throughputStr MB/s)',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Send comprehensive upload failure crash report to Crashlytics
  Future<void> _sendUploadFailureCrashReport(
    PendingUpload upload,
    dynamic error,
    String errorCategory,
    UploadMetrics? metrics,
    ConnectivityResult connectivity,
  ) async {
    try {
      final crashReporting = CrashReportingService.instance;

      // Set context for the crash report
      final context = {
        'upload_id': upload.id,
        'upload_status': upload.status.toString(),
        'error_category': errorCategory,
        'retry_count': upload.retryCount ?? 0,
        'can_retry': upload.canRetry,
        'upload_target': 'blossomServer',
        'circuit_breaker_state': _circuitBreaker.state.toString(),
        'circuit_breaker_failure_rate': _circuitBreaker.failureRate,
        'local_file_path': upload.localVideoPath,
        'video_id': upload.videoId,
        'cdn_url': upload.cdnUrl,
        'upload_progress': upload.uploadProgress,
        'created_at': upload.createdAt.toIso8601String(),
        'file_exists': kIsWeb
            ? false
            : File(upload.localVideoPath).existsSync(),
        // Network connectivity information
        'network_type': _getNetworkTypeString(connectivity),
        'network_status': connectivity.toString(),
        'is_offline': connectivity == ConnectivityResult.none,
        'is_cellular': connectivity == ConnectivityResult.mobile,
        'is_wifi': connectivity == ConnectivityResult.wifi,
      };

      // Add metrics if available
      if (metrics != null) {
        context.addAll({
          'file_size_mb': metrics.fileSizeMB,
          'start_time': metrics.startTime.toIso8601String(),
          'upload_duration_seconds': metrics.uploadDuration?.inSeconds,
          'throughput_mbps': metrics.throughputMBps,
          'metrics_retry_count': metrics.retryCount,
        });
      }

      // Add system context
      context.addAll({
        'total_uploads': _uploadsBox?.length ?? 0,
        'active_uploads': _progressSubscriptions.length,
        'queued_uploads': _pendingSaveQueue.length,
        'platform': _getPlatformName(),
        'is_initialized': _isInitialized,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Set all context as custom keys
      for (final entry in context.entries) {
        await crashReporting.setCustomKey(
          'upload_failure_${entry.key}',
          entry.value.toString(),
        );
      }

      // Get stack trace from current context
      final stackTrace = StackTrace.current;

      // Create detailed error message
      final fileExists = kIsWeb
          ? 'N/A (web)'
          : '${File(upload.localVideoPath).existsSync()}';
      final detailedError =
          '''
Upload Failure Report:
- Upload ID: ${upload.id}
- Error Category: $errorCategory
- Error: $error
- Network: ${_getNetworkTypeString(connectivity)} (${connectivity == ConnectivityResult.none ? 'OFFLINE' : 'ONLINE'})
- File: ${upload.localVideoPath}
- File Exists: $fileExists
- Upload Status: ${upload.status}
- Retry Count: ${upload.retryCount ?? 0}
- Can Retry: ${upload.canRetry}
- Circuit Breaker: ${_circuitBreaker.state} (${_circuitBreaker.failureRate}% failure rate)
- Upload Target: blossomServer
${metrics != null ? '- File Size: ${metrics.fileSizeMB} MB\n- Duration: ${metrics.uploadDuration}\n- Throughput: ${metrics.throughputMBps} MB/s' : ''}
''';

      // Log the detailed error
      crashReporting.log('UPLOAD_FAILURE: $detailedError');

      // Record the error to Crashlytics
      await crashReporting.recordError(
        error,
        stackTrace,
        reason: 'Video upload failure - $errorCategory',
      );

      Log.info(
        '📊 Sent comprehensive upload failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      // Don't let crash reporting failures break the upload failure handling
      Log.error(
        'Failed to send crash report for upload failure: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Send initialization failure crash report to Crashlytics
  Future<void> _sendInitializationFailureCrashReport(
    dynamic error,
    StackTrace stackTrace,
  ) async {
    try {
      final crashReporting = CrashReportingService.instance;

      // Set context for the crash report
      await crashReporting.setCustomKey('init_failure_error', error.toString());
      await crashReporting.setCustomKey(
        'init_failure_platform',
        _getPlatformName(),
      );
      await crashReporting.setCustomKey(
        'init_failure_timestamp',
        DateTime.now().toIso8601String(),
      );
      await crashReporting.setCustomKey(
        'init_failure_retry_attempts',
        'multiple',
      );

      // Create detailed error message
      final detailedError =
          '''
UploadManager Initialization Failure:
- Error: $error
- Platform: ${_getPlatformName()}
- Timestamp: ${DateTime.now().toIso8601String()}
- Context: Failed after all retry attempts in UploadInitializationHelper
''';

      // Log the detailed error
      crashReporting.log('INIT_FAILURE: $detailedError');

      // Record the error to Crashlytics
      await crashReporting.recordError(
        error,
        stackTrace,
        reason: 'UploadManager initialization failure after retries',
      );

      Log.info(
        '📊 Sent UploadManager initialization failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      // Don't let crash reporting failures break the initialization failure handling
      Log.error(
        'Failed to send initialization crash report: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Send timeout failure crash report to Crashlytics
  Future<void> _sendTimeoutCrashReport(
    PendingUpload upload,
    TimeoutException timeoutError,
  ) async {
    try {
      final crashReporting = CrashReportingService.instance;

      // Set context for the crash report
      final context = {
        'timeout_upload_id': upload.id,
        'timeout_file_path': upload.localVideoPath,
        'timeout_upload_target': 'blossomServer',
        'timeout_network_timeout_minutes':
            _retryConfig.networkTimeout.inMinutes,
        'timeout_retry_count': upload.retryCount ?? 0,
        'timeout_upload_status': upload.status.toString(),
        'timeout_platform': _getPlatformName(),
        'timeout_file_exists': kIsWeb
            ? false
            : File(upload.localVideoPath).existsSync(),
        'timeout_timestamp': DateTime.now().toIso8601String(),
      };

      // Set all context as custom keys
      for (final entry in context.entries) {
        await crashReporting.setCustomKey(entry.key, entry.value.toString());
      }

      // Create detailed error message
      final fileExists = kIsWeb
          ? 'N/A (web)'
          : '${File(upload.localVideoPath).existsSync()}';
      final detailedError =
          '''
Upload Timeout Failure:
- Upload ID: ${upload.id}
- File: ${upload.localVideoPath}
- File Exists: $fileExists
- Upload Target: blossomServer
- Timeout Duration: ${_retryConfig.networkTimeout.inMinutes} minutes
- Retry Count: ${upload.retryCount ?? 0}
- Upload Status: ${upload.status}
- Platform: ${_getPlatformName()}
- Timestamp: ${DateTime.now().toIso8601String()}
''';

      // Log the detailed error
      crashReporting.log('TIMEOUT_FAILURE: $detailedError');

      // Record the error to Crashlytics
      await crashReporting.recordError(
        timeoutError,
        StackTrace.current,
        reason:
            'Video upload timeout after ${_retryConfig.networkTimeout.inMinutes} minutes',
      );

      Log.info(
        '📊 Sent upload timeout failure report to Crashlytics',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    } catch (crashReportingError) {
      // Don't let crash reporting failures break the timeout failure handling
      Log.error(
        'Failed to send timeout crash report: $crashReportingError',
        name: 'UploadManager',
        category: LogCategory.video,
      );
    }
  }

  /// Generate and upload thumbnail to Blossom CDN
  Future<String?> _generateAndUploadThumbnail({
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
      final thumbnailPath = await VideoThumbnailService.extractThumbnail(
        videoPath: videoFile.path,
        timeMs: 500, // Extract at 500ms
        quality: 85,
      );

      if (thumbnailPath == null) {
        Log.warning(
          '❌ Failed to extract thumbnail from video',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return null;
      }

      final thumbnailFile = File(thumbnailPath);
      if (!thumbnailFile.existsSync()) {
        Log.warning(
          '❌ Thumbnail file not found after extraction',
          name: 'UploadManager',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        '✅ Thumbnail extracted, uploading to Blossom server',
        name: 'UploadManager',
        category: LogCategory.video,
      );

      _updateUploadProgress(upload.id, 0.85);

      // Upload thumbnail to Blossom server
      final thumbnailResult = await _blossomService.uploadImage(
        imageFile: thumbnailFile,
        nostrPubkey: nostrPubkey,
        mimeType: 'image/jpeg',
        onProgress: (progress) {
          // Map thumbnail progress to 85%-100% of total upload
          _updateUploadProgress(upload.id, 0.85 + (progress * 0.15));
        },
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

      if (thumbnailResult.success && thumbnailResult.cdnUrl != null) {
        return thumbnailResult.cdnUrl;
      }

      return null;
    } catch (e) {
      Log.error(
        'Error generating/uploading thumbnail: $e',
        name: 'UploadManager',
        category: LogCategory.video,
      );
      return null;
    }
  }

  void dispose() {
    // Cancel all progress subscriptions
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();

    // Cancel all retry timers
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();

    // Cancel save queue timer
    _saveQueueTimer?.cancel();
    _saveQueueTimer = null;

    // Clean up old metrics
    _cleanupOldMetrics();

    // Note: We don't close the box here as it might be shared across instances
    // The box will be closed when Hive.close() is called in tearDownAll
    // Closing it here causes "File closed" errors in tests
    // _uploadsBox?.close();
    _uploadsBox = null;
    _isInitialized = false;

    // Clear any pending saves
    _pendingSaveQueue.clear();

    Log.info(
      'UploadManager disposed',
      name: 'UploadManager',
      category: LogCategory.video,
    );
  }

  /// Start polling for processing upload completion
  void _startProcessingPoll(PendingUpload upload) {
    Log.info(
      '🔄 Starting processing poll for upload: ${upload.id}',
      name: 'UploadManager',
      category: LogCategory.video,
    );

    // Poll every 10 seconds for up to 5 minutes
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        // Check if upload still exists and is still processing
        final currentUpload = getUpload(upload.id);
        if (currentUpload == null ||
            currentUpload.status != UploadStatus.processing) {
          timer.cancel();
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
          await _updateUpload(readyUpload);

          Log.info(
            '✅ Video processing complete: ${upload.id}',
            name: 'UploadManager',
            category: LogCategory.video,
          );
          timer.cancel();
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
        timer.cancel();
        Log.warning(
          'Processing poll timeout for upload: ${upload.id}',
          name: 'UploadManager',
          category: LogCategory.video,
        );
      }
    });
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
