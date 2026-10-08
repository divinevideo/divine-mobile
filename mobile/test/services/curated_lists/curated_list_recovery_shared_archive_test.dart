// ABOUTME: Unresolved ownership labels never inherit a legacy account marker.
// ABOUTME: Missing archive provenance cannot imply completed account erasure.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _pending =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  late SharedPreferencesStorePlatform previous;
  late SharedPreferences prefs;
  late CuratedListRecoveryJournal journal;

  Map<String, dynamic> readableLegacyRow() => CuratedList(
    id: 'legacy-private',
    name: 'Unattributed legacy privacy work',
    videoEventIds: const [],
    isPublic: false,
    createdAt: DateTime.utc(2026, 10, 7),
    updatedAt: DateTime.utc(2026, 10, 7),
    pendingPlaintextEventIds: const [_pending],
  ).toJson();

  Future<String> load({String? label}) async {
    final row = readableLegacyRow();
    if (label != null) row[label] = _bob;
    final raw = jsonEncode([row]);
    SharedPreferences.setMockInitialValues({
      'curated_lists': raw,
      'current_user_pubkey_hex': _alice,
    });
    prefs = await SharedPreferences.getInstance();
    final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: sessions.writes.runExclusive,
    );
    return raw;
  }

  setUp(() => previous = SharedPreferencesStorePlatform.instance);
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });

  Future<void> restart() async {
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: sessions.writes.runExclusive,
    );
  }

  group('prepare ambiguous owner labels', () {
    for (final label in ['ownerPubkey', 'authorPubkey']) {
      test(
        'null primary $label conflict is held before normalization',
        () async {
          final raw = await load(label: label);
          expect(journal.needsRepair(_alice), isTrue);
          expect(journal.needsRepair(_bob), isTrue);
          expect(prefs.getString('curated_lists'), raw);
        },
      );

      test(
        'null primary $label conflict remains raw after preparation',
        () async {
          final raw = await load(label: label);
          await journal.prepare(_alice);
          expect(journal.record(_alice, 'legacy-private'), isNull);
          expect(journal.record(_bob, 'legacy-private'), isNull);
          expect(journal.needsRepair(_alice), isTrue);
          expect(journal.needsRepair(_bob), isTrue);
          final archive = jsonDecode(
            prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey)!,
          ) as Map;
          expect(archive['rawBuckets'], contains(raw));
          expect(archive['originalLiveValue'], raw);
        },
      );

      test(
        'null primary $label conflict cannot migrate to the marker owner',
        () async {
          final raw = await load(label: label);
          final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
          await sessions.writes.runExclusive(
            () => CuratedListRecoveryJournal.migrateEmbeddedRecords(
              prefs,
              legacyOwner: _alice,
            ),
          );
          expect(journal.record(_alice, 'legacy-private'), isNull);
          expect(journal.record(_bob, 'legacy-private'), isNull);
          expect(journal.needsRepair(_alice), isTrue);
          expect(journal.needsRepair(_bob), isTrue);
          expect(
            (jsonDecode(
              prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey)!,
            ) as Map)['rawBuckets'],
            contains(raw),
          );
        },
      );

      test(
        'null primary $label conflict cannot be erased as marker-owned data',
        () async {
          final raw = await load(label: label);
          await journal.prepare(_alice);
          await expectLater(
            UserDataCleanupService(prefs).deleteAccountData(
              _alice,
              userNpub: 'synthetic-alice-npub',
              preserveActiveSession: true,
            ),
            throwsA(isA<CuratedListRecoveryException>()),
          );
          await restart();
          final archive = jsonDecode(
            prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey)!,
          ) as Map;
          expect(archive['rawBuckets'], contains(raw));
          expect(archive['originalLiveValue'], raw);
          expect(PendingAccountCleanup.read(prefs)?.userPubkey, _alice);
          expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
          expect(journal.needsRepair(_bob), isTrue);
        },
      );
    }
  });

  group('prepare legacy marker compatibility', () {
    test(
      'unlabelled readable legacy row keeps accepted marker compatibility',
      () async {
        await load();
        await journal.prepare(_alice);
        expect(journal.needsRepair(_alice), isFalse);
        expect(journal.record(_alice, 'legacy-private')?.plaintextEventIds, [
          _pending,
        ]);
        expect(
          prefs.containsKey(CuratedListRecoveryStorage.sharedQuarantineKey),
          isFalse,
        );
      },
    );
  });

  group('deleteAccountData missing provenance', () {
    test(
      'missing-provenance archive keeps deletion explicitly incomplete',
      () async {
        await load();
        await prefs.setString('curated_lists', '[]');
        final raw = jsonEncode({
          'version': 2,
          'rawBuckets': <String>[],
          'recordBackups': <String>[],
          'records': <String, dynamic>{},
          'originalLiveValue': null,
          'normalized': true,
          'needsRepair': true,
          'ownerWide': true,
          'unresolvedCoordinates': <String>[],
        });
        await prefs.setString(
          CuratedListRecoveryStorage.sharedQuarantineKey,
          raw,
        );
        expect(journal.needsRepair(_alice), isTrue);
        expect(journal.needsRepair(_bob), isTrue);
        await expectLater(
          UserDataCleanupService(prefs).deleteAccountData(
            _alice,
            userNpub: 'synthetic-alice-npub',
            preserveActiveSession: true,
          ),
          throwsA(isA<CuratedListRecoveryException>()),
        );
        await restart();
        expect(
          prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey),
          raw,
        );
        expect(PendingAccountCleanup.read(prefs)?.userPubkey, _alice);
        expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
        expect(journal.needsRepair(_bob), isTrue);
      },
    );
  });
}
