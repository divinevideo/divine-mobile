import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('web index bootstrap and worker assets', () {
    test(
      'uses local Drift Wasm worker assets without blocking sql.js or font CSS',
      () {
        final contents = File('web/index.html').readAsStringSync();

        expect(contents, isNot(contains('sql-wasm.js')));
        expect(contents, isNot(contains('initSqlJs')));
        expect(contents, isNot(contains('fonts.googleapis.com')));
        expect(contents, contains('rel="preload" href="main.dart.js"'));
        expect(contents, contains('nostr_crypto.js'));
        expect(contents, contains('pointer-events: none'));
        expect(File('web/sqlite3.wasm').existsSync(), isTrue);
        expect(File('web/drift_worker.js').existsSync(), isTrue);
      },
    );
  });
}
