// ABOUTME: Tests that clearing the shared image caches drops live images and
// ABOUTME: empties the disk cache, so revoked adult media cannot come back.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

void main() {
  group('clearOpenVineImageCache', () {
    late _MockMediaCacheManager diskCache;

    setUp(() {
      diskCache = _MockMediaCacheManager();
      when(() => diskCache.clearCache()).thenAnswer((_) async {});
    });

    testWidgets('drops live images and schedules a frame', (tester) async {
      final cache = PaintingBinding.instance.imageCache;
      await tester.pumpWidget(const SizedBox());
      final image = await tester.runAsync(() {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawPaint(ui.Paint());
        return recorder.endRecording().toImage(4, 4);
      });
      const key = 'open_vine_image_cache_test';
      cache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image!)),
        ),
      );
      final listener = ImageStreamListener((_, _) {});
      final completer = cache.putIfAbsent(key, () => throw StateError('hit'))!
        ..addListener(listener);
      addTearDown(() => completer.removeListener(listener));
      expect(cache.liveImageCount, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isFalse);

      await clearOpenVineImageCache(diskCache: diskCache);

      expect(cache.liveImageCount, isZero);
      expect(cache.currentSizeBytes, isZero);
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pump();
    });

    testWidgets('empties the disk cache', (tester) async {
      await clearOpenVineImageCache(diskCache: diskCache);

      verify(() => diskCache.clearCache()).called(1);
      await tester.pump();
    });
  });
}
