// ABOUTME: Exercises worker-backed import of a synthetic legacy SQLite file.

@TestOn('browser')
library;

import 'dart:convert';

// ignore: implementation_imports
import 'package:db_client/src/database/connection/connection_web.dart';
import 'package:drift/drift.dart'
    show OpeningDetails, QueryExecutor, QueryExecutorUser;
import 'package:sqlite3/wasm.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('web database upgrade', () {
    test(
      'migrates a local row, clears the snapshot and persists the row',
      () async {
        final assetBase = Uri.base.resolve('../web/');
        const dataKey = 'moor_db_str_divine_db';
        const versionKey = 'moor_db_version_divine_db';
        final storage = web.window.localStorage;
        final wasm = await WasmSqlite3.loadFromUrl(
          assetBase.resolve('sqlite3.wasm'),
        );
        final fs = InMemoryFileSystem();
        wasm.registerVirtualFileSystem(fs, makeDefault: true);

        const path = '/legacy';
        final legacy = wasm.open(path);
        try {
          legacy
            ..execute('CREATE TABLE drafts (body TEXT NOT NULL)')
            ..execute("INSERT INTO drafts VALUES ('offline draft')");
        } finally {
          legacy.close();
        }
        storage
          ..setItem(dataKey, latin1.decode(fs.fileData[path]!))
          ..setItem(versionKey, '35');

        final imported = openConnection(assetBase: assetBase);
        try {
          final user = _FixtureSchema();
          expect(await imported.ensureOpen(user), isTrue);
          expect(user.previousVersion, 35);
          expect(
            await imported.runSelect('SELECT * FROM drafts', const []),
            [
              {'body': 'offline draft', 'status': 'queued'},
            ],
          );
          expect(await imported.runSelect('PRAGMA user_version', const []), [
            {'user_version': 36},
          ]);
          expect(storage.getItem(dataKey), isNull);
          expect(storage.getItem(versionKey), isNull);
        } finally {
          await imported.close();
        }

        final reopened = openConnection(assetBase: assetBase);
        try {
          expect(await reopened.ensureOpen(_FixtureSchema()), isTrue);
          expect(
            await reopened.runSelect('SELECT body FROM drafts', const []),
            [
              {'body': 'offline draft'},
            ],
          );
        } finally {
          await reopened.close();
        }
      },
    );
  });
}

class _FixtureSchema implements QueryExecutorUser {
  int? previousVersion;

  @override
  int get schemaVersion => 36;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {
    previousVersion = details.versionBefore;
    if (details.hadUpgrade) {
      await executor.runCustom(
        "ALTER TABLE drafts ADD COLUMN status TEXT NOT NULL DEFAULT 'queued'",
        const [],
      );
    }
  }
}
