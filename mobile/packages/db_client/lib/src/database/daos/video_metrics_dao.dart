// ABOUTME: Data Access Object for video metrics with Event model parsing.
// ABOUTME: Provides upsert from Event model. Simple CRUD is in AppDbClient.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

part 'video_metrics_dao.g.dart';

@DriftAccessor(tables: [VideoMetrics])
class VideoMetricsDao extends DatabaseAccessor<AppDatabase>
    with _$VideoMetricsDaoMixin {
  VideoMetricsDao(super.attachedDatabase);

  /// Upsert video metrics extracted from a video event
  ///
  /// Parses engagement metrics from event tags and stores them in the
  /// video_metrics table for fast sorted queries.
  ///
  /// Metrics extracted:
  /// - loop_count: Number of times video was looped/replayed
  /// - likes: Number of likes/reactions
  /// - comments: Number of comments
  ///
  /// Note: views, avg_completion, and verification flags are set to NULL
  /// until we add support for extracting them from events.
  Future<void> upsertVideoMetrics(Event event) async {
    // Parse metrics from VideoEvent model
    final videoEvent = VideoEvent.fromNostrEvent(event);

    await customInsert(
      'INSERT OR REPLACE INTO video_metrics '
      '(event_id, loop_count, likes, views, comments, avg_completion, '
      'has_proofmode, has_device_attestation, has_pgp_signature, updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(event.id),
        if (videoEvent.originalLoops != null)
          Variable.withInt(videoEvent.originalLoops!)
        else
          const Variable(null),
        if (videoEvent.originalLikes != null)
          Variable.withInt(videoEvent.originalLikes!)
        else
          const Variable(null),
        const Variable(null), // views - not yet extracted from tags
        if (videoEvent.originalComments != null)
          Variable.withInt(videoEvent.originalComments!)
        else
          const Variable(null),
        const Variable(null), // avg_completion - not yet extracted
        const Variable(null), // has_proofmode - not yet extracted
        const Variable(null), // has_device_attestation - not yet extracted
        const Variable(null), // has_pgp_signature - not yet extracted
        Variable.withDateTime(DateTime.now()),
      ],
    );
  }

  /// Batch upsert video metrics for multiple events
  ///
  /// Efficiently processes multiple video events in a single transaction.
  Future<void> batchUpsertVideoMetrics(List<Event> events) async {
    await batch((batch) {
      for (final event in events) {
        final videoEvent = VideoEvent.fromNostrEvent(event);

        batch.insert(
          videoMetrics,
          VideoMetricRow(
            eventId: event.id,
            loopCount: videoEvent.originalLoops,
            likes: videoEvent.originalLikes,
            comments: videoEvent.originalComments,
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }
}
