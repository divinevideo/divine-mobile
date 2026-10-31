// ABOUTME: Draws a question, Add yours or replies sticker on its white card, and
// ABOUTME: in the player who joined or replied, live, over the same card.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/poll_sticker_card.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// One of the latest answers or replies an Add yours or replies sticker
/// shows: its creator's avatar and its thumbnail.
class StickerResponsePreview extends Equatable {
  const StickerResponsePreview({
    this.avatarUrl,
    this.thumbnailUrl,
    this.isBlurred = false,
  });

  /// The avatar of whoever posted it, or `null` while there is none.
  final String? avatarUrl;

  /// Its thumbnail, or `null` when it has none.
  final String? thumbnailUrl;

  /// Whether it carries a content warning, which shows its thumbnail only
  /// blurred.
  final bool isBlurred;

  @override
  List<Object?> get props => [avatarUrl, thumbnailUrl, isBlurred];
}

/// Who joined an Add yours or replied to a video, as its sticker shows it in
/// the player: how many, and the latest ones first.
class StickerResponses extends Equatable {
  const StickerResponses({this.count = 0, this.latest = const []});

  /// How many there are in all.
  final int count;

  /// The latest ones, the newest first.
  final List<StickerResponsePreview> latest;

  @override
  List<Object?> get props => [count, latest];
}

/// The most avatars an interactive card shows.
const int maxStickerAvatars = 3;

/// The size of an avatar on a replies sticker.
const double _avatarSize = 72;

/// The size of an avatar on an Add yours, smaller to leave room for the
/// count beside its button.
const double _compactAvatarSize = 60;

/// How wide a replies sticker's thumbnail is, upright like a video.
const double _thumbnailWidth = 180;

/// How tall a replies sticker's thumbnail is.
const double _thumbnailHeight = 240;

/// How long a replies sticker shows each of the latest thumbnails in turn.
const Duration repliesThumbnailInterval = Duration(seconds: 2);

/// A question, Add yours or replies sticker on the white card every
/// interactive sticker is drawn on.
///
/// In the frames it shows no one's avatar and no number, which would freeze
/// at posting; the player lays it over them again [overFrames] with the
/// [responses] once they are in. A question takes an answer through
/// [onAnswer], an Add yours through [onJoin] and shows who joined through
/// [onOpenResponses], and a replies sticker opens them through
/// [onOpenResponses]; without, the card takes no tap.
class InteractiveStickerCard extends StatelessWidget {
  const InteractiveStickerCard({
    required this.data,
    this.overFrames = false,
    this.responses,
    this.onAnswer,
    this.onJoin,
    this.onOpenResponses,
    super.key,
  });

  final SocialStickerData data;

  /// Whether the card is drawn again over itself in a video's frames.
  final bool overFrames;

  /// Who joined or replied, or `null` to show no one.
  final StickerResponses? responses;

  /// Opens the answer to a question.
  final VoidCallback? onAnswer;

  /// Opens the camera to answer an Add yours.
  final VoidCallback? onJoin;

  /// Opens who joined an Add yours or the replies.
  final VoidCallback? onOpenResponses;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: interactiveCardColor,
        borderRadius: BorderRadius.circular(pollCardRadius),
        boxShadow: overFrames
            ? null
            : const [
                BoxShadow(
                  color: VineTheme.scrim15,
                  blurRadius: 40,
                  offset: Offset(0, 12),
                ),
              ],
      ),
      child: Padding(
        padding: const .all(pollCardPadding),
        child: SizedBox(
          width: pollCardContentWidth,
          child: switch (data.kind) {
            SocialStickerKind.question => _Question(
              data: data,
              onAnswer: onAnswer,
            ),
            SocialStickerKind.addYours => _AddYours(
              data: data,
              responses: responses,
              onJoin: onJoin,
              onOpenResponses: onOpenResponses,
            ),
            _ => _Replies(
              data: data,
              responses: responses,
              onOpen: onOpenResponses,
            ),
          },
        ),
      ),
    );
  }
}

