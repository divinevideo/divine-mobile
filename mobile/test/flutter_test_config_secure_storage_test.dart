// ABOUTME: Guards the secure-storage reset in flutter_test_config.dart.
// ABOUTME: Without it, values one suite stores leak into later merged suites.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _key = 'keycast_session';

void main() {
  group('shared secure storage reset', () {
    // The canonical flutter_secure_storage mock keeps one map for the whole
    // merged isolate. A Keycast session an earlier suite stored there once
    // made an ownerless sign-out in a later suite refuse to run. setUpAll
    // runs before the root setUp, so it stands in for that earlier suite.
    setUpAll(() async {
      const storage = FlutterSecureStorage();
      await storage.write(key: _key, value: 'stored by an earlier suite');
      expect(await storage.read(key: _key), 'stored by an earlier suite');
    });

    test('a value stored before the test is gone when it starts', () async {
      expect(await const FlutterSecureStorage().read(key: _key), isNull);
    });
  });
}
