// ABOUTME: Account ownership fences shared recovery holds and explicit erasure.
// ABOUTME: Unknown bytes remain evidence and prevent a false deletion success.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/curated_lists/curated_list_session_coordinator.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _Auth extends Mock implements AuthService {}

class _Client extends Mock implements NostrClient {}

const _alice =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _bob = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _aliceVideo =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _bobVideo =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  String? refusedKey;
  int? refusedWriteNumber;
  final writes = <String, int>{};
  String? lyingKey;
  String? refusedRemoval;
  String? lyingRemoval;
  bool failReadback = false;

  @override
  Future<Map<String, Object>> getAll() async {
    if (failReadback) throw StateError('synthetic readback unavailable');
    return super.getAll();
  }

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final count = writes.update(key, (value) => value + 1, ifAbsent: () => 1);
    if (key.endsWith(refusedKey ?? '\u0000') &&
        (refusedWriteNumber == null || count == refusedWriteNumber)) {
      return false;
    }
    if (key.endsWith(lyingKey ?? '\u0000')) return true;
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async =>
      key.endsWith(refusedRemoval ?? '\u0000')
      ? false
      : key.endsWith(lyingRemoval ?? '\u0000')
      ? true
      : super.remove(key);
}

void main() {
  late SharedPreferences prefs;
  late SharedPreferencesStorePlatform previous;
  late _Store store;
  late CuratedListRecoveryJournal journal;
  final now = DateTime.utc(2026, 10, 7);
  const archiveKey = CuratedListRecoveryStorage.sharedQuarantineKey;

  Map<String, dynamic> row(String owner) => CuratedList(
    id: owner == _alice ? 'alice-private' : 'bob-private',
    name: owner == _alice ? 'Alice private sentinel' : 'Bob private sentinel',
    description: owner == _alice
        ? 'Alice private description'
        : 'Bob description',
    pubkey: owner,
    videoEventIds: [if (owner == _alice) _aliceVideo else _bobVideo],
    isPublic: false,
    createdAt: now,
    updatedAt: now,
    pendingPlaintextEventIds: [if (owner == _alice) _aliceVideo else _bobVideo],
  ).toJson();

  Map<String, dynamic> damaged(String owner) => {
    ...row(owner),
    'updatedAt': 'invalid private date',
  };

  setUp(() async {
    previous = SharedPreferencesStorePlatform.instance;
    store = _Store();
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = store;
    prefs = await SharedPreferences.getInstance();
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (op) => op(),
    );
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });

  Future<void> restart() async {
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (op) => op(),
    );
  }

  Future<void> prepare(List<Object> rows) async {
    await prefs.setString('curated_lists', jsonEncode(rows));
    await prefs.setString('current_user_pubkey_hex', _bob);
    await journal.prepare(_bob);
  }

  Future<int> deleteAlice() => UserDataCleanupService(prefs).deleteAccountData(
    _alice,
    userNpub: 'synthetic-alice-npub',
    preserveActiveSession: true,
  );

  test(
    'a malformed known owner holds only that owner across restart',
    () async {
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      expect(journal.needsRepair(_alice), isTrue);
      expect(journal.needsRepair(_bob), isFalse);
      expect(await journal.ticket(_alice, 'new'), isNull);
      expect(await journal.ticket(_bob, 'new'), isNotNull);
      await restart();
      expect(journal.needsRepair(_alice), isTrue);
      expect(journal.needsRepair(_bob), isFalse);
      expect(prefs.getString(archiveKey), contains('invalid private date'));
    },
  );

  test('unknown row evidence keeps every account held', () async {
    await prepare([
      row(_alice),
      row(_bob),
      {'opaque': 'unknown privacy work'},
    ]);
    expect(journal.needsRepair(_alice), isTrue);
    expect(journal.needsRepair(_bob), isTrue);
    expect(await journal.ticket(_bob, 'new'), isNull);
  });

  test('explicit deletion scrubs all owned cache and archive copies', () async {
    await prepare([row(_alice), row(_bob), damaged(_alice)]);
    final saved =
        jsonDecode(prefs.getString(archiveKey)!) as Map<String, dynamic>;
    saved['rawBuckets'] = [...saved['rawBuckets'] as List, jsonEncode(saved)];
    saved['recordBackups'] = [
      jsonEncode([row(_alice), row(_bob)]),
    ];
    await prefs.setString(archiveKey, jsonEncode(saved));
    final lease = CuratedListSessionCoordinator.forPreferences(prefs).acquire();
    await deleteAlice();
    expect(lease.isCurrent, isTrue);
    await restart();
    final all = prefs.getKeys().map(prefs.get).join('\n');
    expect(all, isNot(contains('Alice private sentinel')));
    expect(all, isNot(contains('Alice private description')));
    expect(all, isNot(contains(_aliceVideo)));
    expect(all, contains('Bob private sentinel'));
    expect(all, contains(_bobVideo));
    expect(journal.needsRepair(_bob), isFalse);
    expect(PendingAccountCleanup.read(prefs), isNull);
  });

  test(
    'opaque data survives while deletion is explicitly incomplete',
    () async {
      await prepare([
        row(_alice),
        row(_bob),
        {'opaque': 'unknown privacy work'},
      ]);
      await expectLater(
        deleteAlice(),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      await restart();
      final all = prefs.getKeys().map(prefs.get).join('\n');
      expect(all, isNot(contains('Alice private sentinel')));
      expect(all, isNot(contains(_aliceVideo)));
      expect(all, contains('Bob private sentinel'));
      expect(all, contains('unknown privacy work'));
      expect(journal.needsRepair(_bob), isTrue);
      final pending = PendingAccountCleanup.read(prefs)!;
      expect(pending.userPubkey, _alice);
      expect(pending.deleteUserData, isTrue);
    },
  );

  test('conflicting row owner labels retain the conservative hold', () async {
    await prepare([
      row(_bob),
      {...damaged(_alice), 'ownerPubkey': _bob},
    ]);
    expect(journal.needsRepair(_bob), isTrue);
    await expectLater(
      deleteAlice(),
      throwsA(isA<CuratedListRecoveryException>()),
    );
    expect(prefs.getString(archiveKey), contains('Alice private sentinel'));
  });

  test(
    'ordinary sign-out preserves every owner and unknown privacy record',
    () async {
      await prepare([
        row(_alice),
        row(_bob),
        {'opaque': 'unknown privacy work'},
      ]);
      final before = prefs.getString(archiveKey);
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _bob);
      await restart();
      expect(prefs.getString(archiveKey), before);
      expect(journal.record(_alice, 'alice-private')!.plaintextEventIds, [
        _aliceVideo,
      ]);
      expect(journal.record(_bob, 'bob-private')!.plaintextEventIds, [
        _bobVideo,
      ]);
      expect(PendingAccountCleanup.read(prefs), isNull);
    },
  );

  test('repaired archives still erase retained owned raw copies', () async {
    await prepare([row(_alice), row(_bob), damaged(_alice)]);
    final replacement = jsonEncode({
      'alice-private': const CuratedListRecoveryRecord(
        plaintextEventIds: [_aliceVideo],
      ).toJson(),
    });
    expect(
      await journal.repairVerifiedShared(
        activeOwner: _bob,
        expectedSnapshot: journal.repairSnapshot(_bob),
        reconstructedJournals: {_alice.toUpperCase(): replacement},
      ),
      isTrue,
    );
    expect(journal.needsRepair(_alice), isFalse);
    expect(prefs.getString(archiveKey), contains('Alice private sentinel'));
    await deleteAlice();
    await restart();
    expect(
      prefs.getKeys().map(prefs.get).join('\n'),
      isNot(contains(_aliceVideo)),
    );
    expect(prefs.getKeys().map(prefs.get).join('\n'), contains(_bobVideo));
  });

  for (final lying in [false, true]) {
    test(
      '${lying ? 'lying' : 'refused'} shared erasure retains pending deletion and disk evidence',
      () async {
        await prepare([row(_alice), row(_bob), damaged(_alice)]);
        final before = prefs.getString(archiveKey);
        if (lying) {
          store.lyingKey = archiveKey;
        } else {
          store.refusedKey = archiveKey;
        }
        await expectLater(
          deleteAlice(),
          throwsA(isA<CuratedListRecoveryException>()),
        );
        await restart();
        expect(prefs.getString(archiveKey), before);
        expect(PendingAccountCleanup.read(prefs)!.deleteUserData, isTrue);
        store.lyingKey = null;
        store.refusedKey = null;
        await deleteAlice();
        expect(prefs.getString(archiveKey), isNot(contains(_aliceVideo)));
        expect(PendingAccountCleanup.read(prefs), isNull);
      },
    );
  }

  test('a fully opaque archive prevents a false deletion completion', () async {
    await prefs.setString(archiveKey, '{opaque private recovery bytes');
    await expectLater(
      deleteAlice(),
      throwsA(isA<CuratedListRecoveryException>()),
    );
    await restart();
    expect(prefs.getString(archiveKey), '{opaque private recovery bytes');
    expect(PendingAccountCleanup.read(prefs)!.userPubkey, _alice);
    expect(journal.needsRepair(_bob), isTrue);
  });

  test('unknown shared staged and backup records prevent completion', () async {
    await prepare([row(_alice), row(_bob), damaged(_alice)]);
    final archive =
        jsonDecode(prefs.getString(archiveKey)!) as Map<String, dynamic>;
    final unknown = {
      'unattributed': const CuratedListRecoveryRecord(
        plaintextEventIds: [_bobVideo],
      ).toJson(),
    };
    archive['records'] = unknown;
    archive['recordBackups'] = [jsonEncode(unknown)];
    await prefs.setString(archiveKey, jsonEncode(archive));
    await expectLater(
      deleteAlice(),
      throwsA(isA<CuratedListRecoveryException>()),
    );
    await restart();
    final retained = jsonDecode(prefs.getString(archiveKey)!) as Map;
    expect(retained['records'], unknown);
    expect(retained['recordBackups'], [jsonEncode(unknown)]);
    expect(retained.toString(), isNot(contains('Alice private sentinel')));
    expect(journal.needsRepair(_bob), isTrue);
  });

  test(
    'explicit deletion rejects late ACKs and a stale shared repair',
    () async {
      final ticket = await journal.ticket(_alice, 'alice-private');
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      final before = journal.repairSnapshot(_bob);
      await deleteAlice();
      expect(
        await journal.accepted(
          owner: _alice,
          listId: 'alice-private',
          visibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
          eventId: _aliceVideo,
          acceptedAt: now,
          plaintextEventIds: [_aliceVideo],
          ticket: ticket,
        ),
        isFalse,
      );
      expect(
        await journal.repairVerifiedShared(
          activeOwner: _bob,
          expectedSnapshot: before,
          reconstructedJournals: {
            _alice: jsonEncode({
              'alice-private': const CuratedListRecoveryRecord(
                plaintextEventIds: [_aliceVideo],
              ).toJson(),
            }),
          },
        ),
        isFalse,
      );
      expect(
        prefs.getKeys().map(prefs.get).join('\n'),
        isNot(contains(_aliceVideo)),
      );
    },
  );

  test(
    'uppercase cache owners and earlier alias keys have one recovery scope',
    () async {
      final upper = _alice.toUpperCase();
      final legacyKey = '${CuratedListRecoveryJournal.storagePrefix}$upper';
      await prefs.setString(
        legacyKey,
        jsonEncode({
          'alias-list': const CuratedListRecoveryRecord(
            plaintextEventIds: [_aliceVideo],
          ).toJson(),
        }),
      );
      await prefs.setInt(
        '${CuratedListRecoveryStorage.generationPrefix}$upper',
        3,
      );
      await prepare([
        row(_bob),
        {...damaged(_alice), 'pubkey': upper},
      ]);
      expect(journal.needsRepair(_alice), isTrue);
      expect(journal.needsRepair(_bob), isFalse);
      expect(journal.record(_alice, 'alias-list')!.plaintextEventIds, [
        _aliceVideo,
      ]);
      await journal.prepare(_alice);
      expect(prefs.containsKey(legacyKey), isFalse);
      expect(journal.record(_alice, 'alias-list')!.plaintextEventIds, [
        _aliceVideo,
      ]);
      await deleteAlice();
      await restart();
      expect(prefs.getInt(CuratedListRecoveryStorage.generationKey(_alice)), 4);
      expect(
        prefs.getKeys().map(prefs.get).join('\n'),
        isNot(contains(_aliceVideo)),
      );
    },
  );

  test(
    'verdict cache observes direct writes, repair and readback/session holds',
    () async {
      expect(journal.needsRepair(_bob), isFalse);
      await prefs.setString('curated_lists', jsonEncode([damaged(_alice)]));
      expect(journal.needsRepair(_alice), isTrue);
      expect(journal.needsRepair(_bob), isFalse);
      await prefs.setString(
        'curated_lists',
        jsonEncode([
          {'opaque': 'unknown'},
        ]),
      );
      expect(journal.needsRepair(_bob), isTrue);
      await prefs.setString('curated_lists', '[]');
      expect(journal.needsRepair(_bob), isFalse);
      final sessions = CuratedListSessionCoordinator.forPreferences(prefs);
      await sessions.holdRecoveryRepair(() async {
        expect(journal.needsRepair(_bob), isTrue);
      });
      expect(journal.needsRepair(_bob), isFalse);
      sessions.markRecoveryReadbackUnknown();
      expect(journal.needsRepair(_bob), isTrue);
      await CuratedListRecoveryStorage.refreshEvidence(prefs);
      expect(journal.needsRepair(_bob), isFalse);
    },
  );

  test(
    'an interrupted alias migration resumes before writes can publish',
    () async {
      final alias =
          '${CuratedListRecoveryJournal.storagePrefix}${_alice.toUpperCase()}';
      await prefs.setString(
        alias,
        jsonEncode({
          'alias-list': const CuratedListRecoveryRecord(
            plaintextEventIds: [_aliceVideo],
          ).toJson(),
        }),
      );
      store.refusedRemoval = alias;
      await expectLater(
        journal.prepare(_alice),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      await restart();
      expect(journal.needsRepair(_alice), isTrue);
      expect(journal.record(_alice, 'alias-list')!.plaintextEventIds, [
        _aliceVideo,
      ]);
      store.refusedRemoval = null;
      await journal.prepare(_alice);
      expect(prefs.containsKey(alias), isFalse);
      expect(journal.record(_alice, 'alias-list')!.plaintextEventIds, [
        _aliceVideo,
      ]);
    },
  );

  test('readback failure retains required deletion and blocks optimistic readiness', () async {
    await prepare([row(_alice), row(_bob), damaged(_alice)]);
    store.failReadback = true;
    await expectLater(
      deleteAlice(),
      throwsA(isA<CuratedListRecoveryException>()),
    );
    expect(journal.needsRepair(_bob), isTrue);
    store.failReadback = false;
    await restart();
    expect(PendingAccountCleanup.read(prefs)!.userPubkey, _alice);
    await deleteAlice();
    expect(
      prefs.getKeys().map(prefs.get).join('\n'),
      isNot(contains(_aliceVideo)),
    );
  });

  test(
    'a lying owner-journal removal cannot report completed deletion',
    () async {
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      await journal.prepare(_alice);
      store.lyingRemoval = CuratedListRecoveryJournal.storageKey(_alice);
      await expectLater(
        deleteAlice(),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      await restart();
      expect(
        prefs.containsKey(CuratedListRecoveryJournal.storageKey(_alice)),
        isTrue,
      );
      expect(PendingAccountCleanup.read(prefs)!.deleteUserData, isTrue);
      store.lyingRemoval = null;
      await deleteAlice();
      expect(
        prefs.getKeys().map(prefs.get).join('\n'),
        isNot(contains(_aliceVideo)),
      );
    },
  );

  test(
    'healthy deletion preserves Bob without introducing a repair hold',
    () async {
      await prefs.setString(
        'curated_lists',
        jsonEncode([row(_alice), row(_bob)]),
      );
      final lease = CuratedListSessionCoordinator.forPreferences(prefs)
          .acquire();
      await deleteAlice();
      expect(lease.isCurrent, isTrue);
      expect(journal.needsRepair(_bob), isFalse);
      expect(
        prefs.getKeys().map(prefs.get).join('\n'),
        isNot(contains(_aliceVideo)),
      );
      expect(prefs.getKeys().map(prefs.get).join('\n'), contains(_bobVideo));
    },
  );

  test(
    'no-session deletion scrubs archives while retaining Bob privacy work',
    () async {
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      await UserDataCleanupService(prefs).deleteAccountData(
        _alice,
        userNpub: 'synthetic-alice-npub',
        preserveActiveSession: false,
      );
      await restart();
      expect(prefs.containsKey('curated_lists'), isFalse);
      expect(
        prefs.getKeys().map(prefs.get).join('\n'),
        isNot(contains(_aliceVideo)),
      );
      expect(journal.record(_bob, 'bob-private')!.plaintextEventIds, [
        _bobVideo,
      ]);
      expect(journal.needsRepair(_bob), isFalse);
    },
  );

  test(
    'valid but conflicting-owner rows are archived before sign-out',
    () async {
      await prepare([
        row(_bob),
        {...row(_alice), 'ownerPubkey': _bob},
      ]);
      expect(journal.needsRepair(_bob), isTrue);
      final before = prefs.getString(archiveKey);
      expect(before, contains('Alice private sentinel'));
      expect(journal.record(_alice, 'alice-private'), isNull);
      await UserDataCleanupService(prefs)
          .clearUserSpecificData(userPubkey: _bob);
      await restart();
      expect(prefs.getString(archiveKey), before);
      expect(journal.needsRepair(_bob), isTrue);
    },
  );

  test(
    'the real service permits Bob writes while Alice remains read-only',
    () async {
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      final aliceAuth = _Auth();
      final bobAuth = _Auth();
      final aliceClient = _Client();
      final bobClient = _Client();
      when(() => aliceAuth.isAuthenticated).thenReturn(true);
      when(() => aliceAuth.currentPublicKeyHex).thenReturn(_alice);
      when(() => bobAuth.isAuthenticated).thenReturn(true);
      when(() => bobAuth.currentPublicKeyHex).thenReturn(_bob);
      stubListPublishing(client: aliceClient, auth: aliceAuth, pubkey: _alice);
      stubListPublishing(client: bobClient, auth: bobAuth, pubkey: _bob);
      final alice = CuratedListService(
        nostrService: aliceClient,
        authService: aliceAuth,
        prefs: prefs,
      );
      final bob = CuratedListService(
        nostrService: bobClient,
        authService: bobAuth,
        prefs: prefs,
      );
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      await alice.prepareRecovery();
      await bob.prepareRecovery();
      expect(alice.recoveryNeedsRepair, isTrue);
      expect(bob.recoveryNeedsRepair, isFalse);
      expect(await alice.createList(name: 'Held owner'), isNull);
      expect(await bob.createList(name: 'Available owner'), isNotNull);
      verifyNever(() => aliceClient.publishEventAwaitOk(any()));
      final events = verify(() => bobClient.publishEventAwaitOk(captureAny()))
          .captured
          .cast<Event>();
      expect(events, isNotEmpty);
      expect(events.every((event) => event.pubkey == _bob), isTrue);
      expect(prefs.getString(archiveKey), contains('Alice private sentinel'));
    },
  );

  for (final guardedKey in [
    PendingAccountCleanup.storageKey,
    CuratedListRecoveryStorage.generationKey(_alice),
  ]) {
    test('a lying $guardedKey write stops before account erasure', () async {
      await prepare([row(_alice), row(_bob), damaged(_alice)]);
      final original = prefs.getString(archiveKey);
      store.lyingKey = guardedKey;
      await expectLater(
        deleteAlice(),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      await restart();
      expect(prefs.getString(archiveKey), original);
      expect(
        prefs.getString('curated_lists'),
        contains('Alice private sentinel'),
      );
    });
  }

  test(
    'crash after alias removal restores the intended healthy hold verdict',
    () async {
      final alias =
          '${CuratedListRecoveryJournal.storagePrefix}${_alice.toUpperCase()}';
      await prefs.setString(
        alias,
        jsonEncode({
          'alias-list': const CuratedListRecoveryRecord(
            plaintextEventIds: [_aliceVideo],
          ).toJson(),
        }),
      );
      store.refusedKey = CuratedListRecoveryStorage.quarantineKey(_alice);
      store.refusedWriteNumber = 3;
      await expectLater(
        journal.prepare(_alice),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      await restart();
      expect(prefs.containsKey(alias), isFalse);
      expect(journal.needsRepair(_alice), isTrue);
      store.refusedKey = null;
      await journal.prepare(_alice);
      expect(journal.needsRepair(_alice), isFalse);
      expect(journal.record(_alice, 'alias-list')!.plaintextEventIds, [
        _aliceVideo,
      ]);
    },
  );

  test(
    'a completed healthy alias migration cannot clear later journal damage',
    () async {
      final alias =
          '${CuratedListRecoveryJournal.storagePrefix}${_alice.toUpperCase()}';
      await prefs.setString(
        alias,
        jsonEncode({
          'alias-list': const CuratedListRecoveryRecord(
            plaintextEventIds: [_aliceVideo],
          ).toJson(),
        }),
      );
      await journal.prepare(_alice);
      expect(journal.needsRepair(_alice), isFalse);
      await prefs.setString(
        CuratedListRecoveryJournal.storageKey(_alice),
        jsonEncode({
          'damaged': {'visibility': true},
        }),
      );
      await journal.prepare(_alice);
      expect(journal.needsRepair(_alice), isTrue);
      expect(await journal.ticket(_alice, 'new'), isNull);
      expect(
        prefs.getString(CuratedListRecoveryStorage.quarantineKey(_alice)),
        contains('damaged'),
      );
    },
  );

  test(
    'unattributed archive coordinates and missing raw provenance stay held',
    () async {
      final archive = {
        'version': 2,
        'rawBuckets': <String>[],
        'recordBackups': <String>[],
        'records': <String, dynamic>{},
        'originalLiveValue': null,
        'normalized': true,
        'needsRepair': true,
        'ownerWide': true,
        'unresolvedCoordinates': <String>[],
      };
      await prefs.setString(archiveKey, jsonEncode(archive));
      expect(journal.needsRepair(_bob), isTrue);
      archive['rawBuckets'] = [
        jsonEncode([row(_bob)]),
      ];
      archive['unresolvedCoordinates'] = ['unknown-coordinate'];
      await prefs.setString(archiveKey, jsonEncode(archive));
      expect(journal.needsRepair(_bob), isTrue);
      await expectLater(
        deleteAlice(),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      expect(prefs.getString(archiveKey), contains('unknown-coordinate'));
    },
  );

  test(
    'uppercase ticket identity accepts only the same canonical owner ACK',
    () async {
      final ticket = await journal.ticket(_alice.toUpperCase(), 'same-owner');
      expect(
        await journal.accepted(
          owner: _alice,
          listId: 'same-owner',
          visibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
          eventId: _aliceVideo,
          acceptedAt: now,
          plaintextEventIds: [_aliceVideo],
          ticket: ticket,
        ),
        isTrue,
      );
      expect(journal.record(_alice, 'same-owner')!.plaintextEventIds, [
        _aliceVideo,
      ]);
      expect(
        prefs.containsKey(
          '${CuratedListRecoveryJournal.storagePrefix}${_alice.toUpperCase()}',
        ),
        isFalse,
      );
      expect(
        await journal.accepted(
          owner: _bob,
          listId: 'same-owner',
          visibility: const CuratedListVisibility(
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: [],
            relayAccepted: true,
          ),
          eventId: _bobVideo,
          acceptedAt: now,
          plaintextEventIds: [_bobVideo],
          ticket: ticket,
        ),
        isFalse,
      );
      expect(journal.record(_bob, 'same-owner'), isNull);
    },
  );
}
