// ABOUTME: Tests that ReleaseCachedImagesOnDispose empties Flutter's
// ABOUTME: decoded-image cache when its screen leaves the tree, and only then.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/release_cached_images_on_dispose.dart';

void main() {
  group(ReleaseCachedImagesOnDispose, () {
    late ImageCache imageCache;

    setUp(() {
      imageCache = PaintingBinding.instance.imageCache..clear();
    });

    tearDown(() => imageCache.clear());

    Future<void> cacheImage(WidgetTester tester, Object key) async {
      final image = await tester.runAsync(
        () => createTestImage(width: 4, height: 4),
      );
      imageCache.putIfAbsent(
        key,
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image!)),
        ),
      );
    }

    testWidgets('empties the image cache when disposed', (tester) async {
      await tester.pumpWidget(
        const ReleaseCachedImagesOnDispose(child: SizedBox()),
      );
      await cacheImage(tester, 'thumbnail');
      expect(imageCache.statusForKey('thumbnail').keepAlive, isTrue);

      await tester.pumpWidget(const SizedBox());

      expect(imageCache.currentSize, isZero);
      expect(imageCache.statusForKey('thumbnail').untracked, isTrue);
    });

    testWidgets('keeps cached images while it stays mounted', (tester) async {
      await tester.pumpWidget(
        const ReleaseCachedImagesOnDispose(child: SizedBox()),
      );
      await cacheImage(tester, 'thumbnail');

      await tester.pumpWidget(
        const ReleaseCachedImagesOnDispose(child: SizedBox(width: 1)),
      );

      expect(imageCache.statusForKey('thumbnail').keepAlive, isTrue);
    });
  });
}
