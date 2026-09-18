// ABOUTME: Full-screen progress overlays for the long-running clip operations
// ABOUTME: (reverse, transform, detach, merge) that block the editor.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// The blocking progress overlays for [ClipEditorBloc]'s render operations.
///
/// Each overlay renders nothing until its operation is in flight, then covers
/// the editor with a scrim and live progress until the render lands.
class ClipOperationProgressOverlays extends StatelessWidget {
  const ClipOperationProgressOverlays({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: .expand,
      // Matches the editor stack these overlays were lifted out of, which is
      // Clip.none: a Stack otherwise defaults to Clip.hardEdge and would clip
      // anything an overlay paints past the scrim's edge.
      clipBehavior: .none,
      children: [
        _ReverseProgressOverlay(),
        _TransformProgressOverlay(),
        _DetachProgressOverlay(),
        _MergeProgressOverlay(),
      ],
    );
  }
}

class _ReverseProgressOverlay extends StatelessWidget {
  const _ReverseProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isReversing, String? renderId})
    >(
      selector: (state) => (
        isReversing: state.isReversing,
        renderId: state.reversingClipId,
      ),
      builder: (context, reverseState) {
        if (!reverseState.isReversing || reverseState.renderId == null) {
          return const SizedBox.shrink();
        }

        return ColoredBox(
          color: context.vineColors.background.withAlpha(210),
          child: Center(
            child: RepaintBoundary(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  // Transient render progress is read straight from the
                  // plugin stream (no service indirection) since it is purely
                  // ephemeral UI feedback that never outlives this overlay.
                  StreamBuilder<ProgressModel>(
                    stream: ProVideoEditor.instance.progressStreamById(
                      reverseState.renderId!,
                    ),
                    builder: (context, snapshot) {
                      final progress = snapshot.data?.progress ?? 0;
                      return PartialCircleSpinner(progress: progress);
                    },
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 240),
                    child: Text(
                      context.l10n.videoEditorReverseProgressLabel,
                      textAlign: TextAlign.center,
                      style: VineTheme.bodyMediumFont(
                        color: context.vineColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full-screen progress overlay shown while the still that replaces a detached
/// clip is encoded.
///
/// Over everything, like the transform overlay it mirrors: the detach is a
/// composition-wide change, and leaving only a spinner on one action button
/// left the rest of the timeline looking tappable while a render was mid-flight.
class _DetachProgressOverlay extends StatelessWidget {
  const _DetachProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipEditorBloc, ClipEditorState, String?>(
      selector: (state) => state.isDetaching ? state.detachingRenderId : null,
      builder: (context, renderId) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: renderId == null
              ? const SizedBox.shrink()
              : _RenderProgressContent(
                  renderId: renderId,
                  label: context.l10n.videoEditorDetachProgressLabel,
                ),
        );
      },
    );
  }
}

/// Full-screen progress overlay shown while a transform (crop/rotate/flip) is
/// re-rendered into a new clip file. Absorbs input for the duration so the
/// timeline controls underneath can't start a competing edit (reverse, delete,
/// split) mid-render, and fades in/out via [AnimatedSwitcher] so it doesn't pop
/// on/off abruptly.
class _TransformProgressOverlay extends StatelessWidget {
  const _TransformProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isTransforming, String? renderId})
    >(
      selector: (state) => (
        isTransforming: state.isTransforming,
        renderId: state.transformingClipId,
      ),
      builder: (context, transformState) {
        final renderId = transformState.isTransforming
            ? transformState.renderId
            : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: renderId == null
              ? const SizedBox.shrink()
              : _RenderProgressContent(
                  renderId: renderId,
                  label: context.l10n.videoEditorTransformProgressLabel,
                ),
        );
      },
    );
  }
}

/// A render's progress, over the whole editor, absorbing input for the
/// duration so nothing underneath can start a competing edit.
class _RenderProgressContent extends StatelessWidget {
  const _RenderProgressContent({required this.renderId, required this.label});

  final String renderId;

  /// What the user is waiting for, already localized.
  final String label;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: context.vineColors.background.withAlpha(210),
        child: Center(
          child: RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                StreamBuilder<ProgressModel>(
                  stream: ProVideoEditor.instance.progressStreamById(renderId),
                  builder: (context, snapshot) {
                    final progress = snapshot.data?.progress ?? 0;
                    return PartialCircleSpinner(progress: progress);
                  },
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen progress overlay shown while the selected clips are concatenated
/// into a single new clip file. Absorbs input for the duration so the timeline
/// controls underneath can't start a competing edit mid-render, and fades
/// in/out via [AnimatedSwitcher].
class _MergeProgressOverlay extends StatelessWidget {
  const _MergeProgressOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ClipEditorBloc,
      ClipEditorState,
      ({bool isMerging, String? renderId})
    >(
      selector: (state) => (
        isMerging: state.isMerging,
        renderId: state.mergingRenderId,
      ),
      builder: (context, mergeState) {
        final renderId = mergeState.isMerging ? mergeState.renderId : null;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: renderId == null
              ? const SizedBox.shrink()
              : _RenderProgressContent(
                  renderId: renderId,
                  label: context.l10n.videoEditorMergeProgressLabel,
                ),
        );
      },
    );
  }
}
