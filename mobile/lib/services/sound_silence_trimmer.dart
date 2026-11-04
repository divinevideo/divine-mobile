// ABOUTME: Readies a sound file for publishing as a Kind 1063: leaves out a
// ABOUTME: sound with nothing to hear and cuts the silence off its edges.

import 'dart:io';
import 'dart:math' as math;

import 'package:openvine/utils/audible_range.dart';
import 'package:openvine/utils/audio_mime_type.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// How [SoundSilenceTrimmer.trim] found a sound.
sealed class SoundTrimResult {
  const SoundTrimResult();
}

/// Nothing in the sound is loud enough to hear, so publishing it would share
/// silence.
final class SilentSound extends SoundTrimResult {
  const SilentSound();
}

/// A sound with something to hear, and the file to publish it from.
final class AudibleSound extends SoundTrimResult {
  const AudibleSound({
    required this.path,
    required this.mimeType,
    this.trimmedDuration,
  });

  /// The file to upload: a copy cut to the audible part, or the source itself
  /// when it has no silence to cut or could not be cut.
  final String path;

  /// The MIME type of [path].
  final String mimeType;

  /// How long the cut copy is, or `null` when [path] is the source itself.
  final Duration? trimmedDuration;

  /// Whether [path] is a cut copy, which the caller deletes with
  /// [SoundSilenceTrimmer.deleteTrimmedCopy] once it is uploaded.
  bool get isTrimmed => trimmedDuration != null;
}

/// Checks a sound for anything audible before it is published or added to My
/// Sounds, and cuts the silence off its start and end.
///
/// Audibility is the peak of every 5 ms of the sound against
/// [soundSilenceThresholdDbfs], measured by `pro_video_editor`'s waveform
/// reader; [soundEdgeMargin] of silence is kept on each cut edge.
///
/// A cut copy is written without re-encoding: a WAV stays WAV, and AAC (an
/// `.m4a` or `.aac` file, which includes the app's own recordings) is copied
/// frame by frame into an `.m4a`. `pro_video_editor` cannot copy any other
/// codec, MP3 among them, so such a sound is published uncut.
///
/// Only the copy that is published is cut. The editor's own clip audio must
/// keep the clip's timing and never goes through here.
class SoundSilenceTrimmer {
  SoundSilenceTrimmer({
    ProVideoEditor? editor,
    Future<Directory> Function()? temporaryDirectory,
  }) : _editor = editor,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  static const String _logName = 'SoundSilenceTrimmer';

  final ProVideoEditor? _editor;
  final Future<Directory> Function() _temporaryDirectory;

  /// Read at call time, so a replaced platform instance is honoured.
  ProVideoEditor get _videoEditor => _editor ?? ProVideoEditor.instance;

  /// Whether a measurement finds nothing audible in the sound at [path].
  ///
  /// A sound that cannot be measured counts as audible: a decoder failure is
  /// not evidence of silence.
  Future<bool> isSilent(String path) async {
    final measurement = await _measure(path);
    return measurement != null && measurement.range == null;
  }

  /// Measures the sound at [path], of [mimeType], and cuts its silent edges.
  ///
  /// Only a measurement that finds nothing audible returns [SilentSound]. A
  /// sound that cannot be measured or cut is returned as it is, so a decoder
  /// failure never stops a publish.
  Future<SoundTrimResult> trim({
    required String path,
    required String mimeType,
  }) async {
    final whole = AudibleSound(path: path, mimeType: mimeType);
    final measurement = await _measure(path);
    if (measurement == null) return whole;
    final range = measurement.range;
    if (range == null) return const SilentSound();
    if (range.start == Duration.zero && range.end == measurement.duration) {
      return whole;
    }

    final format = _copyFormatFor(mimeType);
    if (format == null) {
      Log.info(
        'A $mimeType sound cannot be cut without re-encoding, publishing it '
        'uncut',
        name: _logName,
        category: LogCategory.video,
      );
      return whole;
    }
    return await _cut(path, range, format) ?? whole;
  }

