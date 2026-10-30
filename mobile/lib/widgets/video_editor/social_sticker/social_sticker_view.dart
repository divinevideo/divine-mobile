// ABOUTME: Draws a social sticker: an @mention, a #hashtag or a link as a pill,
// ABOUTME: a sound credit that moves with the playhead, a countdown or a reply.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_marks.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// A social sticker as it shows on the video.
///
/// Lays out at its own size; the editor's widget layer scales it to the
/// layer's width with a `FittedBox`.
class SocialStickerView extends StatelessWidget {
  const SocialStickerView({
    required this.data,
    this.overFrames = false,
    this.countdownValue,
    super.key,
  });

  final SocialStickerData data;

  /// Whether the sticker is drawn again over itself in a video's frames, in
  /// its [StickerPillPalette.covering] colors.
  final bool overFrames;

  /// What a countdown shows under its title instead of its date: the time
  /// left, which the player draws over the date in the frames.
  final String? countdownValue;

  /// The date a countdown counts down to, written in its locale and clock the
  /// way the video shows it, such as "Jun 21, 2027 · 6:00 PM", in the
  /// phone's time zone.
  static String countdownDateOf(SocialStickerData data) {
    final end = data.countdownEnd?.toLocal();
    if (end == null) return '';
    final locale = data.localeName;
    final known = locale != null && DateFormat.localeExists(locale)
        ? locale
        : null;
    final time = data.use24HourFormat
        ? DateFormat.Hm(known)
        : DateFormat.jm(known);
    return '${DateFormat.yMMMd(known).format(end)} · ${time.format(end)}';
  }

  /// The sticker's text, as it reads on the video and to a screen reader.
  static String textOf(SocialStickerData data) => switch (data.kind) {
    SocialStickerKind.mention => '@${data.name ?? ''}',
    SocialStickerKind.hashtag => '#${data.hashtag ?? ''}',
    SocialStickerKind.link => data.linkTitle ?? data.linkDomain ?? '',
    SocialStickerKind.soundCredit => [
      data.soundTitle,
      data.soundArtist,
      data.lyric,
    ].nonNulls.join(' · '),
    SocialStickerKind.countdown => [
      data.countdownTitle ?? '',
      countdownDateOf(data),
    ].join(' · '),
    SocialStickerKind.reply => [?data.name, ?data.replyText].join(': '),
  };

  @override
  Widget build(BuildContext context) {
    final look = StickerPillPalette.of(data.style);
    final palette = overFrames ? look.covering : look;
    final countdownValue = this.countdownValue;
    return Semantics(
      label: countdownValue == null
          ? textOf(data)
          : '${data.countdownTitle ?? ''} · $countdownValue',
      excludeSemantics: true,
      // The headless draft rasterizer mounts the sticker without a Material
      // above it, whose fallback text style underlines everything in yellow.
      child: DefaultTextStyle(
        style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
        child: switch (data.kind) {
          SocialStickerKind.soundCredit => _SoundCredit(
            data: data,
            overFrames: overFrames,
          ),
          SocialStickerKind.link => StickerPill(
            palette: palette,
            child: Row(
              mainAxisSize: .min,
              spacing: 14,
              children: [
                SocialStickerMarkView(
                  mark: SocialStickerMark.link,
                  size: _markSize,
                  ink: palette.ink,
                  shadows: palette.shadows,
                ),
                _Line(text: textOf(data), style: palette.textStyle()),
              ],
            ),
          ),
          SocialStickerKind.countdown => _CountdownCard(
            data: data,
            palette: palette,
            value: countdownValue ?? countdownDateOf(data),
          ),
          SocialStickerKind.reply => _ReplyCard(data: data, palette: palette),
          _ => StickerPill(
            palette: palette,
            child: _Line(text: textOf(data), style: palette.textStyle()),
          ),
        },
      ),
    );
  }
}

