// ABOUTME: Measures how loud everything that plays in a video is, band by
// ABOUTME: band over time, for an audio visualizer in the preview and export.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/wav_decoding.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// A stretch of sound on the exported video and how loud it plays there.
class AudioLevelPart extends Equatable {
  const AudioLevelPart({
    required this.source,
    this.volume = 1,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });

  /// Where the sound comes from and where it plays.
  final BeatSourcePart source;

  /// How loud the stretch plays, 1 as recorded.
  final double volume;

  /// How long the stretch takes to fade in from silence at its start.
  final Duration fadeIn;

  /// How long the stretch takes to fade out to silence at its end.
  final Duration fadeOut;

  @override
  List<Object?> get props => [source, volume, fadeIn, fadeOut];
}

/// Everything that plays on a video ending at [videoEnd]: every sound among
/// [sounds], voice-overs included, and the clips' own sound, each as loud as
/// it plays in the export.
List<AudioLevelPart> audioLevelSourcesFor({
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required Duration videoEnd,
}) {
  return [
    for (final sound in sounds)
      if (soundSourcePartFor(sound, videoEnd: videoEnd) case final part?)
        AudioLevelPart(
          source: part,
          volume: sound.volume,
          fadeIn: sound.fadeInDuration,
          fadeOut: sound.fadeOutDuration,
        ),
    for (final (:clip, :part) in clipSoundSourcePartsWithClips(clips))
      if (part.at < videoEnd) AudioLevelPart(source: part, volume: clip.volume),
  ];
}

/// [parts] with every sound that streams from the network read from the local
/// copy [localPathFor] returns for its URL instead.
///
/// An export downloads its sounds once, with the stall timeout and retries of
/// its audio fetcher, and reads the visualizer's sound from the same files it
/// muxes.
Future<List<AudioLevelPart>> withLocalNetworkSounds(
  List<AudioLevelPart> parts, {
  required Future<String> Function(String url) localPathFor,
}) async => [
  for (final part in parts)
    if (part.source.media.networkUrl case final url?)
      AudioLevelPart(
        source: BeatSourcePart(
          media: EditorVideo.file(File(await localPathFor(url))),
          fileLength: part.source.fileLength,
          from: part.source.from,
          to: part.source.to,
          at: part.source.at,
          speed: part.source.speed,
        ),
        volume: part.volume,
        fadeIn: part.fadeIn,
        fadeOut: part.fadeOut,
      )
    else
      part,
];

/// Reads how loud sounds are in each frequency band and adds them up on the
/// exported video.
///
/// Remembers what it has read of every stretch of a file, so the preview
/// finds it again without reading the file twice, however the stretch is
/// moved, sped up or turned up.
class VideoEditorAudioLevelResolver {
  VideoEditorAudioLevelResolver({
    Future<Uint8List> Function(AudioExtractConfigs configs)? extractAudio,
  }) : _extractAudio =
           extractAudio ??
           ((configs) => ProVideoEditor.instance.extractAudio(configs));

  /// How much of a file around the stretch that plays is read with it, on
  /// each side, so the first and last rows look at the sound around them as
  /// the analysis window does elsewhere.
  static const context = Duration(milliseconds: 50);

  final Future<Uint8List> Function(AudioExtractConfigs configs) _extractAudio;
  final Map<_Stretch, _StretchEnergies> _energies = {};
  final Map<_Stretch, Future<_StretchEnergies>> _readsInFlight = {};

  /// Whether every part of [parts] has been read.
  bool hasRead(List<AudioLevelPart> parts) =>
      parts.every((part) => _energies.containsKey(_Stretch.of(part.source)));

  /// Reads every part of [parts] that has not been read yet.
  ///
  /// A part without sound, such as a clip recorded without a microphone,
  /// adds nothing, and so does a part that fails to read while another one
  /// is read. Throws when no part could be read at all.
  Future<void> read(List<AudioLevelPart> parts) async {
    Exception? failure;
    var anyRead = false;
    for (final part in parts) {
      final stretch = _Stretch.of(part.source);
      if (_energies.containsKey(stretch)) {
        anyRead = true;
        continue;
      }
      final pending = _readsInFlight.putIfAbsent(
        stretch,
        () => _readEnergies(part.source),
      );
      try {
        _energies[stretch] = await pending;
        anyRead = true;
      } on AudioNoTrackException {
        // An absent audio track is a successful silent result, not a
        // transient read failure.
        anyRead = true;
        _energies[stretch] = _StretchEnergies.silent;
      } on Exception catch (error) {
        // A platform error, or a network sound the plugin could not fetch.
        failure = error;
        _energies[stretch] = _StretchEnergies.silent;
      } finally {
        if (identical(_readsInFlight[stretch], pending)) {
          // Removal only relinquishes the cache's reference. This future was
          // already awaited above, including its error handling.
          unawaited(_readsInFlight.remove(stretch));
        }
      }
    }
    if (!anyRead && failure != null) {
      // Not remembered, so a later read can try again.
      for (final part in parts) {
        _energies.remove(_Stretch.of(part.source));
      }
      throw failure;
    }
  }

