import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';

class VideoEditorTimelineControls extends StatelessWidget {
  const VideoEditorTimelineControls({
    required this.onDone,
    this.onDelete,
    this.onEdit,
    this.onFade,
    this.hasFade = false,
    this.onVoiceEffect,
    this.hasVoiceEffect = false,
    this.onEqualizer,
    this.hasEqualizer = false,
    this.equalizerSemanticLabel,
    this.onDuplicated,
    this.onSplit,
    this.onFreezeFrame,
    this.isFreezingFrame = false,
    this.onDetach,
    this.isDetaching = false,
    this.onReattach,
    this.onBackdrop,
    this.isChangingBackdrop = false,
    this.onAnimate,
    this.onKeyframes,
    this.hasKeyframes = false,
    this.isOnKeyframe = false,
    this.onStyles,
    this.onSpeed,
    this.onTransform,
    this.onChromaKey,
    this.isChromaKeying = false,
    this.hasChromaKey = false,
    this.onOpacity,
    this.hasOpacity = false,
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
  /// action bar to add the per-frame "frames per image" button.
  final List<Widget> extraControls;

  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  /// Opens the fade in / fade out sheet. Sound overlays only.
  final VoidCallback? onFade;

  /// Whether the selected sound already fades in or out, which highlights
  /// the action so the fade is visible from the timeline.
  final bool hasFade;

  /// Opens the voice effect sheet. Sounds only.
  final VoidCallback? onVoiceEffect;

  /// Whether the selected sound plays with an effect or noise reduction,
  /// which highlights the action so the effect is visible from the timeline.
  final bool hasVoiceEffect;

  /// Opens the equalizer of the selected clip or sound.
  ///
  /// A sound shows it with its other sound actions, after the voice effect.
  /// A clip, whose bar leads with the actions used most, shows it with its
  /// other audio action, right after [onExtractAudio].
  final VoidCallback? onEqualizer;

  /// Whether the selected clip or sound already plays with an equalizer, so
  /// the action shows as set.
  final bool hasEqualizer;

  /// What a screen reader says the equalizer action does; the one for a sound
  /// when null.
  final String? equalizerSemanticLabel;
  final VoidCallback? onDuplicated;
  final VoidCallback? onSplit;

  /// Holds the frame under the playhead still for a beat.
  final VoidCallback? onFreezeFrame;

  /// Whether that still is currently rendering. Shows the action as a
  /// spinner, matching the other render actions.
  final bool isFreezingFrame;

  /// Lifts the active clip off the timeline and onto the canvas as a layer.
  final VoidCallback? onDetach;

  /// Whether the active clip's replacement still is currently rendering. Shows
  /// the action as a spinner, matching the other render actions.
  final bool isDetaching;

  /// Puts a detached clip's layer back onto the timeline as a clip.
  final VoidCallback? onReattach;

  /// Opens the backdrop picker for the still that holds a detached clip's
  /// slot. Placeholder clips only.
  final VoidCallback? onBackdrop;

  /// Whether that still's replacement is currently rendering. Shows the action
  /// as a spinner, matching the other render actions.
  final bool isChangingBackdrop;

  /// Opens the layer enter/leave animation picker. Layer overlays only.
  final VoidCallback? onAnimate;

  /// Opens the keyframe sheet of the selected layer. Layer overlays that
  /// keyframes can move only.
  final VoidCallback? onKeyframes;

  /// Whether the layer already has keyframes, which highlights the action the
  /// way [hasChromaKey] does.
  final bool hasKeyframes;

  /// Whether the playhead is on one of the layer's keyframes, which fills the
  /// action's diamond in, as the keyframe's own diamond on the timeline is.
  final bool isOnKeyframe;

  /// Opens the saved title styles sheet. Text overlays only.
  final VoidCallback? onStyles;
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

  /// Whether the active clip already carries a green screen, which
  /// highlights the action so the effect is visible from the timeline.
  final bool hasChromaKey;

  /// Opens the opacity slider for a layer.
  final VoidCallback? onOpacity;

  /// Whether the layer is already see-through somewhere, which highlights the
  /// action the way [hasChromaKey] does.
  final bool hasOpacity;

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
    final equalizer = onEqualizer == null
        ? null
        : TimelineActionButton(
            icon: .faders,
            label: context.l10n.videoEditorEqualizerLabel,
            semanticLabel:
                equalizerSemanticLabel ??
                context.l10n.videoEditorEqualizerSoundSemanticLabel,
            onPressed: onEqualizer,
            type: hasEqualizer ? .primary : .secondary,
          );
    final equalizerWithClipAudio = onExtractAudio != null;
    return TimelineActionBar(
      actions: [
        if (onDelete != null)
          TimelineActionButton(
            icon: .trash,
            label: context.l10n.videoEditorDeleteLabel,
            semanticLabel:
                context.l10n.videoEditorDeleteSelectedItemSemanticLabel,
            onPressed: onDelete,
            type: .error,
          ),
        if (onEdit != null)
          TimelineActionButton(
            icon: .pencilSimple,
            label: context.l10n.videoEditorEditLabel,
            semanticLabel:
                context.l10n.videoEditorEditSelectedItemSemanticLabel,
            onPressed: onEdit,
          ),
        if (onFade != null)
          TimelineActionButton(
            icon: .speakerHigh,
            label: context.l10n.videoEditorFadeLabel,
            semanticLabel: context.l10n.videoEditorFadeSoundSemanticLabel,
            onPressed: onFade,
            type: hasFade ? .primary : .secondary,
          ),
        if (onVoiceEffect != null)
          TimelineActionButton(
            icon: .microphone,
            label: context.l10n.videoEditorVoiceEffectLabel,
            semanticLabel: context.l10n.videoEditorVoiceEffectSemanticLabel,
            onPressed: onVoiceEffect,
            type: hasVoiceEffect ? .primary : .secondary,
          ),
        if (equalizer != null && !equalizerWithClipAudio) equalizer,
        if (onDuplicated != null)
          TimelineActionButton(
            icon: .copy,
            label: context.l10n.videoEditorDuplicateLabel,
            semanticLabel:
                context.l10n.videoEditorDuplicateSelectedItemSemanticLabel,
            onPressed: onDuplicated,
          ),
        if (onSplit != null)
          TimelineActionButton(
            icon: .scissors,
            label: context.l10n.videoEditorSplitLabel,
            semanticLabel:
                context.l10n.videoEditorSplitSelectedClipSemanticLabel,
            onPressed: isSplitting ? null : onSplit,
          ),
        if (onDetach != null)
          TimelineActionButton(
            icon: .stackSimple,
            label: context.l10n.videoEditorDetachLabel,
            semanticLabel: context.l10n.videoEditorDetachSemanticLabel,
            onPressed: isDetaching ? null : onDetach,
            isLoading: isDetaching,
          ),
        if (onReattach != null)
          TimelineActionButton(
            icon: .arrowBendDownLeft,
            label: context.l10n.videoEditorReattachLabel,
            semanticLabel: context.l10n.videoEditorReattachSemanticLabel,
            onPressed: onReattach,
          ),
        if (onBackdrop != null)
          TimelineActionButton(
            icon: .image,
            label: context.l10n.videoEditorBackdropLabel,
            semanticLabel: context.l10n.videoEditorBackdropSemanticLabel,
            onPressed: isChangingBackdrop ? null : onBackdrop,
            isLoading: isChangingBackdrop,
          ),
        if (onAnimate != null)
          TimelineActionButton(
            icon: .sparkle,
            label: context.l10n.videoEditorLayerAnimationLabel,
            semanticLabel:
                context.l10n.videoEditorLayerAnimationButtonSemanticLabel,
            onPressed: onAnimate,
          ),
        if (onKeyframes != null)
          TimelineActionButton(
            icon: isOnKeyframe ? .diamondFill : .diamond,
            label: context.l10n.videoEditorKeyframesLabel,
            semanticLabel: context.l10n.videoEditorKeyframesButtonSemanticLabel,
            onPressed: onKeyframes,
            type: hasKeyframes ? .primary : .secondary,
          ),
        if (onStyles != null)
          TimelineActionButton(
            icon: .bookmarkSimple,
            label: context.l10n.videoEditorTitleStylesLabel,
            semanticLabel:
                context.l10n.videoEditorTitleStylesButtonSemanticLabel,
            onPressed: onStyles,
          ),
        if (onSpeed != null)
          TimelineActionButton(
            icon: .lightning,
            label: context.l10n.videoEditorSpeedLabel,
            semanticLabel: context.l10n.videoEditorSetClipSpeedSemanticLabel,
            onPressed: isExtractingAudio ? null : onSpeed,
          ),
        if (onTransform != null)
          TimelineActionButton(
            icon: .cropSquare,
            label: context.l10n.videoEditorTransformLabel,
            semanticLabel:
                transformSemanticLabel ??
                context.l10n.videoEditorTransformSelectedClipSemanticLabel,
            onPressed: onTransform,
          ),
        if (onChromaKey != null)
          TimelineActionButton(
            icon: .selection,
            label: context.l10n.videoEditorChromaKeyLabel,
            semanticLabel: context.l10n.videoEditorChromaKeySemanticLabel,
            onPressed: isChromaKeying ? null : onChromaKey,
            isLoading: isChromaKeying,
            type: hasChromaKey ? .primary : .secondary,
          ),
        if (onOpacity != null)
          TimelineActionButton(
            icon: .dropHalf,
            label: context.l10n.videoEditorOpacityLabel,
            semanticLabel: context.l10n.videoEditorOpacitySemanticLabel,
            onPressed: onOpacity,
            type: hasOpacity ? .primary : .secondary,
          ),
        if (onReversed != null)
          TimelineActionButton(
            icon: .arrowCounterClockwise,
            label: context.l10n.videoEditorReverseLabel,
            semanticLabel: context.l10n.videoEditorReverseClipSemanticLabel,
            onPressed: onReversed,
            type: isReversed ? .primary : .secondary,
          ),
        if (onExtractAudio != null)
          TimelineActionButton(
            icon: .waveform,
            label: context.l10n.videoEditorExtractAudioLabel,
            semanticLabel:
                context.l10n.videoEditorExtractAudioFromClipSemanticLabel,
            onPressed: isExtractingAudio ? null : onExtractAudio,
            isLoading: isExtractingAudio,
          ),
        if (equalizer != null && equalizerWithClipAudio) equalizer,
        if (onFreezeFrame != null)
          TimelineActionButton(
            icon: .pauseCircle,
            label: context.l10n.videoEditorFreezeFrameLabel,
            semanticLabel: context.l10n.videoEditorFreezeFrameSemanticLabel,
            onPressed: isFreezingFrame ? null : onFreezeFrame,
            isLoading: isFreezingFrame,
          ),
        if (onSaveToLibrary != null)
          TimelineActionButton(
            icon: .save,
            label: context.l10n.videoEditorSaveClip,
            semanticLabel: context.l10n.videoEditorSaveSelectedClip,
            onPressed: isSavingToLibrary || isSaveToLibraryDisabled
                ? null
                : onSaveToLibrary,
            isLoading: isSavingToLibrary,
          ),
        if (onMultiSelect != null)
          TimelineActionButton(
            icon: .checks,
            label: context.l10n.videoEditorMultiSelectLabel,
            semanticLabel:
                multiSelectSemanticLabel ??
                context.l10n.videoEditorMultiSelectSemanticLabel,
            onPressed: onMultiSelect,
          ),
        ...extraControls,
        TimelineActionButton(
          icon: .check,
          label: context.l10n.videoEditorDoneLabel,
          semanticLabel:
              context.l10n.videoEditorFinishTimelineEditingSemanticLabel,
          onPressed: onDone,
        ),
      ],
    );
  }
}
