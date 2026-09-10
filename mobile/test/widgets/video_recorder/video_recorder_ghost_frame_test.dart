// ABOUTME: Tests for VideoRecorderGhostFrame widget
// ABOUTME: Validates ghost frame overlay rendering and AnimatedSwitcher behavior

import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_camera/divine_camera.dart' show CameraLensMetadata;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_ghost_frame.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderGhostFrame, () {
    late _MockVideoRecorderBloc recorderBloc;
    late File tempFile;

    setUp(() async {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());

      // Create a minimal valid PNG file for Image.file
      tempFile = File('${Directory.systemTemp.path}/ghost_frame_test.png');
      // 1x1 transparent PNG
      await tempFile.writeAsBytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x62, 0x00, 0x00, 0x00, 0x02,
        0x00, 0x01, 0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
        0x60, 0x82, // IEND chunk
      ]);
    });

    tearDown(() async {
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
    });

    DivineVideoClip createClip({
      String? ghostFramePath,
      CameraLensMetadata? lensMetadata,
    }) {
      return DivineVideoClip(
        id: 'clip_test',
        video: EditorVideo.file('/path/to/video.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        ghostFramePath: ghostFramePath,
        lensMetadata: lensMetadata,
      );
    }

    Widget buildTestWidget({
      bool showLastClipOverlay = false,
      List<DivineVideoClip> clips = const [],
    }) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(showLastClipOverlay: showLastClipOverlay),
      );
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(() {
            return _TestClipManagerNotifier(clips);
          }),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoRecorderGhostFrame()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$SizedBox when showOverlay is false', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(clips: [createClip(ghostFramePath: tempFile.path)]),
        );

        // Default showLastClipOverlay is false
        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
      });

      testWidgets('$SizedBox when no ghost frame exists', (tester) async {
        await tester.pumpWidget(buildTestWidget(clips: [createClip()]));

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
      });

      testWidgets('$SizedBox when no clips exist', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(SizedBox), findsOneWidget);
        expect(find.byType(Opacity), findsNothing);
      });

      testWidgets('$AnimatedSwitcher', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        expect(find.byType(AnimatedSwitcher), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('wraps overlay in $IgnorePointer', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            showLastClipOverlay: true,
            clips: [createClip(ghostFramePath: tempFile.path)],
          ),
        );

        // Our IgnorePointer has ignoring: true and a ValueKey
        expect(
          find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
          findsOneWidget,
        );
      });

      testWidgets('uses last clip with ghost frame path', (tester) async {
        final clipWithGhost = DivineVideoClip(
          id: 'clip_1',
          video: EditorVideo.file('/path/to/video1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          ghostFramePath: tempFile.path,
        );
        final clipWithoutGhost = DivineVideoClip(
          id: 'clip_2',
          video: EditorVideo.file('/path/to/video2.mp4'),
          duration: const Duration(seconds: 1),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        );

        await tester.pumpWidget(
          buildTestWidget(
            showLastClipOverlay: true,
            clips: [clipWithGhost, clipWithoutGhost],
          ),
        );

        // Should still show the ghost frame from clip_1
        expect(
          find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.48),
          findsOneWidget,
        );
      });

      testWidgets('applies $Transform.flip for front camera clips', (
        tester,
      ) async {
        final frontCameraClip = DivineVideoClip(
          id: 'front_cam_clip',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          ghostFramePath: tempFile.path,
          lensMetadata: const CameraLensMetadata(lensType: 'front'),
        );

        await tester.pumpWidget(
          buildTestWidget(
            showLastClipOverlay: true,
            clips: [frontCameraClip],
          ),
        );

        // Find Transform widget with flipX enabled
        final transformFinder = find.byWidgetPredicate(
          (w) => w is Transform && w.transform.getColumn(0)[0] == -1.0,
        );
        expect(transformFinder, findsOneWidget);
      });

      testWidgets('does not flip for back camera clips', (tester) async {
        final backCameraClip = DivineVideoClip(
          id: 'back_cam_clip',
          video: EditorVideo.file('/path/to/video.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          ghostFramePath: tempFile.path,
          lensMetadata: const CameraLensMetadata(lensType: 'back'),
        );

        await tester.pumpWidget(
          buildTestWidget(
            showLastClipOverlay: true,
            clips: [backCameraClip],
          ),
        );

        // Transform with flipX=false has matrix[0][0] == 1.0
        final transformFinder = find.byWidgetPredicate(
          (w) => w is Transform && w.transform.getColumn(0)[0] == 1.0,
        );
        expect(transformFinder, findsOneWidget);
      });
    });

    group('stop-motion ghost', () {
      Widget buildStopMotionWidget({required bool isFrontCamera}) {
        when(() => recorderBloc.state).thenReturn(
          VideoRecorderBlocState(
            recorderMode: VideoRecorderMode.stopMotion,
            showLastClipOverlay: true,
            stopMotionFrames: [tempFile.path],
            isFrontCamera: isFrontCamera,
          ),
        );
        return ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _TestClipManagerNotifier(const []),
            ),
          ],
          child: BlocProvider<VideoRecorderBloc>.value(
            value: recorderBloc,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoRecorderGhostFrame()),
            ),
          ),
        );
      }

      testWidgets('flips the last still while the front lens is active', (
        tester,
      ) async {
        await tester.pumpWidget(buildStopMotionWidget(isFrontCamera: true));

        // The live preview is mirrored for the front camera, so the ghost of
        // the last still must be flipped (matrix[0][0] == -1) to line up.
        expect(
          find.byWidgetPredicate(
            (w) => w is Transform && w.transform.getColumn(0)[0] == -1.0,
          ),
          findsOneWidget,
        );
      });

      testWidgets(
        'does not flip the last still while the back lens is active',
        (
          tester,
        ) async {
          await tester.pumpWidget(buildStopMotionWidget(isFrontCamera: false));

          expect(
            find.byWidgetPredicate(
              (w) => w is Transform && w.transform.getColumn(0)[0] == 1.0,
            ),
            findsOneWidget,
          );
        },
      );
    });

    group('decode bounds', () {
      testWidgets('bounds the ghost frame decode with cacheHeight', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            showLastClipOverlay: true,
            clips: [createClip(ghostFramePath: tempFile.path)],
          ),
        );

        // A cacheHeight wraps the FileImage in a ResizeImage; without it the
        // full-resolution still is decoded onto the full-screen live overlay.
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.image, isA<ResizeImage>());

        final context = tester.element(find.byType(VideoRecorderGhostFrame));
        final expected =
            (MediaQuery.sizeOf(context).height *
                    MediaQuery.devicePixelRatioOf(context))
                .round();
        expect((image.image as ResizeImage).height, expected);
      });
    });
  });
}

/// Test helper notifier that pre-populates clips.
class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier(this._initialClips);

  final List<DivineVideoClip> _initialClips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: _initialClips);
  }
}
