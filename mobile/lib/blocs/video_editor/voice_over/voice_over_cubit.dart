// ABOUTME: Cubit driving the video editor's voice-over recorder.
// ABOUTME: Gates the mic permission, captures takes, and feeds the waveform.

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_editor/voice_over/voice_over_take_placement.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';

part 'voice_over_state.dart';

/// Manages recording one or more voice-over takes without leaving the screen.
///
/// Each completed take is stored as a draft-local [AudioEvent] (via
/// [AudioEvent.fromLocalImport]); the screen commits them to the editor
/// timeline when the user taps Done. Recording is gated behind a microphone
/// permission check using the injected [PermissionsService].
class VoiceOverCubit extends Cubit<VoiceOverState>
    with CloseGuardedEmit<VoiceOverState> {
  /// Creates a [VoiceOverCubit].
  ///
  /// [takeTitleBuilder] returns the localized title for a take given its
  /// 1-based number (resolved by the UI so this layer stays l10n-free), e.g.
  /// "Recording 1". [availableDuration] is the length of the video the
  /// voice-over will be laid over, used to warn when the recording runs too
  /// long. A [storageDirectoryProvider] can be injected for testing; it
  /// defaults to a `voice_over_recordings` folder under the app documents
  /// directory.
  ///
  /// [recorder] defaults to a [RecordVoiceOverRecorderService] so the UI layer
  /// can construct the cubit without importing the service directly (keeping
  /// the UI → BLoC boundary); tests inject a fake.
  VoiceOverCubit({
    required PermissionsService permissionsService,
    required String Function(int takeNumber) takeTitleBuilder,
    VoiceOverRecorderService? recorder,
    AudioSessionService? audioSessionService,
    Duration availableDuration = Duration.zero,
    int priorTakeCount = 0,
    Future<Directory> Function()? storageDirectoryProvider,
  }) : _recorder = recorder ?? RecordVoiceOverRecorderService(),
       _audioSessionService = audioSessionService ?? AudioSessionService(),
       _permissionsService = permissionsService,
       _takeTitleBuilder = takeTitleBuilder,
       _storageDirectoryProvider =
           storageDirectoryProvider ?? _defaultStorageDirectory,
       super(
         VoiceOverState(
           availableDuration: availableDuration,
           priorTakeCount: priorTakeCount,
         ),
       );

  /// Id prefix shared by every voice-over take, so the editor can later
  /// recognise prior voice-over tracks among all audio on the timeline.
  static const voiceOverIdPrefix = '${AudioEvent.localImportMarker}_voice_over';

  /// Re-exposes [VoiceOverRecorderService.amplitudeInterval] (the canonical
  /// owner of the sampling cadence) so the UI's waveform painter can read it
  /// through the cubit it already depends on, without importing the service
  /// layer directly and crossing the UI → BLoC boundary.
  static const Duration amplitudeInterval =
      VoiceOverRecorderService.amplitudeInterval;

  final VoiceOverRecorderService _recorder;
  final AudioSessionService _audioSessionService;
  final PermissionsService _permissionsService;
  final String Function(int takeNumber) _takeTitleBuilder;
  final Future<Directory> Function() _storageDirectoryProvider;

  StreamSubscription<double>? _amplitudeSubscription;

  // `state_management.md` ("No Mutable Instance Variables in BLoC") reserves
  // mutable cubit fields for injected deps and stream handles. The three below
  // are an intentional, documented exception: they hold transient
  // recorder-lifecycle bookkeeping that never needs to be observed by the UI
  // (an in-flight file path, a re-entrancy latch, and a commit flag), so
  // surfacing them through state would add churn without any rendering value.
  String? _currentPath;

  /// Re-entrancy latch for the async start/stop transitions. State only flips
  /// to recording after permission + native `start()` resolve, so without this
  /// a rapid double-tap could start (or stop) the recorder twice before the
  /// status updates.
  bool _isTransitioning = false;

  /// Whether the takes were handed off to the editor via Done. When `false`,
  /// [close] discards the recorded files so a system-back / swipe-close exit
  /// doesn't leave orphaned recordings in app documents.
  bool _committed = false;

  /// Maximum number of amplitude bars retained for the live waveform.
  ///
  /// Kept well above the bar count any phone width can show (the painter draws
  /// a few-px bar per sample and clips the overflow on the left) so the strip
  /// always fills the full width instead of leaving an empty band.
  static const _maxWaveformBars = 256;

  /// Toggles recording: stops the current take or starts a new one.
  Future<void> toggleRecording() =>
      state.isRecording ? stop() : requestPermissionAndStart();

  /// Requests microphone permission if needed, then starts a new take.
  ///
  /// Emits [VoiceOverStatus.permissionDenied] when the user declines. Ignores
  /// re-entrant calls while a start is already in flight.
  Future<void> requestPermissionAndStart() async {
    if (state.isRecording || _isTransitioning) return;
    _isTransitioning = true;
    try {
      var status = await _permissionsService.checkMicrophoneStatus();
      // The screen is dismissible (system back / close) mid-await, which
      // closes the cubit first. Bail before any emit so a closed-cubit
      // StateError can't throw again inside the catch and surface uncaught
      // (a StateError is forwarded to Crashlytics per the error matrix).
      if (isClosed) return;
      if (status == PermissionStatus.canRequest) {
        status = await _permissionsService.requestMicrophonePermission();
        if (isClosed) return;
      }
      if (status != PermissionStatus.granted) {
        emitIfOpen(state.copyWith(status: VoiceOverStatus.permissionDenied));
        return;
      }
      await _start();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!isClosed) emit(state.copyWith(status: VoiceOverStatus.error));
    } finally {
      _isTransitioning = false;
    }
  }

  /// Marks the recorded takes as committed to the editor timeline, so [close]
  /// keeps their files. Called by the screen's Done action.
  void markCommitted() => _committed = true;

  /// Opens the OS app-settings page so the user can grant microphone access
  /// after a permanent denial.
  Future<void> openSettings() => _permissionsService.openAppSettings();

  Future<void> _start() async {
    final directory = await _storageDirectoryProvider();
    if (isClosed) return;
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    final path = p.join(
      directory.path,
      'voice_over_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    _currentPath = path;
    try {
      await _recorder.start(path);
    } catch (_) {
      await _restoreMixedPlayback();
      // start() may have created a partial file before throwing; delete it and
      // clear the field so the failed take can't strand an orphan or be
      // overwritten (and leaked) by the next successful start.
      await _deleteFile(path);
      _currentPath = null;
      rethrow;
    }

    // The screen can close while start() awaits; close() runs its cleanup
    // before this file exists, so reclaim it here and skip the emit on the
    // now-closed cubit.
    if (isClosed) {
      await _deleteFile(path);
      _currentPath = null;
      return;
    }

    emit(
      state.copyWith(
        status: VoiceOverStatus.recording,
        currentDuration: Duration.zero,
        waveformBars: const [],
      ),
    );

    // Confirm the recording started with a tactile pulse.
    unawaited(HapticService.recordingFeedback());

    _amplitudeSubscription = _recorder.amplitudeStream.listen(_onAmplitude);
  }

  void _onAmplitude(double amplitude) {
    if (!state.isRecording) return;
    final bars = [...state.waveformBars, amplitude];
    if (bars.length > _maxWaveformBars) {
      bars.removeRange(0, bars.length - _maxWaveformBars);
    }
    final wasOver = state.isOverAvailable;
    final next = state.copyWith(
      waveformBars: bars,
      currentDuration: state.currentDuration + amplitudeInterval,
    );
    emitIfOpen(next);
    // Warn with a stronger pulse the moment the audio outgrows the video.
    if (!wasOver && next.isOverAvailable) {
      unawaited(HapticService.heavyImpact());
    }
  }

  /// Stops the in-progress take and appends it to [VoiceOverState.takes].
  ///
  /// Flips to [VoiceOverStatus.stopping] before the recorder is asked to
  /// stop, which takes a moment to close the file: anything following the
  /// take — the preview playing behind the recorder — can hold right away
  /// instead of running on until the take lands. A take with zero duration
  /// is discarded.
  Future<void> stop() async {
    if (!state.isRecording || _isTransitioning) return;
    _isTransitioning = true;
    emit(state.copyWith(status: VoiceOverStatus.stopping));
    // Confirm the recording stopped with a tactile pulse.
    unawaited(HapticService.recordingFeedback());
    await _stopMetering();

    try {
      final path = await _recorder.stop() ?? _currentPath;
      await _restoreMixedPlayback();
      final duration = state.currentDuration;
      _currentPath = null;

      // Screen dismissed mid-stop: this take never enters state.takes, and
      // close() may have already nulled _currentPath, so delete the file here
      // to avoid an orphan and bail before emitting on the closed cubit.
      if (isClosed) {
        await _deleteFile(path);
        return;
      }

      if (path == null || duration <= Duration.zero) {
        // The recorder wrote a (near-empty) file even for a take stopped this
        // fast; delete it here since the take never enters state.takes and so
        // would never be reclaimed by close()/discardAll()/deleteLastTake().
        await _deleteFile(path);
        // Close can land during the delete above; bail before the emit so the
        // post-await emit pattern stays uniform with deleteLastTake/discardAll.
        if (isClosed) return;
        emit(
          state.copyWith(
            status: VoiceOverStatus.idle,
            currentDuration: Duration.zero,
            waveformBars: const [],
          ),
        );
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final take = AudioEvent.fromLocalImport(
        id: '${voiceOverIdPrefix}_$now',
        filePath: path,
        createdAt: now ~/ 1000,
        title: _takeTitleBuilder(state.nextTakeNumber),
        mimeType: 'audio/mp4',
        duration: duration.inMilliseconds / 1000,
      );

      emit(
        state.copyWith(
          status: VoiceOverStatus.idle,
          takes: [...state.takes, take],
          currentDuration: Duration.zero,
          waveformBars: const [],
        ),
      );
    } catch (e, stackTrace) {
      await _restoreMixedPlayback();
      addError(e, stackTrace);
      if (!isClosed) emit(state.copyWith(status: VoiceOverStatus.error));
    } finally {
      _isTransitioning = false;
    }
  }

  /// Removes the most recently recorded take and deletes its file.
  ///
  /// No-op while recording or when there are no takes.
  Future<void> deleteLastTake() async {
    if (state.isRecording || state.takes.isEmpty) return;
    final takes = state.takes;
    unawaited(HapticService.lightImpact());
    await _deleteFile(takes.last.localFilePath);
    // The recorder screen calls this fire-and-forget with no PopScope, so a
    // back gesture can close the cubit mid-delete; guard the emit so it can't
    // throw StateError straight to the zone handler.
    if (isClosed) return;
    emit(state.copyWith(takes: takes.sublist(0, takes.length - 1)));
  }

  /// Discards every recorded take (deleting their files) and resets to idle.
  ///
  /// Stops any in-progress recording first. Used by the close action, whose
  /// recordings are never committed to the timeline.
  Future<void> discardAll() async {
    if (state.isRecording) {
      await _stopMetering();
      await _safeStopRecorder();
      await _restoreMixedPlayback();
    }
    await _deleteTakeFiles(state.takes);
    if (_currentPath != null) {
      await _deleteFile(_currentPath);
      _currentPath = null;
    }
    // Same close-mid-await guard as deleteLastTake; lower risk here since
    // _close awaits this before popping, but a double-pop race can still
    // close the cubit before this emit runs.
    if (isClosed) return;
    emit(const VoiceOverState());
  }

  Future<void> _stopMetering() async {
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
  }

  Future<void> _safeStopRecorder() async {
    try {
      await _recorder.stop();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<void> _restoreMixedPlayback() =>
      _audioSessionService.configureForMixedPlayback();

  Future<void> _deleteTakeFiles(List<AudioEvent> takes) async {
    for (final take in takes) {
      await _deleteFile(take.localFilePath);
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) return;
    try {
      await file.delete();
    } catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _stopMetering();
    // Unless the takes were committed via Done, discard their files so a
    // system-back / swipe-close exit (which never runs discardAll) doesn't
    // leave orphaned recordings behind.
    if (!_committed) {
      final wasRecording = state.isRecording;
      await _safeStopRecorder();
      if (wasRecording) {
        await _restoreMixedPlayback();
      }
      await _deleteTakeFiles(state.takes);
      await _deleteFile(_currentPath);
      _currentPath = null;
    }
    await _recorder.dispose();
    return super.close();
  }

  static Future<Directory> _defaultStorageDirectory() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, voiceOverRecordingsDirName));
  }
}
