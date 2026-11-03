@TestOn('browser')
library;

import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';

// A synthetic, one-pixel PNG. No remote artwork or account data is needed.
const _imageUrl =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNg'
    'AAIAAAUAAXpeqz8AAAAASUVORK5CYII=';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheImageProvider on web', () {
    test('decodes an image without a native filesystem directory', () async {
      final cache = MediaCacheManager(
        config: const MediaCacheConfig.image(cacheKey: 'browser_image_test'),
      );
      final provider = MediaCacheImageProvider(
        _imageUrl,
        cacheManager: cache,
        scale: 2,
      );
      final result = Completer<ImageInfo>();
      final stream = provider.resolve(ImageConfiguration.empty);
      final listener = ImageStreamListener(
        (image, _) => result.complete(image),
        onError: result.completeError,
      );
      stream.addListener(listener);
      try {
        final image = await result.future.timeout(const Duration(seconds: 5));
        expect(image.image.width, 1);
        expect(image.image.height, 1);
        expect(image.scale, 2);
        image.dispose();
      } finally {
        stream.removeListener(listener);
        PaintingBinding.instance.imageCache.clear();
        await cache.close();
      }
    });

    test(
      'keeps HTML fallback images displayable without pixel access',
      () async {
        final cache = MediaCacheManager(
          config: const MediaCacheConfig.image(cacheKey: 'browser_svg_test'),
        );
        final url = Uri.dataFromString(
          '<svg xmlns="http://www.w3.org/2000/svg" width="3" height="2"> '
          '<rect width="3" height="2" fill="green"/></svg>',
          mimeType: 'image/svg+xml',
        ).toString();
        final provider = MediaCacheImageProvider(url, cacheManager: cache);
        final result = Completer<ImageInfo>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (image, _) => result.complete(image),
          onError: result.completeError,
        );
        stream.addListener(listener);
        try {
          final image = await result.future.timeout(const Duration(seconds: 5));
          // The canvas decoder cannot decode SVG; the browser HTML loader can.
          // Like cross-origin images, it has no decoded ui.Image to inspect.
          expect(imageInfoDimensions(image), isNull);
          expect(() => image.clone().dispose(), returnsNormally);
          image.dispose();
        } finally {
          stream.removeListener(listener);
          PaintingBinding.instance.imageCache.clear();
          await cache.close();
        }
      },
    );
  });
}
