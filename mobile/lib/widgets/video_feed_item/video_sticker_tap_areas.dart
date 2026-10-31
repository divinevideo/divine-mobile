// ABOUTME: A playing video's tappable stickers (link, mention, sound, place,
// ABOUTME: countdown, reply, poll and the like), drawn sharp over its frames.

import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, DivineVideoPlayerState;
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show VideoEvent, VideoStickerKind, VideoStickerRegion;
import 'package:openvine/blocs/countdown_reminder/countdown_reminder_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/map_search_launcher.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_navigation.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/video_feed_item/countdown_sticker_reminder.dart';
import 'package:openvine/widgets/video_feed_item/link_sticker_sheet.dart';
import 'package:openvine/widgets/video_feed_item/poll_sticker_overlay.dart';
import 'package:unified_logger/unified_logger.dart';

/// Opens what a tapped sticker on [video] points to; replaced in tests.
typedef VideoStickerOpener = void Function(
  BuildContext context,
  VideoStickerRegion region,
  VideoEvent video,
);

/// Opens what [region] on [video] points to: a profile, a hashtag's feed, a
/// sound, a link through [openVideoLink], a place in a map app, or what the
/// video replies to; a countdown sets or removes a reminder instead. A poll,
/// quiz or slider takes votes on its answers instead; see
/// [PollStickerOverlay].
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
    case VideoStickerKind.place:
      runDetached(
        openMapSearch(region.target),
        'open the place of a location sticker',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
    case VideoStickerKind.countdown:
      final l10n = context.l10n;
      runDetached(
        context.read<CountdownReminderCubit>().reminderToggled(
          video: video,
          region: region,
          title: region.label ?? l10n.videoEditorSocialStickerCountdown,
          body: l10n.videoStickerCountdownReminderBody,
        ),
        'set the reminder of a countdown sticker',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
    case VideoStickerKind.reply:
      // The video's own reply tags name the video the thread hangs on. A
      // reply to a comment opens that thread, with the comment in it.
      final rootId = video.replyRootRouteId;
      final repliesToComment =
          rootId != null && region.target != video.replyRootEventId;
      runDetached(
        context.pushWithVideoPause<void>(
          VideoDetailScreen.pathForId(rootId ?? region.target),
          extra: VideoDetailRouteExtra(
            autoOpenComments: repliesToComment,
            focusCommentId: repliesToComment ? region.target : null,
          ),
        ),
        'open what a reply sticker replies to',
        logName: 'VideoStickerTapAreas',
        category: LogCategory.ui,
      );
    case VideoStickerKind.poll ||
        VideoStickerKind.quiz ||
        VideoStickerKind.slider:
      // Voted on through its answers, never opened as a whole.
      break;
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
///
/// A poll, quiz or slider takes votes on its answers, which keep the pointer
/// from the player, and reads its poll only once the video [isActive];
/// [onVoteStarted] tells the feed a viewer started to vote.
class VideoStickerTapAreas extends StatefulWidget {
  const VideoStickerTapAreas({
    required this.video,
    required this.controller,
    this.shouldPortraitExpand = true,
    this.onOpen = openVideoSticker,
    this.canSetReminders = !kIsWeb,
    this.isActive = true,
    this.onVoteStarted,
    super.key,
  });

  final VideoEvent video;
  final DivineVideoPlayerController controller;

  /// Whether the feed fills its box with a video that is not square.
  final bool shouldPortraitExpand;

  /// Opens a tapped sticker.
  final VideoStickerOpener onOpen;

  /// Whether a tap on a countdown can set a reminder, which the web cannot;
  /// without, a countdown is drawn with its time left and is no button.
  final bool canSetReminders;

  /// Whether the video is the one the feed plays, whose polls are read.
  final bool isActive;

  /// Called when a viewer starts to vote on a poll, quiz or slider.
  final VoidCallback? onVoteStarted;

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
    _loadEmojiFont();
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

  /// Loads the sticker emoji font when a sticker's emoji are all its text
  /// needs beyond the sticker font, and draws the stickers again once it is
  /// in; until then a see-through one shows only as it is in the frames, and
  /// a solid one draws its emoji in the phone's own font.
  void _loadEmojiFont() {
    if (stickerEmojiFontLoaded) return;
    final hasEmoji = widget.video.stickerRegions.any(
      (region) => SocialStickerData.ofRegion(region)?.hasEmoji ?? false,
    );
    if (!hasEmoji) return;
    runDetached(
      loadStickerEmojiFont().then((loaded) {
        if (loaded && mounted) setState(() {});
      }),
      'load the sticker emoji font',
      logName: 'VideoStickerTapAreas',
      category: LogCategory.video,
    );
  }

  /// Whether a tap on [region] has somewhere to go: a sound sticker that
  /// names no sound of its own needs the video's audio reference, which a
  /// video whose sound was not published for reuse goes without; a poll,
  /// quiz or slider needs its poll's id, and a look its copy is drawn in.
  bool _opensSomething(VideoStickerRegion region) => switch (region.kind) {
    VideoStickerKind.sound =>
      region.target.isNotEmpty || widget.video.audioEventId != null,
    VideoStickerKind.poll || VideoStickerKind.quiz || VideoStickerKind.slider =>
      region.target.isNotEmpty && SocialStickerData.ofRegion(region) != null,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty || _aspectRatio <= 0) return const SizedBox.shrink();
    final areas = LayoutBuilder(
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
                if (region.kind.isPoll)
                  _PollStickerArea(
                    region: region,
                    frame: frame,
                    video: widget.video,
                    isActive: widget.isActive,
                    onVoteStarted: widget.onVoteStarted,
                  )
                else
                  _StickerTapArea(
                    region: region,
                    frame: frame,
                    onTap:
                        region.kind == VideoStickerKind.countdown &&
                            !widget.canSetReminders
                        ? null
                        : () => widget.onOpen(context, region, widget.video),
                  ),
            ],
          ),
        );
      },
    );
    // A tap on a countdown sets its reminder through the scope's cubit.
    return widget.canSetReminders &&
            _shown.any((region) => region.kind == VideoStickerKind.countdown)
        ? CountdownReminderScope(child: areas)
        : areas;
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

  /// Opens the sticker; without, it is only drawn.
  final VoidCallback? onTap;

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
            if (sticker != null &&
                sticker.canBeRedrawn(emojiFontLoaded: stickerEmojiFontLoaded))
              // Laid over the sticker in the frames at its exact size, in the
              // parts that cover that one; the button below names it, and
              // only the button takes the pointer.
              IgnorePointer(
                child: ExcludeSemantics(
                  child: SizedBox.fromSize(
                    size: stickerSize,
                    child: sticker.kind == SocialStickerKind.countdown
                        ? _LiveCountdown(data: sticker)
                        : SocialStickerCopy(data: sticker),
                  ),
                ),
              ),
            if (onTap != null)
              Semantics(
                button: true,
                label: _label(context),
                child: GestureDetector(
                  // Translucent and empty, so the player beneath still sees
                  // the pointer: its double tap likes, its long press peeks.
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
    VideoStickerKind.place => context.l10n.videoStickerPlaceSemanticLabel(
      region.label ?? region.target,
    ),
    VideoStickerKind.countdown =>
      context.l10n.videoStickerCountdownSemanticLabel,
    VideoStickerKind.reply => context.l10n.videoStickerReplySemanticLabel,
    // Drawn by _PollStickerArea, whose answers name themselves.
    VideoStickerKind.poll ||
    VideoStickerKind.quiz ||
    VideoStickerKind.slider => region.labelLines.firstOrNull ?? '',
  };
}

