// ABOUTME: Control panel of the chroma-key screen: auto-detect, screen colour,
// ABOUTME: the three tolerance sliders, and the background choice.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/chroma_key/chroma_key_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_shader.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// What the clip being keyed sits on, which decides what "Nothing" behind the
/// subject means and which backdrops can be offered.
enum ChromaKeySurface {
  /// The clip is the timeline track, and the key is baked into its file.
  ///
  /// Nothing lies below the track, so a transparent key flattens to black in
  /// the H.264 file — which the panel warns about — and a library clip can be
  /// put behind the subject by baking a second track under it.
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
    final (chromaKey, isDetecting) = context.select(
      (ChromaKeyEditorCubit c) => (c.state.chromaKey, c.state.isDetecting),
    );
    final cubit = context.read<ChromaKeyEditorCubit>();

    return ChromaKeyControlsPanel(
      chromaKey: chromaKey,
      isDetecting: isDetecting,
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
/// it to [ChromaKeyEditorCubit], and the recorder's chroma key mode, which
/// binds it to the recorder so the key can be tuned against the live camera.
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

  /// Why the last measurement came back empty, shown inline above
  /// Auto-detect, or `null` for nothing to report.
  ///
  /// The editor reports it as a snackbar instead; the recorder's settings
  /// sheet shows it here.
  final String? detectionNotice;

  /// Drives the panel's scroll view, for a host that has to own it — a
  /// draggable sheet resizes off the same controller its content scrolls.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final notice = detectionNotice;
    return _PanelScope(
      panel: this,
      child: SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _sectionSpacing,
          children: [
            // One slot for both. The notice is usually absent, and an absent
            // child in a `spacing` column still costs a full gap — which left
            // the panel's first line floating away from whatever sits above
            // it.
            const _Gutter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PreviewUnavailableNotice(),
                  _SurfaceRequirementHint(),
                ],
              ),
            ),
            if (notice != null) _Gutter(child: _InfoRow(text: notice)),
            const _Gutter(child: _DetectRow()),
            const _Gutter(child: _ScreenColorRow()),
            const _Gutter(child: _ToleranceSliders()),
            // Unpadded: the section insets its own text but lets the chips
            // scroll past the gutter to the screen edge.
            const _BackgroundSection(),
          ],
        ),
      ),
    );
  }
}

/// The parts of the panel that show state, each rebuilt only when what it
/// shows changes.
enum _PanelPart { detect, color, tolerance, background }

/// Hands [panel]'s values to its parts.
///
/// A slider drag gives the panel a new key on every tick. The parts are
/// constant widgets that subscribe to their own [_PanelPart], so a tick
/// rebuilds the sliders rather than the presets, the swatch and the backdrop
/// chips with them.
class _PanelScope extends InheritedModel<_PanelPart> {
  const _PanelScope({required this.panel, required super.child});

  final ChromaKeyControlsPanel panel;

  /// The panel's values, rebuilding [context] when those of [part] change.
  static ChromaKeyControlsPanel watch(BuildContext context, _PanelPart part) =>
      InheritedModel.inheritFrom<_PanelScope>(context, aspect: part)!.panel;

  /// The panel's current values without subscribing, for a callback read
  /// when a control fires rather than when it was built.
  static ChromaKeyControlsPanel read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_PanelScope>()!.panel;

  @override
  bool updateShouldNotify(_PanelScope oldWidget) =>
      _PanelPart.values.any((part) => _changed(oldWidget, part));

  @override
  bool updateShouldNotifyDependent(
    _PanelScope oldWidget,
    Set<_PanelPart> dependencies,
  ) => dependencies.any((part) => _changed(oldWidget, part));

