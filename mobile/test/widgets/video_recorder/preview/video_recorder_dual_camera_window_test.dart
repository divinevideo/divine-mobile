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
      VideoRecorderState recordingState = VideoRecorderState.idle,
      Size box = frame,
      model.AspectRatio aspectRatio = model.AspectRatio.vertical,
    }) async {
      when(() => bloc.state).thenReturn(
        VideoRecorderBlocState(
          isDualCameraEnabled: true,
          secondaryPreviewTextureId: 2,
          dualCameraPipCenter: center,
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
                child: const VideoRecorderDualCameraWindow(),
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
                as VideoRecorderDualCameraPipMoved;
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

        await tester.tap(window());

        verify(() => bloc.add(const VideoRecorderCameraSwitched())).called(1);
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
                as VideoRecorderDualCameraPipMoved;
        expect(moved.center.dx, closeTo(0.5 - 40 / frame.width, 0.02));
        expect(moved.center.dy, closeTo(0.5 + 80 / frame.height, 0.02));
      });
    });
  });
}
