import 'package:meta/meta.dart';
import 'package:models/src/engagement_count_parser.dart';

/// Engagement stats for a single video from a bulk stats response.
///
/// Used when fetching stats for multiple videos at once from the
/// Funnelcake API's bulk endpoint.
@immutable
class BulkVideoStatsEntry {
  /// Creates a new [BulkVideoStatsEntry] instance.
  const BulkVideoStatsEntry({
    required this.eventId,
    required this.reactions,
    required this.comments,
    required this.reposts,
    this.loops,
    this.views,
    this.uniqueViewers,
    this.embeddedLoops,
  });

  /// Creates a [BulkVideoStatsEntry] from JSON response.
  ///
  /// Reads engagement values from the top-level map and from the explicit
  /// `stats` sub-object only. Unbounded recursive search is intentionally
  /// avoided: it would misattribute engagement counts from unrelated nested
  /// sections (e.g. vine archive data, author stats) to a fresh video,
  /// making new uploads appear to already have likes/comments/reposts.
  factory BulkVideoStatsEntry.fromJson(Map<String, dynamic> json) {
    // The API may nest stats under a "stats" key. Look there first, then
    // fall back to the top-level map. No deeper recursion is performed.
    final statsData = json['stats'] is Map<String, dynamic>
        ? json['stats'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return BulkVideoStatsEntry(
      eventId: (json['event_id'] ?? json['id'] ?? '').toString(),
      reactions: _findEngagementCount(
        statsData,
        json,
        const {'reactions', 'likes', 'like_count', 'total_likes'},
      ),
      comments: _findEngagementCount(
        statsData,
        json,
        const {'comments', 'comment_count', 'total_comments'},
      ),
      reposts: _findEngagementCount(
        statsData,
        json,
        const {'reposts', 'repost_count', 'total_reposts'},
      ),
      // `loops` is the live computed count; the archival Vine-era count
      // arrives separately as `embedded_loops` and must not be conflated.
      loops: _findInt(
        statsData,
        json,
        const {
          'loops',
          'loop_count',
          'total_loops',
          'computed_loops',
        },
      ),
      embeddedLoops: _findInt(
        statsData,
        json,
        const {'embedded_loops'},
      ),
      views: _findInt(
        statsData,
        json,
        const {
          'views',
          'view_count',
          'total_views',
        },
      ),
      uniqueViewers: _findInt(
        statsData,
        json,
        const {'unique_viewers', 'unique_views'},
      ),
    );
  }

  /// The Nostr event ID for this video.
  final String eventId;

  /// Reaction/like count.
  final int reactions;

  /// Comment count.
  final int comments;

  /// Repost count.
  final int reposts;

  /// Live loop/play count (if available).
  final int? loops;

  /// View count (if available).
  final int? views;

  /// Number of distinct viewers (when available).
  final int? uniqueViewers;

  /// Archival Vine-era loop count from the archive import (if available).
  final int? embeddedLoops;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkVideoStatsEntry && other.eventId == eventId;
  }

  @override
  int get hashCode => eventId.hashCode;

  @override
  String toString() =>
      'BulkVideoStatsEntry(eventId: $eventId, '
      'reactions: $reactions, comments: $comments)';
}

/// Safely parses a dynamic value to int, handling various formats.
int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final normalized = value.replaceAll(',', '').trim();
    final asInt = int.tryParse(normalized);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.toInt();
  }
  return null;
}

/// Searches [json] first, then [statsData], for any key in [targetKeys] and
/// returns the first successfully parsed int value, or null if not found.
///
/// Only looks in the two provided maps — no recursion into nested objects.
/// This prevents engagement values from unrelated nested sections (e.g. Vine
/// archive data, author stats) from leaking into the current video's counters.
int? _findInt(
  Map<String, dynamic> statsData,
  Map<String, dynamic> json,
  Set<String> targetKeys,
) {
  for (final map in [json, statsData]) {
    for (final entry in map.entries) {
      if (targetKeys.contains(entry.key.toLowerCase())) {
        final parsed = _parseInt(entry.value);
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

/// Searches [json] first, then [statsData], for engagement keys and
/// normalizes invalid counters (sentinels, negatives) to zero.
///
/// Falls through invalid values (sentinel MAX_INT strings, negatives, empty
/// strings) to the next candidate key before defaulting to 0. An explicit
/// zero at the top level wins over a non-zero value in the stats sub-object.
///
/// Only looks in the two provided maps — no recursion into nested objects.
int _findEngagementCount(
  Map<String, dynamic> statsData,
  Map<String, dynamic> json,
  Set<String> targetKeys,
) {
  for (final map in [json, statsData]) {
    for (final entry in map.entries) {
      if (targetKeys.contains(entry.key.toLowerCase())) {
        final parsed = tryParseEngagementCount(entry.value);
        if (parsed != null) return parsed;
      }
    }
  }
  return 0;
}
