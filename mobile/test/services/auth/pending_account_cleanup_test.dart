// ABOUTME: Account cleanup intent is authoritative only after durable readback.
// ABOUTME: False acknowledgements cannot authorize erasure or completed cleanup.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

const _owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class _Store extends InMemorySharedPreferencesStore {
  _Store() : super.empty();
  bool lieAboutWrite = false;
  bool refuseWrite = false;
  bool throwWrite = false;
  bool lieAboutRemoval = false;
  bool refuseRemoval = false;
  bool throwAfterRemoval = false;
  bool failReadback = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key.endsWith(PendingAccountCleanup.storageKey)) {
      if (lieAboutWrite) return true;
      if (refuseWrite) return false;
      if (throwWrite) throw StateError('synthetic storage failure');
    }
    return super.setValue(type, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    if (key.endsWith(PendingAccountCleanup.storageKey)) {
      if (lieAboutRemoval) return true;
      if (refuseRemoval) return false;
      final removed = await super.remove(key);
      if (throwAfterRemoval) throw StateError('synthetic removal failure');
      return removed;
    }
    return super.remove(key);
  }

  @override
  Future<Map<String, Object>> getAll() async {
    if (failReadback) throw StateError('synthetic readback failure');
    return super.getAll();
  }
}

void main() {
  const intent = PendingAccountCleanup(
    userPubkey: _owner,
    isIdentityChange: false,
    deleteUserData: true,
  );
  late SharedPreferencesStorePlatform previous;
  late _Store store;
  late SharedPreferences prefs;

  setUp(() async {
    previous = SharedPreferencesStorePlatform.instance;
    store = _Store();
    SharedPreferencesStorePlatform.instance = store;
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = previous;
  });

  Future<void> restart() async {
    SharedPreferences.resetStatic();
    prefs = await SharedPreferences.getInstance();
  }

  group('record', () {
    test('record acknowledges only the exact durable intent', () async {
      await intent.record(prefs);
      await restart();
      expect(
        PendingAccountCleanup.read(prefs)?.covers(
          userPubkey: _owner,
          isIdentityChange: false,
          deleteUserData: true,
        ),
        isTrue,
      );
    });

    for (final failure in ['lying', 'refused', 'throwing']) {
      test(
        '$failure intent write cannot be acknowledged or remain only in cache',
        () async {
          store.lieAboutWrite = failure == 'lying';
          store.refuseWrite = failure == 'refused';
          store.throwWrite = failure == 'throwing';
          await expectLater(intent.record(prefs), throwsStateError);
          expect(prefs.containsKey(PendingAccountCleanup.storageKey), isFalse);
          await restart();
          expect(PendingAccountCleanup.read(prefs), isNull);
        },
      );
    }

    test(
      'unavailable record readback cannot authorize destructive work',
      () async {
        await prefs.setString('curated_lists', '[]');
        final cleanup = UserDataCleanupService(prefs);
        var databaseAttempts = 0;
        cleanup.onDatabaseCleanup = ({
          userPubkey,
          deleteUserData = false,
          preserveActiveSession = false,
        }) async => databaseAttempts++;
        store.failReadback = true;
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: _owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(databaseAttempts, 0);
        expect(prefs.getString('curated_lists'), '[]');
        expect(PendingAccountCleanup.readbackUnknown(prefs), isTrue);
        store.failReadback = false;
        await restart();
        expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
      },
    );
  });

  group('complete', () {
    test('complete acknowledges only durable absence', () async {
      await intent.record(prefs);
      await intent.complete(prefs);
      await restart();
      expect(PendingAccountCleanup.read(prefs), isNull);
    });

    for (final failure in ['lying', 'refused', 'throwing']) {
      test(
        '$failure intent removal retains the original retry obligation',
        () async {
          await intent.record(prefs);
          store.lieAboutRemoval = failure == 'lying';
          store.refuseRemoval = failure == 'refused';
          store.throwAfterRemoval = failure == 'throwing';
          await expectLater(intent.complete(prefs), throwsStateError);
          expect(PendingAccountCleanup.read(prefs)?.userPubkey, _owner);
          await restart();
          expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
        },
      );
    }

    test(
      'unavailable completion readback preserves intent for a verified retry',
      () async {
        await intent.record(prefs);
        store.failReadback = true;
        await expectLater(intent.complete(prefs), throwsStateError);
        expect(PendingAccountCleanup.readbackUnknown(prefs), isTrue);
        store.failReadback = false;
        await restart();
        expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
        await intent.complete(prefs);
        await restart();
        expect(PendingAccountCleanup.read(prefs), isNull);
      },
    );
  });

  group('sign-out cleanup intent', () {
    test(
      'lying sign-out intent write stops before any cache or database deletion',
      () async {
        await prefs.setString('curated_lists', '[]');
        await prefs.setString('current_user_pubkey_hex', _owner);
        store.lieAboutWrite = true;
        var databaseAttempts = 0;
        final cleanup = UserDataCleanupService(prefs)
          ..onDatabaseCleanup = ({
            userPubkey,
            deleteUserData = false,
            preserveActiveSession = false,
          }) async => databaseAttempts++;
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: _owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(databaseAttempts, 0);
        await restart();
        expect(prefs.getString('curated_lists'), '[]');
        expect(prefs.getString('current_user_pubkey_hex'), _owner);
      },
    );

    test(
      'lying sign-out intent removal cannot report completed cleanup',
      () async {
        await prefs.setString('curated_lists', '[]');
        store.lieAboutRemoval = true;
        var databaseAttempts = 0;
        final cleanup = UserDataCleanupService(prefs)
          ..onDatabaseCleanup = ({
            userPubkey,
            deleteUserData = false,
            preserveActiveSession = false,
          }) async => databaseAttempts++;
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: _owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(databaseAttempts, 1);
        await restart();
        expect(PendingAccountCleanup.read(prefs)?.deleteUserData, isTrue);
      },
    );

    test(
      'honest destructive intent survives failed database cleanup and restart',
      () async {
        await prefs.setString('curated_lists', '[]');
        final cleanup = UserDataCleanupService(prefs)
          ..onDatabaseCleanup = ({
            userPubkey,
            deleteUserData = false,
            preserveActiveSession = false,
          }) async => throw StateError('synthetic database unavailable');
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: _owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        await restart();
        final pending = PendingAccountCleanup.read(prefs)!;
        expect(pending.userPubkey, _owner);
        expect(pending.deleteUserData, isTrue);
      },
    );
  });
}
