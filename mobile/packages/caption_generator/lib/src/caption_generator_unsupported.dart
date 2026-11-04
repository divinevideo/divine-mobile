// ABOUTME: Unsupported-platform CaptionGenerator implementation.
// ABOUTME: Keeps the public library importable on web.

import 'package:caption_generator/src/models/caption_segment.dart';

/// Caption generation is unavailable on this platform.
class CaptionGenerator {
  /// Creates a caption generator.
  CaptionGenerator();

  /// Always throws because caption generation only supports Android, iOS, and
  /// macOS.
  Future<List<CaptionSegment>> generateCaptions({
    required String audioPath,
    String? localeIdentifier,
    bool preferOnDeviceRecognition = true,
    bool requireOnDeviceRecognition = false,
  }) {
    throw UnsupportedError(
      'caption_generator supports Android, iOS, and macOS only.',
    );
  }
}
