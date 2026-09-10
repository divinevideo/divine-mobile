// ABOUTME: Top overlay actions for the video editor with close and done buttons.
// ABOUTME: Hides when the music sub-editor is open.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, audio, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainOverlayActions extends StatelessWidget {
  const VideoEditorMainOverlayActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isHidden = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor == .music,
    );

    return IgnorePointer(
      ignoring: isHidden,
      child: AnimatedOpacity(
        opacity: isHidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: const Stack(
          fit: .expand,
          children: [
            Align(alignment: .topCenter, child: _TopActions()),
            Align(alignment: .bottomCenter, child: _BottomActions()),
          ],
        ),
      ),
    );
  }
}

/// Top row actions: close, audio chip, and done buttons.
class _TopActions extends ConsumerWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = VideoEditorScope.of(context);
    // Uses `read` because `draftId` is set once during `initialize()` and
    // does not change during the editor session.
    final isAutosavedDraft = ref.watch(
      videoEditorProvider.select((s) => s.isAutosavedDraft),
    );

    // Frames-per-image control lives in the toolbar's center slot — top
    // centre, inline between the back and done buttons — only for a
    // stop-motion composition.
    final ({String clipId, int value})? stopMotionData = context.select((
      ClipEditorBloc b,
    ) {
      final clips = b.state.clips;
      if (!isStopMotionComposition(clips)) return null;
      final clip = clips.first;
      final frames = clip.stopMotionFrames ?? const [];
      if (frames.isEmpty) return null;
      return (
        clipId: clip.id,
        value: StopMotionFrameOps.globalDefaultFramesPerImage(frames),
      );
    });

    return PopScope(
      canPop: !isAutosavedDraft,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isAutosavedDraft) {
          _onClosePressed(
            context: context,
            ref: ref,
            closeSubEditor: scope.editor?.closeSubEditor,
          );
        }
      },
      child: VideoEditorToolbar(
        closeIcon: .caretLeft,
        doneIcon: .arrowRight,
        closeSemanticLabel: context.l10n.videoEditorCloseEditorSemanticLabel,
        doneSemanticLabel:
            context.l10n.videoEditorContinueToPostDetailsSemanticLabel,
        center: stopMotionData == null
            ? null
            : _StopMotionFramesChip(
                clipId: stopMotionData.clipId,
                value: stopMotionData.value,
              ),
        onClose: () {
          if (isAutosavedDraft) {
            _onClosePressed(
              context: context,
              ref: ref,
              closeSubEditor: scope.editor?.closeSubEditor,
            );
          } else {
            context.pop();
          }
        },
        onDone: () => _onDonePressed(context, scope),
      ),
    );
  }

  /// Gates Done on the stop-motion minimum length: a composition shorter
  /// than [VideoEditorConstants.stopMotionMinOutputDuration] would only reach
  /// that length by silently looping at render, so instead the tap surfaces a
  /// "capture more frames" snackbar and stays in the editor.
  void _onDonePressed(BuildContext context, VideoEditorScope scope) {
    final clipState = context.read<ClipEditorBloc>().state;
    const minDuration = VideoEditorConstants.stopMotionMinOutputDuration;
    if (isStopMotionComposition(clipState.clips) &&
        clipState.totalDuration < minDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorStopMotionTooShortSnackbar(
            minDuration.inSeconds,
          ),
          error: true,
        ),
      );
      return;
    }
    scope.editor?.doneEditing();
  }

  void _onClosePressed({
    required BuildContext context,
    required WidgetRef ref,
    required VoidCallback? closeSubEditor,
  }) {
    final bloc = context.read<VideoEditorMainBloc>();
    if (bloc.state.isSubEditorOpen) {
      closeSubEditor?.call();
      return;
    }

    final hasBeenEdited = ref
        .read(videoEditorProvider.notifier)
        .getActiveDraft()
        .hasBeenEdited;

    if (!hasBeenEdited) {
      context.pop();
      return;
    }

    VineBottomSheetPrompt.show(
      context: context,
      sticker: .videoClapBoard,
      title: context.l10n.videoEditorSaveDraftTitle,
      subtitle: context.l10n.videoEditorSaveDraftSubtitle,
      primaryButtonText: context.l10n.videoEditorSaveDraftButton,
      secondaryButtonText: context.l10n.videoEditorDiscardChangesButton,
      tertiaryButtonText: context.l10n.videoEditorKeepEditingButton,
      onPrimaryPressed: () => _onSaveDraftPressed(context: context, ref: ref),
      onSecondaryPressed: () => _onDiscardPressed(context: context, ref: ref),
      onTertiaryPressed: context.pop,
    );
  }

  Future<void> _onSaveDraftPressed({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final outcome = await ref
        .read(videoEditorProvider.notifier)
        .saveAsDraft(enforceCreateNewDraft: true);

    // A save was already in flight (the button is normally disabled
    // meanwhile); leave the prompt as-is.
    if (outcome == DraftSaveOutcome.alreadyInProgress) return;
    if (!context.mounted) return;

    final draftSaved = outcome == DraftSaveOutcome.saved;

    if (draftSaved) {
      // The draft now owns the session, so end it here like the discard path
      // does — otherwise its clips stay selected behind the editor and the
      // next camera open inherits them, aspect ratio included.
      //
      // `keepAutosavedDraft` because `saveAsDraft` already awaited
      // `removeAutosavedDraft()`: there is nothing left to reap, and re-issuing
      // that delete unawaited is the hazard its own doc warns about — it
      // targets the fixed autosave id, so landing late would wipe the recovery
      // point of whatever session is active by then (adding a clip back on the
      // recorder writes one).
      unawaited(
        ref
            .read(videoPublishProvider.notifier)
            .clearAll(keepAutosavedDraft: true),
      );
      // Success: close prompt + close editor.
      context.pop();
      context.pop();
    } else {
      // Failure: close only prompt and keep editor open.
      context.pop();
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        draftSaved
            ? context.l10n.videoMetadataSavedToLibrarySnackbar
            : context.l10n.videoMetadataFailedToSaveSnackbar,
      ),
    );
  }

  void _onDiscardPressed({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    ref.read(videoPublishProvider.notifier).clearAll();
    context.pop();
    context.pop();
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final isTimelineHiddenByUser = context.select(
      (VideoEditorMainBloc b) => b.state.isTimelineHiddenByUser,
    );

    return Padding(
      padding: const .only(bottom: 8),
      child: DivineIconButton(
        icon: isTimelineHiddenByUser ? .caretUp : .caretDown,
        onPressed: () => context.read<VideoEditorMainBloc>().add(
          const VideoEditorTimelineVisibilityToggled(),
        ),
        size: .small,
        type: .ghostSecondary,
        semanticLabel: isTimelineHiddenByUser
            ? context.l10n.videoEditorShowTimelineSemanticLabel
            : context.l10n.videoEditorHideTimelineSemanticLabel,
      ),
    );
  }
}

