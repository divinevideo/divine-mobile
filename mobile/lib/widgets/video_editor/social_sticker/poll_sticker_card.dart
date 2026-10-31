// ABOUTME: Draws a poll, quiz or slider sticker: its question over its answers
// ABOUTME: or emoji scale, and in the player the votes over them.

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';

/// What the player shows over a poll, quiz or slider once its votes are in.
class PollStickerResults extends Equatable {
  const PollStickerResults({
    this.shares = const [],
    this.ownAnswer,
    this.rightAnswer,
    this.average,
  });

  /// The share of the votes each answer of a poll or a quiz has, from 0 to 1,
  /// in the order of the answers.
  final List<double> shares;

  /// The index of the answer the viewer picked.
  final int? ownAnswer;

  /// The index of a quiz's right answer.
  final int? rightAnswer;

  /// Where a slider stands on average, from 0 to 1, or `null` before anyone
  /// rated it.
  final double? average;

  @override
  List<Object?> get props => [shares, ownAnswer, rightAnswer, average];
}

/// How wide a poll card's content is laid out, whatever it says, so the copy
/// the player draws is the size of the card in the frames.
const double pollCardContentWidth = 640;

/// The space around a poll card's content.
const double pollCardPadding = 40;

/// The radius of a poll card's corners.
const double pollCardRadius = 56;

/// How round a poll card's corners are, as a share of its width.
const double pollCardRoundness =
    pollCardRadius / (pollCardContentWidth + 2 * pollCardPadding);

/// The card every poll, quiz and slider is drawn on. It is solid, so the
/// player's copy hides the one in the frames with the votes on it.
const Color _cardColor = VineTheme.whiteText;

/// The color of a poll's text, marks and empty answers.
const Color _ink = VineTheme.primaryDarkGreen;

/// How tall an answer of a poll or a quiz is, tall enough to tap on a card
/// three fifths of a phone wide.
const double _answerHeight = 116;

/// How large a slider's emoji is.
const double _thumbSize = 100;

/// The height of a slider's bar.
const double _barHeight = 28;

/// The size of the mark showing where a slider stands on average.
const double _averageMarkSize = 44;

/// Text of a poll card in [fontSize].
TextStyle _textStyle(double fontSize) => VineTheme.titleLargeFont(
  color: _ink,
).copyWith(fontSize: fontSize, height: 1.15);

/// A poll, quiz or slider: its question over its answers or its scale, on a
/// white card.
///
/// In the frames it shows nothing more, with a soft shadow under the card.
/// The player lays it over them again [overFrames], without the shadow that
/// is in the frames already, with the [results] once they are in, and takes
/// votes through [onAnswer], or for a slider [onSlide] and [onSlideEnd].
/// Over the frames only the answers and a slider's emoji take
/// the pointer; a tap anywhere else reaches the player beneath.
class PollStickerCard extends StatelessWidget {
  const PollStickerCard({
    required this.data,
    this.overFrames = false,
    this.results,
    this.onAnswer,
    this.sliderValue = 0,
    this.onSlide,
    this.onSlideEnd,
    super.key,
  });

  final SocialStickerData data;

  /// Whether the card is drawn again over itself in a video's frames.
  final bool overFrames;

  /// The votes shown over the answers, or `null` to show none.
  final PollStickerResults? results;

  /// Votes for the answer of that index; without, the answers take no tap.
  final ValueChanged<int>? onAnswer;

  /// Where a slider's emoji stands, from 0 to 1.
  final double sliderValue;

  /// Moves a slider's emoji to a point from 0 to 1 while it is dragged.
  final ValueChanged<double>? onSlide;

  /// Rates with the slider where its emoji was let go.
  final ValueChanged<double>? onSlideEnd;

