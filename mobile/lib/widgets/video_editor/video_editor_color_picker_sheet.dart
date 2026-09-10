// ABOUTME: Bottom sheet for color selection in the video editor.
// ABOUTME: Shows a grid of preset and recent colors with a custom color picker.
// ABOUTME: Persists recently picked custom colors in SharedPreferences.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/widgets/color_swatch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the full HSV color picker as a bottom sheet, resolving with the
/// picked color, or `null` when dismissed.
///
/// Reuses the same picker the text editor's custom-color flow opens.
Future<Color?> showFullColorPicker(
  BuildContext context, {
  required Color initialColor,
}) async {
  Color? picked;
  await VineBottomSheet.show<void>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: _FullColorPickerSheet(
      initialColor: initialColor,
      onColorSelected: (color) => picked = color,
    ),
  );
  return picked;
}

/// Bottom sheet for color selection in the video editor.
class VideoEditorColorPickerSheet extends ConsumerStatefulWidget {
  const VideoEditorColorPickerSheet({
    required this.selectedColor,
    required this.onColorSelected,
    super.key,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  ConsumerState<VideoEditorColorPickerSheet> createState() =>
      _VideoEditorColorPickerSheetState();
}

class _VideoEditorColorPickerSheetState
    extends ConsumerState<VideoEditorColorPickerSheet> {
  /// Fixed number of items per row.
  static const int _crossAxisCount = 6;

  /// Preferred size for color buttons.
  static const double _preferredItemSize = 48;

  /// Preferred spacing between items.
  static const double _preferredSpacing = 16;

  /// Minimum spacing before item size is reduced.
  static const double _minSpacing = 10;

  /// SharedPreferences key for storing recent custom colors.
  static const _recentColorsKey = 'video_editor_recent_colors';

  late List<Color> _recentColors;

  @override
  void initState() {
    super.initState();
    _recentColors = _loadRecentColors(ref.read(sharedPreferencesProvider));
  }

  List<Color> _loadRecentColors(SharedPreferences prefs) {
    final stored = prefs.getStringList(_recentColorsKey);
    if (stored == null) return [];
    return stored.map((hex) => Color(int.tryParse(hex) ?? 0)).toList();
  }

  void _saveRecentColor(Color color) {
    final prefs = ref.read(sharedPreferencesProvider);
    _recentColors
      ..remove(color)
      ..insert(0, color);
    if (_recentColors.length > _crossAxisCount) {
      _recentColors = _recentColors.sublist(0, _crossAxisCount);
    }
    prefs.setStringList(
      _recentColorsKey,
      _recentColors.map((c) => c.toARGB32().toString()).toList(),
    );
    setState(() {});
  }

  void _openColorPicker(BuildContext context) {
    VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: _FullColorPickerSheet(
        initialColor: VineTheme.primary,
        onColorSelected: (color) {
          _saveRecentColor(color);
          widget.onColorSelected(color);
        },
      ),
    );
  }

  /// Returns (itemSize, spacing) that fit 6 items in [availableWidth].
  ///
  /// Keeps [_preferredItemSize] and shrinks spacing down to [_minSpacing]
  /// first. Only reduces item size if spacing alone is not enough.
  (double, double) _computeLayout(double availableWidth) {
    double needed(double size, double gap) =>
        _crossAxisCount * size + (_crossAxisCount - 1) * gap + 2 * gap;

    if (needed(_preferredItemSize, _preferredSpacing) <= availableWidth) {
      // Absorb excess space into spacing so items stay at 48
      final gap =
          (availableWidth - _crossAxisCount * _preferredItemSize) /
          (_crossAxisCount + 1);
      return (_preferredItemSize, gap);
    }
    if (needed(_preferredItemSize, _minSpacing) <= availableWidth) {
      final gap =
          (availableWidth - _crossAxisCount * _preferredItemSize) /
          (_crossAxisCount + 1);
      return (_preferredItemSize, gap);
    }
    final size =
        (availableWidth - (_crossAxisCount + 1) * _minSpacing) /
        _crossAxisCount;
    return (size, _minSpacing);
  }

  @override
  Widget build(BuildContext context) {
    // 1 color picker + 11 preset colors = 12 (2 rows of 6)
    final presetCount = VideoEditorConstants.colors.length + 1;
    // 3rd row: recent colors padded to 6
    final recentRow = List<Color?>.generate(
      _crossAxisCount,
      (i) => i < _recentColors.length ? _recentColors[i] : null,
    );
    final totalCount = presetCount + _crossAxisCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final (itemSize, spacing) = _computeLayout(constraints.maxWidth);

        return SingleChildScrollView(
          padding: .only(bottom: MediaQuery.viewPaddingOf(context).bottom),
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: spacing, vertical: 32),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
            ),
            itemBuilder: (context, index) {
              if (index < presetCount) {
                final isColorPicker = index == 0;
                final color = isColorPicker
                    ? context.vineColors.surfaceContainer
                    : VideoEditorConstants.colors[index - 1];
                final isSelected = color == widget.selectedColor;

                return _ColorButton(
                  color: color,
                  isSelected: isSelected,
                  isColorPicker: isColorPicker,
                  onTap: () => isColorPicker
                      ? _openColorPicker(context)
                      : widget.onColorSelected(color),
                );
              }

              final recentIndex = index - presetCount;
              final recentColor = recentRow[recentIndex];
              // Empty recent-colour slots read as an inset well on the
              // sheet, so they follow the palette rather than a fixed tint.
              final color = recentColor ?? context.vineColors.surfaceContainer;
              final isEmpty = recentColor == null;

              return _ColorButton(
                color: color,
                isSelected: !isEmpty && color == widget.selectedColor,
                isColorPicker: false,
                isEmpty: isEmpty,
                onTap: isEmpty
                    ? () => _openColorPicker(context)
                    : () => widget.onColorSelected(color),
              );
            },
            itemCount: totalCount,
          ),
        );
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.isColorPicker,
    required this.onTap,
    this.isEmpty = false,
  });

  final Color color;
  final bool isSelected;
  final bool isColorPicker;
  final bool isEmpty;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (isColorPicker) {
      label = context.l10n.videoEditorColorPickerSemanticLabel;
    } else {
      final colorName = ColorSwatchButton.rgbSemanticLabel(context, color);
      label = isSelected
          ? context.l10n.videoEditorColorSelectedSemanticLabel(colorName)
          : colorName;
    }

    return ColorSwatchButton(
      color: color,
      isSelected: isSelected,
      onTap: onTap,
      semanticLabel: label,
      borderColor: isColorPicker
          ? context.vineColors.outlineMuted
          : context.vineColors.disabled,
      borderWidth: isColorPicker ? 2 : 1,
      child: isColorPicker
          ? DivineIcon(
              icon: .paintBrush,
              color: context.vineColors.accentPositive,
            )
          : null,
    );
  }
}

