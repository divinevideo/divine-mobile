// ABOUTME: Regression tests for #5796 — a missing clip thumbnail/ghost file
// ABOUTME: must render a placeholder instead of surfacing PathNotFoundException.

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

void main() {
  group(ClipThumbnailImage, () {
    // A failed resolution stays live in the process-global image cache, so
    // each test evicts its own key and no two tests share a path. Clearing
    // the whole cache instead also disposes what every other suite in the
    // merged-isolate run put there, and `ImageCache` defers that disposal to
    // a post-frame callback — it then lands in the *next* test's first frame
    // as an `ImageInfo.dispose` assertion and fails a test that never
    // touched an image.
    void evictAfterTest(String path) {
      addTearDown(
        () => PaintingBinding.instance.imageCache.evict(FileImage(File(path))),
      );
    }

    Future<void> pumpMissingThumbnail(
      WidgetTester tester,
      String path, {
      Widget? placeholder,
      ImageFrameBuilder? frameBuilder,
    }) async {
      evictAfterTest(path);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: ClipThumbnailImage(
                path: path,
                placeholder: placeholder,
                frameBuilder: frameBuilder,
              ),
            ),
          ),
        ),
      );
    }

    // Resolving the file is real I/O, so the failure needs real time to
    // arrive. Polled rather than slept on: a single fixed delay is a coin
    // flip once the CI box is running four shards at once.
    Future<void> pumpUntil(
      WidgetTester tester,
      bool Function() resolved,
    ) async {
      for (var attempt = 0; attempt < 50 && !resolved(); attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    testWidgets('renders the neutral placeholder for a missing file', (
      tester,
    ) async {
      await pumpMissingThumbnail(
        tester,
        '/nonexistent/container/neutral_thumbnail.jpg',
      );
      await pumpUntil(
        tester,
        () => find.byType(DivineIcon).evaluate().isNotEmpty,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DivineIcon), findsOneWidget);
      expect(find.byType(ColoredBox), findsWidgets);
    });

    testWidgets('renders a custom placeholder for a missing file', (
      tester,
    ) async {
      const marker = Key('custom-placeholder');

      await pumpMissingThumbnail(
        tester,
        '/nonexistent/container/custom_thumbnail.jpg',
        placeholder: const SizedBox.shrink(key: marker),
      );
      await pumpUntil(tester, () => find.byKey(marker).evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      expect(find.byKey(marker), findsOneWidget);
      expect(find.byType(DivineIcon), findsNothing);
    });

    testWidgets(
      'wraps the image with frameBuilder while decoding, and drops it for '
      'the placeholder once decoding fails',
      (tester) async {
        const marker = Key('frame-builder');

        await pumpMissingThumbnail(
          tester,
          '/nonexistent/container/frame_builder_probe.jpg',
          placeholder: const SizedBox.shrink(),
          frameBuilder: (context, child, frame, _) =>
              SizedBox(key: marker, child: child),
        );

        expect(find.byKey(marker), findsOneWidget);

        await pumpUntil(tester, () => find.byKey(marker).evaluate().isEmpty);

        expect(tester.takeException(), isNull);
        expect(find.byKey(marker), findsNothing);
      },
    );
  });
}
