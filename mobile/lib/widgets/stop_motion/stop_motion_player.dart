// ABOUTME: Lightweight looping player for a stop-motion clip's captured stills
// ABOUTME: Renders frames directly, avoiding the short-mp4 loop oscillation

import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';

/// Plays a stop-motion clip by looping through its captured stills, holding
/// each for its own [StopMotionClipFrame.duration].
///
/// Used wherever a frames-based clip would otherwise be handed to the video
/// player. Rendering the frames directly avoids the stutter/oscillation a
/// looping video player exhibits on ultra-short (≈83ms) clips.
///
/// Two modes:
///
/// * **Autonomous** ([position] is `null`): runs its own [Ticker] and loops
///   continuously. Honors the platform reduce-motion setting — when animations
///   are disabled it holds the first frame statically. Used by standalone
///   previews (metadata / clip preview) that have no external timeline.
/// * **Controlled** ([position] is non-null): renders the frame at the supplied
///   composition [position] and never runs its own clock. The caller (the video
///   editor) drives the frame from its play/pause + timeline state, so playback
///   respects the playhead instead of free-running.
class StopMotionPlayer extends StatefulWidget {
  const StopMotionPlayer({
    required this.frames,
    this.fit = BoxFit.cover,
    this.position,
    this.cacheHeight,
    super.key,
  });

  /// The captured stills, in playback order.
  final List<StopMotionClipFrame> frames;

  /// How each frame is inscribed into the player's box.
  final BoxFit fit;

  /// When non-null, the player is *controlled*: it renders the frame at this
  /// composition position and does not run its own ticker. When `null` the
  /// player self-drives a continuous loop.
  ///
  /// The end of the sequence holds the last still rather than wrapping — the
  /// editor's playhead clamps to the composition total inclusive, so the total
  /// means "the end", not "the start of the next loop".
  final Duration? position;

  /// Optional decode height (physical pixels) for the stills. Captured frames
  /// are full camera resolution (multiple MB each decoded); decoding a whole
  /// sequence at that size thrashes the image cache and stutters playback.
  /// Callers displaying the player at a known size pass the target height so
  /// precache and display share one bounded decode.
  final int? cacheHeight;

  @override
  State<StopMotionPlayer> createState() => _StopMotionPlayerState();
}

class _StopMotionPlayerState extends State<StopMotionPlayer>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  final ValueNotifier<int> _frameIndex = ValueNotifier<int>(0);

  /// Cumulative end offset (microseconds) per frame, so the active frame for a
  /// given elapsed time is found with a single forward scan.
  late List<int> _cumulativeEndUs;
  late int _totalUs;
  bool _precached = false;

  bool get _isControlled => widget.position != null;

  @override
  void initState() {
    super.initState();
    _computeTimeline();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheFrames();
    _syncTicker();
  }

  @override
  void didUpdateWidget(StopMotionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.frames != widget.frames) {
      _computeTimeline();
      _frameIndex.value = 0;
    }
    // Re-run precache when the frames change or when only the decode height
    // changes — a cacheHeight-only change would otherwise leave the precache
    // at the previous decode size.
    if (oldWidget.frames != widget.frames ||
        oldWidget.cacheHeight != widget.cacheHeight) {
      _precached = false;
      _precacheFrames();
    }
    if (oldWidget.frames != widget.frames ||
        oldWidget.position != widget.position) {
      _syncTicker();
    }
  }

  void _computeTimeline() {
    var acc = 0;
    _cumulativeEndUs = [
      for (final frame in widget.frames) acc += frame.duration.inMicroseconds,
    ];
    _totalUs = acc;
  }

  void _precacheFrames() {
    if (_precached) return;
    _precached = true;
    for (final frame in widget.frames) {
      precacheImage(
        ResizeImage.resizeIfNeeded(
          null,
          widget.cacheHeight,
          FileImage(File(frame.path)),
        ),
        context,
      );
    }
  }

  void _syncTicker() {
    // Controlled mode renders the frame for the external position; the caller
    // owns the clock, so the internal ticker must stay off.
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final shouldAnimate =
        !_isControlled &&
        !reduceMotion &&
        widget.frames.length > 1 &&
        _totalUs > 0;

    if (shouldAnimate && _ticker == null) {
      _ticker = createTicker(_onTick)..start();
    } else if (!shouldAnimate && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
      _frameIndex.value = 0;
    }
  }

  void _onTick(Duration elapsed) {
    final index = _frameIndexForMicros(elapsed.inMicroseconds);
    if (index != _frameIndex.value) _frameIndex.value = index;
  }

  /// Maps an absolute microsecond offset (looping past [_totalUs]) to the index
  /// of the frame that is showing at that time.
  int _frameIndexForMicros(int micros) {
    if (_totalUs <= 0) return 0;
    final t = micros % _totalUs;
    var index = 0;
    while (index < _cumulativeEndUs.length - 1 &&
        t >= _cumulativeEndUs[index]) {
      index++;
    }
    return index;
  }

  /// Maps an externally driven [micros] to the frame showing at that time,
  /// holding the last still at the end rather than wrapping to the first.
  ///
  /// The controlled clock clamps to the composition total *inclusive*, and at
  /// exactly the total the loop modulo would land back on frame 0 — showing the
  /// first still while the timed layers sit at the end.
  int _controlledFrameIndexForMicros(int micros) {
    if (_totalUs <= 0) return 0;
    if (micros >= _totalUs) return widget.frames.length - 1;
    return _frameIndexForMicros(micros);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frameIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.frames.isEmpty) return const SizedBox.shrink();

    final position = widget.position;
    if (position != null) {
      return _StopMotionFrame(
        frame:
            widget.frames[_controlledFrameIndexForMicros(
              position.inMicroseconds,
            )],
        fit: widget.fit,
        cacheHeight: widget.cacheHeight,
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _frameIndex,
      builder: (context, index, _) => _StopMotionFrame(
        frame: widget.frames[index],
        fit: widget.fit,
        cacheHeight: widget.cacheHeight,
      ),
    );
  }
}

class _StopMotionFrame extends StatelessWidget {
  const _StopMotionFrame({
    required this.frame,
    required this.fit,
    this.cacheHeight,
  });

  final StopMotionClipFrame frame;
  final BoxFit fit;
  final int? cacheHeight;

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(frame.path),
      fit: fit,
      gaplessPlayback: true,
      cacheHeight: cacheHeight,
    );
  }
}
