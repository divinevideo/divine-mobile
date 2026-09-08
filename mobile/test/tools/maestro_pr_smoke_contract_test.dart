// ABOUTME: Pins the small, deterministic Maestro suite used on pull requests.
// ABOUTME: Prevents broad regression flows or credential dependencies entering the gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Maestro flow path the smoke command may name, in invocation order.
final _flowInvocation = RegExp(r'e2e/maestro/\S+\.yaml');

void main() {
  group('Maestro PR smoke contract', () {
    late String codemagic;
    late String smokeCommand;
    late String iosWorkflow;

    /// Slices [source] between two anchors, failing on the anchor rather than
    /// on a `substring` range error when one of them moves.
    String sliceBetween(String source, String start, String end) {
      final from = source.indexOf(start);
      final to = source.indexOf(end);
      expect(from, isNonNegative, reason: 'codemagic.yaml lost anchor $start');
      expect(to, greaterThan(from), reason: 'codemagic.yaml lost anchor $end');
      return source.substring(from, to);
    }

    setUpAll(() {
      codemagic = File('../codemagic.yaml').readAsStringSync();
      smokeCommand = sliceBetween(
        codemagic,
        r'maestro "$@" test',
        'test_report: report.xml',
      );
      iosWorkflow = sliceBetween(
        codemagic,
        '  e2e-smoke-ios:',
        '  e2e-smoke-android:',
      );
    });

    test('runs only the three PR journeys and teardown, in order', () {
      // Ordered equality, not a presence loop: the lane's value is that it is
      // bounded, so a regression flow appended to the command has to fail here.
      expect(
        _flowInvocation
            .allMatches(smokeCommand)
            .map((match) => match.group(0))
            .toList(),
        equals(const [
          'e2e/maestro/tests/prLaunchReady.yaml',
          'e2e/maestro/tests/prAuthenticateHome.yaml',
          'e2e/maestro/tests/prSeededVideoPlayback.yaml',
          'e2e/maestro/tests/removeKeys.yaml',
        ]),
      );
    });

    test('keeps the PR workflow bounded and docs-aware', () {
      expect(iosWorkflow, contains('max_build_duration: 18'));
      expect(iosWorkflow, contains('- mobile/**/*.md'));
      expect(iosWorkflow, contains('cancel_previous_builds: true'));
    });

    test('uses a public fixture id instead of account credentials', () {
      expect(smokeCommand, contains('-e QA_VIDEO_EVENT_ID='));
      expect(smokeCommand, isNot(contains('USER_EMAIL')));
      expect(smokeCommand, isNot(contains('USER_PWD')));
      expect(smokeCommand, isNot(contains('USER_KEYS')));
    });
  });
}
