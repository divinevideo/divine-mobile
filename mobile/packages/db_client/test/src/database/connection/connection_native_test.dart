import 'dart:io';

import 'package:db_client/db_client.dart' show AppDatabase;
import 'package:db_client/src/database/connection/connection_native.dart';
import 'package:db_client/src/database/connection/database_integrity.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery.dart';
import 'package:db_client/src/database/connection/hot_journal_recovery_models.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/common.dart' show CommonDatabase;
import 'package:sqlite3/sqlite3.dart';

class _MockCipherDb extends Mock implements CommonDatabase {}

void main() {
  group('prepareDatabaseFile', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_connection_native_test_',
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('creates the parent database directory tree when missing', () {
      final dbPath = p.join(
        tempRoot.path,
        'openvine',
        'database',
        'divine_db.db',
      );

      final dbFile = prepareDatabaseFile(dbPath);

      expect(dbFile.path, equals(dbPath));
      expect(dbFile.parent.existsSync(), isTrue);
    });
  });

  group('buildSharedDatabasePath', () {
    test('uses Application Support-style base path with openvine/database', () {
      final path = buildSharedDatabasePath('/tmp/app-support');

      expect(path, equals('/tmp/app-support/openvine/database/divine_db.db'));
    });
  });

  group('applyDbCacheVersionReset', () {
    late Directory tempRoot;
    late String dbPath;
    late String dbDir;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cache_version_test_',
      );
      dbDir = p.join(tempRoot.path, 'openvine', 'database');
      dbPath = p.join(dbDir, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('writes current version on first run without deleting DB', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [1, 2, 3]);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isTrue);
      expect(File(dbPath).readAsBytesSync(), equals(const [1, 2, 3]));
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('preserves existing DB and sidecars when stored version is stale', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [1]);
      File('$dbPath-journal').writeAsBytesSync(const [2]);
      File('$dbPath-wal').writeAsBytesSync(const [3]);
      File('$dbPath-shm').writeAsBytesSync(const [4]);
      writeDbCacheVersion(dbDir, 1);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).readAsBytesSync(), equals(const [1]));
      expect(File('$dbPath-journal').readAsBytesSync(), equals(const [2]));
      expect(File('$dbPath-wal').readAsBytesSync(), equals(const [3]));
      expect(File('$dbPath-shm').readAsBytesSync(), equals(const [4]));
      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });

    test('no-op when stored version matches current', () {
      Directory(dbDir).createSync(recursive: true);
      File(dbPath).writeAsBytesSync(const [9, 9]);
      writeDbCacheVersion(dbDir, dbCacheVersion);

      applyDbCacheVersionReset(dbPath);

      expect(File(dbPath).existsSync(), isTrue);
      expect(File(dbPath).readAsBytesSync(), equals(const [9, 9]));
    });

    test('no-op when DB does not exist and no version file', () {
      applyDbCacheVersionReset(dbPath);

      expect(readDbCacheVersion(dbDir), equals(dbCacheVersion));
    });
  });

  group('readDbCacheVersion / writeDbCacheVersion', () {
    late Directory tempRoot;
    late String dbDir;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_version_rw_test_',
      );
      dbDir = p.join(tempRoot.path, 'openvine', 'database');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('returns null when version file does not exist', () {
      expect(readDbCacheVersion(dbDir), isNull);
    });

    test('round-trips a version number', () {
      writeDbCacheVersion(dbDir, 42);

      expect(readDbCacheVersion(dbDir), equals(42));
    });

    test('returns null for corrupt version file content', () {
      Directory(dbDir).createSync(recursive: true);
      File(p.join(dbDir, dbVersionFileName)).writeAsStringSync('not-a-number');

      expect(readDbCacheVersion(dbDir), isNull);
    });
  });

  group('migrateLegacyDatabase', () {
    late Directory tempRoot;
    late String legacyPath;
    late String newPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_migrate_legacy_test_',
      );
      legacyPath = p.join(
        tempRoot.path,
        'legacy',
        'openvine',
        'database',
        'divine_db.db',
      );
      newPath = p.join(
        tempRoot.path,
        'support',
        'openvine',
        'database',
        'divine_db.db',
      );
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('moves the legacy database when the new location is empty', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1, 2, 3, 4]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).existsSync(), isTrue);
      expect(File(newPath).readAsBytesSync(), equals(const [1, 2, 3, 4]));
      expect(File(legacyPath).existsSync(), isFalse);
    });

    test('creates the destination directory tree when missing', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [42]);

      expect(Directory(p.dirname(newPath)).existsSync(), isFalse);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(Directory(p.dirname(newPath)).existsSync(), isTrue);
      expect(File(newPath).existsSync(), isTrue);
    });

    test('preserves new DB when both legacy and new databases exist', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1, 2, 3]);

      final newFile = File(newPath);
      newFile.parent.createSync(recursive: true);
      newFile.writeAsBytesSync(const [9, 9, 9]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(legacyPath).existsSync(), isFalse);
      expect(File(newPath).readAsBytesSync(), equals(const [9, 9, 9]));
      expect(
        File(_legacyConflictBackupPath(newPath)).readAsBytesSync(),
        equals(const [1, 2, 3]),
      );
    });

    test(
      'restores legacy DB when destination exists but has no local data',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(newPath);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
      },
    );

    test(
      'restores legacy DB when destination has only replaceable cache rows',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);
        _createSqliteDatabase(newPath, eventCount: 1);

        expect(File('$legacyPath-wal').existsSync(), isTrue);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
        expect(File(_destinationBackupPath(newPath)).existsSync(), isTrue);
        expect(_eventCount(_destinationBackupPath(newPath)), equals(1));
      },
    );

    test(
      'restores legacy DB when destination only has empty sidecars',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(newPath);
        File('$newPath-wal').createSync();
        File('$newPath-shm').createSync();

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$newPath-wal').existsSync(), isFalse);
        expect(File('$newPath-shm').existsSync(), isFalse);
      },
    );

    test(
      'backs up sidecars when destination has no actionable local rows',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(
          newPath,
          pendingUploadStatuses: const ['published'],
          pendingActionStatuses: const ['completed'],
        );
        File('$newPath-wal').writeAsBytesSync(const [7]);
        File('$newPath-shm').writeAsBytesSync(const [8]);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        final backupPath = _destinationBackupPath(newPath);
        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$newPath-wal').existsSync(), isFalse);
        expect(File('$newPath-shm').existsSync(), isFalse);
        expect(File(backupPath).existsSync(), isTrue);
        expect(File('$backupPath-wal').existsSync(), isTrue);
        expect(File('$backupPath-shm').existsSync(), isTrue);
        expect(File('$backupPath-wal').lengthSync(), greaterThan(0));
        expect(File('$backupPath-shm').lengthSync(), greaterThan(0));
      },
    );

    test('does not reuse a backup name owned by a rollback journal', () async {
      _createSqliteDatabase(legacyPath, draftCount: 1);
      _createSqliteDatabase(newPath);
      final occupiedBackupPath = _destinationBackupPath(newPath);
      File('$occupiedBackupPath-journal').writeAsBytesSync(const [9]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(
        File('$occupiedBackupPath-journal').readAsBytesSync(),
        equals([9]),
      );
      expect(File('$occupiedBackupPath.1').existsSync(), isTrue);
    });

    test(
      'preserves destination when queue rows still require action',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        _createSqliteDatabase(
          newPath,
          pendingUploadStatuses: const ['uploading'],
          pendingActionStatuses: const ['pending'],
        );

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        final legacyBackupPath = _legacyConflictBackupPath(newPath);
        expect(File(legacyPath).existsSync(), isFalse);
        expect(_draftCount(legacyBackupPath), equals(1));
        expect(_pendingUploadCount(newPath), equals(1));
        expect(_pendingActionCount(newPath), equals(1));
        expect(File(_destinationBackupPath(newPath)).existsSync(), isFalse);
      },
    );

    test(
      'backs up legacy beside destination when both DBs have local data',
      () async {
        _createSqliteDatabase(legacyPath, draftCount: 1);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);

        _createSqliteDatabase(newPath, draftCount: 1);
        File('$newPath-wal').writeAsBytesSync(const [2]);
        File('$newPath-shm').writeAsBytesSync(const [3]);

        expect(File('$legacyPath-wal').readAsBytesSync(), equals([4]));
        expect(File('$legacyPath-shm').readAsBytesSync(), equals([5]));

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(File(newPath).existsSync(), isTrue);
        expect(_draftCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
        expect(File(_destinationBackupPath(newPath)).existsSync(), isFalse);

        final legacyBackupPath = _legacyConflictBackupPath(newPath);
        expect(File(legacyBackupPath).existsSync(), isTrue);
        expect(File('$legacyBackupPath-wal').readAsBytesSync(), equals([4]));
        expect(File('$legacyBackupPath-shm').existsSync(), isTrue);
        expect(File('$legacyBackupPath-shm').lengthSync(), greaterThan(0));
        expect(_draftCount(legacyBackupPath), equals(1));
      },
    );

    test(
      'deletes orphaned legacy database when neither side has actionable data',
      () async {
        _createSqliteDatabase(legacyPath);
        File('$legacyPath-wal').writeAsBytesSync(const [4]);
        File('$legacyPath-shm').writeAsBytesSync(const [5]);
        _createSqliteDatabase(newPath, eventCount: 1);

        await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

        expect(File(newPath).existsSync(), isTrue);
        expect(_eventCount(newPath), equals(1));
        expect(File(legacyPath).existsSync(), isFalse);
        expect(File('$legacyPath-wal').existsSync(), isFalse);
        expect(File('$legacyPath-shm').existsSync(), isFalse);
      },
    );

    test('no-op when no legacy database exists (fresh install)', () async {
      expect(File(legacyPath).existsSync(), isFalse);
      expect(File(newPath).existsSync(), isFalse);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).existsSync(), isFalse);
      expect(Directory(p.dirname(newPath)).existsSync(), isFalse);
    });

    test('migrates every sidecar file alongside the database', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [1]);
      File('$legacyPath-journal').writeAsBytesSync(const [2]);
      File('$legacyPath-wal').writeAsBytesSync(const [3]);
      File('$legacyPath-shm').writeAsBytesSync(const [4]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).readAsBytesSync(), equals(const [1]));
      expect(File('$newPath-journal').readAsBytesSync(), equals(const [2]));
      expect(File('$newPath-wal').readAsBytesSync(), equals(const [3]));
      expect(File('$newPath-shm').readAsBytesSync(), equals(const [4]));
      expect(File('$legacyPath-journal').existsSync(), isFalse);
      expect(File('$legacyPath-wal').existsSync(), isFalse);
      expect(File('$legacyPath-shm').existsSync(), isFalse);
    });

    test('migrates database even when no sidecar files are present', () async {
      final legacyFile = File(legacyPath);
      legacyFile.parent.createSync(recursive: true);
      legacyFile.writeAsBytesSync(const [7]);

      await migrateLegacyDatabase(legacyPath: legacyPath, newPath: newPath);

      expect(File(newPath).readAsBytesSync(), equals(const [7]));
      expect(File('$newPath-wal').existsSync(), isFalse);
      expect(File('$newPath-shm').existsSync(), isFalse);
    });
  });

  group('formatCipherKeyPragma', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('wraps a 64-hex key in the SQLCipher raw-key PRAGMA form', () {
      expect(
        formatCipherKeyPragma(validKey),
        equals('PRAGMA key = "x\'$validKey\'";'),
      );
    });

    test('accepts upper-case hex', () {
      expect(
        formatCipherKeyPragma(validKey.toUpperCase()),
        equals('PRAGMA key = "x\'${validKey.toUpperCase()}\'";'),
      );
    });

    test('rejects a key that is too short', () {
      expect(() => formatCipherKeyPragma('abcd'), throwsArgumentError);
    });

    test('rejects a key with non-hex characters', () {
      expect(() => formatCipherKeyPragma('z' * 64), throwsArgumentError);
    });

    test('rejects an empty key (no accidental plaintext open)', () {
      expect(() => formatCipherKeyPragma(''), throwsArgumentError);
    });

    test('thrown ArgumentError never embeds the key material', () {
      // Regression for the #4945 review finding: ArgumentError.value embeds the
      // invalid value in toString(), which would leak cipher key material.
      const malformedKey = 'deadbeef$validKey'; // 72 hex chars => invalid
      expect(
        () => formatCipherKeyPragma(malformedKey),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains(malformedKey)),
          ),
        ),
      );
    });
  });

  group('applyCipherKey', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test(
      'opens a file-backed SQLite3MultipleCiphers database with a raw key',
      () {
        final tempRoot = Directory.systemTemp.createTempSync(
          'db_client_apply_mc_key_test_',
        );
        addTearDown(() {
          if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
        });
        final dbPath = p.join(tempRoot.path, 'encrypted.db');

        final db = sqlite3.open(dbPath);
        applyCipherKey(db, validKey);
        db
          ..execute('CREATE TABLE secrets (value TEXT NOT NULL);')
          ..execute("INSERT INTO secrets (value) VALUES ('kept');")
          ..close();

        final reopened = sqlite3.open(dbPath);
        addTearDown(reopened.close);
        applyCipherKey(reopened, validKey);
        expect(
          reopened.select('SELECT value FROM secrets;').first['value'],
          equals('kept'),
        );
      },
    );

    test('encrypted raw-key database is not readable as plaintext', () {
      final tempRoot = Directory.systemTemp.createTempSync(
        'db_client_plaintext_rejects_mc_key_test_',
      );
      addTearDown(() {
        if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
      });
      final dbPath = p.join(tempRoot.path, 'encrypted.db');

      final encrypted = sqlite3.open(dbPath);
      applyCipherKey(encrypted, validKey);
      encrypted
        ..execute('CREATE TABLE secrets (value TEXT NOT NULL);')
        ..execute("INSERT INTO secrets (value) VALUES ('kept');")
        ..close();

      final plaintext = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      addTearDown(plaintext.close);
      expect(
        () => plaintext.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('rejects a malformed key before touching the database', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      expect(() => applyCipherKey(db, 'not-a-key'), throwsArgumentError);
    });

    test('never leaks the key when the keying statement throws (#4945)', () {
      // SqliteException.toString() appends the causing statement, which is the
      // PRAGMA key containing the raw key. applyCipherKey must convert that to
      // a key-free error before it can escape to Crashlytics.
      final keyPragma = formatCipherKeyPragma(validKey);
      final leaky = SqliteException(
        extendedResultCode: 26,
        message: 'file is not a database',
        causingStatement: keyPragma, // causing statement embeds the key
      );
      expect(leaky.toString(), contains(validKey)); // the source really leaks

      final db = _MockCipherDb();
      when(() => db.execute(any())).thenAnswer((invocation) {
        final sql = invocation.positionalArguments.first as String;
        if (sql == keyPragma) {
          throw leaky;
        }
      });

      expect(
        () => applyCipherKey(db, validKey),
        throwsA(
          isA<StateError>().having(
            (e) => e.toString(),
            'toString',
            isNot(contains(validKey)),
          ),
        ),
      );
    });
  });

  group('openEncryptedConnection', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('throws ArgumentError for a malformed key at construction time', () {
      expect(
        () => openEncryptedConnection(rawKeyHex: 'too-short'),
        throwsArgumentError,
      );
    });

    test('returns a lazily-opened QueryExecutor for a well-formed key', () {
      expect(
        openEncryptedConnection(rawKeyHex: validKey),
        isA<QueryExecutor>(),
      );
    });
  });

  group('databasePassesIntegrityCheck', () {
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_integrity_check_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('returns true for a structurally sound database', () {
      _createMultiPageDatabase(dbPath);
      final db = sqlite3.open(dbPath);
      addTearDown(db.close);

      expect(databasePassesIntegrityCheck(db), isTrue);
    });

    test('returns false when a table/index b-tree page is malformed', () {
      _createMultiPageDatabase(dbPath);
      _corruptPagesAfterSchema(dbPath);
      final db = sqlite3.open(dbPath);
      addTearDown(db.close);

      // The schema page is intact, so the open above and a bare
      // `sqlite_master` read both succeed — this is exactly the corruption
      // that slips past applyCipherKey's schema probe.
      expect(
        () => db.select('SELECT count(*) FROM sqlite_master;'),
        returnsNormally,
      );
      expect(databasePassesIntegrityCheck(db), isFalse);
    });
  });

  group('encryptedCopyMatchesSource', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    late Directory tempRoot;
    late String plaintextPath;
    late String encryptedPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_copy_matches_test_',
      );
      plaintextPath = p.join(tempRoot.path, 'plain.db');
      encryptedPath = p.join(tempRoot.path, 'enc.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    // Builds a plaintext source and a keyed encrypted copy that agree on
    // user_version and user-table row counts, so the only thing that can flip
    // the verifier's verdict is the structural integrity check.
    void seedMatchingPair() {
      sqlite3.open(plaintextPath)
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);')
        ..execute("INSERT INTO t (v) VALUES ('a');")
        ..execute("INSERT INTO t (v) VALUES ('b');")
        ..execute('PRAGMA user_version = 7;')
        ..close();

      final encrypted = sqlite3.open(encryptedPath);
      applyCipherKey(encrypted, validKey);
      encrypted
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);')
        ..execute("INSERT INTO t (v) VALUES ('a');")
        ..execute("INSERT INTO t (v) VALUES ('b');")
        ..execute('PRAGMA user_version = 7;')
        ..close();
    }

    test('rejects the artifact when the integrity check fails, even though row '
        'counts and user_version match', () {
      seedMatchingPair();

      expect(
        encryptedCopyMatchesSource(
          plaintextPath: plaintextPath,
          encryptedPath: encryptedPath,
          rawKeyHex: validKey,
          integrityCheck: (_) => false,
        ),
        isFalse,
        reason:
            'quick_check must gate promotion even when counts and version '
            'match — this is the 1.0.15 index-corruption vector',
      );
    });

    test(
      'accepts a healthy copy whose counts, version, and integrity hold',
      () {
        seedMatchingPair();

        expect(
          encryptedCopyMatchesSource(
            plaintextPath: plaintextPath,
            encryptedPath: encryptedPath,
            rawKeyHex: validKey,
          ),
          isTrue,
        );
      },
    );

    test('rejects a copy whose row counts differ from the source', () {
      seedMatchingPair();
      final encrypted = sqlite3.open(encryptedPath);
      applyCipherKey(encrypted, validKey);
      encrypted
        ..execute("INSERT INTO t (v) VALUES ('c');")
        ..close();

      expect(
        encryptedCopyMatchesSource(
          plaintextPath: plaintextPath,
          encryptedPath: encryptedPath,
          rawKeyHex: validKey,
        ),
        isFalse,
      );
    });

    test('rejects a copy whose user_version differs from the source', () {
      seedMatchingPair();
      final encrypted = sqlite3.open(encryptedPath);
      applyCipherKey(encrypted, validKey);
      encrypted
        ..execute('PRAGMA user_version = 8;')
        ..close();

      expect(
        encryptedCopyMatchesSource(
          plaintextPath: plaintextPath,
          encryptedPath: encryptedPath,
          rawKeyHex: validKey,
        ),
        isFalse,
      );
    });

    test('fails closed when a database cannot be read (SqliteException)', () {
      // A valid encrypted copy but a non-database plaintext source: reading it
      // raises SqliteException, which the verifier must treat as "no match"
      // rather than promoting an unverifiable pair.
      final encrypted = sqlite3.open(encryptedPath);
      applyCipherKey(encrypted, validKey);
      encrypted
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY);')
        ..close();
      File(
        plaintextPath,
      ).writeAsBytesSync(List<int>.generate(2048, (i) => i % 256));

      expect(
        encryptedCopyMatchesSource(
          plaintextPath: plaintextPath,
          encryptedPath: encryptedPath,
          rawKeyHex: validKey,
        ),
        isFalse,
      );
    });
  });

  group('encryptedDatabaseOpensWithKey', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    const otherKey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_opens_with_key_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('returns true when the database file does not exist', () async {
      expect(File(dbPath).existsSync(), isFalse);

      expect(
        await encryptedDatabaseOpensWithKey(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isTrue,
      );
    });

    test('returns true for a healthy encrypted database', () async {
      final db = sqlite3.open(dbPath);
      applyCipherKey(db, validKey);
      db
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);')
        ..execute("INSERT INTO t (v) VALUES ('kept');")
        ..close();

      expect(
        await encryptedDatabaseOpensWithKey(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isTrue,
      );
    });

    test('returns false when the key does not open the database', () async {
      final db = sqlite3.open(dbPath);
      applyCipherKey(db, validKey);
      db
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY);')
        ..close();

      expect(
        await encryptedDatabaseOpensWithKey(
          rawKeyHex: otherKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });

    test('returns false when corruption lies past the schema page', () async {
      final db = sqlite3.open(dbPath);
      applyCipherKey(db, validKey);
      db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);');
      for (var i = 0; i < 500; i += 1) {
        db.execute('INSERT INTO t (v) VALUES (?);', [
          'value_${i.toString().padLeft(6, '0')}',
        ]);
      }
      db.close();

      // Corrupt the back half of the file, leaving the header + schema pages
      // intact so applyCipherKey's `sqlite_master` probe still passes. The
      // damage is only reached once the integrity check walks the data b-tree
      // — the production shape where the shallow schema probe is not enough.
      final bytes = File(dbPath).readAsBytesSync();
      for (var i = bytes.length ~/ 2; i < bytes.length; i += 1) {
        bytes[i] = 0xFF;
      }
      File(dbPath).writeAsBytesSync(bytes);

      expect(
        await encryptedDatabaseOpensWithKey(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });
  });

  group('salvageCorruptEncryptedDatabase', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    const otherKey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('db_client_salvage_test_');
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('returns false when the database file does not exist', () async {
      expect(
        await salvageCorruptEncryptedDatabase(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });

    test('returns false and leaves the file when the key cannot decrypt '
        'it', () async {
      _createEncryptedDatabaseWithLocalData(dbPath, validKey);
      final before = File(dbPath).readAsBytesSync();

      final salvaged = await salvageCorruptEncryptedDatabase(
        rawKeyHex: otherKey,
        databasePath: dbPath,
      );

      expect(salvaged, isFalse);
      expect(File(dbPath).readAsBytesSync(), equals(before));
      expect(File('$dbPath.corruption_salvage').existsSync(), isFalse);
    });

    test(
      'preserves drafts/clips when a corrupt database is salvaged',
      () async {
        _createEncryptedDatabaseWithLocalData(dbPath, validKey);
        _corruptBackHalf(dbPath);

        // Precondition: the DB is corrupt but the local tables are still
        // readable (reading a table does not walk the corrupt event pages).
        expect(
          await encryptedDatabaseOpensWithKey(
            rawKeyHex: validKey,
            databasePath: dbPath,
          ),
          isFalse,
          reason: 'the corrupt DB must fail the integrity probe',
        );

        final salvaged = await salvageCorruptEncryptedDatabase(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(salvaged, isTrue);
        // The swapped-in database opens with the SAME key and is now sound.
        expect(
          await encryptedDatabaseOpensWithKey(
            rawKeyHex: validKey,
            databasePath: dbPath,
          ),
          isTrue,
        );
        // Drift's schema version is carried over so it opens the salvaged file
        // as an existing DB (beforeOpen) rather than re-running onCreate.
        final salvagedDb = sqlite3.open(dbPath);
        applyCipherKey(salvagedDb, validKey);
        expect(
          salvagedDb.select('PRAGMA user_version;').first.values.first,
          equals(1),
        );
        salvagedDb.close();
        // The irreplaceable local-only rows survived; the re-fetchable event
        // cache was dropped and will resync.
        expect(_encryptedRowCount(dbPath, validKey, 'drafts'), equals(2));
        expect(_encryptedRowCount(dbPath, validKey, 'clips'), equals(1));
        expect(_encryptedRowCount(dbPath, validKey, 'event'), equals(0));
        // The unsent DM reaction (only-copy local data) is preserved too.
        expect(
          _encryptedRowCount(dbPath, validKey, 'dm_message_reactions'),
          equals(1),
        );

        // The corrupt original is kept as a backup, still readable under the
        // same key (no key rotation).
        final backup = '$dbPath.pre_corruption_recovery_backup';
        expect(File(backup).existsSync(), isTrue);
        final backupDb = sqlite3.open(backup);
        addTearDown(backupDb.close);
        applyCipherKey(backupDb, validKey);
        expect(
          backupDb.select('SELECT count(*) c FROM drafts;').first['c'],
          equals(2),
        );
      },
    );

    test(
      'keeps the readable prefix when a salvageable table itself is corrupt',
      () async {
        // Corruption lands inside a *salvageable* table's own pages (drafts,
        // here spanning past the file midpoint), not just the re-fetchable
        // event cache. An eager `SELECT *` throws and salvages zero drafts; the
        // cursor keeps every row before the corrupt page.
        _createEncryptedDatabaseWithManyDrafts(
          dbPath,
          validKey,
          draftCount: 2000,
        );
        _corruptBackHalf(dbPath);

        expect(
          await encryptedDatabaseOpensWithKey(
            rawKeyHex: validKey,
            databasePath: dbPath,
          ),
          isFalse,
          reason: 'precondition: the drafts table is genuinely corrupt',
        );

        final salvaged = await salvageCorruptEncryptedDatabase(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(salvaged, isTrue);
        final recovered = _encryptedRowCount(dbPath, validKey, 'drafts');
        expect(
          recovered,
          greaterThan(0),
          reason: 'the readable prefix survives (eager select would drop all)',
        );
        expect(
          recovered,
          lessThan(2000),
          reason: 'the corrupt tail is genuinely past recovery',
        );
      },
    );
  });

  group('encryptedDatabaseKeyDecrypts', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    const otherKey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_key_decrypts_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('returns false when the database file does not exist', () async {
      expect(
        await encryptedDatabaseKeyDecrypts(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });

    test('returns true when the key decrypts a healthy database', () async {
      final db = sqlite3.open(dbPath);
      applyCipherKey(db, validKey);
      db
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY);')
        ..close();

      expect(
        await encryptedDatabaseKeyDecrypts(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        isTrue,
      );
    });

    test('returns false when the key cannot decrypt the file', () async {
      final db = sqlite3.open(dbPath);
      applyCipherKey(db, validKey);
      db
        ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY);')
        ..close();

      expect(
        await encryptedDatabaseKeyDecrypts(
          rawKeyHex: otherKey,
          databasePath: dbPath,
        ),
        isFalse,
      );
    });

    test(
      'returns true for a decryptable-but-corrupt database (keeps the key)',
      () async {
        // The gate must NOT report key loss for a corrupt-but-decryptable DB —
        // that would rotate a still-valid key and orphan the backup. The schema
        // page stays intact (key decrypts) while the data pages are damaged.
        _createEncryptedDatabaseWithLocalData(dbPath, validKey);
        _corruptBackHalf(dbPath);

        expect(
          await encryptedDatabaseKeyDecrypts(
            rawKeyHex: validKey,
            databasePath: dbPath,
          ),
          isTrue,
        );
      },
    );
  });

  group('migratePlaintextToEncrypted salvage-swap resume', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    const otherKey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_salvage_resume_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test(
      'promotes a verified salvage copy stranded by an interrupted swap',
      () async {
        // Reproduce the crash window in salvageCorruptEncryptedDatabase: the
        // corrupt original was already renamed to its backup (so dbPath is
        // gone) and a verified salvage copy sits at `.corruption_salvage`, but
        // the process died before the final promote.
        final salvagePath = '$dbPath.corruption_salvage';
        _createEncryptedDatabaseWithLocalData(salvagePath, validKey);
        expect(File(dbPath).existsSync(), isFalse);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, CipherMigrationOutcome.alreadyEncrypted);
        expect(File(dbPath).existsSync(), isTrue);
        expect(
          File(salvagePath).existsSync(),
          isFalse,
          reason: 'the salvage copy is promoted into place, not left behind',
        );
        // The recovered local-only rows landed in the promoted database.
        expect(_encryptedRowCount(dbPath, validKey, 'drafts'), equals(2));
        expect(_encryptedRowCount(dbPath, validKey, 'clips'), equals(1));
      },
    );

    test(
      'discards an unusable salvage leftover instead of promoting it',
      () async {
        // A salvage copy that no longer opens under the key (here: written
        // under a different key) must not be promoted; it is deleted so
        // startup falls through to creating a fresh database.
        final salvagePath = '$dbPath.corruption_salvage';
        _createEncryptedDatabaseWithLocalData(salvagePath, otherKey);
        expect(File(dbPath).existsSync(), isFalse);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, CipherMigrationOutcome.noDatabase);
        expect(File(salvagePath).existsSync(), isFalse);
        expect(File(dbPath).existsSync(), isFalse);
      },
    );
  });

  group('salvageableLocalOnlyTables', () {
    test('every name exists in the real AppDatabase schema', () {
      // Pins the salvage list to the live Drift schema. Renaming a table
      // without updating this list would make `SELECT * FROM "<old>"` throw and
      // be silently swallowed — that table would salvage zero rows with every
      // test still green, because the salvage tests use a fabricated schema.
      final db = AppDatabase();
      addTearDown(db.close);

      final realTables = db.allTables.map((t) => t.actualTableName).toSet();
      for (final table in salvageableLocalOnlyTables) {
        expect(
          realTables,
          contains(table),
          reason: 'salvage list references unknown table "$table" — renamed?',
        );
      }
    });
  });

  // The production opens use NativeDatabase.createInBackground (#5391), which
  // runs the cipher `setup:` on a spawned background isolate. This proves
  // sqlite3mc resolves there (else applyCipherKey fails closed) and the DB is
  // genuinely encrypted, exercising the real background-isolate open path the
  // unit tests above only construct lazily.
  group('createInBackground encrypted open', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';

    test('opens an encrypted DB with the cipher applied on the background '
        'isolate and persists a keyed round-trip', () async {
      final tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cib_cipher_test_',
      );
      addTearDown(() {
        if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
      });
      final dbPath = p.join(tempRoot.path, 'encrypted.db');

      final db = AppDatabase(
        NativeDatabase.createInBackground(
          File(dbPath),
          setup: (rawDb) => applyCipherKey(rawDb, validKey),
        ),
      );

      // Forces the background isolate to open, run `setup:` (applyCipherKey)
      // there, and run drift's onCreate migration. If sqlite3mc did not
      // resolve on the spawned isolate, applyCipherKey throws StateError and
      // this fails.
      final rows = await db
          .customSelect('SELECT count(*) AS c FROM sqlite_master;')
          .get();
      expect(rows.single.read<int>('c'), greaterThanOrEqualTo(0));
      await db.close();

      // Prove the file is genuinely encrypted by the bg-isolate cipher: a
      // plaintext open must fail to read its schema.
      final plaintext = sqlite3.open(dbPath, mode: OpenMode.readOnly);
      addTearDown(plaintext.close);
      expect(
        () => plaintext.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('migratePlaintextToEncrypted', () {
    const validKey =
        '2dd29ca851e7b56e4697b0e1f08507293d761a05ce4d1b628663f411a8086d99';
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cipher_migration_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('returns noDatabase when no file exists', () async {
      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.noDatabase),
      );
    });

    test('removes an empty plaintext database so a fresh encrypted one is '
        'created on first open', () async {
      sqlite3.open(dbPath).close(); // empty database, no user tables
      expect(File(dbPath).existsSync(), isTrue);

      final outcome = await migratePlaintextToEncrypted(
        rawKeyHex: validKey,
        databasePath: dbPath,
      );

      expect(outcome, equals(CipherMigrationOutcome.removedEmptyPlaintext));
      expect(File(dbPath).existsSync(), isFalse);
    });

    test('classifies a non-database file as already encrypted', () async {
      File(dbPath).writeAsBytesSync(List<int>.generate(64, (i) => i));

      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.alreadyEncrypted),
      );
    });

    test('reports a legible header over a corrupt schema page as unreadable, '
        'not a deferrable failure', () async {
      // The shape that starts the app with a null cipher key (#6897): the
      // 100-byte header survives, so the keyless open succeeds and only the
      // sqlite_master read trips — on SQLITE_CORRUPT, not the SQLITE_NOTADB
      // that would classify the file as encrypted. Whole-file garbage does NOT
      // reproduce it; that reads as encrypted and self-heals.
      _createSqliteDatabase(dbPath, draftCount: 3);
      _corruptSchemaPageKeepingHeader(dbPath);

      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.unreadable),
        reason:
            'CipherMigrationOutcome.failed would defer to a next launch that '
            'classifies the same bytes the same way, forever',
      );
      expect(
        File(dbPath).existsSync(),
        isTrue,
        reason: 'the damaged file is left for the caller to back up',
      );
    });

    test('reports corruption past the schema page as unreadable, not a '
        'deferrable failure', () async {
      // The other door onto the same #6897 state, and the wider one: the
      // classification reads only sqlite_master, so damage anywhere past page 1
      // looks like healthy plaintext and first surfaces in the VACUUM INTO copy
      // below. Deferring there retried the identical bytes on every launch just
      // as forever as the schema-page case did.
      _createMultiPageDatabase(dbPath);
      _corruptPagesAfterSchema(dbPath);

      expect(
        await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        ),
        equals(CipherMigrationOutcome.unreadable),
        reason:
            'the schema page is intact, so only the whole-database copy '
            'can see this damage',
      );
      expect(
        File(dbPath).existsSync(),
        isTrue,
        reason: 'the damaged file is left for the caller to back up',
      );
      expect(
        File('$dbPath.sqlcipher_migrating').existsSync(),
        isFalse,
        reason: 'the half-written side file is cleaned up',
      );
    });

    test('fails closed when the keyless classification is locked', () async {
      _createSqliteDatabase(dbPath, draftCount: 1);
      final lockHolder = sqlite3.open(dbPath)..execute('BEGIN EXCLUSIVE;');
      addTearDown(() {
        lockHolder
          ..execute('ROLLBACK;')
          ..close();
      });

      await expectLater(
        migratePlaintextToEncrypted(rawKeyHex: validKey, databasePath: dbPath),
        throwsA(
          isA<DatabaseClassificationException>()
              .having(
                (error) => error.stage,
                'stage',
                DatabaseClassificationStage.readSchema,
              )
              .having((error) => error.resultCode, 'resultCode', 5),
        ),
      );
      expect(File(dbPath).existsSync(), isTrue);
    });

    test('enters hot-journal recovery only for exact readonly rollback', () {
      const ordinaryReadOnly = DatabaseClassificationException(
        stage: DatabaseClassificationStage.readSchema,
        resultCode: sqliteReadOnly,
        extendedResultCode: sqliteReadOnly,
      );
      const hotRollback = DatabaseClassificationException(
        stage: DatabaseClassificationStage.readSchema,
        resultCode: sqliteReadOnly,
        extendedResultCode: sqliteReadOnlyRollback,
      );

      expect(isHotRollbackJournalFailure(ordinaryReadOnly), isFalse);
      expect(isHotRollbackJournalFailure(hotRollback), isTrue);
    });

    test(
      'recovers a plaintext hot rollback journal before migration',
      () async {
        _createHotJournalFixture(dbPath);
        _expectReadOnlyRollback(dbPath);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, CipherMigrationOutcome.migrated);
        expect(File('$dbPath-journal').existsSync(), isFalse);
        expect(_hotJournalRowCount(dbPath, key: validKey), 1);
      },
    );

    test(
      'recovers an encrypted hot rollback journal under its existing key',
      () async {
        _createHotJournalFixture(dbPath, key: validKey);
        _expectReadOnlyRollback(dbPath);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, CipherMigrationOutcome.alreadyEncrypted);
        expect(File('$dbPath-journal').existsSync(), isFalse);
        expect(_hotJournalRowCount(dbPath, key: validKey), 1);
      },
    );

    test(
      'recovers an encrypted journal whose transaction spilled schema pages',
      () async {
        _createSpilledSchemaHotJournalFixture(dbPath, key: validKey);
        _expectReadOnlyRollback(dbPath);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, CipherMigrationOutcome.alreadyEncrypted);
        expect(File('$dbPath-journal').existsSync(), isFalse);
        expect(_userTableCount(dbPath, key: validKey), 40);
      },
    );

    test(
      'wrong key leaves an encrypted hot journal byte-for-byte intact',
      () async {
        _createHotJournalFixture(dbPath, key: validKey);
        _expectReadOnlyRollback(dbPath);
        final databaseBefore = File(dbPath).readAsBytesSync();
        final journalBefore = File('$dbPath-journal').readAsBytesSync();
        const wrongKey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        expect(
          await migratePlaintextToEncrypted(
            rawKeyHex: wrongKey,
            databasePath: dbPath,
          ),
          CipherMigrationOutcome.alreadyEncrypted,
        );

        expect(File(dbPath).readAsBytesSync(), databaseBefore);
        expect(File('$dbPath-journal').readAsBytesSync(), journalBefore);
      },
    );

    test(
      'wrong key leaves a spilled-schema journal byte-for-byte intact',
      () async {
        _createSpilledSchemaHotJournalFixture(dbPath, key: validKey);
        _expectReadOnlyRollback(dbPath);
        final databaseBefore = File(dbPath).readAsBytesSync();
        final journalBefore = File('$dbPath-journal').readAsBytesSync();
        const wrongKey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        expect(
          await migratePlaintextToEncrypted(
            rawKeyHex: wrongKey,
            databasePath: dbPath,
          ),
          CipherMigrationOutcome.alreadyEncrypted,
        );

        expect(File(dbPath).readAsBytesSync(), databaseBefore);
        expect(File('$dbPath-journal').readAsBytesSync(), journalBefore);
      },
    );

    test('failed replay restores the database and journal snapshot', () {
      _createHotJournalFixture(dbPath, key: validKey);
      final databaseBefore = File(dbPath).readAsBytesSync();
      final journalBefore = File('$dbPath-journal').readAsBytesSync();
      var configurations = 0;

      expect(
        () => recoverHotRollbackJournal(
          databasePath: dbPath,
          configureEncryptedDatabase: (database) {
            configurations += 1;
            applyCipherKey(database, validKey);
            if (configurations == 2) throw StateError('injected failure');
          },
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>().having(
            (error) => error.stage,
            'stage',
            DatabaseHotJournalRecoveryStage.replayJournal,
          ),
        ),
      );

      expect(File(dbPath).readAsBytesSync(), databaseBefore);
      expect(File('$dbPath-journal').readAsBytesSync(), journalBefore);
    });

    test('SQLite replay failure retains its real result codes', () {
      _createHotJournalFixture(dbPath, key: validKey);
      var configurations = 0;

      expect(
        () => recoverHotRollbackJournal(
          databasePath: dbPath,
          configureEncryptedDatabase: (database) {
            configurations += 1;
            keyCipherDatabase(database, validKey);
            if (configurations == 2) {
              throw SqliteException(
                extendedResultCode: 778,
                message: 'injected I/O failure',
              );
            }
          },
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>()
              .having(
                (error) => error.stage,
                'stage',
                DatabaseHotJournalRecoveryStage.replayJournal,
              )
              .having((error) => error.resultCode, 'resultCode', 10)
              .having(
                (error) => error.extendedResultCode,
                'extendedResultCode',
                778,
              ),
        ),
      );
    });

    test('failed validation restores the database and journal snapshot', () {
      _createHotJournalFixture(dbPath, key: validKey);
      final databaseBefore = File(dbPath).readAsBytesSync();
      final journalBefore = File('$dbPath-journal').readAsBytesSync();
      var configurations = 0;

      expect(
        () => recoverHotRollbackJournal(
          databasePath: dbPath,
          configureEncryptedDatabase: (database) {
            configurations += 1;
            keyCipherDatabase(database, validKey);
            if (configurations == 3) throw StateError('injected failure');
          },
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>().having(
            (error) => error.stage,
            'stage',
            DatabaseHotJournalRecoveryStage.validateIntegrity,
          ),
        ),
      );

      expect(File(dbPath).readAsBytesSync(), databaseBefore);
      expect(File('$dbPath-journal').readAsBytesSync(), journalBefore);
    });

    test('restores the journal before attempting the database copy', () {
      _createHotJournalFixture(dbPath, key: validKey);
      final journalBefore = File('$dbPath-journal').readAsBytesSync();
      final restoredDestinations = <String>[];
      var configurations = 0;

      expect(
        () => recoverHotRollbackJournal(
          databasePath: dbPath,
          configureEncryptedDatabase: (database) {
            configurations += 1;
            keyCipherDatabase(database, validKey);
            if (configurations == 2) {
              throw StateError('injected replay failure');
            }
          },
          restoreCopyForTesting: (source, destination) {
            restoredDestinations.add(destination);
            if (destination == dbPath) {
              throw const FileSystemException('injected database copy failure');
            }
            return source.copySync(destination);
          },
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>().having(
            (error) => error.stage,
            'stage',
            DatabaseHotJournalRecoveryStage.restoreSnapshot,
          ),
        ),
      );

      expect(restoredDestinations, ['$dbPath-journal', dbPath]);
      expect(File('$dbPath-journal').readAsBytesSync(), journalBefore);
    });

    test('attempts hot-journal recovery at most once', () async {
      _createHotJournalFixture(dbPath, key: validKey);
      final savedJournal = File('$dbPath.saved-journal')
        ..writeAsBytesSync(File('$dbPath-journal').readAsBytesSync());
      var recoveryCompletions = 0;

      await expectLater(
        migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
          onHotJournalRecoveryCompletedForTesting: () {
            recoveryCompletions += 1;
            savedJournal.copySync('$dbPath-journal');
          },
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>().having(
            (error) => error.stage,
            'stage',
            DatabaseHotJournalRecoveryStage.retryClassification,
          ),
        ),
      );

      expect(recoveryCompletions, 1);
    });

    test('short database fails closed before writable recovery', () {
      File(dbPath).writeAsBytesSync(const [1, 2, 3]);
      File('$dbPath-journal').writeAsBytesSync(const [4, 5, 6]);

      expect(
        () => recoverHotRollbackJournal(
          databasePath: dbPath,
          configureEncryptedDatabase: (db) => applyCipherKey(db, validKey),
        ),
        throwsA(
          isA<DatabaseHotJournalRecoveryError>().having(
            (error) => error.stage,
            'stage',
            DatabaseHotJournalRecoveryStage.inspectHeader,
          ),
        ),
      );
      expect(File(dbPath).readAsBytesSync(), const [1, 2, 3]);
      expect(File('$dbPath-journal').readAsBytesSync(), const [4, 5, 6]);
    });

    test(
      'migrates a populated plaintext DB to encrypted raw-key storage',
      () async {
        _createSqliteDatabase(dbPath, draftCount: 3);

        final outcome = await migratePlaintextToEncrypted(
          rawKeyHex: validKey,
          databasePath: dbPath,
        );

        expect(outcome, equals(CipherMigrationOutcome.migrated));
        expect(File(dbPath).existsSync(), isTrue);
        final encrypted = sqlite3.open(dbPath);
        addTearDown(encrypted.close);
        applyCipherKey(encrypted, validKey);
        expect(_draftCountFromOpenDb(encrypted), equals(3));

        final plaintext = sqlite3.open(dbPath, mode: OpenMode.readOnly);
        addTearDown(plaintext.close);
        expect(
          () => plaintext.select('SELECT count(*) FROM sqlite_master;'),
          throwsA(isA<SqliteException>()),
        );
      },
    );

    test('rejects a malformed key', () async {
      _createSqliteDatabase(dbPath, draftCount: 1);
      await expectLater(
        migratePlaintextToEncrypted(rawKeyHex: 'bad', databasePath: dbPath),
        throwsArgumentError,
      );
    });

    test('resumes an interrupted swap (verified encrypted artifact present, '
        'db absent)', () async {
      // Simulate a force-kill after the plaintext was renamed to its backup
      // but before the verified encrypted copy was moved into place: the
      // .sqlcipher_migrating artifact exists and the db path is absent.
      final encryptedPath = '$dbPath.sqlcipher_migrating';
      _createSqliteDatabase(encryptedPath, draftCount: 2);
      expect(File(dbPath).existsSync(), isFalse);

      final outcome = await migratePlaintextToEncrypted(
        rawKeyHex: validKey,
        databasePath: dbPath,
      );

      expect(outcome, equals(CipherMigrationOutcome.migrated));
      expect(File(dbPath).existsSync(), isTrue);
      expect(File(encryptedPath).existsSync(), isFalse);
      expect(_draftCount(dbPath), equals(2));
    });
  });

  group('promoteEncryptedMigrationArtifact', () {
    late Directory tempRoot;
    late String dbPath;
    late String encryptedPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_promote_cipher_artifact_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      encryptedPath = '$dbPath.sqlcipher_migrating';
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('moves the encrypted artifact and every sidecar into place', () {
      File(encryptedPath).writeAsBytesSync(const [1]);
      File('$encryptedPath-journal').writeAsBytesSync(const [2]);
      File('$encryptedPath-wal').writeAsBytesSync(const [3]);
      File('$encryptedPath-shm').writeAsBytesSync(const [4]);

      promoteEncryptedMigrationArtifact(
        encryptedPath: encryptedPath,
        dbPath: dbPath,
      );

      expect(File(dbPath).readAsBytesSync(), equals(const [1]));
      expect(File('$dbPath-journal').readAsBytesSync(), equals(const [2]));
      expect(File('$dbPath-wal').readAsBytesSync(), equals(const [3]));
      expect(File('$dbPath-shm').readAsBytesSync(), equals(const [4]));
      expect(File(encryptedPath).existsSync(), isFalse);
      expect(File('$encryptedPath-journal').existsSync(), isFalse);
      expect(File('$encryptedPath-wal').existsSync(), isFalse);
      expect(File('$encryptedPath-shm').existsSync(), isFalse);
    });
  });

  group('cleanUpPreCipherMigrationBackups', () {
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_cipher_backup_cleanup_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [0]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test(
      'deletes only pre-cipher plaintext migration backups and sidecars',
      () {
        final backupPath = '$dbPath.pre_cipher_migration_backup';
        final indexedBackupPath = '$dbPath.pre_cipher_migration_backup.1';
        final keyLossBackupPath = '$dbPath.pre_key_loss_wipe_backup';
        File(backupPath).writeAsBytesSync(const [1]);
        File('$backupPath-journal').writeAsBytesSync(const [2]);
        File('$backupPath-wal').writeAsBytesSync(const [3]);
        File('$backupPath-shm').writeAsBytesSync(const [4]);
        File(indexedBackupPath).writeAsBytesSync(const [5]);
        File('$indexedBackupPath-journal').writeAsBytesSync(const [6]);
        File(keyLossBackupPath).writeAsBytesSync(const [7]);
        File(
          '$dbPath.pre_cipher_migration_backup_notes',
        ).writeAsBytesSync(const [8]);

        cleanUpPreCipherMigrationBackups(dbPath);

        expect(File(dbPath).existsSync(), isTrue);
        expect(File(backupPath).existsSync(), isFalse);
        expect(File('$backupPath-journal').existsSync(), isFalse);
        expect(File('$backupPath-wal').existsSync(), isFalse);
        expect(File('$backupPath-shm').existsSync(), isFalse);
        expect(File(indexedBackupPath).existsSync(), isFalse);
        expect(File('$indexedBackupPath-journal').existsSync(), isFalse);
        expect(File('$indexedBackupPath-wal').existsSync(), isFalse);
        expect(File(keyLossBackupPath).existsSync(), isTrue);
        expect(
          File('$dbPath.pre_cipher_migration_backup_notes').existsSync(),
          isTrue,
        );
      },
    );
  });

  group('deleteDatabaseAndSidecars', () {
    late Directory tempRoot;
    late String dbPath;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync(
        'db_client_delete_database_sidecars_test_',
      );
      dbPath = p.join(tempRoot.path, 'divine_db.db');
      File(dbPath).writeAsBytesSync(const [1]);
      File('$dbPath-journal').writeAsBytesSync(const [2]);
      File('$dbPath-wal').writeAsBytesSync(const [3]);
      File('$dbPath-shm').writeAsBytesSync(const [4]);
      File('$dbPath.pre_key_loss_wipe_backup').writeAsBytesSync(const [5]);
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test(
      'deletes the current database and sidecars without making a backup',
      () {
        deleteDatabaseAndSidecars(dbPath);

        expect(File(dbPath).existsSync(), isFalse);
        expect(File('$dbPath-journal').existsSync(), isFalse);
        expect(File('$dbPath-wal').existsSync(), isFalse);
        expect(File('$dbPath-shm').existsSync(), isFalse);
        expect(
          File('$dbPath.pre_key_loss_wipe_backup').existsSync(),
          isTrue,
          reason: 'existing encrypted backups are not part of the current DB',
        );
      },
    );
  });
}

