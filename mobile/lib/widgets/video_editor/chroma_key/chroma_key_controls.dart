// ABOUTME: Control panel of the chroma-key screen: auto-detect, screen colour,
// ABOUTME: the three tolerance sliders, and the background choice.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_shader.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';

/// Everything below the preview on the chroma-key screen.
class ChromaKeyControls extends StatelessWidget {
  const ChromaKeyControls({required this.onPickBackground, super.key});

  /// Opens the picker for [type]. Owned by the screen because an image is shot
  /// with the camera and a video comes from the clip library.
  final ValueChanged<ClipChromaKeyBackgroundType> onPickBackground;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          const _Gutter(child: _PreviewUnavailableNotice()),
          const _Gutter(child: _SurfaceRequirementHint()),
          const _Gutter(child: _DetectRow()),
          const _Gutter(child: _ScreenColorRow()),
          const _Gutter(child: _ToleranceSliders()),
          // Unpadded: the section insets its own text but lets the chips
          // scroll past the gutter to the screen edge.
          _BackgroundSection(onPickBackground: onPickBackground),
        ],
      ),
    );
  }
}

/// Distance between the panel's content and the screen edges.
const double _gutter = 16;

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

/// States the feature's one prerequisite on entry to the controls.
///
/// The requirement used to surface only as a failed detect, after the clip was
/// already shot — and it named a screen, which most people do not own. Saying
/// a wall works is what turns the biggest bounce point into onboarding
/// (#8547).
class _SurfaceRequirementHint extends StatelessWidget {
  const _SurfaceRequirementHint();

  @override
  Widget build(BuildContext context) {
    return _InfoRow(text: context.l10n.videoEditorChromaKeySurfaceHint);
  }
}

/// Says so when the renderer cannot show the key applied.
///
/// Without this the preview just quietly shows the unkeyed video, which reads
/// as "the green screen does nothing" rather than "you can't see it yet".
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
    ChromaKeyShader.ensureLoaded().then((_) {
      if (mounted) setState(() => _loadAttempted = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ChromaKeyShader.isBackendSupported &&
        (!_loadAttempted || ChromaKeyShader.isSupported)) {
      return const SizedBox.shrink();
    }

    return _InfoRow(text: context.l10n.videoEditorChromaKeyPreviewUnavailable);
  }
}

/// The panel's shared info treatment: an info glyph beside one line of
/// secondary copy.
///
/// Carries both the standing surface prerequisite and the conditional
/// preview-unavailable notice.
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

/// Auto-detect plus the two screen presets.
class _DetectRow extends StatelessWidget {
  const _DetectRow();

  @override
  Widget build(BuildContext context) {
    final isDetecting = context.select(
      (ChromaKeyEditorCubit c) => c.state.isDetecting,
    );
    final cubit = context.read<ChromaKeyEditorCubit>();

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: DivineButton(
            label: context.l10n.videoEditorChromaKeyAutoDetect,
            leadingIcon: .sparkle,
            size: .small,
            isLoading: isDetecting,
            onPressed: isDetecting ? null : cubit.detectFromFootage,
          ),
        ),
        DivineButton(
          label: context.l10n.videoEditorChromaKeyPresetGreen,
          type: .secondary,
          size: .small,
          onPressed: isDetecting ? null : cubit.useGreenScreenPreset,
        ),
        DivineButton(
          label: context.l10n.videoEditorChromaKeyPresetBlue,
          type: .secondary,
          size: .small,
          onPressed: isDetecting ? null : cubit.useBlueScreenPreset,
        ),
      ],
    );
  }
}

/// The colour being removed, with a swatch that opens the picker.
class _ScreenColorRow extends StatelessWidget {
  const _ScreenColorRow();

  @override
  Widget build(BuildContext context) {
    final color = context.select(
      (ChromaKeyEditorCubit c) => c.state.chromaKey.key.color,
    );
    final cubit = context.read<ChromaKeyEditorCubit>();

    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.videoEditorChromaKeyScreenColorLabel,
            style: VineTheme.titleSmallFont(
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
            if (picked != null) cubit.setKeyColor(picked);
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

/// The three tolerance sliders.
class _ToleranceSliders extends StatelessWidget {
  const _ToleranceSliders();

  @override
  Widget build(BuildContext context) {
    final key = context.select(
      (ChromaKeyEditorCubit c) => c.state.chromaKey.key,
    );
    final cubit = context.read<ChromaKeyEditorCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeyAmountLabel,
          hint: context.l10n.videoEditorChromaKeyAmountHint,
          value: key.similarity,
          min: ChromaKeyEditorCubit.minSimilarity,
          onChanged: cubit.setSimilarity,
        ),
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeyEdgeLabel,
          hint: context.l10n.videoEditorChromaKeyEdgeHint,
          value: key.smoothness,
          onChanged: cubit.setSmoothness,
        ),
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeySpillLabel,
          hint: context.l10n.videoEditorChromaKeySpillHint,
          value: key.spill,
          onChanged: cubit.setSpill,
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.min = 0,
  });

  final String label;
  final String hint;
  final double value;
  final double min;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
              '${(value * 100).round()}',
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ],
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
  const _BackgroundSection({required this.onPickBackground});

  final ValueChanged<ClipChromaKeyBackgroundType> onPickBackground;

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (ChromaKeyEditorCubit c) => c.state.backgroundType,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        _Gutter(
          child: Text(
            context.l10n.videoEditorChromaKeyBackgroundLabel,
            style: VineTheme.titleSmallFont(
              color: context.vineColors.onSurface,
            ),
          ),
        ),
        // Each chip takes the width its label needs rather than an equal
        // quarter, which is what kept the longest one from being ellipsised.
        // Scrolling is the fallback for narrow screens and for locales whose
        // labels run longer than English; the gutter sits inside the viewport
        // so the row starts at the same inset as the rest of the panel but
        // still scrolls all the way to the screen edge.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _gutter),
          child: Row(
            spacing: 8,
            children: [
              for (final option in ClipChromaKeyBackgroundType.values)
                _BackgroundChip(
                  option: option,
                  isSelected: option == type,
                  onPressed: () => onPickBackground(option),
                ),
            ],
          ),
        ),
        if (type == ClipChromaKeyBackgroundType.transparent)
          _Gutter(
            child: Text(
              context.l10n.videoEditorChromaKeyTransparentHint,
              // `onSurfaceMuted` is only 3.05:1 on the light canvas, so this
              // hint takes the variant token instead of the muted one.
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _BackgroundChip extends StatelessWidget {
  const _BackgroundChip({
    required this.option,
    required this.isSelected,
    required this.onPressed,
  });

  final ClipChromaKeyBackgroundType option;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, icon) = switch (option) {
      ClipChromaKeyBackgroundType.transparent => (
        l10n.videoEditorChromaKeyBackgroundNone,
        DivineIconName.textBgTransparent,
      ),
      ClipChromaKeyBackgroundType.color => (
        l10n.videoEditorChromaKeyBackgroundColor,
        DivineIconName.paintBucket,
      ),
      ClipChromaKeyBackgroundType.image => (
        l10n.videoEditorChromaKeyBackgroundImage,
        DivineIconName.image,
      ),
      ClipChromaKeyBackgroundType.video => (
        l10n.videoEditorChromaKeyBackgroundVideo,
        DivineIconName.filmSlate,
      ),
    };

    return DivineButton(
      label: label,
      leadingIcon: icon,
      size: .small,
      type: isSelected ? .primary : .secondary,
      onPressed: onPressed,
    );
  }
}
