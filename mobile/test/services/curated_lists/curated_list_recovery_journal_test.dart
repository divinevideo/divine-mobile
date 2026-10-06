// ABOUTME: Covers minimal owner-scoped privacy recovery and legacy migration.
// ABOUTME: Uses the durable preference backing store, including refused writes.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  bool reject = false;
  String? failingKey;
  bool throwOnFailure = false;

  bool _fails(String key) =>
      reject || (failingKey != null && key.endsWith(failingKey!));

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (_fails(key)) {
      if (throwOnFailure) throw StateError('Storage unavailable');
      return false;
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (_fails(key)) {
      if (throwOnFailure) throw StateError('Storage unavailable');
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  group('CuratedListRecoveryJournal', () {
    const owner =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherOwner =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const plaintextId =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const acceptedId =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    final now = DateTime.utc(2026, 10, 5);
    late SharedPreferences prefs;
    late _Store backing;
    late SharedPreferencesStorePlatform previous;
    late CuratedListRecoveryJournal journal;
    var current = true;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      previous = SharedPreferencesStorePlatform.instance;
      backing = _Store();
      SharedPreferencesStorePlatform.instance = backing;
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      current = true;
      journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (operation) async => current && await operation(),
      );
    });

    tearDown(() {
      SharedPreferences.resetStatic();
      SharedPreferencesStorePlatform.instance = previous;
    });

    CuratedList row({String pubkey = owner, bool pendingAccepted = true}) =>
        CuratedList(
          id: 'same-id',
          name: 'Private title never copied into recovery',
          description: 'Private description never copied',
          pubkey: pubkey,
          videoEventIds: const ['private-video'],
          createdAt: now,
          updatedAt: now,
          isPublic: false,
          pendingVisibility: CuratedListVisibility(
            isPublic: true,
            isCollaborative: false,
            allowedCollaborators: const [],
            relayAccepted: pendingAccepted,
          ),
          pendingPlaintextEventIds: const [plaintextId],
        );

    test(
      'migration preserves minimal evidence after an ordinary cache wipe',
      () async {
        await prefs.setString('curated_lists', jsonEncode([row().toJson()]));
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(
          prefs,
          legacyOwner: owner,
        );
        await prefs.remove('curated_lists');
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        journal = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        final saved = journal.record(owner, 'same-id')!;
        expect(saved.plaintextEventIds, [plaintextId]);
        expect(saved.visibility?.isPublic, isTrue);
        final encoded = prefs.getString(
          CuratedListRecoveryJournal.storageKey(owner),
        )!;
        expect(encoded, isNot(contains('Private title')));
        expect(encoded, isNot(contains('Private description')));
        expect(encoded, isNot(contains('private-video')));
      },
    );

    test(
      'migration separates all stored owners without copying private payloads',
      () async {
        final legacy = row().toJson()..remove('pubkey');
        await prefs.setString(
          'curated_lists',
          jsonEncode([
            legacy,
            row(pubkey: otherOwner)
                .copyWith(pendingPlaintextEventIds: [acceptedId])
                .toJson(),
          ]),
        );
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(
          prefs,
          legacyOwner: owner,
        );
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
        expect(journal.record(otherOwner, 'same-id')!.plaintextEventIds, [
          acceptedId,
        ]);
        for (final key in prefs.getKeys().where(
          (key) => key.startsWith(CuratedListRecoveryJournal.storagePrefix),
        )) {
          expect(prefs.getString(key), isNot(contains('Private title')));
          expect(prefs.getString(key), isNot(contains('private-video')));
        }
      },
    );

    test(
      'destructive migration never recreates the deleted owner bucket',
      () async {
        await prefs.setString(
          'curated_lists',
          jsonEncode([
            row().toJson(),
            row(pubkey: otherOwner).toJson(),
          ]),
        );
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(
          prefs,
          legacyOwner: owner,
          deletingOwner: owner,
        );
        expect(journal.records(owner), isEmpty);
        expect(journal.record(otherOwner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
      },
    );

    test(
      'unattributed pending evidence stays archived without guessing an owner',
      () async {
        final unattributed = row().toJson()..remove('pubkey');
        await prefs.setString('curated_lists', jsonEncode([unattributed]));
        final raw = prefs.getString('curated_lists');
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        expect(prefs.getString('curated_lists'), '[]');
        expect(journal.records(owner), isEmpty);
        expect(journal.needsRepair(owner), isTrue);
        final archive = jsonDecode(
          prefs.getString(
            CuratedListRecoveryStorage.sharedQuarantineKey,
          )!,
        ) as Map<String, dynamic>;
        expect(archive['rawBuckets'], [raw]);
      },
    );

    test(
      'an unconfirmed proposal is refused by the accepted-evidence entry point',
      () async {
        expect(
          await journal.accepted(
            owner: owner,
            listId: 'same-id',
            visibility: row(pendingAccepted: false).pendingVisibility!,
            eventId: acceptedId,
            acceptedAt: now,
            plaintextEventIds: [plaintextId],
          ),
          isFalse,
        );
        expect(journal.records(owner), isEmpty);
      },
    );

    test(
      'a scoped record never attaches to a different owner with the same ID',
      () async {
        expect(
          await journal.captureRows([row(), row(pubkey: otherOwner)], owner),
          isTrue,
        );
        expect(journal.records(otherOwner), isEmpty);
        final foreign = row(pubkey: otherOwner).copyWith(
          pendingPlaintextEventIds: const [],
          clearPendingVisibility: true,
        );
        expect(journal.recover(foreign, owner), foreign);
        expect(
          journal
              .recover(
                row().copyWith(
                  pendingPlaintextEventIds: const [],
                  clearPendingVisibility: true,
                ),
                owner,
              )
              .pendingVisibility
              ?.relayAccepted,
          isTrue,
        );
      },
    );

    test(
      'an unconfirmed legacy proposal never becomes acknowledged evidence',
      () async {
        final unconfirmed = row(
          pendingAccepted: false,
        ).copyWith(pendingPlaintextEventIds: const []);
        expect(await journal.captureRows([unconfirmed], owner), isTrue);
        expect(
          prefs.containsKey(CuratedListRecoveryJournal.storageKey(owner)),
          isFalse,
        );
      },
    );

    test(
      'accepted evidence is cleared only after the coherent durable revision',
      () async {
        expect(
          await journal.accepted(
            owner: owner,
            listId: 'same-id',
            visibility: const CuratedListVisibility(
              isPublic: true,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
            eventId: acceptedId,
            acceptedAt: now,
            plaintextEventIds: [plaintextId],
          ),
          isTrue,
        );
        expect(
          await journal.visibilityCommitted(owner, 'same-id', row()),
          isFalse,
        );
        expect(journal.record(owner, 'same-id')!.visibility, isNotNull);
        final committed = row().copyWith(
          isPublic: true,
          nostrEventId: acceptedId,
          updatedAt: now.add(const Duration(microseconds: 1)),
          clearPendingVisibility: true,
        );
        expect(
          await journal.visibilityCommitted(owner, 'same-id', committed),
          isTrue,
        );
        expect(journal.record(owner, 'same-id')!.visibility, isNull);
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
      },
    );

    for (final newerTimestamp in [true, false]) {
      test('newer durable public winner keeps evidence without old permissions '
          'using timestamp=$newerTimestamp', () async {
        expect(
          await journal.accepted(
            owner: owner,
            listId: 'same-id',
            visibility: const CuratedListVisibility(
              isPublic: false,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
            eventId: acceptedId,
            acceptedAt: now,
            plaintextEventIds: [plaintextId],
          ),
          isTrue,
        );
        final winner = row().copyWith(
          isPublic: true,
          clearPendingVisibility: true,
          pendingRepublish: false,
          nostrEventId: 'a' * 64,
          updatedAt: newerTimestamp ? now.add(const Duration(seconds: 1)) : now,
        );
        final recovered = journal.recover(winner, owner);
        expect(recovered.pendingVisibility, isNull);
        expect(recovered.pendingRepublish, isFalse);
        expect(recovered.isPublic, isTrue);
        expect(recovered.nostrEventId, winner.nostrEventId);
        expect(recovered.pendingPlaintextEventIds, [plaintextId]);
        expect(journal.record(owner, 'same-id')!.visibility, isNotNull);
        expect(journal.record(owner, 'same-id')!.requiresPrivateCommit, isTrue);
        expect(
          await journal.visibilityCommitted(owner, 'same-id', winner),
          isTrue,
        );
        expect(journal.record(owner, 'same-id')!.visibility, isNull);
        expect(journal.record(owner, 'same-id')!.requiresPrivateCommit, isTrue);
      });
    }

    test(
      'unsaved real ACK drains before cleanup even when the list cache is absent',
      () async {
        backing.reject = true;
        expect(
          await journal.accepted(
            owner: owner,
            listId: 'same-id',
            visibility: const CuratedListVisibility(
              isPublic: false,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
            eventId: acceptedId,
            acceptedAt: now,
            plaintextEventIds: [plaintextId],
          ),
          isFalse,
        );
        expect(
          prefs.getString(CuratedListRecoveryJournal.storageKey(owner)),
          isNull,
        );
        expect(journal.record(owner, 'same-id')!.visibility!.isPublic, isFalse);
        await expectLater(
          CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs),
          throwsStateError,
        );
        backing.reject = false;
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        journal = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        expect(journal.record(owner, 'same-id')!.visibility!.isPublic, isFalse);
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
      },
    );

    test(
      'cleanup retires superseded permissions using only the durable public row',
      () async {
        final legacy = row().copyWith(
          isPublic: true,
          pendingVisibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
          pendingPlaintextEventIds: [plaintextId],
        );
        await journal.captureRows([legacy], owner);
        expect(journal.record(owner, 'same-id')!.acceptedEventId, isNull);
        final winner = row().copyWith(
          isPublic: true,
          clearPendingVisibility: true,
          pendingRepublish: false,
          pendingPlaintextEventIds: [],
          nostrEventId: 'e' * 64,
          updatedAt: now.add(const Duration(seconds: 1)),
        );
        await journal.captureRows([winner], owner);
        expect(
          journal.record(owner, 'same-id')!.visibility,
          isNotNull,
          reason:
              'a pre-save optimistic candidate is not proof of supersession',
        );
        await prefs.setString('curated_lists', jsonEncode([winner.toJson()]));
        await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
        await prefs.remove('curated_lists');
        SharedPreferences.resetStatic();
        prefs = await SharedPreferences.getInstance();
        journal = CuratedListRecoveryJournal(
          prefs: prefs,
          runCurrent: (op) => op(),
        );
        final older = winner.copyWith(
          nostrEventId: 'a' * 64,
          updatedAt: now.subtract(const Duration(seconds: 1)),
        );
        expect(journal.recover(older, owner).pendingVisibility, isNull);
        expect(journal.recover(older, owner).isPublic, isTrue);
        expect(journal.record(owner, 'same-id')!.visibility, isNull);
        expect(journal.record(owner, 'same-id')!.requiresPrivateCommit, isTrue);
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
      },
    );

    test(
      'destructive pending-ACK cleanup forgets only the exact owner',
      () async {
        backing.reject = true;
        for (final account in [owner, otherOwner]) {
          expect(
            await journal.accepted(
              owner: account,
              listId: 'same-id',
              visibility: const CuratedListVisibility(
                isPublic: false,
                isCollaborative: false,
                allowedCollaborators: [],
                relayAccepted: true,
              ),
              eventId: acceptedId,
              acceptedAt: now,
              plaintextEventIds: [plaintextId],
            ),
            isFalse,
          );
        }
        CuratedListRecoveryJournal.discardPendingAccepted(prefs, owner);
        expect(journal.record(owner, 'same-id'), isNull);
        expect(
          journal.record(otherOwner, 'same-id')!.visibility!.relayAccepted,
          isTrue,
        );
      },
    );

    test('refused write cannot become optimistic recovery evidence', () async {
      backing.reject = true;
      expect(await journal.captureRows([row()], owner), isFalse);
      expect(journal.records(owner), isEmpty);
      await prefs.setString('curated_lists', jsonEncode([row().toJson()]));
      backing.reject = false;
      await prefs.setString('curated_lists', jsonEncode([row().toJson()]));
      backing.reject = true;
      await expectLater(
        CuratedListRecoveryJournal.migrateEmbeddedRecords(
          prefs,
          legacyOwner: owner,
        ),
        throwsStateError,
      );
      expect(prefs.containsKey('curated_lists'), isTrue);
    });

    test('retired session cannot create or clear recovery records', () async {
      expect(await journal.captureRows([row()], owner), isTrue);
      current = false;
      expect(
        await journal.redactionAccepted(owner, 'same-id', plaintextId),
        isFalse,
      );
      expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
        plaintextId,
      ]);
    });

    test(
      'clearing one accepted deletion leaves other pending event IDs',
      () async {
        expect(
          await journal.captureRows([
            row().copyWith(pendingPlaintextEventIds: [plaintextId, acceptedId]),
          ], owner),
          isTrue,
        );
        expect(
          await journal.redactionAccepted(owner, 'same-id', plaintextId),
          isTrue,
        );
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          acceptedId,
        ]);
        expect(journal.record(owner, 'same-id')!.visibility, isNotNull);
      },
    );

    Future<void> restart() async {
      SharedPreferences.resetStatic();
      prefs = await SharedPreferences.getInstance();
      journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (operation) async => current && await operation(),
        runEvidence: (operation) => operation(),
      );
    }

    Future<bool> acknowledge(
      String listId, {
      CuratedListRecoveryTicket? ticket,
    }) => journal.accepted(
      owner: owner,
      listId: listId,
      visibility: const CuratedListVisibility(
        isPublic: false,
        isCollaborative: false,
        allowedCollaborators: [],
        relayAccepted: true,
      ),
      eventId: acceptedId,
      acceptedAt: now,
      plaintextEventIds: [plaintextId],
      ticket: ticket,
    );

    for (final throwing in [false, true]) {
      test(
        'retirement survives a ${throwing ? 'throwing' : 'refused'} write without losing its target or sibling ACK',
        () async {
          expect(await acknowledge('same-id'), isTrue);
          backing.failingKey = CuratedListRecoveryJournal.storageKey(owner);
          backing.throwOnFailure = throwing;
          if (throwing) {
            await expectLater(
              acknowledge('sibling'),
              throwsA(isA<CuratedListRecoveryException>()),
            );
            await expectLater(
              journal.retirePermissions(owner, 'same-id'),
              throwsA(isA<CuratedListRecoveryException>()),
            );
          } else {
            expect(await acknowledge('sibling'), isFalse);
            expect(await journal.retirePermissions(owner, 'same-id'), isFalse);
          }
          expect(journal.record(owner, 'same-id')!.visibility, isNotNull);
          expect(journal.record(owner, 'sibling')!.visibility, isNotNull);
          backing.failingKey = null;
          expect(await journal.retirePermissions(owner, 'same-id'), isTrue);
          await restart();
          final retired = journal.record(owner, 'same-id')!;
          expect(retired.permissionsRetired, isTrue);
          expect(retired.visibility, isNull);
          expect(retired.plaintextEventIds, [plaintextId]);
          expect(retired.requiresPrivateCommit, isTrue);
          expect(journal.record(owner, 'sibling')!.visibility, isNotNull);
          final recreated = journal.recover(
            row().copyWith(clearPendingVisibility: true),
            owner,
          );
          expect(recreated.pendingVisibility, isNull);
          expect(recreated.pendingPlaintextEventIds, [plaintextId]);
        },
      );

      test(
        'corrupt recovery is preserved before logout, including a ${throwing ? 'throwing' : 'refused'} quarantine write',
        () async {
          final key = CuratedListRecoveryJournal.storageKey(owner);
          final raw = jsonEncode({
            'same-id': const CuratedListRecoveryRecord(
              plaintextEventIds: [plaintextId],
            ).toJson(),
            'broken': {'visibility': 'unreadable'},
          });
          await prefs.setString(key, raw);
          expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
            plaintextId,
          ]);
          expect(journal.needsRepair(owner), isTrue);
          backing.failingKey = CuratedListRecoveryStorage.quarantineKey(owner);
          backing.throwOnFailure = throwing;
          if (throwing) {
            await expectLater(
              journal.prepare(owner),
              throwsA(isA<CuratedListRecoveryException>()),
            );
          } else {
            await expectLater(
              journal.prepare(owner),
              throwsA(isA<CuratedListRecoveryException>()),
            );
          }
          await restart();
          expect(prefs.getString(key), raw);
          expect(
            prefs.containsKey(CuratedListRecoveryStorage.quarantineKey(owner)),
            isFalse,
          );
          backing.failingKey = null;
          await journal.prepare(owner);
          await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
          await restart();
          expect(
            jsonDecode(prefs.getString(key)!) as Map,
            isNot(contains('broken')),
          );
          final envelope = jsonDecode(
            prefs.getString(CuratedListRecoveryStorage.quarantineKey(owner))!,
          ) as Map<String, dynamic>;
          expect(envelope['rawBuckets'], [raw]);
          expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
            plaintextId,
          ]);
          expect(await journal.ticket(owner, 'same-id'), isNull);
          expect(journal.needsRepair(owner), isTrue);
        },
      );

      test(
        'owner deletion generation rejects stale ACKs after a ${throwing ? 'throwing' : 'refused'} tombstone write is retried',
        () async {
          final ticket = await journal.ticket(owner, 'same-id');
          expect(ticket, isNotNull);
          backing.failingKey = CuratedListRecoveryStorage.generationKey(owner);
          backing.throwOnFailure = throwing;
          await expectLater(
            CuratedListRecoveryJournal.invalidateOwner(prefs, owner),
            throwsA(isA<CuratedListRecoveryException>()),
          );
          await restart();
          expect(
            prefs.containsKey(CuratedListRecoveryStorage.generationKey(owner)),
            isFalse,
          );
          backing.failingKey = null;
          await CuratedListRecoveryJournal.invalidateOwner(prefs, owner);
          await restart();
          expect(await acknowledge('same-id', ticket: ticket), isFalse);
          expect(journal.records(owner), isEmpty);
          expect(
            await acknowledge(
              'same-id',
              ticket: await journal.ticket(owner, 'same-id'),
            ),
            isTrue,
          );
        },
      );
    }

    test('captured evidence survives logout but cannot authorize cache writes or a deleted coordinate', () async {
      journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (operation) async => current && await operation(),
        runEvidence: (operation) => operation(),
      );
      final ticket = await journal.ticket(owner, 'same-id');
      current = false;
      expect(await acknowledge('same-id', ticket: ticket), isTrue);
      expect(await journal.retirePermissions(owner, 'same-id'), isFalse);
      current = true;
      expect(await journal.retirePermissions(owner, 'same-id'), isTrue);
      expect(await acknowledge('same-id', ticket: ticket), isFalse);
      await restart();
      expect(journal.record(owner, 'same-id')!.visibility, isNull);
      expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
        plaintextId,
      ]);
      expect(
        await acknowledge(
          'same-id',
          ticket: await journal.ticket(owner, 'same-id'),
        ),
        isTrue,
      );
      expect(journal.record(owner, 'same-id')!.permissionsRetired, isFalse);
    });

    test('completely invalid JSON is quarantined without inventing empty accepted evidence', () async {
      final key = CuratedListRecoveryJournal.storageKey(owner);
      const raw = '{invalid recovery';
      await prefs.setString(key, raw);
      expect(journal.records(owner), isEmpty);
      await journal.prepare(owner);
      await restart();
      final envelope = jsonDecode(
        prefs.getString(CuratedListRecoveryStorage.quarantineKey(owner))!,
      ) as Map<String, dynamic>;
      expect(envelope['rawBuckets'], [raw]);
      expect(journal.needsRepair(owner), isTrue);
      expect(prefs.getString(key), '{}');
      expect(envelope['normalized'], isTrue);
    });

    for (final throwing in [false, true]) {
      test(
        'committing one permission target preserves a memory-only sibling after ${throwing ? 'throwing' : 'refused'} storage',
        () async {
          expect(await acknowledge('same-id'), isTrue);
          backing.failingKey = CuratedListRecoveryJournal.storageKey(owner);
          backing.throwOnFailure = throwing;
          if (throwing) {
            await expectLater(
              acknowledge('sibling'),
              throwsA(isA<CuratedListRecoveryException>()),
            );
          } else {
            expect(await acknowledge('sibling'), isFalse);
          }
          backing.failingKey = null;
          final committed = row().copyWith(
            nostrEventId: acceptedId,
            clearPendingVisibility: true,
          );
          expect(
            await journal.visibilityCommitted(owner, 'same-id', committed),
            isTrue,
          );
          await restart();
          expect(journal.record(owner, 'same-id')!.visibility, isNull);
          expect(
            journal.record(owner, 'sibling')!.visibility!.isPublic,
            isFalse,
          );
          expect(journal.record(owner, 'sibling')!.plaintextEventIds, [
            plaintextId,
          ]);
        },
      );

      test(
        'refused deletion-evidence removal remains durable when storage ${throwing ? 'throws' : 'returns false'}',
        () async {
          expect(
            await journal.captureRows([
              row().copyWith(clearPendingVisibility: true),
            ], owner),
            isTrue,
          );
          backing.failingKey = CuratedListRecoveryJournal.storageKey(owner);
          backing.throwOnFailure = throwing;
          if (throwing) {
            await expectLater(
              journal.redactionAccepted(owner, 'same-id', plaintextId),
              throwsA(isA<CuratedListRecoveryException>()),
            );
          } else {
            expect(
              await journal.redactionAccepted(owner, 'same-id', plaintextId),
              isFalse,
            );
          }
          await restart();
          expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
            plaintextId,
          ]);
          backing.failingKey = null;
          expect(
            await journal.redactionAccepted(owner, 'same-id', plaintextId),
            isTrue,
          );
          await restart();
          expect(journal.record(owner, 'same-id'), isNull);
        },
      );
    }

    test('a fresh incarnation ACK wins over retired evidence even with an older timestamp', () async {
      expect(
        await journal.accepted(
          owner: owner,
          listId: 'same-id',
          visibility: row().pendingVisibility!,
          eventId: acceptedId,
          acceptedAt: now.add(const Duration(seconds: 30)),
          plaintextEventIds: [plaintextId],
        ),
        isTrue,
      );
      expect(await journal.retirePermissions(owner, 'same-id'), isTrue);
      expect(
        await acknowledge(
          'same-id',
          ticket: await journal.ticket(owner, 'same-id'),
        ),
        isTrue,
      );
      await restart();
      expect(journal.record(owner, 'same-id')!.permissionsRetired, isFalse);
      expect(journal.record(owner, 'same-id')!.visibility!.isPublic, isFalse);
      expect(journal.record(owner, 'same-id')!.acceptedAt, now);
      expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
        plaintextId,
      ]);
    });

    test(
      'a recreated public ACK cannot certify an unpublished private union',
      () async {
        expect(
          await journal.captureRows([
            row().copyWith(
              clearNostrEventId: true,
              clearPendingVisibility: true,
            ),
          ], owner),
          isTrue,
        );
        expect(await journal.retirePermissions(owner, 'same-id'), isTrue);
        expect(
          await journal.accepted(
            owner: owner,
            listId: 'same-id',
            visibility: row().pendingVisibility!,
            eventId: acceptedId,
            acceptedAt: now,
            plaintextEventIds: [plaintextId],
            ticket: await journal.ticket(owner, 'same-id'),
          ),
          isTrue,
        );
        expect(journal.record(owner, 'same-id')!.requiresPrivateCommit, isTrue);
        expect(
          await journal.visibilityCommitted(
            owner,
            'same-id',
            row().copyWith(
              isPublic: true,
              nostrEventId: acceptedId,
              clearPendingVisibility: true,
            ),
          ),
          isTrue,
        );
        await restart();
        expect(journal.record(owner, 'same-id')!.requiresPrivateCommit, isTrue);
        expect(journal.record(owner, 'same-id')!.plaintextEventIds, [
          plaintextId,
        ]);
      },
    );
  });
}
