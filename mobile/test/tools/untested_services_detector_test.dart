// ABOUTME: Pins split-suite recognition for the untested-services floor.
// ABOUTME: Rejects filename-only matches that do not import the service.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/.
import '../../scripts/lib/untested_services_detector.dart';

void main() {
  group('findUntestedServices', () {
    late Directory root;
    late Directory services;
    late Directory tests;

    setUp(() {
      root = Directory.systemTemp.createTempSync('untested-services-');
      services = Directory('${root.path}/lib/services')
        ..createSync(recursive: true);
      tests = Directory('${root.path}/test')..createSync(recursive: true);
    });

    tearDown(() => root.deleteSync(recursive: true));

    void writeService(String name) {
      File('${services.path}/$name.dart').writeAsStringSync('class Subject {}');
    }

    void writeTest(String name, String source) {
      File('${tests.path}/${name}_test.dart').writeAsStringSync(source);
    }

    test('accepts an exact-name test', () {
      writeService('account_service');
      writeTest('account_service', 'void main() {}');

      expect(findUntestedServices(services, tests), isEmpty);
    });

    test('accepts a split suite that directly imports the service', () {
      writeService('account_service');
      writeTest(
        'account_service_cache',
        "import 'package:openvine/services/account_service.dart';",
      );

      expect(findUntestedServices(services, tests), isEmpty);
    });

    test('accepts a split suite that imports a nested service', () {
      Directory('${services.path}/auth').createSync();
      File(
        '${services.path}/auth/nostr_identity.dart',
      ).writeAsStringSync('class Subject {}');
      writeTest(
        'nostr_identity_keycast',
        "import 'package:openvine/services/auth/nostr_identity.dart';",
      );

      expect(findUntestedServices(services, tests), isEmpty);
    });

    test('rejects a filename-only prefix match', () {
      writeService('account_service');
      writeTest('account_service_helper', 'void main() {}');

      expect(findUntestedServices(services, tests), ['account_service']);
    });

    test('rejects a prefix match that only imports a sibling service', () {
      writeService('account_service');
      writeService('account_service_helper');
      writeTest(
        'account_service_sync',
        "import 'package:openvine/services/account_service_helper.dart';",
      );

      expect(
        findUntestedServices(services, tests),
        ['account_service', 'account_service_helper'],
      );
    });

    test('ignores generated service files', () {
      writeService('account_service');
      File('${services.path}/generated.g.dart').writeAsStringSync('');
      File('${services.path}/generated.freezed.dart').writeAsStringSync('');

      expect(findUntestedServices(services, tests), ['account_service']);
    });
  });
}
