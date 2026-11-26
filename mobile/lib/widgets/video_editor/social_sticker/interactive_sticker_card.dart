// ABOUTME: Draws a question, Add yours or replies sticker on its white card, and
// ABOUTME: in the player who joined or replied, live, over the same card.

import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_text_scope.dart';
import 'package:openvine/widgets/video_editor/social_sticker/poll_sticker_card.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// One of the latest answers or replies an Add yours or replies sticker
/// shows: its creator's avatar and its thumbnail.
class StickerResponsePreview extends Equatable {
  const StickerResponsePreview({
    this.avatarUrl,
    this.avatarColor,
    this.thumbnailUrl,
    this.isBlurred = false,
  });

  /// The avatar of whoever posted it, or `null` while there is none.
  final String? avatarUrl;

  /// The color its avatar shows while it has no picture, or `null` for the
  /// card's pale green.
  final Color? avatarColor;

  /// Its thumbnail, or `null` when it has none.
  final String? thumbnailUrl;

  /// Whether it carries a content warning, which shows its thumbnail only
  /// blurred.
  final bool isBlurred;

  @override
  List<Object?> get props => [avatarUrl, avatarColor, thumbnailUrl, isBlurred];
}

/// Who joined an Add yours or replied to a video, as its sticker shows it in
/// the player: how many, and the latest ones first.
class StickerResponses extends Equatable {
  const StickerResponses({
    this.count = 0,
    this.countIsAtLeast = false,
    this.latest = const [],
  });

  /// How many there are in all.
  final int count;

  /// Whether [count] is only a floor, shown as `500+`: there may be more.
  final bool countIsAtLeast;

  /// The latest ones, the newest first.
  final List<StickerResponsePreview> latest;

  /// [count] as the card writes it: `500+` when it is only a floor.
  String get countAtLeastLabel => '$count+';

  @override
  List<Object?> get props => [count, countIsAtLeast, latest];
}

/// The most avatars an interactive card shows.
const int maxStickerAvatars = 3;

/// Who joined or replied in the editor's previews of an Add yours or replies
/// sticker, which show it as viewers will see it once people answer: as
/// many as the card shows avatars, each in its own color.
const StickerResponses sampleStickerResponses = StickerResponses(
  count: maxStickerAvatars,
  latest: [
    StickerResponsePreview(avatarColor: VineTheme.accentPink),
    StickerResponsePreview(avatarColor: VineTheme.accentBlue),
    StickerResponsePreview(avatarColor: VineTheme.accentYellow),
  ],
);

/// The size of an avatar on a replies sticker.
const double _avatarSize = 72;

/// The size of an avatar on an Add yours, smaller to leave room for the
/// count under them in the row beside its button.
const double _compactAvatarSize = 60;

/// How wide a replies sticker's thumbnail is, upright like a video.
const double _thumbnailWidth = 180;

/// How tall a replies sticker's thumbnail is.
const double _thumbnailHeight = 240;

/// How long a replies sticker shows each of the latest thumbnails in turn.
const Duration repliesThumbnailInterval = Duration(seconds: 3);

