// ABOUTME: Full-screen split-screen layout builder: pick a layout, fill its
// ABOUTME: cells from the library or the camera, then place it in one step

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_editor/split_screen_layout/split_screen_layout_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_controls.dart';
import 'package:openvine/widgets/video_editor/split_screen_layout/split_screen_layout_preview.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ProVideoEditor, ProgressModel;

/// Fetches clips for a cell of [cellAspectRatio], opened from the layout
/// screen's [context], or `null` when the user backs out. [maxClips] is how
/// many the layout has room for, the selected cell included.
typedef SplitScreenCellPicker = Future<List<DivineVideoClip>?> Function(
  BuildContext context, {
  required double cellAspectRatio,
  required int maxClips,
});

/// Builds a split-screen layout and hands it back, rendered, on Done.
///
/// Pops with the clip the layout was rendered into, or with `null` when
/// closed. Nothing touches the editor until then, so closing costs nothing.
///
/// The pickers come from the editor, which owns the library sheet and the
/// camera; the screen only decides which cell they fill.
class VideoEditorSplitScreenLayoutScreen extends StatelessWidget {
  const VideoEditorSplitScreenLayoutScreen({
    required this.aspectRatio,
    required this.pickFromLibrary,
    required this.recordWithCamera,
    this.bakeCapturedChromaKey,
    this.deferFileCleanup,
    super.key,
  });

  /// The shape of the video the layout splits.
  final model.AspectRatio aspectRatio;

  final SplitScreenCellPicker pickFromLibrary;
  final SplitScreenCellPicker recordWithCamera;
  final SplitScreenBakeChromaKeyFn? bakeCapturedChromaKey;
  final SplitScreenDeferFileCleanupFn? deferFileCleanup;

  /// Opens the screen full-screen over the editor.
  static Future<DivineVideoClip?> push(
    BuildContext context, {
    required model.AspectRatio aspectRatio,
    required SplitScreenCellPicker pickFromLibrary,
    required SplitScreenCellPicker recordWithCamera,
    SplitScreenBakeChromaKeyFn? bakeCapturedChromaKey,
    SplitScreenDeferFileCleanupFn? deferFileCleanup,
  }) {
    return Navigator.of(context).push<DivineVideoClip>(
      PageRouteBuilder<DivineVideoClip>(
        settings: const RouteSettings(name: 'split_screen_layout'),
        pageBuilder: (_, _, _) => VideoEditorSplitScreenLayoutScreen(
          aspectRatio: aspectRatio,
          pickFromLibrary: pickFromLibrary,
          recordWithCamera: recordWithCamera,
          bakeCapturedChromaKey: bakeCapturedChromaKey,
          deferFileCleanup: deferFileCleanup,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SplitScreenLayoutCubit(
        aspectRatio: aspectRatio,
        borderColor: VineTheme.backgroundColor,
        bakeCapturedChromaKey: bakeCapturedChromaKey,
        deferFileCleanup: deferFileCleanup,
      ),
      child: VideoEditorSplitScreenLayoutView(
        pickFromLibrary: pickFromLibrary,
        recordWithCamera: recordWithCamera,
      ),
    );
  }
}

/// The layout screen under its [SplitScreenLayoutCubit].
class VideoEditorSplitScreenLayoutView extends StatelessWidget {
  @visibleForTesting
  const VideoEditorSplitScreenLayoutView({
    required this.pickFromLibrary,
    required this.recordWithCamera,
    super.key,
  });

  final SplitScreenCellPicker pickFromLibrary;
  final SplitScreenCellPicker recordWithCamera;

  @override
  Widget build(BuildContext context) {
    final (:isApplying, :canApply) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        isApplying: cubit.state.isApplying,
        canApply: cubit.state.canApply,
      ),
    );

    return PopScope(
      // The render writes files the editor is about to own; leaving halfway
      // would strand them, so the back gesture is held, like Close.
      canPop: !isApplying,
      child: BlocListener<SplitScreenLayoutCubit, SplitScreenLayoutState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: _onStatusChanged,
        child: Scaffold(
          backgroundColor: context.vineColors.surfaceContainerHigh,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    VideoEditorToolbar(
                      onClose: () {
                        if (!isApplying) Navigator.of(context).pop();
                      },
                      onDone: canApply
                          ? context.read<SplitScreenLayoutCubit>().apply
                          : null,
                      closeSemanticLabel:
                          context.l10n.videoEditorLayoutCloseSemanticLabel,
                      doneSemanticLabel:
                          context.l10n.videoEditorLayoutDoneSemanticLabel,
                      center: Text(
                        context.l10n.videoEditorLayoutTitle,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.onSurface,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Padding(
                        padding: .all(16),
                        child: SplitScreenLayoutPreview(),
                      ),
                    ),
                    SplitScreenCellActions(
                      onPickFromLibrary: () =>
                          _fillSelectedCell(context, pickFromLibrary),
                      onRecordWithCamera: () =>
                          _fillSelectedCell(context, recordWithCamera),
                    ),
                    const SizedBox(height: 16),
                    const SplitScreenPresetPicker(),
                    const SizedBox(height: 16),
                    const SplitScreenBorderControls(),
                    const SizedBox(height: 16),
                  ],
                ),
                if (isApplying) const _ApplyingOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onStatusChanged(BuildContext context, SplitScreenLayoutState state) {
    switch (state.status) {
      case SplitScreenLayoutStatus.applied:
        Navigator.of(context).pop(state.result);
      case SplitScreenLayoutStatus.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorLayoutFailed,
          ),
        );
      case SplitScreenLayoutStatus.editing:
      case SplitScreenLayoutStatus.applying:
        break;
    }
  }

