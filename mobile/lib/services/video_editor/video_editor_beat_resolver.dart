// ABOUTME: Finds where the beats of a video's music land on the exported
// ABOUTME: video, so effects can fire on them in the preview and the export.

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:models/models.dart' show AudioEvent, AudioSourceKind;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/beat_detection.dart';
import 'package:openvine/utils/wav_decoding.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// A stretch of a sound or clip whose beats land on the exported video.
class BeatSourcePart extends Equatable {
  const BeatSourcePart({
    required this.media,
    required this.from,
    required this.to,
    required this.at,
    this.fileLength,
    this.speed = 1,
    this.speedRamp,
    this.rampStart = Duration.zero,
    this.rampLength = Duration.zero,
  });

  /// The file the sound comes from.
  final EditorVideo media;

  /// How long [media] is, or `null` when that is not known.
  final Duration? fileLength;

  /// Where in [media] the part starts playing.
  final Duration from;

  /// Where in [media] the part stops playing (exclusive).
  final Duration to;

  /// Where [from] plays on the exported video.
  final Duration at;

  /// How much faster than recorded the part plays.
  final double speed;

  /// A speed that changes while the part plays, instead of [speed]; it runs
  /// along [rampLength] of [media] from [rampStart], the clip's trimmed
  /// window or the stretch a sound's window plays, which the part may be only
  /// a stretch of.
  final VideoSpeedRamp? speedRamp;

  /// Where in [media] [speedRamp] starts.
  final Duration rampStart;

  /// How much of [media] [speedRamp] runs along.
  final Duration rampLength;

  /// How long after [from] the moment [position] of [media] plays.
  Duration playedAfterFrom(Duration position) {
    final ramp = speedRamp;
    if (ramp == null) {
      return Duration(
        microseconds: ((position - from).inMicroseconds / speed).round(),
      );
    }
    return _rampOutput(ramp, position) - _rampOutput(ramp, from);
  }

  /// Which moment of [media] plays [played] after [from]: the inverse of
  /// [playedAfterFrom].
  Duration positionAfter(Duration played) {
    final ramp = speedRamp;
    if (ramp == null) {
      return from +
          Duration(microseconds: (played.inMicroseconds * speed).round());
    }
    return rampStart +
        ramp.outputToSource(
          _rampOutput(ramp, from) + played,
          sourceDuration: rampLength,
        );
  }

  /// How long the part plays.
  Duration get playedLength => playedAfterFrom(to);

  Duration _rampOutput(VideoSpeedRamp ramp, Duration position) =>
      ramp.sourceToOutput(position - rampStart, sourceDuration: rampLength);

  @override
  List<Object?> get props => [
    media,
    fileLength,
    from,
    to,
    at,
    speed,
    speedRamp,
    rampStart,
    rampLength,
  ];
}

