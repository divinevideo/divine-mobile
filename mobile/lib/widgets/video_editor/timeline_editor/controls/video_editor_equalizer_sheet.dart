// ABOUTME: Bottom sheet for raising or lowering ten octave bands of the
// ABOUTME: selected clip or sound on a curve; pops the settings or null.

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/equalizer_preset.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';

/// Lets the creator raise or lower a clip's or a sound's audio in ten octave
/// bands from 31 Hz to 16 kHz, by dragging the points of a curve, with
/// one-tap presets above it.
///
/// Every change is handed to [onChanged] as it happens, so the editor preview
/// can play it at once. The sheet pops the settings when confirmed, and
/// `null` when dismissed; the caller then restores what was committed.
class VideoEditorEqualizerSheet extends StatefulWidget {
  /// Creates the sheet starting at [initial].
  const VideoEditorEqualizerSheet({
    required this.initial,
    required this.onChanged,
    super.key,
  });

  /// Opens the sheet over [context].
  static Future<EqualizerSettings?> show({
    required BuildContext context,
    required EqualizerSettings initial,
    required ValueChanged<EqualizerSettings> onChanged,
  }) => VineBottomSheet.show<EqualizerSettings>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: VideoEditorEqualizerSheet(initial: initial, onChanged: onChanged),
  );

  /// The settings the clip or sound has now.
  final EqualizerSettings initial;

  /// Called with every change, before it is confirmed.
  final ValueChanged<EqualizerSettings> onChanged;

  @override
  State<VideoEditorEqualizerSheet> createState() =>
      _VideoEditorEqualizerSheetState();
}

class _VideoEditorEqualizerSheetState extends State<VideoEditorEqualizerSheet> {
  late final ValueNotifier<EqualizerSettings> _settings;

