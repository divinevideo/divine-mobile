// ABOUTME: Bakes a voice effect and noise reduction into the audio of any
// ABOUTME: timeline sound, and renders throwaway auditions of a setting.

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:models/models.dart'
    show AudioEvent, AudioSourceKind, VoiceEffect;
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/utils/audio_mime_type.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show EditorAudio;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:voice_effects/voice_effects.dart';

/// Thrown when a sound cannot be processed.
class VoiceEffectException implements Exception {
  /// Creates a [VoiceEffectException] describing [message], optionally
  /// wrapping the underlying [cause].
  const VoiceEffectException(this.message, {this.cause});

  /// What failed.
  final String message;

  /// The error that made it fail, if any.
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'VoiceEffectException: $message'
      : 'VoiceEffectException: $message ($cause)';
}

/// Where a sound's audio comes from before any effect: a local file, a
/// bundled asset or a network address, as [AudioEvent.originalSource] gives
/// it.
typedef VoiceEffectSource = ({AudioSourceKind kind, String path});

/// The file a sound plays with its effect, and that file's MIME type.
typedef ProcessedAudio = ({String path, String? mimeType});

/// Decodes the audio of the local file at [inputPath] into a 16-bit PCM WAV
/// at [outputPath].
typedef WavDecoder = Future<void> Function(String inputPath, String outputPath);

/// Copies a bundled or network [source] into a local file and returns its
/// path; the caller deletes the copy.
typedef AudioSourceFetcher = Future<String> Function(VoiceEffectSource source);

/// Level of the first echo repeat at full [VoiceEffect.echo].
const double _echoMixAtFull = 0.6;

/// Level of each further echo repeat at full [VoiceEffect.echo].
const double _echoFeedbackAtFull = 0.5;

