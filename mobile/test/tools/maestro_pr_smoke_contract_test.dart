// ABOUTME: Pins the small, deterministic Maestro suite used on pull requests.
// ABOUTME: Prevents broad regression flows or credential dependencies entering the gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Maestro PR smoke contract', () {
    late String codemagic;

    setUpAll(() {
      codemagic = File('../codemagic.yaml').readAsStringSync();
    });

    test('runs only the three PR journeys and teardown', () {
      const expected = [
        'prLaunchReady.yaml',
        'prAuthenticateHome.yaml',
        'prSeededVideoPlayback.yaml',
        'removeKeys.yaml',
      ];
      final smokeBlock = codemagic.substring(
        codemagic.indexOf(r'maestro "$@" test'),
        codemagic.indexOf('test_report: report.xml'),
      );

      for (final flow in expected) {
        expect(smokeBlock, contains('e2e/maestro/tests/$flow'));
      }
      expect(smokeBlock, isNot(contains('suites/smoke.yaml')));
      expect(smokeBlock, isNot(contains('fullRegression.yaml')));
    });

    test('keeps the PR workflow bounded and docs-aware', () {
      final workflow = codemagic.substring(
        codemagic.indexOf('  e2e-smoke-ios:'),
        codemagic.indexOf('  e2e-smoke-android:'),
      );

      expect(workflow, contains('max_build_duration: 18'));
      expect(workflow, contains('- mobile/**/*.md'));
      expect(workflow, contains('cancel_previous_builds: true'));
    });

    test('uses a public fixture id instead of account credentials', () {
      final command = codemagic.substring(
        codemagic.indexOf(r'maestro "$@" test'),
        codemagic.indexOf('test_report: report.xml'),
      );

      expect(command, contains('-e QA_VIDEO_EVENT_ID='));
      expect(command, isNot(contains('USER_EMAIL')));
      expect(command, isNot(contains('USER_PWD')));
      expect(command, isNot(contains('USER_KEYS')));
    });
  });
}
