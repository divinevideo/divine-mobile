import 'package:models/models.dart';

/// Which videos respond to a video.
enum VideoResponseType {
  /// The video replies to it.
  replies,

  /// The videos that joined the Add yours chain it starts.
  joined,
}

/// A page of the videos responding to a video, newest first, and how many
/// there are in all.
class VideoResponsesResponse {
  /// Creates a parsed page of responses.
  const VideoResponsesResponse({required this.videos, required this.total});

  /// The responses on this page, with malformed rows dropped.
  final List<VideoStats> videos;

  /// How many responses there are in all, on every page.
  final int total;
}
