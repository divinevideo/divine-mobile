// ABOUTME: Prepares a downloaded sound for the app with ffmpeg: trims edge
// ABOUTME: silence, normalises loudness, rejects silent files, encodes AAC.

import 'dart:convert';
import 'dart:io';

import 'sound_candidate.dart';

/// Runs an executable; [Process.run] outside tests.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// The levels every imported sound is brought to.
class AudioTargets {
  const AudioTargets({
    this.loudnessLufs = -16,
    this.truePeakDb = -1.5,
    this.silenceThresholdDb = -60,
    this.leadingSilence = 0.05,
    this.trailingSilence = 0.2,
    this.musicBitrateKbps = 192,
    this.otherBitrateKbps = 128,
  });

  /// Integrated loudness (EBU R128), the level most phones play speech and
  /// music at.
  final double loudnessLufs;

  /// The gain never lifts a true peak above this.
  final double truePeakDb;

  /// Below this peak level a stretch counts as silence. The app's own rule
  /// (`soundSilenceThresholdDbfs`), which is ffmpeg's `silencedetect`
  /// default.
  final double silenceThresholdDb;

  /// Seconds of the silence before the first sound that are kept.
  final double leadingSilence;

  /// Seconds of the silence after the last sound that are kept, so a tail
  /// that fades out is not cut off.
  final double trailingSilence;

  final int musicBitrateKbps;
  final int otherBitrateKbps;
}

/// The MIME type of what [AudioPipeline] writes: AAC in an MP4 container,
/// which iOS and Android both play.
const preparedMimeType = 'audio/mp4';

/// What [AudioPipeline.prepare] made of a file.
sealed class PrepareOutcome {
  const PrepareOutcome();
}

/// Written to the output file.
class PreparedAudio extends PrepareOutcome {
  const PreparedAudio({
    required this.durationSeconds,
    required this.gainDb,
    required this.changes,
  });

  final double durationSeconds;
  final double gainDb;

  /// What was changed beyond the format, in the words the event's credit
  /// uses, such as `edge silence trimmed`.
  final List<String> changes;
}

/// Not usable; nothing was written.
class RejectedAudio extends PrepareOutcome {
  const RejectedAudio(this.reason);

  final String reason;
}

/// The two numbers a loudness measurement gives.
class LoudnessMeasurement {
  const LoudnessMeasurement({
    required this.integratedLufs,
    required this.truePeakDb,
  });

  /// Null when the clip is too short or too quiet to be gated.
  final double? integratedLufs;
  final double truePeakDb;
}

/// Trims, measures, normalises and encodes sounds with ffmpeg.
class AudioPipeline {
  AudioPipeline({
    this.targets = const AudioTargets(),
    this.ffmpeg = 'ffmpeg',
    this.ffprobe = 'ffprobe',
    ProcessRunner? run,
  }) : _run = run ?? Process.run;

  final AudioTargets targets;
  final String ffmpeg;
  final String ffprobe;
  final ProcessRunner _run;