void _createHotJournalFixture(String targetPath, {String? key}) {
  final sourcePath = '$targetPath.source';
  File(sourcePath).parent.createSync(recursive: true);
  final source = sqlite3.open(sourcePath);
  try {
    if (key != null) applyCipherKey(source, key);
    source
      ..execute('PRAGMA journal_mode = DELETE;')
      ..execute('PRAGMA synchronous = FULL;')
      ..execute('PRAGMA cache_size = 1;')
      ..execute('CREATE TABLE hot_journal_rows (value BLOB NOT NULL);')
      ..execute('INSERT INTO hot_journal_rows VALUES (zeroblob(1024));')
      ..execute('BEGIN IMMEDIATE;');
    for (var index = 0; index < 24; index += 1) {
      source.execute('INSERT INTO hot_journal_rows VALUES (zeroblob(65536));');
    }
    expect(File('$sourcePath-journal').lengthSync(), greaterThan(0));
    File(sourcePath).copySync(targetPath);
    File('$sourcePath-journal').copySync('$targetPath-journal');
  } finally {
    source
      ..execute('ROLLBACK;')
      ..close();
    File(sourcePath).deleteSync();
  }
}

void _createSpilledSchemaHotJournalFixture(String targetPath, {String? key}) {
  final sourcePath = '$targetPath.source';
  File(sourcePath).parent.createSync(recursive: true);
  final source = sqlite3.open(sourcePath);
  try {
    if (key != null) applyCipherKey(source, key);
    source
      ..execute('PRAGMA journal_mode = DELETE;')
      ..execute('PRAGMA synchronous = FULL;')
      ..execute('PRAGMA cache_size = 1;');
    for (var index = 0; index < 40; index += 1) {
      source
        ..execute('CREATE TABLE committed_$index (value INTEGER);')
        ..execute(
          'CREATE INDEX committed_${index}_value '
          'ON committed_$index (value);',
        );
    }
    source.execute('BEGIN IMMEDIATE;');
    for (var index = 0; index < 360; index += 1) {
      source
        ..execute('CREATE TABLE uncommitted_$index (value INTEGER);')
        ..execute(
          'CREATE INDEX uncommitted_${index}_value '
          'ON uncommitted_$index (value);',
        );
    }
    expect(File('$sourcePath-journal').lengthSync(), greaterThan(0));
    File(sourcePath).copySync(targetPath);
    File('$sourcePath-journal').copySync('$targetPath-journal');
  } finally {
    source
      ..execute('ROLLBACK;')
      ..close();
    File(sourcePath).deleteSync();
  }
}