  /// The band energies of everything in [parts] added up on the exported
  /// video ending at [videoEnd], [audioBandFrameRate] rows a second from its
  /// start, [audioBandCount] bands a row; see [bandEnergies].
  ///
  /// A part that has not been [read] adds nothing.
  Float32List energiesOnOutput(
    List<AudioLevelPart> parts, {
    required Duration videoEnd,
  }) {
    final rows = math.max(
      0,
      (videoEnd.inMicroseconds * audioBandFrameRate / 1e6).ceil(),
    );
    final mix = Float32List(rows * audioBandCount);
    for (final part in parts) {
      final energies = _energies[_Stretch.of(part.source)];
      if (energies == null || energies.rows == 0) continue;
      _addPart(mix, rows, part, energies);
    }
    return mix;
  }

  void _addPart(
    Float32List mix,
    int rows,
    AudioLevelPart part,
    _StretchEnergies energies,
  ) {
    final source = part.source;
    final start = source.at.inMicroseconds / 1e6;
    final length =
        (source.to - source.from).inMicroseconds / 1e6 / source.speed;
    final end = start + length;
    final fadeIn = part.fadeIn.inMicroseconds / 1e6;
    final fadeOut = part.fadeOut.inMicroseconds / 1e6;
    final firstRow = math.max(0, (start * audioBandFrameRate).ceil());
    final lastRow = math.min(rows, (end * audioBandFrameRate).ceil());
    for (var row = firstRow; row < lastRow; row++) {
      final time = row / audioBandFrameRate;
      if (time < start || time >= end) continue;
      var gain = part.volume;
      if (fadeIn > 0 && time - start < fadeIn) {
        gain *= (time - start) / fadeIn;
      }
      if (fadeOut > 0 && end - time < fadeOut) {
        gain *= (end - time) / fadeOut;
      }
      if (gain <= 0) continue;
      // Where this moment of the video plays in the file, as a row of what
      // was read of it.
      final fileSeconds =
          source.from.inMicroseconds / 1e6 + (time - start) * source.speed;
      final position =
          (fileSeconds - energies.start.inMicroseconds / 1e6) *
          audioBandFrameRate;
      final low = position.floor().clamp(0, energies.rows - 1);
      final high = math.min(low + 1, energies.rows - 1);
      final mixOfHigh = (position - low).clamp(0.0, 1.0);
      final power = gain * gain;
      for (var band = 0; band < audioBandCount; band++) {
        final a = energies.values[low * audioBandCount + band];
        final b = energies.values[high * audioBandCount + band];
        mix[row * audioBandCount + band] += power * (a + (b - a) * mixOfHigh);
      }
    }
  }

  /// The band energies of [source]'s file around the stretch that plays,
  /// never past the end of the file: the platforms do not stop there on
  /// their own.
  Future<_StretchEnergies> _readEnergies(BeatSourcePart source) async {
    final start = source.from > context ? source.from - context : Duration.zero;
    final fileLength = source.fileLength;
    final end = source.to + context;
    final wav = await _extractAudio(
      AudioExtractConfigs(
        // The plugin stores a temporary copy of an asset or network source
        // on the object it is given; a copy keeps the cache key unchanged.
        video: source.media.copyWith(),
        format: AudioFormat.wav,
        startTime: start,
        endTime: fileLength == null
            ? null
            : (end < fileLength ? end : fileLength),
      ),
    );
    return _StretchEnergies(start, await compute(_energiesInWav, wav));
  }
}

/// The band energies of [wav], a WAV file, or none when it cannot be read.
Float32List _energiesInWav(Uint8List wav) {
  final audio = decodeWavMono(wav);
  if (audio == null) return Float32List(0);
  return bandEnergies(audio.samples, sampleRate: audio.sampleRate);
}

/// The stretch of a file a part reads; where and how fast it plays does not
/// change what is in it.
class _Stretch extends Equatable {
  const _Stretch(this.media, this.fileLength, this.from, this.to);

  factory _Stretch.of(BeatSourcePart source) =>
      _Stretch(source.media, source.fileLength, source.from, source.to);

  final EditorVideo media;
  final Duration? fileLength;
  final Duration from;
  final Duration to;

  @override
  List<Object?> get props => [media, fileLength, from, to];
}

/// The band energies read from a stretch of a file, from [start] in the file
/// on, [audioBandFrameRate] rows a second.
class _StretchEnergies {
  const _StretchEnergies(this.start, this.values);

  static final silent = _StretchEnergies(Duration.zero, Float32List(0));

  final Duration start;
  final Float32List values;

  int get rows => values.length ~/ audioBandCount;
}
