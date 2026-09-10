// ABOUTME: Timeline for the subtitle editor — a ruler and the video's frames
// ABOUTME: under a fixed playhead, scrubbed by scrolling.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_timeline_thumbnails.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_rules_indicator.dart';

/// The video's timeline: a ruler and its frames.
///
/// Scrolling scrubs — the playhead is fixed at the centre and the film moves
/// under it, the same model the video editor uses. Cues are not drawn here;
/// they are timed with the sliders below, and this is what tells the creator
/// which frame they are timing against.
class SubtitleCueTimeline extends StatefulWidget {
  /// Creates the timeline.
  const SubtitleCueTimeline({
    required this.totalDuration,
    required this.playbackPosition,
    required this.thumbnails,
    required this.onScrubbed,
    super.key,
  });

  /// Length of the time axis.
  final Duration totalDuration;

  /// Where the player currently is; the timeline follows it while the user is
  /// not scrubbing.
  final ValueListenable<Duration> playbackPosition;

  /// Frames extracted for the filmstrip.
  final ValueListenable<List<TimelineFrame>> thumbnails;

  /// Called with the position the user scrubbed to.
  final ValueChanged<Duration> onScrubbed;

  @override
  State<SubtitleCueTimeline> createState() => _SubtitleCueTimelineState();
}

class _SubtitleCueTimelineState extends State<SubtitleCueTimeline> {
  /// Smallest scroll delta worth chasing when following playback. Below this
  /// the animation would fight the frame it was scheduled from.
  static const _followEpsilonPx = 1.0;

  /// Throttle for seeks emitted while scrubbing, in milliseconds.
  static const _seekThrottleMs = 16;

  final ScrollController _scrollController = ScrollController();

  double _pixelsPerSecond = TimelineConstants.pixelsPerSecond;

  /// Half the viewport, used as leading and trailing padding so the first and
  /// last frame can both reach the centred playhead.
  double _halfViewport = 0;

  bool _isUserScrolling = false;

  /// Active pointers, so a two-finger gesture becomes a pinch zoom.
  final Map<int, Offset> _pointers = {};
  double _pinchBaseDistance = 0;
  double _pinchBasePixelsPerSecond = 0;

  bool get _isPinching => _pointers.length >= 2;

  int _lastSeekMs = 0;

  @override
  void initState() {
    super.initState();
    widget.playbackPosition.addListener(_followPlayback);
  }

  @override
  void didUpdateWidget(SubtitleCueTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbackPosition != widget.playbackPosition) {
      oldWidget.playbackPosition.removeListener(_followPlayback);
      widget.playbackPosition.addListener(_followPlayback);
    }
  }

  @override
  void dispose() {
    widget.playbackPosition.removeListener(_followPlayback);
    _scrollController.dispose();
    super.dispose();
  }

  // -- Scroll ↔ position -----------------------------------------------------

  double _offsetFor(Duration position) =>
      position.inMilliseconds /
      Duration.millisecondsPerSecond *
      _pixelsPerSecond;

  Duration _positionFor(double offset) => Duration(
    milliseconds: (offset / _pixelsPerSecond * Duration.millisecondsPerSecond)
        .round()
        .clamp(0, widget.totalDuration.inMilliseconds),
  );

  /// Scrolls the film so the playing frame sits under the playhead.
  ///
  /// Suspended while the user drives the timeline themselves — otherwise the
  /// seek this scroll triggers would scroll again, and the two would chase
  /// each other.
  void _followPlayback() {
    if (_isUserScrolling || _isPinching) return;
    if (!_scrollController.hasClients) return;
    final target = _offsetFor(
      widget.playbackPosition.value,
    ).clamp(0.0, _scrollController.position.maxScrollExtent);
    if ((target - _scrollController.offset).abs() < _followEpsilonPx) return;
    _scrollController.jumpTo(target);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    final isDrag = switch (notification) {
      ScrollStartNotification(:final dragDetails) => dragDetails != null,
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (isDrag) _isUserScrolling = true;

    if (notification is ScrollUpdateNotification && _isUserScrolling) {
      _emitScrub();
    } else if (notification is ScrollEndNotification && _isUserScrolling) {
      _isUserScrolling = false;
      _emitScrub(force: true);
    }
    return false;
  }

  void _emitScrub({bool force = false}) {
    if (!_scrollController.hasClients) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - _lastSeekMs < _seekThrottleMs) return;
    _lastSeekMs = now;
    widget.onScrubbed(_positionFor(_scrollController.offset));
  }

  // -- Pinch zoom ------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2) return;
    _pinchBaseDistance = _pointerDistance();
    _pinchBasePixelsPerSecond = _pixelsPerSecond;
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length < 2 || _pinchBaseDistance <= 0) return;
    _applyPinch();
  }

  void _onPointerRelease(PointerEvent event) {
    final wasPinching = _isPinching;
    _pointers.remove(event.pointer);
    _pinchBaseDistance = 0;
    if (wasPinching && !_isPinching) setState(() {});
  }

  double _pointerDistance() {
    final positions = _pointers.values.toList();
    return (positions[0] - positions[1]).distance;
  }

  void _applyPinch() {
    final scale = _pointerDistance() / _pinchBaseDistance;
    final next = (_pinchBasePixelsPerSecond * scale).clamp(
      TimelineConstants.minPixelsPerSecond,
      TimelineConstants.maxPixelsPerSecond,
    );
    if (next == _pixelsPerSecond) return;

    // Anchor the zoom on the playhead so the frame under it stays put.
    final anchor = _scrollController.hasClients
        ? _positionFor(_scrollController.offset)
        : Duration.zero;
    setState(() => _pixelsPerSecond = next);

    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(
      _offsetFor(anchor).clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds =
        widget.totalDuration.inMilliseconds / Duration.millisecondsPerSecond;
    final totalWidth = totalSeconds * _pixelsPerSecond;

    return LayoutBuilder(
      builder: (context, constraints) {
        _halfViewport = constraints.maxWidth / 2;
        return SizedBox(
          height:
              TimelineConstants.rulerHeight +
              TimelineConstants.rulerToBodyGap +
              TimelineConstants.thumbnailStripHeight,
          child: Stack(
            children: [
              Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerRelease,
                onPointerCancel: _onPointerRelease,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: _isPinching
                        ? const NeverScrollableScrollPhysics()
                        : const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: _halfViewport),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoEditorTimelineRulesIndicator(
                          totalDuration: widget.totalDuration,
                          pixelsPerSecond: _pixelsPerSecond,
                          scrollController: _scrollController,
                          scrollPadding: _halfViewport,
                        ),
                        const SizedBox(
                          height: TimelineConstants.rulerToBodyGap,
                        ),
                        SubtitleTimelineThumbnails(
                          thumbnails: widget.thumbnails,
                          width: totalWidth,
                          totalDuration: widget.totalDuration,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const _Playhead(),
            ],
          ),
        );
      },
    );
  }
}

/// Thin vertical line pinned to the centre of the viewport.
class _Playhead extends StatelessWidget {
  const _Playhead();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        child: SizedBox(
          width: TimelineConstants.playheadWidth,
          height: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(color: context.vineColors.onSurface),
          ),
        ),
      ),
    );
  }
}
