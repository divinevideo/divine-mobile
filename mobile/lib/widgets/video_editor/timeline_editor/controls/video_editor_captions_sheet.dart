// ABOUTME: Bottom sheet for editing the captions session (cues, preset, mode).
// ABOUTME: Generates cues on-device for fresh sessions, pops a result on done.

import 'dart:async';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/captions/caption_cue_row.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_preset_sheet.dart';

/// Result of the captions editor sheet, returned via [Navigator.pop].
sealed class CaptionsEditorResult {
  const CaptionsEditorResult();
}

/// User confirmed the session; the editor commits [track] (and, for burn-in,
/// materializes [cues] as caption layers).
class CaptionsConfirmed extends CaptionsEditorResult {
  /// Creates the confirmed result.
  const CaptionsConfirmed({required this.track, required this.cues});

  /// The caption track to store in editor history meta.
  final CaptionTrack track;

  /// The full cue list of the session (also populated in burn-in mode,
  /// where [CaptionTrack.cues] stays empty).
  final List<CaptionCue> cues;
}

/// User removed the caption track entirely.
class CaptionsDeleted extends CaptionsEditorResult {
  /// Creates the deleted result.
  const CaptionsDeleted();
}

/// Shows the captions editor as a [VineBottomSheet] — the editor's standard
/// surface for focused tools (speed, transitions, presets).
///
/// A fresh session (no [initialCues]) transcribes the clips on-device first;
/// an existing session starts with its cues. Resolves to a
/// [CaptionsEditorResult], `null` when dismissed.
Future<CaptionsEditorResult?> showCaptionsEditorSheet(
  BuildContext context, {
  required String presetId,
  required String languageTag,
  required List<DivineVideoClip> clips,
  required Duration totalDuration,
  bool burnIn = false,
  CaptionCustomStyle? customStyle,
  List<CaptionCue>? initialCues,
  bool canDeleteTrack = false,
  BlossomUploadService? blossomUploadService,
  @visibleForTesting CaptionsEditorCubit? cubit,
}) async {
  final l10n = context.l10n;
  final sessionCubit =
      cubit ??
      CaptionsEditorCubit(
        clips: clips,
        totalDuration: totalDuration,
        burnIn: burnIn,
        presetId: presetId,
        customStyle: customStyle,
        languageTag: languageTag,
        initialCues: initialCues,
        blossomUploadService: blossomUploadService,
      );
  unawaited(sessionCubit.initialize());

  void confirm() {
    final state = sessionCubit.state;
    if (state.status == CaptionsEditorStatus.generating) return;
    // Normalization (drop cleared cues, sort by start) lives on the cubit
    // state so it stays testable and downstream-consistent.
    final track = state.committedTrack;
    Navigator.of(context).pop<CaptionsEditorResult>(
      CaptionsConfirmed(track: track, cues: track.cues),
    );
  }

  Future<void> deleteTrack() async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: l10n.videoEditorCaptionsDeleteTrackConfirmTitle,
      subtitle: l10n.videoEditorCaptionsDeleteTrackConfirmSubtitle,
      primaryButtonText: l10n.commonDelete,
      primaryButtonType: .error,
      secondaryButtonText: l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if ((confirmed ?? false) && context.mounted) {
      Navigator.of(context).pop<CaptionsEditorResult>(const CaptionsDeleted());
    }
  }

  try {
    return await VineBottomSheet.show<CaptionsEditorResult>(
      context: context,
      initialChildSize: 0.8,
      minChildSize: 0.8,
      title: Text(
        l10n.videoEditorCaptionsEditTitle,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      headerLeadingAction: canDeleteTrack
          ? DivineIconButton(
              icon: .trash,
              type: .error,
              size: .small,
              semanticLabel: l10n.videoEditorCaptionsDeleteTrack,
              onPressed: deleteTrack,
            )
          : DivineIconButton(
              icon: .x,
              type: .secondary,
              size: .small,
              semanticLabel: l10n.videoEditorCaptionsCloseSemanticLabel,
              onPressed: () =>
                  Navigator.of(context).pop<CaptionsEditorResult>(),
            ),
      headerTrailingAction: DivineIconButton(
        icon: .check,
        size: .small,
        semanticLabel: l10n.videoEditorCaptionsDoneSemanticLabel,
        onPressed: confirm,
      ),
      contentWrapper: (_, child) =>
          BlocProvider.value(value: sessionCubit, child: child),
      buildScrollBody: (scrollController) => _CaptionsSheetBody(
        scrollController: scrollController,
        totalDuration: totalDuration,
      ),
    );
  } finally {
    unawaited(sessionCubit.close());
  }
}

class _CaptionsSheetBody extends StatelessWidget {
  const _CaptionsSheetBody({
    required this.scrollController,
    required this.totalDuration,
  });

  final ScrollController scrollController;
  final Duration totalDuration;