/// A sharp copy of a social sticker, filling the box the same sticker takes
/// in a video's frames, to be laid over it there.
///
/// A solid look draws its pill at that box, hiding the sticker beneath, and
/// scales the rest to fit inside in proportion: a viewer's phone may draw
/// text the sticker font lacks, or emoji before the sticker emoji font has
/// loaded, wider or narrower than the creator's did, and stretched to the
/// box it would come out distorted. The frames show through
/// any other look, so it is stretched to lie on its own text there; see
/// [SocialStickerData.canBeRedrawn] for when that matches.
class SocialStickerCopy extends StatelessWidget {
  const SocialStickerCopy({
    required this.data,
    this.countdownValue,
    super.key,
  });

  final SocialStickerData data;

  /// What a countdown shows under its title instead of its date; see
  /// [SocialStickerView.countdownValue].
  final String? countdownValue;

  @override
  Widget build(BuildContext context) {
    final sticker = SocialStickerView(
      data: data,
      overFrames: true,
      countdownValue: countdownValue,
    );
    final pill = StickerPillPalette.of(data.style).covering.background;
    if (pill == null) return FittedBox(fit: .fill, child: sticker);
    return CustomPaint(
      painter: _PillPainter(
        color: pill,
        roundness: switch (data.kind) {
          SocialStickerKind.soundCredit => soundCreditRoundness(data),
          SocialStickerKind.countdown => _countdownRoundness,
          _ => 0.5,
        },
      ),
      child: FittedBox(child: sticker),
    );
  }
}

/// Paints a pill in [color] filling the box, the radius of its corners
/// [roundness] of its height.
class _PillPainter extends CustomPainter {
  const _PillPainter({required this.color, required this.roundness});

  final Color color;
  final double roundness;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawRRect(
    RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height * roundness),
    ),
    Paint()..color = color,
  );

  @override
  bool shouldRepaint(_PillPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.roundness != roundness;
}

/// The widest a sticker's line of text gets before it ends in an ellipsis.
const double _maxTextWidth = 720;

/// The side of the mark beside a link's text, the height of its letters.
const double _markSize = 48;

/// How wide a countdown's date or time left is laid out, whatever it says,
/// so the copy the player draws with the time left is as large as the
/// sticker in the frames with the date.
const double _countdownValueWidth = 440;

/// The size of a countdown's date or time left.
const double _countdownValueFontSize = 40;

/// The radius of a countdown card's corners.
const double _countdownRadius = 48;

/// The size of a countdown's title, drawn in [StickerPillPalette.textStyle]'s
/// default size; it only sizes the corner radius, so the two change together.
const double _countdownTitleFontSize = 48;

/// The space above and below a countdown's title and date in its card.
const double _countdownPaddingVertical = 28;

/// The space between a countdown's title and its date.
const double _countdownSpacing = 8;

/// How round a countdown card's corners are, as a share of its height: its
/// padding, its title line and its date line.
///
/// The 1.15 line height and [_countdownTitleFontSize] mirror
/// [StickerPillPalette.textStyle]'s defaults and change together with them.
const double _countdownRoundness =
    _countdownRadius /
    (2 * _countdownPaddingVertical +
        _countdownTitleFontSize * 1.15 +
        _countdownSpacing +
        _countdownValueFontSize * 1.15);

