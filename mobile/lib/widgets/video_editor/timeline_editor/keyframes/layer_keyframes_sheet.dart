// ABOUTME: Keyframe sheet of a timeline layer: says in a line how keyframes
// ABOUTME: work, adds or removes the one at the playhead, fades and eases.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_keyframes.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/keyframes/layer_keyframe_actions.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show AnimationCurve, LayerAnimation, LayerAnimationType;

/// The motion a [LayerKeyframesSheet] edits: from keyframe [from] to the one
/// after it, counted from one, along [curve], playing [effect] on the way.
typedef LayerKeyframeSegment = ({
  int from,
  AnimationCurve curve,
  LayerAnimation? effect,
});

/// Body of the keyframe sheet of a layer.
///
/// The button adds a keyframe at the playhead, or removes the one there. On a
/// keyframe the opacity slider sets how see-through the layer is there, so
/// it fades between keyframes. With two keyframes or more the motion the
/// playhead is in can play an effect and ease along a curve; it is named by
/// the keyframes it runs between so it is clear which one it is.
class LayerKeyframesSheet extends StatefulWidget {
  /// Creates a [LayerKeyframesSheet].
  const LayerKeyframesSheet({
    required this.isOnKeyframe,
    required this.opacity,
    required this.segment,
    required this.allowsEffects,
    required this.onToggleKeyframe,
    required this.onOpacityChanged,
    required this.onEffectChanged,
    required this.onCurveSelected,
    super.key,
  });

  /// Whether the playhead sits on a keyframe, which the button then removes.
  final bool isOnKeyframe;

  /// The opacity of the keyframe the playhead is on, or `null` when it is on
  /// none.
  final double? opacity;

  /// The motion at the playhead, or `null` while the layer has fewer than two
  /// keyframes and so no motion.
  final LayerKeyframeSegment? segment;

  /// Whether the motion can play an effect.
  final bool allowsEffects;

  /// Adds the keyframe at the playhead, or removes the one there.
  final VoidCallback onToggleKeyframe;

  /// Called with each step of the opacity slider while it is dragged.
  final ValueChanged<double> onOpacityChanged;

  /// Called with the effect picked for [segment], or `null` for none, and
  /// with it again at the strength its slider is let go at.
  final ValueChanged<LayerAnimation?> onEffectChanged;

  /// Called with each curve tapped for [segment].
  final ValueChanged<AnimationCurve> onCurveSelected;

  @override
  State<LayerKeyframesSheet> createState() => _LayerKeyframesSheetState();
}

class _LayerKeyframesSheetState extends State<LayerKeyframesSheet> {
  late double? _opacity = widget.opacity;
  late LayerAnimation? _effect = widget.segment?.effect;
  late AnimationCurve? _curve = widget.segment?.curve;

  void _changeOpacity(double opacity) {
    setState(() => _opacity = opacity);
    widget.onOpacityChanged(opacity);
  }

  void _pickEffect(LayerAnimationType? type) {
    // Tapping the effect already picked would reset its strength.
    if (type == _effect?.type) return;
    final effect = type == null ? null : defaultKeyframeEffect(type);
    setState(() => _effect = effect);
    widget.onEffectChanged(effect);
  }

