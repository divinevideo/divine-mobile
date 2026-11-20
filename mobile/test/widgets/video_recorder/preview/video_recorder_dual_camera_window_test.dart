import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart'
    show SecondaryCameraPreviewWidget;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/secondary_camera_take.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_dual_camera_window.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  group(VideoRecorderDualCameraWindow, () {
    // A viewfinder of the frame's own shape: the window is measured against
    // all of it.
    const frame = Size(270, 480);
    late _MockVideoRecorderBloc bloc;

    setUpAll(() {
      registerFallbackValue(const VideoRecorderDualCameraToggled());
    });

    setUp(() {
      bloc = _MockVideoRecorderBloc();
    });

    Future<void> pump(
      WidgetTester tester, {
      Offset center = SecondaryCameraTake.defaultPipCenter,
      double scale = 1,
      double rotation = 0,
      model.AspectRatio shape = model.AspectRatio.vertical,
      VideoRecorderState recordingState = VideoRecorderState.idle,
      Size box = frame,
      model.AspectRatio aspectRatio = model.AspectRatio.vertical,
      Stream<VideoRecorderBlocState>? states,
      Key? windowKey,
    }) async {
      if (states != null) when(() => bloc.stream).thenAnswer((_) => states);
      when(() => bloc.state).thenReturn(
        VideoRecorderBlocState(
          isDualCameraEnabled: true,
          secondaryPreviewTextureId: 2,
          dualCameraPipCenter: center,
          dualCameraPipScale: scale,
          dualCameraPipRotation: rotation,
          dualCameraPipAspectRatio: shape,
          recordingState: recordingState,
          cameraSensorAspectRatio: 9 / 16,
          aspectRatio: aspectRatio,
        ),
      );
      await tester.pumpWidget(
        BlocProvider<VideoRecorderBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Align(
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(
                size: box,
                child: VideoRecorderDualCameraWindow(key: windowKey),
              ),
            ),
          ),
        ),
      );
    }

    Finder window() =>
        find.bySemanticsIdentifier(SemanticIds.cameraDualCameraWindow);

    group('renders', () {
      testWidgets('shows the second camera where the window was placed', (
        tester,
      ) async {
        await pump(tester, center: const Offset(0.25, 0.5));

        expect(find.byType(SecondaryCameraPreviewWidget), findsOneWidget);
        final rect = tester.getRect(find.byType(SecondaryCameraPreviewWidget));
        expect(
          rect.width,
          closeTo(frame.width * SecondaryCameraTake.pipWidthFraction, 0.01),
        );
        expect(rect.center.dx, closeTo(frame.width * 0.25, 0.01));
        expect(rect.center.dy, closeTo(frame.height * 0.5, 0.01));
      });

      testWidgets('shows the window as large and as turned as it was left', (
        tester,
      ) async {
        await pump(
          tester,
          center: const Offset(0.5, 0.5),
          scale: 1.5,
          rotation: 0.5,
        );

        final size = tester.getSize(find.byType(SecondaryCameraPreviewWidget));
        expect(
          size.width,
          closeTo(
            frame.width * SecondaryCameraTake.pipWidthFraction * 1.5,
            0.01,
          ),
        );
        final turn = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byType(SecondaryCameraPreviewWidget),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(turn.transform.storage[1], closeTo(math.sin(0.5), 1e-9));
      });

      testWidgets('shows a square window as tall as it is wide', (
        tester,
      ) async {
        await pump(tester, shape: model.AspectRatio.square);

        final size = tester.getSize(find.byType(SecondaryCameraPreviewWidget));
        expect(
          size.width,
          closeTo(frame.width * SecondaryCameraTake.pipWidthFraction, 0.01),
        );
        expect(size.height, closeTo(size.width, 0.01));
      });

      testWidgets('eases into a new shape', (tester) async {
        final states = StreamController<VideoRecorderBlocState>();
        addTearDown(states.close);
        await pump(tester, states: states.stream);
        final width = frame.width * SecondaryCameraTake.pipWidthFraction;

        final square = bloc.state.copyWith(
          dualCameraPipAspectRatio: model.AspectRatio.square,
        );
        when(() => bloc.state).thenReturn(square);
        states.add(square);
        await tester.pump();
        await tester.pump(VideoRecorderDualCameraWindow.resizeDuration ~/ 2);

        final halfway = tester.getSize(
          find.byType(SecondaryCameraPreviewWidget),
        );
        expect(halfway.height, lessThan(width * 16 / 9));
        expect(halfway.height, greaterThan(width));

        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(SecondaryCameraPreviewWidget)).height,
          closeTo(width, 0.01),
        );
      });

      testWidgets('rounds the window like the editor masks the take', (
        tester,
      ) async {
        await pump(tester);

        final clip = tester.widget<ClipRRect>(
          find.ancestor(
            of: find.byType(SecondaryCameraPreviewWidget),
            matching: find.byType(ClipRRect),
          ),
        );
        final width = frame.width * SecondaryCameraTake.pipWidthFraction;
        expect(
          clip.borderRadius,
          BorderRadius.circular(
            width / 2 * SecondaryCameraTake.pipCornerRadius,
          ),
        );
      });

      testWidgets('keeps a window placed at a corner whole inside the frame', (
        tester,
      ) async {
        await pump(tester, center: const Offset(1, 1));

        final rect = tester.getRect(find.byType(SecondaryCameraPreviewWidget));
        expect(rect.right, closeTo(frame.width, 0.01));
        expect(rect.bottom, closeTo(frame.height, 0.01));
      });
    });

    group('on a viewfinder that cuts the frame', () {
      // A phone taller than 9:16: the preview covers it with the frame,
      // whose sides reach past the screen.
      const tall = Size(270, 585);
      const frameWidth = 585 * 9 / 16;

      testWidgets('sizes the window against the whole frame', (tester) async {
        await pump(tester, center: const Offset(0.5, 0.5), box: tall);

        final rect = tester.getRect(find.byType(SecondaryCameraPreviewWidget));
        expect(
          rect.width,
          closeTo(frameWidth * SecondaryCameraTake.pipWidthFraction, 0.01),
          reason:
              'the post keeps the whole frame, so the window is as wide '
              'as it will be there',
        );
        expect(rect.center.dx, closeTo(tall.width / 2, 0.01));
      });

      testWidgets('moves a position it cannot show whole to where it shows', (
        tester,
      ) async {
        await pump(tester, center: const Offset(0.05, 0.5), box: tall);
        await tester.pump();

        final rect = tester.getRect(find.byType(SecondaryCameraPreviewWidget));
        expect(rect.left, closeTo(0, 0.01));
        final moved =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        final frameLeft = (tall.width - frameWidth) / 2;
        expect(
          moved.center.dx,
          closeTo((rect.center.dx - frameLeft) / frameWidth, 0.001),
          reason: 'the take lands where the window was seen',
        );
      });
    });

    group('on a square take', () {
      testWidgets('measures the window against the square it keeps', (
        tester,
      ) async {
        await pump(
          tester,
          center: const Offset(0.5, 0.3),
          box: const Size(300, 300),
          aspectRatio: model.AspectRatio.square,
        );

        final rect = tester.getRect(find.byType(SecondaryCameraPreviewWidget));
        expect(
          rect.width,
          closeTo(300 * SecondaryCameraTake.pipWidthFraction, 0.01),
        );
        expect(rect.center.dy, closeTo(0.3 * 300, 0.01));
      });
    });

    group('interactions', () {
      testWidgets('tapping swaps the cameras', (tester) async {
        await pump(tester);

        // A finger on the device stays down across frames.
        final finger = await tester.startGesture(tester.getCenter(window()));
        await tester.pump();
        await finger.up();
        await tester.pump();

        verify(() => bloc.add(const VideoRecorderCameraSwitched())).called(1);
      });

      testWidgets('a long press switches the window between portrait and '
          'square', (tester) async {
        await pump(tester);

        await tester.longPress(window());

        verify(
          () => bloc.add(const VideoRecorderDualCameraPipShapeToggled()),
        ).called(1);
        verifyNever(() => bloc.add(const VideoRecorderCameraSwitched()));
      });

      testWidgets('two fingers that rest before spreading still pinch', (
        tester,
      ) async {
        await pump(tester, center: const Offset(0.5, 0.5));
        final center = tester.getCenter(window());

        final top = await tester.startGesture(center - const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 50));
        final bottom = await tester.startGesture(center + const Offset(0, 40));
        // Longer than a long press.
        await tester.pump(const Duration(milliseconds: 700));
        await top.moveBy(const Offset(0, -20));
        await tester.pump();
        await bottom.moveBy(const Offset(0, 20));
        await tester.pump();
        await top.up();
        await bottom.up();
        await tester.pump();

        final changed =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        expect(changed.scale, closeTo(1.5, 0.01));
      });

      testWidgets('a finger held through a long press still pinches with a '
          'second one', (tester) async {
        await pump(tester, center: const Offset(0.5, 0.3));
        final center = tester.getCenter(window());

        final held = await tester.startGesture(center);
        await tester.pump(const Duration(milliseconds: 700));
        final beside = await tester.startGesture(
          center + const Offset(0, 120),
        );
        await tester.pump();
        await beside.moveBy(const Offset(0, 60));
        await tester.pump();
        await held.up();
        await beside.up();
        await tester.pump();

        final events = verify(() => bloc.add(captureAny())).captured;
        expect(events.first, isA<VideoRecorderDualCameraPipShapeToggled>());
        final changed = events.last as VideoRecorderDualCameraPipChanged;
        expect(changed.scale, closeTo(1.5, 0.01));
        // The fingers' midpoint moved 30 down; the window follows it.
        expect(changed.center.dy, closeTo(0.3 + 30 / frame.height, 0.01));
        verifyNever(() => bloc.add(const VideoRecorderCameraSwitched()));
      });

      testWidgets('a drag the camera rebuild cuts off still puts the window '
          'down', (tester) async {
        await pump(
          tester,
          center: const Offset(0.5, 0.5),
          windowKey: const ValueKey(1),
        );
        final finger = await tester.startGesture(tester.getCenter(window()));
        await tester.pump();
        await finger.moveBy(const Offset(30, 0));
        await tester.pump();
        await finger.moveBy(const Offset(10, 0));
        await tester.pump();

        // The camera stack re-keys its children after a camera switch.
        await pump(
          tester,
          center: const Offset(0.5, 0.5),
          windowKey: const ValueKey(2),
        );
        await finger.up();
        await tester.pump();

        expect(tester.takeException(), isNull);
        final changed =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        expect(changed.center.dx, closeTo(0.5 + 40 / frame.width, 0.01));
      });

      testWidgets('two fingers that barely move do not swap the cameras', (
        tester,
      ) async {
        await pump(tester);
        final center = tester.getCenter(window());

        final top = await tester.startGesture(center - const Offset(0, 20));
        await tester.pump();
        final bottom = await tester.startGesture(center + const Offset(0, 20));
        await tester.pump();
        await top.up();
        await tester.pump();
        await bottom.up();
        await tester.pump();

        verifyNever(() => bloc.add(const VideoRecorderCameraSwitched()));
      });

      testWidgets('does not swap while a take is recording', (tester) async {
        await pump(tester, recordingState: VideoRecorderState.recording);

        await tester.tap(window(), warnIfMissed: false);

        verifyNever(() => bloc.add(const VideoRecorderCameraSwitched()));
      });

      testWidgets('dragging moves the window and reports where it ended', (
        tester,
      ) async {
        await pump(tester, center: const Offset(0.5, 0.5));

        await tester.drag(window(), const Offset(-40, 80));
        await tester.pump();

        final moved =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        expect(moved.center.dx, closeTo(0.5 - 40 / frame.width, 0.01));
        expect(moved.center.dy, closeTo(0.5 + 80 / frame.height, 0.01));
        expect(moved.scale, 1);
        expect(moved.rotation, 0);
      });

      testWidgets('follows a dragging finger without easing', (tester) async {
        await pump(tester, center: const Offset(0.5, 0.5));
        final start = tester.getCenter(window());

        final finger = await tester.startGesture(start);
        await tester.pump();
        await finger.moveBy(const Offset(30, 0));
        await tester.pump();
        await finger.moveBy(const Offset(10, 0));
        await tester.pump();

        expect(tester.getCenter(window()).dx, closeTo(start.dx + 40, 0.01));
        await finger.up();
      });

      testWidgets('pinching the window resizes it', (tester) async {
        await pump(tester, center: const Offset(0.5, 0.5));
        final center = tester.getCenter(window());

        final top = await tester.startGesture(center - const Offset(0, 40));
        final bottom = await tester.startGesture(center + const Offset(0, 40));
        await tester.pump();
        await top.moveBy(const Offset(0, -20));
        await tester.pump();
        await bottom.moveBy(const Offset(0, 20));
        await tester.pump();
        await top.up();
        await bottom.up();
        await tester.pump();

        final changed =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        expect(changed.scale, closeTo(1.5, 0.01));
        expect(changed.center.dy, closeTo(0.5, 0.01));
      });

      testWidgets(
        'a second finger beside the window joins the pinch instead of the '
        'viewfinder',
        (tester) async {
          await pump(tester, center: const Offset(0.5, 0.3));
          final center = tester.getCenter(window());

          final onWindow = await tester.startGesture(center);
          await tester.pump();
          // Below the window, which reaches 72 down from its center.
          final beside = await tester.startGesture(
            center + const Offset(0, 120),
          );
          await tester.pump();
          await beside.moveBy(const Offset(0, 60));
          await onWindow.up();
          await beside.up();
          await tester.pump();

          final changed =
              verify(() => bloc.add(captureAny())).captured.single
                  as VideoRecorderDualCameraPipChanged;
          expect(changed.scale, closeTo(1.5, 0.01));
        },
      );

      testWidgets('turning the window settles it at a quarter turn when '
          'close', (tester) async {
        await pump(tester, center: const Offset(0.5, 0.5));
        final center = tester.getCenter(window());

        final left = await tester.startGesture(center - const Offset(30, 0));
        final right = await tester.startGesture(center + const Offset(30, 0));
        await tester.pump();
        // Nearly a quarter turn clockwise: about 2.3° past it.
        await left.moveTo(center - const Offset(-1.2, 30));
        await right.moveTo(center + const Offset(-1.2, 30));
        await left.up();
        await right.up();
        await tester.pump();

        final changed =
            verify(() => bloc.add(captureAny())).captured.single
                as VideoRecorderDualCameraPipChanged;
        // The fingers' turn may come out a full circle off; the recorder
        // stores it the short way round.
        expect(
          changed.rotation % (2 * math.pi),
          closeTo(math.pi / 2, 1e-12),
        );
      });
    });
  });
}