/// A sharp copy of a question, Add yours or replies sticker, filling the box
/// the same sticker takes in a video's frames, to be laid over it there.
///
/// Its card is drawn at that box, hiding the sticker beneath, and the rest is
/// scaled to fit inside in proportion, like a poll's copy; see
/// [PollStickerCopy]. The player passes who joined or replied and takes taps
/// through the same arguments as [InteractiveStickerCard].
class InteractiveStickerCopy extends StatelessWidget {
  const InteractiveStickerCopy({
    required this.data,
    this.responses,
    this.onAnswer,
    this.onJoin,
    this.onOpenResponses,
    super.key,
  });

  final SocialStickerData data;
  final StickerResponses? responses;
  final VoidCallback? onAnswer;
  final VoidCallback? onJoin;
  final VoidCallback? onOpenResponses;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const InteractiveCardPainter(),
      child: FittedBox(
        child: InteractiveStickerCard(
          data: data,
          overFrames: true,
          responses: responses,
          onAnswer: onAnswer,
          onJoin: onJoin,
          onOpenResponses: onOpenResponses,
        ),
      ),
    );
  }
}

/// A question over the field a viewer taps to answer it.
class _Question extends StatelessWidget {
  const _Question({required this.data, required this.onAnswer});

  final SocialStickerData data;
  final VoidCallback? onAnswer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final field = SizedBox(
      height: interactiveCardRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: interactiveCardInk.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(interactiveCardRowHeight / 2),
        ),
        child: Center(
          child: StickerTextLine(
            text: l10n.videoStickerQuestionAnswerHint,
            style: interactiveCardTextStyle(
              42,
            ).copyWith(color: interactiveCardInk.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
    final onAnswer = this.onAnswer;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 28,
      children: [
        StickerTextLine(
          text: data.prompt ?? '',
          style: interactiveCardTextStyle(54),
          maxLines: 2,
          textAlign: .center,
        ),
        if (onAnswer == null)
          field
        else
          Semantics(
            button: true,
            label: l10n.videoStickerQuestionAnswerSemanticLabel(
              data.prompt ?? '',
            ),
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAnswer,
              child: field,
            ),
          ),
      ],
    );
  }
}

/// An Add yours: its prompt and hashtag over who joined and the button that
/// joins.
class _AddYours extends StatelessWidget {
  const _AddYours({
    required this.data,
    required this.responses,
    required this.onJoin,
    required this.onOpenResponses,
  });

