import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

class _Image extends Mock implements ui.Image {}

class _HtmlImageInfo extends Mock implements ImageInfo {}

void main() {
  group('imageInfoDimensions', () {
    test('reports decoded image dimensions', () {
      final image = _Image();
      when(() => image.width).thenReturn(3);
      when(() => image.height).thenReturn(2);
      expect(imageInfoDimensions(ImageInfo(image: image)), (
        width: 3,
        height: 2,
      ));
    });

    test('allows a displayable HTML image with no readable pixels', () {
      final info = _HtmlImageInfo();
      when(() => info.image).thenThrow(UnsupportedError('HTML image pixels'));
      expect(imageInfoDimensions(info), isNull);
    });
  });
}