class _FullColorPickerSheet extends StatefulWidget {
  const _FullColorPickerSheet({
    required this.initialColor,
    required this.onColorSelected,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_FullColorPickerSheet> createState() => _FullColorPickerSheetState();
}

class _FullColorPickerSheetState extends State<_FullColorPickerSheet> {
  late HSVColor _hsvColor;

  @override
  void initState() {
    super.initState();
    _hsvColor = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const .symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          Padding(
            padding: const .symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              spacing: 12,
              children: [
                DivineIconButton(
                  icon: .x,
                  type: .secondary,
                  size: .small,
                  semanticLabel:
                      context.l10n.videoEditorCloseColorPickerSemanticLabel,
                  onPressed: context.pop,
                ),
                Flexible(
                  child: Text(
                    context.l10n.videoEditorPickColorTitle,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
                DivineIconButton(
                  icon: .check,
                  size: .small,
                  semanticLabel:
                      context.l10n.videoEditorConfirmColorSemanticLabel,

                  onPressed: () {
                    widget.onColorSelected(_hsvColor.toColor());
                    context.pop();
                  },
                ),
              ],
            ),
          ),
          Divider(
            height: 32,
            thickness: 2,
            color: context.vineColors.surfaceContainer,
          ),
          Padding(
            padding: const .symmetric(horizontal: 8),
            child: _SaturationBrightnessPanel(
              hsvColor: _hsvColor,
              onChanged: (hsv) => setState(() => _hsvColor = hsv),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const .symmetric(horizontal: 8),
            child: _HueBar(
              hue: _hsvColor.hue,
              onChanged: (hue) => setState(() {
                _hsvColor = _hsvColor.withHue(hue);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaturationBrightnessPanel extends StatelessWidget {
  const _SaturationBrightnessPanel({
    required this.hsvColor,
    required this.onChanged,
  });

  final HSVColor hsvColor;
  final ValueChanged<HSVColor> onChanged;

  static const double _height = 224;
  static const double _borderRadius = 16;
  static const double _thumbSize = 24;

  void _handleInteraction(Offset localPosition, Size size) {
    final s = (localPosition.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (localPosition.dy / size.height).clamp(0.0, 1.0);
    onChanged(hsvColor.withSaturation(s).withValue(v));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, _height);
        return Semantics(
          label: context.l10n.videoEditorSaturationBrightnessSemanticLabel,
          value: context.l10n.videoEditorSaturationBrightnessValue(
            (hsvColor.saturation * 100).round(),
            (hsvColor.value * 100).round(),
          ),
          child: GestureDetector(
            onPanStart: (d) => _handleInteraction(d.localPosition, size),
            onPanUpdate: (d) => _handleInteraction(d.localPosition, size),
            onTapDown: (d) => _handleInteraction(d.localPosition, size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_borderRadius),
                    child: CustomPaint(
                      size: size,
                      painter: _SatBrightPainter(hue: hsvColor.hue),
                    ),
                  ),
                  Positioned(
                    left: hsvColor.saturation * size.width - _thumbSize / 2,
                    top: (1 - hsvColor.value) * size.height - _thumbSize / 2,
                    child: const _ColorThumb(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SatBrightPainter extends CustomPainter {
  _SatBrightPainter({required this.hue});

  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SatBrightPainter oldDelegate) => oldDelegate.hue != hue;
}

class _HueBar extends StatelessWidget {
  const _HueBar({required this.hue, required this.onChanged});

  final double hue;
  final ValueChanged<double> onChanged;

  static const double _height = 24;
  static const double _thumbSize = 24;

  void _handleInteraction(Offset localPosition, double width) {
    final h = (localPosition.dx / width).clamp(0.0, 1.0) * 360;
    onChanged(h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          slider: true,
          label: context.l10n.videoEditorHueSemanticLabel,
          value: '${hue.round()}°',
          increasedValue: '${(hue + 10).clamp(0.0, 360.0).round()}°',
          decreasedValue: '${(hue - 10).clamp(0.0, 360.0).round()}°',
          onIncrease: () => onChanged((hue + 10).clamp(0.0, 360.0)),
          onDecrease: () => onChanged((hue - 10).clamp(0.0, 360.0)),
          child: GestureDetector(
            onPanStart: (d) => _handleInteraction(d.localPosition, width),
            onPanUpdate: (d) => _handleInteraction(d.localPosition, width),
            onTapDown: (d) => _handleInteraction(d.localPosition, width),
            child: SizedBox(
              width: width,
              height: _height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: .circular(_height / 2),
                    child: CustomPaint(
                      size: Size(width, _height),
                      painter: const _HueBarPainter(),
                    ),
                  ),
                  Positioned(
                    left: (hue / 360) * width - _thumbSize / 2,
                    top: 0,
                    child: const _ColorThumb(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueBarPainter extends CustomPainter {
  const _HueBarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const colors = <Color>[
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(colors: colors).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ColorThumb extends StatelessWidget {
  const _ColorThumb();

  static const double _size = 24;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: _size,
        height: _size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: .circle,
            border: .all(color: VineTheme.whiteText, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
