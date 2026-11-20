// ABOUTME: Control panel of the chroma-key screen: what replaces the colour and
// ABOUTME: how strongly, with presets, colour and edge tuning folded away.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_detect_row.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_shader.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;
import 'package:unified_logger/unified_logger.dart';

/// What the clip being keyed sits on, which decides what an empty backdrop
/// means and which backdrops can be offered.
enum ChromaKeySurface {
  /// The clip is the timeline track, and the key is baked into its file.
  ///
  /// Nothing lies below the track, so a transparent key flattens to black in
  /// the H.264 file. The panel offers that choice as "Black" and the preview
  /// paints it black, so neither promises a see-through cutout the export
  /// cannot keep. A library clip can be put behind the subject by baking a
  /// second track under it.
  track,

  /// The clip is a layer over the editor canvas, and the key is applied live.
  ///
  /// A transparent key lets whatever is underneath show through, which is the
  /// point of detaching a green-screen clip. A library clip is not offered:
  /// the key goes on the layer at export rather than into a file, and a layer
  /// has no second track of its own to play a backdrop on.
  canvas,
}

/// Everything below the preview on the chroma-key screen, driven by the
/// [ChromaKeyEditorCubit] above it.
///
/// The screen picks the colour from a tap on its preview, so Auto-detect sits
/// with the presets under Fine-tune: it already ran when the screen opened.
class ChromaKeyControls extends StatelessWidget {
  const ChromaKeyControls({
    required this.onPickBackground,
    this.surface = ChromaKeySurface.track,
    super.key,
  });

  /// Opens the picker for the chosen background type. Owned by the screen
  /// because an image is shot with the camera and a video comes from the clip
  /// library.
  final ValueChanged<ClipChromaKeyBackgroundType> onPickBackground;

  /// What the keyed clip sits on. See [ChromaKeySurface].
  final ChromaKeySurface surface;

  @override
  Widget build(BuildContext context) {
    final (chromaKey, detectionStatus) = context.select(
      (ChromaKeyEditorCubit c) => (c.state.chromaKey, c.state.detectionStatus),
    );
    final cubit = context.read<ChromaKeyEditorCubit>();
    final l10n = context.l10n;

    return ChromaKeyControlsPanel(
      chromaKey: chromaKey,
      isDetecting: detectionStatus == ChromaKeyDetectionStatus.detecting,
      detectionNotice: switch (detectionStatus) {
        ChromaKeyDetectionStatus.failure =>
          l10n.videoEditorChromaKeyDetectFailed,
        ChromaKeyDetectionStatus.timedOut =>
          l10n.videoEditorChromaKeyDetectTimedOut,
        ChromaKeyDetectionStatus.idle ||
        ChromaKeyDetectionStatus.detecting => null,
      },
      showSurfaceHint: detectionStatus == ChromaKeyDetectionStatus.failure,
      onDetect: cubit.detectFromFootage,
      onGreenPreset: cubit.useGreenScreenPreset,
      onBluePreset: cubit.useBlueScreenPreset,
      onKeyColorChanged: cubit.setKeyColor,
      onSimilarityChanged: cubit.setSimilarity,
      onSmoothnessChanged: cubit.setSmoothness,
      onSpillChanged: cubit.setSpill,
      onPickBackground: onPickBackground,
      surface: surface,
    );
  }
}

/// The chroma-key settings panel, free of any particular state holder.
///
/// Shared by the editor's chroma key screen, where [ChromaKeyControls] binds
/// it to [ChromaKeyEditorCubit], and the recorder's color mask, which binds
/// it to the recorder so the key can be tuned against the live camera.
///
/// Up front it asks only what most people came for: what replaces the colour,
/// and how strongly. Everything that tunes the key itself — Auto-detect, the
/// presets, the colour swatch, the edge and the tint — waits under Fine-tune,
/// in the editor and the recorder alike.
class ChromaKeyControlsPanel extends StatelessWidget {
  const ChromaKeyControlsPanel({
    required this.chromaKey,
    required this.isDetecting,
    required this.onDetect,
    required this.onGreenPreset,
    required this.onBluePreset,
    required this.onKeyColorChanged,
    required this.onSimilarityChanged,
    required this.onSmoothnessChanged,
    required this.onSpillChanged,
    required this.onPickBackground,
    this.surface = ChromaKeySurface.track,
    this.detectionNotice,
    this.showSurfaceHint = false,
    this.scrollController,
    super.key,
  });

