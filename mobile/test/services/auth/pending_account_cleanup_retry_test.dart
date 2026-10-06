// ABOUTME: Backend-backed regressions for interrupted required account cleanup.
// ABOUTME: Retains retry intent after cache removal, backend refusal and restart.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/auth/pending_account_cleanup.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _CleanupBackend extends InMemorySharedPreferencesStore {
  _CleanupBackend(super.data) : super.withData();

  String? refusedWrite;
  String? refusedRemoval;
  final removedKeys = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == refusedWrite) {
      return false;
    }
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    if (key == refusedRemoval) {
      return false;
    }
    return super.remove(key);
  }
}

void main() {
  const marker = 'flutter.${PendingAccountCleanup.storageKey}';
  const owner =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const incoming =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  late SharedPreferencesStorePlatform originalStore;
  late _CleanupBackend backend;
  late SharedPreferences preferences;
  late UserDataCleanupService cleanup;

  setUp(() async {
    originalStore = SharedPreferencesStorePlatform.instance;
    backend = _CleanupBackend({'flutter.curated_lists': 'orphaned cache'});
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = backend;
    preferences = await SharedPreferences.getInstance();
    cleanup = UserDataCleanupService(preferences);
  });

  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalStore;
  });

  group('clearUserSpecificData pending cleanup retries', () {
    test(
      'failed orphan database sweep remains mandatory after restart',
      () async {
        var databaseAttempts = 0;
        Future<void> sweep({
          String? userPubkey,
          bool deleteUserData = false,
          bool preserveActiveSession = false,
        }) async {
          databaseAttempts++;
          if (databaseAttempts < 3) {
            throw StateError('database unavailable');
          }
        }

        cleanup.onDatabaseCleanup = sweep;
        expect(preferences.containsKey('current_user_pubkey_hex'), isFalse);
        await expectLater(
          cleanup.clearUserSpecificData(isIdentityChange: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(preferences.containsKey('curated_lists'), isFalse);
        expect(cleanup.shouldClearDataForUser(incoming), isTrue);
        expect((await backend.getAll()).containsKey(marker), isTrue);

        // Re-create the preferences cache from acknowledged backend data, rather
        // than carrying the old service's in-memory failure state into the retry.
        SharedPreferences.resetStatic();
        preferences = await SharedPreferences.getInstance();
        cleanup = UserDataCleanupService(preferences)
          ..onDatabaseCleanup = sweep;
        expect(cleanup.shouldClearDataForUser(incoming), isTrue);
        await expectLater(
          cleanup.clearUserSpecificData(isIdentityChange: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(databaseAttempts, 2);
        expect(cleanup.shouldClearDataForUser(incoming), isTrue);

        await cleanup.clearUserSpecificData(isIdentityChange: true);
        expect(databaseAttempts, 3);
        expect((await backend.getAll()).containsKey(marker), isFalse);
        expect(cleanup.shouldClearDataForUser(incoming), isFalse);
      },
    );

    test('same-owner login cannot bypass an unfinished sweep', () async {
      await preferences.setString('current_user_pubkey_hex', owner);
      cleanup.onDatabaseCleanup = ({
        userPubkey,
        deleteUserData = false,
        preserveActiveSession = false,
      }) async => throw StateError('database unavailable');

      await expectLater(
        cleanup.clearUserSpecificData(
          isIdentityChange: true,
          userPubkey: owner,
        ),
        throwsA(isA<UserDataCleanupException>()),
      );
      expect(cleanup.shouldClearDataForUser(owner), isTrue);
    });

    test(
      'refused intent write stops before cache or database cleanup',
      () async {
        backend.refusedWrite = marker;
        var databaseAttempts = 0;
        cleanup.onDatabaseCleanup = ({
          userPubkey,
          deleteUserData = false,
          preserveActiveSession = false,
        }) async => databaseAttempts++;

        await expectLater(
          cleanup.clearUserSpecificData(isIdentityChange: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(backend.removedKeys, isEmpty);
        expect(
          (await backend.getAll())['flutter.curated_lists'],
          'orphaned cache',
        );
        expect(databaseAttempts, 0);
      },
    );

    test(
      'refused intent removal remains discoverable in memory and disk',
      () async {
        backend.refusedRemoval = marker;
        var databaseAttempts = 0;
        cleanup.onDatabaseCleanup = ({
          userPubkey,
          deleteUserData = false,
          preserveActiveSession = false,
        }) async => databaseAttempts++;

        await expectLater(
          cleanup.clearUserSpecificData(isIdentityChange: true),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(cleanup.shouldClearDataForUser(incoming), isTrue);
        expect((await backend.getAll()).containsKey(marker), isTrue);
        backend.refusedRemoval = null;
        await cleanup.clearUserSpecificData(isIdentityChange: true);
        expect(databaseAttempts, 2);
        expect((await backend.getAll()).containsKey(marker), isFalse);
      },
    );

    test(
      'retry preserves failed deletion scope before the next owner',
      () async {
        final attempts = <(String?, bool)>[];
        cleanup.onDatabaseCleanup =
            ({
              userPubkey,
              deleteUserData = false,
              preserveActiveSession = false,
            }) async {
              attempts.add((userPubkey, deleteUserData));
              if (attempts.length == 1) {
                throw StateError('database unavailable');
              }
            };
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );

        await cleanup.clearUserSpecificData(
          userPubkey: incoming,
          isIdentityChange: true,
        );
        expect(attempts, [(owner, true), (owner, true), (incoming, false)]);
        expect((await backend.getAll()).containsKey(marker), isFalse);
      },
    );

    test(
      'refused owner-scoped removal retains required retry intent',
      () async {
        final soundsKey = SavedSoundsService.accountStorageKey(owner);
        await preferences.setString(soundsKey, 'saved sound');
        backend.refusedRemoval = 'flutter.$soundsKey';
        var databaseAttempts = 0;
        cleanup.onDatabaseCleanup = ({
          userPubkey,
          deleteUserData = false,
          preserveActiveSession = false,
        }) async => databaseAttempts++;
        await expectLater(
          cleanup.clearUserSpecificData(
            userPubkey: owner,
            deleteUserData: true,
          ),
          throwsA(isA<UserDataCleanupException>()),
        );
        expect(databaseAttempts, 0);
        expect((await backend.getAll())['flutter.$soundsKey'], 'saved sound');
        expect((await backend.getAll()).containsKey(marker), isTrue);

        SharedPreferences.resetStatic();
        preferences = await SharedPreferences.getInstance();
        cleanup = UserDataCleanupService(preferences);
        expect(cleanup.shouldClearDataForUser(incoming), isTrue);
      },
    );

    for (final invalid in <Object>['not JSON', '{}', true]) {
      test(
        'unreadable intent is retained without sweeping data: $invalid',
        () async {
          if (invalid is bool) {
            await preferences.setBool(
              PendingAccountCleanup.storageKey,
              invalid,
            );
          } else {
            await preferences.setString(
              PendingAccountCleanup.storageKey,
              invalid as String,
            );
          }
          await expectLater(
            cleanup.clearUserSpecificData(isIdentityChange: true),
            throwsA(isA<UserDataCleanupException>()),
          );
          expect(backend.removedKeys, isEmpty);
          expect(
            (await backend.getAll())['flutter.curated_lists'],
            'orphaned cache',
          );
          expect((await backend.getAll())[marker], invalid);
        },
      );
    }
  });
}
