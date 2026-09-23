// ABOUTME: Cubit for managing audio timing/offset selection in the video editor.
// ABOUTME: Handles audio playback, clipping, and offset normalization.

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent, AudioSourceKind;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

part 'audio_timing_state.dart';

/// Cubit for managing audio timing state and playback in the video editor.
///
/// Handles:
/// - Audio playback with clipped source (looped)
/// - Start offset normalization (0.0-1.0 range)
/// - Audio clipping calculation based on offset
/// - Pause/resume during drag interactions
///
/// The fling physics animation remains in the widget layer since it
/// requires a [TickerProvider].
class AudioTimingCubit extends Cubit<AudioTimingState>
    with CloseGuardedEmit<AudioTimingState> {
  /// Creates an [AudioTimingCubit].
  ///
  /// The [sound] is the audio event to edit timing for.
  /// An optional [clipPlayer] can be injected for testing.
  /// An optional [proVideoEditor] can be injected for testing; defaults to
  /// [ProVideoEditor.instance].
  AudioTimingCubit({
    required AudioEvent sound,
    AudioClipPlayer? clipPlayer,
    ProVideoEditor? proVideoEditor,
  }) : _sound = sound,
       _clipPlayer = clipPlayer ?? AudioClipPlayer(),
       _proVideoEditor = proVideoEditor ?? ProVideoEditor.instance,
       super(const AudioTimingState());

  final AudioEvent _sound;
  final AudioClipPlayer _clipPlayer;
  final ProVideoEditor _proVideoEditor;
  StreamSubscription<void>? _completionSubscription;

  static const _logName = 'AudioTimingCubit';

  /// Minimum amount of audio (in seconds) that must remain playable after
  /// the chosen start offset.
  ///
  /// Bounds the scrollable range so users can position the start anywhere
  /// from `0` up to `audioDuration - minRemainingAudioSecs`, even when the
  /// remaining audio is shorter than the video's max duration. The video
  /// will simply play unscored audio for the trailing portion.
  static const double minRemainingAudioSecs = 0.5;

  /// Maximum video duration in seconds.
  static double get _maxDurationSecs =>
      VideoEditorConstants.maxDuration.inMilliseconds / 1000.0;

  /// The scrollable audio range in seconds.
  ///
  /// Allows the start offset to span from `0` to
  /// `audioDuration - minRemainingAudioSecs`. Returns 0 when the audio is
  /// shorter than [minRemainingAudioSecs].
  double get _scrollableAudioSecs {
    final audioDuration = state.audioDuration ?? 0;
    return (audioDuration - minRemainingAudioSecs).clamp(
      0.0,
      double.infinity,
    );
  }

  /// Initializes the cubit: computes initial offset, starts playback.
  ///
  /// Should be called once after the cubit is created, typically in
  /// a post-frame callback.
  Future<void> initialize() async {
    // Sounds from Nostr sometimes don't carry a duration tag — fall back to
    // probing the audio source via ProVideoEditor.getMetadata so the timeline
    // selector still works.
    var audioDuration = _sound.duration ?? 0;
    if (audioDuration <= 0) {
      audioDuration = await _resolveAudioDurationSecs();
    }

    // Restore previous selection offset (normalized 0-1)
    var initialOffset = 0.0;
    final scrollableAudioSecs = (audioDuration - minRemainingAudioSecs).clamp(
      0.0,
      double.infinity,
    );
    if (scrollableAudioSecs > 0) {
      final startTimeSecs = _sound.startOffset.inMilliseconds / 1000.0;
      initialOffset = (startTimeSecs / scrollableAudioSecs).clamp(0.0, 1.0);
    }

    emitIfOpen(
      AudioTimingState(
        startOffset: initialOffset,
        audioDuration: audioDuration,
      ),
    );

    // Listen for audio completion to restart loop
    _completionSubscription = _clipPlayer.completionStream.listen(
      (_) => unawaited(_onPlaybackCompleted()),
    );

    await _loadAndPlayAudio();
  }

  /// Updates the start offset (e.g. from drag or fling animation).
  void updateOffset(double offset) {
    emitIfOpen(state.copyWith(startOffset: offset.clamp(0.0, 1.0)));
  }

  /// Pauses audio playback (e.g. when drag starts).
  Future<void> pausePlayback() async {
    await _clipPlayer.pause();
    emitIfOpen(state.copyWith(isPlaying: false));
  }

  /// Resumes audio playback from the current offset.
  ///
  /// Re-creates the clipped audio source to match the current offset and
  /// starts playback — the same work [_loadAndPlayAudio] does on entry, and
  /// deliberately the same guard. `setClip` reaches `AudioPlayer.load`, and a
  /// clip the platform cannot open (an evicted cache file, a CDN that served
  /// no playable body) raises a `PlatformException` there. That is an
  /// expected failure of loading remote media, not a defect. Before the
  /// timing screen ran this through `runDetached` (#9227), it escaped to the
  /// uncaught-zone reporter on every drag-to-resume.
  Future<void> resumePlayback() => _loadAndPlayAudio();

  /// Stops audio playback completely.
  Future<void> stopPlayback() async {
    await _clipPlayer.stop();
    emitIfOpen(state.copyWith(isPlaying: false));
  }

  /// Calculates the [Duration] start offset for the confirmed selection.
  ///
  /// Converts the normalized offset (0.0-1.0) back to an actual
  /// time position in the audio track.
  Duration calculateStartOffset() {
    final startTimeMs = (state.startOffset * _scrollableAudioSecs * 1000)
        .toInt();
    return Duration(milliseconds: startTimeMs);
  }

  /// Called when playback completes — restarts from the beginning
  /// to implement manual looping.
  Future<void> _onPlaybackCompleted() async {
    await _clipPlayer.seek(Duration.zero);
    await _clipPlayer.play();
  }

  /// Resolves the audio duration in seconds via [ProVideoEditor.getMetadata]
  /// when the [AudioEvent] does not carry a duration value.
  ///
  /// Returns 0 if the audio source is unavailable or metadata extraction
  /// fails.
  Future<double> _resolveAudioDurationSecs() async {
    final resolved = _sound.resolvedSource;
    if (resolved == null) return 0;

    // Imported audio stores an on-disk path; probing it as a network URL
    // throws "No host specified in URI" (issue #5579). resolvedSource picks
    // the right loader so this mirrors the recorder and waveform paths.
    final source = switch (resolved.kind) {
      AudioSourceKind.asset => EditorVideo.asset(resolved.path),
      AudioSourceKind.file => EditorVideo.file(File(resolved.path)),
      AudioSourceKind.network => EditorVideo.network(resolved.path),
    };

    try {
      final metadata = await _proVideoEditor.getMetadata(source);
      return metadata.duration.inMilliseconds / 1000.0;
    } catch (e, s) {
      Log.error(
        'Failed to resolve audio duration for ${_sound.id}: $e',
        name: _logName,
        error: e,
        stackTrace: s,
      );
      return 0;
    }
  }

  /// Loads the selected audio and starts looped playback.
  Future<void> _loadAndPlayAudio() async {
    try {
      await _setClippedAudioSource();
      // Manual looping via _onPlaybackCompleted instead of LoopMode
      // because ClippingAudioSource + LoopMode.one can be unreliable
      await _clipPlayer.play();
      emitIfOpen(state.copyWith(isPlaying: true));
    } catch (e, s) {
      Log.error(
        'Failed to load audio: $e',
        name: _logName,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Creates a clipped audio source for the current selection.
  Future<void> _setClippedAudioSource() async {
    final audioDurationSecs = state.audioDuration ?? 0;
    if (audioDurationSecs <= 0) return;

    final startPositionSecs = state.startOffset * _scrollableAudioSecs;

    // Calculate clip boundaries
    final clipStart = Duration(
      milliseconds: (startPositionSecs * 1000).toInt(),
    );
    // End is either maxDuration after start, or end of audio
    final clipEndSecs = (startPositionSecs + _maxDurationSecs).clamp(
      0.0,
      audioDurationSecs,
    );
    final clipEnd = Duration(milliseconds: (clipEndSecs * 1000).toInt());

    // Determine the URI and which AudioSourceConfig variant fits.
    //
    // Audio extracted from local clips (see
    // ClipEditorBloc._onAudioExtractionRequested) is stored in
    // AudioEvent.url as a bare absolute path like
    // `/var/mobile/.../extracted_audio_<ts>.wav`. Without explicit
    // classification, that path is treated as a network URL and the
    // remote loader calls HttpClient.getUrl on it, throwing
    // "No host specified in URI" (issue #4395).
    final AudioSourceConfig config;
    if (_sound.isBundled && _sound.assetPath != null) {
      config = AudioSourceConfig.asset(
        _sound.assetPath!,
        start: clipStart,
        end: clipEnd,
      );
    } else if (_sound.url != null) {
      config = _configForUrl(
        _sound.url!,
        start: clipStart,
        end: clipEnd,
      );
    } else {
      Log.warning(
        'No audio source available for sound: ${_sound.id}',
        name: _logName,
      );
      return;
    }

    await _clipPlayer.setClip(config);
  }

  /// Classifies a raw URL string from [AudioEvent.url] into the appropriate
  /// [AudioSourceConfig] variant.
  ///
  /// Supports http(s) network URLs and local file paths (bare absolute paths
  /// like `/var/mobile/...` or `file://` URIs). Platform-specific schemes
  /// such as Android `content://` and web `blob:` are not handled and will
  /// fall through to the network variant, where the defense-in-depth check
  /// in [AudioClipPlayer] will surface a clear [ArgumentError].
  static AudioSourceConfig _configForUrl(
    String url, {
    required Duration start,
    required Duration end,
  }) {
    final parsed = Uri.tryParse(url);
    final isLocalFile =
        parsed == null ||
        parsed.scheme.isEmpty ||
        parsed.scheme == 'file' ||
        url.startsWith('/');
    if (isLocalFile) {
      final filePath = parsed != null && parsed.scheme == 'file'
          ? parsed.toFilePath()
          : url;
      return AudioSourceConfig.file(filePath, start: start, end: end);
    }
    return AudioSourceConfig.network(url, start: start, end: end);
  }

  @override
  Future<void> close() async {
    await _completionSubscription?.cancel();
    await _clipPlayer.dispose();
    return super.close();
  }
}
