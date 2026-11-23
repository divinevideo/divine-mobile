// ABOUTME: Guards web/index.html details the web build relies on: no sql.js or
// ABOUTME: font CSS, the main.dart.js preload, the crypto module, pointer CSS.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web index bootstrap and worker assets', () {
    late String index;

    setUp(() {
      index = File('web/index.html').readAsStringSync();
    });

    test('does not load sql.js', () {
      expect(index, isNot(contains('sql-wasm.js')));
      expect(index, isNot(contains('initSqlJs')));
    });

    test('does not load render-blocking Google Fonts stylesheets', () {
      expect(index, isNot(contains('fonts.googleapis.com')));
    });

    test('preloads main.dart.js as a script', () {
      expect(
        index,
        contains('<link rel="preload" href="main.dart.js" as="script">'),
      );
    });

    test('runs nostr_crypto.js as a module script', () {
      // The modulepreload link only fetches the module; this tag runs it.
      expect(
        index,
        contains('<script type="module" src="nostr_crypto.js"></script>'),
      );
    });

    test('keeps every platform view transparent to pointer events', () {
      // Navigation over video relies on this rule, not on PointerInterceptor.
      expect(
        index,
        matches(
          RegExp(
            r'video,\s*flt-platform-view,\s*flt-platform-view-slot\s*\{\s*'
            r'pointer-events:\s*none;',
          ),
        ),
      );
    });

    test('ships the Drift web worker assets', () {
      expect(File('web/sqlite3.wasm').existsSync(), isTrue);
      expect(File('web/drift_worker.js').existsSync(), isTrue);
    });
  });
}
