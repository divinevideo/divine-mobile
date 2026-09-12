// ABOUTME: Widget tests for FeedImmersiveChrome.
// ABOUTME: Covers fading + pointer-blocking against the cubit, the
// ABOUTME: no-provider fallback, and the reduced-motion instant switch.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';

Future<void> _pumpChrome(
  WidgetTester tester, {
  FeedImmersiveCubit? cubit,
  bool disableAnimations = false,
  VoidCallback? onTap,
}) async {
  final chrome = FeedImmersiveChrome(
    child: GestureDetector(
      onTap: onTap,
      child: const SizedBox.expand(child: Text('chrome')),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: cubit == null
            ? chrome
            : BlocProvider<FeedImmersiveCubit>.value(
                value: cubit,
                child: chrome,
              ),
      ),
    ),
  );
}

double _opacityOf(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

bool _ignoringPointer(WidgetTester tester) => tester
    .widget<IgnorePointer>(
      find.descendant(
        of: find.byType(FeedImmersiveChrome),
        matching: find.byType(IgnorePointer),
      ),
    )
    .ignoring;

void main() {
  group(FeedImmersiveChrome, () {
    testWidgets('shows the chrome while not immersive', (tester) async {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);

      await _pumpChrome(tester, cubit: cubit);

      expect(_opacityOf(tester), equals(1.0));
      expect(_ignoringPointer(tester), isFalse);
    });

    testWidgets('hides the chrome and blocks taps once immersive', (
      tester,
    ) async {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);
      var taps = 0;

      await _pumpChrome(tester, cubit: cubit, onTap: () => taps++);
      cubit.enter();
      await tester.pumpAndSettle();

      expect(_opacityOf(tester), equals(0.0));
      expect(_ignoringPointer(tester), isTrue);

      await tester.tap(find.text('chrome'), warnIfMissed: false);
      await tester.pump();

      expect(
        taps,
        isZero,
        reason: 'hidden chrome must not swallow taps meant for the video',
      );
    });

    testWidgets('restores the chrome when the hold ends', (tester) async {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);

      await _pumpChrome(tester, cubit: cubit);
      cubit.enter();
      await tester.pumpAndSettle();
      cubit.exit();
      await tester.pumpAndSettle();

      expect(_opacityOf(tester), equals(1.0));
      expect(_ignoringPointer(tester), isFalse);
    });

    testWidgets('keeps blocking taps until the chrome is visible again', (
      tester,
    ) async {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);
      var taps = 0;

      await _pumpChrome(tester, cubit: cubit, onTap: () => taps++);
      cubit.enter();
      await tester.pumpAndSettle();

      // Release the hold, then stop part-way through the fade back in.
      cubit.exit();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        _ignoringPointer(tester),
        isTrue,
        reason: 'chrome is still invisible here — it must not accept taps',
      );

      await tester.tap(find.text('chrome'), warnIfMissed: false);
      await tester.pump();

      expect(
        taps,
        isZero,
        reason: 'a tap must never land on a control the viewer cannot see',
      );

      // Once the fade completes the chrome is tappable again.
      await tester.pumpAndSettle();
      expect(_ignoringPointer(tester), isFalse);
      await tester.tap(find.text('chrome'));
      await tester.pump();
      expect(taps, equals(1));
    });

    testWidgets('stays visible when no cubit is provided', (tester) async {
      await _pumpChrome(tester);

      expect(_opacityOf(tester), equals(1.0));
      expect(_ignoringPointer(tester), isFalse);
    });

    testWidgets('skips the cross-fade under reduced motion', (tester) async {
      final cubit = FeedImmersiveCubit();
      addTearDown(cubit.close);

      await _pumpChrome(tester, cubit: cubit, disableAnimations: true);

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).duration,
        equals(Duration.zero),
      );
    });
  });
}
