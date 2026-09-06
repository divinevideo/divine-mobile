import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDivineCameraPlatform
    with MockPlatformInterfaceMixin
    implements DivineCameraPlatform {
  CameraState _state = const CameraState();
  void Function(VideoRecordingResult result)? _onRecordingAutoStopped;
  void Function(RemoteRecordTrigger trigger)? _onRemoteRecordTrigger;

  @override
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    _onRecordingAutoStopped = callback;
  }

  @override
  void Function(RemoteRecordTrigger trigger)? get onRemoteRecordTrigger =>
      _onRemoteRecordTrigger;

  @override
  set onRemoteRecordTrigger(
    void Function(RemoteRecordTrigger trigger)? callback,
  ) {
    _onRemoteRecordTrigger = callback;
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async =>
      true;

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async => true;

  @override
  Future<List<AudioDevice>> listAudioDevices() async => const [];

  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    return _state = CameraState(
      isInitialized: true,
      lens: lens,
      hasFlash: true,
      hasFrontCamera: true,
      hasBackCamera: true,
      maxZoomLevel: 10,
      textureId: 1,
      isFocusPointSupported: true,
      isExposurePointSupported: true,
    );
  }

  @override
  Future<void> disposeCamera() async {
    _state = const CameraState();
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async => true;

  @override
  Future<bool> setFocusPoint(Offset offset) async => true;

  @override
  Future<bool> setExposurePoint(Offset offset) async => true;

  @override
  Future<bool> cancelFocusAndMetering() async => true;

  @override
  Future<CameraZoomState?> setZoomLevel(double level) async => CameraZoomState(
    zoomLevel: level,
    minZoomLevel: _state.minZoomLevel,
    maxZoomLevel: _state.maxZoomLevel,
  );

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async => true;

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    return _state = _state.copyWith(lens: lens);
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    return true;
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async => null;

  @override
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) async => null;

  @override
  Future<void> pausePreview({bool releaseAudio = true}) async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<CameraState> getCameraState() async => _state;

  @override
  Widget buildPreview(int textureId) => Container(
    key: Key('texture_$textureId'),
    color: Colors.blue,
  );
}

/// Mock with wide aspect ratio for testing preview calculation
class _WideAspectRatioMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    return const CameraState(
      isInitialized: true,
      textureId: 1,
    );
  }
}

