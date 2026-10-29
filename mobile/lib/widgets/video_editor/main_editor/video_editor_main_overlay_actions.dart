// ABOUTME: Top overlay actions for the video editor with close and done buttons.
// ABOUTME: Hides when the music sub-editor is open.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_text_wrap_hint.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar_chip.dart';
import 'package:unified_logger/unified_logger.dart';

/// Overlay actions for the video editor.
///
/// Displays the close and done buttons at the top and the timeline visibility
/// toggle at the bottom, and hides them while the music sub-editor is open.
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

/// Top row actions: close and done buttons, plus the stop-motion frames chip
/// or the text wrap hint.
class _TopActions extends ConsumerWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = VideoEditorScope.of(context);
    final isFinishing = context.select(
      (VideoEditorMainBloc b) => b.state.isFinishing,
    );
    final hasLoopSuggestion = context.select(
      (LoopSuggestionCubit cubit) =>
          cubit.state.status == LoopSuggestionStatus.searching,
    );
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

    void close() {
      if (isAutosavedDraft) {
        _onClosePressed(
          context: context,
          ref: ref,
          closeSubEditor: scope.editor?.closeSubEditor,
        );
      } else {
        context.pop();
      }
    }

    // The editor route never pops itself (see `VideoEditorScreen.build`), so
    // Android's system back lands here and leaves the way the close button
    // does. An open sub-editor takes that back press itself
    // (`VideoEditorCanvas`), so it must not also close the editor.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.read<VideoEditorMainBloc>().state.isSubEditorOpen) return;
        close();
      },
      child: VideoEditorToolbar(
        closeIcon: .caretLeft,
        doneIcon: .arrowRight,
        closeSemanticLabel: context.l10n.videoEditorCloseEditorSemanticLabel,
        doneSemanticLabel:
            context.l10n.videoEditorContinueToPostDetailsSemanticLabel,
        // The wrap hint is brief and only follows a text the user is
        // sizing, so it takes the slot over from the frames chip meanwhile.
        center: VideoEditorTextWrapHint(
          fallback: stopMotionData == null
              ? null
              : _StopMotionFramesChip(
                  clipId: stopMotionData.clipId,
                  value: stopMotionData.value,
                ),
        ),
        onClose: close,
        onDone: hasLoopSuggestion || isFinishing
            ? null
            : () => _onDonePressed(context, scope),
      ),
    );
  }

  /// Gates Done on the stop-motion minimum length: a composition shorter
  /// than [VideoEditorConstants.stopMotionMinOutputDuration] would only reach
  /// that length by silently looping at render, so instead the tap surfaces a
  /// "capture more frames" snackbar and stays in the editor.
  void _onDonePressed(BuildContext context, VideoEditorScope scope) {
    final bloc = context.read<VideoEditorMainBloc>();
    if (bloc.state.isFinishing) return;
    if (context.read<LoopSuggestionCubit>().state.status ==
        LoopSuggestionStatus.searching) {
      return;
    }
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
    bloc.add(const VideoEditorFinishingChanged(isFinishing: true));
    runDetached(
      _finishEditing(bloc, scope),
      'finish editing',
      logName: 'VideoEditorMainOverlayActions',
      category: LogCategory.video,
    );
  }

  /// Hands the edit over to the export, first loading the sticker emoji font
  /// when a social sticker has an emoji to draw in it: the export captures the
  /// stickers as they show, and a viewer's copy draws its emoji in that font.
  Future<void> _finishEditing(
    VideoEditorMainBloc bloc,
    VideoEditorScope scope,
  ) async {
    try {
      final editor = scope.editor;
      if (editor == null) return;
      await loadStickerEmojiFontFor([
        for (final layer in editor.activeLayers)
          if (SocialStickerData.of(layer) case final sticker?)
            SocialStickerView.textOf(sticker),
      ]);
      if (editor.mounted) editor.doneEditing();
    } finally {
      bloc.addIfOpen(const VideoEditorFinishingChanged(isFinishing: false));
    }
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

    runDetached(
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
      ),
      'show unsaved changes prompt',
      logName: 'VideoEditorMainOverlayActions',
      category: LogCategory.video,
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
      runDetached(
        ref
            .read(videoPublishProvider.notifier)
            .clearAll(keepAutosavedDraft: true),
        'clear saved editor session',
        logName: 'VideoEditorMainOverlayActions',
        category: LogCategory.video,
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
    runDetached(
      ref.read(videoPublishProvider.notifier).clearAll(),
      'discard editor session',
      logName: 'VideoEditorMainOverlayActions',
      category: LogCategory.video,
    );
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
    return VideoEditorToolbarChip(
      icon: .imagesSquare,
      label: context.l10n.videoEditorStopMotionFramesCount(value),
      semanticValue: context.l10n
          .videoEditorStopMotionFramesPerImageValueSemanticLabel(value),
      onTap: () => editStopMotionGlobalHold(context, clipId: clipId),
    );
  }
}
