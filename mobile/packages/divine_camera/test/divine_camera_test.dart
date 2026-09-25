import 'dart:async';

import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDivineCameraPlatform
    with MockPlatformInterfaceMixin
    implements DivineCameraPlatform {
  CameraState _state = const CameraState();
  bool _isRecording = false;
  bool throwOnStopRecording = false;

  /// Records the `releaseAudio` argument of the last [pausePreview] call, or
  /// `null` if it was never called.
  bool? lastPauseReleaseAudio;

  /// The stabilization mode the last [initializeCamera] call asked for.
  DivineVideoStabilizationMode? lastInitStabilizationMode;

  /// Counts [suspendAudioCapture] calls that reached the platform.
  int suspendAudioCaptureCalls = 0;

  /// Counts [resumeAudioCapture] calls that reached the platform.
  int resumeAudioCaptureCalls = 0;
  void Function(VideoRecordingResult? result)? _onRecordingAutoStopped;
  void Function(RemoteRecordTrigger trigger)? _onRemoteRecordTrigger;

  @override
  void Function(VideoRecordingResult? result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult? result)? callback,
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
  ValueChanged<bool>? onScreenFlashChanged;

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    return true;
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    return true;
  }

  @override
  Future<List<AudioDevice>> listAudioDevices() async {
    return const [
      AudioDevice(id: 'mic-1', name: 'Built-in Microphone'),
      AudioDevice(id: 'mic-2', name: 'External Microphone'),
    ];
  }

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
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    lastInitStabilizationMode = videoStabilizationMode;
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
      availableLenses: const [
        DivineCameraLens.front,
        DivineCameraLens.frontUltraWide,
        DivineCameraLens.back,
        DivineCameraLens.ultraWide,
        DivineCameraLens.telephoto,
      ],
    );
  }

  @override
  Future<void> disposeCamera() async {
    _state = const CameraState();
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    return true;
  }

  /// The last point handed to [setFocusPoint], for asserting the sensor-space
  /// mapping DivineCamera applies before the native call.
  Offset? capturedFocusPoint;

  /// The last point handed to [setExposurePoint].
  Offset? capturedExposurePoint;

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    capturedFocusPoint = offset;
    return true;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    capturedExposurePoint = offset;
    return true;
  }

  @override
  Future<bool> cancelFocusAndMetering() async {
    return true;
  }

  /// When set, [setZoomLevel] reports this value as the currently
  /// available maximum and clamps the applied zoom to it, simulating an
  /// OS runtime restriction (iOS silently clamps in that case).
  double? availableMaxZoomOverride;

  /// When true, [setZoomLevel] fails (returns null).
  bool failZoom = false;

  @override
  Future<CameraZoomState?> setZoomLevel(double level) async {
    if (failZoom) return null;
    final availableMax = availableMaxZoomOverride ?? _state.maxZoomLevel;
    return CameraZoomState(
      zoomLevel: level.clamp(_state.minZoomLevel, availableMax),
      minZoomLevel: _state.minZoomLevel,
      maxZoomLevel: availableMax,
    );
  }

  /// When set, [switchCamera] awaits this before completing, so a test can
  /// hold a switch in flight and probe re-entrant calls.
  Completer<void>? switchGate;

  /// When true, [switchCamera] throws to exercise the native failure path
  /// (e.g. a CameraX bind error surfaced as a [PlatformException]).
  bool throwOnSwitch = false;

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    await switchGate?.future;
    if (throwOnSwitch) {
      throw PlatformException(code: 'SWITCH_FAILED');
    }
    return _state = _state.copyWith(lens: lens);
  }

  @override
  Future<bool> setVideoStabilizationMode(
    DivineVideoStabilizationMode mode,
  ) async {
    return true;
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    _isRecording = true;
    return true;
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    if (throwOnStopRecording) {
      _isRecording = false;
      throw PlatformException(code: 'RECORD_STOP_ERROR');
    }
    _isRecording = false;
    return const VideoRecordingResult(
      filePath: '/test/video.mp4',
      durationMs: 5000,
      width: 1080,
      height: 1920,
    );
  }

  @override
  Future<PhotoCaptureResult?> capturePhoto({
    String? outputDirectory,
    bool useCache = true,
  }) async {
    return const PhotoCaptureResult(
      filePath: '/test/photo.jpg',
      width: 1080,
      height: 1920,
    );
  }

  @override
  Future<void> pausePreview({bool releaseAudio = true}) async {
    lastPauseReleaseAudio = releaseAudio;
  }

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> suspendAudioCapture() async {
    suspendAudioCaptureCalls++;
  }

  @override
  Future<void> resumeAudioCapture() async {
    resumeAudioCaptureCalls++;
  }

  @override
  Future<CameraState> getCameraState() async {
    return _state;
  }

  @override
  Widget buildPreview(int textureId) {
    return Container();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final initialPlatform = DivineCameraPlatform.instance;

  group('DivineCameraPlatform', () {
    test('$MethodChannelDivineCamera is the default instance', () {
      expect(initialPlatform, isInstanceOf<MethodChannelDivineCamera>());
    });

    group('base class throws UnimplementedError', () {
      late _BasePlatformForTesting basePlatform;

      setUp(() {
        basePlatform = _BasePlatformForTesting();
      });

      test('onRemoteRecordTrigger getter throws', () {
        expect(
          () => basePlatform.onRemoteRecordTrigger,
          throwsUnimplementedError,
        );
      });

      test('onRemoteRecordTrigger setter throws', () {
        expect(
          () => basePlatform.onRemoteRecordTrigger = (_) {},
          throwsUnimplementedError,
        );
      });

      test('onScreenFlashChanged getter throws', () {
        expect(
          () => basePlatform.onScreenFlashChanged,
          throwsUnimplementedError,
        );
      });

      test('onScreenFlashChanged setter throws', () {
        expect(
          () => basePlatform.onScreenFlashChanged = (_) {},
          throwsUnimplementedError,
        );
      });

      test('setRemoteRecordControlEnabled throws', () {
        expect(
          () => basePlatform.setRemoteRecordControlEnabled(enabled: true),
          throwsUnimplementedError,
        );
      });

      test('setVolumeKeysEnabled throws', () {
        expect(
          () => basePlatform.setVolumeKeysEnabled(enabled: true),
          throwsUnimplementedError,
        );
      });

      test('listAudioDevices throws', () {
        expect(() => basePlatform.listAudioDevices(), throwsUnimplementedError);
      });
    });
  });

  group('DivineCamera', () {
    late MockDivineCameraPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockDivineCameraPlatform();
      DivineCameraPlatform.instance = mockPlatform;
    });

    tearDown(() async {
      // Reset DivineCamera singleton state between tests
      await DivineCamera.instance.dispose();
      // Restore the process-global platform singleton so the mock does not
      // leak into later files in the package's merged isolate.
      DivineCameraPlatform.instance = initialPlatform;
    });

    test('getPlatformVersion returns expected value', () async {
      expect(await DivineCamera.instance.getPlatformVersion(), '42');
    });

    group('initialize', () {
      test('initializes with default lens (back)', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.isInitialized, isTrue);
        expect(state.lens, DivineCameraLens.back);
        expect(DivineCamera.instance.isInitialized, isTrue);
      });

      test('initializes with front camera', () async {
        final state = await DivineCamera.instance.initialize(
          lens: DivineCameraLens.front,
        );

        expect(state.isInitialized, isTrue);
        expect(state.lens, DivineCameraLens.front);
      });

      test('initializes with video quality', () async {
        final state = await DivineCamera.instance.initialize(
          videoQuality: DivineVideoQuality.uhd,
        );

        expect(state.isInitialized, isTrue);
      });

      test('initializes with enableScreenFlash true (default)', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.isInitialized, isTrue);
      });

      test('initializes with enableScreenFlash false', () async {
        final state = await DivineCamera.instance.initialize(
          enableScreenFlash: false,
        );

        expect(state.isInitialized, isTrue);
      });

      test('asks the platform for no stabilization by default', () async {
        await DivineCamera.instance.initialize();

        expect(
          mockPlatform.lastInitStabilizationMode,
          DivineVideoStabilizationMode.off,
        );
      });

      test('forwards the requested stabilization mode', () async {
        await DivineCamera.instance.initialize(
          videoStabilizationMode: DivineVideoStabilizationMode.cinematic,
        );

        expect(
          mockPlatform.lastInitStabilizationMode,
          DivineVideoStabilizationMode.cinematic,
        );
      });

      test('mirrorFrontCameraOutput defaults to false', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.mirrorFrontCameraOutput, isFalse);
      });

      test('mirrorFrontCameraOutput reflects initialization value', () async {
        await DivineCamera.instance.initialize(mirrorFrontCameraOutput: true);

        expect(DivineCamera.instance.mirrorFrontCameraOutput, isTrue);
      });

      test('sets camera capabilities correctly', () async {
        final state = await DivineCamera.instance.initialize();

        expect(state.hasFlash, isTrue);
        expect(state.hasFrontCamera, isTrue);
        expect(state.hasBackCamera, isTrue);
        expect(state.minZoomLevel, 1.0);
        expect(state.maxZoomLevel, 10.0);
        expect(state.textureId, 1);
      });
    });

    group('dispose', () {
      test('disposes camera resources', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.dispose();

        expect(DivineCamera.instance.isInitialized, isFalse);
      });
    });

    group('flash mode', () {
      test('sets flash mode successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setFlashMode(
          DivineCameraFlashMode.on,
        );

        expect(success, isTrue);
        expect(DivineCamera.instance.state.flashMode, DivineCameraFlashMode.on);
      });

      test('cycles through flash modes', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.off);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.off,
        );

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.auto);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.auto,
        );

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.on);
        expect(DivineCamera.instance.state.flashMode, DivineCameraFlashMode.on);

        await DivineCamera.instance.setFlashMode(DivineCameraFlashMode.torch);
        expect(
          DivineCamera.instance.state.flashMode,
          DivineCameraFlashMode.torch,
        );
      });
    });

    group('video stabilization', () {
      test('sets stabilization mode and updates state', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setVideoStabilizationMode(
          DivineVideoStabilizationMode.cinematic,
        );

        expect(success, isTrue);
        expect(
          DivineCamera.instance.videoStabilizationMode,
          DivineVideoStabilizationMode.cinematic,
        );
        expect(
          DivineCamera.instance.state.videoStabilizationMode,
          DivineVideoStabilizationMode.cinematic,
        );
      });

      test('exposes availability getters from state', () async {
        await DivineCamera.instance.initialize();

        expect(
          DivineCamera.instance.availableVideoStabilizationModes,
          DivineCamera.instance.state.availableVideoStabilizationModes,
        );
        expect(
          DivineCamera.instance.isVideoStabilizationSupported,
          DivineCamera.instance.state.isVideoStabilizationSupported,
        );
      });

      test('rejects a mode change while a lens switch is in flight', () async {
        await DivineCamera.instance.initialize();

        final gate = Completer<void>();
        mockPlatform.switchGate = gate;
        final switching = DivineCamera.instance.switchCamera();

        // Mid-switch the change would rebind through the same native switch
        // path and clobber the switch's pending first-frame completion.
        final rejected = await DivineCamera.instance.setVideoStabilizationMode(
          DivineVideoStabilizationMode.cinematic,
        );
        expect(rejected, isFalse);
        expect(
          DivineCamera.instance.videoStabilizationMode,
          DivineVideoStabilizationMode.off,
        );

        gate.complete();
        expect(await switching, isTrue);

        final applied = await DivineCamera.instance.setVideoStabilizationMode(
          DivineVideoStabilizationMode.cinematic,
        );
        expect(applied, isTrue);
      });
    });

    group('focus and exposure', () {
      test('sets focus point successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setFocusPoint(
          const Offset(0.5, 0.5),
        );

        expect(success, isTrue);
        // No preview rotation (default): the point passes through unchanged.
        expect(mockPlatform.capturedFocusPoint, const Offset(0.5, 0.5));
      });

      test('sets exposure point successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.setExposurePoint(
          const Offset(0.3, 0.7),
        );

        expect(success, isTrue);
        expect(mockPlatform.capturedExposurePoint, const Offset(0.3, 0.7));
      });

      test(
        'maps focus/exposure onto sensor axes for a rotated preview',
        () async {
          // The tap is in the displayed (upright) preview's space; DivineCamera
          // undoes the clockwise RotatedBox so native meters the right point.
          const tap = Offset(0.3, 0.25);
          final cases = <(int, Offset)>[
            (90, const Offset(0.25, 0.7)), // (y, 1 - x)
            (180, const Offset(0.7, 0.75)), // (1 - x, 1 - y)
            (270, const Offset(0.75, 0.3)), // (1 - y, x)
          ];
          for (final (degrees, expected) in cases) {
            final mock = _RotatedFocusMock(degrees);
            DivineCameraPlatform.instance = mock;
            await DivineCamera.instance.initialize();

            await DivineCamera.instance.setFocusPoint(tap);
            await DivineCamera.instance.setExposurePoint(tap);

            expect(
              mock.capturedFocusPoint!.dx,
              closeTo(expected.dx, 0.0001),
              reason: 'focus dx @ $degrees',
            );
            expect(
              mock.capturedFocusPoint!.dy,
              closeTo(expected.dy, 0.0001),
              reason: 'focus dy @ $degrees',
            );
            expect(
              mock.capturedExposurePoint!.dx,
              closeTo(expected.dx, 0.0001),
              reason: 'exposure dx @ $degrees',
            );
            expect(
              mock.capturedExposurePoint!.dy,
              closeTo(expected.dy, 0.0001),
              reason: 'exposure dy @ $degrees',
            );
          }
        },
      );

      test('cancels focus and metering successfully', () async {
        await DivineCamera.instance.initialize();

        final success = await DivineCamera.instance.cancelFocusAndMetering();

        expect(success, isTrue);
      });
    });

    group('zoom', () {
      test('sets zoom level and returns the applied value', () async {
        await DivineCamera.instance.initialize();

        final applied = await DivineCamera.instance.setZoomLevel(2);

        expect(applied, 2.0);
        expect(DivineCamera.instance.zoomLevel, 2.0);
      });

      test('returns minZoomLevel and maxZoomLevel', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.minZoomLevel, 1.0);
        expect(DivineCamera.instance.maxZoomLevel, 10.0);
      });

      test('returns null and keeps state when the platform fails', () async {
        await DivineCamera.instance.initialize();
        mockPlatform.failZoom = true;

        final applied = await DivineCamera.instance.setZoomLevel(2);

        expect(applied, isNull);
        expect(DivineCamera.instance.zoomLevel, 1.0);
      });

      test(
        'adopts the applied zoom and shrunk bounds when the OS restricts '
        'the available range at runtime',
        () async {
          await DivineCamera.instance.initialize();
          mockPlatform.availableMaxZoomOverride = 5.2;

          final applied = await DivineCamera.instance.setZoomLevel(8);

          expect(applied, 5.2);
          expect(DivineCamera.instance.zoomLevel, 5.2);
          expect(DivineCamera.instance.maxZoomLevel, 5.2);
        },
      );

      test('heals the bounds once a runtime restriction lifts', () async {
        await DivineCamera.instance.initialize();
        mockPlatform.availableMaxZoomOverride = 5.2;
        await DivineCamera.instance.setZoomLevel(8);
        mockPlatform.availableMaxZoomOverride = null;

        // The first set after the lift is still pre-clamped to the shrunk
        // bounds, but the platform reports the widened range back.
        await DivineCamera.instance.setZoomLevel(4);
        expect(DivineCamera.instance.maxZoomLevel, 10.0);

        final applied = await DivineCamera.instance.setZoomLevel(8);
        expect(applied, 8.0);
        expect(DivineCamera.instance.zoomLevel, 8.0);
      });
    });

    group('switch camera', () {
      test('switches to front camera', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.switchCamera();

        expect(DivineCamera.instance.state.lens, DivineCameraLens.front);
      });

      test('switches back to rear camera', () async {
        await DivineCamera.instance.initialize(lens: DivineCameraLens.front);

        await DivineCamera.instance.switchCamera();

        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test(
        'canSwitchCamera returns true when both cameras available',
        () async {
          await DivineCamera.instance.initialize();

          expect(DivineCamera.instance.canSwitchCamera, isTrue);
        },
      );

      test('ignores a re-entrant switch while one is in flight', () async {
        await DivineCamera.instance.initialize();

        final gate = Completer<void>();
        mockPlatform.switchGate = gate;

        final first = DivineCamera.instance.switchCamera();
        // Second call arrives before the first resolves.
        final second = await DivineCamera.instance.switchCamera();
        expect(second, isFalse);

        gate.complete();
        expect(await first, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.front);
      });

      test(
        'resets isSwitchingCamera and stays switchable after a thrown switch',
        () async {
          await DivineCamera.instance.initialize();

          mockPlatform.throwOnSwitch = true;
          await expectLater(
            DivineCamera.instance.switchCamera(),
            throwsA(isA<PlatformException>()),
          );

          // A stuck flag would freeze the preview and, via the re-entrancy
          // guard, block every later switch for the session.
          expect(DivineCamera.instance.isSwitchingCamera, isFalse);

          mockPlatform.throwOnSwitch = false;
          final recovered = await DivineCamera.instance.switchCamera();
          expect(recovered, isTrue);
          expect(DivineCamera.instance.state.lens, DivineCameraLens.front);
        },
      );
    });

    group('setLens', () {
      test('switches to specific lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.ultraWide,
        );

        expect(result, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.ultraWide);
      });

      test('returns true when already on requested lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.back,
        );

        expect(result, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test('returns false when lens not available', () async {
        await DivineCamera.instance.initialize();

        // macro is not in availableLenses in the mock
        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.macro,
        );

        expect(result, isFalse);
        // Lens should not have changed
        expect(DivineCamera.instance.state.lens, DivineCameraLens.back);
      });

      test('switches to frontUltraWide lens', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setLens(
          DivineCameraLens.frontUltraWide,
        );

        expect(result, isTrue);
        expect(
          DivineCamera.instance.state.lens,
          DivineCameraLens.frontUltraWide,
        );
      });

      test('resets isSwitchingCamera after a thrown setLens', () async {
        await DivineCamera.instance.initialize();

        mockPlatform.throwOnSwitch = true;
        await expectLater(
          DivineCamera.instance.setLens(DivineCameraLens.ultraWide),
          throwsA(isA<PlatformException>()),
        );

        expect(DivineCamera.instance.isSwitchingCamera, isFalse);

        mockPlatform.throwOnSwitch = false;
        final recovered = await DivineCamera.instance.setLens(
          DivineCameraLens.ultraWide,
        );
        expect(recovered, isTrue);
        expect(DivineCamera.instance.state.lens, DivineCameraLens.ultraWide);
      });
    });

    group('hasFrontUltraWideCamera', () {
      test('returns true when frontUltraWide is in availableLenses', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.state.hasFrontUltraWideCamera, isTrue);
      });

      test('returns false when frontUltraWide is not available', () async {
        // Use single camera mock which doesn't have frontUltraWide
        final singleCameraMock = _SingleCameraMock();
        DivineCameraPlatform.instance = singleCameraMock;

        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.state.hasFrontUltraWideCamera, isFalse);
      });
    });

    group('recording', () {
      test('starts recording', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.startRecording();

        expect(DivineCamera.instance.isRecording, isTrue);
      });

      test('stops recording and returns result', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();

        final result = await DivineCamera.instance.stopRecording();

        expect(result, isNotNull);
        expect(result!.filePath, '/test/video.mp4');
        expect(result.durationMs, 5000);
        expect(result.width, 1080);
        expect(result.height, 1920);
        expect(DivineCamera.instance.isRecording, isFalse);
      });

      test('clears recording state when native stop fails', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();
        mockPlatform.throwOnStopRecording = true;

        await expectLater(
          DivineCamera.instance.stopRecording(),
          throwsA(isA<PlatformException>()),
        );

        expect(DivineCamera.instance.isRecording, isFalse);
        expect(DivineCamera.instance.canRecord, isTrue);
      });

      test('canRecord returns true when initialized', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.canRecord, isTrue);
      });

      test('canRecord returns false when not initialized', () async {
        await DivineCamera.instance.dispose();
        expect(DivineCamera.instance.canRecord, isFalse);
      });
    });

    group('photo capture', () {
      test('captures a photo when initialized', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.capturePhoto();

        expect(result, isNotNull);
        expect(result!.filePath, '/test/photo.jpg');
        expect(result.width, 1080);
        expect(result.height, 1920);
      });

      test('returns null when not initialized', () async {
        await DivineCamera.instance.dispose();

        final result = await DivineCamera.instance.capturePhoto();

        expect(result, isNull);
      });

      test('returns null while recording', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();

        final result = await DivineCamera.instance.capturePhoto();

        expect(result, isNull);
      });
    });

    group('audio capture suspension', () {
      test('suspendAudioCapture reaches the platform when idle', () async {
        await DivineCamera.instance.initialize();

        await DivineCamera.instance.suspendAudioCapture();

        expect(mockPlatform.suspendAudioCaptureCalls, 1);
      });

      test('suspendAudioCapture is a no-op before initialize', () async {
        await DivineCamera.instance.dispose();

        await DivineCamera.instance.suspendAudioCapture();

        expect(mockPlatform.suspendAudioCaptureCalls, 0);
      });

      test('suspendAudioCapture is a no-op while recording', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();

        await DivineCamera.instance.suspendAudioCapture();

        expect(mockPlatform.suspendAudioCaptureCalls, 0);
      });

      test(
        'resumeAudioCapture reaches the platform when initialized',
        () async {
          await DivineCamera.instance.initialize();

          await DivineCamera.instance.resumeAudioCapture();

          expect(mockPlatform.resumeAudioCaptureCalls, 1);
        },
      );

      test('resumeAudioCapture is a no-op before initialize', () async {
        await DivineCamera.instance.dispose();

        await DivineCamera.instance.resumeAudioCapture();

        expect(mockPlatform.resumeAudioCaptureCalls, 0);
      });
    });

    group('listAudioDevices', () {
      test('returns list of audio devices', () async {
        final devices = await DivineCamera.instance.listAudioDevices();

        expect(devices, hasLength(2));
        expect(devices.first.id, equals('mic-1'));
        expect(devices.first.name, equals('Built-in Microphone'));
        expect(devices.last.id, equals('mic-2'));
        expect(devices.last.name, equals('External Microphone'));
      });
    });

    group('state callbacks', () {
      test('onStateChanged is called when state changes', () async {
        CameraState? receivedState;
        DivineCamera.instance.onStateChanged = (state) {
          receivedState = state;
        };

        await DivineCamera.instance.initialize();

        expect(receivedState, isNotNull);
        expect(receivedState!.isInitialized, isTrue);
      });
    });

    group('remote record control', () {
      test('setRemoteRecordControlEnabled enables control', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance
            .setRemoteRecordControlEnabled(enabled: true);

        expect(result, isTrue);
        expect(DivineCamera.instance.remoteRecordControlEnabled, isTrue);
      });

      test('setRemoteRecordControlEnabled disables control', () async {
        await DivineCamera.instance.initialize();
        await DivineCamera.instance.setRemoteRecordControlEnabled(
          enabled: true,
        );

        final result = await DivineCamera.instance
            .setRemoteRecordControlEnabled(enabled: false);

        expect(result, isTrue);
        expect(DivineCamera.instance.remoteRecordControlEnabled, isFalse);
      });

      test('setVolumeKeysEnabled enables volume keys', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setVolumeKeysEnabled(
          enabled: true,
        );

        expect(result, isTrue);
      });

      test('setVolumeKeysEnabled disables volume keys', () async {
        await DivineCamera.instance.initialize();

        final result = await DivineCamera.instance.setVolumeKeysEnabled(
          enabled: false,
        );

        expect(result, isTrue);
      });

      test('onRemoteRecordTrigger callback can be set', () async {
        await DivineCamera.instance.initialize();

        RemoteRecordTrigger? receivedTrigger;
        DivineCamera.instance.onRemoteRecordTrigger = (trigger) {
          receivedTrigger = trigger;
        };

        // The platform callback is now set by DivineCamera - call it to
        // simulate a native trigger event
        final mockPlatform =
            DivineCameraPlatform.instance as MockDivineCameraPlatform;
        mockPlatform.onRemoteRecordTrigger?.call(
          RemoteRecordTrigger.volumeDown,
        );

        expect(receivedTrigger, equals(RemoteRecordTrigger.volumeDown));
      });

      test('onScreenFlashChanged forwards native changes', () async {
        await DivineCamera.instance.initialize();

        final changes = <bool>[];
        DivineCamera.instance.onScreenFlashChanged = changes.add;

        final mockPlatform =
            DivineCameraPlatform.instance as MockDivineCameraPlatform;
        mockPlatform.onScreenFlashChanged?.call(true);
        mockPlatform.onScreenFlashChanged?.call(false);

        expect(changes, equals([true, false]));
      });

      test('remoteRecordControlEnabled defaults to false', () async {
        await DivineCamera.instance.initialize();

        expect(DivineCamera.instance.remoteRecordControlEnabled, isFalse);
      });
    });
  });

  group('CameraState', () {
    test('creates default state', () {
      const state = CameraState();

      expect(state.isInitialized, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.flashMode, DivineCameraFlashMode.off);
      expect(state.lens, DivineCameraLens.back);
      expect(state.zoomLevel, 1.0);
    });

    test('creates state from map', () {
      final map = {
        'isInitialized': true,
        'isRecording': true,
        'flashMode': 'torch',
        'lens': 'front',
        'zoomLevel': 2.5,
        'minZoomLevel': 1.0,
        'maxZoomLevel': 8.0,
        'aspectRatio': 1.777,
        'hasFlash': true,
        'hasFrontCamera': true,
        'hasBackCamera': true,
        'isFocusPointSupported': true,
        'isExposurePointSupported': true,
        'textureId': 42,
        'videoStabilizationMode': 'cinematic',
        'availableVideoStabilizationModes': ['off', 'standard', 'cinematic'],
        'isVideoStabilizationSupported': true,
      };

      final state = CameraState.fromMap(map);

      expect(state.isInitialized, isTrue);
      expect(state.isRecording, isTrue);
      expect(state.flashMode, DivineCameraFlashMode.torch);
      expect(state.lens, DivineCameraLens.front);
      expect(state.zoomLevel, 2.5);
      expect(state.minZoomLevel, 1.0);
      expect(state.maxZoomLevel, 8.0);
      expect(state.aspectRatio, closeTo(1.777, 0.001));
      expect(state.hasFlash, isTrue);
      expect(state.hasFrontCamera, isTrue);
      expect(state.hasBackCamera, isTrue);
      expect(state.isFocusPointSupported, isTrue);
      expect(state.isExposurePointSupported, isTrue);
      expect(state.textureId, 42);
      expect(
        state.videoStabilizationMode,
        DivineVideoStabilizationMode.cinematic,
      );
      expect(state.availableVideoStabilizationModes, const [
        DivineVideoStabilizationMode.off,
        DivineVideoStabilizationMode.standard,
        DivineVideoStabilizationMode.cinematic,
      ]);
      expect(state.isVideoStabilizationSupported, isTrue);
    });

    test('copyWith creates new state with updated values', () {
      const original = CameraState(isInitialized: true);

      final copied = original.copyWith(
        flashMode: DivineCameraFlashMode.on,
        zoomLevel: 3,
      );

      expect(copied.isInitialized, isTrue);
      expect(copied.flashMode, DivineCameraFlashMode.on);
      expect(copied.zoomLevel, 3.0);
      // Original should be unchanged
      expect(original.flashMode, DivineCameraFlashMode.off);
      expect(original.zoomLevel, 1.0);
    });
  });

  group('VideoRecordingResult', () {
    test('creates result with all fields', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 10000,
        width: 1920,
        height: 1080,
      );

      expect(result.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 10000);
      expect(result.width, 1920);
      expect(result.height, 1080);
    });

    test('creates result from map', () {
      final map = {
        'filePath': '/path/to/video.mp4',
        'durationMs': 5000,
        'width': 1280,
        'height': 720,
      };

      final result = VideoRecordingResult.fromMap(map);

      expect(result.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 5000);
      expect(result.width, 1280);
      expect(result.height, 720);
    });

    test('duration getter returns Duration object', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 5000,
      );

      expect(result.duration, const Duration(milliseconds: 5000));
      expect(result.duration!.inSeconds, 5);
    });

    test('duration getter returns null when durationMs is null', () {
      const result = VideoRecordingResult(filePath: '/path/to/video.mp4');

      expect(result.duration, isNull);
    });

    test('toMap converts result to map', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 3000,
        width: 1920,
        height: 1080,
      );

      final map = result.toMap();

      expect(map['filePath'], '/path/to/video.mp4');
      expect(map['durationMs'], 3000);
      expect(map['width'], 1920);
      expect(map['height'], 1080);
    });
  });

  group('DivineCameraFlashMode', () {
    test('toNativeString returns correct values', () {
      expect(DivineCameraFlashMode.off.toNativeString(), 'off');
      expect(DivineCameraFlashMode.auto.toNativeString(), 'auto');
      expect(DivineCameraFlashMode.on.toNativeString(), 'on');
      expect(DivineCameraFlashMode.torch.toNativeString(), 'torch');
    });

    test('fromNativeString creates correct modes', () {
      expect(
        DivineCameraFlashMode.fromNativeString('off'),
        DivineCameraFlashMode.off,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('auto'),
        DivineCameraFlashMode.auto,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('on'),
        DivineCameraFlashMode.on,
      );
      expect(
        DivineCameraFlashMode.fromNativeString('torch'),
        DivineCameraFlashMode.torch,
      );
    });

    test('fromNativeString defaults to off for unknown values', () {
      expect(
        DivineCameraFlashMode.fromNativeString('unknown'),
        DivineCameraFlashMode.off,
      );
      expect(
        DivineCameraFlashMode.fromNativeString(''),
        DivineCameraFlashMode.off,
      );
    });
  });

  group('DivineCameraLens', () {
    test('toNativeString returns correct values', () {
      expect(DivineCameraLens.back.toNativeString(), 'back');
      expect(DivineCameraLens.front.toNativeString(), 'front');
    });

    test('fromNativeString creates correct lens', () {
      expect(DivineCameraLens.fromNativeString('back'), DivineCameraLens.back);
      expect(
        DivineCameraLens.fromNativeString('front'),
        DivineCameraLens.front,
      );
    });

    test('fromNativeString defaults to back for unknown values', () {
      expect(
        DivineCameraLens.fromNativeString('unknown'),
        DivineCameraLens.back,
      );
      expect(DivineCameraLens.fromNativeString(''), DivineCameraLens.back);
    });
  });

  group('DivineVideoQuality', () {
    test('value returns correct strings', () {
      expect(DivineVideoQuality.sd.value, 'sd');
      expect(DivineVideoQuality.hd.value, 'hd');
      expect(DivineVideoQuality.fhd.value, 'fhd');
      expect(DivineVideoQuality.uhd.value, 'uhd');
      expect(DivineVideoQuality.highest.value, 'highest');
      expect(DivineVideoQuality.lowest.value, 'lowest');
    });
  });

  group(RemoteRecordTrigger, () {
    test('fromNativeString returns correct trigger for volumeUp', () {
      expect(
        RemoteRecordTrigger.fromNativeString('volumeUp'),
        equals(RemoteRecordTrigger.volumeUp),
      );
    });

    test('fromNativeString returns correct trigger for volumeDown', () {
      expect(
        RemoteRecordTrigger.fromNativeString('volumeDown'),
        equals(RemoteRecordTrigger.volumeDown),
      );
    });

    test('fromNativeString returns correct trigger for bluetooth', () {
      expect(
        RemoteRecordTrigger.fromNativeString('bluetooth'),
        equals(RemoteRecordTrigger.bluetooth),
      );
    });

    test('fromNativeString defaults to volumeUp for unknown values', () {
      expect(
        RemoteRecordTrigger.fromNativeString('unknown'),
        equals(RemoteRecordTrigger.volumeUp),
      );
      expect(
        RemoteRecordTrigger.fromNativeString(''),
        equals(RemoteRecordTrigger.volumeUp),
      );
    });

    test('all trigger values are distinct', () {
      const triggers = RemoteRecordTrigger.values;
      expect(triggers.length, equals(3));
      expect(triggers.toSet().length, equals(3));
    });

    test('toNativeString returns correct string for volumeUp', () {
      expect(RemoteRecordTrigger.volumeUp.toNativeString(), equals('volumeUp'));
    });

    test('toNativeString returns correct string for volumeDown', () {
      expect(
        RemoteRecordTrigger.volumeDown.toNativeString(),
        equals('volumeDown'),
      );
    });

    test('toNativeString returns correct string for bluetooth', () {
      expect(
        RemoteRecordTrigger.bluetooth.toNativeString(),
        equals('bluetooth'),
      );
    });
  });

  group('CameraState additional tests', () {
    test('toMap converts state to map', () {
      const state = CameraState(
        isInitialized: true,
        isRecording: true,
        flashMode: DivineCameraFlashMode.torch,
        lens: DivineCameraLens.front,
        zoomLevel: 2,
        maxZoomLevel: 8,
        aspectRatio: 1.777,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        isFocusPointSupported: true,
        isExposurePointSupported: true,
        textureId: 42,
      );

      final map = state.toMap();

      expect(map['isInitialized'], isTrue);
      expect(map['isRecording'], isTrue);
      expect(map['isSwitchingCamera'], isFalse);
      expect(map['flashMode'], 'torch');
      expect(map['lens'], 'front');
      expect(map['zoomLevel'], 2.0);
      expect(map['minZoomLevel'], 1.0);
      expect(map['maxZoomLevel'], 8.0);
      expect(map['aspectRatio'], closeTo(1.777, 0.001));
      expect(map['hasFlash'], isTrue);
      expect(map['hasFrontCamera'], isTrue);
      expect(map['hasBackCamera'], isTrue);
      expect(map['isFocusPointSupported'], isTrue);
      expect(map['isExposurePointSupported'], isTrue);
      expect(map['textureId'], 42);
    });

    test('toString returns formatted string', () {
      const state = CameraState(isInitialized: true, textureId: 1);

      final str = state.toString();

      expect(str, contains('CameraState'));
      expect(str, contains('isInitialized: true'));
      expect(str, contains('isRecording: false'));
      expect(str, contains('lens: DivineCameraLens.back'));
      expect(str, contains('textureId: 1'));
    });

    test('props returns correct list of properties', () {
      const state = CameraState(
        isInitialized: true,
        maxZoomLevel: 8,
        aspectRatio: 1.777,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        textureId: 1,
      );

      final props = state.props;

      expect(props.length, 22);
      expect(props[0], isTrue); // isInitialized
      expect(props[1], isFalse); // isRecording
      expect(props[4], DivineCameraLens.back); // lens
      expect(props[14], 1); // textureId
      expect(props[15], 0); // previewRotationDegrees
      expect(props[16], isFalse); // previewHandlesTransform
      expect(
        props[19],
        DivineVideoStabilizationMode.off,
      ); // videoStabilizationMode
    });

    test('equality works correctly', () {
      const state1 = CameraState(isInitialized: true, textureId: 1);
      const state2 = CameraState(isInitialized: true, textureId: 1);
      const state3 = CameraState(isInitialized: true, textureId: 2);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('copyWith with all parameters', () {
      const original = CameraState();

      final copied = original.copyWith(
        isInitialized: true,
        isRecording: true,
        isSwitchingCamera: true,
        flashMode: DivineCameraFlashMode.torch,
        lens: DivineCameraLens.front,
        zoomLevel: 5,
        minZoomLevel: 1,
        maxZoomLevel: 10,
        aspectRatio: 1.5,
        hasFlash: true,
        hasFrontCamera: true,
        hasBackCamera: true,
        isFocusPointSupported: true,
        isExposurePointSupported: true,
        textureId: 99,
      );

      expect(copied.isInitialized, isTrue);
      expect(copied.isRecording, isTrue);
      expect(copied.isSwitchingCamera, isTrue);
      expect(copied.flashMode, DivineCameraFlashMode.torch);
      expect(copied.lens, DivineCameraLens.front);
      expect(copied.zoomLevel, 5.0);
      expect(copied.minZoomLevel, 1.0);
      expect(copied.maxZoomLevel, 10.0);
      expect(copied.aspectRatio, 1.5);
      expect(copied.hasFlash, isTrue);
      expect(copied.hasFrontCamera, isTrue);
      expect(copied.hasBackCamera, isTrue);
      expect(copied.isFocusPointSupported, isTrue);
      expect(copied.isExposurePointSupported, isTrue);
      expect(copied.textureId, 99);
    });

    test('fromMap with missing values uses defaults', () {
      final state = CameraState.fromMap(const {});

      expect(state.isInitialized, isFalse);
      expect(state.isRecording, isFalse);
      expect(state.flashMode, DivineCameraFlashMode.off);
      expect(state.lens, DivineCameraLens.back);
      expect(state.zoomLevel, 1.0);
      expect(state.aspectRatio, closeTo(9 / 16, 0.01));
      expect(state.textureId, isNull);
    });

    test('fromMap with isSwitchingCamera', () {
      final state = CameraState.fromMap(const {'isSwitchingCamera': true});

      expect(state.isSwitchingCamera, isTrue);
    });
  });

  group('VideoRecordingResult additional tests', () {
    test('toString returns formatted string', () {
      const result = VideoRecordingResult(
        filePath: '/path/to/video.mp4',
        durationMs: 5000,
        width: 1920,
        height: 1080,
      );

      final str = result.toString();

      expect(str, contains('VideoRecordingResult'));
      expect(str, contains('filePath: /path/to/video.mp4'));
      expect(str, contains('durationMs: 5000'));
      expect(str, contains('width: 1920'));
      expect(str, contains('height: 1080'));
    });

    test('props returns correct list of properties', () {
      const result = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
        width: 1280,
        height: 720,
      );

      final props = result.props;

      expect(props.length, 4);
      expect(props[0], '/test.mp4');
      expect(props[1], 1000);
      expect(props[2], 1280);
      expect(props[3], 720);
    });

    test('equality works correctly', () {
      const result1 = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
      );
      const result2 = VideoRecordingResult(
        filePath: '/test.mp4',
        durationMs: 1000,
      );
      const result3 = VideoRecordingResult(
        filePath: '/other.mp4',
        durationMs: 1000,
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('file getter returns File object', () {
      const result = VideoRecordingResult(filePath: '/path/to/video.mp4');

      expect(result.file.path, '/path/to/video.mp4');
    });
  });

  group('DivineCameraLens', () {
    test('opposite returns the other lens', () {
      expect(DivineCameraLens.back.opposite, DivineCameraLens.front);
      expect(DivineCameraLens.front.opposite, DivineCameraLens.back);
    });
  });

  group('DivineCamera additional tests', () {
    late MockDivineCameraPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockDivineCameraPlatform();
      DivineCameraPlatform.instance = mockPlatform;
    });

    tearDown(() async {
      // Reset DivineCamera singleton state between tests
      await DivineCamera.instance.dispose();
      // Restore the process-global platform singleton so the mock does not
      // leak into later files in the package's merged isolate.
      DivineCameraPlatform.instance = initialPlatform;
    });

    test('onRecordingAutoStopped callback is invoked', () async {
      VideoRecordingResult? receivedResult;
      DivineCamera.instance.onRecordingAutoStopped = (result) {
        receivedResult = result;
      };

      await DivineCamera.instance.initialize();

      // Simulate auto-stop from platform
      const autoStopResult = VideoRecordingResult(
        filePath: '/auto/stopped.mp4',
        durationMs: 30000,
      );
      mockPlatform.onRecordingAutoStopped?.call(autoStopResult);

      expect(receivedResult, isNotNull);
      expect(receivedResult!.filePath, '/auto/stopped.mp4');
      expect(DivineCamera.instance.isRecording, isFalse);
    });

    test(
      'onRecordingAutoStopped forwards a stop that captured nothing and '
      'ends recording',
      () async {
        var callCount = 0;
        VideoRecordingResult? receivedResult = const VideoRecordingResult(
          filePath: '/sentinel.mp4',
        );
        DivineCamera.instance.onRecordingAutoStopped = (result) {
          callCount++;
          receivedResult = result;
        };

        await DivineCamera.instance.initialize();
        await DivineCamera.instance.startRecording();
        expect(DivineCamera.instance.isRecording, isTrue);

        mockPlatform.onRecordingAutoStopped?.call(null);

        expect(callCount, 1);
        expect(receivedResult, isNull);
        expect(DivineCamera.instance.isRecording, isFalse);
        // The mock platform still reports an active recording, so a stop
        // that reached it would return a file.
        expect(await DivineCamera.instance.stopRecording(), isNull);
      },
    );

    test('setFocusPoint returns false when not supported', () async {
      // Create mock that doesn't support focus
      final noFocusMock = _NoFocusSupportMock();
      DivineCameraPlatform.instance = noFocusMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.setFocusPoint(
        const Offset(0.5, 0.5),
      );

      expect(result, isFalse);
    });

    test('setExposurePoint returns false when not supported', () async {
      // Create mock that doesn't support exposure
      final noExposureMock = _NoExposureSupportMock();
      DivineCameraPlatform.instance = noExposureMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.setExposurePoint(
        const Offset(0.5, 0.5),
      );

      expect(result, isFalse);
    });

    test('setZoomLevel clamps level within bounds', () async {
      await DivineCamera.instance.initialize();

      // Try to set zoom below min
      await DivineCamera.instance.setZoomLevel(0.1);
      expect(DivineCamera.instance.zoomLevel, 1.0);

      // Try to set zoom above max
      await DivineCamera.instance.setZoomLevel(100);
      expect(DivineCamera.instance.zoomLevel, 10.0);
    });

    test('switchCamera returns false when cannot switch', () async {
      // Create mock with only one camera
      final singleCameraMock = _SingleCameraMock();
      DivineCameraPlatform.instance = singleCameraMock;

      await DivineCamera.instance.initialize();

      final result = await DivineCamera.instance.switchCamera();

      expect(result, isFalse);
    });

    test('startRecording does nothing when cannot record', () async {
      await DivineCamera.instance.dispose(); // Not initialized

      await DivineCamera.instance.startRecording();

      expect(DivineCamera.instance.isRecording, isFalse);
    });

    test('startRecording with maxDuration', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.startRecording(
        maxDuration: const Duration(seconds: 30),
      );

      expect(DivineCamera.instance.isRecording, isTrue);
    });

    test('startRecording with useCache false', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.startRecording(useCache: false);

      expect(DivineCamera.instance.isRecording, isTrue);
    });

    test('stopRecording returns null when not recording', () async {
      await DivineCamera.instance.initialize();
      // Don't start recording

      final result = await DivineCamera.instance.stopRecording();

      expect(result, isNull);
    });

    test('handleAppLifecycleState paused releases audio on pause', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.paused,
      );

      // Genuine background frees the mic to clear the lock-screen indicator.
      expect(mockPlatform.lastPauseReleaseAudio, isTrue);
      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState inactive keeps audio session', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.inactive,
      );

      // Transient interruption stops video only — leaving audio alone avoids
      // churning other apps' playback on Control Center / app-switcher pulls.
      expect(mockPlatform.lastPauseReleaseAudio, isFalse);
      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState detached calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.detached,
      );

      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState hidden calls pausePreview', () async {
      await DivineCamera.instance.initialize();

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.hidden,
      );

      expect(DivineCamera.instance.isInitialized, isTrue);
    });

    test('handleAppLifecycleState resumed updates state', () async {
      await DivineCamera.instance.initialize();

      // Set callback AFTER initialize to test that resumed triggers it
      CameraState? receivedState;
      DivineCamera.instance.onStateChanged = (state) {
        receivedState = state;
      };

      // Verify callback hasn't been called yet (since we set it after init)
      expect(receivedState, isNull);

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.resumed,
      );

      // Now onStateChanged should be called by handleAppLifecycleState
      expect(receivedState, isNotNull);
      expect(receivedState!.isInitialized, isTrue);
    });

    test('handleAppLifecycleState does nothing when not initialized', () async {
      await DivineCamera.instance.dispose();

      CameraState? receivedState;
      DivineCamera.instance.onStateChanged = (state) {
        receivedState = state;
      };

      await DivineCamera.instance.handleAppLifecycleState(
        AppLifecycleState.paused,
      );

      // onStateChanged should NOT be called since camera is not initialized
      expect(receivedState, isNull);
      expect(DivineCamera.instance.isInitialized, isFalse);
    });

    test('getter properties return correct values', () async {
      await DivineCamera.instance.initialize();

      expect(DivineCamera.instance.cameraAspectRatio, isA<double>());
      expect(DivineCamera.instance.hasFlash, isTrue);
      expect(DivineCamera.instance.hasFrontCamera, isTrue);
      expect(DivineCamera.instance.hasBackCamera, isTrue);
      expect(DivineCamera.instance.isFocusPointSupported, isTrue);
      expect(DivineCamera.instance.isExposurePointSupported, isTrue);
      expect(DivineCamera.instance.isSwitchingCamera, isFalse);
      expect(DivineCamera.instance.textureId, 1);
      expect(DivineCamera.instance.lens, DivineCameraLens.back);
    });

    test('dispose clears callbacks', () async {
      DivineCamera.instance.onStateChanged = (_) {};
      DivineCamera.instance.onRecordingAutoStopped = (_) {};
      DivineCamera.instance.onScreenFlashChanged = (_) {};

      await DivineCamera.instance.initialize();
      await DivineCamera.instance.dispose();

      expect(DivineCamera.instance.onStateChanged, isNull);
      expect(DivineCamera.instance.onRecordingAutoStopped, isNull);
      expect(DivineCamera.instance.onScreenFlashChanged, isNull);
    });
  });

  group('CameraLensMetadata', () {
    test('creates metadata with required lensType', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.lensType, 'back');
      expect(metadata.focalLength, isNull);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('creates metadata with all fields', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        focalLength: 4.5,
        focalLengthEquivalent35mm: 26,
        aperture: 1.8,
        sensorWidth: 6.17,
        sensorHeight: 4.55,
        pixelArrayWidth: 4032,
        pixelArrayHeight: 3024,
        minFocusDistance: 10,
        fieldOfView: 80,
        hasOpticalStabilization: true,
        isLogicalCamera: true,
        physicalCameraIds: ['cam0', 'cam1'],
      );

      expect(metadata.lensType, 'back');
      expect(metadata.focalLength, 4.5);
      expect(metadata.focalLengthEquivalent35mm, 26.0);
      expect(metadata.aperture, 1.8);
      expect(metadata.sensorWidth, 6.17);
      expect(metadata.sensorHeight, 4.55);
      expect(metadata.pixelArrayWidth, 4032);
      expect(metadata.pixelArrayHeight, 3024);
      expect(metadata.minFocusDistance, 10.0);
      expect(metadata.fieldOfView, 80.0);
      expect(metadata.hasOpticalStabilization, isTrue);
      expect(metadata.isLogicalCamera, isTrue);
      expect(metadata.physicalCameraIds, ['cam0', 'cam1']);
    });

    test('fromMap creates metadata from map', () {
      final map = {
        'lensType': 'ultraWide',
        'focalLength': 2.5,
        'focalLengthEquivalent35mm': 13.0,
        'aperture': 2.2,
        'sensorWidth': 5.0,
        'sensorHeight': 3.75,
        'pixelArrayWidth': 3024,
        'pixelArrayHeight': 2268,
        'minFocusDistance': 25.0,
        'fieldOfView': 120.0,
        'hasOpticalStabilization': false,
        'isLogicalCamera': false,
        'physicalCameraIds': <String>[],
      };

      final metadata = CameraLensMetadata.fromMap(map);

      expect(metadata.lensType, 'ultraWide');
      expect(metadata.focalLength, 2.5);
      expect(metadata.focalLengthEquivalent35mm, 13.0);
      expect(metadata.aperture, 2.2);
      expect(metadata.sensorWidth, 5.0);
      expect(metadata.sensorHeight, 3.75);
      expect(metadata.pixelArrayWidth, 3024);
      expect(metadata.pixelArrayHeight, 2268);
      expect(metadata.minFocusDistance, 25.0);
      expect(metadata.fieldOfView, 120.0);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('fromMap with empty map uses defaults', () {
      final metadata = CameraLensMetadata.fromMap(const {});

      expect(metadata.lensType, 'unknown');
      expect(metadata.focalLength, isNull);
      expect(metadata.hasOpticalStabilization, isFalse);
      expect(metadata.isLogicalCamera, isFalse);
      expect(metadata.physicalCameraIds, isEmpty);
    });

    test('fromMap handles physicalCameraIds with mixed types', () {
      final map = {
        'lensType': 'back',
        'physicalCameraIds': ['cam0', 123, 'cam1', null],
      };

      final metadata = CameraLensMetadata.fromMap(map);

      expect(metadata.physicalCameraIds, ['cam0', 'cam1']);
    });

    test('toMap converts metadata to map', () {
      const metadata = CameraLensMetadata(
        lensType: 'front',
        focalLength: 3,
        focalLengthEquivalent35mm: 22,
        aperture: 2,
        sensorWidth: 4,
        sensorHeight: 3,
        pixelArrayWidth: 2048,
        pixelArrayHeight: 1536,
        minFocusDistance: 5,
        fieldOfView: 90,
        hasOpticalStabilization: true,
        isLogicalCamera: true,
        physicalCameraIds: ['a', 'b'],
      );

      final map = metadata.toMap();

      expect(map['lensType'], 'front');
      expect(map['focalLength'], 3.0);
      expect(map['focalLengthEquivalent35mm'], 22.0);
      expect(map['aperture'], 2.0);
      expect(map['sensorWidth'], 4.0);
      expect(map['sensorHeight'], 3.0);
      expect(map['pixelArrayWidth'], 2048);
      expect(map['pixelArrayHeight'], 1536);
      expect(map['minFocusDistance'], 5.0);
      expect(map['fieldOfView'], 90.0);
      expect(map['hasOpticalStabilization'], isTrue);
      expect(map['isLogicalCamera'], isTrue);
      expect(map['physicalCameraIds'], ['a', 'b']);
    });

    test('megapixels returns correct value', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        pixelArrayWidth: 4000,
        pixelArrayHeight: 3000,
      );

      expect(metadata.megapixels, closeTo(12.0, 0.01));
    });

    test('megapixels returns null when dimensions missing', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.megapixels, isNull);
    });

    test('minFocusDistanceCm returns correct value', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        minFocusDistance: 10, // 10 diopters = 10cm
      );

      expect(metadata.minFocusDistanceCm, closeTo(10.0, 0.01));
    });

    test('minFocusDistanceCm returns null for fixed focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'front',
        minFocusDistance: 0,
      );

      expect(metadata.minFocusDistanceCm, isNull);
    });

    test('minFocusDistanceCm returns null when not set', () {
      const metadata = CameraLensMetadata(lensType: 'front');

      expect(metadata.minFocusDistanceCm, isNull);
    });

    test('isMacroCapable returns true for close focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'ultraWide',
        minFocusDistance: 50, // 50 diopters = 2cm
      );

      expect(metadata.isMacroCapable, isTrue);
    });

    test('isMacroCapable returns false for normal focus', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        minFocusDistance: 10, // 10 diopters = 10cm
      );

      expect(metadata.isMacroCapable, isFalse);
    });

    test('isMacroCapable returns false when focus not set', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      expect(metadata.isMacroCapable, isFalse);
    });

    test('toString returns formatted string', () {
      const metadata = CameraLensMetadata(
        lensType: 'back',
        focalLength: 4.5,
        aperture: 1.8,
        pixelArrayWidth: 4000,
        pixelArrayHeight: 3000,
      );

      final str = metadata.toString();

      expect(str, contains('CameraLensMetadata'));
      expect(str, contains('lensType: back'));
      expect(str, contains('focalLength: 4.5mm'));
      expect(str, contains('aperture: f/1.8'));
      expect(str, contains('12.0MP'));
    });

    test('props returns correct list', () {
      const metadata = CameraLensMetadata(lensType: 'back');

      final props = metadata.props;

      expect(props.length, 20);
      expect(props[0], 'back');
    });

    test('equality works correctly', () {
      const meta1 = CameraLensMetadata(lensType: 'back', focalLength: 4.5);
      const meta2 = CameraLensMetadata(lensType: 'back', focalLength: 4.5);
      const meta3 = CameraLensMetadata(lensType: 'front', focalLength: 4.5);

      expect(meta1, equals(meta2));
      expect(meta1, isNot(equals(meta3)));
    });
  });

  group('CameraState with currentLensMetadata', () {
    test('fromMap parses currentLensMetadata', () {
      final map = {
        'isInitialized': true,
        'currentLensMetadata': {
          'lensType': 'back',
          'focalLength': 4.5,
          'aperture': 1.8,
        },
      };

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNotNull);
      expect(state.currentLensMetadata!.lensType, 'back');
      expect(state.currentLensMetadata!.focalLength, 4.5);
      expect(state.currentLensMetadata!.aperture, 1.8);
    });

    test('fromMap handles null currentLensMetadata', () {
      final map = {'isInitialized': true, 'currentLensMetadata': null};

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNull);
    });

    test('fromMap handles missing currentLensMetadata', () {
      final map = {'isInitialized': true};

      final state = CameraState.fromMap(map);

      expect(state.currentLensMetadata, isNull);
    });
  });

  group(AudioDevice, () {
    test('fromMap creates instance from platform map', () {
      final device = AudioDevice.fromMap(const <dynamic, dynamic>{
        'id': 'mic-1',
        'name': 'Built-in Microphone',
      });

      expect(device.id, equals('mic-1'));
      expect(device.name, equals('Built-in Microphone'));
    });

    test('toString returns formatted string', () {
      const device = AudioDevice(id: 'mic-1', name: 'Built-in Microphone');

      expect(
        device.toString(),
        equals('AudioDevice(id: mic-1, name: Built-in Microphone)'),
      );
    });

    test('equality is based on id', () {
      const deviceA = AudioDevice(id: 'mic-1', name: 'Mic A');
      const deviceB = AudioDevice(id: 'mic-1', name: 'Mic B');
      const deviceC = AudioDevice(id: 'mic-2', name: 'Mic A');

      expect(deviceA, equals(deviceB));
      expect(deviceA, isNot(equals(deviceC)));
    });

    test('hashCode is based on id', () {
      const deviceA = AudioDevice(id: 'mic-1', name: 'Mic A');
      const deviceB = AudioDevice(id: 'mic-1', name: 'Mic B');

      expect(deviceA.hashCode, equals(deviceB.hashCode));
    });

    test('is not equal to non-AudioDevice object', () {
      const device = AudioDevice(id: 'mic-1', name: 'Mic A');

      expect(device, isNot(equals('mic-1')));
    });
  });

  // MethodChannelDivineCamera Tests
  _runMethodChannelTests();
}