  void _selectCurve(AnimationCurve curve) {
    setState(() => _curve = curve);
    widget.onCurveSelected(curve);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final segment = widget.segment;
    final opacity = _opacity;
    final curve = _curve;
    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(
                l10n.videoEditorKeyframesHint,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              DivineButton(
                label: widget.isOnKeyframe
                    ? l10n.videoEditorKeyframeRemove
                    : l10n.videoEditorKeyframeAdd,
                leadingIcon: widget.isOnKeyframe ? .trash : .diamond,
                type: widget.isOnKeyframe ? .secondary : .primary,
                expanded: true,
                onPressed: widget.onToggleKeyframe,
              ),
              if (opacity != null)
                _LabeledSlider(
                  label: l10n.videoEditorOpacityLabel,
                  valueLabel: '${(opacity * 100).round()}%',
                  value: opacity,
                  divisions: 100,
                  onChanged: _changeOpacity,
                ),
              if (segment != null && curve != null) ...[
                Text(
                  // The numbers name keyframes; they are not a count.
                  l10n.videoEditorKeyframeCurveSegment(
                    '${segment.from}',
                    '${segment.from + 1}',
                  ),
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                if (widget.allowsEffects)
                  _EffectPicker(
                    effect: _effect,
                    onPicked: _pickEffect,
                    onStrengthChanged: (effect) =>
                        setState(() => _effect = effect),
                    onStrengthChangeEnd: widget.onEffectChanged,
                  ),
                SectionLabel(l10n.videoEditorTransitionCurve),
                CurvePickerRow(
                  // The two packages name their thirteen curves alike.
                  selected: pveCurveOf(curve),
                  onChanged: (picked) =>
                      _selectCurve(AnimationCurve.values.byName(picked.name)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The effect a motion plays — none, a wiggle, a hop or a pulse — and how
/// strongly, as the loop of the layer animation sheet offers them.
class _EffectPicker extends StatelessWidget {
  const _EffectPicker({
    required this.effect,
    required this.onPicked,
    required this.onStrengthChanged,
    required this.onStrengthChangeEnd,
  });

  final LayerAnimation? effect;

  /// Called with the effect type tapped, or `null` for none.
  final ValueChanged<LayerAnimationType?> onPicked;

  /// Called with [effect] at each step of its strength slider.
  final ValueChanged<LayerAnimation> onStrengthChanged;

  /// Called with [effect] at the strength its slider is let go at.
  final ValueChanged<LayerAnimation> onStrengthChangeEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effect = this.effect;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        SectionLabel(l10n.videoEditorKeyframeEffect),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in [null, ...keyframeEffectTypes])
              _EffectChip(
                label: switch (type) {
                  null => l10n.videoEditorTransitionNone,
                  LayerAnimationType.wiggle =>
                    l10n.videoEditorLayerAnimationWiggle,
                  LayerAnimationType.bounce =>
                    l10n.videoEditorLayerAnimationBounce,
                  _ => l10n.videoEditorLayerAnimationPulse,
                },
                selected: effect?.type == type,
                onTap: () => onPicked(type),
              ),
          ],
        ),
        if (effect != null)
          _EffectStrengthSlider(
            effect: effect,
            onChanged: onStrengthChanged,
            onChangeEnd: onStrengthChangeEnd,
          ),
      ],
    );
  }
}

/// How strongly [effect] plays: how far a wiggle tilts, how high a hop goes,
/// how small a pulse gets. Same bounds as the layer animation sheet.
class _EffectStrengthSlider extends StatelessWidget {
  const _EffectStrengthSlider({
    required this.effect,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final LayerAnimation effect;

  /// Called with [effect] at each step of the slider.
  final ValueChanged<LayerAnimation> onChanged;

  /// Called with [effect] at the strength the slider is let go at.
  final ValueChanged<LayerAnimation> onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final effect = this.effect;
    final slider = switch (effect.type) {
      LayerAnimationType.wiggle => (
        label: l10n.videoEditorLayerAnimationWiggleAngle,
        unit: '°',
        value:
            ((effect.wiggleAngle ?? LayerAnimation.defaultWiggleAngle) *
                    180 /
                    math.pi)
                .roundToDouble(),
        min: VideoEditorConstants.minWiggleDegrees.toDouble(),
        max: VideoEditorConstants.maxWiggleDegrees.toDouble(),
        divisions:
            VideoEditorConstants.maxWiggleDegrees -
            VideoEditorConstants.minWiggleDegrees,
        at: (double degrees) =>
            effect.copyWith(wiggleAngle: degrees * math.pi / 180),
      ),
      LayerAnimationType.bounce => (
        label: l10n.videoEditorLayerAnimationBounceHeight,
        unit: '%',
        value:
            (effect.bounceHeight ?? LayerAnimation.defaultBounceHeight) * 100,
        min: VideoEditorConstants.minBouncePercent.toDouble(),
        max: VideoEditorConstants.maxBouncePercent.toDouble(),
        divisions:
            (VideoEditorConstants.maxBouncePercent -
                VideoEditorConstants.minBouncePercent) ~/
            VideoEditorConstants.bounceStepPercent,
        at: (double percent) => effect.copyWith(bounceHeight: percent / 100),
      ),
      _ => (
        label: l10n.videoEditorLayerAnimationPulseTo,
        unit: '%',
        value:
            (effect.scaleFrom ?? VideoEditorConstants.loopPulseScaleFrom) * 100,
        min: 0.0,
        max: 100.0,
        divisions: 20,
        at: (double percent) => effect.copyWith(scaleFrom: percent / 100),
      ),
    };
    final value = slider.value.clamp(slider.min, slider.max);
    return _LabeledSlider(
      label: slider.label,
      valueLabel: '${value.round()}${slider.unit}',
      value: value,
      min: slider.min,
      max: slider.max,
      divisions: slider.divisions,
      onChanged: (value) => onChanged(slider.at(value)),
      onChangeEnd: (value) => onChangeEnd(slider.at(value)),
    );
  }
}

/// One effect option, labeled, highlighted when [selected].
class _EffectChip extends StatelessWidget {
  const _EffectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return AnimationPickerChip(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          style: VineTheme.labelLargeFont(
            color: selected ? colors.accentBrand : colors.primaryText,
          ),
        ),
      ),
    );
  }
}

/// A slider under a [label], with the value it is at beside the label.
class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0,
    this.max = 1,
    this.divisions,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SectionLabel(label),
            Text(
              valueLabel,
              style: VineTheme.labelSmallFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ],
        ),
        DivineSlider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          semanticLabel: label,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