  /// Scrolls the cue list to the bottom so a freshly added cue is visible.
  /// Deferred to after layout so the new row is measured into
  /// [ScrollPosition.maxScrollExtent] before the animation targets it.
  void _scrollToNewCue() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard inset as scroll padding: content stays reachable above the
    // keyboard and the focused field can scroll itself into view — no
    // pinned bottom bar that would cover the list while typing.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return BlocConsumer<CaptionsEditorCubit, CaptionsEditorState>(
      // Only when a cue is added to an already-shown list — not the initial
      // generation fill (generating→ready), which should stay scrolled to the
      // top.
      listenWhen: (prev, curr) =>
          prev.status == CaptionsEditorStatus.ready &&
          curr.cues.length > prev.cues.length,
      listener: (context, state) => _scrollToNewCue(),
      builder: (context, state) => switch (state.status) {
        CaptionsEditorStatus.generating => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: const [_GeneratingView()],
        ),
        CaptionsEditorStatus.empty || CaptionsEditorStatus.failed => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [_FallbackView(state: state)],
        ),
        // Cue list scrolls; the action buttons stay pinned at the sheet
        // bottom. They carry no keyboard inset — while typing the keyboard
        // covers them and the list (padded by the inset) keeps the focused
        // field visible instead of the buttons overlapping it.
        CaptionsEditorStatus.ready => Column(
          children: [
            // Burn-in choice and style sit above the cue list so the primary
            // decision is made before editing individual cues.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _CaptionsModeControls(state: state),
            ),
            Divider(
              height: 2,
              thickness: 2,
              color: context.vineColors.surfaceContainer,
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                children: [
                  for (var i = 0; i < state.cues.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 32,
                        color: context.vineColors.outlineMuted,
                      ),
                    _CueRow(
                      key: ValueKey(state.cues[i].id),
                      cue: state.cues[i],
                      totalDuration: totalDuration,
                    ),
                  ],
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
                child: DivineButton(
                  label: context.l10n.videoEditorCaptionsAddCue,
                  type: .secondary,
                  expanded: true,
                  onPressed: () => context.read<CaptionsEditorCubit>().addCue(),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        // The title below already announces the wait.
        const ExcludeSemantics(
          child: Center(child: BrandedLoadingIndicator(size: 60)),
        ),
        Text(
          l10n.videoEditorCaptionsGeneratingTitle,
          textAlign: TextAlign.center,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        Text(
          l10n.videoEditorCaptionsGeneratingSubtitle,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

class _FallbackView extends StatelessWidget {
  const _FallbackView({required this.state});

  final CaptionsEditorState state;

  String _message(AppLocalizations l10n) {
    if (state.status == CaptionsEditorStatus.empty) {
      return l10n.videoEditorCaptionsNoSpeechMessage;
    }
    return switch (state.failure) {
      CaptionGenerationFailure.recognizerUnavailable =>
        l10n.videoEditorCaptionsUnavailableMessage,
      CaptionGenerationFailure.notAuthorized =>
        l10n.videoEditorCaptionsNotAuthorizedMessage,
      CaptionGenerationFailure.unsupportedAudio ||
      CaptionGenerationFailure.failed ||
      null => l10n.videoEditorCaptionsFailedMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(
          _message(l10n),
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        DivineButton(
          label: l10n.videoEditorCaptionsStartEmptyButton,
          type: .secondary,
          onPressed: () => context.read<CaptionsEditorCubit>().startEmpty(),
        ),
      ],
    );
  }
}

/// Burn-in choice and style, shown above the cue list.
class _CaptionsModeControls extends StatelessWidget {
  const _CaptionsModeControls({required this.state});

  final CaptionsEditorState state;

  Future<void> _changeStyle(BuildContext context) async {
    final cubit = context.read<CaptionsEditorCubit>();
    final selection = await showCaptionStyleSheet(
      context,
      selectedId: cubit.state.presetId,
      currentCustomStyle: cubit.state.customStyle,
    );
    switch (selection) {
      case CaptionPresetSelection(:final presetId):
        cubit.setPreset(presetId);
      case CaptionCustomSelection(:final style):
        cubit.setCustomStyle(style);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styleName = state.hasCustomStyle
        ? l10n.videoEditorCaptionsPresetCustom
        : captionPresetDisplayName(l10n, state.presetId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        DivineRowCheckbox(
          state: state.burnIn
              ? DivineCheckboxState.selected
              : DivineCheckboxState.unselected,
          onChanged: (checked) =>
              context.read<CaptionsEditorCubit>().setBurnIn(burnIn: checked),
          label: Text(
            l10n.videoEditorCaptionsBurnInLabel,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
          child: state.burnIn
              ? DivineButton(
                  label: '${l10n.videoEditorCaptionsPresetTitle}: $styleName',
                  type: .secondary,
                  expanded: true,
                  onPressed: () => _changeStyle(context),
                )
              : const SizedBox(width: .infinity),
        ),
      ],
    );
  }
}

/// Adapts the shared [CaptionCueRow] to this sheet's cubit.
class _CueRow extends StatelessWidget {
  const _CueRow({
    required this.cue,
    required this.totalDuration,
    super.key,
  });

  final CaptionCue cue;

  /// Slider range: the full video, so cues may freely overlap each other.
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CaptionsEditorCubit>();
    return CaptionCueRow(
      text: cue.text,
      textFieldLabel: l10n.videoEditorCaptionsCueTextHint,
      removeSemanticLabel: l10n.videoEditorCaptionsCueDeleteSemanticLabel,
      start: cue.start,
      end: cue.end,
      totalDuration: totalDuration,
      onTimingChanged: (start, end) =>
          cubit.updateCueTiming(cue.id, start: start, end: end),
      onTextChanged: (value) => cubit.updateCueText(cue.id, value),
      onRemoved: () => cubit.removeCue(cue.id),
    );
  }
}
