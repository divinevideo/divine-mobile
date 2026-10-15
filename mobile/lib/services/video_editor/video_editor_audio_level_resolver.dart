// ABOUTME: Measures how loud everything that plays in a video is, band by
// ABOUTME: band over time, for an audio visualizer in the preview and export.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show AudioEvent, EqualizerSettings;
import 'package:openvine/extensions/animation_curve_easing.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/audio_fade.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/services/video_editor/detached_clip_composite.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/video_editor_beat_resolver.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/equalizer_response.dart';
import 'package:openvine/utils/wav_decoding.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show EditorAudio, ExportedLayer, Layer;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// A stretch of sound on the exported video and how loud it plays there.
class AudioLevelPart extends Equatable {
  const AudioLevelPart({
    required this.source,
    this.volume = 1,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.equalizer = EqualizerSettings.none,
    this.blendIn,
    this.blendOut,
  });

  /// Where the sound comes from and where it plays.
  final BeatSourcePart source;

  /// How loud the stretch plays, 1 as recorded.
  final double volume;

  /// How long the stretch takes to fade in from silence at its start.
  final Duration fadeIn;

  /// How long the stretch takes to fade out to silence at its end.
  final Duration fadeOut;

  /// The equalizer the stretch plays through.
  final EqualizerSettings equalizer;

  /// The overlap transition the stretch is blended in through, or `null` for
  /// none: over the transition's first [ClipTransition.duration] it rises
  /// from silence along the transition's curve.
  final ClipTransition? blendIn;

  /// The overlap transition the stretch is blended out through, or `null` for
  /// none: over its last [ClipTransition.duration] it falls to silence along
  /// the transition's curve.
  final ClipTransition? blendOut;

  /// This stretch, played from [source] instead.
  AudioLevelPart withSource(BeatSourcePart source) => AudioLevelPart(
    source: source,
    volume: volume,
    fadeIn: fadeIn,
    fadeOut: fadeOut,
    equalizer: equalizer,
    blendIn: blendIn,
    blendOut: blendOut,
  );

  @override
  List<Object?> get props => [
    source,
    volume,
    fadeIn,
    fadeOut,
    equalizer,
    blendIn,
    blendOut,
  ];
}

/// A clip detached onto a layer of its own, which plays its sound over the
/// timeline while the layer is on screen.
class DetachedClipSound {
  const DetachedClipSound({
    required this.clip,
    this.sourceOffset = Duration.zero,
    this.startTime,
    this.endTime,
  });

  /// The detached clips among [layers], whose clip files are resolved against
  /// [documentsPath], as [DetachedClipLayerData.fromMeta] does.
  static List<DetachedClipSound> inLayers(
    Iterable<Layer> layers, {
    required String documentsPath,
  }) => [
    for (final layer in layers)
      if (DetachedClipLayerData.fromMeta(
            DetachedClipLayerData.metaOf(layer),
            documentsPath,
          )
          case final data?)
        DetachedClipSound(
          clip: data.clip,
          sourceOffset: data.sourceOffset,
          startTime: layer.startTime,
          endTime: layer.endTime,
        ),
  ];

  /// The clip, with its trim, speed, volume and equalizer.
  final DivineVideoClip clip;

  /// Where the layer starts inside the clip, in playback time.
  final Duration sourceOffset;

  /// Where the layer starts on the editor's timeline, or `null` for its start.
  final Duration? startTime;

  /// Where the layer ends on the editor's timeline, or `null` when it plays
  /// the clip to its end.
  final Duration? endTime;
}

/// Everything that plays on a video ending at [videoEnd]: every sound among
/// [sounds], voice-overs included, the clips' own sound and that of the
/// [detachedClips], each as loud as it plays in the export.
List<AudioLevelPart> audioLevelSourcesFor({
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required Duration videoEnd,
  List<DetachedClipSound> detachedClips = const [],
}) {
  final timelineMap = TransitionTimelineMap.fromClips(clips);
  return [
    for (final sound in sounds)
      if (soundSourcePartFor(sound, videoEnd: videoEnd) case final part?)
        AudioLevelPart(
          source: part,
          volume: sound.volume,
          fadeIn: sound.fadeInDuration,
          fadeOut: sound.fadeOutDuration,
          equalizer: sound.equalizer,
        ),
    for (final part in _clipParts(clips, timelineMap))
      if (part.source.at < videoEnd) part,
    for (final detached in detachedClips)
      if (_detachedClipPart(detached, timelineMap) case final part?
          when part.source.at < videoEnd)
        part,
  ];
}