/// Mock reporting a non-zero preview rotation with focus/exposure supported,
/// to verify DivineCamera maps tap coords onto the sensor axes before the
/// native focus/exposure call.
class _RotatedFocusMock extends MockDivineCameraPlatform {
  _RotatedFocusMock(this.degrees);

  final int degrees;

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    return CameraState(
      isInitialized: true,
      isFocusPointSupported: true,
      isExposurePointSupported: true,
      previewRotationDegrees: degrees,
    );
  }
}

/// Mock that doesn't support focus point
class _NoFocusSupportMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    return const CameraState(
      isInitialized: true,
      isExposurePointSupported: true,
    );
  }
}

/// Mock that doesn't support exposure point
class _NoExposureSupportMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    return const CameraState(isInitialized: true, isFocusPointSupported: true);
  }
}

/// Mock with only one camera (cannot switch)
class _SingleCameraMock extends MockDivineCameraPlatform {
  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    return const CameraState(isInitialized: true, hasBackCamera: true);
  }
}

/// A class that directly extends DivineCameraPlatform for testing the base
/// class methods that throw UnimplementedError.
class _BasePlatformForTesting extends DivineCameraPlatform {}

void _runMethodChannelTests() {
  group(MethodChannelDivineCamera, () {
    late MethodChannelDivineCamera methodChannelImpl;
    late List<MethodCall> capturedCalls;

    setUp(() {
      methodChannelImpl = MethodChannelDivineCamera();
      capturedCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannelImpl.methodChannel, (
            methodCall,
          ) async {
            capturedCalls.add(methodCall);
            switch (methodCall.method) {
              case 'setRemoteRecordControlEnabled':
                return true;
              case 'setVolumeKeysEnabled':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannelImpl.methodChannel, null);
    });

    test('onRemoteRecordTrigger getter returns null initially', () {
      expect(methodChannelImpl.onRemoteRecordTrigger, isNull);
    });

    test('onRemoteRecordTrigger setter sets callback', () {
      void callback(RemoteRecordTrigger trigger) {}
      methodChannelImpl.onRemoteRecordTrigger = callback;
      expect(methodChannelImpl.onRemoteRecordTrigger, equals(callback));
    });

    test('onRemoteRecordTrigger setter can clear callback', () {
      void callback(RemoteRecordTrigger trigger) {}
      methodChannelImpl
        ..onRemoteRecordTrigger = callback
        ..onRemoteRecordTrigger = null;
      expect(methodChannelImpl.onRemoteRecordTrigger, isNull);
    });

    test('onScreenFlashChanged setter sets callback', () {
      final changes = <bool>[];
      methodChannelImpl.onScreenFlashChanged = changes.add;
      expect(methodChannelImpl.onScreenFlashChanged, equals(changes.add));
    });

    test('setRemoteRecordControlEnabled invokes method channel', () async {
      final result = await methodChannelImpl.setRemoteRecordControlEnabled(
        enabled: true,
      );

      expect(result, isTrue);
      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.first.method, 'setRemoteRecordControlEnabled');
      expect(capturedCalls.first.arguments, {'enabled': true});
    });

    test('setRemoteRecordControlEnabled with false', () async {
      final result = await methodChannelImpl.setRemoteRecordControlEnabled(
        enabled: false,
      );

      expect(result, isTrue);
      expect(capturedCalls.first.arguments, {'enabled': false});
    });

    test('setVolumeKeysEnabled invokes method channel', () async {
      final result = await methodChannelImpl.setVolumeKeysEnabled(
        enabled: true,
      );

      expect(result, isTrue);
      expect(capturedCalls, hasLength(1));
      expect(capturedCalls.first.method, 'setVolumeKeysEnabled');
      expect(capturedCalls.first.arguments, {'enabled': true});
    });

    test('setVolumeKeysEnabled with false', () async {
      final result = await methodChannelImpl.setVolumeKeysEnabled(
        enabled: false,
      );

      expect(result, isTrue);
      expect(capturedCalls.first.arguments, {'enabled': false});
    });

    group('listAudioDevices', () {
      test('returns parsed devices from method channel', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannelImpl.methodChannel, (
              methodCall,
            ) async {
              capturedCalls.add(methodCall);
              if (methodCall.method == 'listAudioDevices') {
                return <Map<dynamic, dynamic>>[
                  {'id': 'mic-1', 'name': 'Built-in Microphone'},
                  {'id': 'mic-2', 'name': 'External Mic'},
                ];
              }
              return null;
            });

        final devices = await methodChannelImpl.listAudioDevices();

        expect(devices, hasLength(2));
        expect(devices.first.id, equals('mic-1'));
        expect(devices.first.name, equals('Built-in Microphone'));
        expect(devices.last.id, equals('mic-2'));
        expect(devices.last.name, equals('External Mic'));
      });

      test('returns empty list when platform returns null', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannelImpl.methodChannel, (
              methodCall,
            ) async {
              capturedCalls.add(methodCall);
              return null;
            });

        final devices = await methodChannelImpl.listAudioDevices();

        expect(devices, isEmpty);
      });
    });

    group('handleMethodCall', () {
      test('handles onRemoteRecordTrigger callback', () async {
        RemoteRecordTrigger? receivedTrigger;
        methodChannelImpl.onRemoteRecordTrigger = (trigger) {
          receivedTrigger = trigger;
        };

        final binaryMessenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        // Simulate native calling back to Flutter
        const codec = StandardMethodCodec();
        final encoded = codec.encodeMethodCall(
          const MethodCall('onRemoteRecordTrigger', 'volumeDown'),
        );

        await binaryMessenger.handlePlatformMessage(
          'divine_camera',
          encoded,
          (_) {},
        );

        expect(receivedTrigger, equals(RemoteRecordTrigger.volumeDown));
      });

      test('handles onRemoteRecordTrigger with null callback', () async {
        // Ensure no callback is set
        methodChannelImpl.onRemoteRecordTrigger = null;

        final binaryMessenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        const codec = StandardMethodCodec();
        final encoded = codec.encodeMethodCall(
          const MethodCall('onRemoteRecordTrigger', 'volumeUp'),
        );

        await binaryMessenger.handlePlatformMessage(
          'divine_camera',
          encoded,
          (_) {},
        );

        // Callback should still be null (not modified by the call)
        expect(methodChannelImpl.onRemoteRecordTrigger, isNull);
      });

      test('handles onRemoteRecordTrigger with null trigger type', () async {
        var callbackInvoked = false;
        methodChannelImpl.onRemoteRecordTrigger = (_) {
          callbackInvoked = true;
        };

        final binaryMessenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        const codec = StandardMethodCodec();
        // Pass null as the trigger type argument
        final encoded = codec.encodeMethodCall(
          const MethodCall('onRemoteRecordTrigger'),
        );

        await binaryMessenger.handlePlatformMessage(
          'divine_camera',
          encoded,
          (_) {},
        );

        // Callback should NOT be invoked when trigger type is null
        expect(callbackInvoked, isFalse);
      });

      test('handles onScreenFlashChanged callback', () async {
        final changes = <bool>[];
        methodChannelImpl.onScreenFlashChanged = changes.add;

        final binaryMessenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const codec = StandardMethodCodec();

        for (final isActive in [true, false]) {
          await binaryMessenger.handlePlatformMessage(
            'divine_camera',
            codec.encodeMethodCall(
              MethodCall('onScreenFlashChanged', isActive),
            ),
            (_) {},
          );
        }

        expect(changes, equals([true, false]));
      });

      test('handles unknown method call gracefully', () async {
        // Set callbacks to verify they are NOT invoked for unknown methods
        var remoteRecordTriggerInvoked = false;
        methodChannelImpl.onRemoteRecordTrigger = (_) {
          remoteRecordTriggerInvoked = true;
        };

        final binaryMessenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

        const codec = StandardMethodCodec();
        final encoded = codec.encodeMethodCall(
          const MethodCall('unknownMethod'),
        );

        await binaryMessenger.handlePlatformMessage(
          'divine_camera',
          encoded,
          (_) {},
        );

        // No callbacks should have been invoked
        expect(remoteRecordTriggerInvoked, isFalse);
      });
    });
  });
}
