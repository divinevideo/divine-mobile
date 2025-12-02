// ABOUTME: Simple video thumbnail tile for explore screen
// ABOUTME: Shows clean thumbnail with title/hashtag overlay - full screen handled by parent

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/proofmode_badge.dart';
import 'package:openvine/widgets/proofmode_badge_row.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Video thumbnail tile for explore screen
/// - Shows clean thumbnail with title/hashtag overlay
/// - Parent screen handles full-screen overlay when tapped
class VideoExploreTile extends ConsumerWidget {
  // Not used anymore but kept for API compatibility

  const VideoExploreTile({
    required this.video,
    required this.isActive,
    super.key,
    this.onTap,
    this.onClose,
    this.showTextOverlay = true,
    this.borderRadius = 8.0,
  });
  final VideoEvent video;
  final bool isActive; // Not used anymore but kept for API compatibility
  final VoidCallback? onTap;
  final VoidCallback? onClose;
  final bool showTextOverlay;
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Use LayoutBuilder to get actual dimensions and pass to thumbnail
            LayoutBuilder(
              builder: (context, constraints) {
                return VideoThumbnailWidget(
                  video: video,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  fit: BoxFit.cover,
                  showPlayIcon: false,
                  borderRadius: BorderRadius.circular(borderRadius),
                );
              },
            ),

            // ProofMode and Vine badges
            Positioned(
              top: 8,
              left: 8,
              child: ProofModeBadgeRow(video: video, size: BadgeSize.small),
            ),

            // Video info overlay - conditionally shown
            if (showTextOverlay)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(borderRadius),
                      bottomRight: Radius.circular(borderRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Username/Creator info
                      _buildCreatorInfo(ref),
                      const SizedBox(height: 4),
                      if (video.title != null) ...[
                        Text(
                          video.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (video.hashtags.isNotEmpty)
                        Text(
                          video.hashtags.map((tag) => '#$tag').join(' '),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatorInfo(WidgetRef ref) {
    final profileService = ref.watch(userProfileServiceProvider);
    final profile = profileService.getCachedProfile(video.pubkey);
    final displayName = profile?.bestDisplayName ?? 'Loading...';

    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Log.verbose(
            'Navigating to profile from explore tile: ${video.pubkey}',
            name: 'VideoExploreTile',
            category: LogCategory.ui,
          );
          // Navigate to profile tab using GoRouter
          context.goProfile(video.pubkey, 0);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Add NIP-05 verification badge if verified
            if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 8),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
