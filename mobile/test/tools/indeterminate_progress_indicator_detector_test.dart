// ABOUTME: Tests the raw indeterminate progress-indicator AST guard.
// ABOUTME: Pins constructor parsing and determinate-value exemptions.

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts live outside lib/.
import '../../scripts/lib/indeterminate_progress_indicator_detector.dart';

void main() {
  group('indeterminate progress indicator detector', () {
    test('finds raw circular and linear indicators without a value', () {
      final sites = findIndeterminateProgressIndicatorsInSource('''
Widget a() => const CircularProgressIndicator();
Widget b() => LinearProgressIndicator(color: color);
Widget c() => material.CircularProgressIndicator.adaptive();
''');

      expect(sites.map((site) => site.widget), [
        'CircularProgressIndicator',
        'LinearProgressIndicator',
        'CircularProgressIndicator',
      ]);
    });

    test('finds adaptive constructors in every written form', () {
      // Unresolved, the leading identifier of `CircularProgressIndicator
      // .adaptive()` is equally a class or an import prefix, so the `const`
      // and `new` forms parse as a prefixed type named `adaptive`. On iOS
      // `.adaptive` renders a CupertinoActivityIndicator, which animates
      // forever and never consults MediaQuery.disableAnimations -- exactly
      // what this guard exists to keep out.
      final sites = findIndeterminateProgressIndicatorsInSource('''
Widget a() => const CircularProgressIndicator.adaptive();
Widget b() => new CircularProgressIndicator.adaptive();
Widget c() => CircularProgressIndicator.adaptive();
Widget d() => const material.CircularProgressIndicator.adaptive();
''');

      expect(sites.map((site) => site.widget), [
        'CircularProgressIndicator',
        'CircularProgressIndicator',
        'CircularProgressIndicator',
        'CircularProgressIndicator',
      ]);
    });

    test('reports a prefixed indicator exactly once', () {
      final sites = findIndeterminateProgressIndicatorsInSource(
        'Widget a() => const material.CircularProgressIndicator();',
      );

      expect(sites, hasLength(1));
    });

    test('allows raw determinate indicators and Divine wrappers', () {
      final sites = findIndeterminateProgressIndicatorsInSource('''
Widget a() => CircularProgressIndicator(value: progress);
Widget b() => const LinearProgressIndicator(value: 0.5);
Widget c() => const DivineCircularProgressIndicator();
Widget d() => const DivineLinearProgressIndicator();
''');

      expect(sites, isEmpty);
    });

    test('treats an explicit null value as indeterminate', () {
      final sites = findIndeterminateProgressIndicatorsInSource(
        'Widget a() => const CircularProgressIndicator(value: null);',
      );

      expect(sites, hasLength(1));
      expect(sites.single.line, 1);
    });

    test('ignores comments and strings', () {
      final sites = findIndeterminateProgressIndicatorsInSource('''
// CircularProgressIndicator()
const example = 'LinearProgressIndicator()';
''');

      expect(sites, isEmpty);
    });

    test('scan filter includes production libraries only', () {
      expect(shouldScanProgressIndicatorFile('lib/a.dart'), isTrue);
      expect(
        shouldScanProgressIndicatorFile('packages/divine_ui/lib/a.dart'),
        isTrue,
      );
      expect(shouldScanProgressIndicatorFile('test/a.dart'), isFalse);
      expect(shouldScanProgressIndicatorFile('lib/a.g.dart'), isFalse);
    });
  });
}
