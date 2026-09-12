import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'accessibility_guidelines.dart';

void _noop() {}

/// Runs [check] and returns the failure it threw, or `null` if it passed.
///
/// `expectLater(future, throwsA(...))` cannot be used here: the check has
/// already started async work under `TestAsyncUtils`, and starting a second
/// guarded operation before awaiting the first trips `guardSync`.
Future<TestFailure?> _failureFrom(Future<void> Function() check) async {
  try {
    await check();
    return null;
  } on TestFailure catch (failure) {
    return failure;
  }
}

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? VineTheme.theme,
  home: Scaffold(body: Center(child: child)),
);

/// A bare-Material app whose scaffold is painted [background].
///
/// Contrast fixtures avoid `VineTheme` on purpose: its typography resolves
/// through `google_fonts`, which `divine_ui` cannot satisfy from assets, and
/// [textContrastGuideline] rasterizes inside `runAsync` where that pending
/// load surfaces as a test error. Painting the scaffold too keeps the
/// guideline's 4px sampling ring on the same background as the glyphs.
Widget _plainApp(Widget child, {required Color background}) => MaterialApp(
  home: Scaffold(
    backgroundColor: background,
    body: Center(child: child),
  ),
);

/// A tap target of [side] logical pixels, optionally announcing [label].
class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.side, this.label});

  final double side;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(onTap: _noop, child: const SizedBox.expand()),
      ),
    );
  }
}

void main() {
  group('expectMeetsAccessibilityGuidelines', () {
    testWidgets('passes for a compliant control', (tester) async {
      await tester.pumpWidget(
        _app(const DivineButton(label: 'Continue', onPressed: _noop)),
      );

      await expectMeetsAccessibilityGuidelines(tester);
    });

    testWidgets('fails when a tap target is under 48dp', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 20, label: 'Tiny')));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [androidTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('documents that boundary targets are skipped', (tester) async {
      await tester.pumpWidget(
        _plainApp(
          Semantics(
            label: 'Flush tiny target',
            button: true,
            child: GestureDetector(
              onTap: _noop,
              child: const SizedBox(width: double.infinity, height: 20),
            ),
          ),
          background: Colors.white,
        ),
      );

      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: const [androidTapTargetGuideline],
      );
    });

    testWidgets('fails when a tap target is under 44pt', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 20, label: 'Tiny')));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [iOSTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('fails when a tappable node announces nothing', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 60)));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [labeledTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('passes when text clears WCAG AA contrast', (tester) async {
      await tester.pumpWidget(
        _plainApp(
          const Text(
            'clearly legible label',
            style: TextStyle(fontSize: 14, color: Colors.black),
          ),
          background: Colors.white,
        ),
      );

      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: const [textContrastGuideline],
      );
    });

    testWidgets('fails when text does not meet WCAG AA contrast', (
      tester,
    ) async {
      await tester.pumpWidget(
        _plainApp(
          const Text(
            'barely visible label',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          background: Colors.white,
        ),
      );

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [textContrastGuideline],
        ),
      );

      expect(failure, isNotNull);
    });
  });
}
