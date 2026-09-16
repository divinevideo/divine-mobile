// ABOUTME: Pre-renders a clip's trimmed body at its playbackSpeed into a plain
// ABOUTME: normal-rate file so the preview plays it at 1× instead of retiming live.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show EditorVideo, ProVideoEditor, VideoRenderData, VideoSegment;
import 'package:unified_logger/unified_logger.dart';

/// A clip body rendered to a plain, normal-rate file with its
/// [DivineVideoClip.playbackSpeed] baked in, so the preview plays it at 1×
/// (no live retiming — smoother on both Android and iOS).
class RenderedSpeedClip {
  const RenderedSpeedClip({required this.path, required this.duration});

  /// Path to the rendered normal-rate video.
  final String path;

  /// Playback duration of the rendered file (≈ the clip's `playbackDuration`).
  final Duration duration;
}

/// Renders and caches per-clip speed bodies. Cache keys include the clip's
/// file, trims and speed, so a trim/speed change naturally misses the cache and
/// re-renders; the preview keeps playing the live-retimed clip until the new
/// file lands.
///
/// Mirrors [TransitionSeamRenderService]: the preview plays the live-retimed
/// clip instantly (no wait), this renders the smooth normal-rate file in the
/// background, and the canvas swaps it in when ready. Volume is **not** baked in
/// (the player applies it per clip), so a mute toggle never re-renders.
class ClipSpeedRenderService {
  final _cache = <String, RenderedSpeedClip>{};
  final _inFlight = <String, Future<RenderedSpeedClip?>>{};
  int _clearGeneration = 0;

  /// True while a speed body for this clip is being rendered.
  bool isRendering(DivineVideoClip clip) => _inFlight.containsKey(_key(clip));

  /// The already-rendered speed body for [clip], or `null` if it is not rendered
  /// yet or the clip plays at 1×. Never triggers a render.
  RenderedSpeedClip? cached(DivineVideoClip clip) {
    if (!_needsRender(clip)) return null;
    return _cachedLive(_key(clip));
  }

  /// Returns the cached body for [key], promoting it to most-recently-used so
  /// the bounded LRU eviction ([_evictOverflow]) never drops a body that is
  /// still in use.
  RenderedSpeedClip? _cachedLive(String key) {
    final entry = _cache.remove(key);
    if (entry == null) return null;
    _cache[key] = entry;
    return entry;
  }

  /// Renders (or returns the cached / in-flight) normal-rate body for [clip].
  /// Returns `null` when the clip plays at 1× (nothing to render) or on failure.
  Future<RenderedSpeedClip?> render(DivineVideoClip clip) {
    if (!_needsRender(clip)) return Future<RenderedSpeedClip?>.value();
    final key = _key(clip);
    final cached = _cachedLive(key);
    if (cached != null) return Future<RenderedSpeedClip?>.value(cached);
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;
    late final Future<RenderedSpeedClip?> render;
    render = _renderAndClear(clip, key, () => render);
    _inFlight[key] = render;
    return render;
  }

  Future<RenderedSpeedClip?> _renderAndClear(
    DivineVideoClip clip,
    String key,
    Future<RenderedSpeedClip?> Function() currentRender,
  ) async {
    try {
      return await _render(clip, key);
    } finally {
      if (identical(_inFlight[key], currentRender())) {
        final _ = _inFlight.remove(key);
      }
    }
  }

  bool _needsRender(DivineVideoClip clip) {
    final speed = clip.playbackSpeed ?? 1.0;
    return speed > 0 && speed != 1.0 && clip.video?.file != null;
  }

  /// How many speed bodies may encode natively at the same time.
  ///
  /// The canvas asks for a render per non-1× clip on every timeline change, so
  /// a 28-clip draft would otherwise open 28 export sessions at once. Past a
  /// couple of concurrent sessions the platform encoder stops making progress
  /// and `pro_video_editor` fails them with a stall (`progress=0.00` after
  /// 20s), which is slower *and* lossier than encoding them a few at a time.
  static const _maxConcurrentRenders = 2;

  int _activeRenders = 0;
  final _waitingForSlot = Queue<Completer<void>>();

