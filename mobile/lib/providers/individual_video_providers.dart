// ABOUTME: Individual video controller providers using proper Riverpod Family pattern
// ABOUTME: Each video gets its own controller with automatic lifecycle management via autoDispose

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/services/broken_video_tracker.dart' show BrokenVideoTracker;
import 'package:openvine/providers/app_providers.dart';

part 'individual_video_providers.g.dart';

/// Cache for pre-generated auth headers by video ID
/// This allows synchronous header lookup during controller creation
final authHeadersCacheProvider = StateProvider<Map<String, Map<String, String>>>((ref) => {});

/// Parameters for video controller creation
class VideoControllerParams {
  const VideoControllerParams({
    required this.videoId,
    required this.videoUrl,
    this.videoEvent,
  });

  final String videoId;
  final String videoUrl;
  final dynamic videoEvent; // VideoEvent for enhanced error reporting

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoControllerParams &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          videoUrl == other.videoUrl &&
          videoEvent == other.videoEvent;

  @override
  int get hashCode => videoId.hashCode ^ videoUrl.hashCode ^ videoEvent.hashCode;

  @override
  String toString() => 'VideoControllerParams(videoId: $videoId, videoUrl: $videoUrl, hasEvent: ${videoEvent != null})';
}

/// Loading state for individual videos
class VideoLoadingState {
  const VideoLoadingState({
    required this.videoId,
    required this.isLoading,
    required this.isInitialized,
    required this.hasError,
    this.errorMessage,
  });

  final String videoId;
  final bool isLoading;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  VideoLoadingState copyWith({
    String? videoId,
    bool? isLoading,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return VideoLoadingState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLoadingState &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(videoId, isLoading, isInitialized, hasError, errorMessage);

  @override
  String toString() => 'VideoLoadingState(videoId: $videoId, isLoading: $isLoading, isInitialized: $isInitialized, hasError: $hasError, errorMessage: $errorMessage)';
}

/// Provider for individual video controllers with autoDispose
/// Each video gets its own controller instance
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  // Riverpod-native lifecycle: keep controller alive with 5-minute cache timeout
  // This prevents excessive codec churn during scrolling (creating/disposing controllers rapidly)
  // 5 minutes allows smooth scrolling back and forth without re-initializing codecs
  final link = ref.keepAlive();
  Timer? cacheTimer;

  // Riverpod lifecycle hooks for idiomatic cache behavior
  ref.onCancel(() {
    // Last listener removed - start 5-minute cache timeout
    // Longer timeout reduces jittery scrolling caused by rapid codec initialization/disposal
    cacheTimer = Timer(const Duration(minutes: 5), () {
      link.close(); // Allow autoDispose after 5 minutes of no listeners
    });
  });

  ref.onResume(() {
    // New listener added - cancel the disposal timer
    cacheTimer?.cancel();
  });

  Log.info('🎬 Creating VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
      name: 'IndividualVideoController', category: LogCategory.system);

  // Normalize .bin URLs by replacing extension based on MIME type from event metadata
  // CDN serves files based on hash, not extension, so we can safely rewrite for player compatibility
  String videoUrl = params.videoUrl;
  if (videoUrl.toLowerCase().endsWith('.bin') && params.videoEvent != null) {
    final videoEvent = params.videoEvent as dynamic;
    final mimeType = videoEvent.mimeType as String?;

    if (mimeType != null) {
      String? newExtension;
      if (mimeType.contains('webm')) {
        newExtension = '.webm';
      } else if (mimeType.contains('mp4')) {
        newExtension = '.mp4';
      }

      if (newExtension != null) {
        videoUrl = videoUrl.substring(0, videoUrl.length - 4) + newExtension;
        Log.debug('🔧 Normalized .bin URL based on MIME type $mimeType: $newExtension',
            name: 'IndividualVideoController', category: LogCategory.video);
      }
    }
  }

  final VideoPlayerController controller;

  // On web, skip file caching entirely and always use network URL
  if (kIsWeb) {
    Log.debug('🌐 Web platform - using NETWORK URL for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.video);

    // Compute auth headers synchronously if possible
    final authHeaders = _computeAuthHeadersSync(ref, params);

    controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );
  } else {
    // On native platforms, use file caching
    final videoCache = openVineVideoCache;

    // Synchronous cache check - use getCachedVideoSync() which checks file existence without async
    final cachedFile = videoCache.getCachedVideoSync(params.videoId);

    if (cachedFile != null && cachedFile.existsSync()) {
      // Use cached file!
      Log.info('✅ Using CACHED FILE for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...: ${cachedFile.path}',
          name: 'IndividualVideoController', category: LogCategory.video);
      controller = VideoPlayerController.file(cachedFile);
    } else {
      // Use network URL and start caching
      Log.debug('📡 Using NETWORK URL for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
          name: 'IndividualVideoController', category: LogCategory.video);

      // Compute auth headers synchronously if possible
      final authHeaders = _computeAuthHeadersSync(ref, params);

      controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: authHeaders ?? {},
      );

      // Start caching in background for future use
      unawaited(
        _cacheVideoWithAuth(ref, videoCache, params).catchError((error) {
          Log.warning('⚠️ Background video caching failed: $error',
              name: 'IndividualVideoController', category: LogCategory.video);
          return null;
        }),
      );
    }
  }

