// ABOUTME: A playing video's link, mention, hashtag and sound stickers, drawn
// ABOUTME: sharp over its frames as buttons that open what each points to.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, DivineVideoPlayerState;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/video_feed_item/link_sticker_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens what a tapped sticker on [video] points to; replaced in tests.
typedef VideoStickerOpener = void Function(
  BuildContext context,
  VideoStickerRegion region,
  VideoEvent video,
);

/// Opens what [region] on [video] points to: a profile, a hashtag's feed, a
/// sound, or a link through [openVideoLink].
void openVideoSticker(
  BuildContext context,
  VideoStickerRegion region,
  VideoEvent video,
) {
  switch (region.kind) {
    case VideoStickerKind.link:
      runDetached(
        openVideoLink(context, region.target),
        'open a link sticker',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
    case VideoStickerKind.mention:
      LinkifiedTextNavigation.navigateToProfile(context, region.target);
    case VideoStickerKind.hashtag:
      LinkifiedTextNavigation.navigateToHashtagFeed(context, region.target);
    case VideoStickerKind.sound:
      final soundId = region.target.isNotEmpty
          ? region.target
          : video.audioEventId;
      if (soundId == null) return;
      runDetached(
        context.pushWithVideoPause(
          SoundDetailScreen.pathForId(soundId),
          extra: <String, dynamic>{'sourceVideo': video},
        ),
        'open the sound of a sound sticker',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
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

/// Each of [video]'s tappable stickers while it shows, drawn again where it
/// stands in the video's frames as the feed fits them, and made a button.
///
/// The frames carry the sticker at the video's resolution and compression;
/// drawn over them, it is as sharp as the app's own buttons. The buttons let
/// a tap anywhere else, and a double tap on them, reach the player beneath:
/// a single tap on a sticker opens it, a double tap still likes the video.
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

  /// The video's width over its height, `0` until the player knows it, which
  /// is when its frames show.
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
    final aspectRatio = state.aspectRatio;
    final shown = [
      for (final region in widget.video.stickerRegions)
        if (region.isShownAt(state.position) && _opensSomething(region)) region,
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

  /// Whether a tap on [region] has somewhere to go: a sound sticker that
  /// names no sound of its own needs the video's audio reference, which a
  /// video whose sound was not published for reuse goes without.
  bool _opensSomething(VideoStickerRegion region) =>
      region.kind != VideoStickerKind.sound ||
      region.target.isNotEmpty ||
      widget.video.audioEventId != null;

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
        // A sticker reaching past a contained video's edge is cut there in
        // the frames, so its copy and its button are cut there too.
        return ClipRect(
          clipper: _FrameClipper(frame),
          child: Stack(
            children: [
              for (final region in _shown)
                _StickerTapArea(
                  region: region,
                  frame: frame,
                  onTap: () => widget.onOpen(context, region, widget.video),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips to [frame], where the video shows.
class _FrameClipper extends CustomClipper<Rect> {
  const _FrameClipper(this.frame);

  final Rect frame;

  @override
  Rect getClip(Size size) => frame;

  @override
  bool shouldReclip(_FrameClipper oldClipper) => oldClipper.frame != frame;
}

/// One sticker drawn over its area, turned with it, and the button on it,
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
    final stickerSize = Size(
      region.width * frame.width,
      region.height * frame.height,
    );
    final width = math.max(stickerSize.width, kMinInteractiveDimension);
    final height = math.max(stickerSize.height, kMinInteractiveDimension);
    final sticker = SocialStickerData.ofRegion(region);
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: region.rotation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (sticker != null)
              // Laid over the sticker in the frames at its exact size, so it
              // covers that one; the button below names it, and only the
              // button takes the pointer.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: SizedBox.fromSize(
                    size: stickerSize,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: SocialStickerView(data: sticker),
                    ),
                  ),
                ),
              ),
            Semantics(
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
          ],
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
    VideoStickerKind.sound => context.l10n.videoStickerSoundSemanticLabel,
  };
}
