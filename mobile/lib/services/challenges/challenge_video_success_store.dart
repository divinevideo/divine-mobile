import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';
import 'package:openvine/models/divine_video_draft.dart';

/// Terminal video bookkeeping, independent of active account/signing readiness.
/// Never creates a draft or grants challenge consent. Existing rows must still
/// belong to the original owner and recording generation inside the transaction.
class ChallengeVideoSuccessStore {
  const ChallengeVideoSuccessStore(this.database);
  final AppDatabase database;

  /// The publisher already reports video success. Challenge eligibility and
  /// signature validation belong to handoff/review, not terminal bookkeeping:
  /// a video too large for a challenge must never become eligible to re-upload.
  Future<void> record(DivineVideoDraft draft, String? signedVideo) =>
      _settle(draft, signedVideo, cleanup: false);

  /// Called after durable entry handoff. Only matching original draft rows are
  /// removed. Existing orphan cleanup can reclaim their now-unreferenced files.
  Future<void> discardDrafts(DivineVideoDraft draft) =>
      _settle(draft, null, cleanup: true);

  Future<void> _settle(
    DivineVideoDraft draft,
    String? signedVideo, {
    required bool cleanup,
  }) async {
    final context = draft.challengeContext;
    if (context == null) return;
    await database.transaction(() async {
      final owner =
          await (database.select(database.challengeOwners)
                ..where((row) => row.ownerPubkey.equals(context.owner)))
              .getSingleOrNull();
      final removed = owner?.generation != context.generation;
      for (final id in {draft.id, ?draft.sourceDraftId}) {
        final row = await database.draftsDao.getDraftById(id);
        if (row == null || row.ownerPubkey != context.owner) continue;
        final data = jsonDecode(row.data) as Map<String, dynamic>;
        final stored = data['challengeContext'];
        if (stored is! Map<String, dynamic> ||
            stored['owner'] != context.owner ||
            stored['generation'] != context.generation ||
            stored['recordingId'] != context.recordingId) {
          continue;
        }
        if (removed || cleanup) {
          await database.draftsDao.deleteDraft(id);
          continue;
        }
        // Preserve each source draft's content, media and ownership manifest.
        // The payload and indexed status change atomically; no file writes or
        // active-session service can escape this transaction.
        data['publishStatus'] = PublishStatus.published.name;
        data['publishedVideoEvent'] = signedVideo;
        await (database.update(
          database.drafts,
        )..where((row) => row.id.equals(id))).write(
          DraftsCompanion(
            publishStatus: Value(PublishStatus.published.name),
            data: Value(jsonEncode(data)),
          ),
        );
      }
    });
  }
}