  // Initialize the controller (async in background)
  // Timeout depends on video format:
  // - HLS (.m3u8): 60 seconds - needs to download manifest + buffer segments
  // - Direct MP4: 30 seconds - single file download
  // Previous 15-second timeout was too aggressive for cellular/slow networks
  final isHls = params.videoUrl.toLowerCase().contains('.m3u8') ||
                params.videoUrl.toLowerCase().contains('hls');
  final timeoutDuration = isHls ? const Duration(seconds: 60) : const Duration(seconds: 30);
  final formatType = isHls ? 'HLS' : 'MP4';

  // Track significant video state changes only (initialization, errors, buffering)
  // Previous state tracking to avoid logging every frame update
  bool? _lastIsInitialized;
  bool? _lastIsBuffering;
  bool? _lastHasError;

  void stateChangeListener() {
    final value = controller.value;

    // Only log significant state changes, not every position update
    final isInitialized = value.isInitialized;
    final isBuffering = value.isBuffering;
    final hasError = value.hasError;

    // Log only when significant state changes occur
    if (isInitialized != _lastIsInitialized ||
        isBuffering != _lastIsBuffering ||
        hasError != _lastHasError) {

      final position = value.position;
      final duration = value.duration;
      final buffered = value.buffered.isNotEmpty ? value.buffered.last.end : Duration.zero;

      Log.debug(
        '🎬 VIDEO STATE CHANGE [${params.videoId}]:\n'
        '   • Position: ${position.inMilliseconds}ms / ${duration.inMilliseconds}ms\n'
        '   • Buffered: ${buffered.inMilliseconds}ms\n'
        '   • Initialized: $isInitialized\n'
        '   • Playing: ${value.isPlaying}\n'
        '   • Buffering: $isBuffering\n'
        '   • Size: ${value.size.width.toInt()}x${value.size.height.toInt()}\n'
        '   • HasError: $hasError',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

      _lastIsInitialized = isInitialized;
      _lastIsBuffering = isBuffering;
      _lastHasError = hasError;
    }
  }

  controller.addListener(stateChangeListener);

  // Initialize with automatic retry for transient failures (CoreMedia errors, byte range issues)
  // Retry up to 2 times (3 attempts total) with 500ms delay between attempts
  Future<void> initializeWithRetry() async {
    const maxAttempts = 3;
    const retryDelay = Duration(milliseconds: 500);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await controller.initialize().timeout(
          timeoutDuration,
          onTimeout: () => throw TimeoutException(
            'Video initialization timed out after ${timeoutDuration.inSeconds} seconds ($formatType format)'
          ),
        );
        // Success! Exit retry loop
        if (attempt > 1) {
          Log.info('✅ Video ${params.videoId} initialized successfully on attempt $attempt',
              name: 'IndividualVideoController', category: LogCategory.video);
        }
        return;
      } catch (error) {
        final errorStr = error.toString().toLowerCase();
        final isRetryable = errorStr.contains('byte range') ||
                           errorStr.contains('coremediaerrordomain') ||
                           errorStr.contains('network') ||
                           errorStr.contains('connection');

        if (isRetryable && attempt < maxAttempts) {
          Log.warning('⚠️ Video ${params.videoId} initialization attempt $attempt failed (retryable): $error',
              name: 'IndividualVideoController', category: LogCategory.video);
          await Future.delayed(retryDelay);
          // Continue to next attempt
        } else {
          // Non-retryable error or max attempts reached - rethrow
          if (attempt == maxAttempts) {
            Log.error('❌ Video ${params.videoId} initialization failed after $maxAttempts attempts',
                name: 'IndividualVideoController', category: LogCategory.video);
          }
          rethrow;
        }
      }
    }
  }

  final initFuture = initializeWithRetry();

  initFuture.then((_) {
    final initialPosition = controller.value.position;
    final initialSize = controller.value.size;

    Log.info(
      '✅ VideoPlayerController initialized for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...\n'
      '   • Initial position: ${initialPosition.inMilliseconds}ms\n'
      '   • Duration: ${controller.value.duration.inMilliseconds}ms\n'
      '   • Size: ${initialSize.width.toInt()}x${initialSize.height.toInt()}\n'
      '   • Buffered: ${controller.value.buffered.isNotEmpty ? controller.value.buffered.last.end.inMilliseconds : 0}ms',
      name: 'IndividualVideoController',
      category: LogCategory.system,
    );

    // Set looping for Vine-like behavior
    controller.setLooping(true);

    // CRITICAL DEBUG: Check if video is starting at position 0
    if (initialPosition.inMilliseconds > 0) {
      Log.warning(
        '⚠️ VIDEO NOT AT START! Video ${params.videoId} initialized at ${initialPosition.inMilliseconds}ms instead of 0ms',
        name: 'IndividualVideoController',
        category: LogCategory.video,
      );

      // Try to seek to beginning
      controller.seekTo(Duration.zero).then((_) {
        Log.info('🔄 Seeked video ${params.videoId} back to start (was at ${initialPosition.inMilliseconds}ms)',
            name: 'IndividualVideoController', category: LogCategory.video);
      }).catchError((e) {
        Log.error('❌ Failed to seek video ${params.videoId} to start: $e',
            name: 'IndividualVideoController', category: LogCategory.video);
      });
    }

    // Controller is initialized and paused - widget will control playback
    Log.debug('⏸️ Video ${params.videoId.length > 8 ? params.videoId : params.videoId}... initialized and paused (widget controls playback)',
        name: 'IndividualVideoController', category: LogCategory.system);
  }).catchError((error) {
    final videoIdDisplay = params.videoId.length > 8 ? params.videoId : params.videoId;

    // Enhanced error logging with full Nostr event details
    final errorMessage = error.toString();
    var logMessage = '❌ VideoPlayerController initialization failed for video $videoIdDisplay...: $errorMessage';

    if (params.videoEvent != null) {
      final event = params.videoEvent as dynamic;
      logMessage += '\n📋 Full Nostr Event Details:';
      logMessage += '\n   • Event ID: ${event.id}';
      logMessage += '\n   • Pubkey: ${event.pubkey}';
      logMessage += '\n   • Content: ${event.content}';
      logMessage += '\n   • Video URL: ${event.videoUrl}';
      logMessage += '\n   • Title: ${event.title ?? 'null'}';
      logMessage += '\n   • Duration: ${event.duration ?? 'null'}';
      logMessage += '\n   • Dimensions: ${event.dimensions ?? 'null'}';
      logMessage += '\n   • MIME Type: ${event.mimeType ?? 'null'}';
      logMessage += '\n   • File Size: ${event.fileSize ?? 'null'}';
      logMessage += '\n   • SHA256: ${event.sha256 ?? 'null'}';
      logMessage += '\n   • Thumbnail URL: ${event.thumbnailUrl ?? 'null'}';
      logMessage += '\n   • Hashtags: ${event.hashtags ?? []}';
      logMessage += '\n   • Created At: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}';
      if (event.rawTags != null && event.rawTags.isNotEmpty) {
        logMessage += '\n   • Raw Tags: ${event.rawTags}';
      }
    } else {
      logMessage += '\n⚠️  No Nostr event details available (consider passing videoEvent to VideoControllerParams)';
    }

    Log.error(logMessage, name: 'IndividualVideoController', category: LogCategory.system);

    // Check for 401 Unauthorized - likely NSFW content requiring age verification
    if (_is401Error(errorMessage)) {
      Log.warning('🔐 Detected 401 Unauthorized for video $videoIdDisplay... - age verification may be required',
          name: 'IndividualVideoController', category: LogCategory.video);

      // Check if user has NOT verified adult content yet
      final ageVerificationService = ref.read(ageVerificationServiceProvider);
      if (!ageVerificationService.isAdultContentVerified) {
        Log.info('🔐 User has not verified adult content - need to show verification dialog',
            name: 'IndividualVideoController', category: LogCategory.video);
        // Store this video ID in a provider so the widget can show the dialog
        // For now, just log - we'll handle UI in the widget layer
      } else {
        Log.warning('🔐 User has verified but still getting 401 - may be auth header issue',
            name: 'IndividualVideoController', category: LogCategory.video);
      }
    }

    // Check for corrupted cache file (OSStatus error -12848 or "media may be damaged")
    if (_isCacheCorruption(errorMessage) && !kIsWeb) {
      Log.warning('🗑️ Detected corrupted cache for video $videoIdDisplay... - removing and will retry',
          name: 'IndividualVideoController', category: LogCategory.video);

      // Remove corrupted cache file and invalidate provider to trigger retry
      openVineVideoCache.removeCorruptedVideo(params.videoId).then((_) {
        if (ref.mounted) {
          Log.info('🔄 Invalidating provider to retry download for video $videoIdDisplay...',
              name: 'IndividualVideoController', category: LogCategory.video);
          ref.invalidateSelf();
        }
      }).catchError((removeError) {
        Log.error('❌ Failed to remove corrupted cache: $removeError',
            name: 'IndividualVideoController', category: LogCategory.video);
      });
    } else if (_isVideoError(errorMessage) && ref.mounted) {
      // Mark video as broken for errors that indicate the video URL is non-functional
      ref.read(brokenVideoTrackerProvider.future).then((tracker) {
        // Double-check still mounted before marking broken
        if (ref.mounted) {
          tracker.markVideoBroken(params.videoId, 'Playback initialization failed: $errorMessage');
        }
      }).catchError((trackerError) {
        Log.warning('Failed to mark video as broken: $trackerError',
            name: 'IndividualVideoController', category: LogCategory.system);
      });
    }
  });

  // AutoDispose: Cleanup controller when provider is disposed
  ref.onDispose(() {
    cacheTimer?.cancel();
    Log.info('🧹 Disposing VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.system);

    // Remove state change listener before disposal
    controller.removeListener(stateChangeListener);

    // Defer controller disposal to avoid triggering listener callbacks during lifecycle
    // This prevents "Cannot use Ref inside life-cycles" errors when listeners try to access providers
    Future.microtask(() {
      // Only dispose if controller exists
      try {
        controller.dispose();
      } catch (e) {
        Log.warning('Failed to dispose controller: $e', name: 'IndividualVideoController', category: LogCategory.system);
      }
    });
  });

  // NOTE: Play/pause logic has been moved to VideoFeedItem widget
  // The provider only manages controller lifecycle, NOT playback state
  // This ensures videos can only play when widget is mounted and visible

  return controller;
}

