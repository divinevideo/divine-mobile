// ABOUTME: Golden tests for VideoThumbnailWidget to verify visual consistency
// ABOUTME: Tests various states: with/without thumbnail, blurhash fallback, play icon overlay

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:openvine/services/thumbnail_api_service.dart'
    show ThumbnailSize;
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import '../../helpers/golden_test_devices.dart';
import '../../builders/test_video_event_builder.dart';

void main() {
  group('VideoThumbnailWidget Golden Tests', () {
    setUpAll(() async {
      await loadAppFonts();
    });

    // Create mock video events for testing
    final videoWithBlurhash = TestVideoEventBuilder.create(
      id: 'test_video_1',
      pubkey: 'test_pubkey',
      content: 'Test video content',
      videoUrl: 'https://example.com/video.mp4',
      rawTags: {'blurhash': 'L5H2EC=PM+yV0g-mq.wG9c010J}I'},
    );

    final videoMinimal = TestVideoEventBuilder.create(
      id: 'test_video_3',
      pubkey: 'test_pubkey',
      content: 'Minimal video',
      videoUrl: 'https://example.com/video3.mp4',
    );

    testGoldens('VideoThumbnailWidget states', (tester) async {
      final builder = GoldenBuilder.grid(columns: 3, widthToHeightRatio: 0.75)
        ..addScenario(
          'With Blurhash',
          Container(
            width: 150,
            height: 200,
            child: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 150,
              height: 200,
            ),
          ),
        )
        ..addScenario(
          'With Play Icon',
          Container(
            width: 150,
            height: 200,
            child: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 150,
              height: 200,
              showPlayIcon: true,
            ),
          ),
        )
        ..addScenario(
          'Minimal Fallback',
          Container(
            width: 150,
            height: 200,
            child: VideoThumbnailWidget(
              video: videoMinimal,
              width: 150,
              height: 200,
            ),
          ),
        )
        ..addScenario(
          'Small Size',
          Container(
            width: 100,
            height: 100,
            child: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 100,
              height: 100,
              size: ThumbnailSize.small,
            ),
          ),
        )
        ..addScenario(
          'Large Size',
          Container(
            width: 200,
            height: 200,
            child: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 200,
              height: 200,
              size: ThumbnailSize.large,
            ),
          ),
        )
        ..addScenario(
          'With Border Radius',
          Container(
            width: 150,
            height: 200,
            child: VideoThumbnailWidget(
              video: videoWithBlurhash,
              width: 150,
              height: 200,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(theme: ThemeData.dark()),
      );

      await screenMatchesGolden(tester, 'video_thumbnail_states');
    });

    testGoldens('VideoThumbnailWidget aspect ratios', (tester) async {
      final builder = GoldenBuilder.column()
        ..addScenario(
          'Square',
          VideoThumbnailWidget(
            video: videoWithBlurhash,
            width: 200,
            height: 200,
            showPlayIcon: true,
          ),
        )
        ..addScenario(
          'Portrait',
          VideoThumbnailWidget(
            video: videoWithBlurhash,
            width: 150,
            height: 267,
            showPlayIcon: true,
          ),
        )
        ..addScenario(
          'Landscape',
          VideoThumbnailWidget(
            video: videoWithBlurhash,
            width: 300,
            height: 169,
            showPlayIcon: true,
          ),
        );

      await tester.pumpWidgetBuilder(
        builder.build(),
        wrapper: materialAppWrapper(theme: ThemeData.dark()),
      );

      await screenMatchesGolden(tester, 'video_thumbnail_aspects');
    });

    testGoldens('VideoThumbnailWidget on multiple devices', (tester) async {
      final widget = Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoThumbnailWidget(
                video: videoWithBlurhash,
                width: 300,
                height: 400,
                showPlayIcon: true,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  VideoThumbnailWidget(
                    video: videoWithBlurhash,
                    width: 100,
                    height: 100,
                  ),
                  const SizedBox(width: 8),
                  VideoThumbnailWidget(
                    video: videoMinimal,
                    width: 100,
                    height: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidgetBuilder(
        widget,
        wrapper: materialAppWrapper(theme: ThemeData.dark()),
      );

      await multiScreenGolden(
        tester,
        'video_thumbnail_multi_device',
        devices: GoldenTestDevices.minimalDevices,
      );
    });
  });
}
