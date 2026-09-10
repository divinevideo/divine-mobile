// ABOUTME: Verifies the shared skeleton effect honors reduced motion.
// ABOUTME: Prevents Skeletonizer's shimmer ticker from blocking UI quiescence.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  Widget subject({
    required bool disableAnimations,
    Color? baseColor,
    AlignmentGeometry? begin,
    AlignmentGeometry? end,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) => Skeletonizer(
            effect: begin == null || end == null
                ? vineSkeletonEffectOf(context, baseColor: baseColor)
                : vineSkeletonEffectOf(
                    context,
                    baseColor: baseColor,
                    begin: begin,
                    end: end,
                  ),
            child: const Text('Loading'),
          ),
        ),
      ),
    );
  }

  group('vineSkeletonEffectOf', () {
    testWidgets('uses a static effect when animations are disabled', (
      tester,
    ) async {
      await tester.pumpWidget(subject(disableAnimations: true));

      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
      );
      expect(skeletonizer.effect, isA<SolidColorEffect>());
      expect(skeletonizer.effect!.duration, Duration.zero);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('keeps the shimmer effect when animations are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(subject(disableAnimations: false));

      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
      );
      expect(skeletonizer.effect, isA<ShimmerEffect>());
    });

    testWidgets('sweeps in the direction the caller asks for', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );

      final shimmer =
          tester
                  .widget<Skeletonizer>(
                    find.byWidgetPredicate((widget) => widget is Skeletonizer),
                  )
                  .effect!
              as ShimmerEffect;
      expect(shimmer.begin, Alignment.topCenter);
      expect(shimmer.end, Alignment.bottomCenter);
    });

    testWidgets('paints a caller-supplied base colour in both modes', (
      tester,
    ) async {
      const base = Color(0xFF123456);

      await tester.pumpWidget(
        subject(disableAnimations: false, baseColor: base),
      );
      final shimmer = tester
          .widget<Skeletonizer>(
            find.byWidgetPredicate((widget) => widget is Skeletonizer),
          )
          .effect;
      expect(shimmer, isA<ShimmerEffect>());
      expect((shimmer! as ShimmerEffect).colors.first, base);

      await tester.pumpWidget(
        subject(disableAnimations: true, baseColor: base),
      );
      final solid = tester
          .widget<Skeletonizer>(
            find.byWidgetPredicate((widget) => widget is Skeletonizer),
          )
          .effect;
      expect(solid, isA<SolidColorEffect>());
      expect((solid! as SolidColorEffect).color, base);
    });
  });
}
