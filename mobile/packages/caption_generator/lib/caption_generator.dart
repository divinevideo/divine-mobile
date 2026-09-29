// ABOUTME: Public exports for closed-caption generation.
// ABOUTME: Keeps the top-level library web-safe via conditional exports.

export 'src/caption_generator_unsupported.dart'
    if (dart.library.io) 'src/caption_generator_io.dart';
export 'src/caption_grouper.dart';
export 'src/caption_word_timing.dart';
export 'src/exceptions.dart';
export 'src/models/caption_segment.dart';
