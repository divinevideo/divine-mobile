// ABOUTME: Regression fixtures for the unsettled scroll interaction guard.
// ABOUTME: Pins ordered helper/branch traversal and scan boundaries (#7278).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts live outside the app library.
import '../../scripts/lib/bare_scroll_interaction_detector.dart';

void main() {
  group('bare_scroll_interaction_detector', () {
    late Directory temp;

    List<BareScrollInteraction> scan(String source) {
      File('${temp.path}/test/subject_test.dart').writeAsStringSync(source);
      return findBareScrollInteractions(temp, pathPrefix: temp.path);
    }

    String testBody(String body) =>
        '''
void main() {
  testWidgets('subject', (tester) async {
    $body
  });
}
''';

    setUp(() {
      temp = Directory.systemTemp.createTempSync('bare_scroll_test');
      Directory('${temp.path}/test').createSync(recursive: true);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    group('pending layout', () {
      for (final method in [
        'tap',
        'tapAt',
        'tapOnText',
        'longPress',
        'longPressAt',
        'press',
        'drag',
        'dragFrom',
        'fling',
        'flingFrom',
        'timedDrag',
        'timedDragFrom',
        'startGesture',
        'getCenter',
        'getRect',
        'getTopLeft',
        'getTopRight',
        'getBottomLeft',
        'getBottomRight',
      ]) {
        test('flags $method after bare scroll', () {
          final sites = scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
tester.$method(target);
'''),
          );
          expect(sites, hasLength(1));
          expect(sites.single.method, method);
          expect(sites.single.path, 'test/subject_test.dart');
          expect(sites.single.scrollLine, 3);
          expect(sites.single.line, 4);
        });
      }

      test('assertions and widget reads do not clear a pending scroll', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
expect(target, findsOneWidget);
final widget = tester.widget(target);
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('finds coordinate reads nested inside an assertion', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
expect(tester.getCenter(target).dy, greaterThan(0));
'''),
          ),
          hasLength(1),
        );
      });

      test('an unawaited pump does not clear the scroll', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
tester.pump();
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('a pump passed as an argument has not necessarily completed', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await unknown(tester.pump());
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('a pump on a different tester does not clear the scroll', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await otherTester.pump();
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('deferred callback creation does not execute a pump', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
final callback = () async { await tester.pump(); };
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('comments and literal fixture strings are not code', () {
        expect(
          scan(
            testBody('''
// await tester.scrollUntilVisible(target, 100);
final fixture = 'tester.scrollUntilVisible(target, 100)';
await tester.tap(target);
'''),
          ),
          isEmpty,
        );
      });

      test('interpolation is executed', () {
        expect(
          scan(
            testBody(r'''
await tester.scrollUntilVisible(target, 100);
final message = '${tester.getCenter(target)}';
'''),
          ),
          hasLength(1),
        );
      });
    });

    group('settled and scroll-only cases', () {
      for (final pump in [
        'pump',
        'pumpAndSettle',
        'pumpWidget',
        'pumpFrames',
      ]) {
        test('awaited $pump clears pending layout', () {
          expect(
            scan(
              testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.$pump();
await tester.tap(target);
'''),
            ),
            isEmpty,
          );
        });
      }

      test('allows scroll followed only by assertions and callback use', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
expect(target, findsOneWidget);
tester.widget(target).onChanged(true);
'''),
          ),
          isEmpty,
        );
      });

      test('allows scrollUntilTappable followed by tap', () {
        expect(
          scan(
            testBody('''
await scrollUntilTappable(tester, target, 100);
await tester.tap(target);
'''),
          ),
          isEmpty,
        );
      });

      test('scrollUntilTappable settles earlier bare scrolls too', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await scrollUntilTappable(tester, other, 100);
await tester.tap(other);
'''),
          ),
          isEmpty,
        );
      });

      test('unawaited scrollUntilTappable cannot settle earlier scrolls', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
scrollUntilTappable(tester, other, 100);
await tester.tap(other);
'''),
          ),
          hasLength(1),
        );
      });

      test('a later scroll requires another frame', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.pump();
await tester.scrollUntilVisible(other, 100);
await tester.tap(other);
'''),
          ),
          hasLength(1),
        );
      });

      test('binds a local tester alias', () {
        expect(
          scan(
            testBody('''
final alias = tester;
await alias.scrollUntilVisible(target, 100);
await tester.pump();
await alias.tap(target);
'''),
          ),
          isEmpty,
        );
      });
    });

    group('helpers', () {
      test('follows nested same-file helpers with renamed parameters', () {
        expect(
          scan('''
Future<void> scroll(WidgetTester t) async {
  await t.scrollUntilVisible(target, 100);
}
void main() {
  Future<void> retry(WidgetTester renamed) async { await scroll(renamed); }
  testWidgets('subject', (tester) async {
    await retry(tester);
    await tester.tap(target);
  });
}
'''),
          hasLength(1),
        );
      });

      test('follows an interaction inside a helper', () {
        expect(
          scan('''
Future<void> click(WidgetTester t) async { await t.tap(target); }
void main() {
  testWidgets('subject', (tester) async {
    await tester.scrollUntilVisible(target, 100);
    await click(tester);
  });
}
'''),
          hasLength(1),
        );
      });

      test('follows an awaited settling helper', () {
        expect(
          scan('''
Future<void> settle({required WidgetTester t}) async { await t.pump(); }
void main() {
  testWidgets('subject', (tester) async {
    await tester.scrollUntilVisible(target, 100);
    await settle(t: tester);
    await tester.tap(target);
  });
}
'''),
          isEmpty,
        );
      });

      test('unawaited helper cannot clear a pending scroll', () {
        expect(
          scan('''
Future<void> settle(WidgetTester t) async { await t.pump(); }
void main() {
  testWidgets('subject', (tester) async {
    await tester.scrollUntilVisible(target, 100);
    settle(tester);
    await tester.tap(target);
  });
}
'''),
          hasLength(1),
        );
      });

      test('returned pump future completes when its helper is awaited', () {
        expect(
          scan('''
Future<void> settle(WidgetTester t) => t.pump();
void main() {
  testWidgets('subject', (tester) async {
    await tester.scrollUntilVisible(target, 100);
    await settle(tester);
    await tester.tap(target);
  });
}
'''),
          isEmpty,
        );
      });

      test('resolves shadowed helper names in the nearest lexical scope', () {
        expect(
          scan('''
Future<void> settle(WidgetTester t) async { await t.pump(); }
void main() {
  Future<void> settle(WidgetTester t) async { expect(target, findsOneWidget); }
  testWidgets('subject', (tester) async {
    await tester.scrollUntilVisible(target, 100);
    await settle(tester);
    await tester.tap(target);
  });
}
'''),
          hasLength(1),
        );
      });

      test('unused helper declarations do not clear pending layout', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
Future<void> settle() async { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('recursive helpers terminate and retain the scroll signal', () {
        expect(
          scan('''
Future<void> recursive(WidgetTester t) async {
  await t.scrollUntilVisible(target, 100);
  await recursive(t);
}
void main() {
  testWidgets('subject', (tester) async {
    await recursive(tester);
    await tester.tap(target);
  });
}
'''),
          hasLength(1),
        );
      });
    });

    group('control flow', () {
      test('an exception between scroll and pump keeps the scroll pending', () {
        expect(
          scan(
            testBody('''
try {
  await tester.scrollUntilVisible(target, 100);
  await mightThrow();
  await tester.pump();
} catch (_) { await tester.tap(target); }
'''),
          ),
          hasLength(1),
        );
      });

      test('a throwing branch cannot reach the later interaction', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
if (condition) { throw StateError('stop'); } else { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          isEmpty,
        );
      });

      test('switch statement preserves an unpumped branch', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
switch (value) {
  case 0: await tester.pump(); break;
  default: expect(target, findsOneWidget);
}
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('switch expression preserves an unpumped branch', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await (switch (value) { 0 => tester.pump(), _ => other() });
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('a conditional pump does not settle every path', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
if (condition) { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('pumps in both branches settle every continuing path', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
if (condition) { await tester.pump(); } else { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          isEmpty,
        );
      });

      test('return excludes an unsafe path from later interaction', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
if (condition) { return; } else { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          isEmpty,
        );
      });

      test('conditional expressions preserve the unsettled alternative', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await (condition ? tester.pump() : other());
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('short-circuit pump may never execute', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
condition && await tester.pump();
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('loop may execute zero times', () {
        expect(
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
while (condition) { await tester.pump(); }
await tester.tap(target);
'''),
          ),
          hasLength(1),
        );
      });

      test('detects interaction on the next loop iteration', () {
        expect(
          scan(
            testBody('''
for (var i = 0; i < 2; i++) {
  await tester.tap(target);
  await tester.scrollUntilVisible(target, 100);
}
'''),
          ),
          hasLength(1),
        );
      });

      test('finally settles all return paths from a helper', () {
        expect(
          scan('''
Future<void> scroll(WidgetTester t) async {
  try {
    await t.scrollUntilVisible(target, 100);
    return;
  } finally { await t.pump(); }
}
void main() {
  testWidgets('subject', (tester) async {
    await scroll(tester);
    await tester.tap(target);
  });
}
'''),
          isEmpty,
        );
      });
    });

    group('scan boundaries', () {
      test('an absolute scan root inside a worktree is still checked', () {
        final root = Directory('${temp.path}/.worktrees/task/mobile/test')
          ..createSync(recursive: true);
        File('${root.path}/subject_test.dart').writeAsStringSync(
          testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.tap(target);
'''),
        );
        expect(findBareScrollInteractions(root), hasLength(1));
      });

      test('includes integration, package tests and test helper files', () {
        for (final path in [
          'integration_test/subject_test.dart',
          'packages/example/test/subject_test.dart',
          'test/helpers/scroll.dart',
        ]) {
          final file = File('${temp.path}/$path');
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.tap(target);
'''),
          );
        }
        expect(findBareScrollInteractions(temp), hasLength(3));
      });

      test('excludes production, generated and build files', () {
        for (final path in [
          'lib/subject.dart',
          'test/subject.g.dart',
          'test/subject.mocks.dart',
          'build/test/subject_test.dart',
          '.dart_tool/test/subject_test.dart',
          '.worktrees/other/test/subject_test.dart',
        ]) {
          final file = File('${temp.path}/$path');
          file.parent.createSync(recursive: true);
          file.writeAsStringSync(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.tap(target);
'''),
          );
        }
        expect(findBareScrollInteractions(temp), isEmpty);
      });
    });

    group('guard delivery', () {
      Future<ProcessResult> runGuard() => Process.run(
        'bash',
        [File('scripts/check_bare_scroll_interaction.sh').absolute.path],
        environment: {
          'BARE_SCROLL_INTERACTION_SCAN_DIRS': '${temp.path}/test',
          'BARE_SCROLL_INTERACTION_BASELINE_FILE': '${temp.path}/baseline.txt',
          'BARE_SCROLL_INTERACTION_BASE_REF': 'HEAD',
          'BARE_SCROLL_INTERACTION_BASELINE_REPO_PATH': 'no-test-baseline.txt',
        },
      );

      setUp(() {
        File('${temp.path}/baseline.txt')
            .writeAsStringSync('# zero baseline\n');
      });

      test(
        'shell guard rejects a forbidden site with actionable output',
        () async {
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.tap(target);
'''),
          );
          final result = await runGuard();
          expect(result.exitCode, 1, reason: result.stderr.toString());
          expect(result.stdout, contains('subject_test.dart\t1'));
          expect(result.stdout, contains('Use scrollUntilTappable'));
        },
      );

      test('shell guard accepts an explicitly pumped interaction', () async {
        scan(
          testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.pump();
await tester.tap(target);
'''),
        );
        final result = await runGuard();
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout, contains('0 key(s) tracked'));
      });

      test(
        'detail CLI reports the source scroll and downstream interaction',
        () async {
          scan(
            testBody('''
await tester.scrollUntilVisible(target, 100);
await tester.tap(target);
'''),
          );
          final result = await Process.run('dart', [
            'scripts/lib/bare_scroll_interaction_detector.dart',
            '${temp.path}/test',
            '--path-prefix',
            temp.path,
            '--detail',
          ]);
          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(result.stdout, 'test/subject_test.dart:4\t3\ttap\n');
        },
      );
    });
  });
}
