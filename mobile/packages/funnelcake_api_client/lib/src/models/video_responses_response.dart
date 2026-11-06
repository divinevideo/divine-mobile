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
  const VideoResponsesResponse({
    required this.videos,
    required this.total,
    this.rows = const [],
    this.hasMore = false,
  });

  /// The responses on this page, with malformed rows dropped.
  final List<VideoStats> videos;

  /// How many responses there are in all, on every page.
  final int total;

  /// The event of each row behind [videos], as the server sent it, in the same
  /// order.
  ///
  /// A [VideoStats] keeps what a video list shows and replaces an empty
  /// `content` with the `summary` tag, so a caller that needs the event itself
  /// reads it from here. A row that nests its event beside its stats gives the
  /// nested event.
  final List<Map<String, dynamic>> rows;

  /// Whether the server has responses beyond this page.
  final bool hasMore;
}
