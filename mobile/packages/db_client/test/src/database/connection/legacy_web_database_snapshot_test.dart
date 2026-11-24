// ABOUTME: Verifies legacy version metadata and SQLite bytes survive import.

import 'dart:convert';
import 'dart:io';

import 'package:db_client/src/database/connection/legacy_web_database_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group('decodeLegacyWebDatabaseSnapshot', () {
    late Directory directory;
    late File databaseFile;

    setUp(() {
      directory = Directory.systemTemp.createTempSync('legacy-web-db-');
      databaseFile = File('${directory.path}/legacy.sqlite');
      final db = sqlite3.open(databaseFile.path);
      try {
        db
          ..execute('PRAGMA user_version = 5')
          ..execute('CREATE TABLE outbox (body BLOB NOT NULL)')
          ..execute("INSERT INTO outbox VALUES (X'0080FF')");
      } finally {
        db.close();
      }
    });

    tearDown(() => directory.deleteSync(recursive: true));

    test('restores the authoritative external version and preserves rows', () {
      final snapshot = latin1.decode(databaseFile.readAsBytesSync());
      databaseFile.writeAsBytesSync(
        decodeLegacyWebDatabaseSnapshot(snapshot, '37'),
      );
      final imported = sqlite3.open(databaseFile.path);
      try {
        expect(imported.userVersion, 37);
        expect(
          imported
              .select('SELECT hex(body) AS body FROM outbox')
              .single['body'],
          '0080FF',
        );
      } finally {
        imported.close();
      }
    });

    test('leaves the embedded version intact without external metadata', () {
      final bytes = databaseFile.readAsBytesSync();
      expect(
        decodeLegacyWebDatabaseSnapshot(latin1.decode(bytes), null),
        bytes,
      );
    });
  });
}
