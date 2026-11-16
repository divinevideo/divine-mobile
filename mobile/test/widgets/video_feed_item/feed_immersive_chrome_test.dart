// ABOUTME: Widget tests for FeedImmersiveChrome.
// ABOUTME: Covers fading + pointer-blocking against the cubit, the
// ABOUTME: no-provider fallback, the reduced-motion instant switch, and the
// ABOUTME: copy that flies with a grid tile's picture.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/feed_immersive_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_immersive_chrome.dart';
import 'package:openvine/widgets/video_tile_transition/video_tile_transition_target.dart';

Future<void> _pumpChrome(
  WidgetTester tester, {
  FeedImmersiveCubit? cubit,
  bool disableAnimations = false,
  ValueListenable<VideoTileFlightPhase>? phase,
  ValueListenable<VideoTileFlightFrame?>? flight,
  VoidCallback? onTap,
}) async {
  Widget chrome = FeedImmersiveChrome(
    child: GestureDetector(
      onTap: onTap,
      child: const SizedBox.expand(child: Text('chrome')),
    ),
  );
  if (phase != null) {
    var scopeFlight = flight;
    if (scopeFlight == null) {
      final noFlight = ValueNotifier<VideoTileFlightFrame?>(null);
      addTearDown(noFlight.dispose);
      scopeFlight = noFlight;
    }
    chrome = VideoTileTransitionScope(
      targets: VideoTileTransitionTargets(),
      phase: phase,
      flight: scopeFlight,
      child: chrome,
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

/// The opacity the chrome is drawn at now, mid-fade included.
double _paintedOpacityOf(WidgetTester tester) => tester
    .renderObject<RenderAnimatedOpacity>(
      find.descendant(
        of: find.byType(AnimatedOpacity),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

bool _ignoringPointer(WidgetTester tester) => tester
    .widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(IgnorePointer),
          )
          .first,
    )
    .ignoring;

/// The chrome's copy flying with a tile's picture.
Finder get _flyingCopy => find.descendant(
  of: find.byType(VideoTileFlightCopy),
  matching: find.text('chrome'),
);

/// The rounded rects the flying copy is clipped to.
List<RRect> _flyingClips(WidgetTester tester) => tester
    .widgetList<ClipRRect>(
      find.ancestor(of: _flyingCopy, matching: find.byType(ClipRRect)),
    )
    .map((clip) => clip.clipper?.getClip(Size.zero))
    .whereType<RRect>()
    .toList();

VideoTileFlightFrame _frame({
  double opacity = 0.4,
  RRect clip = const RRect.fromLTRBXY(0, 0, 800, 600, 0, 0),
  RRect bounds = const RRect.fromLTRBXY(0, 0, 800, 600, 0, 0),
}) => VideoTileFlightFrame(
  transform: Matrix4.identity()
    ..translateByDouble(10, 20, 0, 1)
    ..scaleByDouble(0.5, 0.5, 1, 1),
  clip: clip,
  bounds: bounds,
  opacity: opacity,
);

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

    group('while a grid tile picture flies over the player', () {
      testWidgets('hides the chrome and blocks taps', (tester) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        var taps = 0;

        await _pumpChrome(tester, phase: phase, onTap: () => taps++);
        await tester.tap(find.text('chrome'), warnIfMissed: false);

        expect(_opacityOf(tester), equals(0.0));
        expect(_ignoringPointer(tester), isTrue);
        expect(taps, equals(0));
      });

      testWidgets('keeps the chrome hidden while the picture is arriving', (
        tester,
      ) async {
        final phase = ValueNotifier(VideoTileFlightPhase.arriving);
        addTearDown(phase.dispose);

        await _pumpChrome(tester, phase: phase);

        expect(_opacityOf(tester), equals(0.0));
        expect(_ignoringPointer(tester), isTrue);
      });

      testWidgets('flies a copy where the frame puts it', (tester) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        final flight = ValueNotifier<VideoTileFlightFrame?>(_frame());
        addTearDown(flight.dispose);

        await _pumpChrome(tester, phase: phase, flight: flight);

        expect(_flyingCopy, findsOneWidget);
        // Laid out at the chrome's size, then moved and scaled by the frame.
        expect(
          tester.getRect(_flyingCopy),
          equals(const Rect.fromLTWH(10, 20, 400, 300)),
        );
        expect(
          tester
              .widget<Opacity>(
                find.ancestor(of: _flyingCopy, matching: find.byType(Opacity)),
              )
              .opacity,
          equals(0.4),
        );
      });

      testWidgets('lays the copy out with the padding the chrome sees', (
        tester,
      ) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        final flight = ValueNotifier<VideoTileFlightFrame?>(_frame());
        addTearDown(flight.dispose);
        final bottomPaddings = <bool, double>{};
        final chrome = VideoTileTransitionScope(
          targets: VideoTileTransitionTargets(),
          phase: phase,
          flight: flight,
          child: FeedImmersiveChrome(
            child: Builder(
              builder: (context) {
                bottomPaddings[VideoTileFlightCopy.isIn(
                  context,
                )] = MediaQuery.viewPaddingOf(context)
                    .bottom;
                return const SizedBox.expand();
              },
            ),
          ),
        );
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(bottom: 34),
              viewPadding: EdgeInsets.only(bottom: 34),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    // The fullscreen feed removes the home indicator's
                    // padding above its items.
                    builder: (context) => MediaQuery.removePadding(
                      context: context,
                      removeBottom: true,
                      child: chrome,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(bottomPaddings, equals({false: 0.0, true: 0.0}));
      });

      testWidgets('shows only what the frame clips to', (tester) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        final clip = RRect.fromLTRBR(
          30,
          40,
          200,
          250,
          const Radius.circular(8),
        );
        final flight = ValueNotifier<VideoTileFlightFrame?>(_frame(clip: clip));
        addTearDown(flight.dispose);

        await _pumpChrome(tester, phase: phase, flight: flight);

        expect(_flyingClips(tester), contains(clip));
      });

      testWidgets('keeps the copy within the bounds the flight is drawn in', (
        tester,
      ) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        // As above a bottom bar the copy must stay under, inside a panel's
        // rounded corners.
        final bounds = RRect.fromLTRBR(
          0,
          0,
          800,
          520,
          const Radius.circular(30),
        );
        final flight = ValueNotifier<VideoTileFlightFrame?>(
          _frame(bounds: bounds),
        );
        addTearDown(flight.dispose);

        await _pumpChrome(tester, phase: phase, flight: flight);

        expect(_flyingClips(tester), contains(bounds));
      });

      testWidgets('drops the copy when no picture flies', (tester) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        final flight = ValueNotifier<VideoTileFlightFrame?>(_frame());
        addTearDown(flight.dispose);
        await _pumpChrome(tester, phase: phase, flight: flight);
        expect(_flyingCopy, findsOneWidget);

        flight.value = null;
        await tester.pump();

        expect(_flyingCopy, findsNothing);
      });

      testWidgets('swaps the copy for the chrome at once on landing', (
        tester,
      ) async {
        final phase = ValueNotifier(VideoTileFlightPhase.flying);
        addTearDown(phase.dispose);
        final flight = ValueNotifier<VideoTileFlightFrame?>(_frame());
        addTearDown(flight.dispose);
        var taps = 0;
        await _pumpChrome(
          tester,
          phase: phase,
          flight: flight,
          onTap: () => taps++,
        );

        phase.value = VideoTileFlightPhase.landed;
        flight.value = null;
        await tester.pump();

        expect(_flyingCopy, findsNothing);
        expect(_paintedOpacityOf(tester), equals(1.0));
        expect(_ignoringPointer(tester), isFalse);
        await tester.tap(find.text('chrome'));
        expect(taps, equals(1));
      });

      testWidgets('hides the chrome at once when the picture flies back', (
        tester,
      ) async {
        final phase = ValueNotifier(VideoTileFlightPhase.landed);
        addTearDown(phase.dispose);
        final flight = ValueNotifier<VideoTileFlightFrame?>(null);
        addTearDown(flight.dispose);
        await _pumpChrome(tester, phase: phase, flight: flight);
        expect(_paintedOpacityOf(tester), equals(1.0));

        phase.value = VideoTileFlightPhase.flying;
        flight.value = _frame(opacity: 1);
        await tester.pump();

        expect(_paintedOpacityOf(tester), equals(0.0));
        expect(_flyingCopy, findsOneWidget);
      });
    });
  });
}
