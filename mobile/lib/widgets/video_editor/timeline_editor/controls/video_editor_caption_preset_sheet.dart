// ABOUTME: Bottom sheet for picking the caption style: built-in presets plus
// ABOUTME: a Custom tile that opens the user-defined style editor.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_style_preset.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/caption_style_preview.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_custom_style_sheet.dart';

/// The chosen caption style: a built-in preset or a user-defined custom style.
sealed class CaptionStyleSelection {
  const CaptionStyleSelection();
}

/// A built-in preset was chosen.
class CaptionPresetSelection extends CaptionStyleSelection {
  /// Creates a preset selection.
  const CaptionPresetSelection(this.presetId);

  /// The chosen preset id.
  final String presetId;
}

/// A user-defined custom style was chosen.
class CaptionCustomSelection extends CaptionStyleSelection {
  /// Creates a custom selection.
  const CaptionCustomSelection(this.style);

  /// The chosen custom style.
  final CaptionCustomStyle style;
}

/// Resolves the localized display name of the preset with [presetId].
String captionPresetDisplayName(AppLocalizations l10n, String presetId) =>
    switch (presetId) {
      'pop' => l10n.videoEditorCaptionsPresetPop,
      'zoom' => l10n.videoEditorCaptionsPresetZoom,
      'spring' => l10n.videoEditorCaptionsPresetSpring,
      'mono' => l10n.videoEditorCaptionsPresetMono,
      'headline' => l10n.videoEditorCaptionsPresetHeadline,
      'typewriter' => l10n.videoEditorCaptionsPresetTypewriter,
      'marker' => l10n.videoEditorCaptionsPresetMarker,
      'script' => l10n.videoEditorCaptionsPresetScript,
      'retro' => l10n.videoEditorCaptionsPresetRetro,
      'elegant' => l10n.videoEditorCaptionsPresetElegant,
      'bubble' => l10n.videoEditorCaptionsPresetBubble,
      'neon' => l10n.videoEditorCaptionsPresetNeon,
      'bold' => l10n.videoEditorCaptionsPresetBold,
      'dreamy' => l10n.videoEditorCaptionsPresetDreamy,
      'ocean' => l10n.videoEditorCaptionsPresetOcean,
      'sunny' => l10n.videoEditorCaptionsPresetSunny,
      'handwritten' => l10n.videoEditorCaptionsPresetHandwritten,
      'serif' => l10n.videoEditorCaptionsPresetSerif,
      'stamp' => l10n.videoEditorCaptionsPresetStamp,
      _ => l10n.videoEditorCaptionsPresetClassic,
    };

/// Shows the caption style picker; resolves with the chosen selection (a
/// built-in preset or a custom style), or `null` when dismissed.
///
/// [selectedId] highlights the active preset; [currentCustomStyle] seeds the
/// Custom tile and its editor when a custom style is already active.
Future<CaptionStyleSelection?> showCaptionStyleSheet(
  BuildContext context, {
  required String selectedId,
  CaptionCustomStyle? currentCustomStyle,
}) {
  return VineBottomSheet.show<CaptionStyleSelection>(
    context: context,
    title: Text(context.l10n.videoEditorCaptionsPresetTitle),
    buildScrollBody: (scrollController) => CaptionPresetPickerView(
      selectedId: selectedId,
      currentCustomStyle: currentCustomStyle,
      scrollController: scrollController,
    ),
  );
}

/// Vertically scrolling style grid: a Custom tile plus built-in presets.
class CaptionPresetPickerView extends StatefulWidget {
  /// Creates the picker with the currently selected style highlighted.
  const CaptionPresetPickerView({
    required this.selectedId,
    this.currentCustomStyle,
    this.scrollController,
    super.key,
  });

  /// The currently selected preset id (ignored when a custom style is active).
  final String selectedId;

  /// The active custom style, when one is set.
  final CaptionCustomStyle? currentCustomStyle;

  /// Sheet-provided controller so drag-to-resize keeps working.
  final ScrollController? scrollController;

  @override
  State<CaptionPresetPickerView> createState() =>
      _CaptionPresetPickerViewState();
}

class _CaptionPresetPickerViewState extends State<CaptionPresetPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// One preview loop: cue A enters/holds/leaves, then cue B, then repeat.
  static const _loopMs = 3200;

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

  Future<void> _openCustomEditor() async {
    final style = await showCaptionCustomStyleSheet(
      context,
      initial: widget.currentCustomStyle ?? CaptionCustomStyle.initial(),
    );
    if (style != null && mounted) {
      Navigator.of(context).pop(CaptionCustomSelection(style));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasCustom = widget.currentCustomStyle != null;
    return GridView.builder(
      controller: widget.scrollController,
      padding: .fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      // The Custom tile leads; built-in presets follow.
      itemCount: CaptionStylePreset.presets.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CustomStyleTile(
            label: l10n.videoEditorCaptionsPresetCustom,
            selected: hasCustom,
            onTap: _openCustomEditor,
          );
        }
        final preset = CaptionStylePreset.presets[index - 1];
        final label = captionPresetDisplayName(l10n, preset.id);
        return _StyleTile(
          style: preset.style,
          label: label,
          selected: !hasCustom && preset.id == widget.selectedId,
          controller: _controller,
          loopMs: _loopMs,
          onTap: () =>
              Navigator.of(context).pop(CaptionPresetSelection(preset.id)),
        );
      },
    );
  }
}

/// Shared tile frame: a bordered, selectable preview area over a caption
/// label. [preview] fills the framed area.
class _CaptionTileFrame extends StatelessWidget {
  const _CaptionTileFrame({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    // Same semantics shape as the layer-animation picker tiles: one button
    // node, preview and caption excluded so the label isn't announced twice.
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            spacing: 6,
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? context.vineColors.accentPositive
                          : VineTheme.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: ExcludeSemantics(child: preview),
                    ),
                  ),
                ),
              ),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: VineTheme.labelSmallFont(
                    color: selected
                        ? context.vineColors.accentPositive
                        : context.vineColors.mutedText,
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

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.style,
    required this.label,
    required this.selected,
    required this.controller,
    required this.loopMs,
    required this.onTap,
  });

  final CaptionStyle style;
  final String label;
  final bool selected;
  final AnimationController controller;
  final int loopMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CaptionTileFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      preview: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: controller,
          builder: (context, _) => CaptionStylePreview(
            style: style,
            loopValue: controller.value,
            loopMs: loopMs,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        ),
      ),
    );
  }
}

/// The Custom tile: a static edit affordance (no animated preview).
class _CustomStyleTile extends StatelessWidget {
  const _CustomStyleTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _CaptionTileFrame(
      label: label,
      selected: selected,
      onTap: onTap,
      // Fixed colors in both appearance modes: this tile stands in for a
      // preset preview, so it repeats the dark stage `CaptionStylePreview`
      // paints its own previews on rather than following the palette.
      preview: const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VineTheme.primaryDarkGreen, VineTheme.surfaceBackground],
          ),
        ),
        child: Center(
          child: DivineIcon(
            icon: DivineIconName.pencilSimple,
            color: VineTheme.lightText,
            size: 32,
          ),
        ),
      ),
    );
  }
}
