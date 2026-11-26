// ABOUTME: Tests for VideoRecorderCameraPreview widget
// ABOUTME: Validates camera preview rendering, aspect ratio, and grid overlay

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/large_screen_orientation_provider.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_camera_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderCameraPreview Widget Tests', () {
    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    });

    Widget buildSubject({bool ignoresOrientationLock = false}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(_TestClipManagerNotifier.new),
          isFeatureEnabledProvider(
            FeatureFlag.largeScreenLayout,
          ).overrideWithValue(false),
          ignoresOrientationLockOnLargeScreensProvider.overrideWithValue(
            ignoresOrientationLock,
          ),
        ],
        child: BlocProvider<VideoRecorderBloc>.value(
          value: recorderBloc,
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AdaptiveLayoutScope(
              child: Scaffold(body: VideoRecorderCameraPreview()),
            ),
          ),
        ),
      );
    }

    testWidgets('renders camera preview widget', (tester) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(isCameraInitialized: true),
      );

      await tester.pumpWidget(buildSubject());

      expect(find.byType(VideoRecorderCameraPreview), findsOneWidget);
    });

    testWidgets('shows the recorded frame in a narrow landscape window', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(560, 450);
      tester.view.display.devicePixelRatio = 1;
      tester.view.display.size = const Size(1280, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.display.reset);

      await tester.pumpWidget(buildSubject(ignoresOrientationLock: true));

      final preview = find
          .descendant(
            of: find.byType(VideoRecorderCameraPreview),
            matching: find.byType(AspectRatio),
          )
          .first;
      expect(tester.getSize(preview).aspectRatio, closeTo(9 / 16, 0.001));
    });

    testWidgets('displays placeholder when camera not initialized', (
      tester,
    ) async {
      // Camera not initialized - should show placeholder.
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(),
      );

      await tester.pumpWidget(buildSubject());

      // Should show placeholder widget
      expect(find.byType(VideoRecorderCameraPlaceholder), findsOneWidget);
    });

    // Before #3591 this slot rendered
    // `'Camera initialization failed: $e'` — the raw PlatformException
    // toString(), untranslated, full-screen, and on Android carrying the
    // native stack trace that PlatformException interpolates from `details`.
    // These pin that the placeholder now shows localized copy chosen by the
    // reason code, and that the two reasons do not share a message.
    testWidgets('renders localized copy for a failed camera init', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          initializationError: CameraInitializationError.failed,
        ),
      );

      await tester.pumpWidget(buildSubject());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.cameraCouldNotStart), findsOneWidget);
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('initialization failed'), findsNothing);
    });

    testWidgets('renders different copy for an unsupported platform', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          initializationError: CameraInitializationError.unsupportedPlatform,
        ),
      );

      await tester.pumpWidget(buildSubject());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.cameraUnsupportedPlatform), findsOneWidget);
      expect(find.text(l10n.cameraCouldNotStart), findsNothing);
    });

    testWidgets('shows no message at all while init is merely pending', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());

      await tester.pumpWidget(buildSubject());

      final placeholder = tester.widget<VideoRecorderCameraPlaceholder>(
        find.byType(VideoRecorderCameraPlaceholder),
      );
      expect(placeholder.errorMessage, isNull);
    });

    testWidgets('applies no blur filter when not switching cameras', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(isCameraInitialized: true),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('keys the chroma viewfinder onto black, not a checkerboard', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          isCameraInitialized: true,
          isLiveChromaKeySupported: true,
          isChromaKeyEnabled: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // The test renderer has no shader image filter, so the keyed composite
      // never draws here, and what the viewfinder asks for is what can be
      // checked. The bake composites a key with no backdrop onto black, so
      // the viewfinder must show black there too.
      final keyed = tester.widget<ChromaKeyedVideo>(
        find.byType(ChromaKeyedVideo),
      );
      expect(keyed.chromaKey, isNotNull);
      expect(keyed.previewTransparency, isFalse);
      expect(
        find.ancestor(
          of: find.byType(ChromaKeyedVideo),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == VineTheme.backgroundColor,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('blurs the frozen preview while switching cameras', (
      tester,
    ) async {
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(
          isCameraInitialized: true,
          isSwitchingCamera: true,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.byType(ImageFiltered), findsOneWidget);
    });
  });
}

/// Test helper notifier with an empty clip list so the ghost-frame
/// overlay consumed by [VideoRecorderCameraPreview] has no clips to show.
class _TestClipManagerNotifier extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();
}
