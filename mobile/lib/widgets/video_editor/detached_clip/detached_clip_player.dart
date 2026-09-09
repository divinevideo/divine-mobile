// ABOUTME: A detached clip's companion player and its playhead coupling,
// ABOUTME: owned outside the widget so a layer remount cannot restart it

import 'dart:async';
import 'dart:io';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:unified_logger/unified_logger.dart';

const _logName = 'DetachedClipPlayer';

/// Plays one detached clip alongside the timeline player and keeps it in step
/// with the editor playhead.
///
/// Deliberately not owned by a `State`: the editor's layer stack re-parents a
/// layer while it is dragged, which unmounts and remounts the widget about once
/// a second. A player tied to that lifetime is torn down and rebuilt just as
/// often — the layer blanks during each swap and the clip restarts from its
/// first frame.
class DetachedClipPlayer {
  DetachedClipPlayer._(this._controller, this._clip);

  /// Opens a player for [clip], or returns `null` when its file is unusable.
  static Future<DetachedClipPlayer?> open(DivineVideoClip clip) async {
    final video = clip.video;
    if (video == null) return null;

    final path = await video.safeFilePath();
    if (!File(path).existsSync()) {
      Log.warning(
        'Detached clip ${clip.id} file is gone ($path); showing its thumbnail',
        name: _logName,
        category: LogCategory.video,
      );
      return null;
    }

    final controller = DivineVideoPlayerController(
      useTexture: true,
      // Legacy surface, matching the canvas player. Two texture-backed players
      // run side by side here, and the SurfaceProducer backend shares an
      // ImageReader pool between them — which is how this player's frames
      // reached the canvas player's area. The legacy SurfaceTexture has no
      // shared pool.
      useLegacySurface: true,
      // A layer of the composition, not a video of its own: it has to run
      // alongside the timeline player instead of stopping it.
      exclusivePlayback: false,
      debugLabel: 'editor_detached_clip',
    );

    try {
      await controller.initialize();
      await controller.setSource(
        VideoClip.file(
          path,
          start: clip.trimStart,
          end: clip.trimStart + clip.trimmedDuration,
          volume: clip.volume,
          playbackSpeed: clip.playbackSpeed ?? 1.0,
        ),
      );
      return DetachedClipPlayer._(controller, clip);
    } catch (error, stackTrace) {
      Log.error(
        'Detached clip ${clip.id} failed to load; showing its thumbnail',
        name: _logName,
        error: error,
        stackTrace: stackTrace,
        category: LogCategory.video,
      );
      await controller.dispose();
      return null;
    }
  }

  /// A playhead tick further than this from the last one is a jump — a scrub,
  /// or the composition looping — rather than playback advancing.
  static const Duration _continuityWindow = Duration(milliseconds: 400);

  /// How close the companion has to already be for a seek to be skipped.
  ///
  /// Above the 200ms cadence the players report their position at, so an
  /// unavoidably stale sample does not read as a miss.
  static const Duration _seekTolerance = Duration(milliseconds: 150);

  /// How far the companion may slip during ordinary playback before it is put
  /// back.
  ///
  /// Deliberately loose. Ordinary playback is otherwise left alone — a seek
  /// stalls the decoder, and that stall is drift the next seek would react to —
  /// so this is the backstop for slip the companion cannot recover from on its
  /// own: the watchdog pausing it through a jank, a dropped seek, the clip
  /// sitting ended while the composition loops around again.
  static const Duration _driftTolerance = Duration(milliseconds: 500);

  /// Minimum gap between two seeks.
  ///
  /// A seek shows up in the reported position a frame or two later, so without
  /// this the next tick measures the pre-seek position and asks again.
  static const Duration _seekThrottle = Duration(milliseconds: 250);

  final DivineVideoPlayerController _controller;
  final DivineVideoClip _clip;

