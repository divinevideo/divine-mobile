// ABOUTME: Verifies the shared skeleton effect honors reduced motion.
// ABOUTME: Prevents Skeletonizer's shimmer ticker from blocking UI quiescence.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  Widget subject({required bool disableAnimations}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Builder(
          builder: (context) => Skeletonizer(
            effect: vineSkeletonEffectOf(context),
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
  });
}
