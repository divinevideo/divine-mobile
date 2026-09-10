// ABOUTME: Parses the marker-delimited service-suite arrays from the CI workflow.
// ABOUTME: Gives coverage and dependency-scope guards one fail-closed interpretation.

import 'dart:io';

const _startMarker = 'SERVICE_SUITE_LIST_START';
const _endMarker = 'SERVICE_SUITE_LIST_END';
final _arrayStart = RegExp(r'^([A-Za-z_][A-Za-z0-9_]*)=\($');
final _suiteEntry = RegExp(
  r'^integration_test/e2e/[A-Za-z0-9_./-]+_test\.dart$',
);

Map<String, List<String>> parseServiceSuiteWorkflow(String source) {
  final lines = source.split('\n');
  final starts = <int>[];
  final ends = <int>[];
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].contains(_startMarker)) starts.add(index);
    if (lines[index].contains(_endMarker)) ends.add(index);
  }
  if (starts.length != 1 || ends.length != 1 || starts.single >= ends.single) {
    throw const FormatException(
      'workflow must contain exactly one service-suite list marker pair',
    );
  }

  final arrays = <String, List<String>>{};
  String? current;
  for (var index = starts.single + 1; index < ends.single; index++) {
    final line = lines[index].trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (current == null) {
      final match = _arrayStart.firstMatch(line);
      if (match == null) {
        throw FormatException(
          'Unexpected line ${index + 1} between the suite-list markers: $line',
        );
      }
      final arrayName = match.group(1);
      if (arrayName == null) {
        throw StateError('suite array parser did not capture a name');
      }
      current = arrayName;
      if (arrays.containsKey(current)) {
        throw FormatException('duplicate suite array: $current');
      }
      arrays[current] = <String>[];
      continue;
    }
    if (line == ')') {
      current = null;
      continue;
    }
    if (!_suiteEntry.hasMatch(line)) {
      throw FormatException(
        'unrecognized entry on workflow line ${index + 1}: $line',
      );
    }
    arrays[current]!.add(line);
  }
  if (current != null) {
    throw FormatException('unterminated suite array: $current');
  }
  return arrays;
}

void main(List<String> arguments) {
  String? workflowPath;
  var mode = 'all';
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--workflow':
        if (++index >= arguments.length) _usage();
        workflowPath = arguments[index];
      case '--focused':
        mode = 'focused';
      case '--all':
        mode = 'all';
      default:
        _usage('unknown argument: ${arguments[index]}');
    }
  }
  if (workflowPath == null) _usage('--workflow is required');

  try {
    final arrays = parseServiceSuiteWorkflow(
      File(workflowPath).readAsStringSync(),
    );
    final focused = arrays['focused_suites'];
    if (mode == 'focused' && (focused == null || focused.isEmpty)) {
      throw const FormatException('focused_suites must exist and not be empty');
    }
    final selected = mode == 'focused'
        ? focused!
        : arrays.values.expand((entries) => entries);
    selected.forEach(stdout.writeln);
  } on FileSystemException catch (error) {
    stderr.writeln('service-suite workflow read failed: ${error.message}');
    exitCode = 1;
  } on FormatException catch (error) {
    stderr.writeln('service-suite workflow parse failed: ${error.message}');
    exitCode = 1;
  }
}

Never _usage([String? message]) {
  if (message != null) stderr.writeln(message);
  stderr.writeln(
    'usage: dart run service_suite_workflow_parser.dart '
    '--workflow <path> [--focused|--all]',
  );
  exit(64);
}
