// ABOUTME: Overlay controls of the video effects editor: close/done toolbar,
// ABOUTME: intensity slider, on-the-beat switch, the drops' settings and the
// ABOUTME: play/pause tap area.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/drops_effect_settings.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/flashing_effect_snack_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectPreview;

/// What the cards over the preview leave free on the right for the intensity
/// slider.
const double _sliderClearance = 72;

/// Overlay controls for the effects editor.
///
/// Shows a vertical intensity slider on the right while an effect is picked,
/// a switch to fire it on the beat when it can, the settings of the drops
/// while they are picked, and says so when this device cannot preview effects
/// at all.
class VideoEditorEffectsOverlayControls extends StatelessWidget {
  const VideoEditorEffectsOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final hasEffect = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType != null,
    );
    return Stack(
      fit: .expand,
      children: [
        Semantics(
          button: true,
          label: context.l10n.videoEditorPlayPauseSemanticLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<VideoEditorMainBloc>().add(
              const VideoEditorPlaybackToggleRequested(),
            ),
          ),
        ),
        Column(
          children: [
            const _TopBarContent(),
            // Everything else sits under the toolbar: the bar under the
            // preview is tall, so nothing may reach up behind it.
            Expanded(
              child: _ControlsLayout(
                dropsMinHeight: _DropsSettingsCard.minOpenHeight(
                  MediaQuery.textScalerOf(context),
                ),
                notice: const _PreviewUnavailableNotice(),
                dropsSettings: const _DropsSettingsCard(),
                onBeatSwitch: const _OnBeatSwitch(),
                slider: AnimatedSwitcher(
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(1, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  switchInCurve: Curves.easeInOut,
                  duration: const Duration(milliseconds: 220),
                  child: hasEffect
                      ? const _IntensitySlider()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Lays out the controls under the toolbar, so none of them covers another.
///
/// The intensity slider is centred on the right in the space above the room
/// the on-the-beat switch takes at the normal text size. A switch that a
/// larger text size grows into the slider leaves the slider's column free
/// instead, as the drops' settings do, so the slider keeps its full height.
///
/// The notice that the preview cannot show effects lies over the preview at
/// the top, which shows no effects on such a device anyway, so its lines take
/// no room from the slider and the switch. The drops' settings open below it
/// while their [dropsMinHeight] fits there. On a screen too short for the
/// notice and a card, the card covers it, and the notice is left out rather
/// than shown cut off.
class _ControlsLayout extends MultiChildRenderObjectWidget {
  _ControlsLayout({
    required this.dropsMinHeight,
    required Widget notice,
    required Widget dropsSettings,
    required Widget onBeatSwitch,
    required Widget slider,
  }) : super(children: [notice, dropsSettings, onBeatSwitch, slider]);

  /// The least height the drops' settings take open.
  final double dropsMinHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderControlsLayout(dropsMinHeight: dropsMinHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderControlsLayout renderObject,
  ) {
    renderObject.dropsMinHeight = dropsMinHeight;
  }
}

class _ControlsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderControlsLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ControlsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ControlsParentData> {
  _RenderControlsLayout({required double dropsMinHeight})
    : _dropsMinHeight = dropsMinHeight;

  double get dropsMinHeight => _dropsMinHeight;
  double _dropsMinHeight;
  set dropsMinHeight(double value) {
    if (_dropsMinHeight == value) return;
    _dropsMinHeight = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ControlsParentData) {
      child.parentData = _ControlsParentData();
    }
  }

  /// Whether a card covers the notice, which is then left out: neither
  /// painted, read out nor in the way of a tap on the preview.
  bool _isNoticeCovered = false;

  /// Whether [child] takes part in painting, semantics and hit testing.
  bool _isShown(RenderBox child) => !(_isNoticeCovered && child == firstChild);

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  /// Where the card [child] placed at the bottom starts to show, below its
  /// [margin]; the bottom edge for a card that is not there.
  double _cardTop(RenderBox child, double margin) => child.size.isEmpty
      ? size.height
      : (child.parentData! as _ControlsParentData).offset.dy + margin;

  /// Lays [child] out within [maxSize], and places it [atBottom] or at the top,
  /// centred across the width unless [atLeft].
  void _place(
    RenderBox child,
    Size maxSize, {
    required bool atBottom,
    bool atLeft = false,
  }) {
    child.layout(BoxConstraints.loose(maxSize), parentUsesSize: true);
    (child.parentData! as _ControlsParentData).offset = Offset(
      atLeft ? 0 : (size.width - child.size.width) / 2,
      atBottom ? size.height - child.size.height : 0,
    );
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    final notice = firstChild!;
    final dropsSettings = childAfter(notice)!;
    final onBeatSwitch = childAfter(dropsSettings)!;
    final slider = childAfter(onBeatSwitch)!;

    _place(notice, size, atBottom: false);
    final belowNotice = size.height - notice.size.height;
    _place(
      dropsSettings,
      Size(
        size.width,
        belowNotice >= dropsMinHeight ? belowNotice : size.height,
      ),
      atBottom: true,
    );

    final area = max(0.0, size.height - VideoEditorConstants.bottomBarHeight);
    slider.layout(
      BoxConstraints.loose(Size(size.width, _IntensitySlider.heightIn(area))),
      parentUsesSize: true,
    );
    final sliderTop = (area - slider.size.height) / 2;
    (slider.parentData! as _ControlsParentData).offset = Offset(
      size.width - slider.size.width,
      sliderTop,
    );

    _place(onBeatSwitch, size, atBottom: true);
    final switchTop =
        size.height - onBeatSwitch.size.height + _OnBeatSwitch.margin;
    if (!slider.size.isEmpty && switchTop < sliderTop + slider.size.height) {
      _place(
        onBeatSwitch,
        Size(
          size.width - _sliderClearance + _OnBeatSwitch.margin,
          size.height,
        ),
        atBottom: true,
        atLeft: true,
      );
    }

    final isNoticeCovered =
        !notice.size.isEmpty &&
        min(
              _cardTop(dropsSettings, _DropsSettingsCard._margin.top),
              _cardTop(onBeatSwitch, _OnBeatSwitch.margin),
            ) <
            notice.size.height;
    if (isNoticeCovered != _isNoticeCovered) {
      _isNoticeCovered = isNoticeCovered;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      if (_isShown(child)) {
        context.paintChild(
          child,
          (child.parentData! as _ControlsParentData).offset + offset,
        );
      }
      child = childAfter(child);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      if (_isShown(child)) visitor(child);
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (var child = lastChild; child != null; child = childBefore(child)) {
      final current = child;
      if (_isShown(current) &&
          result.addWithPaintOffset(
            offset: (current.parentData! as _ControlsParentData).offset,
            position: position,
            hitTest: (result, transformed) =>
                current.hitTest(result, position: transformed),
          )) {
        return true;
      }
    }
    return false;
  }
}

/// The intensity slider, as tall as it is allowed to be.
class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider();

  /// How tall the slider is in [area] of height.
  static double heightIn(double area) => min(300, area * 0.8);

  @override
  Widget build(BuildContext context) {
    final intensity = context.select(
      (VideoEditorEffectsCubit c) => c.state.intensity,
    );
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: constraints.maxHeight,
          value: intensity,
          onChanged: context.read<VideoEditorEffectsCubit>().setIntensity,
        ),
      ),
    );
  }
}

/// What finding the beats for an effect on the beat came to, for the line
/// under the switch, or `null` when there is nothing to say.
String? onBeatStatusLabel(
  AppLocalizations l10n,
  VideoEditorEffectsState state,
) {
  if (!state.selectionOnBeat) return null;
  return switch (state.beatStatus) {
    VideoEditorBeatStatus.idle => null,
    VideoEditorBeatStatus.loading => l10n.videoEditorEffectsOnBeatFinding,
    VideoEditorBeatStatus.noSound => l10n.videoEditorEffectsOnBeatNoSound,
    VideoEditorBeatStatus.failed => l10n.videoEditorEffectsOnBeatNoBeat,
    VideoEditorBeatStatus.ready =>
      state.beats.isEmpty ? l10n.videoEditorEffectsOnBeatNoBeat : null,
  };
}

/// Fires the picked effect on the beat of the music, for an effect that
/// [EditorEffectType.supportsOnBeat], with a line saying when there is no
/// beat to follow.
class _OnBeatSwitch extends StatelessWidget {
  const _OnBeatSwitch();

  /// Around the card.
  static const double margin = 16;

  @override
  Widget build(BuildContext context) {
    final canFire = context.select((VideoEditorEffectsCubit c) {
      final type = c.state.selectedType;
      return type != null && type.supportsOnBeat;
    });
    if (!canFire) return const SizedBox.shrink();
    final l10n = context.l10n;
    final onBeat = context.select(
      (VideoEditorEffectsCubit c) => c.state.onBeat,
    );
    final status = context.select(
      (VideoEditorEffectsCubit c) => onBeatStatusLabel(l10n, c.state),
    );
    return BlocListener<VideoEditorEffectsCubit, VideoEditorEffectsState>(
      // Finding the beat ends somewhere the screen reader would not notice:
      // say so when there turns out to be nothing to follow.
      listenWhen: (previous, current) =>
          onBeatStatusLabel(l10n, previous) !=
              onBeatStatusLabel(l10n, current) &&
          current.beatStatus != VideoEditorBeatStatus.loading &&
          onBeatStatusLabel(l10n, current) != null,
      listener: (context, state) => SemanticsService.sendAnnouncement(
        View.of(context),
        onBeatStatusLabel(l10n, state)!,
        Directionality.of(context),
      ),
      // Grows with the text only so far, or it would cover the preview.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: chipLabelTextScaleLimit,
        child: Padding(
          padding: const .all(margin),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surfaceContainer,
                borderRadius: .circular(16),
              ),
              // The tile's ink needs a surface of its own over the video.
              child: Material(
                type: MaterialType.transparency,
                child: DivineSwitchTile(
                  title: l10n.videoEditorEffectsOnBeat,
                  subtitle: status,
                  value: onBeat,
                  onChanged: (value) => context
                      .read<VideoEditorEffectsCubit>()
                      .setOnBeat(onBeat: value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The settings of the drops while they are picked: a card that opens to
/// sliders for how many drops there are, how large, how fast and how frosted
/// they are and how strong their colour fringes are, and a button that gives
/// them a new arrangement.
class _DropsSettingsCard extends StatelessWidget {
  const _DropsSettingsCard();

  /// Around the card, clear of the intensity slider on the right.
  static const EdgeInsets _margin = EdgeInsets.fromLTRB(
    16,
    16,
    _sliderClearance,
    16,
  );
  static const EdgeInsets _childrenPadding = EdgeInsets.fromLTRB(16, 0, 16, 16);

  /// A one-line [ListTile]'s height, and the padding it keeps around a title
  /// taller than that. The card's title row is one, its title kept to a
  /// single line.
  static const double _titleRowMinHeight = 56;
  static const double _titleRowVerticalPadding = 8;

  /// The card's text stops growing here: a fixed-width card over a small
  /// area, whose title and labels would be cut past it, and whose settings
  /// would show one row at a time.
  static const double _textScaleLimit = chipLabelTextScaleLimit;

  /// The title row's height at [textScaler], already clamped to the card's
  /// limit.
  static double _titleRowHeight(TextScaler textScaler) {
    // Only the metrics are read; the color is never painted.
    final titleStyle = VineTheme.titleSmallFont(color: VineTheme.transparent);
    final titleLine =
        textScaler.scale(titleStyle.fontSize!) * (titleStyle.height ?? 1.2);
    return max(_titleRowMinHeight, titleLine + 2 * _titleRowVerticalPadding);
  }

  /// The least height the card takes open, its settings scrolled into no
  /// room at all, at the system's [textScaler].
  static double minOpenHeight(TextScaler textScaler) =>
      _margin.vertical +
      _titleRowHeight(textScaler.clamp(maxScaleFactor: _textScaleLimit)) +
      _childrenPadding.vertical;

  @override
  Widget build(BuildContext context) {
    final isDrops = context.select(
      (VideoEditorEffectsCubit c) =>
          c.state.selectedType == EditorEffectType.drops,
    );
    if (!isDrops) return const SizedBox.shrink();
    final l10n = context.l10n;
    final titleStyle = VineTheme.titleSmallFont(
      color: context.vineColors.onSurface,
    );
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _textScaleLimit,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleRow = _titleRowHeight(MediaQuery.textScalerOf(context));
          // The settings scroll in what the area under the toolbar leaves
          // them, and never take more than 40% of the screen, so most of the
          // video stays in view.
          final settingsHeight = max(
            0.0,
            min(
              MediaQuery.sizeOf(context).height * 0.4,
              constraints.maxHeight -
                  _margin.vertical -
                  titleRow -
                  _childrenPadding.vertical,
            ),
          );
          return Padding(
            padding: _margin,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.vineColors.surfaceContainer,
                  borderRadius: .circular(16),
                ),
                // The tile's ink needs a surface of its own over the video.
                child: Material(
                  type: MaterialType.transparency,
                  child: ExpansionTile(
                    title: Text(
                      l10n.videoEditorDropsSettingsTitle,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: .ellipsis,
                    ),
                    shape: const Border(),
                    collapsedShape: const Border(),
                    iconColor: context.vineColors.onSurface,
                    collapsedIconColor: context.vineColors.onSurface,
                    childrenPadding: _childrenPadding,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: settingsHeight),
                        child: const SingleChildScrollView(
                          child: _DropsSettings(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DropsSettings extends StatelessWidget {
  const _DropsSettings();

  @override
  Widget build(BuildContext context) {
    final settings = context.select(
      (VideoEditorEffectsCubit c) => c.state.dropsSettings,
    );
    final cubit = context.read<VideoEditorEffectsCubit>();
    final l10n = context.l10n;
    // Each change starts from the cubit's latest settings, so quick drags on
    // one slider never undo another.
    void update(DropsEffectSettings Function(DropsEffectSettings) change) =>
        cubit.setDropsSettings(change(cubit.state.dropsSettings));
    return Column(
      crossAxisAlignment: .start,
      spacing: 8,
      children: [
        _DropsSlider(
          label: l10n.videoEditorDropsCountLabel,
          value: settings.count.toDouble(),
          format: (value) => '${value.round()}',
          min: DropsEffectSettings.minCount.toDouble(),
          max: DropsEffectSettings.maxCount.toDouble(),
          divisions:
              DropsEffectSettings.maxCount - DropsEffectSettings.minCount,
          onChanged: (value) => update((s) => s.copyWith(count: value.round())),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsSizeLabel,
          value: settings.size,
          onChanged: (value) => update((s) => s.copyWith(size: value)),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsSpeedLabel,
          value: settings.speed,
          onChanged: (value) => update((s) => s.copyWith(speed: value)),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsFrostLabel,
          value: settings.frost,
          onChanged: (value) => update((s) => s.copyWith(frost: value)),
        ),
        _DropsSlider(
          label: l10n.videoEditorDropsFringesLabel,
          value: settings.fringes,
          onChanged: (value) => update((s) => s.copyWith(fringes: value)),
        ),
        DivineButton(
          label: l10n.videoEditorDropsShuffle,
          leadingIcon: DivineIconName.arrowsClockwise,
          size: .small,
          type: .secondary,
          onPressed: cubit.shuffleDrops,
        ),
      ],
    );
  }
}

/// A labelled slider of the drops' settings, with its value on the right:
/// a share from 0 to 100 unless [format] says otherwise.
class _DropsSlider extends StatelessWidget {
  const _DropsSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.format,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  /// Writes the value, for the eye and for screen readers alike.
  final String Function(double value)? format;
  final double min;
  final double max;
  final int? divisions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        // The slider announces its label and value itself.
        ExcludeSemantics(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
              Text(
                format?.call(value) ?? '${(value * 100).round()}',
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        DivineSlider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          semanticValue: format,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VideoEditorEffectsCubit>();
    final mainBloc = context.read<VideoEditorMainBloc>();
    final scope = VideoEditorScope.of(context);
    final toolName = context.l10n.videoEditorEffectsLabel;

    return Align(
      alignment: .topCenter,
      child: VideoEditorToolbar(
        closeSemanticLabel: context.l10n
            .videoEditorDiscardToolChangesSemanticLabel(toolName),
        doneSemanticLabel: context.l10n
            .videoEditorApplyToolChangesSemanticLabel(toolName),
        onClose: () {
          cubit.cancel();
          mainBloc.add(const VideoEditorMainSubEditorClosed());
        },
        onDone: () {
          final result = cubit.confirm();
          scope.editor?.setVideoEffectEntries(result.effects);
          if (result.replacedFlashing) {
            showFlashingEffectReplacedSnackBar(context);
          }
          mainBloc.add(const VideoEditorMainSubEditorClosed());
        },
      ),
    );
  }
}

/// Says so when this device cannot show effects in the preview.
///
/// Without it the preview would quietly show the plain video, which reads as
/// "the effect does nothing" rather than "you can't see it here".
class _PreviewUnavailableNotice extends StatefulWidget {
  const _PreviewUnavailableNotice();

  @override
  State<_PreviewUnavailableNotice> createState() =>
      _PreviewUnavailableNoticeState();
}

class _PreviewUnavailableNoticeState extends State<_PreviewUnavailableNotice> {
  late final Future<bool> _canPreview = VideoEffectPreview.precache();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canPreview,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        return Padding(
          padding: const .only(left: 16, right: _sliderClearance),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(12),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              // Covers the preview, so it stops growing before it covers
              // most of it.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: chipLabelTextScaleLimit,
                child: Text(
                  context.l10n.videoEditorChromaKeyPreviewUnavailable,
                  textAlign: .center,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