/// Compute auth headers synchronously if possible (for VideoPlayerController)
/// Returns cached headers if available, null otherwise
Map<String, String>? _computeAuthHeadersSync(Ref ref, VideoControllerParams params) {
  Log.debug('🔐 [AUTH-SYNC] Computing auth headers for video ${params.videoId}',
      name: 'IndividualVideoController', category: LogCategory.video);

  final ageVerificationService = ref.read(ageVerificationServiceProvider);
  final blossomAuthService = ref.read(blossomAuthServiceProvider);

  Log.debug('🔐 [AUTH-SYNC] isAdultContentVerified=${ageVerificationService.isAdultContentVerified}, canCreateHeaders=${blossomAuthService.canCreateHeaders}, hasVideoEvent=${params.videoEvent != null}',
      name: 'IndividualVideoController', category: LogCategory.video);

  // If user hasn't verified adult content, don't add auth headers
  // This will cause 401 for NSFW videos, triggering the error overlay
  if (!ageVerificationService.isAdultContentVerified) {
    Log.debug('🔐 [AUTH-SYNC] User has NOT verified adult content - returning null',
        name: 'IndividualVideoController', category: LogCategory.video);
    return null;
  }

  // If user has verified but we can't create headers, return null
  if (!blossomAuthService.canCreateHeaders || params.videoEvent == null) {
    Log.debug('🔐 [AUTH-SYNC] Cannot create headers or no video event - returning null',
        name: 'IndividualVideoController', category: LogCategory.video);
    return null;
  }

  // Check if we have cached auth headers for this video
  final cache = ref.read(authHeadersCacheProvider);
  final cachedHeaders = cache[params.videoId];

  Log.debug('🔐 [AUTH-SYNC] Cache check: cacheSize=${cache.length}, hasCachedHeaders=${cachedHeaders != null}',
      name: 'IndividualVideoController', category: LogCategory.video);

  if (cachedHeaders != null) {
    Log.info('🔐 [AUTH-SYNC] ✅ Using cached auth headers for video ${params.videoId}',
        name: 'IndividualVideoController', category: LogCategory.video);
    return cachedHeaders;
  }

  // No cached headers - trigger async generation for next time
  Log.warning('🔐 [AUTH-SYNC] No cached headers found - triggering async generation (this request will fail with 401)',
      name: 'IndividualVideoController', category: LogCategory.video);
  unawaited(_generateAuthHeadersAsync(ref, params));

  // Return null for now - first load after verification will fail with 401
  // but the error overlay retry will have cached headers available
  return null;
}

