// ABOUTME: Tests verifying that video thumbnails match the actual video aspect ratio from dimensions metadata
// ABOUTME: Ensures thumbnails prevent visual jump when video loads by matching video dimensions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('VideoThumbnailWidget Aspect Ratio', () {
    late VideoEvent testVideo;

    setUp(() {
      final now = DateTime.now();
      testVideo = VideoEvent(
        id: 'test-video-id',
        pubkey: 'test-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumbnail.jpg',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );
    });

    testWidgets('thumbnail without dimensions defaults to 2:3 portrait', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: VideoThumbnailWidget(video: testVideo),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the AspectRatio widget that should enforce 1:1 ratio
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(
        aspectRatioFinder,
        findsOneWidget,
        reason: 'Thumbnail should be wrapped in AspectRatio widget',
      );

      // Verify the aspect ratio is 1:1 (square)
      final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
      expect(
        aspectRatioWidget.aspectRatio,
        equals(2 / 3),
        reason: 'Thumbnail aspect ratio should be 2:3 portrait fallback when no dimensions metadata',
      );
    });

    testWidgets('thumbnail with explicit width defaults to 2:3 portrait', (
      tester,
    ) async {
      const thumbnailWidth = 200.0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(video: testVideo, width: thumbnailWidth),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find AspectRatio widget
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);

      // Verify 2:3 portrait fallback
      final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, equals(2 / 3));
    });

    testWidgets('thumbnail with explicit height defaults to 2:3 portrait', (
      tester,
    ) async {
      const thumbnailHeight = 300.0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(
              video: testVideo,
              height: thumbnailHeight,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find AspectRatio widget
      final aspectRatioFinder = find.byType(AspectRatio);
      expect(aspectRatioFinder, findsOneWidget);

      // Verify 2:3 portrait fallback
      final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
      expect(aspectRatioWidget.aspectRatio, equals(2 / 3));
    });

    testWidgets('thumbnail with play icon should maintain aspect ratio', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoThumbnailWidget(video: testVideo, showPlayIcon: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify AspectRatio widget exists
      expect(find.byType(AspectRatio), findsOneWidget);

      // Verify play icon is present
      expect(
        _divineIcon(DivineIconName.play),
        findsOneWidget,
        reason: 'Play icon should be visible on thumbnail',
      );
    });

    testWidgets('thumbnail with blurhash fallback defaults to 2:3 portrait', (
      tester,
    ) async {
      final now = DateTime.now();
      final videoWithBlurhash = VideoEvent(
        id: 'test-video-blurhash',
        pubkey: 'test-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'Test video with blurhash',
        videoUrl: 'https://example.com/video.mp4',
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoThumbnailWidget(video: videoWithBlurhash)),
        ),
      );

      await tester.pumpAndSettle();

      // With blurhash fallback, should use 2:3 portrait default
      expect(find.byType(AspectRatio), findsOneWidget);

      final aspectRatioWidget = tester.widget<AspectRatio>(
        find.byType(AspectRatio),
      );
      expect(aspectRatioWidget.aspectRatio, equals(2 / 3));
    });

    // NEW TESTS: Dynamic aspect ratio based on video dimensions
    group('Dynamic aspect ratio from dimensions metadata', () {
      testWidgets(
        'portrait video (720x1280) should have portrait aspect ratio',
        (tester) async {
          final now = DateTime.now();
          final portraitVideo = VideoEvent(
            id: 'portrait-video-id',
            pubkey: 'test-pubkey',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Portrait video',
            videoUrl: 'https://example.com/portrait.mp4',
            thumbnailUrl: 'https://example.com/portrait-thumb.jpg',
            dimensions: '720x1280', // Portrait dimensions
            blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoThumbnailWidget(video: portraitVideo)),
            ),
          );

          await tester.pumpAndSettle();

          // Find AspectRatio widget
          final aspectRatioFinder = find.byType(AspectRatio);
          expect(
            aspectRatioFinder,
            findsOneWidget,
            reason: 'Thumbnail should be wrapped in AspectRatio widget',
          );

          // Portrait 720/1280 = 0.5625, clamped to 2:3 minimum
          final aspectRatioWidget = tester.widget<AspectRatio>(
            aspectRatioFinder,
          );
          expect(
            aspectRatioWidget.aspectRatio,
            equals(2 / 3),
            reason: 'Portrait aspect ratio should be clamped to 2:3 minimum',
          );
        },
      );

      testWidgets('square video (480x480) should have 1:1 aspect ratio', (
        tester,
      ) async {
        final now = DateTime.now();
        final squareVideo = VideoEvent(
          id: 'square-video-id',
          pubkey: 'test-pubkey',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          content: 'Square video',
          videoUrl: 'https://example.com/square.mp4',
          thumbnailUrl: 'https://example.com/square-thumb.jpg',
          dimensions: '480x480', // Square dimensions
          blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        );

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoThumbnailWidget(video: squareVideo)),
          ),
        );

        await tester.pumpAndSettle();

        // Find AspectRatio widget
        final aspectRatioFinder = find.byType(AspectRatio);
        expect(aspectRatioFinder, findsOneWidget);

        // Verify aspect ratio is 1:1 for square video
        final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
        expect(
          aspectRatioWidget.aspectRatio,
          equals(1.0),
          reason: 'Thumbnail aspect ratio should be 1.0 for square video',
        );
      });

      testWidgets(
        'landscape video (1280x720) should have landscape aspect ratio',
        (tester) async {
          final now = DateTime.now();
          final landscapeVideo = VideoEvent(
            id: 'landscape-video-id',
            pubkey: 'test-pubkey',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Landscape video',
            videoUrl: 'https://example.com/landscape.mp4',
            thumbnailUrl: 'https://example.com/landscape-thumb.jpg',
            dimensions: '1280x720', // Landscape dimensions (16:9)
            blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoThumbnailWidget(video: landscapeVideo)),
            ),
          );

          await tester.pumpAndSettle();

          // Find AspectRatio widget
          final aspectRatioFinder = find.byType(AspectRatio);
          expect(aspectRatioFinder, findsOneWidget);

          // Verify aspect ratio matches video dimensions (1280/720 ≈ 1.778)
          final aspectRatioWidget = tester.widget<AspectRatio>(
            aspectRatioFinder,
          );
          expect(
            aspectRatioWidget.aspectRatio,
            equals(1280 / 720),
            reason: 'Thumbnail aspect ratio should match video dimensions (landscape)',
          );
        },
      );

      testWidgets(
        'video without dimensions should fallback to 2:3 portrait aspect ratio',
        (tester) async {
          final now = DateTime.now();
          final noDimensionsVideo = VideoEvent(
            id: 'no-dimensions-id',
            pubkey: 'test-pubkey',
            createdAt: now.millisecondsSinceEpoch ~/ 1000,
            timestamp: now,
            content: 'Video without dimensions',
            videoUrl: 'https://example.com/video.mp4',
            thumbnailUrl: 'https://example.com/thumb.jpg',
            blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          );

          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoThumbnailWidget(video: noDimensionsVideo),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Find AspectRatio widget
          final aspectRatioFinder = find.byType(AspectRatio);
          expect(aspectRatioFinder, findsOneWidget);

          // Verify aspect ratio defaults to 2:3 when dimensions are missing
          final aspectRatioWidget = tester.widget<AspectRatio>(
            aspectRatioFinder,
          );
          expect(
            aspectRatioWidget.aspectRatio,
            equals(2 / 3),
            reason: 'Thumbnail should fallback to 2:3 portrait aspect ratio when dimensions are missing',
          );
        },
      );
    });

    // Covers the BoxFit branch (portrait -> cover, square/landscape -> contain)
    // that was previously only exercised by the deleted video_thumbnail golden.
    group('BoxFit strategy from aspect ratio', () {
      Future<BlurhashDisplay> pumpFor(
        WidgetTester tester,
        String dimensions,
      ) async {
        final now = DateTime.now();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoThumbnailWidget(
                video: VideoEvent(
                  id: 'fit-$dimensions',
                  pubkey: 'test-pubkey',
                  createdAt: now.millisecondsSinceEpoch ~/ 1000,
                  timestamp: now,
                  content: 'Fit test',
                  videoUrl: 'https://example.com/video.mp4',
                  dimensions: dimensions,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester.widget<BlurhashDisplay>(find.byType(BlurhashDisplay));
      }

      testWidgets('portrait (720x1280) uses BoxFit.cover', (tester) async {
        expect((await pumpFor(tester, '720x1280')).fit, BoxFit.cover);
      });

      testWidgets('landscape (1280x720) uses BoxFit.contain', (tester) async {
        expect((await pumpFor(tester, '1280x720')).fit, BoxFit.contain);
      });

      testWidgets('square (480x480) uses BoxFit.contain', (tester) async {
        expect((await pumpFor(tester, '480x480')).fit, BoxFit.contain);
      });
    });
  });
}
