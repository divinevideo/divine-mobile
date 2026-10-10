// ABOUTME: Rebuilds when the playhead reaches or leaves one of a layer's
// ABOUTME: keyframes, following the canvas play time live while scrubbing.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// Builds [builder] with whether the playhead is on one of [times], on the
/// editor timeline.
///
/// Follows [VideoEditorScope.playTimeNotifier], which the timeline drives
/// unthrottled while it is scrolled, rather than the main bloc's position,
/// which only catches up once the throttled seek lands; a keyframe marked from
/// that would light up only after the scroll stops. Rebuilds only when the
/// answer changes, not on every tick of the playhead.
class PlayheadOnKeyframeBuilder extends StatefulWidget {
  /// Creates a [PlayheadOnKeyframeBuilder].
  const PlayheadOnKeyframeBuilder({
    required this.times,
    required this.builder,
    super.key,
  });

  /// The keyframes' times on the editor timeline.
  final List<Duration> times;

  /// Builds the child with whether the playhead is on one of [times].
  final Widget Function(BuildContext context, bool isOnKeyframe) builder;

  @override
  State<PlayheadOnKeyframeBuilder> createState() =>
      _PlayheadOnKeyframeBuilderState();
}

class _PlayheadOnKeyframeBuilderState extends State<PlayheadOnKeyframeBuilder> {
  ValueListenable<Duration>? _playTime;
  bool _isOnKeyframe = false;

  bool _computeIsOnKeyframe() {
    final playTime = _playTime;
    if (playTime == null) return false;
    return widget.times.any(
      (time) =>
          (time - playTime.value).abs() <=
          VideoEditorConstants.keyframeTolerance,
    );
  }

  void _onPlayTimeChanged() {
    final isOnKeyframe = _computeIsOnKeyframe();
    if (isOnKeyframe != _isOnKeyframe) {
      setState(() => _isOnKeyframe = isOnKeyframe);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playTime = VideoEditorScope.of(context).playTimeNotifier;
    if (!identical(playTime, _playTime)) {
      _playTime?.removeListener(_onPlayTimeChanged);
      _playTime = playTime..addListener(_onPlayTimeChanged);
    }
    _isOnKeyframe = _computeIsOnKeyframe();
  }

  @override
  void didUpdateWidget(PlayheadOnKeyframeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.times, widget.times)) {
      _isOnKeyframe = _computeIsOnKeyframe();
    }
  }

  @override
  void dispose() {
    _playTime?.removeListener(_onPlayTimeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _isOnKeyframe);
}
