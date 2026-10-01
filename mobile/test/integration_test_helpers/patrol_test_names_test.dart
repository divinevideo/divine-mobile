// ABOUTME: Keeps Patrol group and test names runnable on Android, where the
// ABOUTME: test orchestrator turns each full name into a file name and JUnit id.
//
// On Android every Patrol test runs through AndroidTestOrchestrator as
// `MainActivityTest#runDartTest[<group> <test>]`. A "/" in that name crashes
// the orchestrator ("File ... contains a path separator") before any test
// runs, so the whole `patrol test` invocation reports `Total: 0`. A "#" is read
// as the class/method separator and truncates the name, so tests that share
// the text before it collapse into one result.
// Neither shows up on iOS or in `flutter test`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A string literal in either quote style: a name that contains an
/// apostrophe is written in double quotes.
const _quotedLiteral = r'''(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''';

/// The leading string literal(s) of a `group(` or `patrolTest(` call.
final _namedCall = RegExp(
  '\\b(group|patrolTest)\\(\\s*((?:$_quotedLiteral\\s*)+)',
);
final _literal = RegExp(_quotedLiteral);

void main() {
  group('Patrol suite names', () {
    test(
      'contain no "/" or "#", which break the Android test orchestrator',
      () {
        final patrolSuites = Directory('integration_test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .where((file) => file.readAsStringSync().contains('patrolTest('))
            .toList();
        expect(patrolSuites, isNotEmpty, reason: 'no Patrol suites were found');

        final offenders = <String>[];
        for (final suite in patrolSuites) {
          final source = suite.readAsStringSync();
          for (final call in _namedCall.allMatches(source)) {
            final name = _literal
                .allMatches(call.group(2)!)
                .map((literal) => literal.group(1) ?? literal.group(2))
                .join();
            if (name.contains('/') || name.contains('#')) {
              offenders.add('${suite.path}: ${call.group(1)}($name)');
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason:
              'Rename these: "/" crashes the Android test orchestrator and "#" '
              'truncates the test id (see the header of this file).',
        );
      },
    );
  });
}
