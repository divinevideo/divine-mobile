// ABOUTME: Skeleton thumbnail grid shown in the videos tab while the cold
// ABOUTME: profile-feed load is in flight, mirroring the real grid layout.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton placeholder for the videos tab grid.
///
/// Rendered while the cold feed load is in flight and no videos are available
/// yet. Uses the same 3-column [SliverGrid] geometry as the real
/// `ProfileVideosGrid` so transitioning to loaded content does not pop, and a
/// [CustomScrollView] body so it nests correctly inside the profile's
/// `NestedScrollView`. A single top-level [Skeletonizer] shimmers every
/// placeholder cell.
class ProfileVideosGridSkeleton extends StatelessWidget {
  const ProfileVideosGridSkeleton({this.cellCount = 12, super.key});

  /// Number of placeholder thumbnails to render.
  final int cellCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      effect: vineSkeletonEffectOf(context),
      child: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewPaddingOf(context).bottom,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => const ProfileTabThumbnailPlaceholder(),
                childCount: cellCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