  /// Prepares [input] as [kind] into [output], tagging the file itself with
  /// [title], [artist] and the credit [comment].
  Future<PrepareOutcome> prepare({
    required File input,
    required File output,
    required SoundKind kind,
    required String title,
    required String artist,
    required String comment,
  }) async {
    final inputDuration = await _duration(input.path);
    if (inputDuration == null || inputDuration <= 0) {
      return const RejectedAudio('unreadable');
    }

    final scratch = await Directory.systemTemp.createTemp('sound_import');
    try {
      final trimmed = File('${scratch.path}/trimmed.wav');
      final trim = await _run(ffmpeg, [
        '-nostdin',
        '-hide_banner',
        '-y',
        '-i',
        input.path,
        '-vn',
        '-af',
        _trimFilter(),
        '-c:a',
        'pcm_f32le',
        trimmed.path,
      ]);
      if (trim.exitCode != 0) {
        return RejectedAudio('trim failed: ${trim.stderr}');
      }

      final trimmedDuration = await _duration(trimmed.path);
      if (trimmedDuration == null || trimmedDuration < 0.05) {
        return const RejectedAudio('silent');
      }

      final measure = await _run(ffmpeg, [
        '-nostdin',
        '-hide_banner',
        '-i',
        trimmed.path,
        '-af',
        _loudnormFilter,
        '-f',
        'null',
        '-',
      ]);
      final loudness = parseLoudnorm('${measure.stderr}');
      if (measure.exitCode != 0 || loudness == null) {
        return const RejectedAudio('loudness measurement failed');
      }
      if (loudness.truePeakDb <= targets.silenceThresholdDb) {
        return const RejectedAudio('silent');
      }

      final gainDb = normalizationGain(loudness, targets);
      final bitrate = kind == SoundKind.music
          ? targets.musicBitrateKbps
          : targets.otherBitrateKbps;
      final encode = await _run(ffmpeg, [
        '-nostdin',
        '-hide_banner',
        '-y',
        '-i',
        trimmed.path,
        '-af',
        'volume=${gainDb.toStringAsFixed(2)}dB',
        // Mono stays mono; anything wider than stereo is mixed down.
        if ((await _channels(trimmed.path) ?? 2) > 2) ...['-ac', '2'],
        '-ar',
        '44100',
        '-c:a',
        'aac',
        '-b:a',
        '${bitrate}k',
        '-map_metadata',
        '-1',
        '-metadata',
        'title=$title',
        '-metadata',
        'artist=$artist',
        '-metadata',
        'comment=$comment',
        '-fflags',
        '+bitexact',
        '-flags:a',
        '+bitexact',
        '-movflags',
        '+faststart',
        output.path,
      ]);
      if (encode.exitCode != 0) {
        return RejectedAudio('encode failed: ${encode.stderr}');
      }

      final outputDuration = await _duration(output.path);
      if (outputDuration == null) return const RejectedAudio('encode failed');
      return PreparedAudio(
        durationSeconds: outputDuration,
        gainDb: gainDb,
        changes: [
          if (inputDuration - trimmedDuration > 0.01) 'edge silence trimmed',
          if (gainDb.abs() >= 0.1) 'loudness normalized',
        ],
      );
    } finally {
      await scratch.delete(recursive: true);
    }
  }

  String get _loudnormFilter =>
      'loudnorm=I=${targets.loudnessLufs}:TP=${targets.truePeakDb}'
      ':print_format=json';

  /// Keeps [AudioTargets.leadingSilence] before the first sound and
  /// [AudioTargets.trailingSilence] after the last; `areverse` lets the
  /// same filter trim the end.
  String _trimFilter() {
    String remove(double keep) =>
        'silenceremove=start_periods=1'
        ':start_threshold=${targets.silenceThresholdDb}dB'
        ':start_silence=$keep:detection=peak';
    return [
      remove(targets.leadingSilence),
      'areverse',
      remove(targets.trailingSilence),
      'areverse',
    ].join(',');
  }

  Future<double?> _duration(String path) async {
    final probe = await _run(ffprobe, [
      '-v',
      'error',
      '-show_entries',
      'format=duration',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    if (probe.exitCode != 0) return null;
    return double.tryParse('${probe.stdout}'.trim());
  }

  /// The number of channels of [path]'s first audio stream.
  Future<int?> _channels(String path) async {
    final probe = await _run(ffprobe, [
      '-v',
      'error',
      '-select_streams',
      'a:0',
      '-show_entries',
      'stream=channels',
      '-of',
      'default=noprint_wrappers=1:nokey=1',
      path,
    ]);
    if (probe.exitCode != 0) return null;
    return int.tryParse('${probe.stdout}'.trim());
  }
}

/// The gain that brings [measured] to [targets]' loudness without lifting
/// its true peak above the ceiling.
///
/// A clip too short to be gated is brought to the ceiling by its peak.
double normalizationGain(LoudnessMeasurement measured, AudioTargets targets) {
  final peakRoom = targets.truePeakDb - measured.truePeakDb;
  final integrated = measured.integratedLufs;
  if (integrated == null) return peakRoom;
  final toTarget = targets.loudnessLufs - integrated;
  return toTarget < peakRoom ? toTarget : peakRoom;
}

/// The measurement in the JSON block ffmpeg's `loudnorm` filter prints to
/// stderr, or null when there is none.
LoudnessMeasurement? parseLoudnorm(String stderr) {
  final start = stderr.lastIndexOf('{');
  final end = stderr.lastIndexOf('}');
  if (start == -1 || end < start) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(stderr.substring(start, end + 1));
  } on FormatException {
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final peak = _decibels(decoded['input_tp']);
  if (peak == null) return null;
  final integrated = _decibels(decoded['input_i']);
  return LoudnessMeasurement(
    // loudnorm reports -70 or -inf when nothing was loud enough to gate.
    integratedLufs: integrated == null || integrated <= -70 ? null : integrated,
    truePeakDb: peak,
  );
}

/// A level as loudnorm prints it, where `-inf` stands for digital silence.
double? _decibels(Object? value) {
  final text = '$value'.trim();
  if (text == '-inf') return double.negativeInfinity;
  return double.tryParse(text);
}