  /// The key as currently configured.
  final ClipChromaKey chromaKey;

  /// Whether a measurement is running. Holds Auto-detect only: presets and
  /// hand edits stay live and overtake it.
  final bool isDetecting;

  /// Measures the screen and adopts its colour and amount.
  final VoidCallback onDetect;

  /// Adopts the green-screen preset, keeping the backdrop.
  final VoidCallback onGreenPreset;

  /// Adopts the blue-screen preset, keeping the backdrop.
  final VoidCallback onBluePreset;

  final ValueChanged<Color> onKeyColorChanged;
  final ValueChanged<double> onSimilarityChanged;
  final ValueChanged<double> onSmoothnessChanged;
  final ValueChanged<double> onSpillChanged;

  /// Opens the picker for the chosen background type.
  final ValueChanged<ClipChromaKeyBackgroundType> onPickBackground;

  /// What the keyed clip sits on. See [ChromaKeySurface].
  final ChromaKeySurface surface;

  /// Why the last measurement came back empty, shown inline at the top of the
  /// panel, or `null` for nothing to report.
  final String? detectionNotice;

  /// Whether to say what a background swap needs from the footage.
  ///
  /// Only after a measurement found no screen: that is when the tip explains
  /// something the user just saw go wrong (#8547), rather than standing in
  /// the way of every footage that keys fine.
  final bool showSurfaceHint;

  /// Drives the panel's scroll view, for a host that has to own it — a
  /// draggable sheet resizes off the same controller its content scrolls.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final notice = detectionNotice;
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: _sectionSpacing,
        children: [
          // One slot for every notice. They are usually all absent, and an
          // absent child in a `spacing` column still costs a full gap — which
          // left the panel's first line floating away from what sits above it.
          _Gutter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _PreviewUnavailableNotice(),
                if (notice != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _sectionSpacing),
                    child: _InfoRow(text: notice),
                  ),
                if (showSurfaceHint)
                  Padding(
                    padding: const EdgeInsets.only(bottom: _sectionSpacing),
                    child: _InfoRow(
                      text: context.l10n.videoEditorChromaKeySurfaceHint,
                    ),
                  ),
              ],
            ),
          ),
          _Gutter(
            child: _BackgroundSection(
              type: chromaKey.backgroundType,
              onPickBackground: onPickBackground,
              surface: surface,
            ),
          ),
          _Gutter(
            child: _LabeledSlider(
              label: context.l10n.videoEditorChromaKeyAmountLabel,
              hint: context.l10n.videoEditorChromaKeyAmountHint,
              value: chromaKey.key.similarity,
              min: ChromaKeyEditorCubit.minSimilarity,
              onChanged: onSimilarityChanged,
            ),
          ),
          _Gutter(
            child: _FineTuneSection(
              chromaKey: chromaKey.key,
              isDetecting: isDetecting,
              onDetect: onDetect,
              onGreenPreset: onGreenPreset,
              onBluePreset: onBluePreset,
              onKeyColorChanged: onKeyColorChanged,
              onSmoothnessChanged: onSmoothnessChanged,
              onSpillChanged: onSpillChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Distance between the panel's content and the screen edges.
const double _gutter = 16;

/// Vertical gap between the panel's sections.
const double _sectionSpacing = 20;

/// Insets a row to the panel's side [_gutter].
///
/// Carried per row rather than by the enclosing scroll view so that a
/// horizontally scrolling row can opt out and run edge to edge.
class _Gutter extends StatelessWidget {
  const _Gutter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _gutter),
      child: child,
    );
  }
}

