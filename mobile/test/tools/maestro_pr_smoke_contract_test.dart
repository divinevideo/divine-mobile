// ABOUTME: Pins Maestro entry-point tiers and the deterministic PR smoke lane.
// ABOUTME: Prevents supported journeys and their automation policy from drifting.

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

final _flowReference = RegExp(
  r'''(?:runFlow:|file:)\s*["']?([A-Za-z0-9_/&.-]+\.yaml)''',
);

const _tiers = {
  'pr',
  'scheduled',
  'manual-regression',
  'manual-hardware',
};

final class _TierEntry {
  const _TierEntry({
    required this.path,
    required this.tier,
    required this.runners,
    required this.requirements,
    required this.rationale,
  });

  final String path;
  final String tier;
  final List<String> runners;
  final List<String> requirements;
  final String rationale;
}

List<_TierEntry> _parseTierRegistry(String source) {
  final entries = <_TierEntry>[];
  final seenPaths = <String>{};

  for (final (index, rawLine) in source.split('\n').indexed) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    final columns = rawLine.split('\t');
    if (columns.length != 5 || columns.any((column) => column.trim().isEmpty)) {
      throw FormatException(
        'tiers.txt:${index + 1} must contain five non-empty TSV columns',
      );
    }

    final [path, tier, runners, requirements, rationale] = columns;
    if (!_tiers.contains(tier)) {
      throw FormatException('tiers.txt:${index + 1} has unknown tier $tier');
    }
    if (path.startsWith('/') || path.split('/').contains('..')) {
      throw FormatException('tiers.txt:${index + 1} has unsafe path $path');
    }
    if (!seenPaths.add(path)) {
      throw FormatException('tiers.txt:${index + 1} duplicates $path');
    }

    entries.add(
      _TierEntry(
        path: path,
        tier: tier,
        runners: runners.split(','),
        requirements: requirements.split(','),
        rationale: rationale,
      ),
    );
  }

  return entries;
}

bool _existsCaseSensitively(Directory root, String relativePath) {
  var directory = root;
  final segments = relativePath.split('/');

  for (final (index, segment) in segments.indexed) {
    final matches = directory.listSync().where(
      (entity) =>
          entity.uri.pathSegments.lastWhere((part) => part.isNotEmpty) ==
          segment,
    );
    if (matches.length != 1) return false;

    final match = matches.single;
    if (index == segments.length - 1) return match is File;
    if (match is! Directory) return false;
    directory = match;
  }

  return false;
}

Set<String> _graphEntryPoints(Directory maestroDirectory) {
  final candidates = <String>{};
  final referenced = <String>{};

  for (final entity in maestroDirectory.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.yaml')) continue;

    final relativePath = entity.uri.path.substring(
      maestroDirectory.uri.path.length,
    );
    if (const ['tests/', 'flows/', 'suites/'].any(relativePath.startsWith)) {
      candidates.add(relativePath);
    }

    for (final rawLine in entity.readAsLinesSync()) {
      final line = rawLine.split('#').first;
      for (final match in _flowReference.allMatches(line)) {
        final reference = match.group(1)!;
        final resolved = entity.parent.uri.resolve(reference).normalizePath();
        if (resolved.path.startsWith(maestroDirectory.uri.path)) {
          referenced.add(
            resolved.path.substring(maestroDirectory.uri.path.length),
          );
        }
      }
    }
  }

  return candidates.difference(referenced);
}

List<String> _maestroInvocations(String source) => _flowInvocation
    .allMatches(
      source.split('\n').map((line) => line.split('#').first).join('\n'),
    )
    .map((match) => match.group(0)!.replaceFirst('e2e/maestro/', ''))
    .toList();

void main() {
  group('Maestro PR smoke contract', () {
    late String codemagic;
    late String smokeCommand;
    late String iosWorkflow;
    late String androidWorkflow;
    late Directory maestroDirectory;
    late List<_TierEntry> registry;

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
      maestroDirectory = Directory('e2e/maestro').absolute;
      registry = _parseTierRegistry(
        File('e2e/maestro/tiers.txt').readAsStringSync(),
      );
    });

    test('registry covers every supported entry point exactly once', () {
      final invoked = _maestroInvocations(codemagic).toSet();
      final supported = _graphEntryPoints(maestroDirectory)..addAll(invoked);

      expect(
        registry.map((entry) => entry.path).toSet(),
        equals(supported),
      );
    });

    test('registry paths resolve with exact case', () {
      for (final entry in registry) {
        expect(
          _existsCaseSensitively(maestroDirectory, entry.path),
          isTrue,
          reason: '${entry.path} does not resolve case-sensitively',
        );
      }
      expect(
        _existsCaseSensitively(maestroDirectory, 'suites/Smoke.yaml'),
        isFalse,
      );
    });

    test('PR rows exactly match the smoke command in order', () {
      expect(
        _maestroInvocations(smokeCommand),
        equals(
          registry
              .where((entry) => entry.tier == 'pr')
              .map((entry) => entry.path)
              .toList(),
        ),
      );
    });

    test('manual rows have requirements and are absent from CI', () {
      final invoked = _maestroInvocations(codemagic).toSet();
      for (final entry in registry.where(
        (entry) => entry.tier.startsWith('manual-'),
      )) {
        expect(entry.requirements, isNotEmpty, reason: entry.path);
        expect(entry.runners, equals(const ['operator']), reason: entry.path);
        expect(invoked, isNot(contains(entry.path)), reason: entry.path);
      }
    });

    test('automated rows name existing Codemagic workflows', () {
      final invoked = _maestroInvocations(codemagic).toSet();
      for (final entry in registry.where(
        (entry) => entry.tier == 'pr' || entry.tier == 'scheduled',
      )) {
        expect(invoked, contains(entry.path), reason: entry.path);
        for (final runner in entry.runners) {
          expect(runner, startsWith('codemagic:'), reason: entry.path);
          final workflow = runner.substring('codemagic:'.length);
          expect(
            codemagic,
            contains('  $workflow:'),
            reason: '${entry.path} names missing runner $runner',
          );
        }
      }
    });

    test('registry parser rejects malformed policy', () {
      expect(
        () => _parseTierRegistry('tests/example.yaml\tpr\toperator\tsimulator'),
        throwsFormatException,
      );
      expect(
        () => _parseTierRegistry(
          'tests/example.yaml\tunknown\toperator\tsimulator\tReason',
        ),
        throwsFormatException,
      );
      expect(
        () => _parseTierRegistry(
          'tests/example.yaml\tpr\toperator\tsimulator\tReason\n'
          'tests/example.yaml\tpr\toperator\tsimulator\tReason',
        ),
        throwsFormatException,
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
