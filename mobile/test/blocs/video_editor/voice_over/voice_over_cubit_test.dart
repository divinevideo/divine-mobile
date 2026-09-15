// ABOUTME: Unit tests for VoiceOverCubit.
// ABOUTME: Covers permission gating, take capture, waveform, and reset.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_cubit.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';

class _FakeRecorder implements VoiceOverRecorderService {
  final StreamController<double> _controller =
      StreamController<double>.broadcast();

  int startCount = 0;
  int stopCount = 0;
  bool disposed = false;
  bool throwOnStart = false;
  bool throwOnStop = false;
  String? lastPath;

  @override
  Stream<double> get amplitudeStream => _controller.stream;

  @override
  Future<void> start(String path) async {
    lastPath = path;
    // Mirror the native recorder, which opens (creates) the output file as
    // part of start — even when it then fails, leaving a partial file behind.
    File(path).writeAsStringSync('audio');
    if (throwOnStart) throw StateError('mic unavailable');
    startCount++;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    if (throwOnStop) throw StateError('stop failed');
    return lastPath;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }

  void emitAmplitude(double value) => _controller.add(value);
}

class _FakeAudioSessionService extends AudioSessionService {
  int configureForMixedPlaybackCount = 0;

  @override
  Future<void> configureForMixedPlayback() async {
    configureForMixedPlaybackCount++;
  }
}

class _FakePermissions implements PermissionsService {
  _FakePermissions(this.checkStatus, {PermissionStatus? requestStatus})
    : requestStatus = requestStatus ?? checkStatus;

  PermissionStatus checkStatus;
  PermissionStatus requestStatus;
  int openSettingsCount = 0;

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async => checkStatus;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async => requestStatus;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCount++;
    return true;
  }

  @override
  Future<PermissionStatus> checkCameraStatus() => throw UnimplementedError();

  @override
  Future<PermissionStatus> requestCameraPermission() =>
      throw UnimplementedError();

  @override
  Future<PermissionStatus> checkGalleryStatus() => throw UnimplementedError();

  @override
  Future<PermissionStatus> requestGalleryPermission() =>
      throw UnimplementedError();
}

/// Permissions fake whose microphone check resolves only when the test
/// completes [microphoneCheck], so a close() can be interleaved mid-await.
class _DeferredPermissions implements PermissionsService {
  final Completer<PermissionStatus> microphoneCheck =
      Completer<PermissionStatus>();

  @override
  Future<PermissionStatus> checkMicrophoneStatus() => microphoneCheck.future;

  @override
  Future<PermissionStatus> requestMicrophonePermission() async =>
      PermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<PermissionStatus> checkCameraStatus() => throw UnimplementedError();

  @override
  Future<PermissionStatus> requestCameraPermission() =>
      throw UnimplementedError();

  @override
  Future<PermissionStatus> checkGalleryStatus() => throw UnimplementedError();

  @override
  Future<PermissionStatus> requestGalleryPermission() =>
      throw UnimplementedError();
}