  /// The audible part of the sound at [path] and the sound's length, with a
  /// `null` range when nothing in it is audible; `null` when it cannot be
  /// measured.
  Future<({AudibleRange? range, Duration duration})?> _measure(
    String path,
  ) async {
    final WaveformData waveform;
    try {
      waveform = await _videoEditor.getWaveform(
        WaveformConfigs(
          video: EditorVideo.file(path),
          resolution: WaveformResolution.high,
        ),
      );
    } catch (error, stackTrace) {
      // Not only Exceptions: the plugin reports an empty native result or a
      // malformed payload as an ArgumentError.
      Log.warning(
        'Could not measure the sound, treating it as audible: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
    if (waveform.samplesPerSecond <= 0 ||
        waveform.duration <= Duration.zero ||
        waveform.leftChannel.isEmpty) {
      Log.warning(
        'The sound measured empty, treating it as audible',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final channels = [waveform.leftChannel, ?waveform.rightChannel];
    final blocks = channels.fold(
      0,
      (most, peaks) => math.max(most, peaks.length),
    );
    final measured = Duration(
      microseconds:
          blocks * Duration.microsecondsPerSecond ~/ waveform.samplesPerSecond,
    );
    // The plugin keeps the peaks it decoded when a read fails partway and
    // still reports the whole length, so a short read looks complete. Within
    // the edge margin the cut keeps the unread tail anyway.
    if (waveform.duration - measured > soundEdgeMargin) {
      Log.warning(
        'The sound measured ${measured.inMilliseconds} of '
        '${waveform.duration.inMilliseconds} ms, treating it as audible',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final range = audibleRange(
      channels: channels,
      blocksPerSecond: waveform.samplesPerSecond,
      duration: waveform.duration,
    );
    if (range == null) {
      Log.info(
        'Nothing in the sound reaches $soundSilenceThresholdDbfs dBFS',
        name: _logName,
        category: LogCategory.video,
      );
    }
    return (range: range, duration: waveform.duration);
  }

  /// Deletes [sound]'s file when it is a cut copy; the source is left alone.
  Future<void> deleteTrimmedCopy(AudibleSound sound) async {
    if (sound.isTrimmed) await _deleteQuietly(sound.path);
  }

  Future<AudibleSound?> _cut(
    String path,
    AudibleRange range,
    AudioFormat format,
  ) async {
    String? output;
    try {
      final directory = await _temporaryDirectory();
      output = p.join(
        directory.path,
        'trimmed_sound_${DateTime.now().microsecondsSinceEpoch}.'
        '${format == AudioFormat.wav ? 'wav' : 'm4a'}',
      );
      await _videoEditor.extractAudioToFile(
        output,
        AudioExtractConfigs(
          video: EditorVideo.file(path),
          format: format,
          startTime: range.start,
          endTime: range.end,
        ),
      );
    } catch (error, stackTrace) {
      Log.warning(
        'Could not cut the silence off the sound, publishing it uncut: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      if (output != null) await _deleteQuietly(output);
      return null;
    }
    Log.info(
      'Cut the sound to ${range.start.inMilliseconds}-'
      '${range.end.inMilliseconds} ms',
      name: _logName,
      category: LogCategory.video,
    );
    return AudibleSound(
      path: output,
      mimeType: audioMimeTypeForPath(output)!,
      trimmedDuration: await _durationOf(output) ?? range.duration,
    );
  }

  /// The length of the cut copy as written: the plugin cuts at whole decoder
  /// buffers or codec frames, so it can run slightly past the range asked
  /// for.
  Future<Duration?> _durationOf(String path) async {
    try {
      final duration = (await _videoEditor.getMetadata(EditorVideo.file(path)))
          .duration;
      return duration > Duration.zero ? duration : null;
    } catch (error, stackTrace) {
      Log.warning(
        'Could not read back the cut sound, using the cut length: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Never written, or already gone; a leftover copy sits in the
      // temporary directory, which the OS reclaims on its own.
    }
  }

  /// The format a cut copy of a [mimeType] sound is written in without
  /// re-encoding it, or `null` when `pro_video_editor` cannot do that.
  static AudioFormat? _copyFormatFor(String mimeType) =>
      switch (mimeType.toLowerCase()) {
        'audio/wav' || 'audio/x-wav' || 'audio/wave' => AudioFormat.wav,
        'audio/mp4' ||
        'audio/m4a' ||
        'audio/x-m4a' ||
        'audio/aac' => AudioFormat.m4a,
        _ => null,
      };
}