/// A poll, quiz or slider drawn over its area, turned with it, at its exact
/// size: its answers are its buttons, and they have to lie on the answers in
/// the frames.
class _PollStickerArea extends StatelessWidget {
  const _PollStickerArea({
    required this.region,
    required this.frame,
    required this.video,
    required this.isActive,
    required this.onVoteStarted,
  });

  final VideoStickerRegion region;
  final Rect frame;
  final VideoEvent video;
  final bool isActive;
  final VoidCallback? onVoteStarted;

  @override
  Widget build(BuildContext context) {
    final data = SocialStickerData.ofRegion(region);
    if (data == null) return const SizedBox.shrink();
    final width = region.width * frame.width;
    final height = region.height * frame.height;
    return Positioned(
      left: frame.left + region.centerX * frame.width - width / 2,
      top: frame.top + region.centerY * frame.height - height / 2,
      width: width,
      height: height,
      child: Transform.rotate(
        angle: region.rotation,
        child: PollStickerOverlay(
          region: region,
          video: video,
          data: data,
          isActive: isActive,
          onInteraction: onVoteStarted,
        ),
      ),
    );
  }
}

/// A countdown drawn over itself in the frames with the time left in place
/// of its date, ticking every second until it ends; then its date again.
class _LiveCountdown extends StatefulWidget {
  const _LiveCountdown({required this.data});

  final SocialStickerData data;

  @override
  State<_LiveCountdown> createState() => _LiveCountdownState();
}

class _LiveCountdownState extends State<_LiveCountdown> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    setState(() {});
    if (!_left.isNegative) return;
    // Over: the date stays as it is from here on.
    _ticker?.cancel();
    _ticker = null;
  }

  Duration get _left =>
      (widget.data.countdownEnd ?? clock.now()).difference(clock.now());

  @override
  Widget build(BuildContext context) {
    final left = _left;
    return SocialStickerCopy(
      data: widget.data.copyWith(
        localeName: Localizations.localeOf(context).toString(),
        use24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      ),
      countdownValue: left > Duration.zero
          ? countdownTimeLeft(context.l10n, left)
          : null,
    );
  }
}
