// ABOUTME: Video feed item using individual controller architecture
// ABOUTME: Each video gets its own controller with automatic lifecycle management via Riverpod autoDispose

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart'; // For individualVideoControllerProvider only
import 'package:openvine/providers/active_video_provider.dart'; // For isVideoActiveProvider (router-driven)
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/screens/comments_screen.dart';
import 'package:openvine/services/visibility_tracker.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/ui/overlay_policy.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/video_error_overlay.dart';
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/badge_explanation_modal.dart';

/// Video feed item using individual controller architecture
class VideoFeedItem extends ConsumerStatefulWidget {
  const VideoFeedItem({
    super.key,
    required this.video,
    required this.index,
    this.onTap,
    this.forceShowOverlay = false,
    this.hasBottomNavigation = true,
    this.contextTitle,
    this.disableAutoplay = false,
  });

  final VideoEvent video;
  final int index;
  final VoidCallback? onTap;
  final bool forceShowOverlay;
  final bool hasBottomNavigation;
  final String? contextTitle;
  final bool disableAutoplay;

  @override
  ConsumerState<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends ConsumerState<VideoFeedItem> {
  int _playbackGeneration = 0; // Prevents race conditions with rapid state changes
  DateTime? _lastTapTime; // Debounce rapid taps to prevent phantom pauses

  @override
  void initState() {
    super.initState();

    // Listen for active state changes to control playback
    // Active state is now derived from URL + feed + foreground (pure provider)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      // Check initial state and start playback if already active (unless autoplay is disabled)
      if (!widget.disableAutoplay) {
        final isActive = ref.read(isVideoActiveProvider(widget.video.id));
        Log.info('🎬 VideoFeedItem.initState postFrameCallback: videoId=${widget.video.id}, isActive=$isActive',
            name: 'VideoFeedItem', category: LogCategory.video);
        if (isActive) {
          _handlePlaybackChange(true);
        }
      } else {
        Log.info('🎬 VideoFeedItem.initState: autoplay disabled for ${widget.video.id}',
            name: 'VideoFeedItem', category: LogCategory.video);
      }

      // Listen for future changes (unless autoplay is disabled)
      if (!widget.disableAutoplay) {
        ref.listenManual(
          isVideoActiveProvider(widget.video.id),
          (prev, next) {
            Log.info('🔄 VideoFeedItem active state changed: videoId=${widget.video.id}, prev=$prev → next=$next',
                name: 'VideoFeedItem', category: LogCategory.video);
            _handlePlaybackChange(next);
          },
        );
      }
    });
  }

  // No dispose needed - derived provider handles state automatically

  /// Handle playback state changes with generation counter to prevent race conditions
  void _handlePlaybackChange(bool shouldPlay) {
    final gen = ++_playbackGeneration;

    // Get stack trace to understand why playback is changing
    final stackTrace = StackTrace.current;
    final stackLines = stackTrace.toString().split('\n').take(5).join('\n');

    try {
      final controllerParams = VideoControllerParams(
        videoId: widget.video.id,
        videoUrl: widget.video.videoUrl!,
        videoEvent: widget.video,
      );
      final controller = ref.read(individualVideoControllerProvider(controllerParams));

      if (shouldPlay) {
        Log.info('▶️ PLAY REQUEST for video ${widget.video.id} | gen=$gen | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying}\nCalled from:\n$stackLines',
            name: 'VideoFeedItem', category: LogCategory.video);

        Log.info('🔍 Play condition check: isInitialized=${controller.value.isInitialized}, isPlaying=${controller.value.isPlaying}, hasError=${controller.value.hasError}',
            name: 'VideoFeedItem', category: LogCategory.video);

        if (controller.value.isInitialized && !controller.value.isPlaying) {
          // Controller ready - play immediately
          Log.info('▶️ Widget starting video ${widget.video.id} (controller already initialized)',
              name: 'VideoFeedItem', category: LogCategory.ui);
          controller.play().then((_) {
            if (gen != _playbackGeneration) {
              Log.debug('⏭️ Ignoring stale play() completion for ${widget.video.id}',
                  name: 'VideoFeedItem', category: LogCategory.ui);
            }
          }).catchError((error) {
            if (gen == _playbackGeneration) {
              Log.error('❌ Widget failed to play video ${widget.video.id}: $error',
                  name: 'VideoFeedItem', category: LogCategory.ui);
            }
          });
        } else if (!controller.value.isInitialized && !controller.value.hasError) {
          // Controller not ready yet - wait for initialization then play
          Log.debug('⏳ Waiting for initialization of ${widget.video.id} before playing',
              name: 'VideoFeedItem', category: LogCategory.ui);

          void checkAndPlay() {
            // Safety check: don't use ref if widget is disposed
            if (!mounted) {
              Log.debug('⏭️ Ignoring initialization callback for ${widget.video.id} (widget disposed)',
                  name: 'VideoFeedItem', category: LogCategory.ui);
              controller.removeListener(checkAndPlay);
              return;
            }

            // Check if video is still active (even if generation changed)
            final stillActive = ref.read(isVideoActiveProvider(widget.video.id));

            if (!stillActive) {
              // Video no longer active, don't play
              Log.debug('⏭️ Ignoring initialization callback for ${widget.video.id} (no longer active)',
                  name: 'VideoFeedItem', category: LogCategory.ui);
              controller.removeListener(checkAndPlay);
              return;
            }

            if (gen != _playbackGeneration) {
              // Generation changed but video still active - this can happen if state toggled quickly
              Log.debug('⏭️ Ignoring stale initialization callback for ${widget.video.id} (generation mismatch)',
                  name: 'VideoFeedItem', category: LogCategory.ui);
              return;
            }

            if (controller.value.isInitialized && !controller.value.isPlaying) {
              Log.info('▶️ Widget starting video ${widget.video.id} after initialization',
                  name: 'VideoFeedItem', category: LogCategory.ui);
              controller.play().catchError((error) {
                if (gen == _playbackGeneration) {
                  Log.error('❌ Widget failed to play video ${widget.video.id} after init: $error',
                      name: 'VideoFeedItem', category: LogCategory.ui);
                }
              });
              controller.removeListener(checkAndPlay);
            }
          }

          // Listen for initialization completion
          controller.addListener(checkAndPlay);
          // Clean up listener after first initialization or when generation changes
          Future.delayed(const Duration(seconds: 10), () {
            controller.removeListener(checkAndPlay);
          });
        } else {
          Log.info('❓ PLAY REQUEST for video ${widget.video.id} - No action taken | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying} | hasError=${controller.value.hasError}',
              name: 'VideoFeedItem', category: LogCategory.video);
        }
      } else if (!shouldPlay && controller.value.isPlaying) {
        Log.info('⏸️ PAUSE REQUEST for video ${widget.video.id} | gen=$gen | initialized=${controller.value.isInitialized} | isPlaying=${controller.value.isPlaying}\nCalled from:\n$stackLines',
            name: 'VideoFeedItem', category: LogCategory.video);
        controller.pause().then((_) {
          if (gen != _playbackGeneration) {
            Log.debug('⏭️ Ignoring stale pause() completion for ${widget.video.id}',
                name: 'VideoFeedItem', category: LogCategory.ui);
          }
        }).catchError((error) {
          if (gen == _playbackGeneration) {
            Log.error('❌ Widget failed to pause video ${widget.video.id}: $error',
                name: 'VideoFeedItem', category: LogCategory.ui);
          }
        });
      }
    } catch (e) {
      Log.error('❌ Error in playback change handler: $e',
          name: 'VideoFeedItem', category: LogCategory.ui);
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    Log.debug('🏗️ VideoFeedItem.build() for video ${video.id}..., index: ${widget.index}',
        name: 'VideoFeedItem', category: LogCategory.ui);

    // Skip rendering if no video URL
    if (video.videoUrl == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white, size: 48),
        ),
      );
    }

    // Watch if this video is currently active
    final isActive = ref.watch(isVideoActiveProvider(video.id));

    Log.debug('📱 VideoFeedItem state: isActive=$isActive',
        name: 'VideoFeedItem', category: LogCategory.ui);

    // Check if tracker is Noop - if so, skip VisibilityDetector entirely to prevent timer leaks in tests
    final tracker = ref.watch(visibilityTrackerProvider);

    // Compute overlay visibility with policy override
    final policy = ref.watch(overlayPolicyProvider);
    bool overlayVisible = widget.forceShowOverlay || isActive;

    // Override by policy
    switch (policy) {
      case OverlayPolicy.alwaysOn:
        overlayVisible = true;
        break;
      case OverlayPolicy.alwaysOff:
        overlayVisible = false;
        break;
      case OverlayPolicy.auto:
        // keep computed overlayVisible
        break;
    }

    assert(() {
      debugPrint('[OVERLAY] id=${video.id} policy=$policy active=$isActive -> overlay=$overlayVisible');
      return true;
    }());

    final child = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Lighter debounce - ignore taps within 150ms of previous tap
          // 300ms was too aggressive and was swallowing legitimate pause taps
          final now = DateTime.now();
          if (_lastTapTime != null && now.difference(_lastTapTime!) < const Duration(milliseconds: 150)) {
            Log.debug('⏭️ Ignoring rapid tap (debounced) for ${video.id}...',
                name: 'VideoFeedItem', category: LogCategory.ui);
            return;
          }
          _lastTapTime = now;

          Log.debug('📱 Tap detected on VideoFeedItem for ${video.id}...',
              name: 'VideoFeedItem', category: LogCategory.ui);
          try {
            final controllerParams = VideoControllerParams(
              videoId: video.id,
              videoUrl: video.videoUrl!,
              videoEvent: video,
            );
            final controller = ref.read(individualVideoControllerProvider(controllerParams));

            Log.debug('📱 Tap state: isActive=$isActive, isPlaying=${controller.value.isPlaying}, isInitialized=${controller.value.isInitialized}',
                name: 'VideoFeedItem', category: LogCategory.ui);

            if (isActive) {
              // Toggle play/pause only if currently active and initialized
              if (controller.value.isInitialized) {
                if (controller.value.isPlaying) {
                  Log.info('⏸️ Tap pausing video ${video.id}...',
                      name: 'VideoFeedItem', category: LogCategory.ui);
                  controller.pause();
                } else {
                  Log.info('▶️ Tap playing video ${video.id}...',
                      name: 'VideoFeedItem', category: LogCategory.ui);
                  controller.play();
                }
              } else {
                Log.debug('⏳ Tap ignored - video ${video.id}... not yet initialized',
                    name: 'VideoFeedItem', category: LogCategory.ui);
              }
            } else {
              // Tapping inactive video: Navigate to this video's index
              // Active state is derived from URL, so navigation will update it
              Log.info('🎯 Tap navigating to video ${video.id}... at index ${widget.index}',
                  name: 'VideoFeedItem', category: LogCategory.ui);

              // Read current route context to determine which route type to navigate to
              final pageContext = ref.read(pageContextProvider);
              pageContext.whenData((ctx) {
                // Build new route with same type but different index
                final newRoute = RouteContext(
                  type: ctx.type,
                  videoIndex: widget.index,
                  npub: ctx.npub,
                  hashtag: ctx.hashtag,
                );

                Log.info('🎯 Navigating to route: ${buildRoute(newRoute)}',
                    name: 'VideoFeedItem', category: LogCategory.ui);

                context.go(buildRoute(newRoute));
              });
            }
            widget.onTap?.call();
          } catch (e) {
            Log.error('❌ Error in VideoFeedItem tap handler for ${video.id}...: $e',
                name: 'VideoFeedItem', category: LogCategory.ui);
          }
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Per-item video controller rendering when active
              if (isActive)
                Consumer(
                  builder: (context, ref, child) {
                    final controllerParams = VideoControllerParams(
                      videoId: video.id,
                      videoUrl: video.videoUrl!,
                      videoEvent: video,
                    );
                    final controller = ref.watch(
                      individualVideoControllerProvider(controllerParams),
                    );

                    // Only track metrics for active videos
                    final videoWidget = ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        // Let the individual controller handle autoplay based on active state
                        // Don't interfere with playback control here

                        // Check for video error state
                        if (value.hasError) {
                          return VideoErrorOverlay(
                            video: video,
                            controllerParams: controllerParams,
                            errorDescription: value.errorDescription ?? '',
                            isActive: isActive,
                          );
                        }

                        if (!value.isInitialized) {
                          // Show thumbnail/blurhash while the video initializes
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              VideoThumbnailWidget(
                                video: video,
                                fit: BoxFit.cover,
                                showPlayIcon: false,
                              ),
                              // Only show loading indicator on active video
                              if (isActive)
                                const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  ),
                                ),
                            ],
                          );
                        }

                        // Use BoxFit.contain for square/landscape videos to avoid cropping
                        // Use BoxFit.cover for portrait videos to fill the screen
                        final aspectRatio = value.size.width / value.size.height;
                        final isPortraitVideo = aspectRatio < 0.9; // Portrait if width < height (with 10% tolerance)


                        return SizedBox.expand(
                          child: Container(
                            color: Colors.black,
                            child: FittedBox(
                              fit: isPortraitVideo ? BoxFit.cover : BoxFit.contain,
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                                width: value.size.width == 0 ? 1 : value.size.width,
                                height: value.size.height == 0 ? 1 : value.size.height,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    VideoPlayer(controller),
                                    // Centered play button when paused
                                    if (!value.isPlaying)
                                      Center(
                                        child: Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            size: 56,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );

                    // Wrap with VideoMetricsTracker only for active videos
                    return isActive
                        ? VideoMetricsTracker(
                            video: video,
                            controller: controller,
                            child: videoWidget,
                          )
                        : videoWidget;
                  },
                )
              else
                // Not active or prewarmed: show thumbnail/blurhash with play overlay
                VideoThumbnailWidget(
                  video: video,
                  fit: BoxFit.cover,
                  showPlayIcon: true,
                ),

              // Video overlay with actions
              VideoOverlayActions(
                video: video,
                isVisible: overlayVisible,
                isActive: isActive,
                hasBottomNavigation: widget.hasBottomNavigation,
                contextTitle: widget.contextTitle,
              ),
            ],
          ),
        ),
      );

    // If tracker is Noop, return child directly (avoids VisibilityDetector's internal timers in tests)
    if (tracker is NoopVisibilityTracker) return child;

    // In production, wrap with VisibilityDetector for analytics
    return VisibilityDetector(
      key: Key('vis-${video.id}'),
      onVisibilityChanged: (info) {
        final isVisible = info.visibleFraction > 0.7;
        Log.debug('👁️ Visibility changed: ${video.id}... fraction=${info.visibleFraction.toStringAsFixed(3)}, isVisible=$isVisible',
            name: 'VideoFeedItem', category: LogCategory.ui);

        if (isVisible) {
          tracker.onVisible(video.id, fractionVisible: info.visibleFraction);
        } else {
          tracker.onInvisible(video.id);
        }
      },
      child: child,
    );
  }

}

