import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_loading_placeholder.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

void main() {
  Widget buildSubject({
    String? thumbnailUrl,
    bool shouldPortraitExpand = true,
  }) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VideoLoadingPlaceholder(
          videoId: 'video-1',
          index: 0,
          feedMode: 'following',
          thumbnailUrl: thumbnailUrl,
          shouldPortraitExpand: shouldPortraitExpand,
        ),
      ),
    );
  }

  group('VideoLoadingPlaceholder', () {
    testWidgets(
      'uses PassiveAuthThumbnailImage when a thumbnail URL is present',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(thumbnailUrl: 'https://example.com/thumb.jpg'),
        );

        expect(find.byType(PassiveAuthThumbnailImage), findsOneWidget);
        final image = tester.widget<PassiveAuthThumbnailImage>(
          find.byType(PassiveAuthThumbnailImage),
        );
        expect(image.alignment, equals(Alignment.center));
        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      },
    );

    testWidgets('shows only the loading indicator when thumbnail is missing', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(PassiveAuthThumbnailImage), findsNothing);
      expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
    });
  });
}
