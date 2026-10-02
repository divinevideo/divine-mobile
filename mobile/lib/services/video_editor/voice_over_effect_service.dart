// ABOUTME: Bakes a voice effect and noise reduction into a recorded voice-over
// ABOUTME: take, and renders throwaway auditions of a setting before it is kept.

import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show VoiceEffect;
import 'package:openvine/utils/audio_mime_type.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:voice_effects/voice_effects.dart';

/// Thrown when a take cannot be processed.
class VoiceOverEffectException implements Exception {
  /// Creates a [VoiceOverEffectException] describing [message], optionally
  /// wrapping the underlying [cause].
  const VoiceOverEffectException(this.message, {this.cause});

  /// What failed.
  final String message;

  /// The error that made it fail, if any.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'VoiceOverEffectException: $message'
      : 'VoiceOverEffectException: $message ($cause)';
}

/// The file a take plays with its effect, and that file's MIME type.
typedef ProcessedVoiceOverTake = ({String path, String? mimeType});

/// Decodes the audio of [inputPath] into a 16-bit PCM WAV at [outputPath].
typedef VoiceOverWavDecoder = Future<void> Function(
  String inputPath,
  String outputPath,
);

/// Level of the first echo repeat at full [VoiceEffect.echo].
const double _echoMixAtFull = 0.6;

/// Level of each further echo repeat at full [VoiceEffect.echo].
const double _echoFeedbackAtFull = 0.5;

/// The DSP chain that gives a take [effect]: noise reduction first, so the
/// effects work on the clean voice, then pitch, robot and echo.
@visibleForTesting
List<AudioEffect> voiceOverEffectChain(
  VoiceEffect effect, {
  required bool noiseReduction,
}) {
  const full = VoiceEffect.maxAmount;
  final echo = effect.echo / full;
  return [
    if (noiseReduction) const NoiseReduction(),
    if (effect.pitch != 0) PitchShift(effect.pitch.toDouble()),
    if (effect.robot > 0) Robotize(mix: effect.robot / full),
    if (effect.echo > 0)
      Echo(mix: _echoMixAtFull * echo, feedback: _echoFeedbackAtFull * echo),
  ];
}

/// Processes recorded voice-over takes for the voice-effect sheet.
///
/// A take is decoded once and kept decoded in the temporary directory, so
/// every audition after the first only runs the effects. An audition is a
/// throwaway file in a folder of its own; the kept result is a WAV written
/// next to the take and named after its settings, so the editor preview and
/// the export play the very same file, the take itself stays untouched for
/// switching back, and picking a setting again reuses its file.
class VoiceOverEffectService {
  /// Creates the service. [decodeToWav] and [temporaryDirectory] can be
  /// injected for testing.
  VoiceOverEffectService({
    VoiceOverWavDecoder? decodeToWav,
    Future<Directory> Function()? temporaryDirectory,
  }) : _decodeToWav = decodeToWav ?? _decodeWithEditor,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final VoiceOverWavDecoder _decodeToWav;
  final Future<Directory> Function() _temporaryDirectory;

  static const _decodedDirName = 'voice_over_decoded';
  static const _auditionDirName = 'voice_over_audition';

  /// Renders the take at [takePath] with [effect] and, when [noiseReduction]
  /// is set, its background noise filtered out, into a throwaway WAV, and
  /// returns its path.
  ///
  /// Delete it with [discardAudition] once it is no longer played, or all of
  /// them with [clearAuditions].
  ///
  /// Throws a [VoiceOverEffectException] when the take cannot be decoded or
  /// processed, or the audition cannot be written.
  Future<String> renderAudition({
    required String takePath,
    required VoiceEffect effect,
    required bool noiseReduction,
  }) async {
    final decoded = await _decoded(takePath);
    try {
      final directory = await _auditionDirectory();
      await directory.create(recursive: true);
      final audition = File(
        p.join(
          directory.path,
          'audition_${DateTime.now().microsecondsSinceEpoch}.wav',
        ),
      );
      await audition.writeAsBytes(
        await _render(decoded, effect, noiseReduction: noiseReduction),
        flush: true,
      );
      return audition.path;
    } on Exception catch (e, s) {
      Error.throwWithStackTrace(
        VoiceOverEffectException('Failed to render audition', cause: e),
        s,
      );
    }
  }

