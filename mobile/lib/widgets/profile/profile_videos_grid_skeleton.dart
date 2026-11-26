// ABOUTME: Skeleton thumbnail grid shown in the videos tab while the cold
// ABOUTME: profile-feed load is in flight, mirroring the real grid layout.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/profile/profile_masonry_grid.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton placeholder for the videos tab grid.
///
/// Rendered while the cold feed load is in flight and no videos are available
/// yet. Uses the same [ProfileMasonryGrid] as the real `ProfileVideosGrid`,
/// with as many columns, so transitioning to loaded content does not pop, and
/// a [CustomScrollView] body so it nests correctly inside the profile's
/// `NestedScrollView`. A single top-level [Skeletonizer] shimmers every
/// placeholder cell.
class ProfileVideosGridSkeleton extends StatelessWidget {
  const ProfileVideosGridSkeleton({
    this.rowCount = 4,
    this.scrollViewKey,
    super.key,
  });

  /// Number of rows of placeholder thumbnails; each row is as wide as the
  /// real grid's.
  final int rowCount;

  /// Key for the wrapping [CustomScrollView].
  ///
  /// See `ProfileTabLoadingState.scrollViewKey`.
  final GlobalKey? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final layout = context.adaptiveLayout;
    return Skeletonizer(
      effect: vineSkeletonEffectOf(context),
      child: LayoutBuilder(
        builder: (context, constraints) => CustomScrollView(
          key: scrollViewKey,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewPaddingOf(context).bottom,
              ),
              sliver: ProfileMasonryGrid(
                childCount:
                    rowCount *
                    ProfileMasonryGrid.columnsFor(layout, constraints.maxWidth),
                // Most videos are vertical, so the placeholders are too.
                aspectRatioOf: (_) => profileVerticalTileAspectRatio,
                itemBuilder: (context, index) =>
                    const ProfileTabThumbnailPlaceholder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
