// ABOUTME: Invisible buttons over a playing video's link, mention and hashtag
// ABOUTME: stickers, each opening what its sticker points to while it shows.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, DivineVideoPlayerState;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/external_link_launcher.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens what a tapped sticker points to; replaced in tests.
typedef VideoStickerOpener = void Function(
  BuildContext context,
  VideoStickerRegion region,
);

/// Opens what [region] points to: a link after the viewer has seen its
/// address (see [openExternalLink]), a profile, or a hashtag's feed.
void openVideoSticker(BuildContext context, VideoStickerRegion region) {
  switch (region.kind) {
    case VideoStickerKind.link:
      runDetached(
        openExternalLink(context, region.target),
        'open a link sticker',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
    case VideoStickerKind.mention:
      LinkifiedTextNavigation.navigateToProfile(context, region.target);
    case VideoStickerKind.hashtag:
      LinkifiedTextNavigation.navigateToHashtagFeed(context, region.target);
  }
}

/// The rect a video of [aspectRatio] fills in [box], the way the feed fits
/// it: covering the box, unless it is square or [shouldPortraitExpand] is
/// off, when it is contained in it.
Rect videoFrameRect(
  double aspectRatio,
  Size box, {
  required bool shouldPortraitExpand,
}) {
  // Allows the same float rounding of a square video the player allows.
  final covers = shouldPortraitExpand && (aspectRatio - 1).abs() >= 1e-6;
  // Covering, the frame is as tall as it must be to reach every side of the
  // box; contained, as tall as it may be to stay inside them.
  final height = covers
      ? math.max(box.width / aspectRatio, box.height)
      : math.min(box.width / aspectRatio, box.height);
  return Rect.fromCenter(
    center: box.center(Offset.zero),
    width: height * aspectRatio,
    height: height,
  );
}

/// A button over each of [video]'s tappable stickers while it shows, placed
/// where the sticker stands on the video as the feed fits it.
///
/// The buttons let a tap anywhere else, and a double tap on them, reach the
/// player beneath: a single tap on a sticker opens it, a double tap still
/// likes the video.
class VideoStickerTapAreas extends StatefulWidget {
  const VideoStickerTapAreas({
    required this.video,
    required this.controller,
    this.shouldPortraitExpand = true,
    this.onOpen = openVideoSticker,
    super.key,
  });

  final VideoEvent video;
  final DivineVideoPlayerController controller;

  /// Whether the feed fills its box with a video that is not square.
  final bool shouldPortraitExpand;

  /// Opens a tapped sticker.
  final VideoStickerOpener onOpen;

  @override
  State<VideoStickerTapAreas> createState() => _VideoStickerTapAreasState();
}

class _VideoStickerTapAreasState extends State<VideoStickerTapAreas> {
  StreamSubscription<DivineVideoPlayerState>? _subscription;

  /// The stickers showing at the player's position.
  List<VideoStickerRegion> _shown = const [];

  /// The video's width over its height, `0` until it is known.
  double _aspectRatio = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(VideoStickerTapAreas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.video.stickerRegions != widget.video.stickerRegions) {
      unawaited(_subscription?.cancel());
      _subscribe();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _subscribe() {
    _subscription = null;
    _update(widget.controller.state, rebuild: false);
    if (widget.video.stickerRegions.isEmpty) return;
    _subscription = widget.controller.stateStream.listen(_update);
  }

  void _update(DivineVideoPlayerState state, {bool rebuild = true}) {
    final aspectRatio = state.aspectRatio > 0
        ? state.aspectRatio
        : _fallbackAspectRatio;
    final shown = [
      for (final region in widget.video.stickerRegions)
        if (region.isShownAt(state.position)) region,
    ];
    if (aspectRatio == _aspectRatio && listEquals(shown, _shown)) return;
    if (!rebuild) {
      _aspectRatio = aspectRatio;
      _shown = shown;
      return;
    }
    if (!mounted) return;
    setState(() {
      _aspectRatio = aspectRatio;
      _shown = shown;
    });
  }

  /// The aspect ratio the video's dimensions name, before the player knows.
  double get _fallbackAspectRatio {
    final width = widget.video.width;
    final height = widget.video.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return 0;
    }
    return width / height;
  }

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty || _aspectRatio <= 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final frame = videoFrameRect(
          _aspectRatio,
          constraints.biggest,
          shouldPortraitExpand: widget.shouldPortraitExpand,
        );
        return Stack(
          children: [
            for (final region in _shown)
              _StickerTapArea(
                region: region,
                frame: frame,
                onTap: () => widget.onOpen(context, region),
              ),
          ],
        );
      },
    );
  }
}

/// The button over one sticker: the sticker's own area, turned with it and
/// grown to the smallest size a finger can hit.
class _StickerTapArea extends StatelessWidget {
  const _StickerTapArea({
    required this.region,
    required this.frame,
    required this.onTap,
  });

  final VideoStickerRegion region;
  final Rect frame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final center =
        frame.topLeft +
        Offset(region.centerX * frame.width, region.centerY * frame.height);
    final width = math.max(
      region.width * frame.width,
      kMinInteractiveDimension,
    );
    final height = math.max(
      region.height * frame.height,
      kMinInteractiveDimension,
    );
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: region.rotation,
        child: Semantics(
          button: true,
          label: _label(context),
          child: GestureDetector(
            // Translucent and empty, so the player beneath still sees the
            // pointer: its double tap likes, its long press peeks.
            behavior: HitTestBehavior.translucent,
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  String _label(BuildContext context) => switch (region.kind) {
    VideoStickerKind.link => context.l10n.videoStickerLinkSemanticLabel(
      region.target,
    ),
    VideoStickerKind.mention => context.l10n.videoStickerMentionSemanticLabel,
    VideoStickerKind.hashtag => context.l10n.videoStickerHashtagSemanticLabel(
      region.target,
    ),
  };
}