  ValueNotifier<Duration>? _playhead;
  ValueNotifier<bool>? _advancing;
  Duration _windowStart = Duration.zero;
  Duration? _windowEnd;
  Duration? _lastPlayTime;
  DateTime? _lastSeekAt;
  bool _isPlaying = false;

  /// The controller to hand to a `DivineVideoPlayer`.
  DivineVideoPlayerController get controller => _controller;

  /// The clip being played.
  DivineVideoClip get clip => _clip;

  /// Follows [playhead] across the layer's own [windowStart]/[windowEnd].
  ///
  /// [advancing] says whether the editor is playing, rather than leaving the
  /// companion to infer it from the gaps between ticks. A scrub moves the
  /// playhead with it `false`, and the companion follows the finger without
  /// running on past the release.
  ///
  /// The clip plays once through its window and is parked outside it: the
  /// composition is usually longer than the clip, and without a window the
  /// companion spent that surplus sitting at `state=ended` while playback was
  /// still being requested.
  ///
  /// Idempotent for an unchanged window: a remount re-following the same
  /// notifiers changes nothing and the clip keeps playing.
  void follow({
    required ValueNotifier<Duration>? playhead,
    ValueNotifier<bool>? advancing,
    Duration windowStart = Duration.zero,
    Duration? windowEnd,
  }) {
    final sameWindow = windowStart == _windowStart && windowEnd == _windowEnd;
    if (identical(playhead, _playhead) &&
        identical(advancing, _advancing) &&
        sameWindow) {
      return;
    }

    _windowStart = windowStart;
    _windowEnd = windowEnd;

    if (!identical(playhead, _playhead)) {
      _playhead?.removeListener(_onTick);
      _playhead = playhead;
      playhead?.addListener(_onTick);
    }
    if (!identical(advancing, _advancing)) {
      _advancing?.removeListener(_onAdvancingChanged);
      _advancing = advancing;
      advancing?.addListener(_onAdvancingChanged);
    }

    if (playhead == null) {
      // Nothing to follow — loop on its own so the canvas still shows motion.
      unawaited(_controller.setLooping(looping: true));
      unawaited(_play());
      return;
    }

    unawaited(_controller.setLooping(looping: false));
    // The window moved under a live follow, so the anchor is stale.
    if (!sameWindow) _lastPlayTime = null;
    _onTick();
  }

  /// Whether the playhead is inside the layer's window.
  ///
  /// The canvas asks before rendering the texture: outside the window the
  /// editor hides a layer with an opacity-0 compositing layer, which a platform
  /// texture is not reliably bound by, so the video has to be taken out of the
  /// tree rather than merely faded.
  bool isWithinWindow(Duration playTime) {
    if (playTime < _windowStart) return false;
    final end = _windowEnd;
    return end == null || playTime <= end;
  }

  /// Stops following the playhead. The player itself stays open.
  void detach() {
    _playhead?.removeListener(_onTick);
    _playhead = null;
    _advancing?.removeListener(_onAdvancingChanged);
    _advancing = null;
  }

  Future<void> dispose() async {
    detach();
    await _controller.dispose();
  }

  void _onTick() {
    final now = _playhead?.value;
    if (now == null) return;

    final previous = _lastPlayTime;
    _lastPlayTime = now;

    // Outside its window the clip has nothing to show. Parking it at its first
    // frame means the next entry starts clean instead of resuming wherever the
    // last pass stopped.
    if (!isWithinWindow(now)) {
      _setPlaying(playing: false);
      if (now < _windowStart) _syncTo(_windowStart, tolerance: _seekTolerance);
      return;
    }

    if (previous == null) {
      _syncTo(now, tolerance: _seekTolerance);
      return;
    }

    final delta = now - previous;
    // The notifier also fires without the value moving. Reading that as
    // "paused" and the next frame as "playing" is what made the companion
    // oscillate play/pause several times a second, each pause landing mid-seek.
    // A repeated value carries no news, so it changes nothing.
    if (delta == Duration.zero) return;

    // Backwards (the composition looped) or a long jump (a scrub) means the
    // companion is in the wrong place. Ordinary playback advances a frame at a
    // time and is left alone: re-seeking then stalls the decoder, and that
    // stall is what creates the drift triggering the next seek.
    if (delta.isNegative || delta > _continuityWindow) {
      _syncTo(now, tolerance: _seekTolerance);
      return;
    }

    _setPlaying(playing: _advancing?.value ?? true);
    _syncTo(now, tolerance: _driftTolerance);
  }

