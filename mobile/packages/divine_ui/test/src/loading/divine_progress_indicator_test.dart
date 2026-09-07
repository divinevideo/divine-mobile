import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject({required bool disableAnimations, required Widget child}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: child),
      ),
    );
  }

  group('DivineCircularProgressIndicator', () {
    testWidgets('remains indeterminate when animations are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          child: const DivineCircularProgressIndicator(),
        ),
      );

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('becomes determinate when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: true,
          child: const DivineCircularProgressIndicator(),
        ),
      );

      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        1,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('preserves a caller supplied value and appearance', (
      tester,
    ) async {
      const color = Colors.green;
      const backgroundColor = Colors.black;
      const constraints = BoxConstraints.tightFor(width: 20, height: 20);
      const padding = EdgeInsets.all(2);

      await tester.pumpWidget(
        subject(
          disableAnimations: true,
          child: const DivineCircularProgressIndicator(
            value: 0.4,
            backgroundColor: backgroundColor,
            color: color,
            strokeWidth: 3,
            strokeAlign: 0,
            semanticsLabel: 'Uploading',
            semanticsValue: '40',
            strokeCap: StrokeCap.round,
            constraints: constraints,
            trackGap: 1,
            padding: padding,
          ),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.value, 0.4);
      expect(indicator.backgroundColor, backgroundColor);
      expect(indicator.color, color);
      expect(indicator.strokeWidth, 3);
      expect(indicator.strokeAlign, 0);
      expect(indicator.semanticsLabel, 'Uploading');
      expect(indicator.semanticsValue, '40');
      expect(indicator.strokeCap, StrokeCap.round);
      expect(indicator.constraints, constraints);
      expect(indicator.trackGap, 1);
      expect(indicator.padding, padding);
    });

    testWidgets('defers stroke geometry to the SDK and theme defaults', (
      tester,
    ) async {
      // Hardcoding these short-circuits the SDK's
      // `widget.x ?? indicatorTheme.x ?? defaults.x!` chain. `strokeAlign` is
      // the one that bites: with `year2023` defaulting to true the effective
      // default is `strokeAlignCenter` (0.0), so substituting
      // `strokeAlignInside` (-1.0) insets the arc by `strokeWidth / 2` and
      // shrinks every wrapped spinner by a full stroke width.
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          child: const DivineCircularProgressIndicator(),
        ),
      );

      final wrapped = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      const raw = CircularProgressIndicator();

      expect(wrapped.strokeAlign, isNull);
      expect(wrapped.strokeWidth, isNull);
      expect(wrapped.strokeAlign, raw.strokeAlign);
      expect(wrapped.strokeWidth, raw.strokeWidth);
    });
  });

  group('DivineLinearProgressIndicator', () {
    testWidgets('remains indeterminate when animations are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          child: const DivineLinearProgressIndicator(),
        ),
      );

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );
    });

    testWidgets('becomes determinate when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: true,
          child: const DivineLinearProgressIndicator(),
        ),
      );

      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('forwards determinate configuration', (tester) async {
      const color = Colors.green;
      const backgroundColor = Colors.black;
      const borderRadius = BorderRadius.all(Radius.circular(3));

      await tester.pumpWidget(
        subject(
          disableAnimations: true,
          child: const DivineLinearProgressIndicator(
            value: 0.6,
            backgroundColor: backgroundColor,
            color: color,
            minHeight: 5,
            semanticsLabel: 'Uploading',
            semanticsValue: '60',
            borderRadius: borderRadius,
            stopIndicatorColor: Colors.white,
            stopIndicatorRadius: 1,
            trackGap: 2,
          ),
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.6);
      expect(indicator.backgroundColor, backgroundColor);
      expect(indicator.color, color);
      expect(indicator.minHeight, 5);
      expect(indicator.semanticsLabel, 'Uploading');
      expect(indicator.semanticsValue, '60');
      expect(indicator.borderRadius, borderRadius);
      expect(indicator.stopIndicatorColor, Colors.white);
      expect(indicator.stopIndicatorRadius, 1);
      expect(indicator.trackGap, 2);
    });
  });
}
