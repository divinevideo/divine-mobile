// ABOUTME: Pins the web sqlite3.wasm URL to the version in pubspec.lock, and
// ABOUTME: keeps the drift worker URL fixed so every tab shares one worker.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _connections = {
  'db_client':
      'packages/db_client/lib/src/database/connection/connection_web.dart',
  'cache_sync': 'packages/cache_sync/lib/src/connection/connection_web.dart',
};

String _lockedVersion(String package) {
  final lock = File('pubspec.lock').readAsStringSync();
  final match = RegExp(
    '^  $package:\\n(?:    .*\\n)*?    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lock);
  if (match == null) fail('$package is not in pubspec.lock');
  return match.group(1)!;
}

void main() {
  group('web SQLite asset URLs', () {
    for (final MapEntry(key: name, value: path) in _connections.entries) {
      // web/_headers caches *.wasm for a year, so a stale copy is only skipped
      // when the URL changes with the version.
      test('$name requests sqlite3.wasm at the locked sqlite3 version', () {
        final source = File(path).readAsStringSync();

        expect(
          source,
          contains("'sqlite3.wasm?v=${_lockedVersion('sqlite3')}'"),
        );
        expect(source, isNot(contains("'sqlite3.wasm'")));
      });

      // A versioned worker URL would start a second shared worker during a
      // deploy, and two workers writing one IndexedDB database can corrupt it.
      test('$name keeps the drift_worker.js URL unversioned', () {
        final source = File(path).readAsStringSync();

        expect(source, contains("'drift_worker.js'"));
        expect(source, isNot(contains('drift_worker.js?v=')));
      });
    }
  });
}
