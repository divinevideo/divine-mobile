// ABOUTME: Pumps a widget with every VineCachedImage backed by a real PNG, so
// ABOUTME: tests can see semantics that exist only once an image has decoded.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

import 'test_provider_overrides.dart';

/// Pumps [app] with every [VineCachedImage] served from a small PNG on disk,
/// then waits until each [Image] matched by [images] has decoded a frame.
///
/// The app's network images fade in from zero opacity, and a zero-opacity
/// child is left out of the semantics tree, so an image only reaches
/// assistive tech once a frame has decoded. Decoding needs the real event
/// loop, so the widget is built inside [WidgetTester.runAsync]: an image load
/// started under the fake clock would never finish.
Future<void> pumpWithDecodedImages(
  WidgetTester tester,
  Widget app, {
  required Finder images,
}) async {
  await tester.runAsync(() async {
    final pngPath = await _writePng();
    final cache = createMockMediaCacheManager();
    when(() => cache.getFileFromCache(any())).thenAnswer(
      (invocation) async => FileInfo(
        const LocalFileSystem().file(pngPath),
        FileSource.Cache,
        DateTime(2100),
        invocation.positionalArguments.first as String,
      ),
    );
    debugImageCacheOverride = cache;
    addTearDown(() => debugImageCacheOverride = null);

    await tester.pumpWidget(app);
    for (var i = 0; i < 50 && images.evaluate().isEmpty; i++) {
      await pumpEventQueue();
      await tester.pump();
    }
    expect(images, findsWidgets);
    for (final element in images.evaluate().toList()) {
      await precacheImage(
        (element.widget as Image).image,
        element,
      ).timeout(const Duration(seconds: 10));
    }
  });
  await tester.pumpAndSettle();
}

Future<String> _writePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 12),
    ui.Paint()..color = const Color(0xFF27C58B),
  );
  final image = await recorder.endRecording().toImage(8, 12);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = Directory.systemTemp.createTempSync('decoded_images_');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File('${dir.path}/image.png')
    ..writeAsBytesSync(png!.buffer.asUint8List());
  return file.path;
}