/// Generate auth headers asynchronously and cache them for future use
Future<void> _generateAuthHeadersAsync(Ref ref, VideoControllerParams params) async {
  try {
    final blossomAuthService = ref.read(blossomAuthServiceProvider);
    final videoEvent = params.videoEvent as dynamic;
    final sha256 = videoEvent.sha256 as String?;

    if (sha256 == null || sha256.isEmpty) {
      return;
    }

    // Extract server URL from video URL
    String? serverUrl;
    try {
      final uri = Uri.parse(params.videoUrl);
      serverUrl = '${uri.scheme}://${uri.host}';
    } catch (e) {
      Log.warning('Failed to parse video URL for server: $e',
          name: 'IndividualVideoController', category: LogCategory.video);
      return;
    }

    // Generate auth header
    final authHeader = await blossomAuthService.createGetAuthHeader(
      sha256Hash: sha256,
      serverUrl: serverUrl,
    );

    if (authHeader != null) {
      // Cache the header for future use
      final cache = {...ref.read(authHeadersCacheProvider)};
      cache[params.videoId] = {'Authorization': authHeader};
      ref.read(authHeadersCacheProvider.notifier).state = cache;

      Log.info('✅ Cached auth header for video ${params.videoId}',
          name: 'IndividualVideoController', category: LogCategory.video);
    }
  } catch (error) {
    Log.debug('Failed to generate auth headers: $error',
        name: 'IndividualVideoController', category: LogCategory.video);
  }
}