/// The beats of the music in [sounds] and [clips] on an exported video
/// ending at [videoEnd], or none when no effect in [effectEntries] fires on
/// the beat.
///
/// A sound whose beats cannot be read leaves its effects without beats, so
/// they are left out of the export, rather than failing it: the sound itself
/// was fetched for the export already.
Future<List<Duration>> beatsForRender({
  required List<EditorVideoEffect> effectEntries,
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required Duration videoEnd,
}) async {
  if (!effectEntries.any((entry) => entry.onBeat)) return const [];
  final parts = beatSourceFor(sounds: sounds, clips: clips, videoEnd: videoEnd);
  final resolver = VideoEditorBeatResolver();
  try {
    await resolver.read(parts);
    return resolver.beatsOnOutput(parts, videoEnd: videoEnd);
  } on Exception catch (error, stackTrace) {
    Log.error(
      'Could not read the beats for effects on the beat',
      name: 'VideoEditorRenderService',
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    return const [];
  }
}

/// Where the beats of a video ending at [videoEnd] come from: the first music
/// among [sounds], so anything but a voice-over, or else the clips' own sound.
///
/// Empty when nothing plays, for example when every clip is muted and there
/// is no sound.
List<BeatSourcePart> beatSourceFor({
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required Duration videoEnd,
}) {
  final music =
      sounds
          .where((sound) => !sound.isVoiceOver)
          .map((sound) => soundSourcePartFor(sound, videoEnd: videoEnd))
          .nonNulls
          .toList()
        ..sort((a, b) => a.at.compareTo(b.at));
  if (music.isNotEmpty) return [music.first];
  return [for (final sound in clipSoundParts(clips)) sound.part];
}

/// The stretch of [sound] that plays on a video ending at [videoEnd], or
/// `null` when it is silent, has no source or starts after the video ends.
BeatSourcePart? soundSourcePartFor(
  AudioEvent sound, {
  required Duration videoEnd,
}) {
  final source = sound.resolvedSource;
  if (sound.volume <= 0 || source == null || sound.startTime >= videoEnd) {
    return null;
  }
  // A sound without a usable end plays to the end of the video, as it does
  // in the export.
  final soundEnd = sound.endTime;
  final end = soundEnd != null && soundEnd > sound.startTime
      ? (soundEnd < videoEnd ? soundEnd : videoEnd)
      : videoEnd;
  var to = sound.startOffset + sound.sourceOffsetAt(end - sound.startTime);
  final seconds = sound.duration;
  final fileLength = seconds == null
      ? null
      : Duration(microseconds: (seconds * 1e6).round());
  if (fileLength != null && fileLength < to) to = fileLength;
  return BeatSourcePart(
    media: switch (source.kind) {
      AudioSourceKind.asset => EditorVideo.asset(source.path),
      AudioSourceKind.file => EditorVideo.file(File(source.path)),
      AudioSourceKind.network => EditorVideo.network(source.path),
    },
    fileLength: fileLength,
    from: sound.startOffset,
    to: to,
    at: sound.startTime,
    speed: sound.playbackSpeed,
    speedRamp: sound.speedRamp,
    rampStart: sound.startOffset,
    rampLength: sound.playedSourceSpan ?? to - sound.startOffset,
  );
}

/// A stretch of a clip's own sound on the exported video: the [clip] it comes
/// from, where it plays ([part]), and the overlap transitions it is blended
/// in and out through, each `null` for none.
typedef ClipSoundPart = ({
  DivineVideoClip clip,
  BeatSourcePart part,
  ClipTransition? blendIn,
  ClipTransition? blendOut,
});

/// The stretches of the clips' own sound that play on the exported video,
/// leaving out muted clips and freeze frames.
///
/// Across an overlap transition the export blends the two clips: the one
/// going out falls from its volume to silence along the transition's curve,
/// over the part's last [ClipTransition.duration], while the one coming in
/// rises over its first. A muted clip leaves the other to fade against
/// silence, as pro_video_editor does since 2.32.0. The loop-restart blend at
/// the end of the video does the same with the head of the first clip, moved
/// there.
List<ClipSoundPart> clipSoundParts(List<DivineVideoClip> clips) {
  if (clips.isEmpty) return const [];
  final transitions = clampTransitions(clips);
  ClipTransition? overlapAfter(DivineVideoClip clip) {
    final transition = transitions[clip.id];
    return transition == null || transition.type.isDip ? null : transition;
  }

  final wrap = overlapAfter(clips.last);
  final wrapLength = wrap?.duration ?? Duration.zero;
  final outputDuration = TransitionTimelineMap.fromClips(clips).outputDuration;
  final parts = <ClipSoundPart>[];
  // Where the clip starts on the video, before its head moves into the
  // loop-restart blend.
  var clipStart = -wrapLength;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final video = clip.video;
    if (video != null && clip.volume > 0 && !clip.isFreezeFrame) {
      final speed = clip.playbackSpeed ?? 1;
      ClipSoundPart part({
        required Duration from,
        required Duration to,
        required Duration at,
        ClipTransition? blendIn,
        ClipTransition? blendOut,
      }) => (
        clip: clip,
        part: BeatSourcePart(
          media: video,
          fileLength: clip.duration,
          from: from,
          to: to,
          at: at,
          speed: speed,
          speedRamp: clip.speedRamp,
          rampStart: clip.trimStart,
          rampLength: clip.trimmedDuration,
          // Reverse is baked into clip.video; its samples are already in
          // playback order, including the rewritten trims.
        ),
        blendIn: blendIn,
        blendOut: blendOut,
      );

      var from = clip.trimStart;
      var at = clipStart;
      if (i == 0 && wrap != null) {
        // The first head is the incoming side of the loop-restart blend.
        final head = clip.headSourceSpan(wrapLength);
        parts.add(
          part(
            from: from,
            to: from + head,
            at: outputDuration - wrapLength,
            blendIn: wrap,
          ),
        );
        from += head;
        at += wrapLength;
      }
      parts.add(
        part(
          from: from,
          to: clip.trimStart + clip.trimmedDuration,
          at: at,
          blendIn: i == 0 ? null : overlapAfter(clips[i - 1]),
          blendOut: i == clips.length - 1 ? wrap : overlapAfter(clip),
        ),
      );
    }
    clipStart += clip.playbackDuration;
    if (i < clips.length - 1) {
      clipStart -= overlapAfter(clip)?.duration ?? Duration.zero;
    }
  }
  return parts;
}

