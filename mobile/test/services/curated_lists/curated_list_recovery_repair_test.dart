// ABOUTME: Repairs only audited recovery reconstructions with current snapshots.
// ABOUTME: Protects live ACKs, retired coordinates and unknown-owner backups.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  String? rejectedKey;
  String? lyingKey;
  @override
  Future<bool> setValue(String type, String key, Object value) async =>
      key.endsWith(rejectedKey ?? '\u0000')
      ? false
      : key.endsWith(lyingKey ?? '\u0000')
      ? true
      : super.setValue(type, key, value);
}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _incoming =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _oldId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _event =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _newId =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

void main() {
  late _Store backend;
  late SharedPreferences prefs;
  late CuratedListRecoveryJournal journal;
  late SharedPreferencesStorePlatform previous;
  final key = CuratedListRecoveryJournal.storageKey(_owner);
  final archiveKey = CuratedListRecoveryStorage.quarantineKey(_owner);
  final now = DateTime.utc(2026, 10, 6);
  final raw = jsonEncode({
    'healthy': const CuratedListRecoveryRecord(plaintextEventIds: [_oldId])
        .toJson(),
    'bad': {'visibility': 'unreadable'},
  });
  final replacement = jsonEncode({
    'bad': const CuratedListRecoveryRecord(plaintextEventIds: [_newId])
        .toJson(),
  });

  setUp(() async {
    previous = SharedPreferencesStorePlatform.instance;
    backend = _Store();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = backend;
    prefs = await SharedPreferences.getInstance();
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (operation) => operation(),
    );
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });
  Future<void> prepare() async {
    await prefs.setString(key, raw);
    await journal.prepare(_owner);
  }

  Future<void> restart() async {
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (operation) => operation(),
    );
  }

  group('CuratedListRecoveryRepair', () {
    test('verified repair releases only the resolved hold and retains raw bytes, not old live records', () async {
      await prepare();
      await journal.redactionAccepted(_owner, 'healthy', _oldId);
      final snapshot = journal.repairSnapshot(_owner);
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: snapshot,
          reconstructedJournal: replacement,
        ),
        isTrue,
      );
      await restart();
      expect(journal.needsRepair(_owner), isFalse);
      expect(await journal.ticket(_owner, 'bad'), isNotNull);
      expect(journal.record(_owner, 'bad')!.plaintextEventIds, [_newId]);
      expect(journal.record(_owner, 'healthy'), isNull);
      expect((jsonDecode(prefs.getString(archiveKey)!) as Map)['rawBuckets'], [
        raw,
      ]);
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: replacement,
        ),
        isFalse,
      );
    });

    for (final invalid in [
      '{}',
      '{"id":"a public list"}',
      '{"bad":{"plaintextEventIds":["invalid"]}}',
      '{"bad":{"plaintextEventIds":["${_newId.toUpperCase()}"]}}',
      jsonEncode({
        'bad': CuratedListRecoveryRecord(
          acceptedEventId: _event,
          acceptedAt: now,
          visibility: CuratedListVisibility(
            isPublic: true,
            isCollaborative: true,
            allowedCollaborators: [_incoming.toUpperCase()],
            relayAccepted: true,
          ),
        ).toJson(),
      }),
      '{"wrong-coordinate":{"plaintextEventIds":["$_newId"]}}',
    ]) {
      test(
        'reset, public-list and incomplete proposals cannot release a hold: $invalid',
        () async {
          await prepare();
          final before = prefs.getString(archiveKey);
          expect(
            await journal.repairVerifiedJournal(
              owner: _owner,
              expectedSnapshot: journal.repairSnapshot(_owner),
              reconstructedJournal: invalid,
            ),
            isFalse,
          );
          expect(journal.needsRepair(_owner), isTrue);
          expect(prefs.getString(archiveKey), before);
        },
      );
    }

    test(
      'a late ACK or generation change rejects a stale repair snapshot',
      () async {
        final ticket = await journal.ticket(_owner, 'bad');
        await prepare();
        final stale = journal.repairSnapshot(_owner);
        expect(
          await journal.accepted(
            owner: _owner,
            listId: 'bad',
            visibility: const CuratedListVisibility(
              isPublic: false,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
            eventId: _event,
            acceptedAt: now,
            plaintextEventIds: const [_newId],
            ticket: ticket,
          ),
          isTrue,
        );
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: stale,
            reconstructedJournal: replacement,
          ),
          isFalse,
        );
        expect(journal.record(_owner, 'bad')!.acceptedEventId, _event);
        final generationSnapshot = journal.repairSnapshot(_owner);
        await CuratedListRecoveryJournal.invalidateOwner(prefs, _owner);
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: generationSnapshot,
            reconstructedJournal: replacement,
          ),
          isFalse,
        );
      },
    );

    test(
      'older reconstructed permissions and IDs cannot override a newer live ACK',
      () async {
        final ticket = await journal.ticket(_owner, 'bad');
        await prepare();
        await journal.accepted(
          owner: _owner,
          listId: 'bad',
          visibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
          eventId: _event,
          acceptedAt: now.add(const Duration(seconds: 5)),
          plaintextEventIds: const [_newId],
          ticket: ticket,
        );
        final older = jsonEncode({
          'bad': CuratedListRecoveryRecord(
            plaintextEventIds: const [_oldId],
            acceptedEventId: _oldId,
            acceptedAt: now,
            visibility: const CuratedListVisibility(
              isPublic: true,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
          ).toJson(),
        });
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: journal.repairSnapshot(_owner),
            reconstructedJournal: older,
          ),
          isTrue,
        );
        final live = journal.record(_owner, 'bad')!;
        expect(live.acceptedEventId, _event);
        expect(live.visibility!.isPublic, isFalse);
        expect(live.plaintextEventIds, [_newId]);
      },
    );

    test(
      'a retired coordinate cannot regain old permissions through reconstruction',
      () async {
        await prepare();
        await journal.retirePermissions(
          _owner,
          'bad',
          coordinateDeletionAccepted: true,
        );
        final older = jsonEncode({
          'bad': CuratedListRecoveryRecord(
            plaintextEventIds: const [_oldId],
            acceptedEventId: _oldId,
            acceptedAt: now,
            visibility: const CuratedListVisibility(
              isPublic: true,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
          ).toJson(),
        });
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: journal.repairSnapshot(_owner),
            reconstructedJournal: older,
          ),
          isTrue,
        );
        final live = journal.record(_owner, 'bad')!;
        expect(live.permissionsRetired, isTrue);
        expect(live.visibility, isNull);
        expect(live.plaintextEventIds, isEmpty);
      },
    );

    test('shared repair uses explicit owners and never backfills raw private cache into the active account', () async {
      const sharedRaw = 'unreadable private shared payload';
      await prefs.setString('curated_lists', sharedRaw);
      await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
      expect(
        await journal.repairVerifiedShared(
          activeOwner: _incoming,
          expectedSnapshot: journal.repairSnapshot(_incoming),
          reconstructedJournals: {},
        ),
        isFalse,
      );
      expect(
        await journal.repairVerifiedShared(
          activeOwner: _incoming,
          expectedSnapshot: journal.repairSnapshot(_incoming),
          reconstructedJournals: {'unattributed': replacement},
        ),
        isFalse,
      );
      expect(
        await journal.repairVerifiedShared(
          activeOwner: _incoming,
          expectedSnapshot: journal.repairSnapshot(_incoming),
          reconstructedJournals: {_owner: replacement},
        ),
        isTrue,
      );
      await restart();
      expect(journal.records(_incoming), isEmpty);
      expect(journal.record(_owner, 'bad')!.plaintextEventIds, [_newId]);
      expect(journal.needsRepair(_incoming), isFalse);
      expect(prefs.getString('curated_lists'), '[]');
      expect(
        (jsonDecode(
          prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey)!,
        ) as Map)['rawBuckets'],
        [sharedRaw],
      );
    });

    test('refused repair completion leaves the hold and reconstructed records durable', () async {
      await prepare();
      backend.rejectedKey = archiveKey;
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: replacement,
        ),
        isFalse,
      );
      await restart();
      expect(journal.needsRepair(_owner), isTrue);
      expect(journal.record(_owner, 'bad')!.plaintextEventIds, [_newId]);
      backend.rejectedKey = null;
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: replacement,
        ),
        isTrue,
      );
    });

    test('unreadable quarantine envelopes are themselves preserved before read-only recovery', () async {
      await prefs.setString(
        key,
        jsonEncode({
          'healthy': const CuratedListRecoveryRecord(
            plaintextEventIds: [_oldId],
          ).toJson(),
        }),
      );
      const badArchive = '{unreadable archive';
      await prefs.setString(archiveKey, badArchive);
      await journal.prepare(_owner);
      await restart();
      expect(journal.record(_owner, 'healthy')!.plaintextEventIds, [_oldId]);
      expect(journal.needsRepair(_owner), isTrue);
      expect((jsonDecode(prefs.getString(archiveKey)!) as Map)['rawBuckets'], [
        badArchive,
      ]);
    });
    test(
      'uppercase shared owner proposals are refused before bucket writes',
      () async {
        await prefs.setString(
          'curated_lists',
          'unreadable raw shared evidence',
        );
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        final archiveBefore = prefs.getString(
          CuratedListRecoveryStorage.sharedQuarantineKey,
        );
        expect(
          await journal.repairVerifiedShared(
            activeOwner: _incoming,
            expectedSnapshot: journal.repairSnapshot(_incoming),
            reconstructedJournals: {_owner.toUpperCase(): replacement},
          ),
          isFalse,
        );
        expect(journal.needsRepair(_incoming), isTrue);
        expect(
          prefs.containsKey(
            CuratedListRecoveryJournal.storageKey(_owner.toUpperCase()),
          ),
          isFalse,
        );
        expect(
          prefs.getString(CuratedListRecoveryStorage.sharedQuarantineKey),
          archiveBefore,
        );
      },
    );

    test('a successful backend response without a durable journal cannot release the hold', () async {
      await prepare();
      backend.lyingKey = key;
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: replacement,
        ),
        isFalse,
      );
      await restart();
      expect(journal.needsRepair(_owner), isTrue);
      expect(journal.record(_owner, 'bad'), isNull);
    });

    test(
      'an undurable explicit shared journal leaves the device hold intact',
      () async {
        await prefs.setString(
          'curated_lists',
          'unreadable raw shared evidence',
        );
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        backend.lyingKey = key;
        expect(
          await journal.repairVerifiedShared(
            activeOwner: _incoming,
            expectedSnapshot: journal.repairSnapshot(_incoming),
            reconstructedJournals: {_owner: replacement},
          ),
          isFalse,
        );
        await restart();
        expect(journal.needsRepair(_incoming), isTrue);
        expect(journal.record(_owner, 'bad'), isNull);
      },
    );

    test(
      'same ACK reconstruction preserves later commit and redaction progress',
      () async {
        final ticket = await journal.ticket(_owner, 'bad');
        await prepare();
        const visibility = CuratedListVisibility(
          isPublic: false,
          isCollaborative: false,
          allowedCollaborators: [],
          relayAccepted: true,
        );
        await journal.accepted(
          owner: _owner,
          listId: 'bad',
          visibility: visibility,
          eventId: _event,
          acceptedAt: now,
          plaintextEventIds: const [_oldId, _newId],
          ticket: ticket,
        );
        await journal.visibilityCommitted(
          _owner,
          'bad',
          CuratedList(
            id: 'bad',
            name: 'Private',
            pubkey: _owner,
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now,
            nostrEventId: _event,
            isPublic: false,
          ),
        );
        await journal.redactionAccepted(_owner, 'bad', _oldId);
        final originalRevision = jsonEncode({
          'bad': CuratedListRecoveryRecord(
            plaintextEventIds: const [_oldId],
            visibility: visibility,
            acceptedEventId: _event,
            acceptedAt: now,
          ).toJson(),
        });
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: journal.repairSnapshot(_owner),
            reconstructedJournal: originalRevision,
          ),
          isTrue,
        );
        await restart();
        expect(journal.record(_owner, 'bad')!.plaintextEventIds, [_newId]);
        expect(journal.record(_owner, 'bad')!.visibility, isNull);
      },
    );

    test(
      'case aliases cannot undo acknowledged commit and redaction progress',
      () async {
        final ticket = await journal.ticket(_owner, 'bad');
        await prepare();
        const visibility = CuratedListVisibility(
          isPublic: false,
          isCollaborative: false,
          allowedCollaborators: [],
          relayAccepted: true,
        );
        await journal.accepted(
          owner: _owner,
          listId: 'bad',
          visibility: visibility,
          eventId: _event,
          acceptedAt: now,
          plaintextEventIds: const [_oldId, _newId],
          ticket: ticket,
        );
        await journal.visibilityCommitted(
          _owner,
          'bad',
          CuratedList(
            id: 'bad',
            name: 'Private',
            pubkey: _owner,
            videoEventIds: const [],
            createdAt: now,
            updatedAt: now,
            nostrEventId: _event,
            isPublic: false,
          ),
        );
        await journal.redactionAccepted(_owner, 'bad', _oldId);
        final proposal = jsonEncode({
          'bad': CuratedListRecoveryRecord(
            plaintextEventIds: const [_oldId],
            visibility: visibility,
            acceptedEventId: _event.toUpperCase(),
            acceptedAt: now,
          ).toJson(),
        });
        expect(
          await journal.repairVerifiedJournal(
            owner: _owner,
            expectedSnapshot: journal.repairSnapshot(_owner),
            reconstructedJournal: proposal,
          ),
          isFalse,
        );
        expect(journal.record(_owner, 'bad')!.plaintextEventIds, [_newId]);
        expect(journal.record(_owner, 'bad')!.visibility, isNull);
        expect(journal.needsRepair(_owner), isTrue);
      },
    );

    test('later corruption does not require already repaired and drained coordinates', () async {
      await prepare();
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: replacement,
        ),
        isTrue,
      );
      await journal.redactionAccepted(_owner, 'bad', _newId);
      expect(journal.record(_owner, 'bad'), isNull);
      const laterRaw = '{"later":true}';
      await prefs.setString(key, laterRaw);
      await journal.prepare(_owner);
      expect(
        await journal.repairVerifiedJournal(
          owner: _owner,
          expectedSnapshot: journal.repairSnapshot(_owner),
          reconstructedJournal: jsonEncode({
            'later': const CuratedListRecoveryRecord(
              plaintextEventIds: [_newId],
            ).toJson(),
          }),
        ),
        isTrue,
      );
      await restart();
      expect(journal.needsRepair(_owner), isFalse);
      expect(journal.record(_owner, 'bad'), isNull);
      expect(journal.record(_owner, 'later')!.plaintextEventIds, [_newId]);
      expect(
        (jsonDecode(prefs.getString(archiveKey)!) as Map)['rawBuckets'],
        containsAll([raw, laterRaw]),
      );
    });
  });
}
