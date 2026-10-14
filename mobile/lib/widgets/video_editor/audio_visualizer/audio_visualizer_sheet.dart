// ABOUTME: The sheet where a creator picks how an audio visualizer looks and
// ABOUTME: moves, for a new one or to change one.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/audio_visualizer/video_editor_audio_visualizer_cubit.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/audio_visualizer_layer.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/widgets/video_editor/audio_visualizer/audio_visualizer_preview.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_row.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerPainter, AudioVisualizerStyle;

/// Opens the visualizer sheet and resolves with what the creator picked, or
/// `null` when they closed it.
///
/// Starts from [initial] when it changes a visualizer already on the canvas,
/// and from the default look for a new one. Its preview follows the sound
/// [soundLevels] reads.
Future<AudioVisualizerLayerData?> showAudioVisualizerSheet(
  BuildContext context, {
  AudioVisualizerLayerData? initial,
  VideoEditorAudioVisualizerCubit? soundLevels,
}) {
  return VineBottomSheet.show<AudioVisualizerLayerData>(
    context: context,
    title: Text(context.l10n.videoEditorAudioVisualizerLabel),
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    body: AudioVisualizerSheet(initial: initial, soundLevels: soundLevels),
  );
}

/// Lets the creator pick how the visualizer looks while a preview plays it,
/// then pops with the result.
class AudioVisualizerSheet extends StatefulWidget {
  const AudioVisualizerSheet({this.initial, this.soundLevels, super.key});

  /// The visualizer being changed, or `null` for a new one.
  final AudioVisualizerLayerData? initial;

  /// Reads the sound of the edited video for the preview; `null` previews a
  /// sample beat.
  final VideoEditorAudioVisualizerCubit? soundLevels;

  @override
  State<AudioVisualizerSheet> createState() => _AudioVisualizerSheetState();
}

class _AudioVisualizerSheetState extends State<AudioVisualizerSheet> {
  late AudioVisualizerLayerData _data =
      widget.initial ?? const AudioVisualizerLayerData();

