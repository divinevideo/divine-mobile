// ABOUTME: Full-screen editor for correcting a video's subtitles.
// ABOUTME: Page builds the cubit from Riverpod; View renders a cue timeline
// ABOUTME: for the timing and a list of text fields for the wording.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/codec_heavy_surface_guard.dart';
import 'package:openvine/models/subtitle_editor/timeline_frame.dart';
import 'package:openvine/providers/subtitle_repository_provider.dart';
import 'package:openvine/providers/subtitle_timeline_thumbnail_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/widgets/captions/caption_cue_row.dart';
import 'package:openvine/widgets/subtitle_editor/subtitle_editor_stage.dart';

/// Full-screen subtitle editor page.
///
/// The screen is keyed on [videoId] so it can be rebuilt from the route alone.
/// A [prefetched] video may be passed as a fast path when navigating from a
/// feed or metadata screen. It is used only when its complete raw tag array is
/// available for the video replacement published after subtitle changes.
class SubtitleEditorScreen extends ConsumerStatefulWidget {
  /// Creates the subtitle editor page for [videoId].
  const SubtitleEditorScreen({
    required this.videoId,
    this.prefetched,
    super.key,
  });

  /// Base route path.
  static const String path = RoutePaths.subtitleEditor;

  /// GoRouter route name.
  static const routeName = 'subtitle-edit';

  /// Returns the full path for a given video id.
  static String pathFor(String videoId) =>
      RoutePaths.subtitleEditorFor(videoId);

  /// The event id of the video whose subtitles are being edited.
  final String videoId;

  /// Optional complete prefetched video used to avoid an async resolve.
  final VideoEvent? prefetched;

  @override
  ConsumerState<SubtitleEditorScreen> createState() =>
      _SubtitleEditorScreenState();
}

class _SubtitleEditorScreenState extends ConsumerState<SubtitleEditorScreen>
    with CodecHeavySurfaceGuard {
  // The preview player is built as soon as the cues land, so the feed behind
  // has to hand back its decoder before that one is created rather than after
  // the entrance transition — the same reason the video editor opts out.
  @override
  bool get assertCodecSignalAfterEntranceTransition => false;

  VideoEvent? _resolved;
  bool _resolveFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefetched != null &&
        widget.prefetched!.id == widget.videoId &&
        widget.prefetched!.nostrEventTags.isNotEmpty) {
      _resolved = widget.prefetched;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final resolver = ref.read(videoEventResolverProvider);
    final video = await resolver.resolveById(
      widget.videoId,
      allowOwnContentBypass: true,
      requireRawTags: true,
    );
    if (!mounted) return;
    setState(() {
      _resolved = video;
      _resolveFailed = video == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = _resolved;
    if (video == null) {
      if (_resolveFailed) {
        return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
      }
      return Scaffold(
        backgroundColor: context.vineColors.background,
        body: const Center(
          child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    final repository = ref.watch(subtitleRepositoryProvider);
    final loadFrames = ref.watch(subtitleTimelineFrameLoaderProvider);
    return BlocProvider<SubtitleEditorCubit>(
      key: ObjectKey(repository),
      create: (_) =>
          SubtitleEditorCubit(repository: repository, video: video)..load(),
      child: SubtitleEditorView(video: video, loadFrames: loadFrames),
    );
  }
}

/// Renders the subtitle editor UI.
///
/// Expects a [SubtitleEditorCubit] ancestor provided by [SubtitleEditorScreen].
@visibleForTesting
class SubtitleEditorView extends StatelessWidget {
  /// Creates the subtitle editor view.
  const SubtitleEditorView({
    required this.video,
    required this.loadFrames,
    super.key,
  });

  /// The video whose subtitles are being edited.
  final VideoEvent video;

  /// Supplies the timeline's filmstrip.
  final TimelineFrameLoader loadFrames;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      // The keyboard must not shrink the body: the picture stays where it
      // is and the sheet rides up over it instead.
      resizeToAvoidBottomInset: false,
      appBar: DiVineAppBar(
        title: l10n.subtitleEditorTitle,
        backgroundColor: context.vineColors.surface,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: BlocConsumer<SubtitleEditorCubit, SubtitleEditorState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == SubtitleEditorStatus.success) {
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.subtitleEditorSaveSuccess,
              Directionality.of(context),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.subtitleEditorSaveSuccess)),
            );
            context.pop(state.updatedVideo);
          } else if (state.status == SubtitleEditorStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.cues.isEmpty
                      ? l10n.subtitleEditorLoadError
                      : l10n.subtitleEditorSaveError,
                ),
              ),
            );
          }
        },
        builder: (context, state) => switch (state.status) {
          SubtitleEditorStatus.loading => const _Loading(),
          // Transcription is still running, so writing captions now would
          // race the result. Wait or re-check, but don't offer authoring.
          SubtitleEditorStatus.processing => _NoCues(
            message: l10n.subtitleEditorProcessing,
          ),
          SubtitleEditorStatus.empty => _NoCues(
            message: l10n.subtitleEditorNoSpeech,
            canWriteOwn: true,
          ),
          SubtitleEditorStatus.unavailable => _NoCues(
            message: l10n.subtitleEditorLoadError,
            canWriteOwn: true,
          ),
          // A failure with nothing loaded is a failed load: the snackbar
          // fades, so the reason has to stay on screen. A failure with cues
          // is a failed save, and those cues are the creator's work — keep
          // the list.
          SubtitleEditorStatus.failure when state.cues.isEmpty => _NoCues(
            message: l10n.subtitleEditorLoadError,
            canWriteOwn: true,
          ),
          _ => _CueList(state: state, video: video, loadFrames: loadFrames),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: DivineCircularProgressIndicator());
}