  bool _changed(_PanelScope oldWidget, _PanelPart part) {
    final old = oldWidget.panel;
    final key = panel.chromaKey.key;
    final oldKey = old.chromaKey.key;
    return switch (part) {
      _PanelPart.detect => panel.isDetecting != old.isDetecting,
      _PanelPart.color => key.color != oldKey.color,
      _PanelPart.tolerance =>
        key.similarity != oldKey.similarity ||
            key.smoothness != oldKey.smoothness ||
            key.spill != oldKey.spill,
      _PanelPart.background =>
        panel.chromaKey.backgroundType != old.chromaKey.backgroundType ||
            panel.surface != old.surface,
    };
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

/// Tells a first-time user what a background swap needs, on entry to the
/// controls.
///
/// That used to surface only as a failed detect, after the clip was already
/// shot (#8547). It is a tip for the classic use, not a definition of the
/// tool: the mask removes a colour wherever it appears (#8544).
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

    // Carries the section gap itself: it shares a slot with the surface hint
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
///
/// Only Auto-detect waits for a wanted measurement. The presets stay live,
/// like the swatch and the sliders below: someone who shot on blue should not
/// have to sit out the green measurement the panel started on its own. A
/// preset tapped while one runs writes it off instead — see
/// [ChromaKeyEditorState.isDetecting].
class _DetectRow extends StatelessWidget {
  const _DetectRow();

  @override
  Widget build(BuildContext context) {
    final isDetecting = _PanelScope.watch(
      context,
      _PanelPart.detect,
    ).isDetecting;

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: DivineButton(
            label: context.l10n.videoEditorChromaKeyAutoDetect,
            leadingIcon: .sparkle,
            size: .small,
            isLoading: isDetecting,
            onPressed: isDetecting
                ? null
                : () => _PanelScope.read(context).onDetect(),
          ),
        ),
        DivineButton(
          label: context.l10n.videoEditorChromaKeyPresetGreen,
          type: .secondary,
          size: .small,
          onPressed: () => _PanelScope.read(context).onGreenPreset(),
        ),
        DivineButton(
          label: context.l10n.videoEditorChromaKeyPresetBlue,
          type: .secondary,
          size: .small,
          onPressed: () => _PanelScope.read(context).onBluePreset(),
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
    final color = _PanelScope.watch(
      context,
      _PanelPart.color,
    ).chromaKey.key.color;

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
            final onColorChanged = _PanelScope.read(context).onKeyColorChanged;
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

/// The three tolerance sliders.
class _ToleranceSliders extends StatelessWidget {
  const _ToleranceSliders();

  @override
  Widget build(BuildContext context) {
    final key = _PanelScope.watch(context, _PanelPart.tolerance).chromaKey.key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeyAmountLabel,
          hint: context.l10n.videoEditorChromaKeyAmountHint,
          value: key.similarity,
          min: ChromaKeyEditorCubit.minSimilarity,
          onChanged: (value) =>
              _PanelScope.read(context).onSimilarityChanged(value),
        ),
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeyEdgeLabel,
          hint: context.l10n.videoEditorChromaKeyEdgeHint,
          value: key.smoothness,
          onChanged: (value) =>
              _PanelScope.read(context).onSmoothnessChanged(value),
        ),
        _LabeledSlider(
          label: context.l10n.videoEditorChromaKeySpillLabel,
          hint: context.l10n.videoEditorChromaKeySpillHint,
          value: key.spill,
          onChanged: (value) => _PanelScope.read(context).onSpillChanged(value),
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
  const _BackgroundSection();

  /// The backdrops that can be offered on [surface].
  static List<ClipChromaKeyBackgroundType> _optionsOn(
    ChromaKeySurface surface,
  ) => switch (surface) {
    ChromaKeySurface.track => ClipChromaKeyBackgroundType.values,
    ChromaKeySurface.canvas =>
      ClipChromaKeyBackgroundType.values
          .where((type) => type != ClipChromaKeyBackgroundType.video)
          .toList(growable: false),
  };

  @override
  Widget build(BuildContext context) {
    final panel = _PanelScope.watch(context, _PanelPart.background);
    final type = panel.chromaKey.backgroundType;
    final surface = panel.surface;

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
              for (final option in _optionsOn(surface))
                _BackgroundChip(
                  option: option,
                  isSelected: option == type,
                  onPressed: () =>
                      _PanelScope.read(context).onPickBackground(option),
                ),
            ],
          ),
        ),
        if (type == ClipChromaKeyBackgroundType.transparent)
          _Gutter(
            child: Text(
              // A warning on the track, where the removed area exports as
              // black; a reassurance on the canvas, where it really is
              // see-through.
              switch (surface) {
                ChromaKeySurface.track =>
                  context.l10n.videoEditorChromaKeyTransparentHint,
                ChromaKeySurface.canvas =>
                  context.l10n.videoEditorChromaKeyCanvasTransparentHint,
              },
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
