import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_library_button.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderLibraryButton, () {
    late _MockClipLibraryService mockClipLibraryService;
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      mockClipLibraryService = _MockClipLibraryService();
      recorderBloc = _MockVideoRecorderBloc();

      when(
        () => mockClipLibraryService.getAllClips(),
      ).thenAnswer((_) async => []);
    });

    Widget buildWidget({
      List<DivineVideoClip>? clips,
      VideoRecorderBlocState recorderState = const VideoRecorderBlocState(),
      bool interactive = true,
    }) {
      whenListen(
        recorderBloc,
        const Stream<VideoRecorderBlocState>.empty(),
        initialState: recorderState,
      );
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _TestClipManagerNotifier(clips: clips ?? []),
          ),
          clipLibraryServiceProvider.overrideWithValue(mockClipLibraryService),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<VideoRecorderBloc>.value(
              value: recorderBloc,
              child: VideoRecorderLibraryButton(interactive: interactive),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $VideoRecorderLibraryButton', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(VideoRecorderLibraryButton), findsOneWidget);
      });

      testWidgets('renders container with rounded shape', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(Container), findsWidgets);
      });

      testWidgets('renders GestureDetector for tap', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.byType(GestureDetector), findsWidgets);
      });
    });

    group('badge count', () {
      testWidgets('does not show badge when clips is empty', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // The badge uses SizedBox.shrink when count == 0
        expect(find.text('0'), findsNothing);
      });

      testWidgets('shows badge with clip count', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
          DivineVideoClip(
            id: 'clip2',
            video: EditorVideo.file('/test/clip2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('shows badge with 1 for single clip', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);
      });
    });

    group('accessibility', () {
      testWidgets('has no-clips semantic label when empty', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Clip library, no clips'), findsOneWidget);
      });

      testWidgets('has clip count semantic label with clips', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
          ),
          DivineVideoClip(
            id: 'clip2',
            video: EditorVideo.file('/test/clip2.mp4'),
            duration: const Duration(seconds: 3),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb2.jpg',
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(
          semantics.properties.label,
          equals('Open clip library, 2 clips'),
        );
      });

      testWidgets('singular label for single clip', (tester) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            thumbnailPath: '/test/thumb1.jpg',
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.label, equals('Open clip library, 1 clip'));
      });

      testWidgets('is marked as button in semantics', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final semantics = tester.getSemantics(
          find.bySemanticsLabel('Clip library, no clips'),
        );
        expect(semantics.flagsCollection.isButton, isTrue);
      });

      // Anchor for the Maestro capture-mode flow
      // (e2e/maestro/asserts/assertCaptureMode.yaml). The label assertions
      // above go through unchanged if the identifier is dropped, so it needs
      // its own guard.
      testWidgets('exposes an E2E identifier', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier(SemanticIds.cameraLibraryButton),
          findsOneWidget,
        );
      });
    });

    group('disabled state', () {
      testWidgets('GestureDetector onTap is null when no clips', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final detector = tester
            .widgetList<GestureDetector>(
              find.descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(GestureDetector),
              ),
            )
            .first;
        expect(detector.onTap, isNull);
      });
    });

    group('enabled/onTap consistency', () {
      testWidgets('GestureDetector onTap is non-null when clips exist '
          'but thumbnailPath is null', (tester) async {
        // Session clips without thumbnails — button should still be enabled
        final clips = [
          DivineVideoClip(
            id: 'clip-no-thumb',
            video: EditorVideo.file('/test/clip.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
            // thumbnailPath intentionally null
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        final detector = tester
            .widgetList<GestureDetector>(
              find.descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(GestureDetector),
              ),
            )
            .first;
        expect(detector.onTap, isNotNull);
      });

      testWidgets('GestureDetector onTap is non-null when no session clips '
          'but library has clips', (tester) async {
        // No session clips, but library service returns clips
        final libraryClip = DivineVideoClip(
          id: 'lib-clip',
          video: EditorVideo.file('/lib/clip.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
          thumbnailPath: '/lib/thumb.jpg',
        );

        when(
          () => mockClipLibraryService.getAllClips(),
        ).thenAnswer((_) async => [libraryClip]);

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final detector = tester
            .widgetList<GestureDetector>(
              find.descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(GestureDetector),
              ),
            )
            .first;
        expect(detector.onTap, isNotNull);
      });

      testWidgets('Semantics.enabled matches GestureDetector.onTap presence', (
        tester,
      ) async {
        final clips = [
          DivineVideoClip(
            id: 'clip1',
            video: EditorVideo.file('/test/clip1.mp4'),
            duration: const Duration(seconds: 2),
            recordedAt: DateTime.now(),
            targetAspectRatio: .vertical,
            originalAspectRatio: 9 / 16,
          ),
        ];

        await tester.pumpWidget(buildWidget(clips: clips));
        await tester.pumpAndSettle();

        final detector = tester
            .widgetList<GestureDetector>(
              find.descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(GestureDetector),
              ),
            )
            .first;
        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );

        // Both should agree: button is enabled
        expect(detector.onTap, isNotNull);
        expect(semantics.properties.enabled, isTrue);
      });
    });

    group('thumbnail', () {
      testWidgets('shows empty state when no clips and no library', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // No Image.file should appear
        expect(find.byType(Image), findsNothing);
      });

      testWidgets('loads library thumbnail on init', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        verify(() => mockClipLibraryService.getAllClips()).called(1);
      });
    });

    group('stop-motion capture', () {
      const stopMotionState = VideoRecorderBlocState(
        recorderMode: VideoRecorderMode.stopMotion,
        stopMotionFrames: ['/frames/a.jpg', '/frames/b.jpg', '/frames/c.jpg'],
      );

      testWidgets('badge shows the captured-frame count, not clip count', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(recorderState: stopMotionState));
        await tester.pump();

        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('thumbnail is the last captured frame', (tester) async {
        await tester.pumpWidget(buildWidget(recorderState: stopMotionState));
        await tester.pump();

        expect(find.byKey(const ValueKey('/frames/c.jpg')), findsOneWidget);
      });

      testWidgets('semantic label counts captured frames, not clips', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(recorderState: stopMotionState));
        await tester.pump();

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          semantics.properties.label,
          equals(l10n.videoRecorderLibraryOpenStopMotionLabel(3)),
        );
        // The stills must not be announced as clips.
        expect(
          semantics.properties.label,
          isNot(equals(l10n.videoRecorderLibraryOpenLabel(3))),
        );
      });

      testWidgets('no badge before the first frame is captured', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            recorderState: const VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.stopMotion,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('0'), findsNothing);
      });
    });

    group('library fallback per mode', () {
      final videoClip = DivineVideoClip(
        id: 'lib-video',
        video: EditorVideo.file('/lib/video.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2024),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/lib/video_thumb.jpg',
      );
      final stopMotionClip = DivineVideoClip(
        id: 'lib-sm',
        stopMotionFrames: const [
          StopMotionClipFrame(
            path: '/lib/sm_thumb.jpg',
            duration: Duration(milliseconds: 42),
          ),
        ],
        duration: const Duration(milliseconds: 42),
        recordedAt: DateTime(2024),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
        thumbnailPath: '/lib/sm_thumb.jpg',
      );

      testWidgets(
        'stop-motion mode previews the newest stop-motion set, not the '
        'newest video clip',
        (tester) async {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [videoClip, stopMotionClip]);

          await tester.pumpWidget(
            buildWidget(
              recorderState: const VideoRecorderBlocState(
                recorderMode: VideoRecorderMode.stopMotion,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('/lib/sm_thumb.jpg')), findsOne);
          expect(
            find.byKey(const ValueKey('/lib/video_thumb.jpg')),
            findsNothing,
          );
        },
      );

      testWidgets(
        'capture mode previews the newest video clip, not the newest '
        'stop-motion set',
        (tester) async {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [stopMotionClip, videoClip]);

          await tester.pumpWidget(buildWidget());
          await tester.pumpAndSettle();

          expect(find.byKey(const ValueKey('/lib/video_thumb.jpg')), findsOne);
          expect(find.byKey(const ValueKey('/lib/sm_thumb.jpg')), findsNothing);
        },
      );

      testWidgets(
        'stop-motion mode stays empty when the library only holds video '
        'clips',
        (tester) async {
          when(
            () => mockClipLibraryService.getAllClips(),
          ).thenAnswer((_) async => [videoClip]);

          await tester.pumpWidget(
            buildWidget(
              recorderState: const VideoRecorderBlocState(
                recorderMode: VideoRecorderMode.stopMotion,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(Image), findsNothing);
          final detector = tester.widget<GestureDetector>(
            find.byType(GestureDetector),
          );
          expect(detector.onTap, isNull);
        },
      );
    });

    group('non-interactive (editor-hosted recorder)', () {
      testWidgets('still shows the capture count but cannot be pressed', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            interactive: false,
            recorderState: const VideoRecorderBlocState(
              recorderMode: VideoRecorderMode.stopMotion,
              stopMotionFrames: ['/frames/a.jpg', '/frames/b.jpg'],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('2'), findsOneWidget);
        final detector = tester.widget<GestureDetector>(
          find.byType(GestureDetector),
        );
        expect(detector.onTap, isNull);

        final semantics = tester.widget<Semantics>(
          find
              .descendant(
                of: find.byType(VideoRecorderLibraryButton),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(semantics.properties.enabled, isFalse);
        expect(semantics.properties.button, isFalse);
      });
    });
  });
}

class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier({required this.clips});

  @override
  final List<DivineVideoClip> clips;

  @override
  ClipManagerState build() {
    return ClipManagerState(clips: clips);
  }
}