/// Says so when the renderer cannot show the key applied.
///
/// Without this the preview just quietly shows the unkeyed video, which reads
/// as "the colour mask does nothing" rather than "you can't see it yet".
class _PreviewUnavailableNotice extends StatefulWidget {
  const _PreviewUnavailableNotice();

  @override
  State<_PreviewUnavailableNotice> createState() =>
      _PreviewUnavailableNoticeState();
}

class _PreviewUnavailableNoticeState extends State<_PreviewUnavailableNotice> {
  bool _loadAttempted = ChromaKeyShader.isSupported;

  @override
  void initState() {
    super.initState();
    if (!ChromaKeyShader.isBackendSupported || ChromaKeyShader.isSupported) {
      return;
    }
    runDetached(
      ChromaKeyShader.ensureLoaded().then((_) {
        if (mounted) setState(() => _loadAttempted = true);
      }),
      'load chroma-key shader',
      logName: 'ChromaKeyControls',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ChromaKeyShader.isBackendSupported &&
        (!_loadAttempted || ChromaKeyShader.isSupported)) {
      return const SizedBox.shrink();
    }

    // Carries the section gap itself: it shares a slot with the other notices
    // so that it costs no space at all when it is not shown.
    return Padding(
      padding: const EdgeInsets.only(bottom: _sectionSpacing),
      child: _InfoRow(
        text: context.l10n.videoEditorChromaKeyPreviewUnavailable,
      ),
    );
  }
}

/// The panel's shared info treatment: an info glyph beside one line of
/// secondary copy.
///
/// Carries the preview-unavailable notice, a failed measurement, and what a
/// background swap needs from the footage.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.text});

  /// What `DivineIcon` draws at its default size, before text scaling.
  static const double _glyphSize = 24;

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = VineTheme.bodySmallFont(
      color: context.vineColors.onSurfaceVariant,
    );

    // The glyph is taller than one line of the copy it labels — 24 against a
    // 16dp line box — so aligning both to the top leaves the text riding
    // above the glyph's optical centre. Same correction `DivineInfoCard`
    // makes for the same reason.
    final lineHeight =
        MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14) *
        (style.height ?? 1.2);
    final overhang =
        (DivineIcon.scaleSize(context, _glyphSize) - lineHeight) / 2;

    return Row(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: overhang < 0 ? -overhang : 0),
          child: DivineIcon(
            icon: .info,
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: overhang > 0 ? overhang : 0),
            child: Text(text, style: style),
          ),
        ),
      ],
    );
  }
}

/// The key's own settings, folded away behind one row until asked for.
///
/// Open or closed is the panel's own business: nothing outside it reads the
/// state, and it starts closed every time the panel opens.
class _FineTuneSection extends StatefulWidget {
  const _FineTuneSection({
    required this.chromaKey,
    required this.isDetecting,
    required this.onDetect,
    required this.onGreenPreset,
    required this.onBluePreset,
    required this.onKeyColorChanged,
    required this.onSmoothnessChanged,
    required this.onSpillChanged,
  });

  final ChromaKey chromaKey;
  final bool isDetecting;

  final VoidCallback onDetect;
  final VoidCallback onGreenPreset;
  final VoidCallback onBluePreset;
  final ValueChanged<Color> onKeyColorChanged;
  final ValueChanged<double> onSmoothnessChanged;
  final ValueChanged<double> onSpillChanged;

  @override
  State<_FineTuneSection> createState() => _FineTuneSectionState();
}

