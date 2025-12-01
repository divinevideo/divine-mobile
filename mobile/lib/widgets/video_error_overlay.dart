// ABOUTME: Error overlay widget for video playback failures
// ABOUTME: Handles 401 age-restricted content and general playback errors with retry functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Error overlay shown when video playback fails
///
/// Displays different UI for 401 errors (age-restricted) vs other errors:
/// - 401: Lock icon + "Age-restricted content" + "Verify Age" button
/// - Other: Error icon + error message + "Retry" button
class VideoErrorOverlay extends ConsumerWidget {
  const VideoErrorOverlay({
    super.key,
    required this.video,
    required this.controllerParams,
    required this.errorDescription,
    required this.isActive,
  });

  final VideoEvent video;
  final VideoControllerParams controllerParams;
  final String errorDescription;
  final bool isActive;

  /// Check for 401 Unauthorized - likely NSFW content
  bool get _is401Error {
    final lowerError = errorDescription.toLowerCase();
    return lowerError.contains('401') || lowerError.contains('unauthorized');
  }

  /// Translate error messages to user-friendly text
  String get _errorMessage {
    final lowerError = errorDescription.toLowerCase();

    if (lowerError.contains('404') || lowerError.contains('not found')) {
      return 'Video not found';
    }
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Network error';
    }
    if (lowerError.contains('timeout')) {
      return 'Loading timeout';
    }
    if (lowerError.contains('byte range') || lowerError.contains('coremediaerrordomain')) {
      return 'Video format error\n(Try again or use different browser)';
    }
    if (lowerError.contains('format') || lowerError.contains('codec')) {
      return 'Unsupported video format';
    }

