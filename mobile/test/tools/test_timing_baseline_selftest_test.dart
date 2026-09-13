// ABOUTME: Runs test_timing_baseline.sh's Very Good CLI resolver self-test.
// ABOUTME: Keeps pub-cache-only executable resolution aligned with execution.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timing baseline preserves a pub-cache-only Very Good executable', () {
    final result = Process.runSync('bash', [
      'scripts/test_timing_baseline.sh',
      '--selftest',
    ], workingDirectory: Directory.current.path);

    expect(
      result.exitCode,
      0,
      reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}',
    );
    expect(
      result.stdout,
      contains(
        'SELFTEST PASS: pub-cache-only executable is preserved for execution.',
      ),
    );
  });
}