/// A countdown: its title over its date, or over the time left the player
/// draws in [value].
class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.data,
    required this.palette,
    required this.value,
  });

  final SocialStickerData data;
  final StickerPillPalette palette;
  final String value;

  @override
  Widget build(BuildContext context) {
    final valueStyle = palette
        .textStyle(fontSize: _countdownValueFontSize)
        .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return StickerPill(
      palette: palette,
      radius: _countdownRadius,
      padding: const .symmetric(
        horizontal: 40,
        vertical: _countdownPaddingVertical,
      ),
      child: Column(
        mainAxisSize: .min,
        spacing: _countdownSpacing,
        children: [
          _Line(text: data.countdownTitle ?? '', style: palette.textStyle()),
          SizedBox(
            width: _countdownValueWidth,
            height: _countdownValueFontSize * 1.15,
            child: FittedBox(
              fit: .scaleDown,
              child: Text(
                value,
                style: valueStyle,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The widest a reply's name and comment get.
const double _maxReplyTextWidth = 600;

/// A reply: the picture, name and comment of what the video replies to.
class _ReplyCard extends StatelessWidget {
  const _ReplyCard({required this.data, required this.palette});

  final SocialStickerData data;
  final StickerPillPalette palette;

  @override
  Widget build(BuildContext context) {
    final text = data.replyText;
    return StickerPill(
      palette: palette,
      radius: 40,
      padding: const .symmetric(horizontal: 28, vertical: 24),
      child: Row(
        mainAxisSize: .min,
        spacing: 20,
        children: [
          _ReplyPicture(data: data, palette: palette),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxReplyTextWidth),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              spacing: 6,
              children: [
                _Line(
                  text: data.name ?? '',
                  style: palette.textStyle(fontSize: 40),
                ),
                if (text != null)
                  _Line(
                    text: text,
                    style: palette
                        .textStyle(fontSize: 34)
                        .copyWith(fontWeight: FontWeight.w400),
                    maxLines: 3,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar of whoever wrote the comment a reply replies to, round, or the
/// thumbnail of the video, upright; their initial while neither is in.
class _ReplyPicture extends StatelessWidget {
  const _ReplyPicture({required this.data, required this.palette});

  final SocialStickerData data;
  final StickerPillPalette palette;

  @override
  Widget build(BuildContext context) {
    final toVideo = data.replyToVideo;
    final url = data.replyImageUrl;
    final fallback = ColoredBox(
      color: palette.ink.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          (data.name ?? '').characters.firstOrNull?.toUpperCase() ?? '',
          style: palette.textStyle(fontSize: 40),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(toVideo ? 16 : 44),
      child: SizedBox(
        width: toVideo ? 84 : 88,
        height: toVideo ? 112 : 88,
        child: url == null
            ? fallback
            : VineCachedImage(
                imageUrl: url,
                // The capture of the sticker takes it as it is at the time.
                fadeInDuration: Duration.zero,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// One line of sticker text, or up to [maxLines], cut short with an
/// ellipsis past [_maxTextWidth].
///
/// Unscaled by the system font size, like the sound credit's painted text:
/// the sticker is part of the video, sized by the creator's pinch, and the
/// player's copy of it has to match the frames at any font size. Its emoji
/// are drawn in the sticker emoji font once that is loaded, which it loads
/// when they are all its text needs beyond the sticker font.
class _Line extends StatefulWidget {
  const _Line({required this.text, required this.style, this.maxLines = 1});

  final String text;
  final TextStyle style;
  final int maxLines;

  @override
  State<_Line> createState() => _LineState();
}

class _LineState extends State<_Line> {
  @override
  void initState() {
    super.initState();
    _loadEmojiFont();
  }

  @override
  void didUpdateWidget(_Line oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _loadEmojiFont();
  }

  // The text is laid out again on its own once the font is in.
  void _loadEmojiFont() => runDetached(
    loadStickerEmojiFontFor([widget.text]),
    'load the sticker emoji font',
    logName: 'SocialStickerView',
    category: LogCategory.video,
  );

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxTextWidth),
      child: Text(
        widget.text,
        style: withStickerEmojiFont(widget.style),
        maxLines: widget.maxLines,
        overflow: .ellipsis,
        textScaler: TextScaler.noScaling,
      ),
    );
  }
}

/// A sound credit, drawn the way the export draws it and, in the editor,
/// moving with the playhead: a record or a cassette's reels turning, a
/// player's bar running and an equalizer following the video's sound.
class _SoundCredit extends StatefulWidget {
  const _SoundCredit({required this.data, required this.overFrames});

  final SocialStickerData data;
  final bool overFrames;

  @override
  State<_SoundCredit> createState() => _SoundCreditState();
}

class _SoundCreditState extends State<_SoundCredit> {
  VideoEditorAudioVisualizerCubit? _cubit;
  StreamSubscription<VideoEditorAudioVisualizerState>? _subscription;
  TransitionTimelineMap? _timelineMap;

  /// The bar levels of the video's sound, for an equalizer.
  Float32List? _levels;

  /// The energies [_levels] were worked out from.
  Float32List? _levelsFrom;

  /// Whether the sticker emoji font was loaded at the last paint; the painted
  /// text does not lay itself out again when it comes in.
  bool _emojiFontLoaded = stickerEmojiFontLoaded;

  @override
  void initState() {
    super.initState();
    _loadEmojiFont();
  }

  void _loadEmojiFont() {
    if (_emojiFontLoaded) return;
    runDetached(
      loadStickerEmojiFontFor([SocialStickerView.textOf(widget.data)]).then((
        _,
      ) {
        if (!mounted || stickerEmojiFontLoaded == _emojiFontLoaded) return;
        setState(() => _emojiFontLoaded = stickerEmojiFontLoaded);
      }),
      'load the sticker emoji font',
      logName: 'SocialStickerView',
      category: LogCategory.video,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = _readCubit();
    if (identical(cubit, _cubit)) return;
    unawaited(_subscription?.cancel());
    _cubit = cubit;
    _subscription = cubit?.stream.listen(_onState);
    _onState(cubit?.state);
  }

  @override
  void didUpdateWidget(_SoundCredit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.listensToSound != widget.data.listensToSound) {
      _onState(_cubit?.state);
    }
    if (oldWidget.data != widget.data) _loadEmojiFont();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  /// The cubit, or `null` outside the editor, where nothing provides it.
  VideoEditorAudioVisualizerCubit? _readCubit() {
    try {
      return context.read<VideoEditorAudioVisualizerCubit>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  void _onState(VideoEditorAudioVisualizerState? state) {
    final energies = widget.data.listensToSound ? state?.energies : null;
    final timelineMap = state?.timelineMap;
    if (identical(energies, _levelsFrom) &&
        identical(timelineMap, _timelineMap)) {
      return;
    }
    setState(() {
      _timelineMap = timelineMap;
      if (!identical(energies, _levelsFrom)) {
        _levelsFrom = energies;
        _levels = energies == null ? null : soundCreditLevels(energies);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final playTime = data.isAnimated
        ? VideoEditorScope.maybeOf(context)?.playTimeNotifier
        : null;
    return RepaintBoundary(
      child: CustomPaint(
        size: soundCreditSize(data),
        painter: _SoundCreditPainter(
          data: data,
          overFrames: widget.overFrames,
          emojiFontLoaded: _emojiFontLoaded,
          playTime: playTime,
          timelineMap: _timelineMap,
          levels: _levels,
        ),
      ),
    );
  }
}

/// Paints a sound credit as it looks at the playhead, mapped onto the
/// exported video its sound is timed on, and again whenever it moves.
class _SoundCreditPainter extends CustomPainter {
  _SoundCreditPainter({
    required this.data,
    required this.overFrames,
    required this.emojiFontLoaded,
    required this.playTime,
    required this.timelineMap,
    required this.levels,
  }) : super(repaint: playTime);

  final SocialStickerData data;
  final bool overFrames;
  final bool emojiFontLoaded;
  final ValueListenable<Duration>? playTime;
  final TransitionTimelineMap? timelineMap;
  final Float32List? levels;

  @override
  void paint(Canvas canvas, Size size) {
    final editorTime = playTime?.value;
    final motion = editorTime == null
        ? const SoundCreditMotion()
        : _motionAt(timelineMap?.editorToOutput(editorTime) ?? editorTime);
    paintSoundCredit(
      canvas,
      size,
      data: data,
      motion: motion,
      overFrames: overFrames,
    );
  }

  SoundCreditMotion _motionAt(Duration time) {
    final length = timelineMap?.outputDuration ?? Duration.zero;
    return SoundCreditMotion(
      time: time,
      progress: length > Duration.zero
          ? time.inMicroseconds / length.inMicroseconds
          : 0,
      levels: soundCreditLevelsAt(levels, time),
    );
  }

  @override
  bool shouldRepaint(_SoundCreditPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.overFrames != overFrames ||
      oldDelegate.emojiFontLoaded != emojiFontLoaded ||
      !identical(oldDelegate.playTime, playTime) ||
      !identical(oldDelegate.timelineMap, timelineMap) ||
      !identical(oldDelegate.levels, levels);
}