    return 'Video playback error';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show thumbnail as background
        VideoThumbnailWidget(
          video: video,
          fit: BoxFit.cover,
          showPlayIcon: false,
        ),
        // Error overlay (only show on active video)
        if (isActive)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _is401Error ? Icons.lock_outline : Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _is401Error ? 'Age-restricted content' : _errorMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      if (_is401Error) {
                        Log.info('🔐 [AGE-GATE] User tapped Verify Age button for video ${video.id}',
                            name: 'VideoErrorOverlay', category: LogCategory.video);

                        // Show age verification dialog
                        final ageVerificationService = ref.read(ageVerificationServiceProvider);
                        final verified = await ageVerificationService.verifyAdultContentAccess(context);

                        Log.info('🔐 [AGE-GATE] Dialog result: verified=$verified, isAdultContentVerified=${ageVerificationService.isAdultContentVerified}',
                            name: 'VideoErrorOverlay', category: LogCategory.video);

                        if (verified && context.mounted) {
                          // Pre-cache auth headers before retrying
                          // This ensures the retry will have headers available immediately
                          Log.info('🔐 [AGE-GATE] Starting _precacheAuthHeaders for video ${video.id}',
                              name: 'VideoErrorOverlay', category: LogCategory.video);
                          await _precacheAuthHeaders(ref, controllerParams);

                          // Check if headers were actually cached
                          final cachedHeaders = ref.read(authHeadersCacheProvider);
                          final hasHeaders = cachedHeaders.containsKey(video.id);
                          Log.info('🔐 [AGE-GATE] After precache: hasHeaders=$hasHeaders, cacheSize=${cachedHeaders.length}',
                              name: 'VideoErrorOverlay', category: LogCategory.video);

                          // CRITICAL: Only retry if this video is still active
                          // If user swiped away during verification, don't invalidate -
                          // the new active video's controller is already correct
                          final activeVideoId = ref.read(activeVideoIdProvider);
                          Log.info('🔐 [AGE-GATE] Checking active video: activeVideoId=$activeVideoId, thisVideoId=${video.id}, match=${activeVideoId == video.id}',
                              name: 'VideoErrorOverlay', category: LogCategory.video);

                          if (activeVideoId == video.id) {
                            // Video is still active - safe to invalidate and retry
                            if (context.mounted) {
                              Log.info('🔐 [AGE-GATE] Invalidating provider to retry video ${video.id}',
                                  name: 'VideoErrorOverlay', category: LogCategory.video);
                              ref.invalidate(
                                individualVideoControllerProvider(controllerParams),
                              );
                            }
                          } else {
                            // User swiped to different video during verification
                            // Auth headers are cached, so when user swipes back, it will work
                            Log.debug('Age verification completed but video no longer active (active=$activeVideoId, this=${video.id})',
                                name: 'VideoErrorOverlay', category: LogCategory.video);
                          }
                        } else {
                          Log.warning('🔐 [AGE-GATE] Verification failed or context not mounted: verified=$verified, mounted=${context.mounted}',
                              name: 'VideoErrorOverlay', category: LogCategory.video);
                        }
                      } else {
                        // Regular retry for other errors
                        ref.invalidate(
                          individualVideoControllerProvider(controllerParams),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: Text(_is401Error ? 'Verify Age' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Pre-cache authentication headers for a video before retrying
/// This ensures the retry will have headers available immediately without a second 401 failure
Future<void> _precacheAuthHeaders(WidgetRef ref, VideoControllerParams controllerParams) async {
  Log.debug('🔐 [PRECACHE] Starting precache for video ${controllerParams.videoId}',
      name: 'VideoErrorOverlay', category: LogCategory.video);
  try {
    final blossomAuthService = ref.read(blossomAuthServiceProvider);

    if (!blossomAuthService.canCreateHeaders) {
      Log.warning('🔐 [PRECACHE] Cannot create headers - canCreateHeaders=false',
          name: 'VideoErrorOverlay', category: LogCategory.video);
      return;
    }

    if (controllerParams.videoEvent == null) {
      Log.warning('🔐 [PRECACHE] No videoEvent on controllerParams',
          name: 'VideoErrorOverlay', category: LogCategory.video);
      return;
    }

    final videoEvent = controllerParams.videoEvent as dynamic;
    final sha256 = videoEvent.sha256 as String?;

    if (sha256 == null || sha256.isEmpty) {
      Log.warning('🔐 [PRECACHE] No sha256 hash on video event',
          name: 'VideoErrorOverlay', category: LogCategory.video);
      return;
    }

    // Extract server URL from video URL
    String? serverUrl;
    try {
      final uri = Uri.parse(controllerParams.videoUrl);
      serverUrl = '${uri.scheme}://${uri.host}';
      Log.debug('🔐 [PRECACHE] Extracted serverUrl: $serverUrl',
          name: 'VideoErrorOverlay', category: LogCategory.video);
    } catch (e) {
      Log.warning('🔐 [PRECACHE] Failed to parse video URL: $e',
          name: 'VideoErrorOverlay', category: LogCategory.video);
      return;
    }

    // Generate auth header
    Log.debug('🔐 [PRECACHE] Generating auth header with sha256=${sha256.substring(0, 16)}...',
        name: 'VideoErrorOverlay', category: LogCategory.video);
    final authHeader = await blossomAuthService.createGetAuthHeader(
      sha256Hash: sha256,
      serverUrl: serverUrl,
    );

    if (authHeader != null) {
      // Cache the header for immediate use
      final cache = {...ref.read(authHeadersCacheProvider)};
      cache[controllerParams.videoId] = {'Authorization': authHeader};
      ref.read(authHeadersCacheProvider.notifier).state = cache;
      Log.info('🔐 [PRECACHE] Successfully cached auth header for video ${controllerParams.videoId}',
          name: 'VideoErrorOverlay', category: LogCategory.video);
    } else {
      Log.warning('🔐 [PRECACHE] createGetAuthHeader returned null',
          name: 'VideoErrorOverlay', category: LogCategory.video);
    }
  } catch (e) {
    // Log error but don't block retry - retry will attempt without cached headers
    Log.error('🔐 [PRECACHE] Exception during precache: $e',
        name: 'VideoErrorOverlay', category: LogCategory.video);
  }
}