class _FineTuneSectionState extends State<_FineTuneSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = widget.chromaKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FineTuneHeader(
          isExpanded: _isExpanded,
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
        AnimatedReveal(
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 16,
                    children: [
                      ChromaKeyDetectRow(
                        isDetecting: widget.isDetecting,
                        onDetect: widget.onDetect,
                        onGreenPreset: widget.onGreenPreset,
                        onBluePreset: widget.onBluePreset,
                      ),
                      _ScreenColorRow(
                        color: key.color,
                        onColorChanged: widget.onKeyColorChanged,
                      ),
                      _LabeledSlider(
                        label: l10n.videoEditorChromaKeyEdgeLabel,
                        hint: l10n.videoEditorChromaKeyEdgeHint,
                        showHint: true,
                        value: key.smoothness,
                        onChanged: widget.onSmoothnessChanged,
                      ),
                      _LabeledSlider(
                        label: l10n.videoEditorChromaKeySpillLabel,
                        hint: l10n.videoEditorChromaKeySpillHint,
                        showHint: true,
                        value: key.spill,
                        onChanged: widget.onSpillChanged,
                      ),
                    ],
                  ),
                )
              : null,
        ),
      ],
    );
  }
}

/// The row that opens and closes Fine-tune.
class _FineTuneHeader extends StatelessWidget {
  const _FineTuneHeader({required this.isExpanded, required this.onPressed});

  final bool isExpanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.videoEditorChromaKeyFineTune;
    return Semantics(
      button: true,
      expanded: isExpanded,
      label: label,
      excludeSemantics: true,
      child: _TileSurface(
        onTap: onPressed,
        decoration: BoxDecoration(
          borderRadius: _tileRadius,
          border: Border.all(color: context.vineColors.outlineMuted),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                ),
                DivineIcon(
                  icon: isExpanded ? .caretUp : .caretDown,
                  color: context.vineColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour being removed, with a swatch that opens the picker.
class _ScreenColorRow extends StatelessWidget {
  const _ScreenColorRow({required this.color, required this.onColorChanged});

  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.videoEditorChromaKeyScreenColorLabel,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
        ),
        _ColorSwatchButton(
          color: color,
          semanticLabel: context.l10n.videoEditorChromaKeyScreenColorLabel,
          onPressed: () async {
            final picked = await showFullColorPicker(
              context,
              initialColor: color,
            );
            if (picked != null) onColorChanged(picked);
          },
        ),
      ],
    );
  }
}

/// A tappable colour swatch.
class _ColorSwatchButton extends StatelessWidget {
  const _ColorSwatchButton({
    required this.color,
    required this.semanticLabel,
    required this.onPressed,
  });

