// ABOUTME: Tests for the placeholder detector behind check_placeholder_tests.sh
// ABOUTME: (scripts/lib/placeholder_test_detector.dart, #3340).

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/placeholder_test_detector.dart';

/// Pins the detector that freezes tests-that-cannot-fail at zero.
///
/// The boundaries matter more than the hits. Flagging a real test as a
/// placeholder would delete coverage, so the tautology rule is literal-only
/// and a tautology beside a real assertion does not count. The
/// no-declarations rule has exactly one legitimate shape to spare —
/// `void main() => platform.main();`, the conditional-import dispatcher — and
/// the exemption is that shape, not an allowlist of filenames.
void main() {
  group('findPlaceholderTestsInSource', () {
    List<PlaceholderTest> scan(String source) =>
        findPlaceholderTestsInSource(source, path: 'test/subject_test.dart');

    group('tautology rule', () {
      test('flags a test whose only assertion is trivially satisfied', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    test('documents the expected behaviour', () {
      expect(true, isTrue, reason: 'Placeholder until implementation exists');
    });
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.tautology);
        expect(sites.single.description, "'documents the expected behaviour'");
        expect(sites.single.line, 3);
      });

      test('flags every trivially-satisfied shape', () {
        final sites = scan('''
void main() {
  test('a', () { expect(true, isTrue); });
  test('b', () { expect(false, isFalse); });
  test('c', () { expect(true, true); });
  test('d', () { expect(1, 1); });
  test('e', () { expect('x', 'x'); });
  test('f', () { expect(1, equals(1)); });
}
''');

        expect(sites, hasLength(6));
      });

      test('flags however dart format wrapped the call', () {
        // A line-oriented scan found 14 of the 38 tautologies in
        // test/widget/tdd/accessibility_ui_test.dart for exactly this reason.
        final sites = scan('''
void main() {
  test('wrapped', () {
    expect(
      true,
      isTrue,
    );
  });
}
''');

        expect(sites, hasLength(1));
      });

      test('does not flag a tautology beside a real assertion', () {
        // The test as a whole can still fail, so it is noise, not a placeholder.
        final sites = scan('''
void main() {
  test('a', () {
    expect(true, isTrue);
    expect(subject.value, equals(42));
  });
}
''');

        expect(sites, isEmpty);
      });

      test('does not flag a real assertion that merely mentions a literal', () {
        final sites = scan('''
void main() {
  test('a', () { expect(subject.isReady, isTrue); });
  test('b', () { expect(items.length, 1); });
  test('c', () { expect(() => Foo(), returnsNormally); });
  test('d', () { expect(tester.takeException(), isNull); });
}
''');

        expect(sites, isEmpty);
      });

      test('does not flag a test with no assertion at all', () {
        // Deliberately out of scope: assertions arrive via imported helpers and
        // third-party verifiers this parser cannot resolve. See the script header.
        final sites = scan('''
void main() {
  test('a', () async {
    await verifier.migrateAndValidate(db, 9);
  });
}
''');

        expect(sites, isEmpty);
      });
    });

    group('no-declarations rule', () {
      test('flags a test file that declares nothing', () {
        final sites = scan('''
// Fix and re-enable this suite.
void main() {}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.noDeclarations);
        expect(sites.single.description, '<no test declarations>');
      });

      test('exempts a main() that only forwards to another library', () {
        // html_video_element_backend_web_test.dart's shape: the declarations
        // live in whichever platform library the conditional import selects.
        final sites = scan('''
@TestOn('browser')
library;

import 'backend_stub.dart'
    if (dart.library.js_interop) 'backend_web.dart' as platform;

void main() => platform.main();
''');

        expect(sites, isEmpty);
      });

      test('exempts the block-bodied and awaited forwarding forms too', () {
        expect(scan('void main() { platform.main(); }'), isEmpty);
        expect(scan('Future<void> main() async => platform.main();'), isEmpty);
      });

      test('does not exempt a main() that forwards to something else', () {
        // Only a call named `main` is the dispatcher shape. Anything else is a
        // stub wearing its clothes.
        final sites = scan('void main() => setUpEverything();');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.noDeclarations);
      });

      test('does not flag a file that declares only a group', () {
        final sites = scan('''
void main() {
  group('Feature', sharedSuite);
}
''');

        expect(sites, isEmpty);
      });
    });

    group('empty group rule', () {
      test('flags an empty group', () {
        final sites = scan('''
void main() {
  group('Feature', () {});
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
        expect(sites.single.description, "'Feature'");
        expect(sites.single.line, 2);
      });

      test('reports only the outermost group in an empty nested tree', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    group('nested', () {});
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
        expect(sites.single.description, "'Feature'");
      });

      test('accepts a test declared in a nested group', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    group('nested', () {
      test('works', () { expect(subject.value, 1); });
    });
  });
}
''');

        expect(sites, isEmpty);
      });

      test('flags a group containing only lifecycle declarations', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    setUpAll(() { registerFallbackValue(FakeValue()); });
    setUp(() { subject = Subject(); });
    tearDown(() { subject.dispose(); });
    tearDownAll(cleanUpSuite);
    addTearDown(cleanUpCase);
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
      });

      test('accepts a same-file test wrapper', () {
        final sites = scan('''
void testWidgetsWithSurfaceSize(String name, WidgetTesterCallback body) {
  testWidgets(name, body);
}

void main() {
  group('Feature', () {
    testWidgetsWithSurfaceSize('works', (tester) async {});
  });
}
''');

        expect(sites, isEmpty);
      });

      test('accepts an imported test-declaring helper', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    defineFutureDelayedCeilingTests('production', 'lib');
  });
}
''');

        expect(sites, isEmpty);
      });

      test('does not inspect lifecycle callbacks for helper-shaped calls', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    setUp(() {
      when(() => service.load()).thenReturn(value);
    });
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
      });

      test('accepts a generic blocTest declaration', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    blocTest<FeatureBloc, FeatureState>('works', build: FeatureBloc.new);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('accepts a nested group delegated to a suite callback', () {
        // The top-level form is already covered by the no-declarations rule.
        // Only the nested one reaches _GroupScan's no-callback branch.
        final sites = scan('''
void main() {
  group('Feature', () {
    group('nested', sharedSuite);
  });
}
''');

        expect(sites, isEmpty);
      });

      test('flags a group whose only body is an assertion', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    verify(() => mock.thing()).called(1);
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
      });

      test('does not mistake a targeted product call for a test helper', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    subject.initialize();
  });
}
''');

        expect(sites, hasLength(1));
        expect(sites.single.kind, PlaceholderKind.emptyGroup);
      });

      test('accepts a test declared through an import prefix', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    ft.test('real', () {
      expect(subject.value, 1);
    });
  });
}
''');

        expect(sites, isEmpty);
      });

      test('accepts a blocTest reached through a receiver', () {
        final sites = scan('''
void main() {
  group('Feature', () {
    ft.blocTest<MyBloc, MyState>('real', build: buildBloc);
  });
}
''');

        expect(sites, isEmpty);
      });
    });
  });
}
