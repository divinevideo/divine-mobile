// ABOUTME: Draws a social sticker in its pill: an @mention, a #hashtag, a link,
// ABOUTME: or a sound credit that moves with the editor's playhead.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

/// A social sticker as it shows on the video.
///
/// Lays out at its own size; the editor's widget layer scales it to the
/// layer's width with a `FittedBox`.
class SocialStickerView extends StatelessWidget {
  const SocialStickerView({
    required this.data,
    this.overFrames = false,
    super.key,
  });

  final SocialStickerData data;

  /// Whether the sticker is drawn again over itself in a video's frames, in
  /// its [StickerPillPalette.covering] colors.
  final bool overFrames;

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
  };

  @override
  Widget build(BuildContext context) {
    final look = StickerPillPalette.of(data.style);
    final palette = overFrames ? look.covering : look;
    return Semantics(
      label: textOf(data),
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
                Text(
                  '🔗',
                  style: palette.textStyle(),
                  textScaler: TextScaler.noScaling,
                ),
                _Line(text: textOf(data), style: palette.textStyle()),
              ],
            ),
          ),
          _ => StickerPill(
            palette: palette,
            child: _Line(text: textOf(data), style: palette.textStyle()),
          ),
        },
      ),
    );
  }
}

/// The widest a sticker's line of text gets before it ends in an ellipsis.
const double _maxTextWidth = 720;

/// One line of sticker text, cut short with an ellipsis past
/// [_maxTextWidth].
///
/// Unscaled by the system font size, like the sound credit's painted text:
/// the sticker is part of the video, sized by the creator's pinch, and the
/// player's copy of it has to match the frames at any font size.
class _Line extends StatelessWidget {
  const _Line({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxTextWidth),
      child: Text(
        text,
        style: style,
        maxLines: 1,
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
    required this.playTime,
    required this.timelineMap,
    required this.levels,
  }) : super(repaint: playTime);

  final SocialStickerData data;
  final bool overFrames;
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
      !identical(oldDelegate.playTime, playTime) ||
      !identical(oldDelegate.timelineMap, timelineMap) ||
      !identical(oldDelegate.levels, levels);
}