  /// Deletes the audition at [path]. Leaves any other file alone.
  Future<void> discardAudition(String path) async {
    final directory = await _auditionDirectory();
    if (!p.isWithin(directory.path, path)) return;
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone, or still held: an audition lives in the temporary
      // directory, which the OS reclaims on its own.
    }
  }

  /// Deletes every audition.
  Future<void> clearAuditions() async {
    final directory = await _auditionDirectory();
    try {
      await directory.delete(recursive: true);
    } on FileSystemException {
      // Nothing was auditioned, or the OS got there first; see
      // discardAudition.
    }
  }

  /// The file that plays the take at [takePath] with [effect] and, when
  /// [noiseReduction] is set, its background noise filtered out.
  ///
  /// Returns [takePath] itself when there is nothing to apply.
  ///
  /// Throws a [VoiceOverEffectException] when the take cannot be decoded, the
  /// decoded audio is unreadable, or the result cannot be written.
  Future<ProcessedVoiceOverTake> process({
    required String takePath,
    required VoiceEffect effect,
    required bool noiseReduction,
  }) async {
    if (effect.isNone && !noiseReduction) {
      return (path: takePath, mimeType: audioMimeTypeForPath(takePath));
    }

    final target = processedPath(
      takePath,
      effect: effect,
      noiseReduction: noiseReduction,
    );
    final result = (path: target, mimeType: audioMimeTypeForPath(target));
    if (File(target).existsSync()) return result;

    final decoded = await _decoded(takePath);
    final partial = File('$target.part');
    try {
      // Written aside and renamed into place, so an interrupted write never
      // leaves a file that would be reused as finished.
      await partial.writeAsBytes(
        await _render(decoded, effect, noiseReduction: noiseReduction),
        flush: true,
      );
      await partial.rename(target);
      return result;
    } on Exception catch (e, s) {
      if (partial.existsSync()) await partial.delete();
      Error.throwWithStackTrace(
        VoiceOverEffectException('Failed to process voice-over take', cause: e),
        s,
      );
    }
  }

  /// Where the take at [takePath] is written with [effect] and
  /// [noiseReduction] applied: beside it, named after both.
  @visibleForTesting
  static String processedPath(
    String takePath, {
    required VoiceEffect effect,
    required bool noiseReduction,
  }) {
    final settings =
        'p${effect.pitch}_r${effect.robot}_e${effect.echo}'
        '${noiseReduction ? '_nr' : ''}';
    return p.join(
      p.dirname(takePath),
      '${p.basenameWithoutExtension(takePath)}_$settings.wav',
    );
  }

  /// The take at [takePath] decoded to WAV, decoding it on first use.
  ///
  /// Takes are never rewritten, so a decode keyed by the take's name stays
  /// valid until the OS clears the temporary directory.
  ///
  /// Throws a [VoiceOverEffectException] when the take cannot be decoded.
  Future<File> _decoded(String takePath) async {
    final temporary = await _temporaryDirectory();
    final name = p.basenameWithoutExtension(takePath);
    final decoded = File(p.join(temporary.path, _decodedDirName, '$name.wav'));
    if (decoded.existsSync()) return decoded;

    // The decoder picks its output format from the extension, so the file in
    // progress keeps `.wav` and only its name says it is unfinished.
    final partial = File(p.join(decoded.parent.path, '$name.partial.wav'));
    try {
      await decoded.parent.create(recursive: true);
      await _decodeToWav(takePath, partial.path);
      await partial.rename(decoded.path);
      return decoded;
    } on Exception catch (e, s) {
      if (partial.existsSync()) await partial.delete();
      Error.throwWithStackTrace(
        VoiceOverEffectException('Failed to decode voice-over take', cause: e),
        s,
      );
    }
  }

  Future<Directory> _auditionDirectory() async =>
      Directory(p.join((await _temporaryDirectory()).path, _auditionDirName));

  static Future<Uint8List> _render(
    File decoded,
    VoiceEffect effect, {
    required bool noiseReduction,
  }) async {
    final bytes = await decoded.readAsBytes();
    return Isolate.run(
      () => _processWav(bytes, effect, noiseReduction: noiseReduction),
    );
  }

  static Future<void> _decodeWithEditor(String inputPath, String outputPath) =>
      ProVideoEditor.instance.extractAudioToFile(
        outputPath,
        AudioExtractConfigs(
          video: EditorVideo.file(inputPath),
          format: AudioFormat.wav,
        ),
      );
}

Uint8List _processWav(
  Uint8List wav,
  VoiceEffect effect, {
  required bool noiseReduction,
}) {
  final audio = decodeWav(wav);
  final processed = applyAudioEffects(
    audio.samples,
    audio.sampleRate,
    voiceOverEffectChain(effect, noiseReduction: noiseReduction),
  );
  return encodeWav(processed, audio.sampleRate);
}