  final SocialStickerData data;
  final StickerResponses? responses;
  final VoidCallback? onJoin;
  final VoidCallback? onOpenResponses;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responses = this.responses;
    final latest = responses?.latest ?? const <StickerResponsePreview>[];
    final joined = SizedBox(
      height: interactiveCardRowHeight,
      child: Row(
        spacing: 14,
        children: [
          // Nobody yet leaves the room to "Be the first".
          if (latest.isNotEmpty)
            _Avatars(responses: latest, size: _compactAvatarSize),
          Expanded(
            child: responses == null
                ? const SizedBox.shrink()
                : StickerTextLine(
                    text: l10n.videoStickerAddYoursJoined(responses.count),
                    style: interactiveCardTextStyle(34),
                  ),
          ),
        ],
      ),
    );
    final button = SizedBox(
      height: interactiveCardRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.vineGreen,
          borderRadius: BorderRadius.circular(interactiveCardRowHeight / 2),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 32),
          child: Center(
            child: StickerTextLine(
              text: l10n.videoStickerAddYoursButton,
              style: interactiveCardTextStyle(
                42,
              ).copyWith(color: interactiveCardColor),
            ),
          ),
        ),
      ),
    );
    final onJoin = this.onJoin;
    final onOpenResponses = this.onOpenResponses;
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        StickerTextLine(
          text: data.prompt ?? '',
          style: interactiveCardTextStyle(54),
          maxLines: 2,
          textAlign: .center,
        ),
        StickerTextLine(
          text: '#${data.hashtag ?? ''}',
          style: interactiveCardTextStyle(
            36,
          ).copyWith(color: interactiveCardInk.withValues(alpha: 0.6)),
          textAlign: .center,
        ),
        const SizedBox(height: 8),
        Row(
          spacing: 20,
          children: [
            Expanded(
              child: onOpenResponses == null
                  ? joined
                  : Semantics(
                      button: true,
                      label: l10n.videoStickerAddYoursOpenSemanticLabel,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpenResponses,
                        child: ExcludeSemantics(child: joined),
                      ),
                    ),
            ),
            if (onJoin == null)
              button
            else
              Semantics(
                button: true,
                label: l10n.videoStickerAddYoursJoinSemanticLabel(
                  data.prompt ?? '',
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onJoin,
                  child: ExcludeSemantics(child: button),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A replies sticker: the latest reply's thumbnail beside its title, who
/// replied and how many did.
class _Replies extends StatelessWidget {
  const _Replies({
    required this.data,
    required this.responses,
    required this.onOpen,
  });

  final SocialStickerData data;
  final StickerResponses? responses;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final responses = this.responses;
    final card = Row(
      spacing: 32,
      children: [
        _CyclingThumbnail(responses: responses?.latest ?? const []),
        Expanded(
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            spacing: 24,
            children: [
              StickerTextLine(
                text: data.prompt ?? '',
                style: interactiveCardTextStyle(50),
                maxLines: 2,
              ),
              SizedBox(
                height: _avatarSize,
                child: Row(
                  spacing: 16,
                  children: [
                    if (responses?.latest.isNotEmpty ?? false)
                      _Avatars(responses: responses!.latest, size: _avatarSize),
                    Expanded(
                      child: responses == null
                          ? const SizedBox.shrink()
                          : StickerTextLine(
                              text: l10n.videoStickerRepliesCount(
                                responses.count,
                              ),
                              style: interactiveCardTextStyle(34),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final onOpen = this.onOpen;
    if (onOpen == null) return card;
    return Semantics(
      button: true,
      label: l10n.videoStickerRepliesSemanticLabel(responses?.count ?? 0),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: card,
      ),
    );
  }
}

/// The avatars of the latest [responses], each [size] across and a third
/// over the one before, in a box as wide as [maxStickerAvatars] take, so the
/// card is laid out the same however many there are.
class _Avatars extends StatelessWidget {
  const _Avatars({required this.responses, required this.size});

  final List<StickerResponsePreview> responses;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = responses.take(maxStickerAvatars).toList();
    final step = size * 2 / 3;
    return SizedBox(
      width: size + (maxStickerAvatars - 1) * step,
      height: size,
      child: Stack(
        children: [
          for (final (index, response) in shown.indexed.toList().reversed)
            Positioned(
              left: index * step,
              child: _Avatar(url: response.avatarUrl, size: size),
            ),
        ],
      ),
    );
  }
}

/// One round avatar with a white ring, pale green while it has no picture.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    const fallback = ColoredBox(
      color: VineTheme.vineGreenLight,
      child: SizedBox.expand(),
    );
    return Container(
      width: size,
      height: size,
      padding: const .all(4),
      decoration: const BoxDecoration(
        color: interactiveCardColor,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: url == null
            ? fallback
            : VineCachedImage(
                imageUrl: url,
                fadeInDuration: Duration.zero,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// The thumbnails of the latest [responses] one after another, each for
/// [repliesThumbnailInterval]; the newest one held still when the viewer
/// asked for less motion, and a pale frame while there is none.
class _CyclingThumbnail extends StatefulWidget {
  const _CyclingThumbnail({required this.responses});

  final List<StickerResponsePreview> responses;

  @override
  State<_CyclingThumbnail> createState() => _CyclingThumbnailState();
}

class _CyclingThumbnailState extends State<_CyclingThumbnail> {
  Timer? _timer;
  int _index = 0;

  List<StickerResponsePreview> get _withThumbnail => [
    for (final response in widget.responses)
      if (response.thumbnailUrl != null) response,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restart();
  }

  @override
  void didUpdateWidget(_CyclingThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.responses != widget.responses) {
      _index = 0;
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion || _withThumbnail.length < 2) return;
    _timer = Timer.periodic(repliesThumbnailInterval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _withThumbnail.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _withThumbnail;
    final response = shown.isEmpty ? null : shown[_index % shown.length];
    final placeholder = ColoredBox(
      color: interactiveCardInk.withValues(alpha: 0.08),
      child: Center(
        child: DivineIcon(
          icon: .play,
          size: 72,
          color: interactiveCardInk.withValues(alpha: 0.4),
        ),
      ),
    );
    final url = response?.thumbnailUrl;
    Widget picture = url == null
        ? placeholder
        : VineCachedImage(
            imageUrl: url,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
    if (response?.isBlurred ?? false) {
      picture = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: picture,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: _thumbnailWidth,
        height: _thumbnailHeight,
        child: picture,
      ),
    );
  }
}
