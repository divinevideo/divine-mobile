// ABOUTME: Optionally enriches device-local saved sounds with compact waveform data.
// ABOUTME: Decoder and metadata failures are normal and never fail a library save.

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

abstract interface class SavedSoundMediaProbe {
  Future<SavedSoundMediaResult?> probe(AudioEvent sound);
}

@immutable
class SavedSoundMediaResult {
  const SavedSoundMediaResult({
    required this.waveformSamples,
    this.durationSeconds,
  });

  final double? durationSeconds;
  final List<double> waveformSamples;
}

typedef SavedSoundWaveformReader = Future<WaveformData> Function(
  WaveformConfigs configs,
);
typedef SavedSoundMetadataReader = Future<VideoMetadata> Function(
  EditorVideo source,
);

class ProVideoEditorSavedSoundMediaProbe implements SavedSoundMediaProbe {
  ProVideoEditorSavedSoundMediaProbe({
    SavedSoundWaveformReader? getWaveform,
    SavedSoundMetadataReader? getMetadata,
  }) : _getWaveform =
           getWaveform ??
           ((configs) => ProVideoEditor.instance.getWaveform(configs)),
       _getMetadata =
           getMetadata ??
           ((source) => ProVideoEditor.instance.getMetadata(source));

  static const maxSamples = 96;

  final SavedSoundWaveformReader _getWaveform;
  final SavedSoundMetadataReader _getMetadata;

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async {
    final source = _editorVideo(sound);
    if (source == null) return null;

    try {
      final waveform = await _getWaveform(WaveformConfigs(video: source));
      final durationSeconds = _positiveSeconds(waveform.duration);
      return SavedSoundMediaResult(
        durationSeconds: durationSeconds,
        waveformSamples: compactSavedSoundWaveform(
          waveform.leftChannel,
          waveform.rightChannel,
        ),
      );
    } catch (_) {
      if ((sound.duration ?? 0) > 0) return null;
    }

    try {
      final metadata = await _getMetadata(source);
      final durationSeconds = _positiveSeconds(metadata.duration);
      if (durationSeconds == null) return null;
      return SavedSoundMediaResult(
        durationSeconds: durationSeconds,
        waveformSamples: const [],
      );
    } catch (_) {
      return null;
    }
  }

  EditorVideo? _editorVideo(AudioEvent sound) {
    final resolved = sound.resolvedSource;
    if (resolved == null) return null;
    return switch (resolved.kind) {
      AudioSourceKind.asset => EditorVideo.asset(resolved.path),
      AudioSourceKind.file => EditorVideo.file(resolved.path),
      AudioSourceKind.network => EditorVideo.network(resolved.path),
    };
  }

  double? _positiveSeconds(Duration duration) {
    final seconds = duration.inMilliseconds / 1000;
    return seconds > 0 ? seconds : null;
  }
}

@visibleForTesting
List<double> compactSavedSoundWaveform(
  List<double> left,
  List<double>? right,
) {
  if (left.isEmpty) return const [];

  final mono = List<double>.generate(left.length, (index) {
    final leftAmplitude = left[index].abs();
    if (right == null || index >= right.length) return leftAmplitude;
    return (leftAmplitude + right[index].abs()) / 2;
  }, growable: false);

  final bucketCount = math.min(
    ProVideoEditorSavedSoundMediaProbe.maxSamples,
    mono.length,
  );
  return List<double>.generate(bucketCount, (bucket) {
    final start = bucket * mono.length ~/ bucketCount;
    final end = (bucket + 1) * mono.length ~/ bucketCount;
    var peak = 0.0;
    for (var index = start; index < end; index++) {
      peak = math.max(peak, mono[index]);
    }
    return peak;
  }, growable: false);
}