/// Explains why there is nothing to edit, and offers a way forward.
///
/// When [canWriteOwn] is set there will be no auto-generated track to wait
/// for, so the creator is offered the chance to author captions by hand.
class _NoCues extends StatelessWidget {
  const _NoCues({required this.message, this.canWriteOwn = false});

  final String message;
  final bool canWriteOwn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          if (canWriteOwn)
            DivineButton(
              label: l10n.subtitleEditorWriteOwn,
              leadingIcon: DivineIconName.plus,
              onPressed: () => context.read<SubtitleEditorCubit>().addCue(),
            ),
          DivineButton(
            label: l10n.subtitleEditorRetry,
            type: DivineButtonType.link,
            onPressed: () => context.read<SubtitleEditorCubit>().load(),
          ),
        ],
      ),
    );
  }
}

/// The video with its timeline, and the cue sheet over it.
class _CueList extends StatelessWidget {
  const _CueList({
    required this.state,
    required this.video,
    required this.loadFrames,
  });

  final SubtitleEditorState state;
  final VideoEvent video;
  final TimelineFrameLoader loadFrames;

  /// Share of the screen the picture and its timeline may take. The sheet
  /// covers the rest, and opens flush against the bottom of the stage.
  static const _stageHeightFactor = 0.5;

  @override
  Widget build(BuildContext context) {
    final videoUrl = video.videoUrl;
    final hasStage =
        state.cues.isNotEmpty && videoUrl != null && videoUrl.isNotEmpty;
    // With no picture to sit under there is nothing for a sheet to reveal, so
    // the rows take the whole screen the way they did before the video was on
    // it. A sheet here would strand the list under half a screen of nothing.
    if (!hasStage) return _CueBody(state: state);
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: _stageHeightFactor,
              child: _Stage(
                state: state,
                videoUrl: videoUrl,
                playbackUrls: video.previewPlaybackSources,
                videoId: video.id,
                loadFrames: loadFrames,
              ),
            ),
          ),
        ),
        // Lifted by the keyboard inset so the sheet slides over the picture
        // rather than the picture being squeezed out from under it.
        Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _CueSheet(state: state),
        ),
      ],
    );
  }
}

/// The cue rows and save button filling the screen, with no video above them.
class _CueBody extends StatelessWidget {
  const _CueBody({required this.state});

  final SubtitleEditorState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Expanded(
            child: _CueRows(state: state, padding: const EdgeInsets.all(16)),
          ),
          _SaveBar(state: state),
        ],
      ),
    );
  }
}

/// The cue rows, add action and save button, on a sheet over the video.
///
/// Draggable so the creator can trade picture for rows, but never dismissible:
/// it is the editor, not an overlay on it.
class _CueSheet extends StatelessWidget {
  const _CueSheet({required this.state});

  final SubtitleEditorState state;

  /// Dragged all the way up the sheet still leaves a sliver of picture, so it
  /// never reads as a screen of its own.
  static const _maxSize = 0.95;

  /// The sheet rests flush against the bottom of the stage and cannot be
  /// collapsed past it. The stage's height is fixed, so a smaller sheet would
  /// not reveal more picture — only a band of empty background under it.
  ///
  /// It is also where the sheet opens. `snap: true` snaps to the two bounds and
  /// nothing between them, so a resting size that is not one of them would be
  /// unreachable after the first drag.
  static const double _minSize = _CueList._stageHeightFactor;

