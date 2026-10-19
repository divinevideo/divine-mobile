// ABOUTME: Tests that clearing the decoded-image cache also schedules a frame,
// ABOUTME: which is when the cache releases the images it dropped.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/decoded_image_cache.dart';

void main() {
  group('clearDecodedImageCache', () {
    late ImageCache cache;

    Future<void> cacheImage(WidgetTester tester, Object key) async {
      final image = await tester.runAsync(() {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawPaint(ui.Paint());
        return recorder.endRecording().toImage(4, 4);
      });
      cache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image!)),
        ),
      );
    }

    setUp(() => cache = PaintingBinding.instance.imageCache);

    testWidgets('empties the cache and schedules a frame', (tester) async {
      await tester.pumpWidget(const SizedBox());
      await cacheImage(tester, 'decoded_image_cache_test');
      expect(cache.currentSizeBytes, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isFalse);

      clearDecodedImageCache();

      expect(cache.currentSizeBytes, isZero);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
    });

    testWidgets('schedules no frame while the app is in the background', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      await cacheImage(tester, 'decoded_image_cache_background_test');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(tester.binding.hasScheduledFrame, isFalse);

      clearDecodedImageCache();

      expect(cache.currentSizeBytes, isZero);
      expect(tester.binding.hasScheduledFrame, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    });

    testWidgets('keeps live images tracked unless asked to drop them', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      const key = 'decoded_image_cache_live_test';
      await cacheImage(tester, key);
      final listener = ImageStreamListener((_, _) {});
      final completer = cache.putIfAbsent(key, () => throw StateError('hit'))!
        ..addListener(listener);
      addTearDown(() => completer.removeListener(listener));
      expect(cache.liveImageCount, greaterThan(0));

      clearDecodedImageCache();
      expect(cache.liveImageCount, greaterThan(0));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);

      clearDecodedImageCache(includeLiveImages: true);
      expect(cache.liveImageCount, isZero);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
    });
  });
}