/// The DSP chain that gives a sound [effect]: noise reduction first, so the
/// effects work on the clean signal, then pitch, robot and echo.
@visibleForTesting
List<AudioEffect> voiceEffectChain(
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

/// Processes the audio of timeline sounds for the voice-effect sheet.
///
/// A sound is fetched (when it is bundled or remote) and decoded once, and
/// kept decoded in the temporary directory, so every audition after the first
/// only runs the effects. An audition is a throwaway file in a folder of its
/// own, rendered from the stretch of the sound the timeline plays only, so
/// trying a setting on a long song costs no more than on a short take.
///
/// The kept result covers the whole sound, so its timing can still be edited
/// afterwards. It is a WAV named after its settings, so the editor preview
/// and the export play the very same file, the source stays untouched for
/// switching back, and picking a setting again reuses its file. A draft-local
/// file gets it beside itself; any other sound gets it in
/// [voiceEffectAudioDirName], where drafts keep track of it like their own
/// audio.
class VoiceEffectService {
  /// Creates the service. [decodeToWav], [fetchSource], [temporaryDirectory]
  /// and [documentsDirectory] can be injected for testing.
  VoiceEffectService({
    WavDecoder? decodeToWav,
    AudioSourceFetcher? fetchSource,
    Future<Directory> Function()? temporaryDirectory,
    Future<Directory> Function()? documentsDirectory,
  }) : _decodeToWav = decodeToWav ?? _decodeWithEditor,
       _fetchSource = fetchSource ?? _fetchToTemporaryFile,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _documentsDirectory =
           documentsDirectory ??
           (() async => Directory(await getDocumentsPath()));

  final WavDecoder _decodeToWav;
  final AudioSourceFetcher _fetchSource;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function() _documentsDirectory;

  /// Decodes still running, by source key. Auditions and a bake started
  /// before the first decode of a sound finishes wait for it instead of
  /// decoding the sound into the same file a second time.
  final Map<String, Future<File>> _decoding = {};

  static const _decodedDirName = 'voice_effect_decoded';
  static const _auditionDirName = 'voice_effect_audition';

  /// Renders [source] with [effect] and, when [noiseReduction] is set, its
  /// background noise filtered out, into a throwaway WAV, and returns its
  /// path.
  ///
  /// Only the stretch from [start], [length] long — to the end of the sound
  /// when `null` — is rendered, and the audition starts with it.
  ///
  /// Delete it with [discardAudition] once it is no longer played, or all of
  /// them with [clearAuditions].
  ///
  /// Throws a [VoiceEffectException] when the sound cannot be fetched,
  /// decoded or processed, or the audition cannot be written.
  Future<String> renderAudition({
    required VoiceEffectSource source,
    required VoiceEffect effect,
    required bool noiseReduction,
    Duration start = Duration.zero,
    Duration? length,
  }) async {
    final decoded = await _decoded(source);
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
        await _render(
          decoded,
          effect,
          noiseReduction: noiseReduction,
          start: start,
          length: length,
        ),
        flush: true,
      );
      return audition.path;
    } on Exception catch (e, s) {
      Error.throwWithStackTrace(
        VoiceEffectException('Failed to render audition', cause: e),
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

  /// The file that plays [source] with [effect] and, when [noiseReduction]
  /// is set, its background noise filtered out.
  ///
  /// There must be something to apply: a sound going back to its source plays
  /// the source itself.
  ///
  /// Throws a [VoiceEffectException] when the sound cannot be fetched or
  /// decoded, the decoded audio is unreadable, or the result cannot be
  /// written.
  Future<ProcessedAudio> process({
    required VoiceEffectSource source,
    required VoiceEffect effect,
    required bool noiseReduction,
  }) async {
    assert(
      !effect.isNone || noiseReduction,
      'Nothing to apply; play the source itself',
    );
    final target = processedPath(
      source,
      effect: effect,
      noiseReduction: noiseReduction,
      documentsPath: (await _documentsDirectory()).path,
    );
    final result = (path: target, mimeType: audioMimeTypeForPath(target));
    if (File(target).existsSync()) return result;

    final decoded = await _decoded(source);
    final partial = File('$target.part');
    try {
      await partial.parent.create(recursive: true);
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
        VoiceEffectException('Failed to process audio', cause: e),
        s,
      );
    }
  }

  /// Where [source] is written with [effect] and [noiseReduction] applied,
  /// named after both: beside it when it is a draft-local file, else in
  /// [voiceEffectAudioDirName] below [documentsPath], named after the source.
  @visibleForTesting
  static String processedPath(
    VoiceEffectSource source, {
    required VoiceEffect effect,
    required bool noiseReduction,
    required String documentsPath,
  }) {
    final settings =
        'p${effect.pitch}_r${effect.robot}_e${effect.echo}'
        '${noiseReduction ? '_nr' : ''}';
    if (source.kind == AudioSourceKind.file &&
        isDraftLocalAudioPath(source.path)) {
      return p.join(
        p.dirname(source.path),
        '${p.basenameWithoutExtension(source.path)}_$settings.wav',
      );
    }
    return p.join(
      documentsPath,
      voiceEffectAudioDirName,
      '${_sourceKey(source)}_$settings.wav',
    );
  }

  /// A file-name-safe key that names [source] and nothing else.
  static String _sourceKey(VoiceEffectSource source) => sha256
      .convert(utf8.encode('${source.kind.name}:${source.path}'))
      .toString();

  /// [source] decoded to WAV, decoding it on first use.
  ///
  /// Sources are never rewritten in place — a take keeps its file, a bundled
  /// sound its asset, a published sound its content-addressed blob — so a
  /// decode keyed by the source stays valid until the OS clears the
  /// temporary directory.
  ///
  /// Throws a [VoiceEffectException] when the sound cannot be fetched or
  /// decoded.
  Future<File> _decoded(VoiceEffectSource source) async {
    final key = _sourceKey(source);
    final running = _decoding[key];
    if (running != null) return running;
    final decoding = _decode(source, key);
    _decoding[key] = decoding;
    try {
      return await decoding;
    } finally {
      final _ = _decoding.remove(key);
    }
  }

  Future<File> _decode(VoiceEffectSource source, String key) async {
    final temporary = await _temporaryDirectory();
    final decoded = File(p.join(temporary.path, _decodedDirName, '$key.wav'));
    if (decoded.existsSync()) return decoded;

    // The decoder picks its output format from the extension, so the file in
    // progress keeps `.wav` and only its name says it is unfinished.
    final partial = File(p.join(decoded.parent.path, '$key.partial.wav'));
    final isLocal = source.kind == AudioSourceKind.file;
    String? fetched;
    try {
      await decoded.parent.create(recursive: true);
      final input = isLocal
          ? source.path
          : fetched = await _fetchSource(source);
      await _decodeToWav(input, partial.path);
      await partial.rename(decoded.path);
      return decoded;
    } on Exception catch (e, s) {
      if (partial.existsSync()) await partial.delete();
      Error.throwWithStackTrace(
        VoiceEffectException('Failed to decode audio', cause: e),
        s,
      );
    } finally {
      if (fetched != null) await _deleteQuietly(fetched);
    }
  }

  Future<Directory> _auditionDirectory() async =>
      Directory(p.join((await _temporaryDirectory()).path, _auditionDirName));

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // A fetched copy lives in the temporary directory, which the OS
      // reclaims on its own.
    }
  }

  static Future<Uint8List> _render(
    File decoded,
    VoiceEffect effect, {
    required bool noiseReduction,
    Duration start = Duration.zero,
    Duration? length,
  }) async {
    final bytes = await decoded.readAsBytes();
    return Isolate.run(
      () => _processWav(
        bytes,
        effect,
        noiseReduction: noiseReduction,
        start: start,
        length: length,
      ),
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

  /// Downloads a network sound with [RenderAudioFetcher], which retries, and
  /// names the file after its sniffed container rather than an extension a
  /// Blossom URL does not have; writes a bundled sound out of the app's
  /// assets.
  ///
  /// A file source is already local — [_decode] short-circuits it before this
  /// is called — so routing it through the Blossom-flavoured downloader is a
  /// bug, not a fallback.
  static Future<String> _fetchToTemporaryFile(VoiceEffectSource source) =>
      RenderAudioFetcher().localPathFor(
        switch (source.kind) {
          AudioSourceKind.asset => EditorAudio.asset(source.path),
          AudioSourceKind.network => EditorAudio.network(source.path),
          AudioSourceKind.file => throw StateError(
            '_fetchToTemporaryFile called with a local file source: '
            '${source.path}',
          ),
        },
        logName: 'VoiceEffectService',
      );
}

Uint8List _processWav(
  Uint8List wav,
  VoiceEffect effect, {
  required bool noiseReduction,
  required Duration start,
  required Duration? length,
}) {
  final audio = decodeWav(wav);
  final rate = audio.sampleRate;
  final total = audio.samples.length;
  final first = (start.inMicroseconds * rate ~/ Duration.microsecondsPerSecond)
      .clamp(0, total);
  final end = length == null
      ? total
      : (first + length.inMicroseconds * rate ~/ Duration.microsecondsPerSecond)
            .clamp(first, total);
  final samples = first == 0 && end == total
      ? audio.samples
      : Float32List.sublistView(audio.samples, first, end);
  final processed = applyAudioEffects(
    samples,
    rate,
    voiceEffectChain(effect, noiseReduction: noiseReduction),
  );
  return encodeWav(processed, rate);
}