void _expectReadOnlyRollback(String path) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    expect(
      () => database.select('SELECT count(*) FROM sqlite_master;'),
      throwsA(
        isA<SqliteException>()
            .having((error) => error.resultCode, 'resultCode', sqliteReadOnly)
            .having(
              (error) => error.extendedResultCode,
              'extendedResultCode',
              sqliteReadOnlyRollback,
            ),
      ),
    );
  } finally {
    database.close();
  }
}

int _hotJournalRowCount(String path, {String? key}) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(database, key);
    return database
            .select('SELECT count(*) AS count FROM hot_journal_rows;')
            .single['count']
        as int;
  } finally {
    database.close();
  }
}

int _userTableCount(String path, {String? key}) {
  final database = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    if (key != null) applyCipherKey(database, key);
    return database
            .select(
              'SELECT count(*) AS count FROM sqlite_master '
              "WHERE type = 'table' "
              "AND name NOT LIKE 'sqlite_%';",
            )
            .single['count']
        as int;
  } finally {
    database.close();
  }
}

/// Creates an encrypted database with a few local-only rows (drafts, clips) in
/// early pages and a large re-fetchable `event` table filling the later pages,
/// so [_corruptBackHalf] can damage the event region while leaving the local
/// tables readable.
void _createEncryptedDatabaseWithLocalData(String path, String key) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    applyCipherKey(db, key);
    db
      ..execute('PRAGMA user_version = 1;')
      ..execute('CREATE TABLE drafts (id TEXT PRIMARY KEY, title TEXT);')
      ..execute('CREATE TABLE clips (id TEXT PRIMARY KEY, draft_id TEXT);')
      ..execute("INSERT INTO drafts (id, title) VALUES ('d1', 'My draft');")
      ..execute("INSERT INTO drafts (id, title) VALUES ('d2', 'Another');")
      ..execute("INSERT INTO clips (id, draft_id) VALUES ('c1', 'd1');")
      // An unsent DM reaction (gift_wrap_id NULL): only-copy local data whose
      // rumor lives solely here, so salvage must keep it.
      ..execute(
        'CREATE TABLE dm_message_reactions '
        '(id TEXT PRIMARY KEY, gift_wrap_id TEXT, rumor_event_json TEXT);',
      )
      ..execute(
        'INSERT INTO dm_message_reactions (id, gift_wrap_id, rumor_event_json) '
        'VALUES (?, ?, ?);',
        ['r1', null, '{"kind":7}'],
      )
      ..execute('CREATE TABLE event (id TEXT PRIMARY KEY, content TEXT);')
      ..execute('CREATE INDEX idx_event_content ON event (content);');
    for (var i = 0; i < 800; i += 1) {
      db.execute('INSERT INTO event (id, content) VALUES (?, ?);', [
        'e${i.toString().padLeft(6, '0')}',
        'content_${i.toString().padLeft(6, '0')}',
      ]);
    }
  } finally {
    db.close();
  }
}

