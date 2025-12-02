// ABOUTME: Data Access Object for video engagement metrics operations
// ABOUTME: Provides upsert operations for denormalized video metrics (loop_count, likes, views, etc.)

import 'package:drift/drift.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/database/tables.dart';
import 'package:openvine/models/video_event.dart';

part 'video_metrics_dao.g.dart';

@DriftAccessor(tables: [VideoMetrics])
class VideoMetricsDao extends DatabaseAccessor<AppDatabase>
    with _$VideoMetricsDaoMixin {
  VideoMetricsDao(AppDatabase db) : super(db);

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
        videoEvent.originalLoops != null
            ? Variable.withInt(videoEvent.originalLoops!)
            : const Variable(null),
        videoEvent.originalLikes != null
            ? Variable.withInt(videoEvent.originalLikes!)
            : const Variable(null),
        const Variable(null), // views - not yet extracted from tags
        videoEvent.originalComments != null
            ? Variable.withInt(videoEvent.originalComments!)
            : const Variable(null),
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
            views: null, // not yet extracted from tags
            comments: videoEvent.originalComments,
            avgCompletion: null, // not yet extracted
            hasProofmode: null, // not yet extracted
            hasDeviceAttestation: null, // not yet extracted
            hasPgpSignature: null, // not yet extracted
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Delete video metrics for a specific event
  ///
  /// Called when the parent event is deleted (automatically via foreign key cascade).
  Future<void> deleteVideoMetrics(String eventId) async {
    await customStatement('DELETE FROM video_metrics WHERE event_id = ?', [
      Variable.withString(eventId),
    ]);
  }
}
