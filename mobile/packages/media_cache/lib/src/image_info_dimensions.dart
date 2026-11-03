import 'package:flutter/painting.dart';

/// Pixel dimensions when [info] exposes a decoded image.
///
/// Flutter can display cross-origin browser images through an HTML element
/// without exposing their pixels. Reading `image` on that ImageInfo throws
/// UnsupportedError; the image remains displayable without decoded dimensions.
({int width, int height})? imageInfoDimensions(ImageInfo info) {
  try {
    return (width: info.image.width, height: info.image.height);
    // Flutter deliberately throws this for HTML image pixel access.
    // ignore: avoid_catching_errors
  } on UnsupportedError {
    return null;
  }
}