/// Builds an encrypted DB whose `drafts` table alone spans well past the file
/// midpoint (chunky titles + [draftCount] rows), so [_corruptBackHalf] damages
/// the drafts b-tree itself — the salvageable-table corruption case.
void _createEncryptedDatabaseWithManyDrafts(
  String path,
  String key, {
  required int draftCount,
}) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    applyCipherKey(db, key);
    db
      ..execute('PRAGMA user_version = 1;')
      ..execute('CREATE TABLE drafts (id TEXT PRIMARY KEY, title TEXT);')
      ..execute('CREATE TABLE clips (id TEXT PRIMARY KEY, draft_id TEXT);');
    final title = 'x' * 256;
    for (var i = 0; i < draftCount; i += 1) {
      db.execute('INSERT INTO drafts (id, title) VALUES (?, ?);', [
        'd${i.toString().padLeft(7, '0')}',
        title,
      ]);
    }
  } finally {
    db.close();
  }
}

/// Overwrites the back half of the file so the event pages are damaged while
/// the header, schema, and early `drafts`/`clips` pages stay intact.
void _corruptBackHalf(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  for (var i = bytes.length ~/ 2; i < bytes.length; i += 1) {
    bytes[i] = 0xFF;
  }
  file.writeAsBytesSync(bytes);
}

