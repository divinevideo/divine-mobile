import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/desktop/desktop_video_file_inspector.dart';
import 'package:divine_camera/src/desktop/divine_camera_desktop.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  group('DivineCameraDesktop', () {
    late _CameraBackend backend;
    late DivineCameraDesktop camera;
    late _FileInspector fileInspector;

    setUp(() {
      backend = _CameraBackend();
      fileInspector = _FileInspector();
      camera = DivineCameraDesktop(
        cameraPlatform: backend,
        fileInspector: fileInspector,
      );
    });

    tearDown(() async {
      await backend.initialized.close();
      await backend.errors.close();
      await backend.closing.close();
    });

    group('persistent capture', () {
      for (final photo in [false, true]) {
        test(
          'retains ${photo ? 'photo' : 'video'} outside the cache',
          () async {
            final directory = await Directory.systemTemp.createTemp(
              'desktop camera documents ',
            );
            final originalPaths = PathProviderPlatform.instance;
            PathProviderPlatform.instance = _DocumentPaths(directory.path);
            try {
              final source = photo
                  ? await File('test/fixtures/desktop_still_portrait.jpg').copy(
                      '${directory.path}/native.jpg',
                    )
                  : await File('${directory.path}/native.mp4').writeAsBytes([
                      1,
                      2,
                      3,
                    ]);
              backend
                ..photoFile = XFile(source.path)
                ..recordedFile = XFile(source.path);
              await camera.initializeCamera();
              final String path;
              if (photo) {
                path = (await camera.capturePhoto(useCache: false))!.filePath;
              } else {
                await camera.startRecording(useCache: false);
                path = (await camera.stopRecording())!.filePath;
              }

              expect(File(path).parent.path, directory.path);
              expect(path, isNot(source.path));
              expect(
                await File(path).readAsBytes(),
                await source.readAsBytes(),
              );
              await camera.disposeCamera();
              expect(File(path).existsSync(), isTrue);
            } finally {
              await camera.disposeCamera();
              PathProviderPlatform.instance = originalPaths;
              await directory.delete(recursive: true);
            }
          },
        );
      }
    });

    group('initializeCamera', () {
      test('releases an opening device when its error stream fails', () async {
        final gate = Completer<void>();
        backend.initializationGate = gate;
        final initializing = camera.initializeCamera();
        final rejected = expectLater(
          initializing,
          throwsA(isA<CameraException>()),
        );
        await backend.initializationEntered.future;
        try {
          backend.errors.add(const CameraErrorEvent(7, 'Synthetic unplug'));
          await rejected;
          expect(backend.activeCameraIds, isEmpty);
          expect((await camera.getCameraState()).isInitialized, isFalse);
        } finally {
          gate.complete();
          await pumpEventQueue();
        }
      });

      test('creates an idle adapter without acquiring hardware', () async {
        final idle = DivineCameraDesktop(cameraPlatform: backend);
        expect((await idle.getCameraState()).isInitialized, isFalse);
        expect(await idle.getPlatformVersion(), isNotEmpty);
        expect(backend.activeCameraIds, isEmpty);
        await idle.disposeCamera();
      });

      for (final entry in const {
        DivineVideoQuality.lowest: ResolutionPreset.low,
        DivineVideoQuality.sd: ResolutionPreset.medium,
        DivineVideoQuality.hd: ResolutionPreset.high,
        DivineVideoQuality.fhd: ResolutionPreset.veryHigh,
        DivineVideoQuality.uhd: ResolutionPreset.ultraHigh,
        DivineVideoQuality.highest: ResolutionPreset.max,
      }.entries) {
        final quality = entry.key;
        test('honors requested $quality capture quality', () async {
          await camera.initializeCamera(videoQuality: quality);
          expect(backend.settings?.resolutionPreset, entry.value);
          expect(backend.settings?.enableAudio, isTrue);
          await camera.disposeCamera();
        });
      }

      test(
        'opens a webcam with microphone audio and honest capabilities',
        () async {
          final state = await camera.initializeCamera(
            mirrorFrontCameraOutput: false,
          );

          expect(state.isInitialized, isTrue);
          expect(await camera.getCameraState(), state);
          expect(state.aspectRatio, 1920 / 1080);
          expect(state.hasFlash, isFalse);
          expect(state.isFocusPointSupported, isFalse);
          expect(state.isVideoStabilizationSupported, isFalse);
          expect(state.minZoomLevel, 1);
          expect(state.maxZoomLevel, 1);
          expect(backend.settings?.enableAudio, isTrue);
          expect(backend.activeCameraIds, {7});
        },
      );
      test('reports missing hardware without retaining a device', () async {
        backend.cameras = [];

        await expectLater(
          camera.initializeCamera(mirrorFrontCameraOutput: false),
          throwsA(isA<CameraException>()),
        );
        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isInitialized, isFalse);
      });

      test('releases a device when initialization is denied', () async {
        backend.initializationError = CameraException(
          'camera_access_denied',
          'Camera access denied',
        );

        await expectLater(
          camera.initializeCamera(mirrorFrontCameraOutput: false),
          throwsA(isA<CameraException>()),
        );
        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isInitialized, isFalse);
      });
    });

    group('disposeCamera', () {
      for (final action in ['recording', 'photo']) {
        test('cancels queued $action before native capture starts', () async {
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          backend.photoFile = XFile('/synthetic/photo.jpg');
          final capture = action == 'recording'
              ? camera.startRecording()
              : camera.capturePhoto();
          final cancelled = expectLater(capture, throwsStateError);

          await camera.disposeCamera();
          await cancelled;

          expect(backend.startCalls, 0);
          expect(backend.photoCalls, 0);
          expect(backend.activeCameraIds, isEmpty);
        });
      }

      test(
        'closes an acquired device without waiting for initialization',
        () async {
          final gate = Completer<void>();
          backend.initializationGate = gate;
          final initializing = camera.initializeCamera(
            mirrorFrontCameraOutput: false,
          );
          await backend.initializationEntered.future;
          final cancelled = expectLater(initializing, throwsStateError);
          final closing = camera.disposeCamera();
          try {
            await closing.timeout(const Duration(seconds: 1));
            expect(backend.activeCameraIds, isEmpty);
          } finally {
            gate.complete();
            await cancelled;
            await closing;
          }
          expect((await camera.getCameraState()).isInitialized, isFalse);
        },
      );

      test('cancels a pending initialization before reopening', () async {
        final gate = Completer<void>();
        backend.initializationGate = gate;
        final initializing = camera.initializeCamera(
          mirrorFrontCameraOutput: false,
          videoQuality: DivineVideoQuality.hd,
        );
        await backend.initializationEntered.future;
        final cancelled = expectLater(initializing, throwsStateError);

        final closed = camera.disposeCamera();
        gate.complete();
        await cancelled;
        await closed;

        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isInitialized, isFalse);
        backend.initializationGate = null;
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        expect(backend.activeCameraIds, {8});
        await camera.disposeCamera();
      });

      test('releases the webcam and allows it to reopen', () async {
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        expect(backend.activeCameraIds, {7});

        await camera.disposeCamera();

        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isInitialized, isFalse);
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        expect((await camera.getCameraState()).isInitialized, isTrue);
        expect(backend.activeCameraIds, {8});
        await camera.disposeCamera();
        expect(backend.activeCameraIds, isEmpty);
      });
    });

    group('buildPreview', () {
      test('does not render a retired camera handle', () async {
        final state = await camera.initializeCamera(
          mirrorFrontCameraOutput: false,
        );
        await camera.disposeCamera();

        expect(camera.buildPreview(state.textureId!), isA<SizedBox>());
      });

      testWidgets('resolves the camera handle to the native texture', (
        tester,
      ) async {
        final state = await tester.runAsync(
          () => camera.initializeCamera(mirrorFrontCameraOutput: false),
        );
        await tester.pumpWidget(camera.buildPreview(state!.textureId!));

        expect(tester.widget<Texture>(find.byType(Texture)).textureId, 107);
        expect(state.textureId, 7);
        await tester.runAsync(camera.disposeCamera);
      });
    });

    group('DivineCamera facade', () {
      test('publishes native device loss and allows a fresh session', () async {
        final original = DivineCameraPlatform.instance;
        final failures = <Object>[];
        final states = <CameraState>[];
        DivineCameraPlatform.instance = camera;
        DivineCamera.instance
          ..onCameraError = failures.add
          ..onStateChanged = states.add;
        try {
          await DivineCamera.instance.initialize();
          expect(DivineCamera.instance.state.isInitialized, isTrue);

          backend.errors.add(const CameraErrorEvent(7, 'Synthetic unplug'));
          await pumpEventQueue();

          expect(backend.activeCameraIds, isEmpty);
          expect(DivineCamera.instance.state.isInitialized, isFalse);
          expect(states.last.isInitialized, isFalse);
          expect(failures.single, isA<CameraException>());
          await DivineCamera.instance.initialize();
          expect(DivineCamera.instance.state.isInitialized, isTrue);
          expect(backend.activeCameraIds, {8});
        } finally {
          await DivineCamera.instance.dispose();
          DivineCameraPlatform.instance = original;
        }
      });

      test('opens and closes through the public app contract', () async {
        final original = DivineCameraPlatform.instance;
        DivineCameraPlatform.instance = camera;
        try {
          final state = await DivineCamera.instance.initialize();

          expect(state.isInitialized, isTrue);
          expect(backend.activeCameraIds, {7});
          await DivineCamera.instance.dispose();
          expect(backend.activeCameraIds, isEmpty);
          expect(DivineCamera.instance.state.isInitialized, isFalse);
        } finally {
          await camera.disposeCamera();
          DivineCameraPlatform.instance = original;
        }
      });
    });

    group('hardware controls', () {
      test(
        'rejects an unavailable lens and preserves usable capture',
        () async {
          final state = await camera.initializeCamera();
          expect(state.availableLenses, [DivineCameraLens.front]);

          await expectLater(
            camera.switchCamera(DivineCameraLens.back),
            throwsArgumentError,
          );

          expect(backend.activeCameraIds, {7});
          expect((await camera.getCameraState()).lens, state.lens);
          expect(await camera.startRecording(), isTrue);
          await camera.disposeCamera();
        },
      );

      test(
        'keeps the current device when its lens is selected again',
        () async {
          final state = await camera.initializeCamera();
          final selected = await camera.switchCamera(state.lens);
          expect(selected, state);
          expect(backend.activeCameraIds, {7});
          expect(backend.nextCameraId, 8);
          await camera.disposeCamera();
        },
      );
      test('clears stale readiness when microphone reopen fails', () async {
        await camera.initializeCamera();
        await camera.suspendAudioCapture();
        expect((await camera.getCameraState()).isInitialized, isTrue);
        backend.initializationError = CameraException(
          'microphone_access_denied',
          'Synthetic microphone denial',
        );

        await expectLater(
          camera.resumeAudioCapture(),
          throwsA(isA<CameraException>()),
        );

        expect((await camera.getCameraState()).isInitialized, isFalse);
        expect(backend.activeCameraIds, isEmpty);
        backend.initializationError = null;
        expect((await camera.initializeCamera()).isInitialized, isTrue);
        await camera.disposeCamera();
      });

      test('reopens the selected camera at the existing quality', () async {
        backend.cameras = const [
          CameraDescription(
            name: 'front',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 0,
          ),
          CameraDescription(
            name: 'back',
            lensDirection: CameraLensDirection.back,
            sensorOrientation: 0,
          ),
        ];
        await camera.initializeCamera(
          lens: DivineCameraLens.front,
          videoQuality: DivineVideoQuality.hd,
          mirrorFrontCameraOutput: false,
        );

        final state = await camera.switchCamera(DivineCameraLens.back);

        expect(state.lens, DivineCameraLens.back);
        expect(backend.selectedCamera?.name, 'back');
        expect(backend.settings?.resolutionPreset, ResolutionPreset.high);
        expect(backend.activeCameraIds, {8});
        await camera.disposeCamera();
      });

      test('does not replace a camera during a recording', () async {
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();

        await expectLater(
          camera.switchCamera(DivineCameraLens.back),
          throwsStateError,
        );

        expect((await camera.getCameraState()).isRecording, isTrue);
        expect(backend.activeCameraIds, {7});
        await camera.disposeCamera();
      });

      test('keeps dual-camera controls unavailable', () async {
        final state = await camera.initializeCamera(
          mirrorFrontCameraOutput: false,
        );

        expect(await camera.setDualCameraEnabled(enabled: false), state);
        await expectLater(
          camera.setDualCameraEnabled(enabled: true),
          throwsUnsupportedError,
        );
        expect((await camera.getCameraState()).isDualCameraSupported, isFalse);
        await camera.disposeCamera();
      });

      test(
        'reports unavailable webcam controls without claiming success',
        () async {
          await camera.initializeCamera(mirrorFrontCameraOutput: false);

          expect(
            await camera.setFlashMode(DivineCameraFlashMode.torch),
            isFalse,
          );
          expect(await camera.setFocusPoint(const Offset(0.5, 0.5)), isFalse);
          expect(
            await camera.setExposurePoint(const Offset(0.5, 0.5)),
            isFalse,
          );
          expect(await camera.cancelFocusAndMetering(), isFalse);
          expect(await camera.setZoomLevel(2), isNull);
          expect(
            await camera.setVideoStabilizationMode(
              DivineVideoStabilizationMode.standard,
            ),
            isFalse,
          );
          expect(
            await camera.setRemoteRecordControlEnabled(enabled: true),
            isFalse,
          );
          expect(await camera.setVolumeKeysEnabled(enabled: true), isFalse);
          await camera.disposeCamera();
        },
      );
    });

    group('preview lifecycle', () {
      test('reports a lost take even when the error listener throws', () async {
        final results = <VideoRecordingResult?>[];
        camera
          ..onCameraError = (_) {
            throw StateError('Synthetic listener failure');
          }
          ..onRecordingAutoStopped = results.add;
        await camera.initializeCamera();
        await camera.startRecording();

        backend.errors.add(const CameraErrorEvent(7, 'Synthetic unplug'));
        await pumpEventQueue();

        expect(results, [null]);
        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isInitialized, isFalse);
        expect((await camera.initializeCamera()).isInitialized, isTrue);
        await camera.disposeCamera();
      });

      test(
        'releases failed capture while its media reader closes',
        () async {
          final errors = <Object>[];
          camera.onCameraError = errors.add;
          backend.recordedFile = XFile('/synthetic/interrupted-reader.mp4');
          fileInspector.pending = Completer<DesktopVideoMetadata>();
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();
          final stopping = camera.stopRecording();
          final cancelled = expectLater(stopping, throwsStateError);
          await fileInspector.entered.future;
          final closing = Completer<void>();
          fileInspector.closing = closing;
          try {
            backend.errors.add(const CameraErrorEvent(7, 'Synthetic unplug'));
            await pumpEventQueue();

            expect(backend.activeCameraIds, isEmpty);
            expect((await camera.getCameraState()).isInitialized, isFalse);
            expect(errors, hasLength(1));
            expect(closing.isCompleted, isFalse);
          } finally {
            closing.complete();
            await cancelled;
            await camera.disposeCamera();
          }
        },
      );

      test('releases devices while a stopped take is inspected', () async {
        backend.recordedFile = XFile('/synthetic/finalizing.mp4');
        fileInspector.pending = Completer<DesktopVideoMetadata>();
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();
        final stopping = camera.stopRecording();
        await fileInspector.entered.future;
        final pausing = camera.pausePreview();
        try {
          await pausing.timeout(const Duration(seconds: 1));
          expect(backend.activeCameraIds, isEmpty);
          fileInspector.pending!.complete(fileInspector.metadata);
          expect((await stopping)?.filePath, '/synthetic/finalizing.mp4');
        } finally {
          if (!fileInspector.pending!.isCompleted) {
            fileInspector.pending!.complete(fileInspector.metadata);
          }
          await stopping;
          await pausing;
          await camera.disposeCamera();
        }
      });

      test('closes background devices before inspecting the take', () async {
        final results = <VideoRecordingResult?>[];
        camera.onRecordingAutoStopped = results.add;
        backend.recordedFile = XFile('/synthetic/background-finalize.mp4');
        fileInspector.pending = Completer<DesktopVideoMetadata>();
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();
        final pausing = camera.pausePreview();
        await fileInspector.entered.future;
        try {
          expect(backend.activeCameraIds, isEmpty);
          expect(results, isEmpty);
          fileInspector.pending!.complete(fileInspector.metadata);
          await pausing;
          expect(
            results.single?.filePath,
            '/synthetic/background-finalize.mp4',
          );
        } finally {
          if (!fileInspector.pending!.isCompleted) {
            fileInspector.pending!.complete(fileInspector.metadata);
          }
          await pausing;
          await camera.disposeCamera();
        }
      });

      for (final event in ['error', 'closing', 'stream error']) {
        test('releases capture after a native $event', () async {
          final results = <VideoRecordingResult?>[];
          camera.onRecordingAutoStopped = results.add;
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();

          switch (event) {
            case 'error':
              backend.errors.add(const CameraErrorEvent(7, 'Synthetic unplug'));
            case 'closing':
              backend.closing.add(const CameraClosingEvent(7));
            case 'stream error':
              backend.errors.addError(StateError('Synthetic device failure'));
          }
          await pumpEventQueue();

          expect(backend.activeCameraIds, isEmpty);
          expect((await camera.getCameraState()).isInitialized, isFalse);
          expect(results, [null]);
          await camera.disposeCamera();
        });
      }

      testWidgets(
        'releases microphone ownership while retaining a live preview handle',
        (tester) async {
          final state = await tester.runAsync(
            () => camera.initializeCamera(mirrorFrontCameraOutput: false),
          );
          try {
            await tester.pumpWidget(camera.buildPreview(state!.textureId!));
            expect(tester.widget<Texture>(find.byType(Texture)).textureId, 107);

            await tester.runAsync(camera.suspendAudioCapture);
            await tester.pump();
            expect(backend.activeCameraIds, {8});
            expect(backend.settings?.enableAudio, isFalse);
            expect((await camera.getCameraState()).textureId, state.textureId);
            expect(tester.widget<Texture>(find.byType(Texture)).textureId, 108);

            await tester.runAsync(camera.resumeAudioCapture);
            await tester.pump();
            expect(backend.activeCameraIds, {9});
            expect(backend.settings?.enableAudio, isTrue);
            expect(tester.widget<Texture>(find.byType(Texture)).textureId, 109);
          } finally {
            await tester.runAsync(camera.disposeCamera);
            await tester.pump();
          }
          expect(find.byType(Texture), findsNothing);
        },
      );

      test(
        'keeps the public camera session ready during audio reconfiguration',
        () async {
          final state = await camera.initializeCamera(
            mirrorFrontCameraOutput: false,
          );
          final gate = Completer<void>();
          backend
            ..initializationGate = gate
            ..nextInitializationEntered = Completer<void>();
          try {
            final suspending = camera.suspendAudioCapture();
            await backend.nextInitializationEntered!.future;
            final pendingState = await camera.getCameraState();
            gate.complete();
            await suspending;

            expect(pendingState.isInitialized, isTrue);
            expect(pendingState.textureId, state.textureId);
            expect(backend.settings?.enableAudio, isFalse);
          } finally {
            if (!gate.isCompleted) gate.complete();
            await camera.disposeCamera();
          }
        },
      );

      test(
        'reopens microphone capture before recording after suspension',
        () async {
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          try {
            await camera.suspendAudioCapture();
            expect(backend.settings?.enableAudio, isFalse);

            await camera.startRecording();

            expect(backend.settings?.enableAudio, isTrue);
            expect(backend.recordingCameraId, 9);
            expect((await camera.getCameraState()).isRecording, isTrue);
          } finally {
            await camera.disposeCamera();
          }
        },
      );

      test('backgrounding cancels a pending camera initialization', () async {
        final gate = Completer<void>();
        backend.initializationGate = gate;
        final initializing = camera.initializeCamera(
          mirrorFrontCameraOutput: false,
          videoQuality: DivineVideoQuality.hd,
        );
        await backend.initializationEntered.future;
        final cancelled = expectLater(initializing, throwsStateError);
        final pausing = camera.pausePreview();
        try {
          await pausing.timeout(const Duration(seconds: 1));
          expect(backend.activeCameraIds, isEmpty);
        } finally {
          gate.complete();
          await cancelled;
          await pausing;
        }
        backend.initializationGate = null;
        await camera.resumePreview();
        expect(backend.activeCameraIds, {8});
        expect(backend.settings?.resolutionPreset, ResolutionPreset.high);
        await camera.disposeCamera();
      });

      test('finalizes a backgrounded take before releasing devices', () async {
        final results = <VideoRecordingResult?>[];
        camera.onRecordingAutoStopped = results.add;
        backend.recordedFile = XFile('/synthetic/background.mp4');
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();

        await camera.pausePreview();

        expect(results.single?.filePath, '/synthetic/background.mp4');
        expect(backend.activeCameraIds, isEmpty);
        expect((await camera.getCameraState()).isRecording, isFalse);
        await camera.resumePreview();
        expect((await camera.getCameraState()).isRecording, isFalse);
        expect(backend.activeCameraIds, {8});
        await camera.disposeCamera();
      });

      test(
        'releases background devices and reopens the selected quality',
        () async {
          await camera.initializeCamera(
            mirrorFrontCameraOutput: false,
            videoQuality: DivineVideoQuality.hd,
          );

          await camera.pausePreview();
          expect(backend.activeCameraIds, isEmpty);
          expect((await camera.getCameraState()).isInitialized, isFalse);
          await camera.resumePreview();
          expect(backend.activeCameraIds, {8});
          expect(backend.settings?.resolutionPreset, ResolutionPreset.high);
          expect((await camera.getCameraState()).isInitialized, isTrue);
          await camera.disposeCamera();
          await camera.resumePreview();
          expect(backend.activeCameraIds, isEmpty);
        },
      );

      test(
        'keeps the device during a transient foreground interruption',
        () async {
          await camera.initializeCamera(mirrorFrontCameraOutput: false);

          await camera.pausePreview(releaseAudio: false);

          expect(backend.activeCameraIds, {7});
          expect(backend.previewPaused, isTrue);
          await camera.resumePreview();
          expect(backend.previewPaused, isFalse);
          expect(backend.activeCameraIds, {7});
          await camera.disposeCamera();
        },
      );
    });

    group('recording', () {
      test(
        'rejects an invalid recording limit without starting capture',
        () async {
          await camera.initializeCamera();
          for (final duration in [Duration.zero, const Duration(seconds: -1)]) {
            await expectLater(
              camera.startRecording(maxDuration: duration),
              throwsArgumentError,
            );
          }
          expect((await camera.getCameraState()).isRecording, isFalse);
          expect(backend.startCalls, 0);
          expect(await camera.startRecording(), isTrue);
          await camera.disposeCamera();
        },
      );

      test(
        'reports a failed duration-limited take and permits retry',
        () async {
          final time = FakeAsync();
          final results = <VideoRecordingResult?>[];
          time.run((time) {
            camera = DivineCameraDesktop(
              cameraPlatform: backend,
              fileInspector: fileInspector,
            )..onRecordingAutoStopped = results.add;
            unawaited(camera.initializeCamera());
            time.flushMicrotasks();
          });
          await pumpEventQueue();
          time.run((time) {
            time.flushMicrotasks();
            backend.stopError = CameraException(
              'stop_failed',
              'Synthetic failure',
            );
            unawaited(
              camera.startRecording(maxDuration: const Duration(seconds: 6)),
            );
            time.flushMicrotasks();
            expect(backend.startCalls, 1);
            expect(time.pendingTimers, hasLength(1));
            time.elapse(const Duration(seconds: 6));
          });
          await pumpEventQueue();
          time.run((time) => time.flushMicrotasks());

          expect(results, [null]);
          expect(backend.activeCameraIds, isEmpty);
          expect((await camera.getCameraState()).isRecording, isFalse);
          CameraState? reopened;
          time.run((time) {
            backend.stopError = null;
            unawaited(
              camera.initializeCamera().then((state) => reopened = state),
            );
            time.flushMicrotasks();
          });
          await pumpEventQueue();
          time.run((time) {
            time.flushMicrotasks();
            expect(reopened?.isInitialized, isTrue);
            unawaited(camera.disposeCamera());
            time.flushMicrotasks();
          });
          await pumpEventQueue();
          time.run((time) => time.flushMicrotasks());
          expect(backend.activeCameraIds, isEmpty);
        },
      );

      test(
        'new initialization cancels inspection before opening capture',
        () async {
          backend.recordedFile = XFile('/synthetic/retired-take.mp4');
          fileInspector.pending = Completer<DesktopVideoMetadata>();
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();
          final stopping = camera.stopRecording();
          final cancelled = expectLater(stopping, throwsStateError);
          await fileInspector.entered.future;

          final state = await camera.initializeCamera(
            mirrorFrontCameraOutput: false,
          );
          await cancelled;

          expect(state.isInitialized, isTrue);
          expect(backend.activeCameraIds, {8});
          expect(await camera.startRecording(), isTrue);
          await camera.disposeCamera();
        },
      );

      test('a failed old take cannot close resumed capture', () async {
        backend.recordedFile = XFile('/synthetic/old-take.mp4');
        fileInspector.pending = Completer<DesktopVideoMetadata>();
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();
        final stopping = camera.stopRecording();
        final rejected = expectLater(stopping, throwsFormatException);
        await fileInspector.entered.future;
        await camera.pausePreview();
        await camera.resumePreview();
        expect(backend.activeCameraIds, {8});

        fileInspector.pending!.completeError(
          const FormatException('Synthetic invalid take'),
        );
        await rejected;

        expect((await camera.getCameraState()).isInitialized, isTrue);
        expect(backend.activeCameraIds, {8});
        expect(await camera.startRecording(), isTrue);
        await camera.disposeCamera();
      });

      test('refuses a new take while the prior take is inspected', () async {
        backend.recordedFile = XFile('/synthetic/prior.mp4');
        fileInspector.pending = Completer<DesktopVideoMetadata>();
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();
        final stopping = camera.stopRecording();
        await fileInspector.entered.future;
        try {
          expect(
            await camera.startRecording().timeout(const Duration(seconds: 1)),
            isFalse,
          );
          expect(backend.startCalls, 1);
          fileInspector.pending!.complete(fileInspector.metadata);
          await stopping;
          expect(await camera.startRecording(), isTrue);
        } finally {
          if (!fileInspector.pending!.isCompleted) {
            fileInspector.pending!.complete(fileInspector.metadata);
          }
          await stopping;
          await camera.disposeCamera();
        }
      });

      test('closing capture cancels unfinished output inspection', () async {
        backend.recordedFile = XFile('/synthetic/pending.mp4');
        fileInspector.pending = Completer<DesktopVideoMetadata>();
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();
        final stopping = camera.stopRecording();
        final cancelled = expectLater(stopping, throwsStateError);
        await fileInspector.entered.future;
        final closing = camera.disposeCamera();
        try {
          await closing.timeout(const Duration(seconds: 1));
          expect(backend.activeCameraIds, isEmpty);
          expect(fileInspector.cancelCalls, 1);
        } finally {
          if (!fileInspector.pending!.isCompleted) {
            fileInspector.pending!.complete(fileInspector.metadata);
          }
          await cancelled;
          await closing;
        }
      });

      test(
        'reports completed file metadata rather than the live preview',
        () async {
          backend.recordedFile = XFile('/synthetic/encoded.mp4');
          fileInspector.metadata = const DesktopVideoMetadata(
            duration: Duration(milliseconds: 1234),
            width: 640,
            height: 480,
            hasAudio: true,
          );
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();

          final result = await camera.stopRecording();

          expect(result?.durationMs, 1234);
          expect(result?.width, 640);
          expect(result?.height, 480);
          expect(fileInspector.inspectedPath, '/synthetic/encoded.mp4');
          await camera.disposeCamera();
        },
      );

      test(
        'rejects a file without microphone audio and releases capture',
        () async {
          backend.recordedFile = XFile('/synthetic/silent.mp4');
          fileInspector.metadata = const DesktopVideoMetadata(
            duration: Duration(seconds: 1),
            width: 640,
            height: 480,
            hasAudio: false,
          );
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();

          await expectLater(
            camera.stopRecording(),
            throwsA(
              isA<CameraException>().having(
                (error) => error.code,
                'code',
                'recording_missing_audio',
              ),
            ),
          );

          expect(backend.activeCameraIds, isEmpty);
          expect((await camera.getCameraState()).isRecording, isFalse);
        },
      );

      test(
        'preserves the Linux fallback container when retaining a take',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'camera-mkv-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = await File(
            '${directory.path}/native.mkv',
          ).writeAsBytes([26, 69, 223, 163]);
          backend.recordedFile = XFile(file.path);
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording(
            outputDirectory: '${directory.path}/saved',
          );

          final result = await camera.stopRecording();

          expect(result!.filePath.endsWith('.mkv'), isTrue);
          expect(await result.file.readAsBytes(), [26, 69, 223, 163]);
          await camera.disposeCamera();
        },
      );

      test(
        'releases a failed stop instead of retaining an active device',
        () async {
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          await camera.startRecording();
          backend.stopError = CameraException(
            'stop_failed',
            'Could not finalize',
          );

          await expectLater(
            camera.stopRecording(),
            throwsA(isA<CameraException>()),
          );
          expect((await camera.getCameraState()).isRecording, isFalse);
          expect(backend.activeCameraIds, isEmpty);
          backend.stopError = null;
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          expect(await camera.startRecording(), isTrue);
          await camera.disposeCamera();
        },
      );

      test(
        'stops at the requested limit and cancels the timer on close',
        () async {
          final time = FakeAsync();
          final results = <VideoRecordingResult?>[];
          time.run((time) {
            camera = DivineCameraDesktop(
              cameraPlatform: backend,
              fileInspector: fileInspector,
            )..onRecordingAutoStopped = results.add;
            backend.recordedFile = XFile('/synthetic/take.mp4');
            unawaited(camera.initializeCamera(mirrorFrontCameraOutput: false));
            time.flushMicrotasks();
          });
          // Broadcast subscription cancellation uses a completed root-zone
          // future. Settle that boundary before advancing the owned timer.
          await pumpEventQueue();
          time.run((time) {
            time.flushMicrotasks();
            unawaited(
              camera.startRecording(maxDuration: const Duration(seconds: 6)),
            );
            time
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 5));
            expect(time.pendingTimers, hasLength(1));
            expect(results, isEmpty);
            time.elapse(const Duration(seconds: 1));
            expect(results.single?.filePath, '/synthetic/take.mp4');
            expect(backend.stopCalls, 1);
            unawaited(
              camera.startRecording(maxDuration: const Duration(seconds: 6)),
            );
            time.flushMicrotasks();
            unawaited(camera.disposeCamera());
            time
              ..flushMicrotasks()
              ..elapse(const Duration(seconds: 6));
            expect(results, hasLength(1));
            expect(time.pendingTimers, isEmpty);
          });
        },
      );

      test('retains a take in a requested output directory', () async {
        final directory = await Directory.systemTemp.createTemp(
          'camera-output-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File(
          '${directory.path}/native.mp4',
        ).writeAsBytes([1, 2, 3]);
        final destination = Directory('${directory.path}/saved');
        backend.recordedFile = XFile(file.path);
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording(outputDirectory: destination.path);

        final result = await camera.stopRecording();
        expect(File(result!.filePath).parent.path, destination.path);
        expect(await result.file.readAsBytes(), [1, 2, 3]);
        await camera.disposeCamera();
        expect(result.file.existsSync(), isTrue);
      });

      test('returns a retained video and allows another take', () async {
        final directory = await Directory.systemTemp.createTemp('camera-take-');
        addTearDown(() => directory.delete(recursive: true));
        final file = await File('${directory.path}/take.mp4').writeAsBytes([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
        ]);
        backend.recordedFile = XFile(file.path);
        await camera.initializeCamera(mirrorFrontCameraOutput: false);

        expect(await camera.startRecording(), isTrue);
        expect((await camera.getCameraState()).isRecording, isTrue);
        final result = await camera.stopRecording();

        expect(result?.filePath, file.path);
        expect(await result!.file.readAsBytes(), await file.readAsBytes());
        expect(result.width, 1920);
        expect(result.height, 1080);
        expect((await camera.getCameraState()).isRecording, isFalse);
        expect(await camera.startRecording(), isTrue);
        expect(await camera.stopRecording(), isNotNull);
        await camera.disposeCamera();
        expect(file.existsSync(), isTrue);
      });

      test('does not leave a denied recording active and can retry', () async {
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        backend.recordingError = CameraException('audio_denied', 'Denied');

        await expectLater(
          camera.startRecording(),
          throwsA(isA<CameraException>()),
        );
        expect((await camera.getCameraState()).isRecording, isFalse);
        backend.recordingError = null;
        expect(await camera.startRecording(), isTrue);
        await camera.disposeCamera();
        expect(backend.activeCameraIds, isEmpty);
      });
    });

    group('capturePhoto', () {
      test('does not take a still during a video recording', () async {
        await camera.initializeCamera(mirrorFrontCameraOutput: false);
        await camera.startRecording();

        expect(await camera.capturePhoto(), isNull);
        expect(backend.photoCalls, 0);
        expect((await camera.getCameraState()).isRecording, isTrue);
        await camera.disposeCamera();
      });

      test('returns a retained still in the requested directory', () async {
        final directory = await Directory.systemTemp.createTemp(
          'camera-still-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = await File('test/fixtures/desktop_still_portrait.jpg')
            .copy(
              '${directory.path}/native.jpg',
            );
        backend.photoFile = XFile(file.path);
        final destination = Directory('${directory.path}/photos');
        await camera.initializeCamera(mirrorFrontCameraOutput: false);

        final result = await camera.capturePhoto(
          outputDirectory: destination.path,
        );

        expect(File(result!.filePath).parent.path, destination.path);
        expect(result.filePath.endsWith('.jpg'), isTrue);
        expect(await result.file.readAsBytes(), await file.readAsBytes());
        expect(result.width, 128);
        expect(result.height, 240);
        await camera.disposeCamera();
        expect(result.file.existsSync(), isTrue);
      });

      test(
        'rejects an invalid native photo without retaining a copy',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'camera-bad-',
          );
          addTearDown(() => directory.delete(recursive: true));
          final file = await File(
            '${directory.path}/bad.jpg',
          ).writeAsBytes([0]);
          backend.photoFile = XFile(file.path);
          final destination = Directory('${directory.path}/photos');
          await camera.initializeCamera(mirrorFrontCameraOutput: false);
          try {
            await expectLater(
              camera.capturePhoto(outputDirectory: destination.path),
              throwsA(isA<Exception>()),
            );

            expect(destination.existsSync(), isFalse);
          } finally {
            await camera.disposeCamera();
          }
        },
      );
    });
  });
}

