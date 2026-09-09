// ABOUTME: One extracted video frame on the subtitle editor's timeline, in the
// ABOUTME: model layer so the UI can name it without reaching into services.

import 'package:equatable/equatable.dart';

/// A single frame of the filmstrip under the subtitle editor's ruler.
class TimelineFrame extends Equatable {
  /// Creates a frame extracted at [timestamp].
  const TimelineFrame({required this.path, required this.timestamp});

  /// Path to the extracted image on disk.
  final String path;

  /// The video position this frame was taken at.
  final Duration timestamp;

  @override
  List<Object?> get props => [path, timestamp];
}

/// Streams progressively denser filmstrips for a published video.
///
/// Each event is the full set extracted so far. Injected as a function rather
/// than the service itself so the widgets that render frames stay out of the
/// service layer.
typedef TimelineFrameLoader = Stream<List<TimelineFrame>> Function({
  required String videoUrl,
  required String videoId,
  required Duration duration,
  required double devicePixelRatio,
});
