import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_zoom_indicator.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoRecorderZoomLevelSet(1));
  });

  group(VideoRecorderZoomIndicator, () {
    late _MockVideoRecorderBloc bloc;

    setUp(() {
      bloc = _MockVideoRecorderBloc();
    });

    Widget buildWidget({
      double zoomLevel = 1.0,
      double minZoomLevel = 0.5,
      double maxZoomLevel = 5.0,
      bool showZoomIndicator = true,
      bool isPinchActive = false,
    }) {
      when(() => bloc.state).thenReturn(
        VideoRecorderBlocState(
          zoomLevel: zoomLevel,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          showZoomIndicator: showZoomIndicator,
          isPinchActive: isPinchActive,
          isCameraInitialized: true,
        ),
      );

      return BlocProvider<VideoRecorderBloc>.value(
        value: bloc,
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: VideoRecorderZoomIndicator()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('shows the live zoom value while zooming', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2.4));
        await tester.pumpAndSettle();

        expect(find.text('2.4×'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('drops the trailing .0 on clean zoom factors', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text('1×'), findsOneWidget);
      });
    });

    group('visibility', () {
      testWidgets('is visible while the user is zooming', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('is hidden when not zooming', (tester) async {
        await tester.pumpWidget(buildWidget(showZoomIndicator: false));
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0));
      });

      testWidgets('exposes the zoom level as a semantics label while visible', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderZoomLevelLabel('1')),
          findsOneWidget,
        );
      });

      testWidgets('excludes the zoom semantics label when hidden', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(showZoomIndicator: false));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.bySemanticsLabel(l10n.videoRecorderZoomLevelLabel('1')),
          findsNothing,
        );
      });

      testWidgets('renders nothing when the camera has a single zoom stop', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(minZoomLevel: 1, maxZoomLevel: 1),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedOpacity), findsNothing);
        expect(find.text('1×'), findsNothing);
      });
    });

    group('interaction', () {
      List<VideoRecorderZoomLevelSet> capturedZoomEvents() {
        return verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<VideoRecorderZoomLevelSet>().toList();
      }

      List<MethodCall> recordPlatformCalls() {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              calls.add(call);
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        return calls;
      }

      Iterable<MethodCall> hapticTicks(List<MethodCall> calls) =>
          calls.where((c) => c.method == 'HapticFeedback.vibrate');

      testWidgets('dragging left zooms in', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, greaterThan(2));
      });

      testWidgets('dragging right zooms out', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 3));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(110, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, lessThan(3));
      });

      testWidgets('never dispatches beyond the camera max', (tester) async {
        await tester.pumpWidget(
          buildWidget(zoomLevel: 4.8),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        for (final event in capturedZoomEvents()) {
          expect(event.value, lessThanOrEqualTo(5));
        }
      });

      testWidgets('eases onto a major mark when released nearby', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // 1× dragged ~0.95 lands at a raw 1.95×, inside the 2× detent radius,
        // so the emitted value is pulled snug to 2× rather than left at 1.95×.
        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-104.5, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(2, 0.02));
      });

      testWidgets('reaches a non-integer camera max next to a detent', (
        tester,
      ) async {
        // maxZoom 2.1 sits inside the 2× detent radius; the bound must stay
        // reachable rather than being pulled back toward 2×.
        await tester.pumpWidget(buildWidget(maxZoomLevel: 2.1));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(2.1, 1e-9));
      });

      testWidgets('reaches a non-integer camera min next to a detent', (
        tester,
      ) async {
        // minZoom 0.95 sits inside the 1× detent radius.
        await tester.pumpWidget(buildWidget(minZoomLevel: 0.95));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(1000, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(0.95, 1e-9));
      });

      testWidgets('ticks haptics when crossing a major mark', (tester) async {
        final calls = recordPlatformCalls();

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // 1× → ~2× crosses the 2× whole-factor mark.
        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
        );
        await tester.pumpAndSettle();

        expect(hapticTicks(calls), isNotEmpty);
      });

      testWidgets('ticks the 0.5× stop even when it sits on the camera min', (
        tester,
      ) async {
        final calls = recordPlatformCalls();

        // Default minZoom 0.5 IS the 0.5× stop: the value can only arrive on it
        // from above, never cross below it, yet the detent must still tick.
        await tester.pumpWidget(buildWidget(zoomLevel: 0.7));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(110, 0),
        );
        await tester.pumpAndSettle();

        expect(hapticTicks(calls), isNotEmpty);
      });

      testWidgets('eases onto and ticks the 0.5× stop on an ultra-wide lens', (
        tester,
      ) async {
        final calls = recordPlatformCalls();

        // 0.7× dragged right to a raw 0.45× crosses the 0.5× mark (haptic) and
        // lands inside its detent radius, so the value is pulled toward 0.5×.
        await tester.pumpWidget(buildWidget(zoomLevel: 0.7, minZoomLevel: 0.3));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(27.5, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(0.5, 0.06));
        expect(hapticTicks(calls), isNotEmpty);
      });

      testWidgets('does not spam haptics while pinned against a bound', (
        tester,
      ) async {
        final calls = recordPlatformCalls();

        // One long over-drag pins the value at 5×; it must tick at most once
        // for the 5× mark rather than on every clamped update.
        await tester.pumpWidget(buildWidget(zoomLevel: 4.8));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        expect(hapticTicks(calls).length, lessThanOrEqualTo(1));
      });

      testWidgets('semantic increase nudges the zoom up by a step', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2));
        await tester.pumpAndSettle();

        tester.semantics.increase(
          find.semantics.byAction(SemanticsAction.increase),
        );
        await tester.pump();

        expect(capturedZoomEvents().last.value, closeTo(2.1, 1e-9));
      });

      testWidgets('semantic decrease nudges the zoom down by a step', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2));
        await tester.pumpAndSettle();

        tester.semantics.decrease(
          find.semantics.byAction(SemanticsAction.decrease),
        );
        await tester.pump();

        expect(capturedZoomEvents().last.value, closeTo(1.9, 1e-9));
      });

      testWidgets('semantic increase clamps at the camera max', (tester) async {
        // 4.95× + a 0.1× step overshoots the 5× max and must clamp, not emit
        // 5.05×. Unlike a drag, the nudge clamps without snapping to a detent.
        await tester.pumpWidget(buildWidget(zoomLevel: 4.95));
        await tester.pumpAndSettle();

        tester.semantics.increase(
          find.semantics.byAction(SemanticsAction.increase),
        );
        await tester.pump();

        expect(capturedZoomEvents().last.value, closeTo(5, 1e-9));
      });

      testWidgets('does not capture drags while hidden', (tester) async {
        await tester.pumpWidget(buildWidget(showZoomIndicator: false));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        verifyNever(
          () => bloc.add(any(that: isA<VideoRecorderZoomLevelSet>())),
        );
      });

      testWidgets(
        'does not capture pointers while a preview pinch is in progress',
        (tester) async {
          // Regression: the visible ruler used to swallow the second finger
          // of a pinch with its opaque full-width band, degrading the pinch
          // into a one-finger no-op plus an unintended ruler scrub.
          await tester.pumpWidget(buildWidget(isPinchActive: true));
          await tester.pumpAndSettle();

          await tester.drag(
            find.byType(VideoRecorderZoomIndicator),
            const Offset(-110, 0),
            warnIfMissed: false,
          );
          await tester.pumpAndSettle();

          verifyNever(
            () => bloc.add(any(that: isA<VideoRecorderZoomLevelSet>())),
          );
        },
      );
    });
  });
}
