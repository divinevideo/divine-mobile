import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_mobile_preview.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

/// Reports an initialized camera so [CameraPreviewWidget] renders its live
/// texture and gesture detector. Without this it falls back to `loadingWidget`,
/// which contributes no semantics at all — and then nothing in this file can
/// tell an excluded preview from an unexcluded one.
class _FakeCameraPlatform extends DivineCameraPlatform {
  @override
  void Function(VideoRecordingResult result)? onRecordingAutoStopped;

  @override
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    return const CameraState(isInitialized: true, textureId: 1);
  }

  @override
  Future<void> disposeCamera() async {}
}

void main() {
  group(VideoRecorderMobilePreview, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final initialPlatform = DivineCameraPlatform.instance;

    late _MockVideoRecorderBloc recorderBloc;

    setUp(() async {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(),
      );
      DivineCameraPlatform.instance = _FakeCameraPlatform();
      await DivineCamera.instance.initialize();
    });

    tearDown(() async {
      // Restore both process globals: the camera singleton's state and the
      // platform instance. Either one left mutated leaks into every later
      // suite in the merged isolate.
      await DivineCamera.instance.dispose();
      DivineCameraPlatform.instance = initialPlatform;
    });

    Widget buildSubject({required bool enableTapToFocus}) {
      return BlocProvider<VideoRecorderBloc>.value(
        value: recorderBloc,
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoRecorderMobilePreview(
              enableTapToFocus: enableTapToFocus,
            ),
          ),
        ),
      );
    }

    /// The stops a screen reader would land on, narrowed to the tappable ones.
    Iterable<SemanticsNode> tappableStops(WidgetTester tester) {
      return tester.semantics.simulatedAccessibilityTraversal().where(
        (n) => n.getSemanticsData().hasAction(SemanticsAction.tap),
      );
    }

    testWidgets('describes the camera preview and tap-to-focus action', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildSubject(enableTapToFocus: true));

        final node = tester.getSemantics(
          find.bySemanticsLabel(l10n.videoRecorderCameraPreviewLabel),
        );
        final data = node.getSemanticsData();

        expect(data.label, l10n.videoRecorderCameraPreviewLabel);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(
          node.hintOverrides?.onTapHint,
          l10n.videoRecorderCameraPreviewFocusHint,
        );

        // The preview's own gesture detector is excluded, so the labeled node
        // is the only tappable stop — the reader gets one, not two.
        expect(tappableStops(tester), hasLength(1));

        node.owner!.performAction(node.id, SemanticsAction.tap);
        verify(
          () => recorderBloc.add(
            const VideoRecorderFocusPointSet(Offset(0.5, 0.5)),
          ),
        ).called(1);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('is not a traversal stop when tap-to-focus is disabled', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildSubject(enableTapToFocus: false));

        expect(
          find.bySemanticsLabel(l10n.videoRecorderCameraPreviewLabel),
          findsNothing,
        );
        // An inert preview still builds a tappable gesture detector, so this
        // fails the moment the ExcludeSemantics around it is dropped.
        expect(tappableStops(tester), isEmpty);
      } finally {
        semanticsHandle.dispose();
      }
    });
  });
}
