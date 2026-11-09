// ABOUTME: Tests for VideoRecorderCountdownOverlay widget
// ABOUTME: Validates countdown display, animations, and visibility states

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_countdown_overlay.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCountdownOverlay Widget Tests', () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildTestWidget() {
      return BlocProvider<VideoRecorderBloc>.value(
        value: recorderBloc,
        child: const MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: VideoRecorderCountdownOverlay()),
        ),
      );
    }

    testWidgets('renders countdown overlay', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });

    testWidgets('is initially invisible when countdown is 0', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );

      expect(animatedOpacity.opacity, equals(0));
    });

    testWidgets('uses IgnorePointer for touch blocking', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(
        find.descendant(
          of: find.byType(VideoRecorderCountdownOverlay),
          matching: find.byType(IgnorePointer),
        ),
        findsOneWidget,
      );
    });

    testWidgets('contains AnimatedOpacity for fade transitions', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(AnimatedOpacity), findsOneWidget);
    });

    group('between stop-motion interval stills', () {
      setUp(() {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(
            isIntervalCaptureRunning: true,
            countdownValue: 2,
          ),
        );
      });

      testWidgets('lets the shutter underneath stop the loop', (tester) async {
        var shutterTaps = 0;
        await tester.pumpWidget(
          BlocProvider<VideoRecorderBloc>.value(
            value: recorderBloc,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Stack(
                  children: [
                    Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => shutterTaps++,
                        child: const SizedBox.square(dimension: 96),
                      ),
                    ),
                    const VideoRecorderCountdownOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        await tester.tapAt(tester.getCenter(find.byType(Scaffold)));
        expect(shutterTaps, equals(1));
      });

      testWidgets('leaves the preview undimmed', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final backdrop = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(VideoRecorderCountdownOverlay),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(backdrop.color.a, equals(0));
      });
    });

    testWidgets('updates when countdown value changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      expect(find.byType(VideoRecorderCountdownOverlay), findsOneWidget);
    });

    testWidgets('keeps a two-digit count clear of the side controls at the '
        'largest text size', (tester) async {
      // An iPhone SE at the largest iOS text size.
      const screenWidth = 375.0;
      tester.view
        ..physicalSize = const Size(screenWidth, 667)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.12;
      addTearDown(() {
        tester.view
          ..resetPhysicalSize()
          ..resetDevicePixelRatio();
        tester.platformDispatcher.clearAllTestValues();
      });
      when(
        () => recorderBloc.state,
      ).thenReturn(const VideoRecorderBlocState(countdownValue: 10));

      await tester.pumpWidget(buildTestWidget());

      // The capture side rail takes about 72px from the right edge, and the
      // count is centered, so it has to stay that far in on both sides.
      const sideRailInset = 72.0;
      expect(
        tester.getSize(find.text('10')).width,
        lessThan(screenWidth - 2 * sideRailInset),
      );
    });
  });
}