/// The clips' own sound on the exported video.
///
/// Across an overlap transition the export blends the two clips: the one
/// going out falls from its volume to silence along the transition's curve
/// while the one coming in rises, and a muted clip leaves the other to fade
/// against silence. The loop-restart blend at the end of the video does the
/// same with the head of the first clip, moved there. Freeze frames play no
/// sound of their own.
List<AudioLevelPart> _clipParts(
  List<DivineVideoClip> clips,
  TransitionTimelineMap timelineMap,
) {
  if (clips.isEmpty) return const [];
  final transitions = clampTransitions(clips);
  ClipTransition? overlapAfter(DivineVideoClip clip) {
    final transition = transitions[clip.id];
    return transition == null ||
            transition.type == ClipTransitionType.fadeToBlack ||
            transition.type == ClipTransitionType.fadeToWhite
        ? null
        : transition;
  }

  final wrap = overlapAfter(clips.last);
  final wrapLength = wrap?.duration ?? Duration.zero;
  final parts = <AudioLevelPart>[];
  // Where the clip starts on the video, before its head moves into the
  // loop-restart blend.
  var clipStart = -wrapLength;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final video = clip.video;
    if (video != null && clip.volume > 0 && !clip.isFreezeFrame) {
      final speed = clip.playbackSpeed ?? 1;
      AudioLevelPart part({
        required Duration from,
        required Duration to,
        required Duration at,
        ClipTransition? blendIn,
        ClipTransition? blendOut,
      }) => AudioLevelPart(
        source: BeatSourcePart(
          media: video,
          fileLength: clip.duration,
          from: from,
          to: to,
          at: at,
          speed: speed,
          // Reverse is baked into clip.video; its samples are already in
          // playback order, including the rewritten trims.
        ),
        volume: clip.volume,
        equalizer: clip.equalizer,
        blendIn: blendIn,
        blendOut: blendOut,
      );

      var from = clip.trimStart;
      var at = clipStart;
      if (i == 0 && wrap != null) {
        // The first head is the incoming side of the loop-restart blend.
        final head = Duration(
          microseconds: (wrapLength.inMicroseconds * speed).round(),
        );
        parts.add(
          part(
            from: from,
            to: from + head,
            at: timelineMap.outputDuration - wrapLength,
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

/// The sound of [detached] on the exported video, as the export composites
/// it over the timeline, or `null` when it plays none.
AudioLevelPart? _detachedClipPart(
  DetachedClipSound detached,
  TransitionTimelineMap timelineMap,
) {
  final clip = detached.clip;
  final video = clip.video;
  if (video == null || clip.volume <= 0 || clip.isFreezeFrame) return null;
  final (:start, :trimStart, :span) = detachedClipWindow(
    clip: clip,
    sourceOffset: detached.sourceOffset,
    layerStart: detached.startTime,
    layerEnd: detached.endTime,
    timelineMap: timelineMap,
    speedFlattened: false,
  );
  if (span <= Duration.zero) return null;
  return AudioLevelPart(
    source: BeatSourcePart(
      media: video,
      fileLength: clip.duration,
      from: trimStart,
      to: trimStart + span,
      at: start ?? Duration.zero,
      speed: clip.playbackSpeed ?? 1,
    ),
    volume: clip.volume,
    equalizer: clip.equalizer,
  );
}

/// [parts] with every sound that streams from the network read from the local
/// copy [localPathFor] returns for its URL instead.
///
/// An export downloads its sounds once, with the stall timeout and retries of
/// its audio fetcher, and reads the visualizer's sound from the same files it
/// muxes. A sound whose download fails is left out, so the others still
/// move the visualizer; [onDownloadFailed] hears of it.
Future<List<AudioLevelPart>> withLocalNetworkSounds(
  List<AudioLevelPart> parts, {
  required Future<String> Function(String url) localPathFor,
  void Function(Object error, StackTrace stackTrace)? onDownloadFailed,
}) async {
  final local = <AudioLevelPart>[];
  for (final part in parts) {
    final url = part.source.media.networkUrl;
    if (url == null) {
      local.add(part);
      continue;
    }
    final String path;
    try {
      path = await localPathFor(url);
    } on Exception catch (error, stackTrace) {
      onDownloadFailed?.call(error, stackTrace);
      continue;
    }
    local.add(
      part.withSource(
        BeatSourcePart(
          media: EditorVideo.file(File(path)),
          fileLength: part.source.fileLength,
          from: part.source.from,
          to: part.source.to,
          at: part.source.at,
          speed: part.source.speed,
        ),
      ),
    );
  }
  return local;
}

/// The band energies of everything among [sounds], [clips] and
/// [detachedClips] that plays on an exported video ending at [videoEnd], or
/// `null` when none could be read; see
/// [VideoEditorAudioLevelResolver.energiesOnOutput].
///
/// A network sound is read from the local copy [localPathFor] returns, see
/// [withLocalNetworkSounds]. A sound that cannot be downloaded or read is
/// left out rather than failing the export, as a missing beat is for effects
/// on the beat; the mux tries the download again and fails the export if the
/// sound is still out of reach.
Future<Float32List?> audioEnergiesOnExport({
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required Duration videoEnd,
  required Future<String> Function(String url) localPathFor,
  List<DetachedClipSound> detachedClips = const [],
  VideoEditorAudioLevelResolver? resolver,
}) async {
  void logFailure(Object error, StackTrace stackTrace) => Log.error(
    'Could not read the sound for the audio visualizer',
    name: 'VideoEditorAudioLevelResolver',
    category: LogCategory.video,
    error: error,
    stackTrace: stackTrace,
  );
  final reader = resolver ?? VideoEditorAudioLevelResolver();
  final parts = await withLocalNetworkSounds(
    audioLevelSourcesFor(
      sounds: sounds,
      clips: clips,
      videoEnd: videoEnd,
      detachedClips: detachedClips,
    ),
    localPathFor: localPathFor,
    onDownloadFailed: logFailure,
  );
  try {
    await reader.read(parts);
  } on Exception catch (error, stackTrace) {
    logFailure(error, stackTrace);
    return null;
  }
  return reader.energiesOnOutput(parts, videoEnd: videoEnd);
}

/// [audioEnergiesOnExport] for the audio visualizers among [capturedLayers],
/// or `null` when it holds none: the [sounds] and [clips] of a render cut at
/// [maxOutputDuration], and the [detached] clips it composites over them.
/// Downloads go through [audioFetcher], which the mux reuses, into
/// [tempFilePaths].
Future<Float32List?> audioVisualizerEnergiesForRender({
  required List<ExportedLayer> capturedLayers,
  required List<AudioEvent> sounds,
  required List<DivineVideoClip> clips,
  required List<DetachedClipExportLayer> detached,
  required Duration? maxOutputDuration,
  required RenderAudioFetcher audioFetcher,
  required List<String> tempFilePaths,
}) async {
  if (!capturedLayers.any(
    (item) => AudioVisualizerLayerData.isAudioVisualizerLayer(item.layer),
  )) {
    return null;
  }
  final outputDuration = TransitionTimelineMap.fromClips(clips).outputDuration;
  return audioEnergiesOnExport(
    sounds: sounds,
    clips: clips,
    detachedClips: [
      for (final item in detached)
        DetachedClipSound(
          clip: item.clip,
          sourceOffset: item.sourceOffset,
          startTime: item.layer.startTime,
          endTime: item.layer.endTime,
        ),
    ],
    videoEnd: maxOutputDuration != null && maxOutputDuration < outputDuration
        ? maxOutputDuration
        : outputDuration,
    localPathFor: (url) async {
      final path = await audioFetcher.localPathFor(
        EditorAudio.network(url),
        logName: 'VideoEditorRenderService',
      );
      if (!tempFilePaths.contains(path)) tempFilePaths.add(path);
      return path;
    },
  );
}

/// Why sound could not be read for an audio visualizer: [cause] is the
/// failure underneath. [VideoEditorAudioLevelResolver.read] throws it when no
/// part could be read at all.
class AudioLevelReadException implements Exception {
  const AudioLevelReadException(this.cause);

  final Object cause;

  @override
  String toString() => 'AudioLevelReadException: $cause';
}

/// Reads how loud sounds are in each frequency band and adds them up on the
/// exported video.
///
/// Remembers what it has read of every stretch of a file, so the preview
/// finds it again without reading the file twice, however the stretch is
/// moved, sped up or turned up. A read serves every later stretch that starts
/// where it did and ends no later, so moving a sound that runs past the end
/// of the video, which shortens or lengthens the stretch that plays, reads
/// its file again only when the stretch grows past what was read.
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
  final Map<_ReadStart, _StretchEnergies> _energies = {};
  final Map<_Stretch, Future<_StretchEnergies>> _readsInFlight = {};

  /// Whether every part of [parts] has been read.
  bool hasRead(List<AudioLevelPart> parts) =>
      parts.every((part) => _readFor(part.source) != null);

  /// What has been read of [source]'s file, when it covers the stretch.
  _StretchEnergies? _readFor(BeatSourcePart source) {
    final energies = _energies[_ReadStart.of(source)];
    return energies != null && energies.covers(source.to) ? energies : null;
  }

  /// Remembers [energies] read for [source], unless what is remembered
  /// already reaches further, as when a longer read finished first.
  void _remember(BeatSourcePart source, _StretchEnergies energies) {
    final key = _ReadStart.of(source);
    final known = _energies[key];
    if (known == null || !known.coversAll(energies)) _energies[key] = energies;
  }

  /// Reads every part of [parts] that has not been read yet.
  ///
  /// A part without sound, such as a clip recorded without a microphone,
  /// adds nothing, and a part that cannot be read leaves the others to be
  /// read. A failed part is not remembered, so the next read tries it again;
  /// until then it adds nothing. Throws an [AudioLevelReadException] when no
  /// part could be read at all.
  Future<void> read(List<AudioLevelPart> parts) async {
    Exception? failure;
    var anyRead = false;
    for (final part in parts) {
      if (_readFor(part.source) != null) {
        anyRead = true;
        continue;
      }
      final (stretch, pending) = _pendingReadFor(part.source);
      try {
        _remember(part.source, await pending);
        anyRead = true;
      } on AudioNoTrackException {
        // An absent audio track is a successful silent result, not a
        // transient read failure.
        anyRead = true;
        _remember(part.source, _StretchEnergies.silent);
      } on Exception catch (error, stackTrace) {
        // A platform failure, no audio from the platform, or a network sound
        // that could not be fetched. The other parts are still read.
        failure = error;
        Log.warning(
          'Could not read a sound for the audio visualizer',
          name: 'VideoEditorAudioLevelResolver',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        if (identical(_readsInFlight[stretch], pending)) {
          // Removal only relinquishes the cache's reference. This future was
          // already awaited above, including its error handling.
          unawaited(_readsInFlight.remove(stretch));
        }
      }
    }
    if (!anyRead && failure != null) {
      throw failure is AudioLevelReadException
          ? failure
          : AudioLevelReadException(failure);
    }
  }

  /// A read under way that covers [source], or a new one for it, with the
  /// stretch it is filed under.
  (_Stretch, Future<_StretchEnergies>) _pendingReadFor(BeatSourcePart source) {
    for (final MapEntry(key: stretch, value: pending)
        in _readsInFlight.entries) {
      if (stretch.covers(source)) return (stretch, pending);
    }
    final stretch = _Stretch.of(source);
    return (stretch, _readsInFlight[stretch] = _readEnergies(source));
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
      final energies = _readFor(part.source);
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
    final firstRow = math.max(0, (start * audioBandFrameRate).ceil());
    final lastRow = math.min(rows, (end * audioBandFrameRate).ceil());
    final bandGains = equalizerBandPowerGains(part.equalizer);
    for (var row = firstRow; row < lastRow; row++) {
      final time = row / audioBandFrameRate;
      if (time < start || time >= end) continue;
      final gain = part.volume * _envelope(part, time - start, length);
      // A bounce or elastic blend overshoots below silence, which still
      // sounds: its power is the square.
      if (gain == 0) continue;
      // Where this moment of the video plays in the file, as a row of what
      // was read of it.
      final fileSeconds =
          source.from.inMicroseconds / 1e6 + (time - start) * source.speed;
      final position =
          (fileSeconds - energies.start.inMicroseconds / 1e6) *
          audioBandFrameRate;
      // Past the end of what was read, as when a file is shorter than its
      // slot, the part plays nothing.
      if (position >= energies.rows) continue;
      final low = position.floor().clamp(0, energies.rows - 1);
      final high = math.min(low + 1, energies.rows - 1);
      final mixOfHigh = (position - low).clamp(0.0, 1.0);
      final power = gain * gain;
      for (var band = 0; band < audioBandCount; band++) {
        final a = energies.values[low * audioBandCount + band];
        final b = energies.values[high * audioBandCount + band];
        mix[row * audioBandCount + band] +=
            power * (bandGains?[band] ?? 1) * (a + (b - a) * mixOfHigh);
      }
    }
  }

  /// How loud [part] plays [position] seconds into its [length] seconds, as
  /// a share of its volume: faded as the export fades a sound, and blended
  /// in and out across an overlap transition as the export blends a clip.
  static double _envelope(AudioLevelPart part, double position, double length) {
    Duration duration(double seconds) =>
        Duration(microseconds: (seconds * 1e6).round());
    var gain = audioFadeGain(
      position: duration(position),
      length: duration(length),
      fadeIn: part.fadeIn,
      fadeOut: part.fadeOut,
    );
    if (part.blendIn case final blend?) {
      final blendLength = blend.duration.inMicroseconds / 1e6;
      if (position < blendLength) {
        gain *= blend.curve.ease(position / blendLength);
      }
    }
    if (part.blendOut case final blend?) {
      final blendLength = blend.duration.inMicroseconds / 1e6;
      final left = length - position;
      if (left < blendLength) {
        gain *= 1 - blend.curve.ease(1 - left / blendLength);
      }
    }
    return gain;
  }

  /// The band energies of [source]'s file around the stretch that plays,
  /// never past the end of the file: the platforms do not stop there on
  /// their own.
  Future<_StretchEnergies> _readEnergies(BeatSourcePart source) async {
    final start = source.from > context ? source.from - context : Duration.zero;
    final fileLength = source.fileLength;
    final end = source.to + context;
    final toEndOfFile = _Stretch.of(source).readsToEndOfFile;
    final Uint8List wav;
    try {
      wav = await _extractAudio(
        AudioExtractConfigs(
          // The plugin stores a temporary copy of an asset or network source
          // on the object it is given; a copy keeps the cache key unchanged.
          video: source.media.copyWith(),
          format: AudioFormat.wav,
          startTime: start,
          endTime: toEndOfFile ? fileLength : end,
        ),
      );
      // The plugin reports a platform that returned no audio as a plain
      // ArgumentError: an operational failure, not a bug here. A RangeError
      // is one, so it is let through.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (error) {
      if (error is RangeError) rethrow;
      throw AudioLevelReadException(error);
    }
    return _StretchEnergies(
      start,
      await compute(_energiesInWav, wav),
      // A read to the end of the file holds every stretch from its start.
      readTo: toEndOfFile ? null : source.to,
    );
  }
}

/// The band energies of [wav], a WAV file, or none when it cannot be read.
Float32List _energiesInWav(Uint8List wav) {
  final audio = decodeWavMono(wav);
  if (audio == null) return Float32List(0);
  return bandEnergies(audio.samples, sampleRate: audio.sampleRate);
}

/// Where in a file a part starts reading; see
/// [VideoEditorAudioLevelResolver._readFor].
class _ReadStart extends Equatable {
  const _ReadStart(this.media, this.fileLength, this.from);

  factory _ReadStart.of(BeatSourcePart source) =>
      _ReadStart(source.media, source.fileLength, source.from);

  final EditorVideo media;
  final Duration? fileLength;
  final Duration from;

  @override
  List<Object?> get props => [media, fileLength, from];
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

  /// Whether reading this stretch, with the context around it, reaches the
  /// end of the file.
  bool get readsToEndOfFile {
    final length = fileLength;
    return length == null ||
        to + VideoEditorAudioLevelResolver.context >= length;
  }

  /// Whether reading this stretch also reads [source]'s.
  bool covers(BeatSourcePart source) =>
      media == source.media &&
      fileLength == source.fileLength &&
      from == source.from &&
      (readsToEndOfFile || to >= source.to);

  @override
  List<Object?> get props => [media, fileLength, from, to];
}

/// The band energies read from a stretch of a file, from [start] in the file
/// on, [audioBandFrameRate] rows a second, for a stretch ending at [readTo].
class _StretchEnergies {
  const _StretchEnergies(this.start, this.values, {this.readTo});

  /// A file without sound, which is silent however much of it plays.
  static final silent = _StretchEnergies(Duration.zero, Float32List(0));

  final Duration start;
  final Float32List values;

  /// Where in the file the stretch read for ends, or `null` for all of it.
  final Duration? readTo;

  int get rows => values.length ~/ audioBandCount;

  /// Whether this holds a stretch from its start to [to].
  bool covers(Duration to) {
    final end = readTo;
    return end == null || end >= to;
  }

  /// Whether this holds everything [other] does.
  bool coversAll(_StretchEnergies other) {
    final otherEnd = other.readTo;
    return otherEnd == null ? readTo == null : covers(otherEnd);
  }
}