void main() {
  // The cubit triggers HapticService (a platform channel) on record/stop/
  // delete; the test binding handles those calls without a real device.
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VoiceOverCubit, () {
    late _FakeRecorder recorder;
    late _FakeAudioSessionService audioSessionService;
    late Directory tempDir;

    String takeTitle(int number) => 'Recording $number';

    setUp(() {
      recorder = _FakeRecorder();
      audioSessionService = _FakeAudioSessionService();
      tempDir = Directory.systemTemp.createTempSync('voice_over_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    VoiceOverCubit buildCubit(PermissionsService permissions) {
      return VoiceOverCubit(
        recorder: recorder,
        audioSessionService: audioSessionService,
        permissionsService: permissions,
        takeTitleBuilder: takeTitle,
        storageDirectoryProvider: () async => tempDir,
      );
    }

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    group('requestPermissionAndStart', () {
      test('starts recording when permission is already granted', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.requestPermissionAndStart();

        expect(cubit.state.status, equals(VoiceOverStatus.recording));
        expect(cubit.state.isRecording, isTrue);
        expect(recorder.startCount, equals(1));

        await cubit.close();
      });

      test('requests permission when it can be requested', () async {
        final permissions = _FakePermissions(
          PermissionStatus.canRequest,
          requestStatus: PermissionStatus.granted,
        );
        final cubit = buildCubit(permissions);

        await cubit.requestPermissionAndStart();

        expect(cubit.state.status, equals(VoiceOverStatus.recording));

        await cubit.close();
      });

      test('emits permissionDenied when permission is refused', () async {
        final cubit = buildCubit(
          _FakePermissions(PermissionStatus.requiresSettings),
        );

        await cubit.requestPermissionAndStart();

        expect(cubit.state.status, equals(VoiceOverStatus.permissionDenied));
        expect(cubit.state.isRecording, isFalse);
        expect(recorder.startCount, equals(0));

        await cubit.close();
      });

      test('emits error when the recorder fails to start', () async {
        recorder.throwOnStart = true;
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.requestPermissionAndStart();

        expect(cubit.state.status, equals(VoiceOverStatus.error));

        await cubit.close();
      });

      test(
        'deletes the partial file when the recorder fails to start',
        () async {
          recorder.throwOnStart = true;
          final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

          await cubit.requestPermissionAndStart();

          // start() created the file before throwing; the failed take must not
          // strand it on disk.
          expect(File(recorder.lastPath!).existsSync(), isFalse);

          await cubit.close();
        },
      );

      test('ignores the permission result after the cubit is closed', () async {
        final permissions = _DeferredPermissions();
        final cubit = buildCubit(permissions);

        final pending = cubit.requestPermissionAndStart();
        await cubit.close();
        permissions.microphoneCheck.complete(PermissionStatus.granted);

        // Without the isClosed guard the continuation would emit on the closed
        // cubit and throw a StateError, then throw a second StateError inside
        // the catch which would surface uncaught.
        await expectLater(pending, completes);
        expect(recorder.startCount, equals(0));
      });
    });

    group('amplitude', () {
      test('builds the waveform and advances the duration', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();

        recorder
          ..emitAmplitude(0.4)
          ..emitAmplitude(0.8);
        await flush();

        expect(cubit.state.waveformBars, equals([0.4, 0.8]));
        expect(
          cubit.state.currentDuration,
          equals(const Duration(milliseconds: 200)),
        );

        await cubit.close();
      });
    });

    group('stop', () {
      test('announces stopping before the recorder has stopped', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        final statuses = <VoiceOverStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);

        final stopping = cubit.stop();

        // Emitted synchronously, before the first await in stop(): the
        // preview behind the recorder holds on this, not on the take landing.
        expect(cubit.state.status, equals(VoiceOverStatus.stopping));
        expect(cubit.state.isRecording, isFalse);
        expect(cubit.state.hasLiveTake, isTrue);
        expect(recorder.stopCount, equals(0));
        // The live take keeps its length while it lands.
        expect(
          cubit.state.currentDuration,
          equals(VoiceOverCubit.amplitudeInterval),
        );

        await stopping;
        // The state stream delivers asynchronously; let the last emit land.
        await flush();

        expect(
          statuses,
          equals([VoiceOverStatus.stopping, VoiceOverStatus.idle]),
        );
        expect(cubit.state.takes, hasLength(1));

        await cubit.close();
      });

      test('appends a take with the measured duration', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();

        recorder
          ..emitAmplitude(0.5)
          ..emitAmplitude(0.5)
          ..emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        expect(cubit.state.status, equals(VoiceOverStatus.idle));
        expect(cubit.state.takes, hasLength(1));

        final take = cubit.state.takes.single;
        expect(take.isLocalImport, isTrue);
        expect(take.title, equals('Recording 1'));
        expect(take.duration, closeTo(0.3, 0.0001));
        expect(cubit.state.currentDuration, equals(Duration.zero));
        expect(cubit.state.waveformBars, isEmpty);
        expect(audioSessionService.configureForMixedPlaybackCount, equals(1));

        await cubit.close();
      });

      test('discards a take with no recorded audio', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();

        await cubit.stop();

        expect(cubit.state.takes, isEmpty);
        expect(cubit.state.status, equals(VoiceOverStatus.idle));
        expect(audioSessionService.configureForMixedPlaybackCount, equals(1));

        await cubit.close();
      });

      test('restores mixed playback when recorder stop fails', () async {
        recorder.throwOnStop = true;
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();

        await cubit.stop();

        expect(cubit.state.status, equals(VoiceOverStatus.error));
        expect(audioSessionService.configureForMixedPlaybackCount, equals(1));

        await cubit.close();
      });

      test(
        'deletes the orphaned file when a zero-duration take is discarded',
        () async {
          final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
          await cubit.requestPermissionAndStart();

          final path = recorder.lastPath!;
          expect(File(path).existsSync(), isTrue);

          // No amplitude samples → currentDuration stays zero → discard branch.
          await cubit.stop();

          expect(cubit.state.takes, isEmpty);
          expect(File(path).existsSync(), isFalse);

          await cubit.close();
        },
      );

      test('captures multiple takes without leaving the screen', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.7);
        await flush();
        await cubit.stop();

        expect(cubit.state.takes, hasLength(2));
        expect(recorder.startCount, equals(2));
        expect(
          cubit.state.takes.map((t) => t.title),
          equals(['Recording 1', 'Recording 2']),
        );

        await cubit.close();
      });
    });

    group('deleteLastTake', () {
      test('removes only the most recent take', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.7);
        await flush();
        await cubit.stop();

        final firstTakeId = cubit.state.takes.first.id;
        await cubit.deleteLastTake();

        expect(cubit.state.takes, hasLength(1));
        expect(cubit.state.takes.single.id, equals(firstTakeId));

        await cubit.close();
      });

      test('is a no-op when there are no takes', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.deleteLastTake();

        expect(cubit.state.takes, isEmpty);

        await cubit.close();
      });

      test('deletes the removed take file from disk', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        final path = cubit.state.takes.single.localFilePath!;
        expect(File(path).existsSync(), isTrue);

        await cubit.deleteLastTake();

        expect(File(path).existsSync(), isFalse);

        await cubit.close();
      });

      test('ignores the delete after the cubit is closed mid-delete', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        final path = cubit.state.takes.single.localFilePath!;

        // The recorder screen calls deleteLastTake fire-and-forget with no
        // PopScope, so a back gesture can close the cubit between the file
        // delete and the emit. Without the isClosed guard that emit would throw
        // an uncaught StateError straight to the zone handler.
        final pending = cubit.deleteLastTake();
        await cubit.close();

        await expectLater(pending, completes);
        expect(File(path).existsSync(), isFalse);
      });
    });

    group('prior takes already on the timeline', () {
      test(
        'numbers new takes after the prior ones but resets count and duration',
        () async {
          final cubit = VoiceOverCubit(
            recorder: recorder,
            audioSessionService: audioSessionService,
            permissionsService: _FakePermissions(PermissionStatus.granted),
            takeTitleBuilder: takeTitle,
            priorTakeCount: 2,
            storageDirectoryProvider: () async => tempDir,
          );

          // Count and duration start fresh, ignoring prior takes.
          expect(cubit.state.recordingCount, equals(0));
          expect(cubit.state.totalRecordedDuration, equals(Duration.zero));

          await cubit.requestPermissionAndStart();
          recorder.emitAmplitude(0.5);
          await flush();
          await cubit.stop();

          // Count/duration reflect only this session, but the title continues
          // the numbering past the prior takes.
          expect(cubit.state.recordingCount, equals(1));
          expect(cubit.state.takes.single.title, equals('Recording 3'));
          expect(
            cubit.state.totalRecordedDuration,
            equals(const Duration(milliseconds: 100)),
          );

          await cubit.close();
        },
      );
    });

    group('discardAll', () {
      test('clears recorded takes and resets to idle', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();
        expect(cubit.state.takes, hasLength(1));

        await cubit.discardAll();

        expect(cubit.state.takes, isEmpty);
        expect(cubit.state.status, equals(VoiceOverStatus.idle));
        expect(audioSessionService.configureForMixedPlaybackCount, equals(1));

        await cubit.close();
      });

      test('deletes every take file from disk', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();
        final firstPath = cubit.state.takes.first.localFilePath!;

        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.7);
        await flush();
        await cubit.stop();
        final secondPath = cubit.state.takes.last.localFilePath!;

        expect(File(firstPath).existsSync(), isTrue);
        expect(File(secondPath).existsSync(), isTrue);

        await cubit.discardAll();

        expect(File(firstPath).existsSync(), isFalse);
        expect(File(secondPath).existsSync(), isFalse);

        await cubit.close();
      });

      test('ignores the reset after the cubit is closed mid-discard', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();
        expect(cubit.state.takes, hasLength(1));

        // Lower-risk sibling of the deleteLastTake race (_close awaits this
        // before popping), but the isClosed guard still has to hold if a
        // double-pop closes the cubit before the reset emit runs.
        final pending = cubit.discardAll();
        await cubit.close();

        await expectLater(pending, completes);
      });
    });

    group('over-available warning', () {
      test(
        'flags over-available once recorded time exceeds the clip',
        () async {
          final cubit = VoiceOverCubit(
            recorder: recorder,
            audioSessionService: audioSessionService,
            permissionsService: _FakePermissions(PermissionStatus.granted),
            takeTitleBuilder: takeTitle,
            availableDuration: const Duration(milliseconds: 150),
            storageDirectoryProvider: () async => tempDir,
          );

          await cubit.requestPermissionAndStart();
          expect(cubit.state.isOverAvailable, isFalse);

          // Two 100ms samples (200ms) outgrow the 150ms clip, crossing into the
          // over-available branch that fires the warning haptic.
          recorder
            ..emitAmplitude(0.5)
            ..emitAmplitude(0.5);
          await flush();

          expect(cubit.state.isOverAvailable, isTrue);

          await cubit.close();
        },
      );
    });

    group('re-entrancy', () {
      test('ignores a re-entrant start while one is in flight', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

        await Future.wait([
          cubit.requestPermissionAndStart(),
          cubit.requestPermissionAndStart(),
        ]);

        expect(recorder.startCount, equals(1));
        expect(cubit.state.isRecording, isTrue);

        await cubit.close();
      });

      test('ignores a re-entrant stop while one is in flight', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();

        await Future.wait([cubit.stop(), cubit.stop()]);

        expect(recorder.stopCount, equals(1));
        expect(cubit.state.takes, hasLength(1));

        await cubit.close();
      });
    });

    group('close', () {
      test('restores mixed playback when closed during recording', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();

        await cubit.close();

        expect(audioSessionService.configureForMixedPlaybackCount, equals(1));
      });

      test('discards uncommitted take files', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        final path = cubit.state.takes.single.localFilePath!;
        File(path).writeAsStringSync('audio');
        expect(File(path).existsSync(), isTrue);

        await cubit.close();

        expect(File(path).existsSync(), isFalse);
      });

      test('keeps take files once committed', () async {
        final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));
        await cubit.requestPermissionAndStart();
        recorder.emitAmplitude(0.5);
        await flush();
        await cubit.stop();

        final path = cubit.state.takes.single.localFilePath!;
        File(path).writeAsStringSync('audio');
        cubit.markCommitted();

        await cubit.close();

        expect(File(path).existsSync(), isTrue);
      });
    });

    group('openSettings', () {
      test('delegates to the permissions service', () async {
        final permissions = _FakePermissions(PermissionStatus.requiresSettings);
        final cubit = buildCubit(permissions);

        await cubit.openSettings();

        expect(permissions.openSettingsCount, equals(1));

        await cubit.close();
      });
    });

    test('disposes the recorder on close', () async {
      final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

      await cubit.close();

      expect(recorder.disposed, isTrue);
    });

    test('restores mixed playback when recorder start fails', () async {
      recorder.throwOnStart = true;
      final cubit = buildCubit(_FakePermissions(PermissionStatus.granted));

      await cubit.requestPermissionAndStart();

      expect(cubit.state.status, equals(VoiceOverStatus.error));
      expect(audioSessionService.configureForMixedPlaybackCount, equals(1));

      await cubit.close();
    });
  });
}
