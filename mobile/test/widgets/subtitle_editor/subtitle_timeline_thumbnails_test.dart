// ABOUTME: Widget tests for the subtitle timeline's filmstrip frame selection.
// ABOUTME: Keeps frame timestamps aligned with the ruler and playhead.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_timeline_thumbnails.dart';

void main() {
  group(SubtitleTimelineThumbnails, () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('subtitle_frames');
    });

    tearDown(() => temp.deleteSync(recursive: true));

    String framePath(String name) {
      final file = File('${temp.path}/$name.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
            '/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
          ),
        );
      return file.path;
    }

    testWidgets('uses actual axis width when choosing a slot frame', (
      tester,
    ) async {
      final early = framePath('early');
      final aligned = framePath('aligned');
      final thumbnails = ValueNotifier([
        TimelineFrame(path: framePath('start'), timestamp: Duration.zero),
        TimelineFrame(
          path: early,
          timestamp: const Duration(milliseconds: 4700),
        ),
        TimelineFrame(
          path: aligned,
          timestamp: const Duration(milliseconds: 5100),
        ),
      ]);
      addTearDown(thumbnails.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SubtitleTimelineThumbnails(
              thumbnails: thumbnails,
              // 6s at default zoom gives 312px, which rounds up to seven
              // 48px slots. Slot five should still map by 312px of axis, not
              // 336px of rounded raster.
              width: 312,
              totalDuration: const Duration(seconds: 6),
            ),
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      final selected = images[5].image as FileImage;
      expect(selected.file.path, aligned);
    });
  });
}
