// ABOUTME: Plans when sounds get quieter under a voice-over, so the editor
// ABOUTME: preview and the export lower them at exactly the same moments.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show AudioEvent;
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
/// the take's loudness ([AudioDucking]). The preview and the export both ask
/// [curvesFor] with the same sounds, so they get the same curves: the preview
/// plays them through the player, the render bakes them into the sound.
///
/// The voice-overs are measured once per change to them and kept, so a sound
/// moved or a volume dragged re-plans its dips without decoding again.
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
            case final curve when curve.points.isNotEmpty)
          sound.id: curve,
    };
  }

  /// [voiceOver] as the render plays it, for measuring when it talks; `null`
  /// when it has no file on this device.
  @visibleForTesting
  static VideoAudioTrack? voiceTrackOf(AudioEvent voiceOver) {
    final path = voiceOver.localFilePath;
    if (path == null) return null;
    // A take without a valid window plays across the whole video, as the
    // render maps it.
    final end = voiceOver.endTime;
    final hasWindow = end != null && end > voiceOver.startTime;
    return VideoAudioTrack(
      path: path,
      startTime: hasWindow ? voiceOver.startTime : null,
      endTime: hasWindow ? end : null,
      audioStartTime: voiceOver.startOffset,
      volume: voiceOver.volume,
      playbackSpeed: voiceOver.playbackSpeed,
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
