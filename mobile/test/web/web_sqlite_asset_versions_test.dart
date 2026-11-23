// ABOUTME: Pins the web sqlite3.wasm URL to the version in pubspec.lock, and
// ABOUTME: keeps the drift worker URL fixed so every tab shares one worker.

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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

class _AssetUrls extends RecursiveAstVisitor<void> {
  _AssetUrls(this.fileName);

  final String fileName;
  final urls = <String>[];

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    final uri = Uri.tryParse(node.value);
    if (uri?.pathSegments.lastOrNull == fileName) {
      urls.add(node.value);
    }
  }
}

List<String> _assetUrls(String path, String fileName) {
  final source = File(path).readAsStringSync();
  final visitor = _AssetUrls(fileName);
  parseString(content: source, path: path).unit.accept(visitor);
  return visitor.urls;
}

void main() {
  group('web SQLite asset URLs', () {
    for (final MapEntry(key: name, value: path) in _connections.entries) {
      // web/_headers caches *.wasm for a year, so a stale copy is only skipped
      // when the URL changes with the version.
      test('$name requests sqlite3.wasm at the locked sqlite3 version', () {
        expect(
          _assetUrls(path, 'sqlite3.wasm'),
          allOf(
            isNotEmpty,
            everyElement('sqlite3.wasm?v=${_lockedVersion('sqlite3')}'),
          ),
        );
      });

      // A versioned worker URL would start a second shared worker during a
      // deploy, and two workers writing one IndexedDB database can corrupt it.
      test('$name keeps the drift_worker.js URL unversioned', () {
        expect(
          _assetUrls(path, 'drift_worker.js'),
          allOf(isNotEmpty, everyElement('drift_worker.js')),
        );
      });
    }
  });
}
