// ABOUTME: Pins the CI guard for Divine's vendored LibProofMode privacy patch.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LibProofMode network privacy guard', () {
    late Directory temporaryDirectory;
    late String scriptPath;

    setUp(() {
      temporaryDirectory = Directory.systemTemp.createTempSync(
        'libproofmode_network_privacy_',
      );
      scriptPath = File(
        'scripts/check_libproofmode_network_privacy.py',
      ).absolute.path;
    });

    tearDown(() {
      temporaryDirectory.deleteSync(recursive: true);
    });

    Future<ProcessResult> runGuard(String buildProofBody) {
      final source = File('${temporaryDirectory.path}/Proof.swift')
        ..writeAsStringSync('''
open class Proof {
  private func buildProof() -> ProofCollection {
$buildProofBody
  }
}
''');
      return Process.run('python3', [scriptPath, source.path]);
    }

    const assignments = '''
      proof[.ipv4] = value
      proof[.ipv6] = value
      proof[.dataType] = value
      proof[.network] = value
      proof[.networkType] = value
''';

    test('passes when every sensitive assignment is inside the gate', () async {
      final result = await runGuard('''
    if showMobileNetwork {
$assignments
    }
''');

      expect(result.exitCode, 0, reason: result.stderr as String?);
    });

    test('fails when a sensitive assignment moves outside the gate', () async {
      final result = await runGuard('''
    proof[.ipv4] = value
    if showMobileNetwork {
      proof[.ipv6] = value
      proof[.dataType] = value
      proof[.network] = value
      proof[.networkType] = value
    }
''');

      expect(result.exitCode, isNot(0));
      expect(
        result.stdout,
        contains('proof[.ipv4] = must stay inside the showMobileNetwork gate'),
      );
    });

    test('fails closed when a sensitive assignment disappears', () async {
      final result = await runGuard('''
    if showMobileNetwork {
      proof[.ipv4] = value
      proof[.ipv6] = value
      proof[.dataType] = value
      proof[.network] = value
    }
''');

      expect(result.exitCode, isNot(0));
      expect(
        result.stdout,
        contains('proof[.networkType] = must appear exactly once'),
      );
    });
  });
}