/// Video overlay actions widget with working functionality
class VideoOverlayActions extends ConsumerWidget {
  const VideoOverlayActions({
    super.key,
    required this.video,
    required this.isVisible,
    required this.isActive,
    this.hasBottomNavigation = true,
    this.contextTitle,
  });

  final VideoEvent video;
  final bool isVisible;
  final bool isActive;
  final bool hasBottomNavigation;
  final String? contextTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isVisible) return const SizedBox();

    final socialState = ref.watch(socialProvider);
    final isLiked = socialState.isLiked(video.id);
    final isLikeInProgress = socialState.isLikeInProgress(video.id);
    final likeCount = socialState.likeCounts[video.id] ?? 0;

    // Stack does not block pointer events by default - taps pass through to GestureDetector below
    // Only interactive elements (buttons, chips with GestureDetector) absorb taps
    return Stack(
        children: [
        // Username and follow button at top left
        Positioned(
          top: MediaQuery.of(context).viewPadding.top + 16,
          left: 16,
          child: Consumer(
            builder: (context, ref, _) {
              // Watch the reactive user profile state
              // This will rebuild when profiles are added to the cache
              final profileState = ref.watch(userProfileProvider);
              final profile = profileState.getCachedProfile(video.pubkey);
              final display = profile?.bestDisplayName ?? profile?.displayName ?? profile?.name ?? 'Loading...';

              // Trigger async profile fetch if not cached (doesn't block UI)
              if (profile == null && !profileState.shouldSkipFetch(video.pubkey)) {
                Future.microtask(() {
                  if (ref.exists(userProfileProvider)) {
                    ref.read(userProfileProvider.notifier).fetchProfile(video.pubkey);
                  }
                });
              }

              final authService = ref.watch(authServiceProvider);
              final currentUserPubkey = authService.currentPublicKeyHex;
              final isOwnVideo = currentUserPubkey == video.pubkey;

              final socialState = ref.watch(socialProvider);
              final isFollowing = socialState.isFollowing(video.pubkey);
              final isFollowInProgress = socialState.isFollowInProgress(video.pubkey);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Username chip (tappable to go to profile)
                  GestureDetector(
                    onTap: () {
                      Log.info('👤 User tapped profile: videoId=${video.id}, authorPubkey=${video.pubkey}',
                        name: 'VideoFeedItem', category: LogCategory.ui);
                      context.goProfileGrid(video.pubkey);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            display,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Follow button next to username (only for other users' videos)
                  if (!isOwnVideo) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isFollowInProgress ? null : () async {
                        Log.info(
                          '👤 Follow button tapped for ${video.pubkey}',
                          name: 'VideoFeedItem',
                          category: LogCategory.ui,
                        );
                        if (isFollowing) {
                          await ref.read(socialProvider.notifier).unfollowUser(video.pubkey);
                        } else {
                          await ref.read(socialProvider.notifier).followUser(video.pubkey);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (isFollowing ? Colors.grey[800] : VineTheme.vineGreen)?.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: (isFollowing ? Colors.grey[600] : VineTheme.vineGreen)?.withValues(alpha: 0.5) ?? Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: isFollowInProgress
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        // ProofMode and Vine badges in upper right corner (tappable)
        Positioned(
          top: MediaQuery.of(context).viewPadding.top + 16,
          right: 16,
          child: GestureDetector(
            onTap: () {
              _showBadgeExplanationModal(context, ref, video);
            },
            child: ProofModeBadgeRow(
              video: video,
              size: BadgeSize.small,
            ),
          ),
        ),
        // Gradient background for bottom section (metadata + action buttons)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: EdgeInsets.only(
                bottom: hasBottomNavigation ? 80 : 16,
                top: 100,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
        // Video title overlay at bottom left
        Positioned(
          bottom: hasBottomNavigation ? 80 : 16,
          left: 16,
          right: 80, // Leave space for action buttons
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Video title with clickable hashtags
                ClickableHashtagText(
                  text: video.content.isNotEmpty ? video.content : video.title ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  hashtagStyle: TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 8,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 4,
                        color: Colors.black,
                      ),
                    ],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Show original loop count if available
                if (video.originalLoops != null && video.originalLoops! > 0) ...[
                  Text(
                    '🔁 ${StringUtils.formatCompactNumber(video.originalLoops!)} loops',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 0),
                          blurRadius: 6,
                          color: Colors.black,
                        ),
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          ),
        ),
        // Action buttons at bottom right
        Positioned(
          bottom: hasBottomNavigation ? 80 : 16,
          right: 16,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
            ignoring: false, // Action buttons SHOULD receive taps
            child: Column(
              children: [
            // Like button
            Column(
            children: [
              _buildCircularIconButton(
                onPressed: isLikeInProgress ? () {} : () async {
                  Log.info(
                    '❤️ Like button tapped for ${video.id}',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                  await ref.read(socialProvider.notifier)
                    .toggleLike(video.id, video.pubkey);
                },
                icon: isLikeInProgress
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isLiked ? Icons.favorite : Icons.favorite_outline,
                      color: isLiked ? Colors.red : Colors.white,
                      size: 32,
                    ),
              ),
              // Show total like count: new likes + original Vine likes
              if (likeCount > 0 || (video.originalLikes != null && video.originalLikes! > 0)) ...[
                const SizedBox(height: 0),
                Text(
                  StringUtils.formatCompactNumber(likeCount + (video.originalLikes ?? 0)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Comment button with count
          Column(
            children: [
              _buildCircularIconButton(
                onPressed: () {
                  Log.info(
                    '💬 Comment button tapped for ${video.id}',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CommentsScreen(videoEvent: video),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.comment_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              // Show original comment count if available
              if (video.originalComments != null && video.originalComments! > 0) ...[
                const SizedBox(height: 0),
                Text(
                  StringUtils.formatCompactNumber(video.originalComments!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 0),
                        blurRadius: 6,
                        color: Colors.black,
                      ),
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Share button with label
          Column(
            children: [
              _buildCircularIconButton(
                onPressed: () {
                  Log.info(
                    '📤 Share button tapped for ${video.id}',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                  _showShareMenu(context, video);
                },
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 0),
              const Text(
                'Share',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 0),
                      blurRadius: 6,
                      color: Colors.black,
                    ),
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Flag/Report button for content moderation
          Column(
            children: [
              _buildCircularIconButton(
                onPressed: () {
                  Log.info(
                    '🚩 Report button tapped for ${video.id}',
                    name: 'VideoFeedItem',
                    category: LogCategory.ui,
                  );
                  showDialog(
                    context: context,
                    builder: (context) => ReportContentDialog(video: video),
                  );
                },
                icon: const Icon(
                  Icons.flag_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 0),
              const Text(
                'Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 0),
                      blurRadius: 6,
                      color: Colors.black,
                    ),
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Edit button (only show for owned videos when feature is enabled)
          _buildEditButton(context, ref, video),
              ],
            ),
          ),
          ),
        ),
      ],
    );
  }

  /// Build icon button with semi-transparent circular background
  Widget _buildCircularIconButton({
    required VoidCallback onPressed,
    required Widget icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        padding: EdgeInsets.zero,
      ),
    );
  }

  /// Build edit button if video is owned by current user and feature flag is enabled
  Widget _buildEditButton(BuildContext context, WidgetRef ref, VideoEvent video) {
    // Check feature flag
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(FeatureFlag.enableVideoEditorV1);

    if (!isEditorEnabled) {
      return const SizedBox.shrink();
    }

    // Check ownership
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo = currentUserPubkey != null && currentUserPubkey == video.pubkey;

    if (!isOwnVideo) {
      return const SizedBox.shrink();
    }

    // Show edit button
    return Column(
      children: [
        const SizedBox(height: 16),
        IconButton(
          onPressed: () {
            Log.info(
              '✏️ Edit button tapped for ${video.id}',
              name: 'VideoFeedItem',
              category: LogCategory.ui,
            );

            // Show edit dialog directly (works on all platforms)
            showEditDialogForVideo(context, video);
          },
          tooltip: 'Edit video',
          icon: const Icon(
            Icons.edit,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  void _showShareMenu(BuildContext context, VideoEvent video) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(video: video),
    );
  }

  Future<void> _showBadgeExplanationModal(BuildContext context, WidgetRef ref, VideoEvent video) async {
    // Pause video before showing modal
    bool wasPaused = false;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      final controller = ref.read(individualVideoControllerProvider(controllerParams));
      if (controller.value.isPlaying) {
        await controller.pause();
        wasPaused = true;
        Log.info('🎬 Paused video for badge modal',
            name: 'VideoFeedItem', category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('Failed to pause video for modal: $e',
          name: 'VideoFeedItem', category: LogCategory.ui);
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => BadgeExplanationModal(video: video),
    );

    // Resume video after modal closes if it was playing
    if (wasPaused) {
      try {
        final controllerParams = VideoControllerParams(
          videoId: video.id,
          videoUrl: video.videoUrl!,
          videoEvent: video,
        );
        final controller = ref.read(individualVideoControllerProvider(controllerParams));
        final isActive = ref.read(isVideoActiveProvider(video.id));

        // Only resume if video is still active (not scrolled away)
        if (isActive && controller.value.isInitialized && !controller.value.isPlaying) {
          await controller.play();
          Log.info('🎬 Resumed video after badge modal closed',
              name: 'VideoFeedItem', category: LogCategory.ui);
        }
      } catch (e) {
        Log.error('Failed to resume video after modal: $e',
            name: 'VideoFeedItem', category: LogCategory.ui);
      }
    }
  }
}