/// Mock that reports a non-zero preview rotation, as the Android
/// SurfaceProducer path does when the producer does not orient frames itself.
class _RotatedPreviewMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async {
    return const CameraState(
      isInitialized: true,
      textureId: 1,
      previewRotationDegrees: 90,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialPlatform = DivineCameraPlatform.instance;
  late MockDivineCameraPlatform mockPlatform;

  setUp(() async {
    mockPlatform = MockDivineCameraPlatform();
    DivineCameraPlatform.instance = mockPlatform;
    // Reset singleton state
    await DivineCamera.instance.dispose();
  });

  tearDown(() {
    // Restore the process-global platform singleton so the mock does not
    // leak into later files in the package's merged isolate.
    DivineCameraPlatform.instance = initialPlatform;
  });

  final camera = DivineCamera.instance;

  Widget buildTestWidget({
    BoxFit fit = BoxFit.contain,
    void Function(Offset, Offset)? onTap,
    Widget? loadingWidget,
    Widget Function(Offset)? focusIndicatorBuilder,
    ValueChanged<ScaleStartDetails>? onScaleStart,
    ValueChanged<ScaleUpdateDetails>? onScaleUpdate,
    ValueChanged<ScaleEndDetails>? onScaleEnd,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 800,
          child: CameraPreviewWidget(
            fit: fit,
            onTap: onTap,
            loadingWidget: loadingWidget,
            focusIndicatorBuilder: focusIndicatorBuilder,
            onScaleStart: onScaleStart,
            onScaleUpdate: onScaleUpdate,
            onScaleEnd: onScaleEnd,
          ),
        ),
      ),
    );
  }

  group('CameraPreviewWidget', () {
    testWidgets('shows loading widget when camera is not initialized', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Should show default loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
      'keeps the default loader static when animations are disabled',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const Scaffold(body: CameraPreviewWidget()),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, 1);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('shows custom loading widget when provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          loadingWidget: const Text('Loading...'),
        ),
      );

      expect(find.text('Loading...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows Texture when camera is initialized', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(Texture), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays preview with correct aspect ratio', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      // Find AspectRatio widget (used in contain mode)
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('uses FittedBox for BoxFit.cover mode', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget(fit: BoxFit.cover));

      expect(find.byType(FittedBox), findsOneWidget);
    });

    testWidgets('rotates preview when previewRotationDegrees is non-zero', (
      tester,
    ) async {
      DivineCameraPlatform.instance = _RotatedPreviewMock();
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      final rotatedBox = tester.widget<RotatedBox>(find.byType(RotatedBox));
      // 90 degrees clockwise = one quarter turn.
      expect(rotatedBox.quarterTurns, 1);
    });

    testWidgets('does not rotate preview when previewRotationDegrees is zero', (
      tester,
    ) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(RotatedBox), findsNothing);
    });

    testWidgets(
      'onTap coordinates stay in display space regardless of preview rotation',
      (tester) async {
        // The onTap point drives both the native focus call and the visual
        // focus indicator, so it must stay in the displayed preview's space.
        // The rotation-to-sensor mapping happens at the native boundary
        // (DivineCamera.setFocusPoint), not here — a rotated preview must not
        // shift the emitted point, or the indicator would jump away from the
        // tap.
        Offset? unrotated;
        await camera.initialize();
        await tester.pumpWidget(
          buildTestWidget(onTap: (_, normalized) => unrotated = normalized),
        );
        final rect = tester.getRect(find.byType(GestureDetector));
        final tapPoint =
            rect.topLeft + Offset(rect.width * 0.3, rect.height * 0.25);
        await tester.tapAt(tapPoint);
        await tester.pump();

        Offset? rotated;
        DivineCameraPlatform.instance = _RotatedPreviewMock();
        await camera.initialize();
        await tester.pumpWidget(
          buildTestWidget(onTap: (_, normalized) => rotated = normalized),
        );
        await tester.tapAt(tapPoint);
        await tester.pump();

        expect(unrotated, isNotNull);
        expect(rotated, isNotNull);
        expect(rotated!.dx, closeTo(unrotated!.dx, 0.0001));
        expect(rotated!.dy, closeTo(unrotated!.dy, 0.0001));
      },
    );

    testWidgets('calls onTap callback with correct positions', (tester) async {
      await camera.initialize();

      Offset? receivedLocalPosition;
      Offset? receivedNormalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (local, normalized) {
            receivedLocalPosition = local;
            receivedNormalizedPosition = normalized;
          },
        ),
      );

      // Tap on the preview
      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(receivedLocalPosition, isNotNull);
      expect(receivedNormalizedPosition, isNotNull);

      // Normalized position should be between 0 and 1
      expect(receivedNormalizedPosition!.dx, inInclusiveRange(0.0, 1.0));
      expect(receivedNormalizedPosition!.dy, inInclusiveRange(0.0, 1.0));
    });

    testWidgets(
      'shows focus indicator when focusIndicatorBuilder is provided',
      (tester) async {
        await camera.initialize();

        await tester.pumpWidget(
          buildTestWidget(
            onTap: (_, _) {},
            focusIndicatorBuilder: (position) => Positioned(
              left: position.dx - 25,
              top: position.dy - 25,
              child: Container(
                key: const Key('focus_indicator'),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),
          ),
        );

        // Initially no focus indicator
        expect(find.byKey(const Key('focus_indicator')), findsNothing);

        // Tap to trigger focus indicator
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        // Focus indicator should now be visible
        expect(find.byKey(const Key('focus_indicator')), findsOneWidget);
      },
    );

    testWidgets('does not show focus indicator without builder', (
      tester,
    ) async {
      await camera.initialize();

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, _) {},
          // No focusIndicatorBuilder
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      // Should not find any positioned widgets for focus
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('handles tap at center of preview', (tester) async {
      await camera.initialize();

      Offset? normalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, normalized) {
            normalizedPosition = normalized;
          },
        ),
      );

      // Get the center of the GestureDetector
      final gesture = find.byType(GestureDetector);
      final center = tester.getCenter(gesture);

      await tester.tapAt(center);
      await tester.pump();

      expect(normalizedPosition, isNotNull);
      // Center tap should be around 0.5, 0.5 (with some tolerance for
      //aspect ratio)
      expect(normalizedPosition!.dx, closeTo(0.5, 0.2));
      expect(normalizedPosition!.dy, closeTo(0.5, 0.2));
    });

    testWidgets('handles tap at corner of preview', (tester) async {
      await camera.initialize();

      Offset? normalizedPosition;

      await tester.pumpWidget(
        buildTestWidget(
          onTap: (_, normalized) {
            normalizedPosition = normalized;
          },
        ),
      );

      // Get the top-left corner of the GestureDetector
      final gesture = find.byType(GestureDetector);
      final topLeft = tester.getTopLeft(gesture);

      await tester.tapAt(topLeft);
      await tester.pump();

      expect(normalizedPosition, isNotNull);
      // Top-left should be close to 0, 0
      expect(normalizedPosition!.dx, closeTo(0.0, 0.1));
      expect(normalizedPosition!.dy, closeTo(0.0, 0.1));
    });

    testWidgets('rebuilds when camera state changes', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Initialize camera
      await camera.initialize();
      // Rebuild widget with initialized camera
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Now shows texture
      expect(find.byType(Texture), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('wraps preview in GestureDetector', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('uses LayoutBuilder for responsive sizing', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('uses Stack for layering focus indicator', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(
        buildTestWidget(
          focusIndicatorBuilder: (_) => const SizedBox(),
        ),
      );

      // Find Stack inside CameraPreviewWidget (there may be other Stacks in
      // Scaffold)
      expect(find.byType(Stack), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(CameraPreviewWidget),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
    });

    testWidgets('passes onScaleStart callback to GestureDetector', (
      tester,
    ) async {
      await camera.initialize();

      await tester.pumpWidget(
        buildTestWidget(
          onScaleStart: (_) {},
        ),
      );

      // Verify GestureDetector is present and accepts the callback
      final gestureDetector = tester.widget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gestureDetector.onScaleStart, isNotNull);
    });

    testWidgets('passes onScaleUpdate callback to GestureDetector', (
      tester,
    ) async {
      await camera.initialize();

      await tester.pumpWidget(
        buildTestWidget(
          onScaleUpdate: (details) {},
        ),
      );

      // Verify GestureDetector is present and accepts the callback
      final gestureDetector = tester.widget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gestureDetector.onScaleUpdate, isNotNull);
    });

    testWidgets('passes onScaleEnd callback to GestureDetector', (
      tester,
    ) async {
      await camera.initialize();

      await tester.pumpWidget(
        buildTestWidget(
          onScaleEnd: (details) {},
        ),
      );

      // Verify GestureDetector is present and accepts the callback
      final gestureDetector = tester.widget<GestureDetector>(
        find.byType(GestureDetector),
      );
      expect(gestureDetector.onScaleEnd, isNotNull);
    });

    testWidgets('shows last frame during camera switch', (tester) async {
      await camera.initialize();
      await tester.pumpWidget(buildTestWidget());

      // Verify texture is shown
      expect(find.byType(Texture), findsOneWidget);
    });

    testWidgets('disposes ValueNotifier properly', (tester) async {
      await camera.initialize();

      await tester.pumpWidget(buildTestWidget());
      expect(find.byType(CameraPreviewWidget), findsOneWidget);

      // Remove the widget to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // Widget should be removed without errors
      expect(find.byType(CameraPreviewWidget), findsNothing);
    });

    testWidgets(
      'handles wide preview aspect ratio (wider than container)',
      (tester) async {
        // Create a mock that returns a wide aspect ratio
        final widePlatform = _WideAspectRatioMock();
        DivineCameraPlatform.instance = widePlatform;

        await camera.initialize();
        // Build widget with narrow container (width < height * aspectRatio)
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200, // Narrow width
                height: 800, // Tall height
                child: CameraPreviewWidget(
                  onTap: (_, _) {},
                ),
              ),
            ),
          ),
        );

        expect(find.byType(Texture), findsOneWidget);
      },
    );

    testWidgets(
      'tap does not call handler when tapDownDetails is null',
      (tester) async {
        await camera.initialize();

        var tapCalled = false;

        await tester.pumpWidget(
          buildTestWidget(
            onTap: (_, _) {
              tapCalled = true;
            },
          ),
        );

        // Normal tap should work
        await tester.tap(find.byType(GestureDetector));
        await tester.pump();

        expect(tapCalled, isTrue);
      },
    );
  });
}
