// ABOUTME: Bottom sheet for the speed of the selected clip: one constant speed
// ABOUTME: from presets or a slider, or a speed curve from ramp presets or dragged points.

import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_speed_choice.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show VideoSpeedRamp, VideoSpeedRampPoint;

/// The slider computes its discrete values in floating point, so a preset
/// counts as selected when the speed is within this distance of it.
const double _presetTolerance = 1e-6;

const double _minTapTarget = 48;

const double _chipGap = 8;

const double _curveHeight = 196;

const double _handleSize = 18;

/// Pops a [ClipSpeedChoice]: [ConstantClipSpeed] or [RampClipSpeed].
class VideoEditorClipSpeedSheet extends StatefulWidget {
  const VideoEditorClipSpeedSheet({
    super.key,
    this.initialSpeed = 1.0,
    this.initialRamp,
    this.sourceDuration,
  });

  final double initialSpeed;

  /// The clip's speed curve; the sheet opens on the curve when set.
  final VideoSpeedRamp? initialRamp;

  /// The trimmed clip's source length, for the resulting length shown under
  /// the controls; hidden when null.
  final Duration? sourceDuration;

  @override
  State<VideoEditorClipSpeedSheet> createState() =>
      _VideoEditorClipSpeedSheetState();
}

class _VideoEditorClipSpeedSheetState extends State<VideoEditorClipSpeedSheet> {
  late final ValueNotifier<double> _speed;
  late final ValueNotifier<VideoSpeedRamp> _ramp;
  late final ValueNotifier<bool> _curveMode;

  /// The last curve the user shaped by hand, which the custom chip returns to.
  VideoSpeedRamp? _customRamp;

  @override
  void initState() {
    super.initState();
    _speed = ValueNotifier(
      widget.initialSpeed.clamp(
        VideoEditorConstants.clipSpeedMin,
        VideoEditorConstants.clipSpeedMax,
      ),
    );
    final initialRamp = widget.initialRamp;
    _ramp = ValueNotifier(initialRamp ?? flatSpeedRamp);
    if (initialRamp != null && ClipSpeedRampPreset.of(initialRamp) == null) {
      _customRamp = initialRamp;
    }
    _curveMode = ValueNotifier(initialRamp != null);
  }

  @override
  void dispose() {
    _speed.dispose();
    _ramp.dispose();
    _curveMode.dispose();
    super.dispose();
  }

  /// A curve whose points all share one speed plays like that constant speed,
  /// so it comes back as one and the clip is not re-rendered for nothing.
  ClipSpeedChoice get _choice {
    if (!_curveMode.value) return ConstantClipSpeed(_speed.value);
    final ramp = _ramp.value;
    if (ramp.isConstant) return ConstantClipSpeed(ramp.points.first.speed);
    return RampClipSpeed(ramp);
  }