  /// Resolves once a render slot is free. Slots are handed out FIFO so the
  /// clips at the head of the timeline — the ones the user is most likely to
  /// play first — finish first.
  Future<void> _acquireRenderSlot() {
    if (_activeRenders < _maxConcurrentRenders) {
      _activeRenders++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waitingForSlot.add(waiter);
    return waiter.future;
  }

  /// Hands this slot straight to the next waiter, or gives it back to the pool
  /// when nobody is queued. Passing it on keeps [_activeRenders] at the cap
  /// instead of dipping below it between renders.
  void _releaseRenderSlot() {
    if (_waitingForSlot.isNotEmpty) {
      _waitingForSlot.removeFirst().complete();
      return;
    }
    _activeRenders--;
  }

  Future<RenderedSpeedClip?> _render(DivineVideoClip clip, String key) async {
    // Reachable only via [render], which gates on [_needsRender] (video
    // non-null). Re-checked here so the type is provably non-null below.
    final video = clip.video;
    if (video == null) return null;
    final renderGeneration = _clearGeneration;
    String? tempOutput;
    String? tempPath;
    String? cachePath;
    try {
      // Wait for a still-processing recording to finish before rendering.
      await clip.processingCompleter?.future;

      final hash = sha256.convert(utf8.encode(key)).toString();
      cachePath = await _cachePath(hash);
      if (_isStale(renderGeneration)) return null;

      // Reuse a file rendered earlier in this temp-cache lifetime; a truncated
      // file left by a kill mid-write is detected and dropped so it re-renders.
      if (File(cachePath).existsSync()) {
        final existing = await _fromPersistedFile(cachePath);
        if (existing != null) {
          if (_isStale(renderGeneration)) {
            await _deleteQuietly(existing.path);
            return null;
          }
          _store(key, existing);
          return existing;
        }
      }

      final tempDir = await getTemporaryDirectory();
      tempOutput =
          '${tempDir.path}/speed_${DateTime.now().microsecondsSinceEpoch}.mp4';

      // Render only the trimmed body at the target speed, with no crop/transform
      // — the preview player crops the texture itself, exactly as it does for
      // the raw live-retimed clip, so nothing is double-cropped.
      await _acquireRenderSlot();
      try {
        // The editor may have closed, or this clip may have been edited again,
        // while the request waited for a slot. Bailing here keeps a queued
        // backlog from encoding bodies nobody will play — the case that kept
        // the encoder busy for ~20s after the editor was torn down.
        if (_isStale(renderGeneration)) return null;
        await VideoEditorRenderService.renderNativeVideoToFile(
          tempOutput,
          VideoRenderData(
            id: 'speed_$hash',
            videoSegments: [
              VideoSegment(
                video: video,
                startTime: clip.trimStart == Duration.zero
                    ? null
                    : clip.trimStart,
                endTime: clip.trimStart + clip.trimmedDuration,
                playbackSpeed: clip.playbackSpeed,
              ),
            ],
            shouldOptimizeForNetworkUse: true,
          ),
        );
      } finally {
        _releaseRenderSlot();
      }
      if (_isStale(renderGeneration)) {
        await _deleteQuietly(tempOutput);
        return null;
      }

      // Publish atomically within the temp cache (temp→copy→rename) so a
      // crash mid-copy can only leave a stray `.tmp`, never a truncated keyed
      // file that would resolve to a corrupt render forever.
      tempPath = '$cachePath.tmp';
      File(cachePath).parent.createSync(recursive: true);
      await File(tempOutput).copy(tempPath);
      await File(tempPath).rename(cachePath);
      await _deleteQuietly(tempOutput);
      if (_isStale(renderGeneration)) {
        await _deleteQuietly(cachePath);
        await _deleteEmptyParent(cachePath);
        return null;
      }

      final rendered = await _fromPersistedFile(cachePath);
      if (rendered == null) return null;
      if (_isStale(renderGeneration)) {
        await _deleteQuietly(rendered.path);
        await _deleteEmptyParent(rendered.path);
        return null;
      }
      _store(key, rendered);
      Log.info(
        '🎬 Speed body rendered: ${clip.id} @${clip.playbackSpeed}× '
        '→ ${rendered.duration.inMilliseconds}ms',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
      );
      return rendered;
    } catch (e, stackTrace) {
      Log.error(
        'Clip speed render failed',
        name: 'ClipSpeedRenderService',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      return null;
    } finally {
      // tempOutput and tempPath are always intermediate scratch files: on the
      // success path they've already been consumed (deleted / renamed away), so
      // deleting them again is a no-op — but if the native render or the publish
      // threw while not stale, this is what stops the scratch file leaking.
      if (tempOutput != null) await _deleteQuietly(tempOutput);
      if (tempPath != null) await _deleteQuietly(tempPath);
      if (_isStale(renderGeneration) && cachePath != null) {
        await _deleteEmptyParent(cachePath);
      }
    }
  }

  bool _isStale(int renderGeneration) => renderGeneration != _clearGeneration;

  /// Loads a previously-rendered file from [path], or `null` (deleting it) when
  /// it can't be read or has no duration — e.g. a truncated file from a kill
  /// mid-write. Deleting lets the caller re-render instead of resolving to the
  /// same corrupt file forever.
  Future<RenderedSpeedClip?> _fromPersistedFile(String path) async {
    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(path),
      );
      if (metadata.duration <= Duration.zero) {
        await _deleteQuietly(path);
        return null;
      }
      return RenderedSpeedClip(path: path, duration: metadata.duration);
    } catch (e, stackTrace) {
      Log.warning(
        'Dropping unreadable rendered speed clip at $path',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
      );
      Log.debug(
        'Rendered speed clip read failed: $e\n$stackTrace',
        name: 'ClipSpeedRenderService',
        category: LogCategory.video,
      );
      await _deleteQuietly(path);
      return null;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {
      // Best-effort cleanup; a failed delete just re-renders next time.
    }
  }

  Future<void> _deleteEmptyParent(String path) async {
    try {
      final parent = File(path).parent;
      if (parent.existsSync() && parent.listSync().isEmpty) {
        await parent.delete();
      }
    } catch (_) {
      // Best-effort cleanup; temp cache can be reaped by the OS later.
    }
  }

  void _deleteCachedFilesSync(Iterable<RenderedSpeedClip> clips) {
    final parents = <String>{};
    for (final clip in clips) {
      parents.add(File(clip.path).parent.path);
      try {
        final file = File(clip.path);
        if (file.existsSync()) file.deleteSync();
      } catch (_) {
        // Best-effort cleanup; temp cache can be reaped by the OS later.
      }
      try {
        final tempFile = File('${clip.path}.tmp');
        if (tempFile.existsSync()) tempFile.deleteSync();
      } catch (_) {
        // Best-effort cleanup; temp cache can be reaped by the OS later.
      }
    }
    for (final parent in parents) {
      try {
        final dir = Directory(parent);
        if (dir.existsSync() && dir.listSync().isEmpty) {
          dir.deleteSync();
        }
      } catch (_) {
        // Best-effort cleanup; temp cache can be reaped by the OS later.
      }
    }
  }

  static const _maxCachedFiles = 32;

  /// Publishes [rendered] for [key] as the most-recently-used entry and evicts
  /// the least-recently-used bodies once the cache exceeds [_maxCachedFiles].
  /// Eviction removes the map entry **and** its file together, so the in-memory
  /// cache and the on-disk files stay in lockstep and a later lookup can never
  /// resolve to an evicted file.
  void _store(String key, RenderedSpeedClip rendered) {
    _cache.remove(key);
    _cache[key] = rendered;
    _evictOverflow();
  }

  void _evictOverflow() {
    while (_cache.length > _maxCachedFiles) {
      final oldestKey = _cache.keys.first;
      final evicted = _cache.remove(oldestKey);
      if (evicted != null) _deleteCachedFilesSync([evicted]);
    }
  }

  /// Bumped whenever the render inputs baked into the file change shape, so
  /// files rendered by an older algorithm are re-rendered after an app upgrade
  /// instead of replayed stale if the OS keeps temp cache files around.
  static const _cacheVersion = 1;

  /// Keyed by what the render actually bakes in — source file, trims and speed
  /// — and deliberately **not** by [DivineVideoClip.id]. Duplicating a clip,
  /// splitting one and undoing the split, or reopening a draft all mint fresh
  /// ids for byte-identical bodies; keying on the id re-encoded every one of
  /// them. Two clips that agree on all of these produce the same file, so they
  /// can share a single render.
  String _key(DivineVideoClip clip) =>
      'v$_cacheVersion|${clip.video?.file?.path}:'
      '${clip.duration.inMicroseconds}:${clip.trimStart.inMicroseconds}:'
      '${clip.trimEnd.inMicroseconds}:${clip.playbackSpeed ?? 1.0}';

  /// Deterministic on-disk path for a rendered body, keyed by [hash] so the same
  /// clip + trims + speed can reuse a temp-cache file while it remains valid.
  Future<String> _cachePath(String hash) async {
    final dir = await getTemporaryDirectory();
    final speedDir = Directory('${dir.path}/speed_clips');
    if (!speedDir.existsSync()) speedDir.createSync(recursive: true);
    return '${speedDir.path}/$hash.mp4';
  }

  /// Drops the in-memory cache (e.g. when the editor closes) and deletes the
  /// derived speed files it owns. In-flight renders are generation-invalidated
  /// so a late native completion cleans itself up instead of repopulating disk.
  void clear() {
    _clearGeneration++;
    final cachedClips = _cache.values.toList();
    _cache.clear();
    _inFlight.clear();
    _deleteCachedFilesSync(cachedClips);
  }

  /// Seeds the cache directly so [buildSeamAwarePlayerClips] can be exercised
  /// without running the native render pipeline.
  @visibleForTesting
  void cacheForTest(DivineVideoClip clip, RenderedSpeedClip rendered) {
    _store(_key(clip), rendered);
  }
}
