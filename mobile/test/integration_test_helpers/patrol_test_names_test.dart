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
//
// Names are read from source, so they must be plain string literals. A name
// built from a variable or an interpolation is only known at runtime, and this
// guard fails it rather than let it pass unchecked.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A string literal in either quote style: a name that contains an
/// apostrophe is written in double quotes.
const _quotedLiteral = r'''(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)")''';

/// The start of a `group(` or `patrolTest(` call, up to its first argument.
final _callStart = RegExp(r'\b(group|patrolTest)\(\s*');

/// One or more adjacent string literals.
final _literalRun = RegExp('(?:$_quotedLiteral\\s*)+');

final _literal = RegExp(_quotedLiteral);

/// What may follow a name for it to be the whole first argument.
final _argumentEnd = RegExp(r'\s*[,)]');

/// A `$` behind an even number of backslashes, which starts an interpolation.
final _interpolation = RegExp(r'(?<!\\)(?:\\\\)*\$');

typedef _NamedCall = ({String location, String function, String? name});

/// Every `group(` and `patrolTest(` call in the Patrol suites.
///
/// `name` is null when the first argument is anything but adjacent plain
/// string literals: a variable, an interpolation, a raw string, or a literal
/// with an operator or method call after it.
List<_NamedCall> _patrolSuiteCalls() {
  final calls = <_NamedCall>[];
  final suites = Directory('integration_test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
  for (final suite in suites) {
    final source = suite.readAsStringSync();
    if (!source.contains('patrolTest(')) continue;
    for (final call in _callStart.allMatches(source)) {
      final run = _literalRun.matchAsPrefix(source, call.end);
      final literals = [
        if (run != null)
          for (final literal in _literal.allMatches(run.group(0)!))
            literal.group(1) ?? literal.group(2)!,
      ];
      final readable =
          run != null &&
          _argumentEnd.matchAsPrefix(source, run.end) != null &&
          !literals.any(_interpolation.hasMatch);
      final line = source.substring(0, call.start).split('\n').length;
      calls.add((
        location: '${suite.path}:$line',
        function: call.group(1)!,
        name: readable ? literals.join() : null,
      ));
    }
  }
  return calls;
}

void main() {
  group('Patrol suite names', () {
    test('are plain string literals, which this guard can read', () {
      final calls = _patrolSuiteCalls();
      expect(calls, isNotEmpty, reason: 'no Patrol suites were found');

      final unreadable = [
        for (final call in calls)
          if (call.name == null) '${call.location}: ${call.function}(...)',
      ];
      expect(
        unreadable,
        isEmpty,
        reason:
            'Write these names as plain string literals, with no variable, '
            'interpolation or concatenation, so they can be checked for "/" '
            'and "#".',
      );
    });

    test(
      'contain no "/" or "#", which break the Android test orchestrator',
      () {
        final calls = _patrolSuiteCalls();
        expect(calls, isNotEmpty, reason: 'no Patrol suites were found');

        final offenders = [
          for (final call in calls)
            if (call.name case final name?
                when name.contains('/') || name.contains('#'))
              '${call.location}: ${call.function}($name)',
        ];
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
