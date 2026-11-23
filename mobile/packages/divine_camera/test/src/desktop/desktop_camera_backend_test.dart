import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:divine_camera/src/desktop/desktop_camera_backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('video.divine/desktop_capture_test');
  group('DesktopCameraBackend', () {
    late Directory root;
    late DesktopCameraBackend backend;
    late int id;
    File? nativeFile;
    PlatformException? startError;
    PlatformException? stopError;
    PlatformException? disposalError;
    String? returnedPath;
    Completer<void>? releaseGate;
    late Completer<void> releaseEntered;
    late List<MethodCall> calls;
    Completer<void>? creationGate;
    late Completer<void> creationEntered;
    var nextId = 7;
    Completer<void>? directoryGate;
    late Completer<void> directoryEntered;
    Directory Function(Directory)? wrapDirectory;
    List<Object?>? cameraList;
    Map<String, Object?>? previewSize;
    late Directory expectedCaptureParent;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('capture backend test ');
      calls = [];
      creationGate = null;
      creationEntered = Completer<void>();
      nextId = 7;
      directoryGate = null;
      directoryEntered = Completer<void>();
      wrapDirectory = null;
      cameraList = null;
      previewSize = null;
      expectedCaptureParent = root;
      nativeFile = null;
      returnedPath = null;
      startError = null;
      stopError = null;
      disposalError = null;
      releaseGate = null;
      releaseEntered = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            final args = call.arguments as Map<Object?, Object?>? ?? {};
            switch (call.method) {
              case 'availableCameras':
                return cameraList ??
                    [
                      {
                        'name': 'synthetic',
                        'lensDirection': 2,
                        'sensorOrientation': 0,
                      },
                    ];
              case 'create':
                if (!creationEntered.isCompleted) creationEntered.complete();
                await creationGate?.future;
                final cameraId = nextId++;
                return {'cameraId': cameraId, 'textureId': cameraId + 100};
              case 'initialize':
                return previewSize ??
                    {'previewWidth': 1280, 'previewHeight': 720};
              case 'startVideoRecording':
              case 'takePicture':
                final directory = args['outputDirectory']! as String;
                expect(
                  Directory(directory).parent.path,
                  expectedCaptureParent.path,
                );
                expect(Directory(directory).existsSync(), isTrue);
                nativeFile = await File(
                  '$directory/native.${call.method == 'takePicture' ? 'jpg' : 'mp4'}',
                ).writeAsBytes([1, 2, 3]);
                if (startError case final error?) throw error;
                return call.method == 'takePicture' ? nativeFile!.path : null;
              case 'stopVideoRecording':
                if (stopError case final error?) throw error;
                return returnedPath ?? nativeFile!.path;
              case 'dispose':
                if (!releaseEntered.isCompleted) releaseEntered.complete();
                await releaseGate?.future;
                if (disposalError case final error?) throw error;
                return null;
            }
            return null;
          });
      backend = DesktopCameraBackend(
        channel: channel,
        temporaryDirectory: () async {
          if (!directoryEntered.isCompleted) directoryEntered.complete();
          await directoryGate?.future;
          return wrapDirectory?.call(root) ?? root;
        },
      );
      id = await backend.createCameraWithSettings(
        const CameraDescription(
          name: 'synthetic',
          lensDirection: CameraLensDirection.external,
          sensorOrientation: 0,
        ),
        const MediaSettings(enableAudio: true),
      );
    });

    tearDown(() async {
      if (releaseGate case final gate? when !gate.isCompleted) gate.complete();
      if (creationGate case final gate? when !gate.isCompleted) gate.complete();
      if (directoryGate case final gate? when !gate.isCompleted) {
        gate.complete();
      }
      disposalError = null;
      await backend.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await root.delete(recursive: true);
    });

    group('native camera contract', () {
      test('rejects malformed camera descriptors', () async {
        for (final malformed in <Object?>[
          42,
          {'name': 'missing lens'},
          {'name': 'bad lens', 'lensDirection': 9, 'sensorOrientation': 0},
        ]) {
          cameraList = [malformed];
          await expectLater(
            backend.availableCameras(),
            throwsA(isA<CameraException>()),
          );
        }
      });

      test(
        'rejects invalid preview dimensions without an initialized event',
        () async {
          previewSize = {'previewWidth': 0, 'previewHeight': 720};
          final events = <CameraInitializedEvent>[];
          final subscription = backend
              .onCameraInitialized(id)
              .listen(events.add);
          try {
            await expectLater(
              backend.initializeCamera(id),
              throwsA(isA<CameraException>()),
            );
            await pumpEventQueue();
            expect(events, isEmpty);
          } finally {
            await subscription.cancel();
          }
        },
      );

      test(
        'rejects a duplicate native ID without losing the original camera',
        () async {
          nextId = id;
          await expectLater(
            backend.createCameraWithSettings(
              const CameraDescription(
                name: 'duplicate',
                lensDirection: CameraLensDirection.external,
                sensorOrientation: 0,
              ),
              const MediaSettings(enableAudio: true),
            ),
            throwsA(isA<CameraException>()),
          );
          expect((backend.buildPreview(id) as Texture).textureId, 107);
        },
      );

      test('rejects access to a retired camera', () async {
        await backend.dispose(id);
        expect(() => backend.buildPreview(id), throwsA(isA<CameraException>()));
      });

      test(
        'close waits for late native creation and retires the returned device',
        () async {
          creationGate = Completer<void>();
          creationEntered = Completer<void>();
          final opening = backend.createCameraWithSettings(
            const CameraDescription(
              name: 'second',
              lensDirection: CameraLensDirection.external,
              sensorOrientation: 0,
            ),
            const MediaSettings(enableAudio: true),
          );
          final rejected = expectLater(
            opening,
            throwsA(isA<CameraException>()),
          );
          await creationEntered.future;
          var finished = false;
          final closing = backend.close().then((_) => finished = true);
          try {
            await pumpEventQueue();
            expect(finished, isFalse);
          } finally {
            creationGate!.complete();
            await rejected;
            await closing;
          }
          expect(
            calls
                .where((call) => call.method == 'dispose')
                .map((call) => (call.arguments as Map)['cameraId']),
            unorderedEquals([7, 8]),
          );
        },
      );

      test(
        'enumerates native cameras and exposes the registered texture',
        () async {
          final cameras = await backend.availableCameras();
          expect(cameras.single.name, 'synthetic');
          expect(cameras.single.lensDirection, CameraLensDirection.external);
          expect((backend.buildPreview(id) as Texture).textureId, 107);
        },
      );

      test(
        'publishes initialized dimensions and forwards preview lifecycle',
        () async {
          final initialized = backend.onCameraInitialized(id).first;
          await backend.initializeCamera(id);
          final event = await initialized;
          expect(event.cameraId, id);
          expect(event.previewWidth, 1280);
          expect(event.previewHeight, 720);
          await backend.pausePreview(id);
          await backend.resumePreview(id);
          expect(calls.map((call) => call.method), [
            'create',
            'initialize',
            'pausePreview',
            'resumePreview',
          ]);
        },
      );

      test('routes error and closing events only to their camera', () async {
        final errors = <CameraErrorEvent>[];
        final closing = <CameraClosingEvent>[];
        final wrongCamera = <CameraErrorEvent>[];
        final subscriptions = [
          backend.onCameraError(id).listen(errors.add),
          backend.onCameraClosing(id).listen(closing.add),
          backend.onCameraError(id + 1).listen(wrongCamera.add),
        ];
        try {
          await _nativeCall(channel, 'cameraError', {
            'cameraId': id,
            'description': 'Synthetic unplug',
          });
          await _nativeCall(channel, 'cameraClosing', {'cameraId': id});
          await pumpEventQueue();
          expect(errors.single.description, 'Synthetic unplug');
          expect(closing.single.cameraId, id);
          expect(wrongCamera, isEmpty);
        } finally {
          await Future.wait(
            subscriptions.map((subscription) => subscription.cancel()),
          );
        }
      });

      test('rejects new acquisition after backend close', () async {
        await backend.close();
        await backend.close();
        await expectLater(
          backend.availableCameras(),
          throwsA(isA<CameraException>()),
        );
        expect(calls.where((call) => call.method == 'dispose'), hasLength(1));
      });
    });

    group('recording ownership', () {
      test(
        'default temporary storage releases only its private capture directory',
        () async {
          await backend.close();
          expectedCaptureParent = Directory.systemTemp;
          backend = DesktopCameraBackend(channel: channel);
          id = await backend.createCameraWithSettings(
            const CameraDescription(
              name: 'synthetic',
              lensDirection: CameraLensDirection.external,
              sensorOrientation: 0,
            ),
            const MediaSettings(enableAudio: true),
          );
          await backend.startVideoRecording(id);
          final privateDirectory = nativeFile!.parent;
          expect(nativeFile!.existsSync(), isTrue);
          await backend.dispose(id);
          expect(privateDirectory.existsSync(), isFalse);
          expect(expectedCaptureParent.existsSync(), isTrue);
        },
      );

      test(
        'does not acquire a writer when disposal wins directory allocation',
        () async {
          directoryGate = Completer<void>();
          final starting = backend.startVideoRecording(id);
          final rejected = expectLater(
            starting,
            throwsA(isA<CameraException>()),
          );
          await directoryEntered.future;
          await backend.dispose(id);
          directoryGate!.complete();
          await rejected;
          expect(root.listSync(), isEmpty);
          expect(
            calls.where((call) => call.method == 'startVideoRecording'),
            isEmpty,
          );
        },
      );

      test('rejects stop without a started recording', () async {
        await expectLater(
          backend.stopVideoRecording(id),
          throwsA(isA<CameraException>()),
        );
      });

      test(
        'rejects a missing native stop path and retains cleanup ownership',
        () async {
          await backend.startVideoRecording(id);
          returnedPath = '';
          await expectLater(
            backend.stopVideoRecording(id),
            throwsA(isA<CameraException>()),
          );
          expect(nativeFile!.existsSync(), isTrue);
          await backend.dispose(id);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'removes a partially published take if private cleanup fails',
        () async {
          wrapDirectory = _FailingDeletionParent.new;
          await backend.startVideoRecording(id);
          await expectLater(
            backend.stopVideoRecording(id),
            throwsA(isA<FileSystemException>()),
          );
          expect(root.listSync().whereType<File>(), isEmpty);
          await backend.dispose(id);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'reserves a take before asynchronous directory allocation',
        () async {
          directoryGate = Completer<void>();
          final first = backend.startVideoRecording(id);
          await directoryEntered.future;
          final second = backend.startVideoRecording(id);
          final rejected = expectLater(second, throwsA(isA<CameraException>()));
          directoryGate!.complete();
          await first;
          await rejected;
          expect(
            calls.where((call) => call.method == 'startVideoRecording'),
            hasLength(1),
          );
        },
      );

      test(
        'provides an owned directory before native recording starts',
        () async {
          await backend.startVideoRecording(id);
          expect(nativeFile!.existsSync(), isTrue);
          await backend.dispose(id);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'transfers a stopped take and preserves it after disposal',
        () async {
          await backend.startVideoRecording(id);
          final original = nativeFile!;
          final output = await backend.stopVideoRecording(id);
          expect(output.path, isNot(original.path));
          expect(File(output.path).parent.path, root.path);
          expect(await File(output.path).readAsBytes(), [1, 2, 3]);
          expect(original.parent.existsSync(), isFalse);
          await backend.dispose(id);
          expect(await File(output.path).readAsBytes(), [1, 2, 3]);
          expect(root.listSync().map((entry) => entry.path), [output.path]);
        },
      );

      test(
        'removes a failed-start intermediate before returning the error',
        () async {
          startError = PlatformException(code: 'start_failed');
          await expectLater(
            backend.startVideoRecording(id),
            throwsA(isA<CameraException>()),
          );
          expect(nativeFile!.existsSync(), isFalse);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'cleans failed stop only after native disposal confirms release',
        () async {
          await backend.startVideoRecording(id);
          stopError = PlatformException(code: 'stop_failed');
          await expectLater(
            backend.stopVideoRecording(id),
            throwsA(isA<CameraException>()),
          );
          releaseGate = Completer<void>();
          final closing = backend.dispose(id);
          await releaseEntered.future;
          expect(nativeFile!.existsSync(), isTrue);
          releaseGate!.complete();
          await closing;
          expect(nativeFile!.existsSync(), isFalse);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'retries private-directory cleanup after a filesystem failure',
        () async {
          wrapDirectory = _FailingDeletionParent.new;
          await backend.startVideoRecording(id);
          await expectLater(
            backend.dispose(id),
            throwsA(isA<FileSystemException>()),
          );
          expect(nativeFile!.existsSync(), isTrue);
          await backend.dispose(id);
          expect(root.listSync(), isEmpty);
        },
      );

      test(
        'keeps ownership when native release fails and cleans on retry',
        () async {
          await backend.startVideoRecording(id);
          disposalError = PlatformException(code: 'release_failed');
          await expectLater(
            backend.dispose(id),
            throwsA(isA<CameraException>()),
          );
          expect(nativeFile!.existsSync(), isTrue);
          disposalError = null;
          await backend.dispose(id);
          expect(root.listSync(), isEmpty);
          expect(calls.where((call) => call.method == 'dispose'), hasLength(2));
        },
      );

      test(
        'rejects a foreign stop path without moving or deleting it',
        () async {
          final foreign = await File(
            '${root.path}/foreign.mp4',
          ).writeAsBytes([42]);
          await backend.startVideoRecording(id);
          returnedPath = foreign.path;
          await expectLater(
            backend.stopVideoRecording(id),
            throwsA(isA<CameraException>()),
          );
          await backend.dispose(id);
          expect(await foreign.readAsBytes(), [42]);
          expect(root.listSync().map((entry) => entry.path), [foreign.path]);
        },
      );
    });

    group('takePicture', () {
      test(
        'transfers its owned picture without leaving an intermediate directory',
        () async {
          final output = await backend.takePicture(id);
          expect(await File(output.path).readAsBytes(), [1, 2, 3]);
          expect(nativeFile!.parent.existsSync(), isFalse);
          await backend.dispose(id);
          expect(root.listSync().map((entry) => entry.path), [output.path]);
        },
      );
    });
  });
}

Future<void> _nativeCall(
  MethodChannel channel,
  String method,
  Object? arguments,
) async {
  final response = Completer<void>();
  TestDefaultBinaryMessengerBinding.instance.channelBuffers.push(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    (_) => response.complete(),
  );
  await response.future;
}

class _FailingDeletionParent implements Directory {
  _FailingDeletionParent(this.parentDirectory);
  final Directory parentDirectory;

  @override
  Future<Directory> createTemp([String? prefix]) async =>
      _FailingDeletionDirectory(await parentDirectory.createTemp(prefix));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingDeletionDirectory implements Directory {
  _FailingDeletionDirectory(this.directory);
  final Directory directory;
  bool fail = true;

  @override
  String get path => directory.path;

  @override
  Uri get uri => directory.uri;

  @override
  Directory get parent => directory.parent;

  @override
  Future<String> resolveSymbolicLinks() => directory.resolveSymbolicLinks();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (fail) {
      fail = false;
      throw FileSystemException('Synthetic cleanup failure', path);
    }
    return directory.delete(recursive: recursive);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
