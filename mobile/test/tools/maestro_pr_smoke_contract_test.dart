// ABOUTME: Pins the small, deterministic Maestro suite used on pull requests.
// ABOUTME: Prevents broad regression flows or credential dependencies entering the gate.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Maestro flow path the smoke command may name, in invocation order.
final _flowInvocation = RegExp(r'e2e/maestro/\S+\.yaml');

/// The fixture id as a workflow assigns it, so a prose mention of the name in
/// a comment is not mistaken for a definition.
final _fixtureAssignment = RegExp(
  r'^\s*QA_VIDEO_EVENT_ID:\s*(\S+)',
  multiLine: true,
);

/// A bare 32-byte Nostr event id — the only shape this variable may carry.
final _eventId = RegExp(r'^[0-9a-f]{64}$');

void main() {
  group('Maestro PR smoke contract', () {
    late String codemagic;
    late String smokeCommand;
    late String iosWorkflow;
    late String androidWorkflow;

    /// Slices [source] between two anchors, failing on the anchor rather than
    /// on a `substring` range error when one of them moves.
    String sliceBetween(String source, String start, String end) {
      final from = source.indexOf(start);
      final to = source.indexOf(end);
      expect(from, isNonNegative, reason: 'codemagic.yaml lost anchor $start');
      expect(to, greaterThan(from), reason: 'codemagic.yaml lost anchor $end');
      return source.substring(from, to);
    }

    /// Slices [source] from [start] to end of file, for the last workflow in
    /// the document, which has no following anchor to stop at.
    String sliceFrom(String source, String start) {
      final from = source.indexOf(start);
      expect(from, isNonNegative, reason: 'codemagic.yaml lost anchor $start');
      return source.substring(from);
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
      androidWorkflow = sliceFrom(codemagic, '  e2e-smoke-android:');
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
      expect(iosWorkflow, contains('max_build_duration: 25'));
      expect(iosWorkflow, contains('- mobile/**/*.md'));
      expect(iosWorkflow, contains('cancel_previous_builds: true'));
    });

    test('uses a public fixture id instead of account credentials', () {
      expect(smokeCommand, contains('-e QA_VIDEO_EVENT_ID='));
      expect(smokeCommand, isNot(contains('USER_EMAIL')));
      expect(smokeCommand, isNot(contains('USER_PWD')));
      expect(smokeCommand, isNot(contains('USER_KEYS')));
    });

    test('gives every workflow on the shared script the same fixture id', () {
      // The smoke command is a YAML anchor, so iOS and Android both inherit
      // `-e QA_VIDEO_EVENT_ID`. A workflow that runs it without defining the
      // variable passes an empty string — the script has `set -e` but no
      // `set -u`, so nothing fails until prSeededVideoPlayback's own guard.
      for (final workflow in {
        'e2e-smoke-ios': iosWorkflow,
        'e2e-smoke-android': androidWorkflow,
      }.entries) {
        expect(
          workflow.value,
          contains('- *run_maestro_smoke_tests'),
          reason:
              '${workflow.key} no longer runs the shared smoke command; '
              'drop it from this test if that is intended',
        );
        final assigned = _fixtureAssignment
            .firstMatch(workflow.value)
            ?.group(1);
        expect(
          assigned,
          isNotNull,
          reason:
              '${workflow.key} runs the shared smoke command but defines '
              'no QA_VIDEO_EVENT_ID',
        );
        expect(
          assigned,
          matches(_eventId),
          reason:
              '${workflow.key} must carry a bare public event id, never a '
              'credential or a secret reference',
        );
      }

      // Pinned as equal rather than as a literal: the two lanes must prove the
      // same fixture, and duplicating the hex is what lets them drift apart.
      expect(
        _fixtureAssignment.firstMatch(androidWorkflow)!.group(1),
        equals(_fixtureAssignment.firstMatch(iosWorkflow)!.group(1)),
      );
    });
  });
}
