// ABOUTME: Pre-renders the window of a sound that plays along a speed ramp into
// ABOUTME: a normal-rate WAV, so the preview plays at 1× what the export plays.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/extensions/audio_event_speed.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show EditorAudioType;
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioMergeConfigs, AudioMergeSegment, EditorVideo, ProVideoEditor;
import 'package:unified_logger/unified_logger.dart';

/// Renders and caches the window of every sound with a speed ramp.
///
/// The preview player plays an added sound at one rate, so a ramp reaches it
/// only as a file with the ramp baked in. `mergeAudioToFile` stretches the
/// window along the ramp's steps at unchanged pitch, exactly as the export
/// stretches the track, and the player plays the file at 1× from its start.
/// Until it lands the preview plays the sound at the ramp's average speed,
/// which keeps the window's length. Volume, fades and the equalizer are left
/// to the player, so changing them never renders again.
class SoundSpeedRampRenderService {
  /// [proVideoEditor], [fetcher] and [directory] can be injected for tests.
  SoundSpeedRampRenderService({
    ProVideoEditor? proVideoEditor,
    RenderAudioFetcher? fetcher,
    Future<Directory> Function()? directory,
  }) : _proVideoEditor = proVideoEditor ?? ProVideoEditor.instance,
       _fetcher = fetcher ?? RenderAudioFetcher(),
       _directory = directory ?? getTemporaryDirectory;

  final ProVideoEditor _proVideoEditor;
  final RenderAudioFetcher _fetcher;
  final Future<Directory> Function() _directory;

  final _cache = <String, String>{};
  final _inFlight = <String, Future<String?>>{};

  /// Sources copied or downloaded for a render, deleted by [clear].
  final _fetchedPaths = <String>{};

  /// Bumped by [clear]; a render started under an older one discards itself.
  int _generation = 0;

  static const _logName = 'SoundSpeedRampRenderService';

  /// How many rendered windows stay on disk. Every edit of a ramp or a window
  /// renders a new one; the ones the preview asks for are kept the longest.
  static const maxCachedFiles = 12;

  /// The rendered window of [sound], or `null` when it is not rendered yet
  /// or the sound has no ramp. Never starts a render.
  String? cached(AudioEvent sound) {
    final key = _keyOf(sound);
    return key == null ? null : _cachedLive(key);
  }

  /// The file for [key], now the most recently used one.
  String? _cachedLive(String key) {
    final path = _cache.remove(key);
    if (path != null) _cache[key] = path;
    return path;
  }

  /// Renders the window of [sound] along its ramp, or returns the file
  /// already rendered or rendering for it.
  ///
  /// Completes with `null` when the sound has no ramp, no source or no known
  /// window, or when the render fails; the next call tries again.
  Future<String?> render(AudioEvent sound) {
    final key = _keyOf(sound);
    if (key == null) return Future.value();
    final cached = _cachedLive(key);
    if (cached != null) return Future.value(cached);
    // Not returned: the removed future is this one, which would then wait
    // for itself.
    return _inFlight[key] ??= _render(sound, key).whenComplete(() {
      final _ = _inFlight.remove(key);
    });
  }

  Future<String?> _render(AudioEvent sound, String key) async {
    final generation = _generation;
    final ramp = sound.speedRamp!;
    final span = sound.playedSourceSpan!;
    final audio = audioTrackFromMetaForRender(sound, logName: _logName)?.audio;
    if (audio == null) return null;
    String? output;
    try {
      final source = await _fetcher.localPathFor(audio, logName: _logName);
      if (audio.type != EditorAudioType.file) _fetchedPaths.add(source);
      final directory = Directory('${(await _directory()).path}/sound_ramps');
      if (!directory.existsSync()) directory.createSync(recursive: true);
      final hash = sha256.convert(utf8.encode(key)).toString();
      output = '${directory.path}/$hash.wav';
      final scratch = '$output.tmp.wav';
      await _proVideoEditor.mergeAudioToFile(
        scratch,
        AudioMergeConfigs(
          segments: [
            AudioMergeSegment(
              video: EditorVideo.file(source),
              startTime: sound.startOffset,
              endTime: sound.startOffset + span,
              speedRamp: ramp,
            ),
          ],
        ),
      );
      await File(scratch).rename(output);
      if (generation != _generation) {
        await _deleteQuietly(output);
        return null;
      }
      _cache[key] = output;
      while (_cache.length > maxCachedFiles) {
        final evicted = _cache.remove(_cache.keys.first)!;
        unawaited(_deleteQuietly(evicted));
      }
      Log.info(
        '🎵 Ramped sound rendered: ${sound.id} → $output',
        name: _logName,
        category: LogCategory.video,
      );
      return output;
    } catch (e, stackTrace) {
      Log.error(
        'Ramped sound render failed for ${sound.id}',
        name: _logName,
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      if (output != null) await _deleteQuietly('$output.tmp.wav');
      return null;
    }
  }

  /// Keyed by what the file bakes in — the sound's file, where its window
  /// starts, how much of the sound it plays and the ramp — and not by the
  /// sound's id, so a duplicate or an undo plays the same file.
  String? _keyOf(AudioEvent sound) {
    final ramp = sound.speedRamp;
    final span = sound.playedSourceSpan;
    final source = sound.url ?? sound.assetPath;
    if (ramp == null || span == null || span <= Duration.zero) return null;
    if (source == null) return null;
    return 'v1|$source|${sound.startOffset.inMicroseconds}|'
        '${span.inMicroseconds}|${jsonEncode(ramp.toMap())}';
  }

  /// Forgets every rendered window and deletes its file, along with the
  /// sources fetched for them. A render still running deletes its file when
  /// it lands.
  void clear() {
    _generation++;
    final files = [..._cache.values, ..._fetchedPaths];
    _cache.clear();
    _inFlight.clear();
    _fetchedPaths.clear();
    for (final path in files) {
      unawaited(_deleteQuietly(path));
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } on FileSystemException {
      // Best-effort cleanup; the OS reaps the temp directory later.
    }
  }
}