  Future<void> _pickCustomColor() async {
    final color = await showFullColorPicker(context, initialColor: _data.color);
    if (color == null || !mounted) return;
    setState(() => _data = _data.copyWith(color: color));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final l10n = context.l10n;
    // The options scroll on a short screen, between the preview above them
    // and the button below them.
    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        Padding(
          padding: const .fromLTRB(16, 8, 16, 0),
          child: AudioVisualizerPreview(
            data: _data,
            soundLevels: widget.soundLevels,
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const .only(top: 16, bottom: 16),
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                Padding(
                  padding: const .symmetric(horizontal: 16),
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final style in AudioVisualizerStyle.values)
                        Expanded(
                          child: _StyleTile(
                            data: _data.copyWith(style: style),
                            selected: style == _data.style,
                            onTap: () => setState(
                              () => _data = _data.copyWith(style: style),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                VideoEditorColorRow(
                  selected: _data.color,
                  onSelected: (color) =>
                      setState(() => _data = _data.copyWith(color: color)),
                  onCustom: _pickCustomColor,
                  padding: const .symmetric(horizontal: 16),
                  semanticLabel: l10n.videoEditorAudioVisualizerColorLabel,
                ),
                const SizedBox(height: 16),
                _OptionSlider(
                  label: l10n.videoEditorAudioVisualizerDensityLabel,
                  minLabel: l10n.videoEditorAudioVisualizerDensityFewer,
                  maxLabel: l10n.videoEditorAudioVisualizerDensityMore,
                  value: _data.bandCount.toDouble(),
                  min: VideoEditorConstants.audioVisualizerMinBandCount
                      .toDouble(),
                  max: audioBandCount.toDouble(),
                  // One band a step, without a tick mark for each of them.
                  onChanged: (value) {
                    final bands = value.round();
                    if (bands == _data.bandCount) return;
                    setState(() => _data = _data.copyWith(bands: bands));
                  },
                ),
                _OptionSlider(
                  label: l10n.videoEditorAudioVisualizerReactionLabel,
                  minLabel: l10n.videoEditorAudioVisualizerReactionCalm,
                  maxLabel: l10n.videoEditorAudioVisualizerReactionLively,
                  value: _data.reaction,
                  onChanged: (value) =>
                      setState(() => _data = _data.copyWith(reaction: value)),
                ),
                // The wave has no bars to make thinner or wider.
                if (_data.style != .wave)
                  _OptionSlider(
                    label: l10n.videoEditorAudioVisualizerBarWidthLabel,
                    minLabel: l10n.videoEditorAudioVisualizerBarWidthThin,
                    maxLabel: l10n.videoEditorAudioVisualizerBarWidthWide,
                    value: _data.effectiveBarFill.clamp(
                      VideoEditorConstants.audioVisualizerMinBarFill,
                      VideoEditorConstants.audioVisualizerMaxBarFill,
                    ),
                    min: VideoEditorConstants.audioVisualizerMinBarFill,
                    max: VideoEditorConstants.audioVisualizerMaxBarFill,
                    onChanged: (value) =>
                        setState(() => _data = _data.copyWith(barFill: value)),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
          child: DivineButton(
            label: widget.initial == null
                ? l10n.videoEditorAudioVisualizerAdd
                : l10n.videoEditorDoneLabel,
            expanded: true,
            onPressed: () => Navigator.of(context).pop(_data),
          ),
        ),
      ],
    );
  }
}

/// A setting of the visualizer on a slider, named above it, with what its
/// two ends mean below.
class _OptionSlider extends StatelessWidget {
  const _OptionSlider({
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
  });

  final String label;
  final String minLabel;
  final String maxLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final endStyle = VineTheme.bodySmallFont(
      color: context.vineColors.onSurfaceMuted,
    );
    return Padding(
      padding: const .fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            label,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          DivineSlider(
            value: value,
            min: min,
            max: max,
            semanticLabel: '$label: $minLabel – $maxLabel',
            onChanged: onChanged,
          ),
          // The slider announces both ends itself.
          ExcludeSemantics(
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(minLabel, style: endStyle),
                Text(maxLabel, style: endStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A style to pick: a still of the style in the picked color, and its name.
class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  /// The visualizer as it looks in this style.
  final AudioVisualizerLayerData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = switch (data.style) {
      .bars => context.l10n.videoEditorAudioVisualizerStyleBars,
      .mirroredBars => context.l10n.videoEditorAudioVisualizerStyleMirrored,
      .wave => context.l10n.videoEditorAudioVisualizerStyleWave,
      .circle => context.l10n.videoEditorAudioVisualizerStyleCircle,
    };
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      onTap: onTap,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTap: onTap,
        behavior: .opaque,
        child: Column(
          spacing: 8,
          children: [
            DecoratedBox(
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
                padding: const .all(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: data.aspectRatio,
                      child: CustomPaint(
                        painter: AudioVisualizerPainter(
                          style: data.style,
                          color: data.color,
                          levels: _sampleLevels(data.bandCount),
                          barFill: data.effectiveBarFill,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The tile announces the name itself.
            ExcludeSemantics(
              child: Text(
                label,
                maxLines: 1,
                overflow: .ellipsis,
                style: VineTheme.bodySmallFont(
                  color: selected
                      ? context.vineColors.primaryText
                      : context.vineColors.onSurfaceMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Levels that read as music in a still: loud in the bass, a bump in the
/// mids, quieter in the highs.
Float32List _sampleLevels(int bandCount) => Float32List.fromList([
  for (var band = 0; band < bandCount; band++)
    _sampleLevel(band / math.max(1, bandCount - 1)),
]);

/// The level of [_sampleLevels] at [position], 0 for the lowest band and 1
/// for the highest.
double _sampleLevel(double position) =>
    (0.85 - 0.55 * position + 0.25 * math.sin(position * 3 * math.pi)).clamp(
      0.1,
      1.0,
    );