int _encryptedRowCount(String path, String key, String table) {
  final db = sqlite3.open(path);
  try {
    applyCipherKey(db, key);
    return db.select('SELECT count(*) AS c FROM "$table";').first['c'] as int;
  } finally {
    db.close();
  }
}

/// Creates a plaintext database spanning many small pages so corruption can be
/// injected into a data/index b-tree page while leaving the schema page intact.
void _createMultiPageDatabase(String path) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    db
      ..execute('PRAGMA page_size = 512;')
      ..execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT);')
      ..execute('CREATE INDEX idx_t_v ON t (v);');
    for (var i = 0; i < 500; i += 1) {
      db.execute('INSERT INTO t (v) VALUES (?);', [
        'value_${i.toString().padLeft(6, '0')}',
      ]);
    }
  } finally {
    db.close();
  }
}

/// Overwrites every page after the first two (the schema/root pages) with
/// garbage, corrupting the table and index b-tree pages while keeping the file
/// openable and its schema readable.
void _corruptPagesAfterSchema(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  // page_size is 512, so bytes [0, 1024) cover pages 1-2 (header + schema).
  for (var i = 1024; i < bytes.length; i += 1) {
    bytes[i] = 0xFF;
  }
  file.writeAsBytesSync(bytes);
}

/// Overwrites page 1 from the end of the 100-byte file header onwards, leaving
/// the `SQLite format 3` magic (and the page size it declares) intact.
///
/// The magic is what SQLite checks before reporting `SQLITE_NOTADB`, so keeping
/// it forces the damage to surface as `SQLITE_CORRUPT` instead — the case that
/// the keyless classification cannot label. Byte 100 is the b-tree page type;
/// `0xFF` is not one of the four legal values.
void _corruptSchemaPageKeepingHeader(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  final pageSize = (bytes[16] << 8) | bytes[17];
  for (var i = 100; i < pageSize; i += 1) {
    bytes[i] = 0xFF;
  }
  file.writeAsBytesSync(bytes);
}