/// Cache video with authentication if needed for NSFW content
Future<dynamic> _cacheVideoWithAuth(
  Ref ref,
  VideoCacheManager videoCache,
  VideoControllerParams params,
) async {
  // Get tracker for broken video handling
  BrokenVideoTracker? tracker;
  try {
    tracker = await ref.read(brokenVideoTrackerProvider.future);
  } catch (e) {
    Log.warning('Failed to get BrokenVideoTracker: $e',
        name: 'IndividualVideoController', category: LogCategory.video);
  }

  // Check if we should add auth headers for NSFW content
  Map<String, String>? authHeaders;

  final ageVerificationService = ref.read(ageVerificationServiceProvider);
  final blossomAuthService = ref.read(blossomAuthServiceProvider);

  Log.debug('🔐 Auth check: verified=${ageVerificationService.isAdultContentVerified}, canCreate=${blossomAuthService.canCreateHeaders}, hasEvent=${params.videoEvent != null}',
      name: 'IndividualVideoController', category: LogCategory.video);

  // If user has verified adult content AND video has sha256 hash, create auth header
  if (ageVerificationService.isAdultContentVerified &&
      blossomAuthService.canCreateHeaders &&
      params.videoEvent != null) {
    final videoEvent = params.videoEvent as dynamic;
    final sha256 = videoEvent.sha256 as String?;

    Log.debug('🔐 Video sha256: $sha256',
        name: 'IndividualVideoController', category: LogCategory.video);

    if (sha256 != null && sha256.isNotEmpty) {
      Log.debug('🔐 Creating Blossom auth header for video cache request',
          name: 'IndividualVideoController', category: LogCategory.video);

      // Extract server URL from video URL for auth
      String? serverUrl;
      try {
        final uri = Uri.parse(params.videoUrl);
        serverUrl = '${uri.scheme}://${uri.host}';
      } catch (e) {
        Log.warning('Failed to parse video URL for server: $e',
            name: 'IndividualVideoController', category: LogCategory.video);
      }

      final authHeader = await blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256,
        serverUrl: serverUrl,
      );

      if (authHeader != null) {
        authHeaders = {'Authorization': authHeader};
        Log.info('✅ Added Blossom auth header for NSFW video cache',
            name: 'IndividualVideoController', category: LogCategory.video);
      }
    }
  }

  // Cache video with optional auth headers
  return videoCache.cacheVideo(
    params.videoUrl,
    params.videoId,
    brokenVideoTracker: tracker,
    authHeaders: authHeaders,
  );
}