/// How long a replies sticker's next thumbnail takes to fade in over the one
/// before.
const Duration repliesThumbnailFade = Duration(milliseconds: 250);

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
    this.watchOnly = false,
    super.key,
  });

  final SocialStickerData data;

  /// Whether the card is drawn again over itself in a video's frames.
  final bool overFrames;

  /// Whether an Add yours is shown to a viewer who may not join it: in place
  /// of who joined and its button, it shows the latest answers and invites
  /// them to watch the series through [onOpenResponses].
  final bool watchOnly;

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
    // The player builds the card without the sticker view around it.
    return StickerTextScope(
      child: DecoratedBox(
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
              SocialStickerKind.addYours when watchOnly => _AddYoursSeries(
                data: data,
                responses: responses,
                onOpen: onOpenResponses,
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
    this.watchOnly = false,
    super.key,
  });

  final SocialStickerData data;
  final StickerResponses? responses;
  final VoidCallback? onAnswer;
  final VoidCallback? onJoin;
  final VoidCallback? onOpenResponses;

  /// See [InteractiveStickerCard.watchOnly].
  final bool watchOnly;

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
          watchOnly: watchOnly,
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
            // excludeSemantics drops the detector's own tap action with it.
            onTap: onAnswer,
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
    // The count goes under the avatars, where it has all the room the button
    // leaves: beside them, most languages cut it short.
    final joined = SizedBox(
      height: interactiveCardRowHeight,
      child: Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .start,
        spacing: 8,
        children: [
          if (latest.isNotEmpty)
            _Avatars(responses: latest, size: _compactAvatarSize),
          if (responses != null)
            // A count longer still is made smaller rather than cut short.
            FittedBox(
              fit: .scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: StickerTextLine(
                text: responses.countIsAtLeast
                    ? l10n.videoStickerAddYoursJoinedAtLeast(
                        responses.countAtLeastLabel,
                      )
                    : l10n.videoStickerAddYoursJoined(responses.count),
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

/// How many answers' thumbnails an Add yours shows to a viewer who may not
/// join it.
const int _seriesThumbnails = 3;

/// How tall each of those thumbnails is: what is left of the card the
/// viewer who may join sees once the prompt and the invitation to watch take
/// theirs, so both are the same size and fill the same box.
const double _seriesThumbnailHeight = 123;

/// How wide each of them is, upright like a video.
const double _seriesThumbnailWidth = _seriesThumbnailHeight * 3 / 4;

/// An Add yours shown to a viewer who may not join it: its prompt over the
/// latest answers' thumbnails and an invitation to watch the series, which
/// [onOpen] opens. Its hashtag is left out to give the thumbnails room.
class _AddYoursSeries extends StatelessWidget {
  const _AddYoursSeries({
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
    final shown = (responses?.latest ?? const <StickerResponsePreview>[])
        .take(_seriesThumbnails)
        .toList();
    // The answers beyond the thumbnails, counted on the last one.
    final more = (responses?.count ?? 0) - shown.length + 1;
    final card = Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      spacing: 16,
      children: [
        StickerTextLine(
          text: data.prompt ?? '',
          style: interactiveCardTextStyle(54),
          maxLines: 2,
          textAlign: .center,
        ),
        Row(
          mainAxisAlignment: .center,
          spacing: 12,
          children: [
            for (final (index, response) in shown.indexed)
              _ResponseThumbnail(
                response: response,
                width: _seriesThumbnailWidth,
                height: _seriesThumbnailHeight,
                radius: 16,
                moreCount: index == shown.length - 1 && more > 1 ? more : null,
              ),
          ],
        ),
        // A longer translation is made smaller rather than cut short.
        FittedBox(
          fit: .scaleDown,
          child: Row(
            mainAxisSize: .min,
            spacing: 8,
            children: [
              const DivineIcon(
                icon: .play,
                size: 40,
                color: VineTheme.vineGreenDark,
              ),
              StickerTextLine(
                text: l10n.videoStickerAddYoursWatchSeries,
                style: interactiveCardTextStyle(40),
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
      label: l10n.videoStickerAddYoursWatchSeriesSemanticLabel(
        data.prompt ?? '',
      ),
      excludeSemantics: true,
      // excludeSemantics drops the detector's own tap action with it.
      onTap: onOpen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: card,
      ),
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
                              text: responses.countIsAtLeast
                                  ? l10n.videoStickerRepliesCountAtLeast(
                                      responses.countAtLeastLabel,
                                    )
                                  : l10n.videoStickerRepliesCount(
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
      label: responses != null && responses.countIsAtLeast
          ? l10n.videoStickerRepliesSemanticLabelAtLeast(
              responses.countAtLeastLabel,
            )
          : l10n.videoStickerRepliesSemanticLabel(responses?.count ?? 0),
      excludeSemantics: true,
      // excludeSemantics drops the detector's own tap action with it.
      onTap: onOpen,
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
              child: _Avatar(
                url: response.avatarUrl,
                color: response.avatarColor,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

/// One round avatar with a white ring, in [color] or pale green while it has
/// no picture.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.color, required this.size});

  final String? url;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    final fallback = ColoredBox(
      color: color ?? VineTheme.vineGreenLight,
      child: const SizedBox.expand(),
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
/// [repliesThumbnailInterval], and each fading in over the one before once
/// its picture is loaded, so the card never shows one half drawn; the newest
/// loaded held still when the viewer asked for less motion, and a pale frame
/// while none is loaded.
class _CyclingThumbnail extends StatefulWidget {
  const _CyclingThumbnail({required this.responses});

  final List<StickerResponsePreview> responses;

  @override
  State<_CyclingThumbnail> createState() => _CyclingThumbnailState();
}

class _CyclingThumbnailState extends State<_CyclingThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: repliesThumbnailFade,
    value: 1,
  )..addStatusListener(_onFadeStatus);

  Timer? _timer;
  bool _reduceMotion = false;

  /// The thumbnails asked for, loaded or not.
  final Set<String> _requested = {};

  /// The thumbnails whose picture is loaded.
  final Set<String> _loaded = {};

  /// The thumbnails whose picture could not be loaded.
  final Set<String> _failed = {};

  /// The response shown, or `null` for the pale frame.
  StickerResponsePreview? _current;

  /// The response, or the pale frame for `null`, [_current] fades in over.
  StickerResponsePreview? _previous;

  /// Whether [_current] is fading in over [_previous].
  bool _isFading = false;

  /// The responses with a thumbnail, newest first, each thumbnail once.
  List<StickerResponsePreview> get _withThumbnail {
    final urls = <String>{};
    return [
      for (final response in widget.responses)
        if (response.thumbnailUrl case final url? when urls.add(url)) response,
    ];
  }

  /// Those of [_withThumbnail] whose picture is loaded, newest first.
  List<StickerResponsePreview> get _ready => [
    for (final response in _withThumbnail)
      if (_loaded.contains(response.thumbnailUrl)) response,
  ];

  /// The newest of [_withThumbnail] whose picture is loaded, once none newer
  /// is still loading; `null` until then.
  StickerResponsePreview? get _newest {
    for (final response in _withThumbnail) {
      final url = response.thumbnailUrl!;
      if (_loaded.contains(url)) return response;
      if (!_failed.contains(url)) return null;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_CyclingThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.responses, widget.responses)) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  /// Loads the thumbnails not asked for yet, keeps the one shown while it is
  /// still among them, and cycles while there is more than one.
  void _sync() {
    final withThumbnail = _withThumbnail;
    StickerResponsePreview? latest(StickerResponsePreview? response) =>
        response == null
        ? null
        : withThumbnail
              .where((other) => other.thumbnailUrl == response.thumbnailUrl)
              .firstOrNull;
    final current = latest(_current);
    if (current == null && _current != null) {
      _fade.value = 1;
      _isFading = false;
      _previous = null;
    } else if (_isFading) {
      _previous = latest(_previous);
    }
    _current = current;
    for (final response in withThumbnail) {
      final url = response.thumbnailUrl!;
      if (_requested.add(url)) {
        unawaited(_load(url));
      }
    }
    if (_current == null || _reduceMotion) _showNewest();
    if (_reduceMotion || withThumbnail.length < 2) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(repliesThumbnailInterval, (_) => _next());
    }
  }

  Future<void> _load(String url) async {
    final loaded = await VineCachedImage.precache(context, url);
    if (!mounted) return;
    (loaded ? _loaded : _failed).add(url);
    if (_current == null || _reduceMotion) _showNewest();
  }

  /// Shows [_newest]: first, and held still for less motion.
  void _showNewest() {
    final newest = _newest;
    if (newest != null && newest.thumbnailUrl != _current?.thumbnailUrl) {
      _show(newest);
    }
  }

  /// Fades the loaded thumbnail after the one shown in over it.
  void _next() {
    if (!mounted || _isFading || _current == null) return;
    final ready = _ready;
    if (ready.length < 2) return;
    final at = ready.indexWhere(
      (response) => response.thumbnailUrl == _current?.thumbnailUrl,
    );
    _show(ready[(at + 1) % ready.length]);
  }

  void _show(StickerResponsePreview response) {
    setState(() {
      _previous = _current;
      _current = response;
      _isFading = !_reduceMotion;
    });
    if (_isFading) {
      _fade.forward(from: 0);
    } else {
      _fade.value = 1;
      _previous = null;
    }
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isFading || !mounted) return;
    setState(() {
      _isFading = false;
      _previous = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keyed by thumbnail, so the one fading in keeps its picture when the
    // next fades in over it in turn; the pale frame is the one for `null`.
    return Stack(
      children: [
        for (final (response, isIncoming) in [
          if (_isFading) (_previous, false),
          (_current, true),
        ])
          FadeTransition(
            key: ValueKey(response?.thumbnailUrl),
            opacity: isIncoming ? _fade : kAlwaysCompleteAnimation,
            child: _ResponseThumbnail(
              response: response,
              width: _thumbnailWidth,
              height: _thumbnailHeight,
              radius: 28,
            ),
          ),
      ],
    );
  }
}

/// The thumbnail of [response], blurred when it carries a content warning,
/// or a pale frame with a play mark while there is none; with [moreCount],
/// darkened under `+moreCount`, the answers it stands for.
class _ResponseThumbnail extends StatelessWidget {
  const _ResponseThumbnail({
    required this.response,
    required this.width,
    required this.height,
    required this.radius,
    this.moreCount,
  });

  final StickerResponsePreview? response;
  final double width;
  final double height;
  final double radius;
  final int? moreCount;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: interactiveCardInk.withValues(alpha: 0.08),
      child: Center(
        child: DivineIcon(
          icon: .play,
          size: width * 0.4,
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
    final moreCount = this.moreCount;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: moreCount == null
            ? picture
            : Stack(
                fit: .expand,
                children: [
                  picture,
                  const ColoredBox(color: VineTheme.scrim50),
                  Center(
                    child: StickerTextLine(
                      text: '+$moreCount',
                      style: interactiveCardTextStyle(
                        34,
                      ).copyWith(color: interactiveCardColor),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
