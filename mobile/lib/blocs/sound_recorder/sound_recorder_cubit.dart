// ABOUTME: Cubit for recording a sound with the microphone on the library's
// ABOUTME: Add sound screen: gates the mic permission, meters, and stops.

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:clock/clock.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'sound_recorder_state.dart';

/// Records one sound at a time with the microphone into a scratch file.
///
/// The finished file is published in [SoundRecorderState.recordingPath]; the
/// Add sound screen hands it to `AddSoundCubit`, which moves it into library
/// storage. Until then the file is this cubit's: a recording that is
/// cancelled, superseded by the next one, or still unclaimed when the screen
/// closes is deleted.
class SoundRecorderCubit extends Cubit<SoundRecorderState>
    with CloseGuardedEmit<SoundRecorderState> {
  /// Creates the recorder.
  ///
  /// [recorder] defaults to the `record`-backed microphone service, so the
  /// screen can build the cubit without reaching into the service layer;
  /// tests inject a fake. [scratchDirectoryProvider] defaults to a folder in
  /// the app's temporary directory.
  SoundRecorderCubit({
    required PermissionsService permissionsService,
    required AudioSessionService audioSessionService,
    VoiceOverRecorderService? recorder,
    Future<Directory> Function()? scratchDirectoryProvider,
    DateTime Function()? now,
    Duration maxDuration = defaultMaxDuration,
  }) : _permissionsService = permissionsService,
       _audioSessionService = audioSessionService,
       _recorder = recorder ?? RecordVoiceOverRecorderService(),
       _scratchDirectoryProvider =
           scratchDirectoryProvider ?? _defaultScratchDirectory,
       _now = now ?? clock.now,
       super(SoundRecorderState(maxDuration: maxDuration));

  /// Length at which a recording stops on its own, so a recorder left running
  /// cannot fill the device.
  static const defaultMaxDuration = Duration(minutes: 5);

  /// Interval between two level samples, re-exposed so the waveform can glide
  /// in step without importing the service layer.
  static const Duration amplitudeInterval =
      VoiceOverRecorderService.amplitudeInterval;

  static const _logName = 'SoundRecorderCubit';

  /// Levels kept for the live waveform; more than any phone width shows.
  static const _maxWaveformBars = 256;

  final PermissionsService _permissionsService;
  final AudioSessionService _audioSessionService;
  final VoiceOverRecorderService _recorder;
  final Future<Directory> Function() _scratchDirectoryProvider;
  final DateTime Function() _now;

  StreamSubscription<double>? _amplitudeSubscription;
  StreamSubscription<void>? _systemPauseSubscription;
  Timer? _durationLimit;
  late DateTime _startedAt;

  // Recorder bookkeeping the UI never renders, kept off the state like
  // VoiceOverCubit's: the file being written, and a latch that stops a double
  // tap from starting or stopping the native recorder twice while its state
  // has not flipped yet.
  String? _currentPath;
  bool _isTransitioning = false;

  // Set as close() begins. isClosed only flips at super.close(), after
  // close() has awaited the recorder's dispose, and `record` runs dispose
  // behind the same lock as start: a start in flight returns first. Every
  // step that resumes after an await checks this instead, so nothing it
  // creates outlives the cleanup close() has already done.
  bool _closing = false;
  bool _startCancelled = false;

  bool get _shouldAbortStart => _closing || _startCancelled;

  /// Asks for microphone access if needed, then starts recording.
  ///
  /// Emits [SoundRecorderStatus.permissionDenied] when access is refused. An
  /// earlier recording the screen never took over is deleted first.
  Future<void> start() async {
    if (state.isActive || _isTransitioning) return;
    _isTransitioning = true;
    _startCancelled = false;
    // Announced before the permission prompt and the native start, so the
    // screen can lock the file picker meanwhile. It also makes a repeated
    // failure a new status transition for the view's error listener.
    emitIfOpen(state.copyWith(status: SoundRecorderStatus.starting));
    try {
      var permission = await _permissionsService.checkMicrophoneStatus();
      if (_shouldAbortStart) return;
      if (permission == PermissionStatus.canRequest) {
        permission = await _permissionsService.requestMicrophonePermission();
        if (_shouldAbortStart) return;
      }
      if (permission != PermissionStatus.granted) {
        emitIfOpen(
          state.copyWith(status: SoundRecorderStatus.permissionDenied),
        );
        return;
      }
      await _start();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: SoundRecorderStatus.failed));
    } finally {
      _isTransitioning = false;
      if (_startCancelled && !_closing) {
        if (state.isRecording) {
          await stop();
        } else if (state.isStarting) {
          emitIfOpen(state.copyWith(status: SoundRecorderStatus.idle));
        }
      }
    }
  }

  /// Stops recording and publishes the file in
  /// [SoundRecorderState.recordingPath].
  ///
  /// A sample-less recording shorter than one metering interval is discarded.
  Future<void> stop() async {
    // Losing visibility while the permission prompt/native start is pending
    // must prevent that work from opening a microphone under another screen.
    if (state.isStarting || (_isTransitioning && state.isRecording)) {
      _startCancelled = true;
      return;
    }
    if (!state.isRecording || _isTransitioning) return;
    _isTransitioning = true;
    emitIfOpen(state.copyWith(status: SoundRecorderStatus.stopping));
    unawaited(HapticService.recordingFeedback());
    await _stopMetering();
    try {
      final path = await _recorder.stop() ?? _currentPath;
      _currentPath = null;
      await _safeResetSession();
      // Native capture can continue while level updates stall. Keep such a
      // take, but still discard an immediate tap before the first interval.
      final recorded =
          state.elapsed > Duration.zero ||
          _now().difference(_startedAt) >= amplitudeInterval;
      // close() may already have deleted state.recordingPath, so a take that
      // finishes while closing is deleted here rather than published.
      final keep = recorded && !_closing;
      if (!keep) _deleteFile(path);
      emitIfOpen(
        state.copyWith(
          status: SoundRecorderStatus.idle,
          elapsed: Duration.zero,
          waveformBars: const [],
          recordingPath: keep ? path : null,
        ),
      );
    } catch (error, stackTrace) {
      await _safeResetSession();
      _deleteFile(_currentPath);
      _currentPath = null;
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          status: SoundRecorderStatus.failed,
          elapsed: Duration.zero,
          waveformBars: const [],
        ),
      );
    } finally {
      _isTransitioning = false;
    }
  }

  /// Stops and deletes the recording in progress.
  Future<void> cancel() async {
    if (state.isStarting) {
      _startCancelled = true;
      return;
    }
    if (!state.isRecording || _isTransitioning) return;
    _isTransitioning = true;
    try {
      await _stopMetering();
      await _safeStopRecorder();
      await _safeResetSession();
      _deleteFile(_currentPath);
      _currentPath = null;
      emitIfOpen(
        state.copyWith(
          status: SoundRecorderStatus.idle,
          elapsed: Duration.zero,
          waveformBars: const [],
        ),
      );
    } finally {
      _isTransitioning = false;
    }
  }

  /// Opens the OS settings page, where microphone access is granted after a
  /// permanent refusal.
  Future<void> openSettings() => _permissionsService.openAppSettings();

  /// Clears a refusal the person chose to work around, e.g. by picking a file
  /// instead, so its notice does not linger.
  void dismissPermissionNotice() {
    if (state.status != SoundRecorderStatus.permissionDenied) return;
    emitIfOpen(state.copyWith(status: SoundRecorderStatus.idle));
  }

  Future<void> _start() async {
    // Taken over recordings were moved away already; this only deletes one
    // the screen never claimed.
    _deleteFile(state.recordingPath);
    final directory = await _scratchDirectoryProvider();
    if (_shouldAbortStart) return;
    directory.createSync(recursive: true);

    final path = p.join(
      directory.path,
      'sound_${DateTime.now().microsecondsSinceEpoch}.m4a',
    );
    _currentPath = path;
    // Listen before the native await: an interruption can arrive while the
    // microphone is opening, before the start acknowledgement reaches Dart.
    _systemPauseSubscription = _recorder.systemPauses.listen(
      (_) => _stopOnItsOwn('stop a recording the system paused'),
    );
    try {
      await _recorder.start(path);
    } catch (_) {
      await _stopMetering();
      await _safeResetSession();
      _deleteFile(path);
      _currentPath = null;
      rethrow;
    }

    // A close or loss of visibility can land before native startup settles.
    // Undo that unfinished start here, and never arm the length timer or
    // announce a recording behind the covering screen.
    if (_shouldAbortStart) {
      await _stopMetering();
      await _safeStopRecorder();
      await _safeResetSession();
      _deleteFile(path);
      _currentPath = null;
      return;
    }

    _startedAt = _now();
    _durationLimit = Timer(state.maxDuration, () {
      // Meter samples can stall independently of native capture. The length
      // limit must not depend on the number of samples delivered to Dart.
      emitIfOpen(state.copyWith(elapsed: state.maxDuration));
      _stopOnItsOwn('stop a recording at its length limit');
    });
    emitIfOpen(
      state.copyWith(
        status: SoundRecorderStatus.recording,
        elapsed: Duration.zero,
        waveformBars: const [],
        recordingPath: null,
      ),
    );
    unawaited(HapticService.recordingFeedback());
    _amplitudeSubscription = _recorder.amplitudeStream.listen(_onAmplitude);
  }

  /// Stops the take without the person tapping stop, keeping it.
  void _stopOnItsOwn(String description) {
    runDetached(
      stop(),
      description,
      logName: _logName,
      category: LogCategory.video,
    );
  }

  void _onAmplitude(double amplitude) {
    if (!state.isRecording) return;
    final bars = [...state.waveformBars, amplitude];
    if (bars.length > _maxWaveformBars) {
      bars.removeRange(0, bars.length - _maxWaveformBars);
    }
    final elapsed = _now().difference(_startedAt);
    emitIfOpen(state.copyWith(waveformBars: bars, elapsed: elapsed));
    if (elapsed >= state.maxDuration) {
      _stopOnItsOwn('stop a recording at its length limit');
    }
  }

  Future<void> _stopMetering() async {
    _durationLimit?.cancel();
    _durationLimit = null;
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _systemPauseSubscription?.cancel();
    _systemPauseSubscription = null;
  }

  Future<void> _safeStopRecorder() async {
    try {
      await _recorder.stop();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Hands the audio session back to playback. A session that will not reset
  /// is reported and skipped: it must not drop a finished take, leave a file
  /// behind, or wedge the recorder in `stopping`.
  Future<void> _safeResetSession() async {
    try {
      await _audioSessionService.resetAudioSession();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Deletes a scratch recording. Synchronous on purpose: it is one unlink,
  /// and it keeps cleanup ordered before whatever the caller emits next.
  void _deleteFile(String? path) {
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _stopMetering();
    if (state.isActive) {
      await _safeStopRecorder();
      await _safeResetSession();
    }
    _deleteFile(_currentPath);
    _currentPath = null;
    // A recording the screen took over was moved away already.
    _deleteFile(state.recordingPath);
    try {
      await _recorder.dispose();
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    return super.close();
  }

  static Future<Directory> _defaultScratchDirectory() async {
    final temporary = await getTemporaryDirectory();
    // The Storage screen clears this folder, which is how a recording cut
    // off by the app being killed gets removed.
    return Directory(
      p.join(temporary.path, TempRenderDirectories.soundRecordings),
    );
  }
}
