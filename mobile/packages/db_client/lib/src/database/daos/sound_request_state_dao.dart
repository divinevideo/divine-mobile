// ABOUTME: Persists account-owned sound request records and pending jobs.
// ABOUTME: Commits record changes atomically before side effects.
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'sound_request_state_dao.g.dart';

@DriftAccessor(tables: [SoundRequestStates])
class SoundRequestStateDao extends DatabaseAccessor<AppDatabase>
    with _$SoundRequestStateDaoMixin {
  SoundRequestStateDao(super.attachedDatabase);

  /// Restores only this account's records.
  Future<List<SoundRequestStateRow>> readAccount(String owner) => (select(
    soundRequestStates,
  )..where((t) => t.ownerPubkey.equals(owner))).get();

  /// Atomically reconciles a snapshot, writing only changed rows.
  Future<void> writeAccount(
    String owner,
    Map<String, Map<String, String>> sections,
  ) => transaction(() async {
    final previous = await readAccount(owner);
    final remaining = {
      for (final row in previous) (row.section, row.recordKey): row,
    };
    await batch((batch) {
      for (final section in sections.entries) {
        for (final entry in section.value.entries) {
          final old = remaining.remove((section.key, entry.key));
          if (old?.value == entry.value) continue;
          batch.insert(
            soundRequestStates,
            SoundRequestStatesCompanion.insert(
              ownerPubkey: owner,
              section: section.key,
              recordKey: entry.key,
              value: entry.value,
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }
      for (final row in remaining.values) {
        batch.deleteWhere(
          soundRequestStates,
          (t) =>
              t.ownerPubkey.equals(owner) &
              t.section.equals(row.section) &
              t.recordKey.equals(row.recordKey),
        );
      }
    });
  });

  /// Removes one deleted account's local-only workflow state.
  Future<int> clearAccount(String owner) => (delete(
    soundRequestStates,
  )..where((t) => t.ownerPubkey.equals(owner))).go();
}
