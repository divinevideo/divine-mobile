import 'package:db_client/db_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/database_encryption_bootstrap.dart';
import 'package:openvine/services/database_recovery_store.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('generateCipherKeyHex', () {
    test('returns 64 lower-case hex characters (a raw 32-byte key)', () {
      final key = generateCipherKeyHex();
      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('returns a different key each call (CSPRNG)', () {
      expect(generateCipherKeyHex(), isNot(equals(generateCipherKeyHex())));
    });
  });

  group('DatabaseEncryptionBootstrap.resolveCipherKey', () {
    late _MockSecureStorage storage;
    late Map<String, String> store;
    // There is one slot. The second instance differs only in the iOS
    // accessibility it names, and exists because `delete` is the one operation
    // that filters on the class. It gets its own backing map so a test can tell
    // which instance issued a delete.
    late _MockSecureStorage legacyStorage;
    late Map<String, String> legacyStore;

    void backBy(_MockSecureStorage mock, Map<String, String> map) {
      when(
        () => mock.read(key: any(named: 'key')),
      ).thenAnswer((inv) async => map[inv.namedArguments[#key]]);
      when(
        () => mock.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        map[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });
      when(() => mock.delete(key: any(named: 'key'))).thenAnswer((inv) async {
        map.remove(inv.namedArguments[#key] as String);
      });
    }

    setUp(() {
      storage = _MockSecureStorage();
      store = <String, String>{};
      backBy(storage, store);
      legacyStorage = _MockSecureStorage();
      legacyStore = <String, String>{};
      backBy(legacyStorage, legacyStore);
    });

    DatabaseEncryptionBootstrap buildBootstrap({
      required CipherMigrationOutcome outcome,
      required void Function() onDelete,
      Future<bool?> Function()? isProtectedDataAvailable,
      bool cipherAvailable = true,
      void Function()? onReset,
      bool Function(String rawKeyHex)? canOpenEncryptedDatabase,
      bool Function(String rawKeyHex)? salvageDatabase,
      bool Function(String rawKeyHex)? encryptedKeyMatches,
      void Function(Object error)? onRecordRecovery,
      void Function(DatabaseRecoveryOutcome outcome)? onPersistRecovery,
      bool hasPendingCorruptionRecovery = false,
      void Function()? onClearPendingCorruptionRecovery,
    }) {
      return DatabaseEncryptionBootstrap(
        secureStorage: storage,
        isProtectedDataAvailable: isProtectedDataAvailable,
        hasPendingCorruptionRecovery: () async => hasPendingCorruptionRecovery,
        clearPendingCorruptionRecovery: onClearPendingCorruptionRecovery == null
            ? null
            : () async => onClearPendingCorruptionRecovery(),
        ensureRuntime: () async {},
        isCipherAvailable: () => cipherAvailable,
        migrate: (_) async => outcome,
        deleteDatabase: () async => onDelete(),
        onDatabaseReset: onReset == null ? null : () async => onReset(),
        canOpenEncryptedDatabase: canOpenEncryptedDatabase == null
            ? null
            : (rawKeyHex) async => canOpenEncryptedDatabase(rawKeyHex),
        // Default to "nothing to salvage" so the corruption branch falls
        // through to the wipe unless a test opts in.
        salvageDatabase: (rawKeyHex) async =>
            salvageDatabase?.call(rawKeyHex) ?? false,
        // Default to "key no longer decrypts" (genuine key loss) so the wipe
        // rotates the key unless a test opts into the still-valid-key case.
        encryptedKeyMatches: (rawKeyHex) async =>
            encryptedKeyMatches?.call(rawKeyHex) ?? false,
        recordRecovery: onRecordRecovery == null
            ? null
            : (error, _) async => onRecordRecovery(error),
        persistRecoveryOutcome: onPersistRecovery == null
            ? null
            : (outcome) async => onPersistRecovery(outcome),
      );
    }

    test('throws StateError when SQLite3MultipleCiphers is not active', () {
      final bootstrap = buildBootstrap(
        cipherAvailable: false,
        outcome: CipherMigrationOutcome.noDatabase,
        onDelete: () {},
      );

      expect(
        bootstrap.resolveCipherKey(),
        throwsA(isA<DatabaseCipherUnavailableError>()),
      );
    });

    test(
      'surfaces an unreachable keystore as '
      'DatabaseCipherStorageUnavailableException without rotating the key',
      () async {
        // What flutter_secure_storage raises when the Keychain refuses a read
        // because the device is still locked: a status code, no prose.
        final platformFailure = PlatformException(
          code: 'Unexpected security result code',
          message: 'Code: -25308, Message: User interaction is not allowed.',
        );
        when(
          () => storage.read(key: any(named: 'key')),
        ).thenThrow(platformFailure);
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.noDatabase,
          onDelete: () {},
        );

        await expectLater(
          bootstrap.resolveCipherKey(),
          throwsA(
            isA<DatabaseCipherStorageUnavailableException>().having(
              (e) => e.cause,
              'cause',
              same(platformFailure),
            ),
          ),
        );
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
        expect(
          store,
          isEmpty,
          reason:
              'a failed read must not be read as "no key stored" — that '
              'would overwrite the only key that opens the existing database',
        );
      },
    );

    test(
      'surfaces an unwritable keystore as '
      'DatabaseCipherStorageUnavailableException',
      () async {
        // Same locked-keystore shape as the read above, on the other half of
        // the contract: a launch that has to persist a key cannot either.
        final platformFailure = PlatformException(
          code: 'Unexpected security result code',
          message: 'Code: -25308, Message: User interaction is not allowed.',
        );
        when(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(platformFailure);
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.noDatabase,
          onDelete: () {},
        );

        await expectLater(
          bootstrap.resolveCipherKey(),
          throwsA(
            isA<DatabaseCipherStorageUnavailableException>().having(
              (e) => e.cause,
              'cause',
              same(platformFailure),
            ),
          ),
        );
        expect(store, isEmpty);
        expect(legacyStore, isEmpty);
      },
    );

    group('empty keystore while protected data is unavailable', () {
      // What a launch before the first unlock — or, for a key still stored
      // under `unlocked`, any launch while the device is locked — looks like:
      // flutter_secure_storage's iOS read drops the -25308 status and reports
      // the item as absent, so both slots read back null with no throw.
      test(
        'fails closed as DatabaseCipherStorageUnavailableException without '
        'generating a key',
        () async {
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.noDatabase,
            onDelete: () {},
            isProtectedDataAvailable: () async => false,
          );

          await expectLater(
            bootstrap.resolveCipherKey(),
            throwsA(
              isA<DatabaseCipherStorageUnavailableException>().having(
                (e) => e.cause,
                'cause',
                isA<ProtectedDataUnavailableException>(),
              ),
            ),
          );
          verifyNever(
            () => storage.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          );
          expect(
            store,
            isEmpty,
            reason:
                'an absent key is not evidence of a fresh install while the '
                'Keychain could not have shown an existing one; a generated '
                'replacement would strand the database the real key opens',
          );
        },
      );

      test('is not repairable by clearing the local database cache', () {
        expect(
          shouldRepairLocalDatabaseCacheAfterBootstrapError(
            DatabaseCipherStorageUnavailableException(
              const ProtectedDataUnavailableException(),
            ),
          ),
          isFalse,
        );
      });

      test(
        'never fails a launch that read a key, however the probe answers',
        () async {
          const existing =
              '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
          store[dbCipherKeyStorageKey] = existing;
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.alreadyEncrypted,
            onDelete: () {},
            isProtectedDataAvailable: () async => false,
          );

          // The probe gates the accessibility rewrite, never the key that was
          // read: a key stored under first_unlock is readable while locked,
          // and a locked launch after first unlock must open the database —
          // that is the point of #9343.
          expect(await bootstrap.resolveCipherKey(), equals(existing));
        },
      );

      group('default probe', () {
        tearDown(() => debugDefaultTargetPlatformOverride = null);

        test('asks the storage on iOS', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          when(
            () => storage.isCupertinoProtectedDataAvailable(),
          ).thenAnswer((_) async => false);
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.noDatabase,
            onDelete: () {},
          );

          await expectLater(
            bootstrap.resolveCipherKey(),
            throwsA(isA<DatabaseCipherStorageUnavailableException>()),
          );
          expect(store, isEmpty);
        });

        test('leaves macOS trusting an empty read, as before', () async {
          // macOS answers the probe too (12+), but its key stays on the
          // `unlocked` class and a wrong `false` there would fail every fresh
          // install closed for good.
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          when(
            () => storage.isCupertinoProtectedDataAvailable(),
          ).thenAnswer((_) async => false);
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.noDatabase,
            onDelete: () {},
          );

          final key = await bootstrap.resolveCipherKey();

          expect(store[dbCipherKeyStorageKey], equals(key));
          verifyNever(() => storage.isCupertinoProtectedDataAvailable());
        });
      });

      test(
        'generates a key when the platform has no protected-data notion',
        () async {
          // Android and web report null: their backends never refuse a read
          // for lock state, so an empty keystore is a fresh install.
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.noDatabase,
            onDelete: () {},
            isProtectedDataAvailable: () async => null,
          );

          final key = await bootstrap.resolveCipherKey();

          expect(store[dbCipherKeyStorageKey], equals(key));
        },
      );
    });

    group('cipher-key slot', () {
      test('is the name every shipped build reads and writes', () {
        // A wire format, not an implementation detail. Moving the key to a
        // second slot leaves an older build — an App Store or TestFlight
        // rollback, a downgraded macOS build, a sideloaded older APK, a
        // Shorebird patch rolled back to its release baseline — reading an
        // empty slot, generating a replacement and wiping the database it
        // could still have opened. See #9385.
        expect(dbCipherKeyStorageKey, equals('db.cipher.key.v1'));
      });
    });

    group('Keychain accessibility upgrade (#9343 class, in place)', () {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

      test('rewrites an existing key into its own slot so the stored item '
          'picks up the current accessibility', () async {
        store[dbCipherKeyStorageKey] = existing;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          isProtectedDataAvailable: () async => true,
        );

        expect(await bootstrap.resolveCipherKey(), equals(existing));
        // Same slot, same value: the plugin's iOS write is what changes the
        // class, and it only does so for the item already at this key.
        verify(
          () => storage.write(key: dbCipherKeyStorageKey, value: existing),
        ).called(1);
        expect(store[dbCipherKeyStorageKey], equals(existing));
        // Nothing is ever deleted: that is what keeps a rollback readable.
        verifyNever(() => storage.delete(key: any(named: 'key')));
        verifyNever(() => legacyStorage.read(key: any(named: 'key')));
        verifyNever(() => legacyStorage.delete(key: any(named: 'key')));
      });

      test('does not report an existing key as generated', () async {
        store[dbCipherKeyStorageKey] = existing;
        var deleted = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () => deleted = true,
          isProtectedDataAvailable: () async => true,
        );

        expect(await bootstrap.resolveCipherKey(), equals(existing));
        expect(
          deleted,
          isFalse,
          reason: 'a rewritten key is the existing key, not a generated one',
        );
      });

      test('skips the rewrite while protected data is unavailable', () async {
        store[dbCipherKeyStorageKey] = existing;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          isProtectedDataAvailable: () async => false,
        );

        expect(await bootstrap.resolveCipherKey(), equals(existing));
        // Deleting the old item would fail with -25308 and the re-add would
        // collide with the copy that survived. The next unlocked launch does
        // it instead.
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });

      test('skips the rewrite where the platform has no protected-data '
          'notion', () async {
        store[dbCipherKeyStorageKey] = existing;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          isProtectedDataAvailable: () async => null,
        );

        expect(await bootstrap.resolveCipherKey(), equals(existing));
        // Android, web and macOS never changed class, so there is nothing to
        // rewrite and no reason to touch the keystore.
        verifyNever(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        );
      });

      test('a failed rewrite does not fail the launch', () async {
        store[dbCipherKeyStorageKey] = existing;
        when(
          () => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenThrow(
          PlatformException(
            code: 'Unexpected security result code',
            message: 'Code: -25308, Message: User interaction is not allowed.',
          ),
        );
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          isProtectedDataAvailable: () async => true,
        );

        expect(
          await bootstrap.resolveCipherKey(),
          equals(existing),
          reason:
              'the caller already holds a key that opens the database; a '
              'failed rewrite only defers the locked-launch fix',
        );
      });

      test(
        'regenerates when the stored value is malformed without consulting '
        'the probe',
        () async {
          // A value came back, so the keystore did answer; the probe is only
          // for the case where it may have hidden an existing item.
          store[dbCipherKeyStorageKey] = 'not-a-valid-key';
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.noDatabase,
            onDelete: () {},
            isProtectedDataAvailable: () async => false,
          );

          final key = await bootstrap.resolveCipherKey();

          expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
          expect(store[dbCipherKeyStorageKey], equals(key));
        },
      );
    });

    test(
      'generates and persists a key on fresh install (noDatabase)',
      () async {
        var deleted = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.noDatabase,
          onDelete: () => deleted = true,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(store[dbCipherKeyStorageKey], equals(key));
        expect(deleted, isFalse);
      },
    );

    test('returns the key after a successful migration', () async {
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.migrated,
        onDelete: () {},
      );

      expect(await bootstrap.resolveCipherKey(), isNotNull);
    });

    test('reuses an existing key without wiping (alreadyEncrypted)', () async {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
      store[dbCipherKeyStorageKey] = existing;
      var deleted = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.alreadyEncrypted,
        onDelete: () => deleted = true,
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, equals(existing));
      expect(deleted, isFalse, reason: 'key intact => not key-loss');
    });

    group('pending runtime-corruption recovery', () {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

      test(
        'salvages without consulting the probe when a previous session '
        'reported corruption',
        () async {
          store[dbCipherKeyStorageKey] = existing;
          var probed = false;
          var salvaged = false;
          final bootstrap = buildBootstrap(
            outcome: CipherMigrationOutcome.alreadyEncrypted,
            onDelete: () {},
            hasPendingCorruptionRecovery: true,
            // The probe is reactive and already missed this corruption once;
            // trusting it again would strand the user on the broken database.
            canOpenEncryptedDatabase: (_) {
              probed = true;
              return true;
            },
            salvageDatabase: (_) {
              salvaged = true;
              return true;
            },
          );

          final key = await bootstrap.resolveCipherKey();

          expect(probed, isFalse, reason: 'the flag must bypass the probe');
          expect(salvaged, isTrue);
          expect(key, equals(existing), reason: 'salvage keeps the same key');
        },
      );

      test('still trusts the probe when no corruption was reported', () async {
        store[dbCipherKeyStorageKey] = existing;
        var salvaged = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          canOpenEncryptedDatabase: (_) => true,
          salvageDatabase: (_) {
            salvaged = true;
            return true;
          },
        );

        expect(await bootstrap.resolveCipherKey(), equals(existing));
        expect(salvaged, isFalse, reason: 'a healthy DB must not be salvaged');
      });

      test('clears the flag once the launch has settled it', () async {
        store[dbCipherKeyStorageKey] = existing;
        var cleared = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          hasPendingCorruptionRecovery: true,
          canOpenEncryptedDatabase: (_) => true,
          salvageDatabase: (_) => true,
          onClearPendingCorruptionRecovery: () => cleared = true,
        );

        await bootstrap.resolveCipherKey();

        expect(cleared, isTrue);
      });

      test('clears the flag after a failed salvage falls through to the '
          'backup-and-recreate', () async {
        store[dbCipherKeyStorageKey] = existing;
        var cleared = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          hasPendingCorruptionRecovery: true,
          canOpenEncryptedDatabase: (_) => true,
          // Salvage fails, key still decrypts => recreate under the same key.
          salvageDatabase: (_) => false,
          encryptedKeyMatches: (_) => true,
          onClearPendingCorruptionRecovery: () => cleared = true,
        );

        await bootstrap.resolveCipherKey();

        expect(
          cleared,
          isTrue,
          reason: 'a stuck flag would salvage on every launch forever',
        );
      });

      test('keeps the flag when resolution throws, so the retry still '
          'recovers', () async {
        store[dbCipherKeyStorageKey] = existing;
        var cleared = false;
        final bootstrap = buildBootstrap(
          cipherAvailable: false,
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          hasPendingCorruptionRecovery: true,
          onClearPendingCorruptionRecovery: () => cleared = true,
        );

        await expectLater(
          bootstrap.resolveCipherKey(),
          throwsA(isA<DatabaseCipherUnavailableError>()),
        );
        expect(cleared, isFalse);
      });

      test(
        'keeps the flag when the migration defers to the next launch',
        () async {
          store[dbCipherKeyStorageKey] = existing;
          var cleared = false;
          final bootstrap = buildBootstrap(
            // The migration could not complete, so it left the database exactly
            // as it was and this launch settled nothing.
            outcome: CipherMigrationOutcome.failed,
            onDelete: () {},
            hasPendingCorruptionRecovery: true,
            onClearPendingCorruptionRecovery: () => cleared = true,
          );

          expect(await bootstrap.resolveCipherKey(), isNull);
          expect(
            cleared,
            isFalse,
            reason:
                'clearing here would drop the only signal forcing the '
                'salvage once the retry classifies the file as encrypted',
          );
        },
      );

      test('keeps the flag when the database is unreadable', () async {
        store[dbCipherKeyStorageKey] = existing;
        var cleared = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.unreadable,
          onDelete: () {},
          hasPendingCorruptionRecovery: true,
          onClearPendingCorruptionRecovery: () => cleared = true,
        );

        await expectLater(
          bootstrap.resolveCipherKey(),
          throwsA(isA<DatabaseUnreadableError>()),
        );
        expect(
          cleared,
          isFalse,
          reason: 'startup failed on the database, so it recovered nothing',
        );
      });
    });

    test('backs up the unrecoverable DB on key loss (generated key + '
        'alreadyEncrypted)', () async {
      // Empty store => key is freshly generated, but an encrypted DB already
      // exists: the keystore was reset. The DB is unrecoverable and must be
      // backed up + recreated under the new key (#570 §6).
      var deleted = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.alreadyEncrypted,
        onDelete: () => deleted = true,
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(deleted, isTrue);
    });

    test(
      'backs up DB and rotates key when stored key no longer opens it',
      () async {
        const staleKey =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = staleKey;
        var deleted = false;
        var reset = false;

        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () => deleted = true,
          onReset: () => reset = true,
          canOpenEncryptedDatabase: (rawKeyHex) => rawKeyHex != staleKey,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
        expect(key, isNot(equals(staleKey)));
        expect(store[dbCipherKeyStorageKey], equals(key));
        expect(deleted, isTrue);
        expect(reset, isTrue);
      },
    );

    test('persists each completed automatic recovery outcome', () async {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

      Future<DatabaseRecoveryOutcome> run({
        required bool keyExists,
        required bool salvageSucceeds,
        required bool keyMatches,
      }) async {
        store.clear();
        if (keyExists) store[dbCipherKeyStorageKey] = existing;
        final outcomes = <DatabaseRecoveryOutcome>[];
        await buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          canOpenEncryptedDatabase: (_) => false,
          salvageDatabase: (_) => salvageSucceeds,
          encryptedKeyMatches: (_) => keyMatches,
          onPersistRecovery: outcomes.add,
        ).resolveCipherKey();
        return outcomes.single;
      }

      expect(
        await run(
          keyExists: false,
          salvageSucceeds: false,
          keyMatches: false,
        ),
        DatabaseRecoveryOutcome.recreatedMissingKey,
      );
      expect(
        await run(
          keyExists: true,
          salvageSucceeds: true,
          keyMatches: true,
        ),
        DatabaseRecoveryOutcome.salvaged,
      );
      expect(
        await run(
          keyExists: true,
          salvageSucceeds: false,
          keyMatches: true,
        ),
        DatabaseRecoveryOutcome.recreatedCorrupt,
      );
      expect(
        await run(
          keyExists: true,
          salvageSucceeds: false,
          keyMatches: false,
        ),
        DatabaseRecoveryOutcome.recreatedKeyLoss,
      );
    });

    test(
      'a failed recovery breadcrumb never fails successful salvage',
      () async {
        const existing =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = existing;
        final bootstrap = DatabaseEncryptionBootstrap(
          secureStorage: storage,
          ensureRuntime: () async {},
          isCipherAvailable: () => true,
          migrate: (_) async => CipherMigrationOutcome.alreadyEncrypted,
          canOpenEncryptedDatabase: (_) async => false,
          salvageDatabase: (_) async => true,
          persistRecoveryOutcome: (_) async => throw StateError('disk full'),
        );

        expect(await bootstrap.resolveCipherKey(), existing);
      },
    );

    test(
      'salvages local data and keeps the key when a corrupt DB is repaired',
      () async {
        // The key still decrypts the DB (so it is NOT key loss) but the DB
        // failed the integrity check. Salvage rebuilds it in place under the
        // same key, so the key is kept — no rotation, no wipe — and the DM
        // sync state is cleared so DMs re-drain into the fresh DB.
        const existing =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = existing;
        var deleted = false;
        var reset = false;

        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () => deleted = true,
          onReset: () => reset = true,
          canOpenEncryptedDatabase: (_) => false,
          salvageDatabase: (_) => true,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, equals(existing), reason: 'key kept, not rotated');
        expect(store[dbCipherKeyStorageKey], equals(existing));
        expect(deleted, isFalse, reason: 'no key-rotation wipe on salvage');
        expect(reset, isTrue, reason: 'DMs re-drain into the salvaged DB');
      },
    );

    test(
      'records a recovery event to Crashlytics on salvage (#116)',
      () async {
        // Recovery succeeds silently, so it never reaches the startup error
        // reporter; the bootstrap must record it as a non-fatal so the
        // corruption rate is observable.
        const existing =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = existing;
        Object? recorded;

        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          canOpenEncryptedDatabase: (_) => false,
          salvageDatabase: (_) => true,
          onRecordRecovery: (error) => recorded = error,
        );

        await bootstrap.resolveCipherKey();

        expect(recorded, isA<DatabaseRecoveryEvent>());
      },
    );

    test(
      'wipes and rotates the key when the key can no longer decrypt the DB',
      () async {
        // Salvage returns false AND the key no longer decrypts the file
        // (genuine key loss), so recovery must rotate the key + wipe.
        const staleKey =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = staleKey;
        var deleted = false;

        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () => deleted = true,
          canOpenEncryptedDatabase: (_) => false,
          salvageDatabase: (_) => false,
          encryptedKeyMatches: (_) => false,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, isNot(equals(staleKey)));
        expect(deleted, isTrue);
      },
    );

    test(
      'wipes but keeps the key when salvage fails yet the key still decrypts',
      () async {
        // The key decrypts the schema (so it is NOT key loss) but the DB is
        // corrupt and could not be salvaged. Rotating would make the backup —
        // encrypted with this key — unreadable, so the key must be kept and the
        // DB recreated under it.
        const validKey =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        store[dbCipherKeyStorageKey] = validKey;
        var deleted = false;

        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () => deleted = true,
          canOpenEncryptedDatabase: (_) => false,
          salvageDatabase: (_) => false,
          encryptedKeyMatches: (_) => true,
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, equals(validKey), reason: 'key kept so the backup is read');
        expect(store[dbCipherKeyStorageKey], equals(validKey));
        expect(deleted, isTrue, reason: 'the corrupt DB is still backed up');
      },
    );

    test(
      'clears DM sync state on key loss so the inbox re-drains (#5304)',
      () async {
        // Key-loss recreate wipes the Drift DB but leaves SharedPreferences; the
        // bootstrap must signal a reset so the DM sync cursors / drain-complete
        // flag are cleared, otherwise recovered chats stay stranded under
        // "Message requests".
        var reset = false;
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          onReset: () => reset = true,
        );

        await bootstrap.resolveCipherKey();

        expect(reset, isTrue);
      },
    );

    test(
      'a failing onDatabaseReset does not abort cipher-key resolution (#5304)',
      () async {
        // A SharedPreferences IO failure while clearing DM sync state must not
        // escalate into a hard cipher-key-resolution failure now that the DB
        // has already been recreated — it only re-strands requests, which the
        // drain-version bump heals.
        final bootstrap = buildBootstrap(
          outcome: CipherMigrationOutcome.alreadyEncrypted,
          onDelete: () {},
          onReset: () => throw StateError('prefs IO failure'),
        );

        final key = await bootstrap.resolveCipherKey();

        expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      },
    );

    test('does not clear DM sync state when the key is intact', () async {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
      store[dbCipherKeyStorageKey] = existing;
      var reset = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.alreadyEncrypted,
        onDelete: () {},
        onReset: () => reset = true,
      );

      await bootstrap.resolveCipherKey();

      expect(reset, isFalse, reason: 'key intact => not a reset');
    });

    test('does not clear DM sync state on a normal migration', () async {
      var reset = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.migrated,
        onDelete: () {},
        onReset: () => reset = true,
      );

      await bootstrap.resolveCipherKey();

      expect(reset, isFalse);
    });

    test('returns null (plaintext fallback) when migration failed', () async {
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.failed,
        onDelete: () {},
      );

      expect(await bootstrap.resolveCipherKey(), isNull);
    });

    test(
      'fails closed and preserves the key when classification is unknown',
      () async {
        const existing =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        const error = DatabaseClassificationException(
          stage: DatabaseClassificationStage.readSchema,
          resultCode: 5,
          extendedResultCode: 5,
        );
        store[dbCipherKeyStorageKey] = existing;
        final bootstrap = DatabaseEncryptionBootstrap(
          secureStorage: storage,
          ensureRuntime: () async {},
          isCipherAvailable: () => true,
          migrate: (_) async => throw error,
          deleteDatabase: () async {},
        );

        await expectLater(bootstrap.resolveCipherKey(), throwsA(same(error)));
        expect(store[dbCipherKeyStorageKey], existing);
      },
    );

    test(
      'fails closed and preserves the key after journal recovery fails',
      () async {
        const existing =
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
        const error = DatabaseHotJournalRecoveryError(
          stage: DatabaseHotJournalRecoveryStage.validateIntegrity,
        );
        store[dbCipherKeyStorageKey] = existing;
        var deleted = false;
        final bootstrap = DatabaseEncryptionBootstrap(
          secureStorage: storage,
          ensureRuntime: () async {},
          isCipherAvailable: () => true,
          migrate: (_) async => throw error,
          deleteDatabase: () async => deleted = true,
        );

        await expectLater(bootstrap.resolveCipherKey(), throwsA(same(error)));
        expect(store[dbCipherKeyStorageKey], existing);
        expect(deleted, isFalse);
        expect(
          shouldRepairLocalDatabaseCacheAfterBootstrapError(error),
          isFalse,
        );
      },
    );

    test('fails closed instead of handing back a null key for an unreadable '
        'database', () async {
      // The gap #6897 closes: this used to share the plaintext deferral's
      // enum case, so startup continued on a null key, opened the damaged file
      // anyway, and failed every statement for the rest of the session.
      var deleted = false;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.unreadable,
        onDelete: () => deleted = true,
      );

      await expectLater(
        bootstrap.resolveCipherKey(),
        throwsA(isA<DatabaseUnreadableError>()),
      );
      expect(
        deleted,
        isFalse,
        reason:
            'the damaged file is preserved for the user-confirmed reset on '
            'the failure screen, not wiped behind their back',
      );
    });

    test('keeps the cipher key when the database is unreadable', () async {
      const existing =
          '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
      store[dbCipherKeyStorageKey] = existing;
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.unreadable,
        onDelete: () {},
      );

      await expectLater(
        bootstrap.resolveCipherKey(),
        throwsA(isA<DatabaseUnreadableError>()),
      );
      expect(
        store[dbCipherKeyStorageKey],
        equals(existing),
        reason:
            'nothing here proves the key is stale, and it is the only thing '
            'that can still read a backup of the damaged file',
      );
    });

    test('regenerates a key when the stored value is malformed', () async {
      store[dbCipherKeyStorageKey] = 'not-a-valid-key';
      final bootstrap = buildBootstrap(
        outcome: CipherMigrationOutcome.migrated,
        onDelete: () {},
      );

      final key = await bootstrap.resolveCipherKey();

      expect(key, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(store[dbCipherKeyStorageKey], equals(key));
    });
  });

  group('resetEncryptedDatabaseCache', () {
    late _MockSecureStorage storage;
    late Map<String, String> store;
    late _MockSecureStorage legacyStorage;
    late Map<String, String> legacyStore;

    setUp(() {
      storage = _MockSecureStorage();
      store = <String, String>{
        dbCipherKeyStorageKey:
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99',
        'auth_key': 'must-stay',
      };
      when(
        () => storage.delete(key: any(named: 'key')),
      ).thenAnswer((inv) async {
        store.remove(inv.namedArguments[#key] as String);
      });
      legacyStorage = _MockSecureStorage();
      legacyStore = <String, String>{
        dbCipherKeyStorageKey:
            '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99',
      };
      when(
        () => legacyStorage.delete(key: any(named: 'key')),
      ).thenAnswer((inv) async {
        legacyStore.remove(inv.namedArguments[#key] as String);
      });
    });

    test(
      'backs up DB, deletes only DB cipher key, and clears reset state',
      () async {
        var deleted = false;
        var reset = false;

        await resetEncryptedDatabaseCache(
          secureStorage: storage,
          legacySecureStorage: legacyStorage,
          deleteDatabase: () async => deleted = true,
          onDatabaseReset: () async => reset = true,
        );

        expect(deleted, isTrue);
        expect(store, isNot(contains(dbCipherKeyStorageKey)));
        expect(store['auth_key'], equals('must-stay'));
        expect(reset, isTrue);
      },
    );

    test(
      'deletes the pre-#9343 copy of the key through the legacy storage',
      () async {
        await resetEncryptedDatabaseCache(
          secureStorage: storage,
          legacySecureStorage: legacyStorage,
          deleteDatabase: () async {},
        );

        // The key is in one slot, but an item this device has not rewritten yet
        // still carries the pre-#9343 class, and only `delete` filters on it.
        // Without the second delete that item survives the reset, and the next
        // launch reads the key the reset was supposed to rotate.
        expect(legacyStore, isEmpty);
        verify(
          () => legacyStorage.delete(key: dbCipherKeyStorageKey),
        ).called(1);
      },
    );

    test(
      'keeps the cipher key when the caller opts out of deleting it',
      () async {
        var deleted = false;

        await resetEncryptedDatabaseCache(
          secureStorage: storage,
          legacySecureStorage: legacyStorage,
          deleteCipherKey: false,
          deleteDatabase: () async => deleted = true,
        );

        expect(deleted, isTrue);
        expect(
          store[dbCipherKeyStorageKey],
          isNotNull,
          reason:
              'the backup this leaves behind is encrypted under that key, so '
              'deleting it would make the backup permanently unreadable',
        );
        verifyNever(() => storage.delete(key: any(named: 'key')));
        verifyNever(() => legacyStorage.delete(key: any(named: 'key')));
      },
    );

    test(
      'unreadable plaintext reset deletes DB without deleting cipher key',
      () async {
        var deleted = false;
        var reset = false;

        await resetUnreadablePlaintextDatabaseCache(
          secureStorage: storage,
          legacySecureStorage: legacyStorage,
          deleteDatabase: () async => deleted = true,
          onDatabaseReset: () async => reset = true,
        );

        expect(deleted, isTrue);
        expect(reset, isTrue);
        expect(store[dbCipherKeyStorageKey], isNotNull);
        verifyNever(() => storage.delete(key: any(named: 'key')));
        verifyNever(() => legacyStorage.delete(key: any(named: 'key')));
      },
    );

    test('records completed explicit reset outcomes', () async {
      final outcomes = <DatabaseRecoveryOutcome>[];

      await resetEncryptedDatabaseCache(
        secureStorage: storage,
        legacySecureStorage: legacyStorage,
        deleteCipherKey: false,
        deleteDatabase: () async {},
        recoveryOutcome: DatabaseRecoveryOutcome.recreatedAfterBootstrapFailure,
        persistRecoveryOutcome: (outcome) async => outcomes.add(outcome),
      );
      await resetUnreadablePlaintextDatabaseCache(
        secureStorage: storage,
        legacySecureStorage: legacyStorage,
        deleteDatabase: () async {},
        persistRecoveryOutcome: (outcome) async => outcomes.add(outcome),
      );

      expect(outcomes, [
        DatabaseRecoveryOutcome.recreatedAfterBootstrapFailure,
        DatabaseRecoveryOutcome.recreatedUnreadable,
      ]);
    });
  });

  group('resolveStartupDatabaseCipherKey', () {
    test('records and rethrows bootstrap failures', () async {
      final error = StateError('secure storage unavailable');
      Object? recordedError;
      StackTrace? recordedStack;

      await expectLater(
        resolveStartupDatabaseCipherKey(
          resolveCipherKey: () async => throw error,
          recordError: (error, stack) async {
            recordedError = error;
            recordedStack = stack;
          },
        ),
        throwsA(same(error)),
      );

      expect(recordedError, same(error));
      expect(recordedStack, isNotNull);
    });

    test('rethrows bootstrap root cause when recording fails', () async {
      final bootstrapError = StateError('secure storage unavailable');

      await expectLater(
        resolveStartupDatabaseCipherKey(
          resolveCipherKey: () async => throw bootstrapError,
          recordError: (_, _) async => throw StateError('crash reporter down'),
        ),
        throwsA(same(bootstrapError)),
      );
    });
  });
}
