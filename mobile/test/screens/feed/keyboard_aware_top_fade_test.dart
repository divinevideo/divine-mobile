// ABOUTME: Tests for KeyboardAwareTopFade — the ShaderMask wrapper that
// ABOUTME: fades the top of the fullscreen action column while the soft
// ABOUTME: keyboard is on screen. Drives the platform's viewInsets
// ABOUTME: animation directly since that's the signal the widget reads.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';

void main() {
  group(KeyboardAwareTopFade, () {
    // The mask is driven by the *direction* of viewInsets.bottom, not
    // by its value. On iOS/Android the platform animates the inset
    // over the OS keyboard curve (~250 ms) and Flutter fires
    // didChangeMetrics each frame — first rise from 0 = show starting,
    // first decrease from a non-zero value = hide starting.

    const subject = Directionality(
      textDirection: TextDirection.ltr,
      child: KeyboardAwareTopFade(
        child: SizedBox(
          key: ValueKey('child'),
          width: 48,
          height: 200,
        ),
      ),
    );

    testWidgets(
      'passes the child through with no ShaderMask when viewInsets are 0',
      (tester) async {
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);

        expect(find.byType(ShaderMask), findsNothing);
        expect(find.byKey(const ValueKey('child')), findsOneWidget);
      },
    );

    testWidgets(
      'snaps the ShaderMask on as soon as viewInsets begin rising from 0',
      (tester) async {
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);
        expect(find.byType(ShaderMask), findsNothing);

        // First frame of the keyboard show animation — inset is still
        // well below the eventual target.
        tester.view.viewInsets = const FakeViewPadding(bottom: 40);
        await tester.pump();

        expect(find.byType(ShaderMask), findsOneWidget);
        expect(find.byKey(const ValueKey('child')), findsOneWidget);
      },
    );

    testWidgets(
      'starts the fade-out on the FIRST decrease in viewInsets, not at 0',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);
        expect(find.byType(ShaderMask), findsOneWidget);

        // First frame of the keyboard hide animation. The inset is
        // still very much non-zero — but the fade-out must already
        // be running because the platform keyboard is now sliding
        // off-screen in parallel.
        tester.view.viewInsets = const FakeViewPadding(bottom: 270);
        await tester.pump();
        expect(find.byType(ShaderMask), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(ShaderMask), findsOneWidget);

        // Past the 100 ms fade — wrapper drops while viewInsets are
        // still mid-animation (in real iOS this is ~150 ms before
        // the keyboard has finished sliding down).
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.byType(ShaderMask), findsNothing);
      },
    );

    testWidgets(
      'ignores rising viewInsets while already visible (no re-trigger '
      'mid-show animation)',
      (tester) async {
        tester.view.viewInsets = FakeViewPadding.zero;
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);

        // Successive frames of the keyboard show animation — each
        // frame the inset rises further. The mask should stay on
        // throughout, not flicker.
        for (final inset in const [40.0, 120.0, 220.0, 280.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pump();
          expect(find.byType(ShaderMask), findsOneWidget);
        }
      },
    );

    testWidgets(
      'uses BlendMode.dstIn so the gradient acts as an alpha mask',
      (tester) async {
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        addTearDown(tester.view.resetViewInsets);

        await tester.pumpWidget(subject);

        final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
        expect(mask.blendMode, BlendMode.dstIn);
      },
    );
  });
}
