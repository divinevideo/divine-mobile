import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelDivineCamera platform;
  Map<dynamic, dynamic>? lastInitializeArgs;
  const channel = MethodChannel('divine_camera');

  setUp(() {
    platform = MethodChannelDivineCamera();
    lastInitializeArgs = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          final args = methodCall.arguments as Map<dynamic, dynamic>?;
          switch (methodCall.method) {
            case 'getPlatformVersion':
              return 'Android 14';
            case 'initializeCamera':
              lastInitializeArgs = args;
              return {
                'isInitialized': true,
                'isRecording': false,
                'flashMode': 'off',
                'lens': args?['lens'] ?? 'back',
                'zoomLevel': 1.0,
                'minZoomLevel': 1.0,
                'maxZoomLevel': 8.0,
                'aspectRatio': 1.777,
                'hasFlash': true,
                'hasFrontCamera': true,
                'hasBackCamera': true,
                'isFocusPointSupported': true,
                'isExposurePointSupported': true,
                'textureId': 1,
                'availableLenses': ['front', 'back', 'ultraWide', 'telephoto'],
              };
            case 'disposeCamera':
              return null;
            case 'setFlashMode':
              return true;
            case 'setFocusPoint':
              return true;
            case 'setExposurePoint':
              return true;
            case 'cancelFocusAndMetering':
              return true;
            case 'setZoomLevel':
              return {
                'zoomLevel': args?['level'],
                'minZoomLevel': 0.5,
                'maxZoomLevel': 61.875,
              };
            case 'setVideoStabilizationMode':
              return true;
            case 'switchCamera':
              return {
                'isInitialized': true,
                'isRecording': false,
                'flashMode': 'off',
                'lens': args?['lens'] ?? 'front',
                'zoomLevel': 1.0,
                'minZoomLevel': 1.0,
                'maxZoomLevel': 8.0,
                'aspectRatio': 1.777,
                'hasFlash': true,
                'hasFrontCamera': true,
                'hasBackCamera': true,
                'isFocusPointSupported': true,
                'isExposurePointSupported': true,
                'textureId': 1,
                'availableLenses': ['front', 'back', 'ultraWide', 'telephoto'],
              };
            case 'startRecording':
              return null;
            case 'stopRecording':
              return {
                'filePath': '/path/to/video.mp4',
                'durationMs': 5000,
                'width': 1920,
                'height': 1080,
              };
            case 'capturePhoto':
              return {
                'filePath': '/path/to/photo.jpg',
                'width': 1080,
                'height': 1920,
              };
            case 'pausePreview':
              return null;
            case 'resumePreview':
              return null;
            case 'getCameraState':
              return {
                'isInitialized': true,
                'isRecording': false,
                'flashMode': 'off',
                'lens': 'back',
                'zoomLevel': 1.0,
                'minZoomLevel': 1.0,
                'maxZoomLevel': 8.0,
                'aspectRatio': 1.777,
                'hasFlash': true,
                'hasFrontCamera': true,
                'hasBackCamera': true,
                'isFocusPointSupported': true,
                'isExposurePointSupported': true,
                'textureId': 1,
                'availableLenses': ['front', 'back', 'ultraWide', 'telephoto'],
              };
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('MethodChannelDivineCamera', () {
    test('getPlatformVersion returns platform version', () async {
      expect(await platform.getPlatformVersion(), 'Android 14');
    });

    test('initializeCamera returns CameraState', () async {
      final state = await platform.initializeCamera();

      expect(state.isInitialized, isTrue);
      expect(state.hasFlash, isTrue);
      expect(state.hasFrontCamera, isTrue);
      expect(state.hasBackCamera, isTrue);
      expect(state.textureId, 1);
    });

    test(
      'initializeCamera defaults to the platform audio processing',
      () async {
        await platform.initializeCamera();

        expect(lastInitializeArgs?['preferUnprocessedAudio'], isFalse);
      },
    );

    test('initializeCamera forwards the unprocessed-audio request', () async {
      // iOS reads this key to pick the recording audio-session mode (#7796)
      // and Android to pick the recording audio source (#8079); dropping it
      // here silently strands the Music mode setting.
      await platform.initializeCamera(preferUnprocessedAudio: true);

      expect(lastInitializeArgs?['preferUnprocessedAudio'], isTrue);
    });

    test('initializeCamera with front lens', () async {
      final state = await platform.initializeCamera(
        lens: DivineCameraLens.front,
      );

      expect(state.lens, DivineCameraLens.front);
    });

    test('initializeCamera with video quality', () async {
      final state = await platform.initializeCamera(
        videoQuality: DivineVideoQuality.uhd,
      );

      expect(state.isInitialized, isTrue);
    });

    test('initializeCamera with enableScreenFlash false', () async {
      final state = await platform.initializeCamera(enableScreenFlash: false);

      expect(state.isInitialized, isTrue);
    });

    test('disposeCamera completes without error', () async {
      await expectLater(platform.disposeCamera(), completes);
    });

    test('setFlashMode returns true', () async {
      final result = await platform.setFlashMode(DivineCameraFlashMode.torch);

      expect(result, isTrue);
    });

    test('setFocusPoint returns true', () async {
      final result = await platform.setFocusPoint(const Offset(0.5, 0.5));

      expect(result, isTrue);
    });

    test('setVideoStabilizationMode returns true', () async {
      final result = await platform.setVideoStabilizationMode(
        DivineVideoStabilizationMode.cinematic,
      );

      expect(result, isTrue);
    });

    test('setExposurePoint returns true', () async {
      final result = await platform.setExposurePoint(const Offset(0.3, 0.7));

      expect(result, isTrue);
    });

    test('cancelFocusAndMetering returns true', () async {
      final result = await platform.cancelFocusAndMetering();

      expect(result, isTrue);
    });

    test('setZoomLevel returns the applied zoom state', () async {
      final result = await platform.setZoomLevel(2.5);

      expect(result, isNotNull);
      expect(result!.zoomLevel, 2.5);
      expect(result.minZoomLevel, 0.5);
      expect(result.maxZoomLevel, 61.875);
    });

    test('switchCamera returns updated CameraState', () async {
      final state = await platform.switchCamera(DivineCameraLens.front);

      expect(state.lens, DivineCameraLens.front);
    });

    test('switchCamera to ultraWide returns correct lens', () async {
      final state = await platform.switchCamera(DivineCameraLens.ultraWide);

      expect(state.lens, DivineCameraLens.ultraWide);
    });

    test('switchCamera to telephoto returns correct lens', () async {
      final state = await platform.switchCamera(DivineCameraLens.telephoto);

      expect(state.lens, DivineCameraLens.telephoto);
    });

    test('initializeCamera returns availableLenses', () async {
      final state = await platform.initializeCamera();

      expect(state.availableLenses, isNotEmpty);
      expect(state.availableLenses, contains(DivineCameraLens.front));
      expect(state.availableLenses, contains(DivineCameraLens.back));
      expect(state.availableLenses, contains(DivineCameraLens.ultraWide));
      expect(state.availableLenses, contains(DivineCameraLens.telephoto));
    });

    test(
      'CameraState hasUltraWideCamera returns true when available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasUltraWideCamera, isTrue);
      },
    );

    test(
      'CameraState hasTelephotoCamera returns true when available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasTelephotoCamera, isTrue);
      },
    );

    test(
      'CameraState hasMacroCamera returns false when not available',
      () async {
        final state = await platform.initializeCamera();

        expect(state.hasMacroCamera, isFalse);
      },
    );

    test('CameraState availableBackLenses filters front camera', () async {
      final state = await platform.initializeCamera();

      expect(
        state.availableBackLenses,
        isNot(contains(DivineCameraLens.front)),
      );
      expect(state.availableBackLenses, contains(DivineCameraLens.back));
      expect(state.availableBackLenses, contains(DivineCameraLens.ultraWide));
    });

    test(
      'CameraState availableFrontLenses returns only front cameras',
      () async {
        final state = await platform.initializeCamera();

        expect(state.availableFrontLenses, contains(DivineCameraLens.front));
        expect(
          state.availableFrontLenses,
          isNot(contains(DivineCameraLens.back)),
        );
        expect(
          state.availableFrontLenses,
          isNot(contains(DivineCameraLens.ultraWide)),
        );
      },
    );

    test('startRecording completes without error', () async {
      await expectLater(platform.startRecording(), completes);
    });

    test('startRecording with maxDuration', () async {
      await expectLater(
        platform.startRecording(maxDuration: const Duration(seconds: 30)),
        completes,
      );
    });

    test('startRecording with useCache false', () async {
      await expectLater(platform.startRecording(useCache: false), completes);
    });

    test('startRecording with outputDirectory', () async {
      await expectLater(
        platform.startRecording(outputDirectory: '/custom/path'),
        completes,
      );
    });

    test('startRecording returns false on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'startRecording') {
              throw PlatformException(
                code: 'RECORD_START_ERROR',
                message: 'Recording failed to start',
              );
            }
            return null;
          });

      final result = await platform.startRecording();
      expect(result, isFalse);

      final logged = LogCaptureService().getRecentLogs().any(
        (entry) =>
            entry.level == LogLevel.error &&
            entry.message.contains('RECORD_START_ERROR'),
      );
      expect(logged, isTrue);
    });

    test('stopRecording returns VideoRecordingResult', () async {
      final result = await platform.stopRecording();

      expect(result, isNotNull);
      expect(result!.filePath, '/path/to/video.mp4');
      expect(result.durationMs, 5000);
      expect(result.width, 1920);
      expect(result.height, 1080);
    });

    test('capturePhoto returns PhotoCaptureResult', () async {
      final result = await platform.capturePhoto();

      expect(result, isNotNull);
      expect(result!.filePath, '/path/to/photo.jpg');
      expect(result.width, 1080);
      expect(result.height, 1920);
    });

    test('capturePhoto forwards outputDirectory and useCache', () async {
      Map<dynamic, dynamic>? sentArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'capturePhoto') {
              sentArgs = methodCall.arguments as Map<dynamic, dynamic>?;
              return {'filePath': '/custom/photo.jpg'};
            }
            return null;
          });

      await platform.capturePhoto(outputDirectory: '/custom', useCache: false);

      expect(sentArgs?['outputDirectory'], '/custom');
      expect(sentArgs?['useCache'], isFalse);
    });

    test('capturePhoto returns null when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'capturePhoto') {
              return null;
            }
            return null;
          });

      final result = await platform.capturePhoto();
      expect(result, isNull);
    });

    test('capturePhoto returns null and logs on PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'capturePhoto') {
              throw PlatformException(
                code: 'PHOTO_CAPTURE_ERROR',
                message: 'Capture failed',
              );
            }
            return null;
          });

      final result = await platform.capturePhoto();
      expect(result, isNull);

      final logged = LogCaptureService().getRecentLogs().any(
        (entry) =>
            entry.level == LogLevel.error &&
            entry.message.contains('PHOTO_CAPTURE_ERROR'),
      );
      expect(logged, isTrue);
    });

    test('pausePreview forwards releaseAudio: true by default', () async {
      Map<dynamic, dynamic>? pauseArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'pausePreview') {
              pauseArgs = methodCall.arguments as Map<dynamic, dynamic>?;
            }
            return null;
          });

      await platform.pausePreview();

      expect(pauseArgs?['releaseAudio'], isTrue);
    });

    test('pausePreview forwards releaseAudio: false when passed', () async {
      Map<dynamic, dynamic>? pauseArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'pausePreview') {
              pauseArgs = methodCall.arguments as Map<dynamic, dynamic>?;
            }
            return null;
          });

      await platform.pausePreview(releaseAudio: false);

      expect(pauseArgs?['releaseAudio'], isFalse);
    });

    test('resumePreview completes without error', () async {
      await expectLater(platform.resumePreview(), completes);
    });

    test('suspendAudioCapture invokes the method with no arguments', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            calls.add(methodCall);
            return null;
          });

      await platform.suspendAudioCapture();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'suspendAudioCapture');
      expect(calls.single.arguments, isNull);
    });

    test('resumeAudioCapture invokes the method with no arguments', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            calls.add(methodCall);
            return null;
          });

      await platform.resumeAudioCapture();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'resumeAudioCapture');
      expect(calls.single.arguments, isNull);
    });

    test('getCameraState returns CameraState', () async {
      final state = await platform.getCameraState();

      expect(state.isInitialized, isTrue);
      expect(state.lens, DivineCameraLens.back);
    });

    test('buildPreview returns Texture widget', () {
      final widget = platform.buildPreview(1);

      expect(widget, isA<Texture>());
      expect((widget as Texture).textureId, 1);
    });

    test('onRecordingAutoStopped getter and setter work', () {
      void Function(VideoRecordingResult)? callback;
      callback = (result) {};

      platform.onRecordingAutoStopped = callback;
      expect(platform.onRecordingAutoStopped, callback);

      platform.onRecordingAutoStopped = null;
      expect(platform.onRecordingAutoStopped, isNull);
    });
  });

  group('MethodChannelDivineCamera error handling', () {
    test('initializeCamera throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'initializeCamera') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.initializeCamera(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('switchCamera throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'switchCamera') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.switchCamera(DivineCameraLens.front),
        throwsA(isA<PlatformException>()),
      );
    });

    test('getCameraState throws when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'getCameraState') {
              return null;
            }
            return null;
          });

      await expectLater(
        platform.getCameraState(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('stopRecording returns null when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'stopRecording') {
              return null;
            }
            return null;
          });

      final result = await platform.stopRecording();
      expect(result, isNull);
    });

    test('setFlashMode returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setFlashMode') {
              return null;
            }
            return null;
          });

      final result = await platform.setFlashMode(DivineCameraFlashMode.on);
      expect(result, isFalse);
    });

    test('setFocusPoint returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setFocusPoint') {
              return null;
            }
            return null;
          });

      final result = await platform.setFocusPoint(const Offset(0.5, 0.5));
      expect(result, isFalse);
    });

    test('setExposurePoint returns false when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setExposurePoint') {
              return null;
            }
            return null;
          });

      final result = await platform.setExposurePoint(const Offset(0.5, 0.5));
      expect(result, isFalse);
    });

    test('setZoomLevel returns null when result is null', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
            if (methodCall.method == 'setZoomLevel') {
              return null;
            }
            return null;
          });

      final result = await platform.setZoomLevel(2);
      expect(result, isNull);
    });
  });

  group('MethodChannelDivineCamera native callbacks', () {
    test('handles onRecordingAutoStopped callback from native', () async {
      VideoRecordingResult? receivedResult;
      platform.onRecordingAutoStopped = (result) {
        receivedResult = result;
      };

      // Simulate native callback by invoking the method channel from "native"
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped', {
          'filePath': '/auto/stopped.mp4',
          'durationMs': 30000,
          'width': 1920,
          'height': 1080,
        }),
      );

      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('divine_camera', envelope, (data) {}),
        completes,
      );

      expect(receivedResult, isNotNull);
      expect(receivedResult!.filePath, '/auto/stopped.mp4');
      expect(receivedResult!.durationMs, 30000);
    });

    test('handles onRecordingAutoStopped with null args', () async {
      platform.onRecordingAutoStopped = (result) {};

      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped'),
      );

      // Should not throw
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('divine_camera', envelope, (data) {}),
        completes,
      );
    });

    test('handles onRecordingAutoStopped with no callback set', () async {
      platform.onRecordingAutoStopped = null;

      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('onRecordingAutoStopped', {'filePath': '/test.mp4'}),
      );

      // Should not throw
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('divine_camera', envelope, (data) {}),
        completes,
      );
    });

    test('handles unknown method call', () async {
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        const MethodCall('unknownMethod'),
      );

      // Should not throw, just return null
      await expectLater(
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('divine_camera', envelope, (data) {}),
        completes,
      );
    });
  });

  group('MethodChannelDivineCamera onNativeLog forwarding', () {
    Future<void> dispatchNativeLog(Object? arguments) {
      const codec = StandardMethodCodec();
      final envelope = codec.encodeMethodCall(
        MethodCall('onNativeLog', arguments),
      );
      return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('divine_camera', envelope, (data) {});
    }

    LogEntry? latestEntryWithMessage(String message) {
      final matches = LogCaptureService().getRecentLogs().where(
        (entry) => entry.message == message,
      );
      return matches.isEmpty ? null : matches.last;
    }

    LogEntry? latestEntryWithName(String name) {
      final matches = LogCaptureService().getRecentLogs().where(
        (entry) => entry.name == name,
      );
      return matches.isEmpty ? null : matches.last;
    }

    test(
      'forwards a warning into UnifiedLogger under the video category',
      () async {
        const message = 'onNativeLog-test-warning-unique';
        await dispatchNativeLog({
          'level': 'warning',
          'message': message,
          'name': 'DivineCamera.Recording',
        });

        final entry = latestEntryWithMessage(message);
        expect(entry, isNotNull);
        expect(entry!.level, LogLevel.warning);
        expect(entry.name, 'DivineCamera.Recording');
        expect(entry.category, LogCategory.video);
      },
    );

    test('maps the error level', () async {
      const message = 'onNativeLog-test-error-unique';
      await dispatchNativeLog({
        'level': 'error',
        'message': message,
        'name': 'DivineCamera.AudioSession',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.error);
    });

    test('maps the debug level', () async {
      const message = 'onNativeLog-test-debug-unique';
      await dispatchNativeLog({
        'level': 'debug',
        'message': message,
        'name': 'DivineCamera.Lifecycle',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.debug);
    });

    test('maps the verbose level', () async {
      const message = 'onNativeLog-test-verbose-unique';
      await dispatchNativeLog({
        'level': 'verbose',
        'message': message,
        'name': 'DivineCamera',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.verbose);
    });

    test('falls back to info for an unknown level', () async {
      const message = 'onNativeLog-test-unknown-level-unique';
      await dispatchNativeLog({
        'level': 'something-unexpected',
        'message': message,
        'name': 'DivineCamera',
      });

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.level, LogLevel.info);
    });

    test('falls back to the native name when none is provided', () async {
      const message = 'onNativeLog-test-default-name-unique';
      await dispatchNativeLog({'level': 'info', 'message': message});

      final entry = latestEntryWithMessage(message);
      expect(entry, isNotNull);
      expect(entry!.name, 'DivineCameraNative');
    });

    test('ignores an entry with an empty message', () async {
      const name = 'DivineCamera-empty-message-unique';
      // Positive control first: a dead dispatcher would also leave the buffer
      // untouched, and the buffer is a ring that stops growing once full, so
      // the guard is asserted on content rather than on bufferSize (#8617).
      const control = 'onNativeLog-empty-message-control-unique';
      await dispatchNativeLog({
        'level': 'warning',
        'message': control,
        'name': name,
      });
      expect(latestEntryWithMessage(control)?.name, name);

      await dispatchNativeLog({
        'level': 'warning',
        'message': '',
        'name': name,
      });

      expect(
        LogCaptureService().getRecentLogs().where(
          (entry) => entry.name == name && entry.message.isEmpty,
        ),
        isEmpty,
      );
    });

    test(
      'carries the native emit timestamp into the forwarded message',
      () async {
        const name = 'DivineCamera-native-timestamp-unique';
        const body = 'Recording completed with audio track (durationMs=6300)';
        await dispatchNativeLog({
          'level': 'info',
          'message': body,
          'name': name,
          'timestampMs': 1789659688123.0,
        });

        final entry = latestEntryWithName(name);
        expect(entry, isNotNull);
        // Both stamps have to survive, rendered the same way: the native one
        // says when the event happened, `entry.timestamp` says when the
        // forward arrived, and the gap is the whole diagnostic (#9291).
        expect(entry!.message, '[native 2026-09-17T15:41:28.123Z] $body');
        expect(entry.timestamp.isUtc, isTrue);
      },
    );

    test('drops an empty message even when native stamps it', () async {
      const name = 'DivineCamera-empty-message-stamped-unique';
      // Positive control: prove the dispatcher reaches the buffer at all
      // before asserting on an absence (#8617).
      await dispatchNativeLog({
        'level': 'warning',
        'message': 'onNativeLog-empty-message-stamped-control-unique',
        'name': name,
        'timestampMs': 1789659688123.0,
      });
      expect(latestEntryWithName(name), isNotNull);

      await dispatchNativeLog({
        'level': 'warning',
        'message': '',
        'name': name,
        'timestampMs': 1789659689456.0,
      });

      // The empty-message guard reads the raw message, so a stamp cannot
      // smuggle a contentless line into the export as '[native ...] '.
      expect(
        LogCaptureService().getRecentLogs().where(
          (entry) => entry.message.contains('15:41:29.456'),
        ),
        isEmpty,
      );
    });

    test('ignores a call with null arguments without throwing', () async {
      await expectLater(dispatchNativeLog(null), completes);
    });
  });
}
