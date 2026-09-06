// ABOUTME: Bottom sheet to build a user-defined caption style: font, colors,
// ABOUTME: background pill, and animation, with a looped live preview.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/color_swatch_button.dart';
import 'package:openvine/widgets/video_editor/text_editor/video_editor_text_extensions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/caption_style_preview.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_font_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

/// Shows the custom caption-style editor seeded with [initial]; resolves with
/// the edited style, or `null` when dismissed.
Future<CaptionCustomStyle?> showCaptionCustomStyleSheet(
  BuildContext context, {
  required CaptionCustomStyle initial,
}) {
  return VineBottomSheet.show<CaptionCustomStyle>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.6,
    title: Text(
      context.l10n.videoEditorCaptionsCustomStyleTitle,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    ),
    buildScrollBody: (scrollController) => _CaptionCustomStyleView(
      initial: initial,
      scrollController: scrollController,
    ),
  );
}

class _CaptionCustomStyleView extends StatefulWidget {
  const _CaptionCustomStyleView({
    required this.initial,
    required this.scrollController,
  });

  final CaptionCustomStyle initial;
  final ScrollController scrollController;

  @override
  State<_CaptionCustomStyleView> createState() =>
      _CaptionCustomStyleViewState();
}

class _CaptionCustomStyleViewState extends State<_CaptionCustomStyleView>
    with SingleTickerProviderStateMixin {
  late CaptionCustomStyle _style = widget.initial;
  late final AnimationController _controller;

  static const _loopMs = 2400;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _loopMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  void _syncAnimation() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFont(int currentIndex) async {
    final index = await showCaptionFontSheet(
      context,
      selectedIndex: currentIndex,
    );
    if (index != null && mounted) {
      setState(() => _style = _style.copyWith(fontIndex: index));
    }
  }

  /// Opens the HSV picker (same one the text editor uses); [apply] mutates the
  /// working style with the picked color.
  Future<void> _pickColor(
    Color initial,
    CaptionCustomStyle Function(Color) apply,
  ) async {
    final color = await showFullColorPicker(context, initialColor: initial);
    if (color != null && mounted) {
      setState(() => _style = apply(color));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasBackground = _style.hasBackground;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              ExcludeSemantics(
                child: _Preview(
                  style: _style,
                  controller: _controller,
                  loopMs: _loopMs,
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.videoEditorCaptionsCustomFont),
              _FontField(index: _style.fontIndex, onChanged: _pickFont),
              const SizedBox(height: 20),
              _SectionLabel(l10n.videoEditorCaptionsCustomTextColor),
              _ColorRow(
                selected: _style.color,
                onSelected: (color) =>
                    setState(() => _style = _style.copyWith(color: color)),
                onCustom: () => _pickColor(
                  _style.color,
                  (color) => _style.copyWith(color: color),
                ),
              ),
              const SizedBox(height: 16),
              DivineRowCheckbox(
                state: hasBackground
                    ? DivineCheckboxState.selected
                    : DivineCheckboxState.unselected,
                onChanged: (checked) => setState(() {
                  _style = _style.copyWith(
                    colorMode: checked
                        ? LayerBackgroundMode.backgroundAndColor
                        : LayerBackgroundMode.onlyColor,
                  );
                }),
                label: Text(
                  l10n.videoEditorCaptionsCustomBackground,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              if (hasBackground) ...[
                const SizedBox(height: 16),
                _SectionLabel(l10n.videoEditorCaptionsCustomBackgroundColor),
                _ColorRow(
                  selected: _style.background,
                  onSelected: (color) => setState(
                    () => _style = _style.copyWith(background: color),
                  ),
                  onCustom: () => _pickColor(
                    _style.background,
                    (color) => _style.copyWith(background: color),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel(l10n.videoEditorCaptionsCustomAnimation),
              _AnimationRow(
                selected: _style.animation,
                onSelected: (animation) => setState(
                  () => _style = _style.copyWith(animation: animation),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 2,
          thickness: 2,
          color: context.vineColors.surfaceContainer,
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: DivineButton(
                    label: l10n.commonCancel,
                    type: .secondary,
                    onPressed: () =>
                        Navigator.of(context).pop<CaptionCustomStyle>(),
                  ),
                ),
                Expanded(
                  child: DivineButton(
                    label: l10n.videoEditorCaptionsCustomApply,
                    onPressed: () =>
                        Navigator.of(context).pop<CaptionCustomStyle>(_style),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.style,
    required this.controller,
    required this.loopMs,
  });

  final CaptionCustomStyle style;
  final AnimationController controller;
  final int loopMs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: controller,
            builder: (context, _) => CaptionStylePreview(
              style: style.resolve(),
              loopValue: controller.value,
              loopMs: loopMs,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              fontSizeFactor: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: VineTheme.labelMediumFont(
          color: context.vineColors.secondaryText,
        ),
      ),
    );
  }
}

/// Trigger row showing the current font (in its own face); tapping opens the
/// full font list, mirroring the text editor's font selector.
class _FontField extends StatelessWidget {
  const _FontField({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final font = VideoEditorConstants.textFonts[index];
    return Semantics(
      button: true,
      value: font.localizedDisplayName(l10n),
      child: GestureDetector(
        onTap: () => onChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Row(
            spacing: 8,
            children: [
              Expanded(
                child: Text(
                  font.localizedDisplayName(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: font(
                    fontSize: 20,
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
              DivineIcon(
                icon: DivineIconName.caretDown,
                color: context.vineColors.accentPositive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  const _ColorRow({
    required this.selected,
    required this.onSelected,
    required this.onCustom,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final onPalette = VideoEditorConstants.colors.any(
      (c) => c.toARGB32() == selected.toARGB32(),
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // A custom (non-palette) color is shown selected on the picker swatch.
        _ColorSwatch(
          isCustom: true,
          color: selected,
          selected: !onPalette,
          onTap: onCustom,
        ),
        for (final color in VideoEditorConstants.colors)
          _ColorSwatch(
            color: color,
            selected: color.toARGB32() == selected.toARGB32(),
            onTap: () => onSelected(color),
          ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.isCustom = false,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    // Same swatch treatment as the text editor's color control: a rounded
    // surfaceContainer tile framing the color circle, primary when selected.
    // The custom swatch shows a paint-brush over the current color.
    final rgbLabel = ColorSwatchButton.rgbSemanticLabel(context, color);
    final semanticLabel = isCustom
        ? context.l10n.videoEditorColorPickerSwatchSemanticLabel(
            context.l10n.videoEditorColorPickerSemanticLabel,
            rgbLabel,
          )
        : rgbLabel;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: isCustom
                  ? const Center(
                      child: DivineIcon(
                        icon: DivineIconName.paintBrush,
                        color: VineTheme.primary,
                        size: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimationRow extends StatelessWidget {
  const _AnimationRow({required this.selected, required this.onSelected});

  final CaptionAnimationStyle selected;
  final ValueChanged<CaptionAnimationStyle> onSelected;

  static String _label(AppLocalizations l10n, CaptionAnimationStyle style) =>
      switch (style) {
        CaptionAnimationStyle.none => l10n.videoEditorCaptionsAnimationNone,
        CaptionAnimationStyle.fade => l10n.videoEditorCaptionsAnimationFade,
        CaptionAnimationStyle.pop => l10n.videoEditorCaptionsAnimationPop,
        CaptionAnimationStyle.spring => l10n.videoEditorCaptionsAnimationSpring,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final style in CaptionAnimationStyle.values)
          _AnimationChip(
            label: _label(l10n, style),
            selected: style == selected,
            onTap: () => onSelected(style),
          ),
      ],
    );
  }
}

class _AnimationChip extends StatelessWidget {
  const _AnimationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.outlineMuted,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: selected
                  ? context.vineColors.accentPositive
                  : context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