  static double get _initialSize => _minSize;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: _initialSize,
      minChildSize: _minSize,
      maxChildSize: _maxSize,
      snap: true,
      builder: (context, scrollController) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.vineColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: context.vineColors.surfaceContainerHigh,
              blurRadius: 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: VineBottomSheetDragHandle()),
              ),
              Expanded(
                child: _CueRows(
                  state: state,
                  scrollController: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                ),
              ),
              _SaveBar(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

/// The editable cue rows, with the add action in a trailing slot.
class _CueRows extends StatelessWidget {
  const _CueRows({
    required this.state,
    required this.padding,
    this.scrollController,
  });

  final SubtitleEditorState state;
  final EdgeInsets padding;

  /// Supplied when the rows live in a draggable sheet, so scrolling past the
  /// top of the list drags the sheet instead.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final saving = state.status == SubtitleEditorStatus.saving;
    return ListView.builder(
      controller: scrollController,
      padding: padding,
      // One trailing slot for the add action, so authoring a caption stays
      // reachable from the bottom of a long list.
      itemCount: state.cues.length + 1,
      itemBuilder: (context, index) => index == state.cues.length
          ? _AddCueButton(enabled: state.canAddCue && !saving)
          : _CueRow(
              index: index,
              cue: state.cues[index],
              totalDuration: Duration(milliseconds: state.timelineDurationMs),
              isSelected: state.selectedCueIndex == index,
            ),
    );
  }
}

/// Pinned foot of the sheet: why saving is blocked, and the save button.
class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.state});

  final SubtitleEditorState state;

  @override
  Widget build(BuildContext context) {
    final saving = state.status == SubtitleEditorStatus.saving;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (state.isDirty && !state.isValid)
              Text(
                context.l10n.subtitleEditorInvalidHint,
                textAlign: TextAlign.center,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            _SaveButton(
              enabled: state.isDirty && state.isValid && !saving,
              busy: saving,
            ),
          ],
        ),
      ),
    );
  }
}

/// Appends a cue to the end of the list.
///
/// Disabled once the cues already reach the end of the video: a line past
/// the end would never play, so there is nothing left to caption.
class _AddCueButton extends StatelessWidget {
  const _AddCueButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DivineButton(
        label: context.l10n.subtitleEditorAddCue,
        type: DivineButtonType.secondary,
        leadingIcon: DivineIconName.plus,
        onPressed: enabled
            ? () => context.read<SubtitleEditorCubit>().addCue()
            : null,
      ),
    );
  }
}

/// The video and its filmstrip, above the list that edits the captions.
///
/// The timeline is a viewing surface, not an editing one: it says which frame
/// the playhead is on. Timing is changed with the sliders below, and picking a
/// row jumps the picture to that cue.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.state,
    required this.videoUrl,
    required this.playbackUrls,
    required this.videoId,
    required this.loadFrames,
  });

  final SubtitleEditorState state;
  final String videoUrl;
  final List<String> playbackUrls;
  final String videoId;
  final TimelineFrameLoader loadFrames;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SubtitleEditorStage(
            videoUrl: videoUrl,
            playbackUrls: playbackUrls,
            videoId: videoId,
            cues: state.cues,
            totalDuration: Duration(milliseconds: state.timelineDurationMs),
            selectedCue: state.selectedCue,
            loadFrames: loadFrames,
          ),
        ),
        Divider(height: 1, color: context.vineColors.surfaceContainer),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({
    required this.index,
    required this.cue,
    required this.totalDuration,
    required this.isSelected,
  });

  final int index;
  final EditableCue cue;

  /// Slider range: the whole video, so cues may freely overlap each other.
  final Duration totalDuration;

  /// Whether this is the cue the preview is showing.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SubtitleEditorCubit>();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => cubit.selectCue(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: CaptionCueRow(
          text: cue.text,
          start: Duration(milliseconds: cue.start),
          end: Duration(milliseconds: cue.end),
          totalDuration: totalDuration,
          isSelected: isSelected,
          textFieldLabel: l10n.subtitleEditorCueHint,
          removeSemanticLabel: l10n.subtitleEditorRemoveCue,
          onTimingChanged: (start, end) => cubit.updateCueTiming(
            index,
            start: start.inMilliseconds,
            end: end.inMilliseconds,
          ),
          onTextChanged: (value) => cubit.updateCueText(index, value),
          onRemoved: () => cubit.removeCue(index),
          // Typing in a row is the clearest statement of which cue the creator
          // is on, so it drives the preview selection too.
          onFocused: () => cubit.selectCue(index),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.busy});

  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.subtitleEditorSave,
      expanded: true,
      isLoading: busy,
      onPressed: enabled
          ? () => context.read<SubtitleEditorCubit>().save()
          : null,
    );
  }
}
