import 'package:models/models.dart';

/// Response model for the recent videos endpoint.
class RecentVideosResponse {
  /// Creates a parsed response for a recent videos page.
  const RecentVideosResponse({
    required this.videos,
    required this.serverItemCount,
    this.hasMore,
    this.nextCursor,
  });

  /// Videos returned for this page, with malformed rows dropped.
  final List<VideoStats> videos;

  /// How many rows the server returned, before malformed ones were dropped.
  ///
  /// Callers that page this feed must compare this — not `videos.length` —
  /// against the limit they requested. A single row missing an `id` or a
  /// `videoUrl` shortens [videos] without the source having run out, and
  /// reading that as exhaustion stops pagination early.
  final int serverItemCount;

  /// Server-provided "has more" flag, when the response carries an envelope.
  ///
  /// `null` only when a legacy bare-list response is returned, in which case
  /// callers fall back to comparing [serverItemCount] against the limit.
  final bool? hasMore;

  /// Opaque server cursor for the next publication-ordered page.
  final String? nextCursor;
}
