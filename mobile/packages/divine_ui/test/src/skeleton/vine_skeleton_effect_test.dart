// ABOUTME: Verifies the shared skeleton effect follows Divine appearance.
// ABOUTME: Covers semantic colors and reduced-motion behavior.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  Widget subject({
    required bool disableAnimations,
    ThemeData? theme,
    Brightness platformBrightness = Brightness.light,
    Color? baseColor,
  }) {
    return MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: disableAnimations,
          platformBrightness: platformBrightness,
        ),
        child: Builder(
          builder: (context) => Skeletonizer(
            effect: vineSkeletonEffectOf(context, baseColor: baseColor),
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

    testWidgets('uses dark semantic colors when the platform is light', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          theme: VineTheme.theme,
        ),
      );

      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
      );
      final effect = skeletonizer.effect! as ShimmerEffect;
      final base = VineTheme.darkColors.skeleton;
      expect(effect.colors, [base, base.withValues(alpha: 0.6), base]);
    });

    testWidgets('uses light semantic colors when the platform is dark', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          disableAnimations: false,
          theme: VineTheme.lightTheme,
          platformBrightness: Brightness.dark,
        ),
      );

      final skeletonizer = tester.widget<Skeletonizer>(
        find.byWidgetPredicate((widget) => widget is Skeletonizer),
      );
      final effect = skeletonizer.effect! as ShimmerEffect;
      final base = VineTheme.lightColors.skeleton;
      expect(effect.colors, [base, base.withValues(alpha: 0.6), base]);
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
