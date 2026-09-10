import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';

/// Displays a single video item with a native video player.
///
/// When [controller] is `null` (the video has not been preloaded yet),
/// nothing is shown.
///
/// Uses [shouldPortraitExpand] to control how the video texture is inscribed
/// into the available space. Because a [Texture] widget has no intrinsic size,
/// this widget listens for video dimension updates from the controller
/// and sizes the texture explicitly so the [FittedBox] transform stays
/// finite.
class VideoItemWidget extends StatefulWidget {
  /// Creates a [VideoItemWidget].
  const VideoItemWidget({
    this.controller,
    this.shouldPortraitExpand = true,
    super.key,
  });

  /// The native video player controller, or `null` if the video
  /// has not been initialized yet.
  final DivineVideoPlayerController? controller;

  /// Controls how the video is fitted into its layout bounds.
  ///
  /// When `true`, non-square videos use [BoxFit.cover] while
  /// square (1:1) videos use [BoxFit.contain].
  /// When `false`, all videos use [BoxFit.contain].
  final bool shouldPortraitExpand;

  @override
  State<VideoItemWidget> createState() => _VideoItemWidgetState();
}

class _VideoItemWidgetState extends State<VideoItemWidget> {
  StreamSubscription<DivineVideoPlayerState>? _subscription;
  double _aspectRatio = 0;

  @override
  void initState() {
    super.initState();
    _subscribe(widget.controller);
  }

  @override
  void didUpdateWidget(VideoItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      unawaited(_subscription?.cancel());
      _subscribe(widget.controller);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribe(DivineVideoPlayerController? controller) {
    if (controller == null) {
      _aspectRatio = 0;
      return;
    }
    _aspectRatio = controller.state.aspectRatio;
    _subscription = controller.stateStream.listen((state) {
      final newRatio = state.aspectRatio;
      if (newRatio != _aspectRatio && newRatio > 0) {
        if (!mounted) return;
        setState(() => _aspectRatio = newRatio);
      }
    });
  }

  /// Resolves the [BoxFit] based on `widget.shouldPortraitExpand` and
  /// the actual video aspect ratio.
  BoxFit _resolveBoxFit() {
    if (!widget.shouldPortraitExpand) return BoxFit.contain;
    // Allow float32 rounding in Media3's pixel ratio for square videos.
    if ((_aspectRatio - 1.0).abs() < 1e-6) return BoxFit.contain;
    return BoxFit.cover;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller == null) return const SizedBox.shrink();

    final player = DivineVideoPlayer(controller: widget.controller);

    if (_aspectRatio <= 0) return player;

    return ClipRect(
      child: FittedBox(
        fit: _resolveBoxFit(),
        child: SizedBox(
          width: _aspectRatio * 100,
          height: 100,
          child: player,
        ),
      ),
    );
  }
}
