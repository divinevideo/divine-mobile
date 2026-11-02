// ABOUTME: Plans when sounds get quieter under a voice-over, so the editor
// ABOUTME: preview and the export lower them at exactly the same moments.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:openvine/models/video_editor/audio_render_window.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Measures how loud [tracks] play on the exported video; see
/// [AudioLevelEnvelope.ofTracks].
typedef AudioLevelMeasure = Future<AudioLevelEnvelope> Function(
  List<VideoAudioTrack> tracks, {
  Duration? videoDuration,
});

/// Works out the volume curve of every sound that ducks under the voice-over.
///
/// A sound with [AudioEvent.ducksUnderVoiceOver] drops to its
/// [AudioEvent.duckingVolume] wherever a voice-over take talks, measured by
/// the take's loudness ([AudioDucking]). The preview and the export each ask
/// [curvesFor] with the same sounds, so they plan the same curves wherever
/// both can read the takes: the preview plays them through the player, the
/// render bakes them into the sound.
///
/// The voice-overs are measured once per change to them and kept, so a sound
/// moved or a volume dragged re-plans its dips without decoding again. A
/// measurement that fails is not kept, so the next sync tries again.
class VideoEditorAudioDucking {
  VideoEditorAudioDucking({AudioLevelMeasure? measure})
    : _measure = measure ?? AudioLevelEnvelope.ofTracks;

  final AudioLevelMeasure _measure;

  List<VideoAudioTrack>? _measuredVoices;
  Duration? _measuredDuration;
  Future<AudioLevelEnvelope?>? _envelope;

  /// The curve each ducking sound in [sounds] follows, by sound id.
  ///
  /// [sounds] are the timeline's sounds, voice-overs included, with their
  /// timeline placement; [videoDuration] is where the export ends. A sound
  /// that never needs to go down is left out, and so is every sound when
  /// there is no voice-over or it cannot be measured: the sounds then play
  /// as they are, in the preview and the export alike.
  Future<Map<String, AudioVolumeCurve>> curvesFor(
    List<AudioEvent> sounds, {
    required Duration? videoDuration,
  }) async {
    final ducking = [
      for (final sound in sounds)
        if (sound.ducksUnderVoiceOver && !sound.isVoiceOver) sound,
    ];
    if (ducking.isEmpty) return const {};
    final voices = [
      for (final sound in sounds)
        if (sound.isVoiceOver) ?voiceTrackOf(sound),
    ];
    if (voices.isEmpty) return const {};

    final envelope = await _envelopeOf(voices, videoDuration);
    if (envelope == null) return const {};
    return {
      for (final sound in ducking)
        if (AudioDucking(volume: sound.duckingVolume).curve(envelope)
            case final curve when _lowersWithin(curve, sound, videoDuration))
          sound.id: curve,
    };
  }

  /// Whether [curve] goes below 1 anywhere [sound] plays. The curve is
  /// linear between its points, so its lowest value in a window is at one
  /// of them or at an edge of the window.
  static bool _lowersWithin(
    AudioVolumeCurve curve,
    AudioEvent sound,
    Duration? videoDuration,
  ) {
    final (:startTime, :endTime) = renderWindowOf(sound);
    final from = startTime ?? Duration.zero;
    final to = endTime ?? videoDuration;
    if (curve.volumeAt(from) < 1) return true;
    if (to != null && curve.volumeAt(to) < 1) return true;
    return curve.points.any(
      (point) =>
          point.volume < 1 &&
          point.time > from &&
          (to == null || point.time < to),
    );
  }

  /// [voiceOver] as the render plays it, for measuring when it talks; `null`
  /// when it has no file on this device.
  @visibleForTesting
  static VideoAudioTrack? voiceTrackOf(AudioEvent voiceOver) {
    final path = voiceOver.localFilePath;
    if (path == null) return null;
    final (:startTime, :endTime) = renderWindowOf(voiceOver);
    final speedRamp = voiceOver.speedRamp;
    final rampSpan = speedRamp == null ? null : voiceOver.playedSourceSpan;
    return VideoAudioTrack(
      path: path,
      startTime: startTime,
      endTime: endTime,
      audioStartTime: voiceOver.startOffset,
      // A ramp runs over the stretch the window plays, as in the render.
      audioEndTime: rampSpan == null ? null : voiceOver.startOffset + rampSpan,
      volume: voiceOver.volume,
      playbackSpeed: voiceOver.playbackSpeed,
      speedRamp: speedRamp,
      fadeInDuration: voiceOver.fadeInDuration,
      fadeOutDuration: voiceOver.fadeOutDuration,
    );
  }

  Future<AudioLevelEnvelope?> _envelopeOf(
    List<VideoAudioTrack> voices,
    Duration? videoDuration,
  ) {
    if (_envelope != null &&
        _measuredDuration == videoDuration &&
        listEquals(_measuredVoices, voices)) {
      return _envelope!;
    }
    _measuredVoices = voices;
    _measuredDuration = videoDuration;
    return _envelope = _measureOrNull(voices, videoDuration);
  }

  Future<AudioLevelEnvelope?> _measureOrNull(
    List<VideoAudioTrack> voices,
    Duration? videoDuration,
  ) async {
    try {
      return await _measure(voices, videoDuration: videoDuration);
    } catch (e, stackTrace) {
      // Forget the failure, so the next sync measures again rather than
      // playing flat until the takes change.
      if (identical(_measuredVoices, voices)) {
        _measuredVoices = null;
        _envelope = null;
      }
      // The sounds then play at their own volume: a missing dip is a far
      // smaller loss than an export that fails over it.
      Log.warning(
        'Could not measure the voice-over for ducking, so nothing ducks: $e',
        name: 'VideoEditorAudioDucking',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
