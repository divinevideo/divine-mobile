import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/thumbnail_api_service.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_icon_placeholder.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

import '../test_data/video_test_data.dart';

void main() {
  group('VideoThumbnailWidget', () {
    late VideoEvent videoWithThumbnail;
    late VideoEvent videoWithBlurhash;
    late VideoEvent videoWithBoth;
    late VideoEvent videoWithNeither;

    setUp(() {
      // Video with only thumbnail URL
      videoWithThumbnail = createTestVideoEvent(
        id: 'test1',
        thumbnailUrl: 'https://example.com/thumb1.jpg',
        blurhash: null,
      );

      // Video with only blurhash
      videoWithBlurhash = createTestVideoEvent(
        id: 'test2',
        thumbnailUrl: null,
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with both thumbnail and blurhash
      videoWithBoth = createTestVideoEvent(
        id: 'test3',
        thumbnailUrl: 'https://example.com/thumb3.jpg',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      // Video with neither
      videoWithNeither = createTestVideoEvent(
        id: 'test4',
        thumbnailUrl: null,
        blurhash: null,
      );
    });

    testWidgets('builds widget tree correctly when thumbnail URL exists', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Widget should build without error
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);

      // Should create an Image widget when thumbnail URL exists
      expect(find.byType(Image), findsOneWidget);

      // Should not show placeholder when thumbnail exists
      expect(find.byType(VideoIconPlaceholder), findsNothing);
    });

    testWidgets('displays blurhash when only blurhash is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show BlurhashDisplay
      expect(find.byType(BlurhashDisplay), findsOneWidget);

      // Should not show placeholder or image
      expect(find.byType(VideoIconPlaceholder), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets(
      'displays blurhash as background when both thumbnail and blurhash exist',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithBoth,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        // Should show both BlurhashDisplay and Image in a Stack
        expect(find.byType(BlurhashDisplay), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(Stack), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'displays icon placeholder when neither thumbnail nor blurhash exists',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: videoWithNeither,
                width: 200,
                height: 200,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should show VideoIconPlaceholder
        expect(find.byType(VideoIconPlaceholder), findsOneWidget);

        // Should not show blurhash or image
        expect(find.byType(BlurhashDisplay), findsNothing);
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets('shows play icon when requested', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
              showPlayIcon: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show play icon
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('applies border radius when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );

      // Should have ClipRRect with border radius
      expect(find.byType(ClipRRect), findsOneWidget);
      final ClipRRect clipRRect = tester.widget(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets('updates when video changes', (tester) async {
      // Start with video that has thumbnail
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Initially shows image
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(BlurhashDisplay), findsNothing);

      // Update to video with only blurhash
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should now show blurhash instead of image
      expect(find.byType(BlurhashDisplay), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('respects thumbnail size parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
              size: ThumbnailSize.large,
            ),
          ),
        ),
      );

      // Widget should build without error with different size
      expect(find.byType(VideoThumbnailWidget), findsOneWidget);
    });

    testWidgets('does not try to generate thumbnails when URL is missing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show blurhash, not loading indicator
      expect(find.byType(BlurhashDisplay), findsOneWidget);

      // Should not show loading placeholder
      final placeholderFinder = find.byWidgetPredicate(
        (widget) =>
            widget is VideoIconPlaceholder && widget.showLoading == true,
      );
      expect(placeholderFinder, findsNothing);
    });

    testWidgets('shows loading state briefly during initialization', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithThumbnail,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      // Initially might show loading state
      // After settling, should show the content
      await tester.pumpAndSettle();

      expect(find.byType(VideoThumbnailWidget), findsOneWidget);
    });

    testWidgets('handles empty thumbnail URL as null', (tester) async {
      final videoWithEmptyUrl = createTestVideoEvent(
        id: 'test5',
        thumbnailUrl: '',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: videoWithEmptyUrl,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should treat empty URL as null and show blurhash
      expect(find.byType(BlurhashDisplay), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