  @override
  void initState() {
    super.initState();
    _settings = ValueNotifier(widget.initial);
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  void _change(EqualizerSettings settings) {
    if (settings == _settings.value) return;
    _settings.value = settings;
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
                semanticLabel: l10n.commonCancel,
                onPressed: () => context.pop<EqualizerSettings>(),
              ),
              Flexible(
                child: Text(
                  l10n.videoEditorEqualizerSheetTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIconButton(
                icon: DivineIconName.check,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.videoEditorDoneLabel,
                onPressed: () =>
                    context.pop<EqualizerSettings>(_settings.value),
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
        ValueListenableBuilder<EqualizerSettings>(
          valueListenable: _settings,
          builder: (_, settings, _) => Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              _PresetRow(selected: settings, onChanged: _change),
              _EqualizerCurve(settings: settings, onChanged: _change),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// The presets, in one row that scrolls sideways once it outgrows the sheet.
class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.selected, required this.onChanged});

  final EqualizerSettings selected;
  final ValueChanged<EqualizerSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final preset = EqualizerPreset.matching(selected);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: [
          for (final option in EqualizerPreset.values)
            _PresetChip(
              preset: option,
              selected: option == preset,
              onTap: () => onChanged(option.settings),
            ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final EqualizerPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (preset) {
      EqualizerPreset.original => l10n.videoEditorVoiceEffectOriginal,
      EqualizerPreset.voice => l10n.videoEditorEqualizerVoice,
      EqualizerPreset.bassy => l10n.videoEditorEqualizerBassy,
      EqualizerPreset.bright => l10n.videoEditorEqualizerBright,
    };
    final colors = context.vineColors;
    return AnimationPickerChip(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: ExcludeSemantics(
        child: Text(
          label,
          maxLines: 1,
          style: VineTheme.labelMediumFont(
            color: selected ? colors.accentBrand : colors.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// The bands as points on a curve, lowest frequency on the left, with the
/// frequency and gain of the point last touched above it.
///
/// Ten points share the width of a phone, too little for a gain under each,
/// so only the one being touched says its value. On a narrow screen a point's
/// column is under 30 dp wide, so beside that value sit buttons with full
/// tap targets that move it a decibel at a time.
class _EqualizerCurve extends StatefulWidget {
  const _EqualizerCurve({required this.settings, required this.onChanged});

  final EqualizerSettings settings;
  final ValueChanged<EqualizerSettings> onChanged;

  @override
  State<_EqualizerCurve> createState() => _EqualizerCurveState();
}

class _EqualizerCurveState extends State<_EqualizerCurve> {
  /// The band last touched, whose value the readout shows.
  int? _selectedBand;

  void _select(int band) {
    if (_selectedBand != band) setState(() => _selectedBand = band);
  }

  void _change(int band, int gain) {
    _select(band);
    widget.onChanged(widget.settings.withGain(band, gain));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final gains = widget.settings.gains;
    final selected = _selectedBand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          _Readout(
            band: selected,
            gain: selected == null ? 0 : gains[selected],
            onChanged: (gain) => _change(selected!, gain),
          ),
          SizedBox(
            height: _curveHeight,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CurvePainter(
                      gains: gains,
                      selectedBand: selected,
                      lineColor: colors.accentBrand,
                      gridColor: colors.outlineMuted,
                      handleBorderColor: colors.background,
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var band = 0; band < gains.length; band++)
                      Expanded(
                        child: _BandHandle(
                          band: band,
                          gain: gains[band],
                          onSelected: () => _select(band),
                          onChanged: (gain) => _change(band, gain),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // The handles above carry each band's frequency for a screen reader.
          ExcludeSemantics(
            child: Row(
              children: [
                for (var band = 0; band < gains.length; band++)
                  Expanded(child: _AxisLabel(band: band)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The frequency and gain of [band] between buttons that lower and raise it
/// a decibel, or how to use the curve before any point has been touched.
class _Readout extends StatelessWidget {
  const _Readout({
    required this.band,
    required this.gain,
    required this.onChanged,
  });

  final int? band;
  final int gain;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final band = this.band;
    if (band == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Center(
          child: Text(
            l10n.videoEditorEqualizerCurveHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodySmallFont(color: colors.mutedText),
          ),
        ),
      );
    }
    final frequency = _frequencyLabel(context, band);
    return Row(
      children: [
        DivineIconButton(
          icon: DivineIconName.minus,
          type: DivineIconButtonType.secondary,
          size: DivineIconButtonSize.small,
          semanticLabel: l10n.videoEditorEqualizerLowerBand(frequency),
          onPressed: gain > EqualizerSettings.minGain
              ? () => onChanged(gain - 1)
              : null,
        ),
        Expanded(
          // Says nothing the band's slider does not say to a screen reader.
          child: ExcludeSemantics(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  frequency,
                  style: VineTheme.bodyMediumFont(color: colors.secondaryText),
                ),
                Text(
                  _gainLabel(context, gain),
                  style: VineTheme.titleMediumFont(color: colors.primaryText),
                ),
              ],
            ),
          ),
        ),
        DivineIconButton(
          icon: DivineIconName.plus,
          type: DivineIconButtonType.secondary,
          size: DivineIconButtonSize.small,
          semanticLabel: l10n.videoEditorEqualizerRaiseBand(frequency),
          onPressed: gain < EqualizerSettings.maxGain
              ? () => onChanged(gain + 1)
              : null,
        ),
      ],
    );
  }
}

const double _curveHeight = 180;

/// How far the highest and lowest gains sit from the curve's edges, so a
/// handle there is drawn whole.
const double _curveInset = 12;

/// The vertical position of [gain] in a curve [height] tall.
double _gainY(int gain, double height) {
  const range = EqualizerSettings.maxGain - EqualizerSettings.minGain;
  final fraction = (EqualizerSettings.maxGain - gain) / range;
  return _curveInset + fraction * (height - 2 * _curveInset);
}

/// The gain at vertical position [y] in a curve [height] tall, in whole
/// decibels within range.
int _gainAt(double y, double height) {
  const range = EqualizerSettings.maxGain - EqualizerSettings.minGain;
  final fraction = ((y - _curveInset) / (height - 2 * _curveInset)).clamp(
    0.0,
    1.0,
  );
  return (EqualizerSettings.maxGain - fraction * range).round();
}

String _frequencyLabel(BuildContext context, int band) {
  final frequency = EqualizerSettings.frequencies[band];
  return frequency >= 1000
      ? context.l10n.videoEditorEqualizerKilohertz('${frequency ~/ 1000}')
      : context.l10n.videoEditorEqualizerHertz('$frequency');
}

String _gainLabel(BuildContext context, int gain) =>
    context.l10n.videoEditorEqualizerGainValue(gain > 0 ? '+$gain' : '$gain');

/// One band's column of the curve: a tap picks the band for the readout's
/// buttons, dragging anywhere in it moves the band's point to the finger, and
/// a double tap puts it back to zero. A drag stays with the band it started
/// on, however far the finger strays sideways. A screen reader adjusts it as
/// a slider, a decibel at a time.
class _BandHandle extends StatelessWidget {
  const _BandHandle({
    required this.band,
    required this.gain,
    required this.onSelected,
    required this.onChanged,
  });

  final int band;
  final int gain;
  final VoidCallback onSelected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canRaise = gain < EqualizerSettings.maxGain;
    final canLower = gain > EqualizerSettings.minGain;
    return Semantics(
      slider: true,
      label: _frequencyLabel(context, band),
      value: _gainLabel(context, gain),
      increasedValue: canRaise ? _gainLabel(context, gain + 1) : null,
      decreasedValue: canLower ? _gainLabel(context, gain - 1) : null,
      onIncrease: canRaise ? () => onChanged(gain + 1) : null,
      onDecrease: canLower ? () => onChanged(gain - 1) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelected,
            onVerticalDragStart: (details) =>
                onChanged(_gainAt(details.localPosition.dy, height)),
            onVerticalDragUpdate: (details) =>
                onChanged(_gainAt(details.localPosition.dy, height)),
            onDoubleTap: () => onChanged(0),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

/// A band's frequency under its point, as short as it can be written.
class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.band});

  final int band;

  @override
  Widget build(BuildContext context) {
    final frequency = EqualizerSettings.frequencies[band];
    // A gap on each side keeps neighbours apart once large text shrinks them
    // to fit a narrow screen.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          frequency >= 1000
              ? context.l10n.videoEditorEqualizerKilohertzShort(
                  '${frequency ~/ 1000}',
                )
              : '$frequency',
          maxLines: 1,
          style: VineTheme.labelSmallFont(color: context.vineColors.mutedText),
        ),
      ),
    );
  }
}

/// Draws the curve through the bands' points, the area between it and zero,
/// and the zero and half-range lines behind it.
class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.gains,
    required this.selectedBand,
    required this.lineColor,
    required this.gridColor,
    required this.handleBorderColor,
  });

  final List<int> gains;
  final int? selectedBand;
  final Color lineColor;
  final Color gridColor;
  final Color handleBorderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.isEmpty) return;
    final columnWidth = size.width / gains.length;
    final points = [
      for (var band = 0; band < gains.length; band++)
        Offset((band + 0.5) * columnWidth, _gainY(gains[band], size.height)),
    ];
    final zeroY = _gainY(0, size.height);

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final gain in const [
      EqualizerSettings.maxGain ~/ 2,
      EqualizerSettings.minGain ~/ 2,
    ]) {
      final y = _gainY(gain, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      grid..strokeWidth = 2,
    );

    final curve = _curveThrough(points, size.width);
    final area = Path.from(curve)
      ..lineTo(size.width, zeroY)
      ..lineTo(0, zeroY)
      ..close();
    canvas
      ..drawPath(area, Paint()..color = lineColor.withValues(alpha: 0.16))
      ..drawPath(
        curve,
        Paint()
          ..color = lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );

    final handle = Paint()..color = lineColor;
    final border = Paint()
      ..color = handleBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var band = 0; band < points.length; band++) {
      final radius = band == selectedBand ? 10.0 : 7.0;
      canvas
        ..drawCircle(points[band], radius, handle)
        ..drawCircle(points[band], radius, border);
    }
  }

  /// A smooth line through every point, level from each edge to the point
  /// nearest it, as the shelves there are.
  static Path _curveThrough(List<Offset> points, double width) {
    final path = Path()
      ..moveTo(0, points.first.dy)
      ..lineTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final previous = points[i == 0 ? 0 : i - 1];
      final start = points[i];
      final end = points[i + 1];
      final next = points[i + 2 < points.length ? i + 2 : i + 1];
      // Catmull-Rom tangents, as cubic Bézier control points.
      final control1 = start + (end - previous) / 6;
      final control2 = end - (next - start) / 6;
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
    }
    return path..lineTo(width, points.last.dy);
  }

  @override
  bool shouldRepaint(_CurvePainter oldDelegate) =>
      !_sameGains(oldDelegate.gains, gains) ||
      oldDelegate.selectedBand != selectedBand ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.handleBorderColor != handleBorderColor;

  static bool _sameGains(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
