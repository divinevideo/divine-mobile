// ABOUTME: Tests the perpetual-animation reduced-motion AST guard.
// ABOUTME: Pins Skeletonizer parse forms and every gating shape in the app.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts live outside lib/.
import '../../scripts/lib/reduced_motion_gating_detector.dart';

void main() {
  List<String> kinds(String source) =>
      findReducedMotionGatingViolations(source).map((s) => s.kind).toList();

  group('reduced motion gating detector', () {
    group('Skeletonizer', () {
      test('reports every parse form of a construction with no effect', () {
        // Without `const` or `new`, unresolved source parses `Skeletonizer(...)`
        // as a method invocation rather than an instance creation, and
        // `.zone()` puts the class name on the target. A detector that watches
        // only the creation form silently passes every real call site.
        expect(
          kinds('''
Widget a() => Skeletonizer(child: x);
Widget b() => const Skeletonizer(child: x);
Widget c() => new Skeletonizer(child: x);
Widget d() => Skeletonizer.zone(child: x);
Widget e() => const pkg.Skeletonizer(child: x);
'''),
          List.filled(5, 'skeletonizer'),
        );
      });

      test('allows an effect taken from the shared helper', () {
        expect(
          kinds('''
Widget a(BuildContext context) =>
    Skeletonizer(effect: vineSkeletonEffectOf(context), child: x);
Widget b(BuildContext context) => const Skeletonizer.zone(
  effect: vineSkeletonEffectOf(context),
  child: x,
);
'''),
          isEmpty,
        );
      });

      test('rejects an effect that bypasses the shared helper', () {
        // A hand-rolled ShimmerEffect is the regression this exists to catch:
        // it renders, it looks right, and it repeats forever.
        expect(
          kinds('''
Widget a() => Skeletonizer(
  effect: ShimmerEffect(baseColor: c, highlightColor: h),
  child: x,
);
'''),
          ['skeletonizer'],
        );
      });

      test('rejects an effect that only mentions the helper in one branch', () {
        expect(
          kinds('''
Widget a(bool custom) => Skeletonizer(
  effect: custom ? ShimmerEffect() : vineSkeletonEffectOf(context),
  child: x,
);
'''),
          ['skeletonizer'],
        );
      });

      test('ignores our own wrapper and unrelated widgets', () {
        expect(
          kinds('''
Widget a(BuildContext context) => IdentitySkeletonizer(child: x);
Widget b() => SomeOtherWidget(child: x);
'''),
          isEmpty,
        );
      });
    });

    group('repeat', () {
      test('reports an ungated repeating controller', () {
        expect(kinds('void a() { _controller.repeat(); }'), ['repeat']);
      });

      test('allows the else branch of an if on reduced motion', () {
        expect(
          kinds('''
void a(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) {
    _c.stop();
  } else {
    _c.repeat();
  }
}
'''),
          isEmpty,
        );
      });

      test('allows a then branch guarded by a negated check', () {
        expect(
          kinds('''
void a(BuildContext context) {
  if (isPlaying && !MediaQuery.disableAnimationsOf(context)) {
    if (!_c.isAnimating) _c.repeat();
  }
}
'''),
          isEmpty,
        );
      });

      test('allows a statement after a reduced-motion early return', () {
        expect(
          kinds('''
void a(BuildContext context) {
  if (context.reduceMotion) {
    _swap.value = 1;
    return;
  }
  _rotation.repeat();
}
'''),
          isEmpty,
        );
      });

      test('allows the older MediaQuery.of property read', () {
        expect(
          kinds('''
void a(BuildContext context) {
  if (!isPlaying || MediaQuery.of(context).disableAnimations) {
    _c.stop();
  } else if (!_c.isAnimating) {
    _c.repeat(reverse: true);
  }
}
'''),
          isEmpty,
        );
      });

      test('does not trust a similarly named condition', () {
        expect(
          kinds('''
void a(bool disableAnimationsLater) {
  if (disableAnimationsLater) {
    _c.stop();
  } else {
    _c.repeat();
  }
}
'''),
          ['repeat'],
        );
      });

      test('does not accept a gate in a different function', () {
        // The walk stops at the enclosing body: a check somewhere else in the
        // file says nothing about this call.
        expect(
          kinds('''
void gate(BuildContext context) {
  if (MediaQuery.disableAnimationsOf(context)) return;
}
void a() { _c.repeat(); }
'''),
          ['repeat'],
        );
      });

      test('does not accept an early return that does not exit', () {
        expect(
          kinds('''
void a(BuildContext context) {
  if (context.reduceMotion) {
    _c.stop();
  }
  _c.repeat();
}
'''),
          ['repeat'],
        );
      });

      test('does not treat a mixed OR as a motion-allowed gate', () {
        expect(
          kinds('''
void a(bool other) {
  if (!reduceMotion || other) {
    _c.repeat();
  }
}
'''),
          ['repeat'],
        );
      });

      test('does not treat a mixed AND else as a motion-allowed gate', () {
        expect(
          kinds('''
void a(bool other) {
  if (reduceMotion && other) {
    _c.stop();
  } else {
    _c.repeat();
  }
}
'''),
          ['repeat'],
        );
      });
    });

    test('ignores comments and strings', () {
      expect(
        kinds('''
// Skeletonizer(child: x) and _c.repeat();
const example = 'Skeletonizer(child: x)';
'''),
        isEmpty,
      );
    });

    test('reports the line of each site', () {
      final sites = findReducedMotionGatingViolations('''
Widget a() => Skeletonizer(child: x);

void b() { _c.repeat(); }
''');
      expect(sites.map((s) => s.line), [1, 3]);
    });

    test('scan filter includes production libraries only', () {
      expect(shouldScanReducedMotionFile('lib/a.dart'), isTrue);
      expect(
        shouldScanReducedMotionFile('packages/divine_ui/lib/a.dart'),
        isTrue,
      );
      expect(shouldScanReducedMotionFile('test/a.dart'), isFalse);
      expect(shouldScanReducedMotionFile('integration_test/a.dart'), isFalse);
      expect(shouldScanReducedMotionFile('lib/a.g.dart'), isFalse);
      expect(shouldScanReducedMotionFile('lib/a.md'), isFalse);
    });
  });
}