  /// Mirrors the editor's play/pause onto the companion.
  ///
  /// Resuming re-anchors first: the playhead may have been scrubbed while the
  /// editor was paused, and the companion followed those jumps under the tight
  /// tolerance — but a seek that lands within it leaves the two a frame or two
  /// apart, which playback would then keep.
  void _onAdvancingChanged() {
    final advancing = _advancing?.value ?? false;
    if (advancing) {
      final now = _playhead?.value;
      if (now != null && isWithinWindow(now)) {
        _syncTo(now, tolerance: _seekTolerance);
      }
    }
    _setPlaying(playing: advancing && _isWithinCurrentWindow);
  }

  /// Whether the playhead currently sits inside the layer's window.
  bool get _isWithinCurrentWindow {
    final now = _playhead?.value;
    return now != null && isWithinWindow(now);
  }

  /// Points the companion at the frame [now] calls for, unless it is close
  /// enough already.
  ///
  /// [tolerance] is how far off is worth a seek: tight for a jump the user just
  /// made, loose while playing, where correcting costs a decoder stall.
  ///
  /// Playing state is deliberately untouched: whether the editor is playing is
  /// decided by ticks arriving, not by where they land.
  void _syncTo(Duration now, {required Duration tolerance}) {
    final since = _lastSeekAt;
    if (since != null && DateTime.now().difference(since) < _seekThrottle) {
      return;
    }

    final target = detachedClipPlayerPosition(
      now,
      _clip,
      layerStart: _windowStart,
    );
    // Compared against where the player actually is, not against the last
    // position asked for. The two part company whenever a seek is dropped or
    // the clip runs to its end — and comparing requests to requests meant a
    // companion sitting on its last frame was judged already in place, so the
    // composition's next pass showed a frozen still instead of the clip.
    if (_absDiff(_controller.state.position, target) < tolerance) return;

    _lastSeekAt = DateTime.now();
    unawaited(_controller.seekTo(target));
  }

  static Duration _absDiff(Duration a, Duration b) => a > b ? a - b : b - a;

  void _setPlaying({required bool playing}) {
    if (playing == _isPlaying) return;
    _isPlaying = playing;
    unawaited(playing ? _play() : _controller.pause());
  }

  Future<void> _play() async {
    _isPlaying = true;
    await _controller.play();
  }
}

/// Where the companion player should be at editor-timeline position
/// [playTime], for a layer that starts at [layerStart].
///
/// In the player's own coordinates, which are neither the clip's source
/// timecodes nor the editor's: the companion is loaded as a single clip
/// trimmed to `[trimStart, trimStart + trimmedDuration]` and running at the
/// clip's speed, and both `seekTo` and the reported position count playback
/// time from that clip's own start. So the trim offset is already folded in
/// and the speed is applied on the far side — which makes this simply how long
/// the layer has been on screen.
///
/// Clamped to the clip's playback span at both ends: outside its window the
/// editor hides the layer anyway, and a companion parked on the last frame is
/// the right thing to reveal if it does not.
Duration detachedClipPlayerPosition(
  Duration playTime,
  DivineVideoClip clip, {
  Duration layerStart = Duration.zero,
}) {
  final elapsed = playTime - layerStart;
  if (elapsed.isNegative) return Duration.zero;
  final end = clip.playbackDuration;
  return elapsed > end ? end : elapsed;
}