/// Check if error indicates a 401 Unauthorized (likely NSFW content)
bool _is401Error(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('401') ||
         lowerError.contains('unauthorized') ||
         lowerError.contains('invalid statuscode: 401');
}

/// Check if error indicates a corrupted cache file
bool _isCacheCorruption(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('osstatus error -12848') ||
         lowerError.contains('media may be damaged') ||
         lowerError.contains('cannot open') ||
         (lowerError.contains('failed to load video') && lowerError.contains('damaged'));
}

/// Check if error indicates a broken/non-functional video
bool _isVideoError(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('404') ||
         lowerError.contains('not found') ||
         lowerError.contains('invalid statuscode: 404') ||
         lowerError.contains('httpexception') ||
         lowerError.contains('timeout') ||
         lowerError.contains('connection refused') ||
         lowerError.contains('network error') ||
         lowerError.contains('video initialization timed out');
}

/// Provider for video loading state
@riverpod
VideoLoadingState videoLoadingState(
  Ref ref,
  VideoControllerParams params,
) {
  final controller = ref.watch(individualVideoControllerProvider(params));

  if (controller.value.hasError) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: false,
      hasError: true,
      errorMessage: controller.value.errorDescription,
    );
  }

  if (controller.value.isInitialized) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: true,
      hasError: false,
    );
  }

  return VideoLoadingState(
    videoId: params.videoId,
    isLoading: true,
    isInitialized: false,
    hasError: false,
  );
}

// NOTE: PrewarmManager removed - using Riverpod-native lifecycle (onCancel/onResume + 30s timeout)
// NOTE: Active video state moved to active_video_provider.dart (route-reactive derived providers)
