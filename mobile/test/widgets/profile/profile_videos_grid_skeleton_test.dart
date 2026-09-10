import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail_placeholder.dart';
import 'package:openvine/widgets/profile/profile_videos_grid_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  group(ProfileVideosGridSkeleton, () {
    Widget buildSubject({int? cellCount}) {
      return MaterialApp(
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

    testWidgets('lays the placeholders out in a 3-column SliverGrid', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
    });
  });
}