/// A tappable "N frames" chip shown in the editor toolbar's centre slot (top
/// centre, between the back and done buttons) while editing a frames-only
/// stop-motion clip. Opens the frames-per-image wheel sheet and applies the
/// chosen hold as the global default (per-frame overrides are preserved).
class _StopMotionFramesChip extends StatelessWidget {
  const _StopMotionFramesChip({required this.clipId, required this.value});

  final String clipId;

  /// The global-default frames-per-image (see
  /// [StopMotionFrameOps.globalDefaultFramesPerImage]).
  final int value;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.videoEditorStopMotionFramesCount(value);

    return Semantics(
      button: true,
      value: context.l10n.videoEditorStopMotionFramesPerImageValueSemanticLabel(
        value,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => editStopMotionGlobalHold(context, clipId: clipId),
        // Expand the hit area to the 48dp minimum touch target while the
        // visible pill keeps its natural size, centred inside it. The
        // width/height factors are essential: the toolbar row is laid out with
        // loose (near-full-height) constraints, so a plain Center would grow to
        // fill them and stretch the whole toolbar down the editor. Sizing to
        // the child means the ConstrainedBox only enforces the 48dp minimum.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.vineColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    DivineIcon(
                      icon: .imagesSquare,
                      color: context.vineColors.mutedText,
                      size: 16,
                    ),
                    Text(
                      label,
                      style: VineTheme.labelLargeFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