class _FileInspector extends DesktopVideoFileInspector {
  DesktopVideoMetadata metadata = const DesktopVideoMetadata(
    duration: Duration(seconds: 1),
    width: 1920,
    height: 1080,
    hasAudio: true,
  );
  String? inspectedPath;
  Completer<DesktopVideoMetadata>? pending;
  final entered = Completer<void>();
  int cancelCalls = 0;
  Completer<void>? closing;

  @override
  Future<DesktopVideoMetadata> inspect(String path) async {
    inspectedPath = path;
    if (!entered.isCompleted) entered.complete();
    try {
      return pending == null ? metadata : await pending!.future;
    } finally {
      await closing?.future;
    }
  }

  @override
  Future<void> cancelPending() async {
    cancelCalls++;
    final pendingRead = pending;
    if (pendingRead != null && !pendingRead.isCompleted) {
      pendingRead.completeError(StateError('Recording inspection cancelled'));
    }
    await closing?.future;
  }
}

class _CameraBackend extends CameraPlatform {
  final initialized = StreamController<CameraInitializedEvent>.broadcast();
  final errors = StreamController<CameraErrorEvent>.broadcast();
  final closing = StreamController<CameraClosingEvent>.broadcast();
  final activeCameraIds = <int>{};
  MediaSettings? settings;
  CameraDescription? selectedCamera;
  CameraException? initializationError;
  Completer<void>? initializationGate;
  final initializationEntered = Completer<void>();
  Completer<void>? nextInitializationEntered;
  int? recordingCameraId;
  int nextCameraId = 7;
  XFile? recordedFile;
  XFile? photoFile;
  CameraException? recordingError;
  CameraException? stopError;
  int stopCalls = 0;
  int startCalls = 0;
  int photoCalls = 0;
  bool previewPaused = false;
  List<CameraDescription> cameras = const [
    CameraDescription(
      name: 'synthetic-webcam',
      lensDirection: CameraLensDirection.external,
      sensorOrientation: 0,
    ),
  ];

