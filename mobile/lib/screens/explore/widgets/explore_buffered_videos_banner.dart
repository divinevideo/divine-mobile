// ABOUTME: Pill banner shown on the New/Trending explore tabs to load buffered
// ABOUTME: videos when new content has arrived.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:unified_logger/unified_logger.dart';

/// Banner that surfaces buffered new videos and loads them on tap.
class ExploreBufferedVideosBanner extends ConsumerWidget {
  /// Creates the buffered-videos banner.
  const ExploreBufferedVideosBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bufferedCount = ref.watch(bufferedVideoCountProvider);

    if (bufferedCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Semantics(
          label: context.l10n.exploreLoadNewVideosLabel(bufferedCount),
          button: true,
          child: GestureDetector(
            onTap: () {
              // Load buffered videos
              ref.read(videoEventsProvider.notifier).loadBufferedVideos();
              Log.info(
                '🔄 ExploreScreen: Loaded $bufferedCount buffered videos',
                category: LogCategory.video,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: VineTheme.vineGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: context.vineColors.background.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DivineIcon(
                    icon: DivineIconName.arrowUp,
                    color: context.vineColors.background,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.exploreNewVideosCount(bufferedCount),
                    style: TextStyle(
                      color: context.vineColors.background,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