  /// Opens [picker] for the selected cell and puts what comes back into the
  /// layout, telling the user when some of it found no empty cell.
  Future<void> _fillSelectedCell(
    BuildContext context,
    SplitScreenCellPicker picker,
  ) async {
    final cubit = context.read<SplitScreenLayoutCubit>();
    final state = cubit.state;
    if (state.isApplying) return;
    final clips = await picker(
      context,
      cellAspectRatio: splitScreenCellAspectRatio(
        state.cellRects[state.selectedCellIndex],
        state.frameAspectRatio,
      ),
      maxClips: state.pickableClipCount,
    );
    if (clips == null || clips.isEmpty || cubit.isClosed) return;
    final leftOver = cubit.clipsPicked(clips);
    if (leftOver == 0 || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.videoEditorLayoutClipsDidNotFit,
      ),
    );
  }
}

/// Blocks the screen while the layout renders, with the running render's
/// progress and, when a stop-motion set is assembled first, which step it is.
class _ApplyingOverlay extends StatelessWidget {
  const _ApplyingOverlay();

  @override
  Widget build(BuildContext context) {
    final (:renderId, :step, :stepCount) = context.select(
      (SplitScreenLayoutCubit cubit) => (
        renderId: cubit.state.applyRenderId,
        step: cubit.state.applyStep,
        stepCount: cubit.state.applyStepCount,
      ),
    );
    return Positioned.fill(
      // Pointers are absorbed by the box, but semantics travel their own path:
      // without BlockSemantics the controls underneath stay reachable to a
      // screen reader while the render runs on the choices made before.
      child: BlockSemantics(
        child: ColoredBox(
          color: context.vineColors.background.withAlpha(210),
          child: Center(
            child: Column(
              mainAxisSize: .min,
              spacing: 16,
              children: [
                RepaintBoundary(
                  child: renderId == null
                      ? const PartialCircleSpinner(progress: 0)
                      : StreamBuilder<ProgressModel>(
                          stream: ProVideoEditor.instance.progressStreamById(
                            renderId,
                          ),
                          builder: (context, snapshot) => PartialCircleSpinner(
                            progress: snapshot.data?.progress ?? 0,
                          ),
                        ),
                ),
                Text(
                  context.l10n.videoEditorLayoutApplying,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                if (stepCount > 1)
                  Text(
                    context.l10n.videoEditorLayoutApplyStep(
                      '$step',
                      '$stepCount',
                    ),
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.secondaryText,
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