  @override
  Widget build(BuildContext context) {
    final results = this.results;
    final content = Padding(
      padding: const .all(pollCardPadding),
      child: SizedBox(
        width: pollCardContentWidth,
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: 16,
          children: [
            IgnorePointer(
              ignoring: overFrames,
              child: Padding(
                padding: const .only(bottom: 12),
                child: StickerTextLine(
                  text: data.pollQuestion ?? '',
                  style: _textStyle(54),
                  maxLines: 2,
                  textAlign: .center,
                ),
              ),
            ),
            if (data.kind == SocialStickerKind.slider)
              _SliderScale(
                question: data.pollQuestion ?? '',
                emoji: data.sliderEmoji ?? '',
                value: sliderValue,
                average: results?.average,
                passesTaps: overFrames,
                onSlide: onSlide,
                onSlideEnd: onSlideEnd,
              )
            else
              for (final (index, answer) in data.pollOptions.indexed)
                IgnorePointer(
                  ignoring: overFrames && onAnswer == null,
                  child: _Answer(
                    text: answer,
                    share: results?.shares.elementAtOrNull(index),
                    isOwn: results?.ownAnswer == index,
                    isRight: results?.rightAnswer == index,
                    isWrong:
                        results?.rightAnswer != null &&
                        results?.ownAnswer == index &&
                        results?.rightAnswer != index,
                    onTap: onAnswer == null ? null : () => onAnswer!(index),
                  ),
                ),
          ],
        ),
      ),
    );
    // Over the frames the copy's painter draws the card, which a decoration
    // here would hit-test as a whole and keep the player's taps from.
    if (overFrames) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(pollCardRadius),
        boxShadow: const [
          BoxShadow(
            color: VineTheme.scrim15,
            blurRadius: 40,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// A sharp copy of a poll, quiz or slider, filling the box the same sticker
/// takes in a video's frames, to be laid over it there.
///
/// Its card is drawn at that box, hiding the sticker beneath, and the rest is
/// scaled to fit inside in proportion, like any solid sticker's copy; see
/// `SocialStickerCopy`. The player passes the votes and takes new ones
/// through the same arguments as [PollStickerCard].
class PollStickerCopy extends StatelessWidget {
  const PollStickerCopy({
    required this.data,
    this.results,
    this.onAnswer,
    this.sliderValue = 0,
    this.onSlide,
    this.onSlideEnd,
    super.key,
  });

  final SocialStickerData data;
  final PollStickerResults? results;
  final ValueChanged<int>? onAnswer;
  final double sliderValue;
  final ValueChanged<double>? onSlide;
  final ValueChanged<double>? onSlideEnd;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _CardPainter(),
      child: FittedBox(
        child: PollStickerCard(
          data: data,
          overFrames: true,
          results: results,
          onAnswer: onAnswer,
          sliderValue: sliderValue,
          onSlide: onSlide,
          onSlideEnd: onSlideEnd,
        ),
      ),
    );
  }
}

/// Paints a poll card filling the box, its corners as round for its width as
/// [PollStickerCard]'s.
class _CardPainter extends CustomPainter {
  const _CardPainter();

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width * pollCardRoundness),
    ),
    Paint()..color = _cardColor,
  );

  // Only the answers and a slider's emoji take the pointer; a tap anywhere
  // else on the card still reaches the player beneath.
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_CardPainter oldDelegate) => false;
}

/// One answer of a poll or a quiz, a pill, and once the votes are in, the
/// share it has filled in from the start: the viewer's own pick and a quiz's
/// right answer in Divine green, a wrong pick in red, the others pale green.
class _Answer extends StatelessWidget {
  const _Answer({
    required this.text,
    required this.share,
    required this.isOwn,
    required this.isRight,
    required this.isWrong,
    required this.onTap,
  });