/// Reads the beats of sounds and places them on the exported video.
///
/// Remembers the beats of every stretch it has read, so the preview finds
/// them again without reading the file twice.
class VideoEditorBeatResolver {
  VideoEditorBeatResolver({
    Future<Uint8List> Function(AudioExtractConfigs configs)? extractAudio,
  }) : _extractAudio =
           extractAudio ??
           ((configs) => ProVideoEditor.instance.extractAudio(configs));

  /// How much of a sound around the part that plays is read with it, on each
  /// side, so a hit at either end is weighed against the sound around it as
  /// in the file.
  static const context = Duration(seconds: 1);

  final Future<Uint8List> Function(AudioExtractConfigs configs) _extractAudio;
  final Map<BeatSourcePart, List<Duration>> _beatsByPart = {};
  final Map<BeatSourcePart, Future<List<Duration>>> _readsInFlight = {};

  /// Whether the beats of every part in [parts] have been read.
  bool hasRead(List<BeatSourcePart> parts) =>
      parts.every(_beatsByPart.containsKey);

  /// Reads the beats of every part in [parts] that has not been read yet.
  ///
  /// A part without sound, such as a clip recorded without a microphone, adds
  /// no beats. Throws when no part could be read at all.
  Future<void> read(List<BeatSourcePart> parts) async {
    PlatformException? failure;
    var anyRead = false;
    for (final part in parts) {
      if (_beatsByPart.containsKey(part)) {
        anyRead = true;
        continue;
      }
      final pending = _readsInFlight.putIfAbsent(part, () => _readBeats(part));
      try {
        _beatsByPart[part] = await pending;
        anyRead = true;
      } on AudioNoTrackException {
        // An absent audio track is a successful empty result, not a
        // transient read failure. Remember it even for an all-silent source.
        anyRead = true;
        _beatsByPart[part] = const [];
      } on PlatformException catch (error) {
        failure = error;
        _beatsByPart[part] = const [];
      } finally {
        if (identical(_readsInFlight[part], pending)) {
          // Removal only relinquishes the cache's reference. This future was
          // already awaited above, including its error handling.
          unawaited(_readsInFlight.remove(part));
        }
      }
    }
    if (!anyRead && failure != null) {
      // Not remembered, so a later read can try again.
      parts.forEach(_beatsByPart.remove);
      throw failure;
    }
  }

  /// The beats of [parts] on the exported video ending at [videoEnd], in order.
  ///
  /// A part whose beats have not been [read] adds none.
  List<Duration> beatsOnOutput(
    List<BeatSourcePart> parts, {
    required Duration videoEnd,
  }) {
    final beats = <Duration>[];
    for (final part in parts) {
      for (final beat in _beatsByPart[part] ?? const <Duration>[]) {
        if (beat < part.from || beat >= part.to) continue;
        final at = part.at + part.playedAfterFrom(beat);
        if (at >= Duration.zero && at < videoEnd) beats.add(at);
      }
    }
    return beats..sort();
  }

  /// The beats of [part]'s file, as times in the file, read from a little
  /// around the stretch that plays, but never past the end of the file: the
  /// platforms do not stop there on their own.
  Future<List<Duration>> _readBeats(BeatSourcePart part) async {
    final start = part.from > context ? part.from - context : Duration.zero;
    final fileLength = part.fileLength;
    final end = part.to + context;
    final wav = await _extractAudio(
      AudioExtractConfigs(
        // The plugin stores a temporary copy of an asset or network source
        // on the object it is given; a copy keeps the cache key unchanged.
        video: part.media.copyWith(),
        format: AudioFormat.wav,
        startTime: start,
        endTime: fileLength == null
            ? null
            : (end < fileLength ? end : fileLength),
      ),
    );
    final beats = await compute(_detectBeatsInWav, wav);
    return [for (final beat in beats) start + beat];
  }
}

/// The beats in [wav], a WAV file, or none when it cannot be read.
List<Duration> _detectBeatsInWav(Uint8List wav) {
  final audio = decodeWavMono(wav);
  if (audio == null) return const [];
  return detectBeats(audio.samples, sampleRate: audio.sampleRate);
}