  final Color color;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: VineTheme.borderWhite25, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.showHint = false,
    this.min = 0,
  });

  final String label;

  /// What the slider does. Always part of its semantic label; drawn under
  /// the label only when [showHint] is set.
  final String hint;

  /// Whether [hint] is drawn, for a slider whose label alone would not say
  /// what it does.
  final bool showHint;

  final double value;
  final double min;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VineTheme.bodyMediumFont(color: context.vineColors.onSurface),
        ),
        if (showHint)
          // The slider's semantic label already carries the hint.
          ExcludeSemantics(
            child: Text(
              hint,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
        DivineSlider(
          value: value.clamp(min, 1),
          min: min,
          semanticLabel: '$label. $hint',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Picks what fills the area the key removed.
class _BackgroundSection extends StatelessWidget {
  const _BackgroundSection({
    required this.type,
    required this.onPickBackground,
    required this.surface,
  });

  /// The background currently chosen.
  final ClipChromaKeyBackgroundType type;
  final ValueChanged<ClipChromaKeyBackgroundType> onPickBackground;
  final ChromaKeySurface surface;

  /// The backdrops that can be offered on [surface].
  List<ClipChromaKeyBackgroundType> get _options => switch (surface) {
    ChromaKeySurface.track => ClipChromaKeyBackgroundType.values,
    ChromaKeySurface.canvas =>
      ClipChromaKeyBackgroundType.values
          .where((type) => type != ClipChromaKeyBackgroundType.video)
          .toList(growable: false),
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(
          context.l10n.videoEditorChromaKeyBackgroundLabel,
          style: VineTheme.titleSmallFont(color: context.vineColors.onSurface),
        ),
        // Equal tiles rather than chips sized to their labels: four short
        // choices read as one decision, and none of them scrolls out of view.
        Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final option in _options)
              Expanded(
                child: _BackgroundTile(
                  option: option,
                  surface: surface,
                  isSelected: option == type,
                  onPressed: () => onPickBackground(option),
                ),
              ),
          ],
        ),
        // On the canvas the cutout really is see-through, which is worth
        // saying: the preview's checkerboard alone reads as a placeholder.
        if (surface == ChromaKeySurface.canvas &&
            type == ClipChromaKeyBackgroundType.transparent)
          Text(
            context.l10n.videoEditorChromaKeyCanvasTransparentHint,
            // `onSurfaceMuted` is only 3.05:1 on the light canvas, so this
            // hint takes the variant token instead of the muted one.
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Corner rounding of the background tiles and the Fine-tune row.
const BorderRadius _tileRadius = BorderRadius.all(Radius.circular(12));

/// One background choice: its icon over its name.
class _BackgroundTile extends StatelessWidget {
  const _BackgroundTile({
    required this.option,
    required this.surface,
    required this.isSelected,
    required this.onPressed,
  });

  final ClipChromaKeyBackgroundType option;
  final ChromaKeySurface surface;
  final bool isSelected;
  final VoidCallback onPressed;

  /// Border width of the selected tile. Unselected tiles pad by the
  /// difference, so selecting one does not nudge its content.
  static const double _selectedBorderWidth = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final (label, icon) = switch (option) {
      // Named for what the export shows: on the track an empty backdrop is
      // black, and only on the canvas does something else show through.
      ClipChromaKeyBackgroundType.transparent => (
        switch (surface) {
          ChromaKeySurface.track => l10n.videoEditorChromaKeyBackgroundBlack,
          ChromaKeySurface.canvas => l10n.videoEditorChromaKeyBackgroundNone,
        },
        DivineIconName.squareDuo,
      ),
      ClipChromaKeyBackgroundType.color => (
        l10n.videoEditorChromaKeyBackgroundColor,
        DivineIconName.paintBucket,
      ),
      // The photo is shot with the camera — see
      // `captureChromaKeyBackdropImage` — so the tile shows one.
      ClipChromaKeyBackgroundType.image => (
        l10n.videoEditorChromaKeyBackgroundImage,
        DivineIconName.camera,
      ),
      ClipChromaKeyBackgroundType.video => (
        l10n.videoEditorChromaKeyBackgroundVideo,
        DivineIconName.filmSlate,
      ),
    };
    final foreground = isSelected ? colors.accentBrand : colors.onSurface;
    final borderWidth = isSelected ? _selectedBorderWidth : 1.0;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: _TileSurface(
        onTap: onPressed,
        decoration: BoxDecoration(
          color: isSelected ? colors.controlSelectedFill : colors.controlFill,
          borderRadius: _tileRadius,
          border: Border.all(
            color: isSelected ? colors.accentBrand : colors.outlineMuted,
            width: borderWidth,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4 + _selectedBorderWidth - borderWidth,
              vertical: 8 + _selectedBorderWidth - borderWidth,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                DivineIcon(icon: icon, color: foreground),
                DivineWordFitText(
                  label,
                  textAlign: TextAlign.center,
                  style: VineTheme.labelLargeFont(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded, decorated tap target with its ripple drawn over [decoration].
///
/// `Ink` would paint the decoration onto the nearest `Material`, which in a
/// bottom sheet lies under the sheet's own background and never shows. So the
/// decoration is a plain box, and a transparent `Material` on top of it
/// carries the ripple.
class _TileSurface extends StatelessWidget {
  const _TileSurface({
    required this.decoration,
    required this.onTap,
    required this.child,
  });

  final BoxDecoration decoration;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        shape: const RoundedRectangleBorder(borderRadius: _tileRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}
