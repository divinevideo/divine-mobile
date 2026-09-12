import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class VideoEditorTimelineControls extends StatelessWidget {
  const VideoEditorTimelineControls({
    required this.onDone,
    this.onDelete,
    this.onEdit,
    this.onDuplicated,
    this.onSplit,
    this.onDetach,
    this.isDetaching = false,
    this.onAnimate,
    this.onSpeed,
    this.onTransform,
    this.onChromaKey,
    this.isChromaKeying = false,
    this.hasChromaKey = false,
    this.onReversed,
    this.isReversed = false,
    this.onExtractAudio,
    this.isExtractingAudio = false,
    this.isSplitting = false,
    this.onSaveToLibrary,
    this.isSavingToLibrary = false,
    this.isSaveToLibraryDisabled = false,
    this.onMultiSelect,
    this.multiSelectSemanticLabel,
    this.transformSemanticLabel,
    this.extraControls = const [],
    super.key,
  });

  /// Extra controls inserted before the Done button — used by the stop-motion
  /// action bar to add the per-frame "frames per image" stepper.
  final List<Widget> extraControls;

  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicated;
  final VoidCallback? onSplit;

  /// Lifts the active clip off the timeline and onto the canvas as a layer.
  final VoidCallback? onDetach;

  /// Whether the active clip's replacement still is currently rendering. Shows
  /// the action as a spinner, matching the other render actions.
  final bool isDetaching;

  /// Opens the layer enter/leave animation picker. Layer overlays only.
  final VoidCallback? onAnimate;
  final VoidCallback? onSpeed;
  final VoidCallback? onTransform;

  /// Overrides the transform button's accessibility label. Defaults to the
  /// clip-oriented copy; the stop-motion action bar passes a frame-specific
  /// label because it transforms a single still, not the clip.
  final String? transformSemanticLabel;

  /// Opens the green-screen editor for the active clip.
  final VoidCallback? onChromaKey;

  /// Whether the active clip's green screen is currently being baked into its
  /// file. Shows the action as a spinner, matching the other render actions.
  final bool isChromaKeying;

  /// Whether the active clip already carries a baked green screen, which
  /// highlights the action so the effect is visible from the timeline.
  final bool hasChromaKey;

  final VoidCallback? onReversed;
  final bool isReversed;
  final VoidCallback? onExtractAudio;
  final bool isExtractingAudio;

  /// Whether a split of the active clip is currently rendering. Renders the
  /// Split action disabled (rather than removing it) so the control stays in
  /// place instead of confusingly disappearing mid-operation.
  final bool isSplitting;

  /// Saves the active clip to the clip library as a standalone clip.
  final VoidCallback? onSaveToLibrary;

  /// Whether the active clip is currently being re-encoded for the library.
  /// Shows the Save action as a spinner.
  final bool isSavingToLibrary;

  /// Whether Save should be shown disabled because a library re-encode of some
  /// (possibly other) clip is already running. Only one save runs at a time, so
  /// the button is greyed rather than left tappable-but-ignored. Distinct from
  /// [isSavingToLibrary], which additionally swaps the button for a spinner on
  /// the clip actually being saved.
  final bool isSaveToLibraryDisabled;
  final VoidCallback? onMultiSelect;

  /// Overrides the multi-select button's accessibility label. Defaults to the
  /// clip-oriented copy; draw-layer callers pass a drawing-specific label.
  final String? multiSelectSemanticLabel;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Container(
        width: double.infinity,
        padding: const .fromLTRB(0, 16, 0, 8),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              scrollDirection: .horizontal,
              padding: const .symmetric(horizontal: 16),
              child: Row(
                spacing: 16,
                mainAxisAlignment: .center,
                children: [
                  if (onDelete != null)
                    _ControlButton(
                      icon: .trash,
                      label: context.l10n.videoEditorDeleteLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorDeleteSelectedItemSemanticLabel,
                      onPressed: onDelete,
                      type: .error,
                    ),
                  if (onEdit != null)
                    _ControlButton(
                      icon: .pencilSimple,
                      label: context.l10n.videoEditorEditLabel,
                      semanticLabel:
                          context.l10n.videoEditorEditSelectedItemSemanticLabel,
                      onPressed: onEdit,
                    ),
                  if (onDuplicated != null)
                    _ControlButton(
                      icon: .copy,
                      label: context.l10n.videoEditorDuplicateLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorDuplicateSelectedItemSemanticLabel,
                      onPressed: onDuplicated,
                    ),
                  if (onSplit != null)
                    _ControlButton(
                      icon: .scissors,
                      label: context.l10n.videoEditorSplitLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorSplitSelectedClipSemanticLabel,
                      onPressed: isSplitting ? null : onSplit,
                    ),
                  if (onDetach != null)
                    _ControlButton(
                      icon: .stackSimple,
                      label: context.l10n.videoEditorDetachLabel,
                      semanticLabel:
                          context.l10n.videoEditorDetachSemanticLabel,
                      onPressed: isDetaching ? null : onDetach,
                      isLoading: isDetaching,
                    ),
                  if (onAnimate != null)
                    _ControlButton(
                      icon: .sparkle,
                      label: context.l10n.videoEditorLayerAnimationLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorLayerAnimationButtonSemanticLabel,
                      onPressed: onAnimate,
                    ),
                  if (onSpeed != null)
                    _ControlButton(
                      icon: .lightning,
                      label: context.l10n.videoEditorSpeedLabel,
                      semanticLabel:
                          context.l10n.videoEditorSetClipSpeedSemanticLabel,
                      onPressed: isExtractingAudio ? null : onSpeed,
                    ),
                  if (onTransform != null)
                    _ControlButton(
                      icon: .cropSquare,
                      label: context.l10n.videoEditorTransformLabel,
                      semanticLabel:
                          transformSemanticLabel ??
                          context
                              .l10n
                              .videoEditorTransformSelectedClipSemanticLabel,
                      onPressed: onTransform,
                    ),
                  if (onChromaKey != null)
                    _ControlButton(
                      icon: .selection,
                      label: context.l10n.videoEditorChromaKeyLabel,
                      semanticLabel:
                          context.l10n.videoEditorChromaKeySemanticLabel,
                      onPressed: isChromaKeying ? null : onChromaKey,
                      isLoading: isChromaKeying,
                      type: hasChromaKey ? .primary : .secondary,
                    ),
                  if (onReversed != null)
                    _ControlButton(
                      icon: .arrowCounterClockwise,
                      label: context.l10n.videoEditorReverseLabel,
                      semanticLabel:
                          context.l10n.videoEditorReverseClipSemanticLabel,
                      onPressed: onReversed,
                      type: isReversed ? .primary : .secondary,
                    ),
                  if (onExtractAudio != null)
                    _ControlButton(
                      icon: .waveform,
                      label: context.l10n.videoEditorExtractAudioLabel,
                      semanticLabel: context
                          .l10n
                          .videoEditorExtractAudioFromClipSemanticLabel,
                      onPressed: isExtractingAudio ? null : onExtractAudio,
                      isLoading: isExtractingAudio,
                    ),
                  if (onSaveToLibrary != null)
                    _ControlButton(
                      icon: .save,
                      label: context.l10n.videoEditorSaveClip,
                      semanticLabel: context.l10n.videoEditorSaveSelectedClip,
                      onPressed: isSavingToLibrary || isSaveToLibraryDisabled
                          ? null
                          : onSaveToLibrary,
                      isLoading: isSavingToLibrary,
                    ),
                  if (onMultiSelect != null)
                    _ControlButton(
                      icon: .checks,
                      label: context.l10n.videoEditorMultiSelectLabel,
                      semanticLabel:
                          multiSelectSemanticLabel ??
                          context.l10n.videoEditorMultiSelectSemanticLabel,
                      onPressed: onMultiSelect,
                    ),
                  ...extraControls,
                  _ControlButton(
                    icon: .check,
                    label: context.l10n.videoEditorDoneLabel,
                    semanticLabel: context
                        .l10n
                        .videoEditorFinishTimelineEditingSemanticLabel,
                    onPressed: onDone,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.type = .secondary,
    this.isLoading = false,
  });

  final DivineIconName icon;
  final String label;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final DivineIconButtonType type;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        if (isLoading)
          const SizedBox.square(
            dimension: 52,
            child: Center(
              child: BrandedLoadingIndicator(size: 32),
            ),
          )
        else
          DivineIconButton(
            icon: icon,
            semanticLabel: semanticLabel,
            onPressed: onPressed,
            type: type,
            size: .small,
          ),
        // The caption repeats the button's own label, so it is excluded only
        // while that button is there to carry it. The spinner that replaces it
        // announces the wait but not what is waiting, so the caption is what
        // names the control for the length of the run.
        ExcludeSemantics(
          excluding: !isLoading,
          child: Text(
            label,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}
