// ABOUTME: Finds where the beats of a video's music land on the exported
// ABOUTME: video, so effects can fire on them in the preview and the export.

import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:models/models.dart' show AudioEvent, AudioSourceKind;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/beat_detection.dart';
import 'package:openvine/utils/wav_decoding.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A stretch of a sound or clip whose beats land on the exported video.
class BeatSourcePart extends Equatable {
  const BeatSourcePart({
    required this.media,
    required this.from,
    required this.to,
    required this.at,
    this.fileLength,
    this.speed = 1,
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

  @override
  List<Object?> get props => [
    media,
    fileLength,
    from,
    to,
    at,
    speed,
  ];
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
          .where(
            (sound) =>
                sound.volume > 0 &&
                !sound.isVoiceOver &&
                sound.resolvedSource != null &&
                sound.startTime < videoEnd,
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
  if (music.isNotEmpty) {
    final sound = music.first;
    final source = sound.resolvedSource!;
    // A sound without a usable end plays to the end of the video, as it does
    // in the export.
    final soundEnd = sound.endTime;
    final end = soundEnd != null && soundEnd > sound.startTime
        ? (soundEnd < videoEnd ? soundEnd : videoEnd)
        : videoEnd;
    var to = sound.startOffset + (end - sound.startTime);
    final seconds = sound.duration;
    final fileLength = seconds == null
        ? null
        : Duration(microseconds: (seconds * 1e6).round());
    if (fileLength != null && fileLength < to) to = fileLength;
    return [
      BeatSourcePart(
        media: switch (source.kind) {
          AudioSourceKind.asset => EditorVideo.asset(source.path),
          AudioSourceKind.file => EditorVideo.file(File(source.path)),
          AudioSourceKind.network => EditorVideo.network(source.path),
        },
        fileLength: fileLength,
        from: sound.startOffset,
        to: to,
        at: sound.startTime,
      ),
    ];
  }

  final parts = <BeatSourcePart>[];
  final transitions = clampTransitions(clips);
  Duration overlapAfter(DivineVideoClip clip) {
    final transition = transitions[clip.id];
    if (transition == null ||
        transition.type == ClipTransitionType.fadeToBlack ||
        transition.type == ClipTransitionType.fadeToWhite) {
      return Duration.zero;
    }
    return transition.duration;
  }

  final wrap = clips.isEmpty ? Duration.zero : overlapAfter(clips.last);
  // The export gives the loop-restart blend sound only when the clips on both
  // sides of it have some: next to a muted last clip, the first head moved
  // into the blend plays in silence.
  final headSounds = clips.isNotEmpty && clips.last.volume > 0;
  final outputDuration = TransitionTimelineMap.fromClips(clips).outputDuration;
  var clipStart = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final video = clip.video;
    if (video != null && clip.volume > 0 && !clip.isFreezeFrame) {
      final speed = clip.playbackSpeed ?? 1;
      final headPlayback = i == 0
          ? wrap
          : clips[i - 1].volume <= 0
          ? overlapAfter(clips[i - 1])
          : Duration.zero;
      final head = Duration(
        microseconds: (headPlayback.inMicroseconds * speed).round(),
      );
      final tailPlayback = i == clips.length - 1
          ? (clips.first.volume <= 0 ? wrap : Duration.zero)
          : clips[i + 1].volume <= 0
          ? overlapAfter(clip)
          : Duration.zero;
      final tail = Duration(
        microseconds: (tailPlayback.inMicroseconds * speed).round(),
      );
      if (i == 0 && head > Duration.zero && headSounds) {
        // The first head is the incoming side of the final wrap blend.
        parts.add(
          BeatSourcePart(
            media: video,
            fileLength: clip.duration,
            from: clip.trimStart,
            to: clip.trimStart + head,
            at: outputDuration - wrap,
            speed: speed,
          ),
        );
      }
      parts.add(
        BeatSourcePart(
          media: video,
          fileLength: clip.duration,
          from: clip.trimStart + head,
          // Like the loop seam, an internal overlap has no clip audio if
          // either side is muted. Do not trigger on its silent source range.
          to: clip.trimStart + clip.trimmedDuration - tail,
          at: clipStart - wrap + headPlayback,
          speed: speed,
          // Reverse is baked into clip.video; its samples are already in
          // playback order, including the rewritten trims.
        ),
      );
    }
    clipStart += clip.playbackDuration;
    if (i < clips.length - 1) clipStart -= overlapAfter(clip);
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
    Exception? failure;
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
      } on AudioNoTrackException catch (error) {
        failure = error;
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
        final played = beat - part.from;
        final at =
            part.at +
            Duration(
              microseconds: (played.inMicroseconds / part.speed).round(),
            );
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
