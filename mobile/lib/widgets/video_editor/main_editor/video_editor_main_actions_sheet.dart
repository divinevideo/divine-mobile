// ABOUTME: Bottom sheet with sub-editor actions for the video editor.
// ABOUTME: Opened from Editing tools, provides access to text, draw, and more.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/draw_editor/video_editor_draw_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_loop_repair_listener.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';

/// Bottom sheet that shows video editor sub-editor actions.
///
/// Uses [_ItemButton] for each action and closes the sheet after
/// an action is selected.
class VideoEditorMainActionsSheet extends StatelessWidget {
  const VideoEditorMainActionsSheet({
    required this.scope,
    required this.onAlignLoop,
    super.key,
  });

  static const _maxItemWidth = 72.0;
  static const _itemMainSpacing = 16.0;
  static const _itemCrossSpacing = 24.0;
  static const _minItemCrossSpacing = 8.0;

  /// The editor scope captured before opening the sheet.
  final VideoEditorScope scope;

  /// Uses the editor context outside the sheet to preserve loop history.
  final VoidCallback onAlignLoop;

  /// Opens the actions bottom sheet.
  static Future<void> show(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final videoEditorMainBloc = context.read<VideoEditorMainBloc>();
    final clipEditorBloc = context.read<ClipEditorBloc>();
    final tuneBloc = context.read<VideoEditorTuneBloc>();
    final drawBloc = context.read<VideoEditorDrawBloc>();

    return VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      showHeader: false,
      showHeaderDivider: false,
      // The sheet opens on a separate route, outside the editor's
      // MultiBlocProvider, so re-provide every bloc the actions read —
      // including the tune bloc the Adjust action needs and the draw bloc
      // the Draw and Blur actions open the draw editor with.
      body: SingleChildScrollView(
        child: MultiBlocProvider(
          providers: [
            BlocProvider<VideoEditorMainBloc>.value(
              value: videoEditorMainBloc,
            ),
            BlocProvider<ClipEditorBloc>.value(value: clipEditorBloc),
            BlocProvider<VideoEditorTuneBloc>.value(value: tuneBloc),
            BlocProvider<VideoEditorDrawBloc>.value(value: drawBloc),
          ],
          child: VideoEditorMainActionsSheet(
            scope: scope,
            onAlignLoop: () => alignEditorLoop(context),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = VineTheme.bodySmallFont(
      color: context.vineColors.primaryText,
    );
    final labelScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: chipLabelTextScaleLimit,
    );
    // Reserve two scaled label lines below the largest icon tile, which
    // [_ItemButton] caps at [_maxItemWidth]. The grid gives each column a
    // tight height, even when its label wraps.
    final itemHeight =
        (_maxItemWidth +
                8 +
                2 *
                    labelScaler.scale(labelStyle.fontSize!) *
                    labelStyle.height!)
            .ceilToDouble();
    final totalDuration = context.select(
      (ClipEditorBloc b) => b.state.totalDuration,
    );
    final isStopMotion = context.select(
      (ClipEditorBloc b) => isStopMotionComposition(b.state.clips),
    );
    final canAlignLoop = context.select(
      (ClipEditorBloc b) =>
          b.state.clips.isNotEmpty && !b.state.hasPendingClipOperation,
    );
    final items = <_ItemButton>[
      _ItemButton(
        icon: .camera,
        label: context.l10n.videoEditorCameraLabel,
        semanticLabel: context.l10n.videoEditorOpenCameraSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenCamera();
        },
      ),
      _ItemButton(
        icon: .images,
        label: context.l10n.videoEditorLibraryLabel,
        semanticLabel: context.l10n.videoEditorOpenLibrarySemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenClipsEditor();
        },
      ),
      // A layout joins the timeline as one rendered video clip, and a
      // frames-first stop-motion composition holds stills, never a
      // video, so it is not offered there.
      if (scope.onOpenLayout case final onOpenLayout? when !isStopMotion)
        _ItemButton(
          icon: .squaresFour,
          label: context.l10n.videoEditorLayoutLabel,
          semanticLabel: context.l10n.videoEditorOpenLayoutSemanticLabel,
          onTap: () {
            Navigator.pop(context);
            onOpenLayout();
          },
        ),
      _ItemButton(
        icon: .waveform,
        label: context.l10n.videoEditorAudioLabel,
        semanticLabel: context.l10n.videoEditorOpenAudioSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenMusicLibrary();
        },
      ),
      _ItemButton(
        icon: .microphone,
        label: context.l10n.videoEditorVoiceOverLabel,
        semanticLabel: context.l10n.videoEditorOpenVoiceOverSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenVoiceOver();
        },
      ),
      _ItemButton(
        icon: .textAa,
        label: context.l10n.videoEditorTextLabel,
        semanticLabel: context.l10n.videoEditorOpenTextSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.editor?.openTextEditor();
        },
      ),
      _ItemButton(
        icon: .circlesThree,
        label: context.l10n.videoEditorFilterLabel,
        semanticLabel: context.l10n.videoEditorOpenFilterSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.editor?.openFilterEditor();
        },
      ),
      _ItemButton(
        icon: .television,
        label: context.l10n.videoEditorEffectsLabel,
        semanticLabel: context.l10n.videoEditorOpenEffectsSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenEffects();
        },
      ),
      _ItemButton(
        icon: .repeat,
        label: context.l10n.videoEditorLoopLabel,
        semanticLabel: context.l10n.videoEditorLoopSemanticLabel,
        onTap: canAlignLoop
            ? () {
                Navigator.pop(context);
                onAlignLoop();
              }
            : null,
      ),
      _ItemButton(
        icon: .slidersHorizontal,
        label: context.l10n.videoEditorTuneLabel,
        semanticLabel: context.l10n.videoEditorOpenTuneSemanticLabel,
        onTap: () {
          final tuneBloc = context.read<VideoEditorTuneBloc>();
          Navigator.pop(context);
          openTuneEditor(tuneBloc, scope);
        },
      ),
      _ItemButton(
        icon: .scribble,
        label: context.l10n.videoEditorDrawLabel,
        semanticLabel: context.l10n.videoEditorOpenDrawSemanticLabel,
        onTap: () {
          context.read<VideoEditorDrawBloc>().add(
            const VideoEditorDrawOpened(censor: false),
          );
          Navigator.pop(context);
          scope.editor?.openPaintEditor();
        },
      ),
      _ItemButton(
        icon: .eyeSlash,
        label: context.l10n.videoEditorCensorLabel,
        semanticLabel: context.l10n.videoEditorOpenBlurSemanticLabel,
        onTap: () {
          context.read<VideoEditorDrawBloc>().add(
            const VideoEditorDrawOpened(censor: true),
          );
          Navigator.pop(context);
          scope.editor?.openPaintEditor();
        },
      ),
      _ItemButton(
        icon: .sticker,
        label: context.l10n.videoEditorStickers,
        semanticLabel: context.l10n.videoEditorOpenStickerSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onAddStickers();
        },
      ),
      if (scope.onAddAudioVisualizer case final onAddAudioVisualizer?)
        _ItemButton(
          icon: .equalizer,
          label: context.l10n.videoEditorAudioVisualizerLabel,
          semanticLabel:
              context.l10n.videoEditorOpenAudioVisualizerSemanticLabel,
          onTap: () {
            Navigator.pop(context);
            onAddAudioVisualizer();
          },
        ),
      _ItemButton(
        icon: .closedCaptioning,
        label: context.l10n.videoEditorCaptionsLabel,
        semanticLabel: context.l10n.videoEditorOpenCaptionsSemanticLabel,
        onTap: () {
          Navigator.pop(context);
          scope.onOpenCaptions();
        },
      ),
      // Timeline markers anchor to video playback positions; on a
      // frames-first stop-motion composition the stills themselves
      // are the granularity, so the option is hidden.
      if (!isStopMotion)
        _ItemButton(
          icon: .bookmarkPlus,
          label: context.l10n.videoEditorMarkerLabel,
          semanticLabel: context.l10n.videoEditorAddTimelineMarkerSemanticLabel,
          onTap: () {
            Navigator.pop(context);
            if (totalDuration <= Duration.zero) return;

            // Enter marker mode instead of dropping a single marker, so
            // the bottom bar exposes add/delete-marker controls and the
            // user can keep marking beats while playback runs.
            context.read<VideoEditorMainBloc>().add(
              const VideoEditorMarkerModeChanged(isActive: true),
            );
          },
        ),
    ];
    final widestWord = _widestWordWidth(
      context,
      labels: [for (final item in items) item.label],
      style: labelStyle,
      textScaler: labelScaler,
    );
    return Padding(
      padding: const .all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final grid = _gridLayout(
            width: constraints.maxWidth,
            minItemWidth: widestWord,
          );
          return GridView(
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid.columns,
              mainAxisExtent: itemHeight,
              mainAxisSpacing: _itemMainSpacing,
              crossAxisSpacing: grid.spacing,
            ),
            children: items,
          );
        },
      ),
    );
  }

  /// The columns and the gap between them: as many columns as fit items at
  /// most [_maxItemWidth] wide, with the gap narrowed, and then a column
  /// dropped, until the longest word of the labels fits an item.
  ///
  /// A word too long for its column breaks in the middle, which a long
  /// translation or a large text size would otherwise do.
  static ({int columns, double spacing}) _gridLayout({
    required double width,
    required double minItemWidth,
  }) {
    var columns = math.max(
      1,
      (width / (_maxItemWidth + _itemCrossSpacing)).ceil(),
    );
    while (columns > 1) {
      // The widest gap that still leaves each item [minItemWidth].
      final spacing = (width - columns * minItemWidth) / (columns - 1);
      if (spacing >= _minItemCrossSpacing) {
        return (
          columns: columns,
          spacing: math.min(spacing, _itemCrossSpacing),
        );
      }
      columns--;
    }
    return (columns: 1, spacing: _itemCrossSpacing);
  }

  /// The width of the longest word in [labels], as their [Text] lays it out.
  static double _widestWordWidth(
    BuildContext context, {
    required List<String> labels,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    // Bold Text widens every glyph, as [Text] applies it.
    final effectiveStyle = MediaQuery.boldTextOf(context)
        ? style.copyWith(fontWeight: FontWeight.bold)
        : style;
    var widest = 0.0;
    for (final label in labels) {
      for (final word in label.split(_wordSeparator)) {
        if (word.isEmpty) continue;
        final painter = TextPainter(
          text: TextSpan(text: word, style: effectiveStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        widest = math.max(widest, painter.width);
        painter.dispose();
      }
    }
    return widest.ceilToDouble();
  }

  static final _wordSeparator = RegExp(r'\s+');
}

class _ItemButton extends StatelessWidget {
  const _ItemButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.semanticLabel,
  });

  final VoidCallback? onTap;
  final DivineIconName icon;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      mainAxisSize: .min,
      spacing: 8,
      children: [
        Semantics(
          label: semanticLabel,
          button: true,
          enabled: enabled,
          child: GestureDetector(
            onTap: onTap,
            // A column can be wider than `_maxItemWidth` (the grid rounds the
            // column count up, narrows its gaps, or drops a column for a long
            // label word), and the row height budgets for a max-width tile, so
            // a square at the column width overflows.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: VideoEditorMainActionsSheet._maxItemWidth,
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: context.vineColors.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: 2,
                        color: context.vineColors.outlineMuted,
                      ),
                      borderRadius: .circular(24),
                    ),
                  ),
                  child: Center(
                    child: DivineIcon(
                      icon: icon,
                      color: enabled
                          ? context.vineColors.accentPositive
                          : context.vineColors.disabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          excludeSemantics: true,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: chipLabelTextScaleLimit,
            child: Text(
              label,
              maxLines: 2,
              textAlign: .center,
              style: VineTheme.bodySmallFont(
                color: enabled
                    ? context.vineColors.primaryText
                    : context.vineColors.disabled,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