  void _shapeCurve(VideoSpeedRamp ramp) {
    _customRamp = ramp;
    _ramp.value = ramp;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              DivineIconButton(
                icon: DivineIconName.x,
                type: DivineIconButtonType.secondary,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop<ClipSpeedChoice>(),
              ),
              Flexible(
                child: Text(
                  context.l10n.videoEditorSpeedSheetTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                onPressed: () => context.pop<ClipSpeedChoice>(_choice),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: _curveMode,
          builder: (context, curveMode, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                _SpeedModeToggle(
                  curveMode: curveMode,
                  onChanged: (value) => _curveMode.value = value,
                ),
                if (curveMode)
                  _SpeedCurveControls(
                    ramp: _ramp,
                    onPreset: (preset) => _ramp.value = preset.ramp,
                    onCustom: () => _ramp.value = _customRamp ?? flatSpeedRamp,
                    onShaped: _shapeCurve,
                  )
                else
                  _SpeedControlBar(speed: _speed),
                if (widget.sourceDuration case final source?)
                  ListenableBuilder(
                    listenable: Listenable.merge([_speed, _ramp]),
                    builder: (context, _) => _ResultingLength(
                      length: curveMode
                          ? _ramp.value.outputDuration(source)
                          : Duration(
                              microseconds:
                                  (source.inMicroseconds / _speed.value)
                                      .round(),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Constant | Curve segmented toggle.
class _SpeedModeToggle extends StatelessWidget {
  const _SpeedModeToggle({required this.curveMode, required this.onChanged});

  final bool curveMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.controlFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.controlOutline),
      ),
      child: Row(
        children: [
          _SpeedModeSegment(
            label: l10n.videoEditorSpeedModeConstant,
            selected: !curveMode,
            onTap: () => onChanged(false),
          ),
          _SpeedModeSegment(
            label: l10n.videoEditorSpeedModeCurve,
            selected: curveMode,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SpeedModeSegment extends StatelessWidget {
  const _SpeedModeSegment({
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
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: _minTapTarget),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.controlSelectedFill : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.accentBrand : VineTheme.transparent,
              ),
            ),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: VineTheme.labelMediumFont(
                  color: selected ? colors.accentBrand : colors.mutedText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedControlBar extends StatelessWidget {
  const _SpeedControlBar({required this.speed});

  final ValueNotifier<double> speed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: speed,
          builder: (_, value, _) => _SpeedLabelRow(value: value),
        ),
        ValueListenableBuilder<double>(
          valueListenable: speed,
          builder: (_, value, _) => DivineSlider(
            value: value,
            min: VideoEditorConstants.clipSpeedMin,
            max: VideoEditorConstants.clipSpeedMax,
            divisions:
                ((VideoEditorConstants.clipSpeedMax -
                            VideoEditorConstants.clipSpeedMin) /
                        VideoEditorConstants.clipSpeedStep)
                    .round(),
            onChanged: (v) => speed.value = v,
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: speed,
          builder: (_, value, _) => _SpeedPresetRow(
            value: value,
            onSelected: (preset) => speed.value = preset,
          ),
        ),
      ],
    );
  }
}

/// Lays chips out in as many equal columns as fit a 48dp tap target each.
int _columnsFor(double width, int count) {
  if (count <= 1 || width <= 0) return 1;
  var columns = count;
  while (columns > 1) {
    final slot = (width - _chipGap * (columns - 1)) / columns;
    if (slot >= _minTapTarget) return columns;
    columns--;
  }
  return 1;
}

class _SpeedPresetRow extends StatelessWidget {
  const _SpeedPresetRow({required this.value, required this.onSelected});

  final double value;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    const presets = VideoEditorConstants.clipSpeedPresets;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth, presets.length);
        final slot =
            (constraints.maxWidth - _chipGap * (columns - 1)) / columns;
        return Wrap(
          spacing: _chipGap,
          runSpacing: _chipGap,
          children: [
            for (final preset in presets)
              SizedBox(
                width: slot,
                child: _SpeedChip(
                  label: '${_formatSpeed(preset)}×',
                  semanticLabel: context.l10n
                      .videoEditorSpeedPresetSemanticLabel(
                        _formatSpeed(preset),
                      ),
                  selected: (value - preset).abs() < _presetTolerance,
                  onTap: () => onSelected(preset),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 0.50 -> "0.5", 1.00 -> "1": speeds read as short, familiar numbers.
String _formatSpeed(double speed) =>
    speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minTapTarget),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: selected
                      ? colors.controlSelectedFill
                      : colors.controlFill,
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: selected
                          ? colors.accentBrand
                          : colors.controlOutline,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      label,
                      maxLines: 1,
                      style: VineTheme.labelMediumFont(
                        color: selected
                            ? colors.accentBrand
                            : colors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedLabelRow extends StatelessWidget {
  const _SpeedLabelRow({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          context.l10n.videoEditorSpeedLabel,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)}×',
          style: VineTheme.bodyMediumFont(color: context.vineColors.mutedText),
        ),
      ],
    );
  }
}

/// The ramp presets above the curve editor.
class _SpeedCurveControls extends StatelessWidget {
  const _SpeedCurveControls({
    required this.ramp,
    required this.onPreset,
    required this.onCustom,
    required this.onShaped,
  });

  final ValueNotifier<VideoSpeedRamp> ramp;
  final ValueChanged<ClipSpeedRampPreset> onPreset;
  final VoidCallback onCustom;
  final ValueChanged<VideoSpeedRamp> onShaped;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoSpeedRamp>(
      valueListenable: ramp,
      builder: (context, value, _) {
        final selected = ClipSpeedRampPreset.of(value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            _RampPresetRow(
              selected: selected,
              onPreset: onPreset,
              onCustom: onCustom,
            ),
            _SpeedCurveEditor(ramp: value, onChanged: onShaped),
            Text(
              context.l10n.videoEditorSpeedCurveHint,
              textAlign: TextAlign.center,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.mutedText,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RampPresetRow extends StatelessWidget {
  const _RampPresetRow({
    required this.selected,
    required this.onPreset,
    required this.onCustom,
  });

  /// The preset the curve matches; null for a custom curve.
  final ClipSpeedRampPreset? selected;
  final ValueChanged<ClipSpeedRampPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = <ClipSpeedRampPreset, String>{
      ClipSpeedRampPreset.montage: l10n.videoEditorSpeedCurveMontage,
      ClipSpeedRampPreset.hero: l10n.videoEditorSpeedCurveHero,
      ClipSpeedRampPreset.bullet: l10n.videoEditorSpeedCurveBullet,
      ClipSpeedRampPreset.flashIn: l10n.videoEditorSpeedCurveFlashIn,
      ClipSpeedRampPreset.flashOut: l10n.videoEditorSpeedCurveFlashOut,
    };
    // One scrolling row keeps the sheet short enough for a small phone.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        spacing: _chipGap,
        children: [
          _SpeedChip(
            label: l10n.videoEditorSpeedCurveCustom,
            semanticLabel: l10n.videoEditorSpeedCurveCustom,
            selected: selected == null,
            onTap: onCustom,
          ),
          for (final preset in ClipSpeedRampPreset.values)
            _SpeedChip(
              label: labels[preset]!,
              semanticLabel: labels[preset]!,
              selected: selected == preset,
              onTap: () => onPreset(preset),
            ),
        ],
      ),
    );
  }
}

/// The speed curve over the clip, on a logarithmic scale from
/// [VideoEditorConstants.clipSpeedMin] at the bottom to
/// [VideoEditorConstants.clipSpeedMax] at the top, with a handle per point
/// that drags up and down.
class _SpeedCurveEditor extends StatefulWidget {
  const _SpeedCurveEditor({required this.ramp, required this.onChanged});

  final VideoSpeedRamp ramp;
  final ValueChanged<VideoSpeedRamp> onChanged;

  @override
  State<_SpeedCurveEditor> createState() => _SpeedCurveEditorState();
}

class _SpeedCurveEditorState extends State<_SpeedCurveEditor> {
  /// The point being dragged, whose speed shows above its handle.
  int? _active;

  /// Where the finger dragging [_active] is, as a y in the editor: the
  /// handle's centre when the drag started plus every move since.
  double? _dragY;

  static final double _logMin = math.log(VideoEditorConstants.clipSpeedMin);
  static final double _logMax = math.log(VideoEditorConstants.clipSpeedMax);

  /// Height from the bottom, as a fraction, of [speed] on the scale.
  static double _heightOf(double speed) =>
      (math.log(speed) - _logMin) / (_logMax - _logMin);

  /// The speed at [fraction] of the height, snapped to the slider's steps.
  static double _speedAt(double fraction) {
    final raw = math.exp(
      _logMin + fraction.clamp(0.0, 1.0) * (_logMax - _logMin),
    );
    return _snap(raw);
  }

  static double _snap(double speed) {
    const step = VideoEditorConstants.clipSpeedStep;
    // Rounded to the step's two decimals, so 24 steps of 0.05 store 1.2
    // rather than 1.2000000000000002.
    final snapped = double.parse(
      ((speed / step).round() * step).toStringAsFixed(2),
    );
    return snapped.clamp(
      VideoEditorConstants.clipSpeedMin,
      VideoEditorConstants.clipSpeedMax,
    );
  }

  void _setSpeed(int index, double speed) {
    final points = widget.ramp.points;
    if (points[index].speed == speed) return;
    widget.onChanged(
      VideoSpeedRamp([
        for (var i = 0; i < points.length; i++)
          if (i == index)
            VideoSpeedRampPoint(position: points[i].position, speed: speed)
          else
            points[i],
      ]),
    );
  }

  /// The speed one slider step up or down from [speed].
  static double _stepped(double speed, int direction) =>
      _snap(speed + direction * VideoEditorConstants.clipSpeedStep);

  /// One slider step up or down, for assistive technologies.
  void _nudge(int index, int direction) {
    _setSpeed(index, _stepped(widget.ramp.points[index].speed, direction));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final points = widget.ramp.points;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Inset by half a handle so the end points stay fully on screen.
        const inset = _minTapTarget / 2;
        final width = constraints.maxWidth - 2 * inset;
        const plotHeight = _curveHeight - 2 * inset;
        Offset place(VideoSpeedRampPoint point) => Offset(
          inset + point.position * width,
          inset + (1 - _heightOf(point.speed)) * plotHeight,
        );

        return SizedBox(
          height: _curveHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _SpeedCurvePainter(
                      ramp: widget.ramp,
                      inset: inset,
                      curveColor: colors.accentBrand,
                      gridColor: colors.controlOutline,
                      heightOf: _heightOf,
                    ),
                  ),
                ),
              ),
              for (final speed in const [3.0, 1.0, 0.25])
                Positioned(
                  left: 0,
                  top: inset + (1 - _heightOf(speed)) * plotHeight - 18,
                  child: ExcludeSemantics(
                    child: Text(
                      '${_formatSpeed(speed)}×',
                      style: VineTheme.labelSmallFont(color: colors.mutedText),
                    ),
                  ),
                ),
              for (var i = 0; i < points.length; i++)
                _CurveHandle(
                  key: ValueKey(i),
                  center: place(points[i]),
                  speed: points[i].speed,
                  increasedSpeed: _stepped(points[i].speed, 1),
                  decreasedSpeed: _stepped(points[i].speed, -1),
                  active: _active == i,
                  semanticLabel: context.l10n
                      .videoEditorSpeedCurvePointSemanticLabel(
                        '${i + 1}',
                        '${points.length}',
                      ),
                  onDragStart: () => setState(() {
                    _active = i;
                    _dragY = place(points[i]).dy;
                  }),
                  onDragUpdate: (delta) {
                    // Clamped to the plot, so dragging past an end and back
                    // turns around right away instead of after a dead zone.
                    final y = ((_dragY ?? place(points[i]).dy) + delta).clamp(
                      inset,
                      inset + plotHeight,
                    );
                    _dragY = y;
                    _setSpeed(i, _speedAt(1 - (y - inset) / plotHeight));
                  },
                  onDragEnd: () => setState(() {
                    _active = null;
                    _dragY = null;
                  }),
                  onIncrease: () => _nudge(i, 1),
                  onDecrease: () => _nudge(i, -1),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A point's handle: a dot with a 48dp hit area that drags vertically.
class _CurveHandle extends StatelessWidget {
  const _CurveHandle({
    required this.center,
    required this.speed,
    required this.increasedSpeed,
    required this.decreasedSpeed,
    required this.active,
    required this.semanticLabel,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onIncrease,
    required this.onDecrease,
    super.key,
  });

  final Offset center;
  final double speed;

  /// The speed one step up and down, announced before a screen reader
  /// changes it.
  final double increasedSpeed;
  final double decreasedSpeed;
  final bool active;
  final String semanticLabel;
  final VoidCallback onDragStart;

  /// Called with how far the finger moved since the last call, in pixels.
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final value = '${_formatSpeed(speed)}×';
    return Positioned(
      left: center.dx - _minTapTarget / 2,
      top: center.dy - _minTapTarget / 2,
      width: _minTapTarget,
      height: _minTapTarget,
      child: Semantics(
        slider: true,
        label: semanticLabel,
        value: value,
        increasedValue: '${_formatSpeed(increasedSpeed)}×',
        decreasedValue: '${_formatSpeed(decreasedSpeed)}×',
        onIncrease: onIncrease,
        onDecrease: onDecrease,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Counted from the touch, so the handle stays under the finger.
          // Deltas, not the local position: an event's local position is
          // measured against where the handle was when the finger went down,
          // and the handle moves while it is dragged.
          dragStartBehavior: DragStartBehavior.down,
          onVerticalDragStart: (_) => onDragStart(),
          onVerticalDragUpdate: (details) => onDragUpdate(details.delta.dy),
          onVerticalDragEnd: (_) => onDragEnd(),
          onVerticalDragCancel: onDragEnd,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: _handleSize,
                height: _handleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? colors.accentBrand : colors.controlFill,
                  border: Border.all(color: colors.accentBrand, width: 2),
                ),
              ),
              if (active)
                Positioned(
                  bottom: _minTapTarget - 4,
                  child: ExcludeSemantics(
                    child: Text(
                      value,
                      style: VineTheme.labelMediumFont(
                        color: colors.accentBrand,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedCurvePainter extends CustomPainter {
  _SpeedCurvePainter({
    required this.ramp,
    required this.inset,
    required this.curveColor,
    required this.gridColor,
    required this.heightOf,
  });

  final VideoSpeedRamp ramp;
  final double inset;
  final Color curveColor;
  final Color gridColor;
  final double Function(double speed) heightOf;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width - 2 * inset;
    final height = size.height - 2 * inset;
    double yOf(double speed) => inset + (1 - heightOf(speed)) * height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final speed in const [3.0, 1.0, 0.25]) {
      final y = yOf(speed);
      canvas.drawLine(Offset(inset, y), Offset(inset + width, y), grid);
    }

    final path = Path();
    const samples = 96;
    for (var i = 0; i <= samples; i++) {
      final position = i / samples;
      final point = Offset(
        inset + position * width,
        yOf(ramp.speedAt(position)),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = curveColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SpeedCurvePainter oldDelegate) =>
      oldDelegate.ramp != ramp ||
      oldDelegate.curveColor != curveColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.inset != inset;
}

class _ResultingLength extends StatelessWidget {
  const _ResultingLength({required this.length});

  final Duration length;

  @override
  Widget build(BuildContext context) {
    final seconds = (length.inMilliseconds / 1000).toStringAsFixed(1);
    return Text(
      context.l10n.videoEditorSpeedResultingLength(seconds),
      textAlign: TextAlign.center,
      style: VineTheme.bodyMediumFont(color: context.vineColors.secondaryText),
    );
  }
}