  final String text;
  final double? share;
  final bool isOwn;
  final bool isRight;
  final bool isWrong;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final share = this.share;
    final percent = share == null
        ? null
        : NumberFormat.percentPattern(
            Localizations.maybeLocaleOf(context)?.toString(),
          ).format(share);
    final fill = isWrong
        ? VineTheme.error.withValues(alpha: 0.35)
        : isRight || (isOwn && !isWrong)
        ? VineTheme.vineGreen
        : VineTheme.vineGreenLight;
    final answer = SizedBox(
      height: _answerHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_answerHeight / 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: _ink.withValues(alpha: 0.06)),
            ),
            if (share != null)
              FractionallySizedBox(
                widthFactor: share.clamp(0, 1),
                heightFactor: 1,
                child: ColoredBox(color: fill),
              ),
            Positioned.fill(
              child: Padding(
                padding: const .symmetric(horizontal: 40),
                child: Row(
                  spacing: 16,
                  children: [
                    Expanded(
                      child: StickerTextLine(
                        text: text,
                        style: _textStyle(44),
                      ),
                    ),
                    if (isRight || isWrong)
                      DivineIcon(
                        icon: isRight ? .check : .x,
                        size: 48,
                        color: _ink,
                      ),
                    if (percent != null)
                      Text(
                        percent,
                        style: _textStyle(42).copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textScaler: TextScaler.noScaling,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return answer;
    return Semantics(
      button: true,
      selected: isOwn,
      label: percent == null ? text : '$text, $percent',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: answer,
      ),
    );
  }
}

/// A slider's bar with its emoji on it, which the viewer drags along, and
/// once there are votes, where everyone put it on average.
///
/// It runs from left to right in every language, as it does in the frames.
class _SliderScale extends StatelessWidget {
  const _SliderScale({
    required this.question,
    required this.emoji,
    required this.value,
    required this.average,
    required this.passesTaps,
    required this.onSlide,
    required this.onSlideEnd,
  });

  /// What the slider asks, which names it to a screen reader.
  final String question;
  final String emoji;
  final double value;
  final double? average;

  /// Whether a tap off the emoji reaches what is beneath.
  final bool passesTaps;
  final ValueChanged<double>? onSlide;
  final ValueChanged<double>? onSlideEnd;

  /// How far the emoji's centre travels, from one end of the bar to the
  /// other.
  static const double _travel = pollCardContentWidth - _thumbSize;

  /// The point on the bar from 0 to 1 that [globalPosition] is over, through
  /// whatever scales and turns the sticker.
  static double _valueAt(BuildContext context, Offset globalPosition) {
    final box = context.findRenderObject()! as RenderBox;
    final x = box.globalToLocal(globalPosition).dx;
    return ((x - _thumbSize / 2) / _travel).clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final average = this.average;
    final thumb = SizedBox.square(
      dimension: _thumbSize,
      child: Center(
        child: StickerTextLine(text: emoji, style: _textStyle(84)),
      ),
    );
    final onSlide = this.onSlide;
    final onSlideEnd = this.onSlideEnd;
    return SizedBox(
      height: _thumbSize,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          Positioned(
            left: _thumbSize / 2,
            right: _thumbSize / 2,
            top: (_thumbSize - _barHeight) / 2,
            height: _barHeight,
            child: IgnorePointer(
              ignoring: passesTaps,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_barHeight / 2),
                child: Stack(
                  textDirection: TextDirection.ltr,
                  children: [
                    Positioned.fill(
                      child: ColoredBox(color: _ink.withValues(alpha: 0.08)),
                    ),
                    if (average != null)
                      FractionallySizedBox(
                        widthFactor: average.clamp(0, 1),
                        heightFactor: 1,
                        child: const ColoredBox(color: VineTheme.vineGreen),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (average != null)
            Positioned(
              left:
                  average.clamp(0, 1) * _travel +
                  (_thumbSize - _averageMarkSize) / 2,
              top: (_thumbSize - _averageMarkSize) / 2,
              child: IgnorePointer(
                ignoring: passesTaps,
                child: const SizedBox.square(
                  dimension: _averageMarkSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _cardColor,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: VineTheme.vineGreen, width: 8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: value.clamp(0, 1) * _travel,
            top: 0,
            child: onSlide == null || onSlideEnd == null
                ? IgnorePointer(ignoring: passesTaps, child: thumb)
                : Semantics(
                    slider: true,
                    label: question,
                    value: '${(value * 100).round()}',
                    increasedValue:
                        '${((value + 0.1).clamp(0, 1) * 100).round()}',
                    decreasedValue:
                        '${((value - 0.1).clamp(0, 1) * 100).round()}',
                    onIncrease: () => onSlideEnd((value + 0.1).clamp(0, 1)),
                    onDecrease: () => onSlideEnd((value - 0.1).clamp(0, 1)),
                    excludeSemantics: true,
                    child: GestureDetector(
                      // Only the emoji drags, so a swipe to the next video
                      // anywhere else on the sticker still reaches the feed.
                      behavior: HitTestBehavior.opaque,
                      // Where the finger is on the bar, not how far it moved
                      // since the last frame: several moves can come in
                      // before the emoji is drawn where the last one put it.
                      onHorizontalDragUpdate: (details) => onSlide(
                        _valueAt(context, details.globalPosition),
                      ),
                      onHorizontalDragEnd: (_) => onSlideEnd(value),
                      child: thumb,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
