import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/profile_masonry_grid.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  group(ProfileVideosGridSkeleton, () {
    Widget buildSubject({int? cellCount}) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: cellCount == null
              ? const ProfileVideosGridSkeleton()
              : ProfileVideosGridSkeleton(cellCount: cellCount),
        ),
      );
    }

    testWidgets('renders placeholder thumbnails under a Skeletonizer', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.bySubtype<Skeletonizer>(), findsOneWidget);
      expect(find.byType(ProfileTabThumbnailPlaceholder), findsWidgets);
    });

    testWidgets('lays the placeholders out as vertical masonry tiles', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final grid = tester.widget<ProfileMasonryGrid>(
        find.byType(ProfileMasonryGrid),
      );
      expect(grid.aspectRatioOf(0), equals(profileVerticalTileAspectRatio));
      final tile = tester.getSize(
        find.byType(ProfileTabThumbnailPlaceholder).first,
      );
      expect(tile.width / tile.height, closeTo(2 / 3, 0.01));
    });
  });
}
