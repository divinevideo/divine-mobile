// ABOUTME: Tests for mobile/scripts/ios_store_version_preflight.rb, the iOS
// ABOUTME: Shorebird release version guard. Pins that only released/approved
// ABOUTME: App Store versions block a candidate, not TestFlight-only ones.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs the preflight script against a JSON fixture of App Store versions.
///
/// The script is what the Codemagic `Preflight iOS Shorebird release` step
/// invokes with the output of `app-store-connect apps app-store-versions
/// --json`. It must refuse a candidate that is not newer than the highest
/// *released* App Store version, while allowing a version that only ever
/// reached TestFlight or is still in review to be reused.
void main() {
  group('ios_store_version_preflight.rb', () {
    late Directory sandbox;
    late String scriptPath;
    late int fixtureIndex;

    String writeFixture(List<Map<String, Object?>> versions) {
      final file = File(p.join(sandbox.path, 'versions_${fixtureIndex++}.json'))
        ..writeAsStringSync(jsonEncode(versions));
      return file.path;
    }

    Map<String, Object?> version(
      String versionString, {
      String? state,
      bool legacyState = false,
      bool includeAttributes = true,
    }) {
      return {
        'type': 'appStoreVersions',
        'id': 'version-$versionString',
        if (includeAttributes)
          'attributes': {
            'versionString': versionString,
            if (state != null)
              if (legacyState)
                'appStoreState': state
              else
                'appVersionState': state,
          },
      };
    }

    ProcessResult run(List<Map<String, Object?>> versions, String candidate) {
      return Process.runSync('ruby', [
        scriptPath,
        writeFixture(versions),
        candidate,
      ]);
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('ios_store_version_');
      fixtureIndex = 0;
      final realScript = File(
        p.join(
          Directory.current.path,
          'scripts/ios_store_version_preflight.rb',
        ),
      );
      expect(
        realScript.existsSync(),
        isTrue,
        reason: 'mobile/scripts/ios_store_version_preflight.rb must exist',
      );
      scriptPath = realScript.path;
    });

    tearDown(() {
      sandbox.deleteSync(recursive: true);
    });

    group('released versions', () {
      test('accepts a candidate newer than the released version', () {
        final result = run([
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          contains('newer than released App Store version 1.0.22'),
        );
      });

      test('rejects a candidate equal to the released version', () {
        final result = run([
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.22');

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr,
          contains('must be newer than released App Store version 1.0.22'),
        );
      });

      test('rejects a candidate older than the released version', () {
        final result = run([
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.21');

        expect(result.exitCode, isNot(0));
        expect(
          result.stderr,
          contains('must be newer than released App Store version 1.0.22'),
        );
      });

      test('uses the highest released version when several are listed', () {
        final result = run([
          version('1.0.20', state: 'READY_FOR_DISTRIBUTION'),
          version('1.0.22', state: 'REPLACED_WITH_NEW_VERSION'),
          version('1.0.21', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.22');

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('released App Store version 1.0.22'));
      });

      test('recognises the deprecated appStoreState field', () {
        final result = run([
          version('1.0.22', state: 'READY_FOR_SALE', legacyState: true),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          contains('newer than released App Store version 1.0.22'),
        );
      });
    });

    group('unreleased versions', () {
      test('allows a candidate that only reached TestFlight', () {
        final result = run([
          version('1.0.23', state: 'PREPARE_FOR_SUBMISSION'),
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          contains('newer than released App Store version 1.0.22'),
        );
      });

      test('allows a candidate that is still in review', () {
        final result = run([
          version('1.0.23', state: 'WAITING_FOR_REVIEW'),
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
      });

      test('allows a candidate with no released version at all', () {
        final result = run([
          version('1.0.23', state: 'PREPARE_FOR_SUBMISSION'),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(result.stdout, contains('first release on this train'));
      });

      test(
        'rejects a candidate equal to an approved but unreleased version',
        () {
          final result = run([
            version('1.0.23', state: 'PENDING_DEVELOPER_RELEASE'),
            version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
          ], '1.0.23');

          expect(result.exitCode, isNot(0));
          expect(
            result.stderr,
            contains('must be newer than released App Store version 1.0.23'),
          );
        },
      );
    });

    group('malformed input', () {
      test('rejects a payload that is not an array', () {
        final file = File(p.join(sandbox.path, 'object.json'))
          ..writeAsStringSync(jsonEncode({'version': '1.0.22'}));

        final result = Process.runSync('ruby', [
          scriptPath,
          file.path,
          '1.0.23',
        ]);

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('expected a JSON array'));
      });

      test('rejects a candidate with an unparseable version', () {
        final result = run([
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.23-beta');

        expect(result.exitCode, isNot(0));
        expect(result.stderr, contains('invalid candidate version'));
      });

      test('skips entries without readable attributes', () {
        final result = run([
          version('1.0.23', includeAttributes: false),
          version('1.0.22', state: 'READY_FOR_DISTRIBUTION'),
        ], '1.0.23');

        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(
          result.stdout,
          contains('newer than released App Store version 1.0.22'),
        );
      });
    });
  });
}
