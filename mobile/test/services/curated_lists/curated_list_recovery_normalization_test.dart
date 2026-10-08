// ABOUTME: Durable quarantine restores reads without authorizing unknown writes.
// ABOUTME: Exercises restart, backend refusals and ACK/archive precedence.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import '../../helpers/curated_list_publish_stubs.dart';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  String? rejectedKey;
  int? rejectedWriteNumber;
  String? lyingKey;
  final writes = <String, int>{};

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    final count = writes.update(key, (value) => value + 1, ifAbsent: () => 1);
    if (key.endsWith(rejectedKey ?? '\u0000') &&
        (rejectedWriteNumber == null || count == rejectedWriteNumber)) {
      return false;
    }
    if (key.endsWith(lyingKey ?? '\u0000')) return true;
    return super.setValue(type, key, value);
  }
}

class _Client extends Mock implements NostrClient {}

class _Auth extends Mock implements AuthService {}

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _incoming =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _plaintext =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _accepted =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _sharedArchive = 'curated_list_recovery_shared_quarantine_v1';

void main() {
  late _Store backend;
  late SharedPreferences prefs;
  late CuratedListRecoveryJournal journal;
  late SharedPreferencesStorePlatform previous;
  final now = DateTime.utc(2026, 10, 6);
  final key = CuratedListRecoveryJournal.storageKey(_owner);
  final archiveKey = CuratedListRecoveryStorage.quarantineKey(_owner);
  const good = CuratedListRecoveryRecord(plaintextEventIds: [_plaintext]);
  final broken = jsonEncode({
    'healthy': good.toJson(),
    'bad': {'visibility': true},
  });

  setUpAll(
    () => registerFallbackValue(Event(_owner, 1, <List<String>>[], '')),
  );
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

  Future<void> restart() async {
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
    journal = CuratedListRecoveryJournal(
      prefs: prefs,
      runCurrent: (operation) => operation(),
    );
  }

  CuratedList row({String? owner = _owner}) => CuratedList(
    id: 'healthy',
    name: 'Readable list',
    pubkey: owner,
    videoEventIds: const [],
    createdAt: now,
    updatedAt: now,
    pendingPlaintextEventIds: const [_plaintext],
  );

  group('CuratedListRecoveryNormalization', () {
    test('normalization retains healthy rows and the hold across restart, idempotently', () async {
      await prefs.setString(key, broken);
      await journal.prepare(_owner);
      expect(journal.record(_owner, 'healthy')!.plaintextEventIds, [
        _plaintext,
      ]);
      expect(jsonDecode(prefs.getString(key)!) as Map, isNot(contains('bad')));
      final archive = jsonDecode(prefs.getString(archiveKey)!) as Map;
      expect(archive['rawBuckets'], [broken]);
      expect(archive['normalized'], isTrue);
      expect(archive['needsRepair'], isTrue);
      expect(archive['unresolvedCoordinates'], ['bad']);
      await restart();
      expect(journal.needsRepair(_owner), isTrue);
      expect(await journal.ticket(_owner, 'healthy'), isNull);
      final writes = Map<String, int>.of(backend.writes);
      await journal.prepare(_owner);
      expect(backend.writes, writes);
    });

    test(
      'normalized backups do not resurrect redaction IDs or accepted targets',
      () async {
        await prefs.setString(key, broken);
        await journal.prepare(_owner);
        expect(
          await journal.redactionAccepted(_owner, 'healthy', _plaintext),
          isTrue,
        );
        await restart();
        expect(journal.record(_owner, 'healthy'), isNull);
        expect(journal.needsRepair(_owner), isTrue);
        expect(
          (jsonDecode(prefs.getString(archiveKey)!) as Map)['rawBuckets'],
          [
            broken,
          ],
        );
      },
    );

    test(
      'an ACK after normalization supersedes archived state and survives restart',
      () async {
        final ticket = await journal.ticket(_owner, 'healthy');
        await prefs.setString(key, broken);
        await journal.prepare(_owner);
        expect(
          await journal.accepted(
            owner: _owner,
            listId: 'healthy',
            visibility: const CuratedListVisibility(
              isPublic: false,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
            eventId: _accepted,
            acceptedAt: now,
            plaintextEventIds: const [_plaintext],
            ticket: ticket,
          ),
          isTrue,
        );
        await restart();
        expect(journal.record(_owner, 'healthy')!.acceptedEventId, _accepted);
        expect(
          journal.record(_owner, 'healthy')!.visibility!.isPublic,
          isFalse,
        );
        expect(journal.needsRepair(_owner), isTrue);
      },
    );

    test('failure of the final marker does not make old backups override the live journal', () async {
      await prefs.setString(key, broken);
      backend.rejectedKey = archiveKey;
      backend.rejectedWriteNumber = 2;
      await expectLater(
        journal.prepare(_owner),
        throwsA(isA<CuratedListRecoveryException>()),
      );
      expect(jsonDecode(prefs.getString(key)!) as Map, isNot(contains('bad')));
      backend.rejectedKey = null;
      expect(
        await journal.redactionAccepted(_owner, 'healthy', _plaintext),
        isTrue,
      );
      await restart();
      expect(journal.record(_owner, 'healthy'), isNull);
      expect(journal.needsRepair(_owner), isTrue);
    });

    for (final lying in [false, true]) {
      test(
        '${lying ? 'unacknowledged' : 'refused'} backup blocks cleanup without losing original bytes',
        () async {
          await prefs.setString('curated_lists', 'private unreadable raw');
          if (lying) {
            backend.lyingKey = _sharedArchive;
          } else {
            backend.rejectedKey = _sharedArchive;
          }
          var databaseCalls = 0;
          final cleanup = UserDataCleanupService(prefs)
            ..onDatabaseCleanup =
                ({
                  userPubkey,
                  deleteUserData = false,
                  preserveActiveSession = false,
                }) async {
                  databaseCalls++;
                };
          await expectLater(
            cleanup.clearUserSpecificData(isIdentityChange: true),
            throwsA(isA<UserDataCleanupException>()),
          );
          await restart();
          expect(prefs.getString('curated_lists'), 'private unreadable raw');
          expect(databaseCalls, 0);
          expect(cleanup.shouldClearDataForUser(_incoming), isTrue);
        },
      );
    }

    test('mixed shared rows are archived before account cleanup and never attributed to the incoming owner', () async {
      final raw = jsonEncode([
        row().toJson(),
        {'unreadable': true},
      ]);
      await prefs.setString('curated_lists', raw);
      await prefs.setString('current_user_pubkey_hex', _owner);
      var databaseCalls = 0;
      final cleanup = UserDataCleanupService(prefs)
        ..onDatabaseCleanup =
            ({
              userPubkey,
              deleteUserData = false,
              preserveActiveSession = false,
            }) async {
              expect(userPubkey, _owner);
              databaseCalls++;
            };
      await cleanup.clearUserSpecificData(
        isIdentityChange: true,
        userPubkey: _owner,
      );
      await restart();
      expect(databaseCalls, 1);
      expect(prefs.containsKey('curated_lists'), isFalse);
      expect(
        (jsonDecode(prefs.getString(_sharedArchive)!) as Map)['rawBuckets'],
        [raw],
      );
      expect(journal.record(_owner, 'healthy')!.plaintextEventIds, [
        _plaintext,
      ]);
      expect(journal.record(_incoming, 'healthy'), isNull);
      expect(journal.needsRepair(_incoming), isTrue);
    });

    test('an ownerless pending row is retained at device scope without owner guessing', () async {
      final raw = jsonEncode([row(owner: null).toJson()]);
      await prefs.setString('curated_lists', raw);
      await CuratedListRecoveryJournal.migrateEmbeddedRecords(prefs);
      expect(journal.records(_owner), isEmpty);
      expect(journal.records(_incoming), isEmpty);
      expect(prefs.getString('curated_lists'), '[]');
      expect(
        (jsonDecode(prefs.getString(_sharedArchive)!) as Map)['rawBuckets'],
        [raw],
      );
      expect(journal.needsRepair(_incoming), isTrue);
    });

    test(
      'an incomplete shared normalization marker resumes after restart',
      () async {
        const original = 'private shared bytes';
        await prefs.setString('curated_lists', original);
        backend.rejectedKey = _sharedArchive;
        backend.rejectedWriteNumber = 2;
        await expectLater(
          journal.prepare(_owner),
          throwsA(isA<CuratedListRecoveryException>()),
        );
        await restart();
        expect(prefs.getString('curated_lists'), '[]');
        expect(
          (jsonDecode(prefs.getString(_sharedArchive)!) as Map)['normalized'],
          isFalse,
        );
        backend.rejectedKey = null;
        await journal.prepare(_owner);
        final archive = jsonDecode(prefs.getString(_sharedArchive)!) as Map;
        expect(archive['normalized'], isTrue);
        expect(archive['rawBuckets'], [original]);
        expect(CuratedListRecoveryStorage.canRepairShared(prefs), isTrue);
        expect(await journal.ticket(_owner, 'new-attempt'), isNull);
      },
    );

    test('successful preservation restores read-only initialization and never publishes or creates defaults', () async {
      await prefs.setString('curated_lists', jsonEncode([row().toJson()]));
      await prefs.setString(key, broken);
      final client = _Client();
      final auth = _Auth();
      stubListSigner(client, _owner);
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_owner);
      final service = CuratedListService(
        nostrService: client,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      await service.initialize();
      expect(service.initializationError, isNull);
      expect(service.isInitialized, isTrue);
      expect(service.lists.map((row) => row.id), ['healthy']);
      expect(service.recoveryNeedsRepair, isTrue);
      expect(service.isReadyForMutations, isFalse);
      expect(await service.createList(name: 'Blocked'), isNull);
      expect(service.hasDefaultList(), isFalse);
      verifyNever(() => client.publishEventAwaitOk(any()));
      verifyNever(() => client.publishEvent(any()));
    });
  });
}