  @override
  Future<List<CameraDescription>> availableCameras() async => cameras;

  @override
  Future<int> createCameraWithSettings(
    CameraDescription description,
    MediaSettings mediaSettings,
  ) async {
    settings = mediaSettings;
    selectedCamera = description;
    final id = nextCameraId++;
    activeCameraIds.add(id);
    return id;
  }

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {
    if (!initializationEntered.isCompleted) initializationEntered.complete();
    final entered = nextInitializationEntered;
    if (entered != null && !entered.isCompleted) entered.complete();
    await initializationGate?.future;
    if (initializationError case final error?) throw error;
    initialized.add(
      CameraInitializedEvent(
        cameraId,
        1920,
        1080,
        ExposureMode.auto,
        false,
        FocusMode.auto,
        false,
      ),
    );
  }

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      initialized.stream;

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => errors.stream;

  @override
  Stream<CameraClosingEvent> onCameraClosing(int cameraId) => closing.stream;

  @override
  Future<void> startVideoRecording(
    int cameraId, {
    Duration? maxVideoDuration,
  }) async {
    startCalls++;
    if (recordingError case final error?) throw error;
    recordingCameraId = cameraId;
  }

  @override
  Future<XFile> stopVideoRecording(int cameraId) async {
    stopCalls++;
    if (stopError case final error?) throw error;
    return recordedFile!;
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    photoCalls++;
    return photoFile!;
  }

  @override
  Future<void> pausePreview(int cameraId) async {
    previewPaused = true;
  }

  @override
  Future<void> resumePreview(int cameraId) async => previewPaused = false;

  @override
  Widget buildPreview(int cameraId) => Texture(textureId: cameraId + 100);

  @override
  Future<void> dispose(int cameraId) async {
    activeCameraIds.remove(cameraId);
  }
}

class _DocumentPaths extends PathProviderPlatform {
  _DocumentPaths(this.documents);

  final String documents;

  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
}