void _createSqliteDatabase(
  String path, {
  int draftCount = 0,
  int eventCount = 0,
  List<String> pendingUploadStatuses = const [],
  List<String> pendingActionStatuses = const [],
}) {
  File(path).parent.createSync(recursive: true);
  final db = sqlite3.open(path);
  try {
    db.execute('CREATE TABLE drafts (id TEXT PRIMARY KEY)');
    for (var i = 0; i < draftCount; i += 1) {
      db.execute('INSERT INTO drafts (id) VALUES (?)', ['draft_$i']);
    }

    db.execute('CREATE TABLE event (id TEXT PRIMARY KEY)');
    for (var i = 0; i < eventCount; i += 1) {
      db.execute('INSERT INTO event (id) VALUES (?)', ['event_$i']);
    }

    db.execute('''
      CREATE TABLE pending_uploads (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL
      )
    ''');
    for (var i = 0; i < pendingUploadStatuses.length; i += 1) {
      db.execute('INSERT INTO pending_uploads (id, status) VALUES (?, ?)', [
        'upload_$i',
        pendingUploadStatuses[i],
      ]);
    }

    db.execute('''
      CREATE TABLE pending_actions (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL
      )
    ''');
    for (var i = 0; i < pendingActionStatuses.length; i += 1) {
      db.execute('INSERT INTO pending_actions (id, status) VALUES (?, ?)', [
        'action_$i',
        pendingActionStatuses[i],
      ]);
    }
  } finally {
    db.close();
  }
}

int _draftCount(String path) {
  final db = sqlite3.open(path);
  try {
    return _draftCountFromOpenDb(db);
  } finally {
    db.close();
  }
}

int _draftCountFromOpenDb(Database db) =>
    db.select('SELECT COUNT(*) AS count FROM drafts').first['count'] as int;

int _eventCount(String path) {
  final db = sqlite3.open(path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM event').first['count']
        as int;
  } finally {
    db.close();
  }
}

int _pendingUploadCount(String path) => _tableCount(path, 'pending_uploads');

int _pendingActionCount(String path) => _tableCount(path, 'pending_actions');

int _tableCount(String path, String table) {
  final db = sqlite3.open(path);
  try {
    return db.select('SELECT COUNT(*) AS count FROM $table').first['count']
        as int;
  } finally {
    db.close();
  }
}

String _destinationBackupPath(String path) =>
    '$path.pre_legacy_migration_backup';

String _legacyConflictBackupPath(String path) => '$path.legacy_conflict_backup';
