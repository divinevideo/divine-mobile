import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An image provider whose successive loads deliver successive images, so a
/// test can tell a tile's resized decode from a later full-size one.
///
/// Wrapped in a [ResizeImage] it still delivers the image as given: the
/// resize happens in the decode step, which this provider skips.
class SequencedImageProvider extends ImageProvider<SequencedImageProvider> {
  /// Delivers [loads] in order, one per load.
  SequencedImageProvider(this.loads);

  /// Starts each load, the first for the first one. A load starts only when
  /// asked for, so a failing one fails while something listens.
  final List<Future<ui.Image> Function()> loads;

  int _next = 0;

  @override
  Future<SequencedImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    SequencedImageProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    loads[_next++]().then((image) => ImageInfo(image: image.clone())),
  );
}
