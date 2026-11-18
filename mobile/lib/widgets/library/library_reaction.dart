// ABOUTME: Starts a reaction from a saved clip using the camera and layout tools.
// ABOUTME: Keeps the unfinished draft and the source footage before a new session.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/library_reaction/library_reaction_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/router/creation_session_guard.dart';
import 'package:openvine/router/routes/video_routes.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_split_screen_layout_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

/// Concatenates all cuts accepted from the reaction camera, in capture order.
typedef LibraryReactionMerge = MergeReactionTakes;

/// Opens a filled layout, returning only the user's confirmed render.
typedef LibraryReactionLayout = Future<DivineVideoClip?> Function(
  BuildContext context,
  List<DivineVideoClip> clips,
  SplitScreenCellPicker pickFromLibrary,
  SplitScreenCellPicker recordWithCamera,
);

/// Keeps the active editor session as a draft and clears it, records a take,
/// reviews it beside [source], and opens the confirmed layout in the editor.
/// The optional callbacks stand in for the camera, layout, renderer, cleanup
/// and editor in tests.
Future<void> recordLibraryReaction(
  BuildContext context,
  WidgetRef ref,
  DivineVideoClip source, {
  SplitScreenCellPicker? recordWithCamera,
  LibraryReactionLayout? showLayout,
  LibraryReactionMerge? mergeTakes,
  ExtractReactionPoster? extractThumbnail,
  Future<void> Function(List<String> paths)? cleanupAbandoned,
  Future<void> Function(BuildContext context)? openEditor,
}) async {
  final router = GoRouter.maybeOf(context);
  if (router != null &&
      hasCreationSessionInRouteStack(
        router.routerDelegate.currentConfiguration,
      )) {
    return;
  }
  final editor = ref.read(videoEditorProvider.notifier);
  final publish = ref.read(videoPublishProvider.notifier);
  final manager = ref.read(clipManagerProvider.notifier);
  final owner = ref.read(authServiceProvider).currentPublicKeyHex;
  // Capture the connection before navigation; cleanup can outlive its widget.
  final database = cleanupAbandoned == null ? ref.read(databaseProvider) : null;

  bool isActive() =>
      context.mounted &&
      ref.read(authServiceProvider).currentPublicKeyHex == owner &&
      identical(ref.read(clipManagerProvider.notifier), manager);

  // A full recorder session must not consume the reaction's recording budget.
  // Keep edited work as a named draft before clearing its active session.
  final keptDraftId = await editor.keepAutosaveAsDraft();
  if (!context.mounted ||
      !isActive() ||
      ModalRoute.of(context)?.isCurrent == false) {
    if (keptDraftId != null) await editor.discardKeptDraft(keptDraftId);
    return;
  }
  await publish.clearAll();
  if (!context.mounted || !isActive() || manager.clips.isNotEmpty) return;
  final reaction = LibraryReactionCubit(
    deferFileCleanup: editor.deferFileCleanup,
    bakeCapturedChromaKey: manager.bakeCapturedChromaKey,
    draftsDao: database?.draftsDao,
    clipsDao: database?.clipsDao,
    mergeTakes: mergeTakes,
    extractThumbnail: extractThumbnail,
    cleanupFiles: cleanupAbandoned,
  );

  Future<List<DivineVideoClip>?> record(
    BuildContext cameraContext, {
    required double cellAspectRatio,
    required int maxClips,
  }) async {
    final initialIds = manager.clips.map((clip) => clip.id).toSet();
    final route = editorRecorderRoute(
      VideoRecorderRoute(
        fromEditor: true,
        entryPoint: CreationEntryPoint.editor,
        cropGuideAspectRatio: cellAspectRatio,
      ),
    );
    final result = await Navigator.of(cameraContext).push<bool>(route);
    await route.completed;
    if (!isActive()) return null;
    final takeIds = manager.clips
        .where((clip) => !initialIds.contains(clip.id))
        .map((clip) => clip.id)
        .toSet();
    // Extraction waits for camera processing and its enriched library save.
    // Even a cancelled take stays in the library, outside this timeline.
    final takes = await manager.extractClips(takeIds);
    return isActive() && result == true && takes.isNotEmpty ? takes : null;
  }

  Future<List<DivineVideoClip>?> pick(
    BuildContext layoutContext, {
    required double cellAspectRatio,
    required int maxClips,
  }) => VineBottomSheet.show<List<DivineVideoClip>>(
    context: layoutContext,
    maxChildSize: 1,
    initialChildSize: 0.9,
    minChildSize: VineTheme.bottomSheetDismissFloor,
    buildScrollBody: (controller) => LibraryScreen(
      initialTabIndex: LibraryScreen.clipsTabIndex,
      selectionMode: true,
      allowsMixedClipTypes: true,
      cropGuideAspectRatio: cellAspectRatio,
      maxSelectedClips: maxClips,
      scrollController: controller,
    ),
  );

  final capture = recordWithCamera ?? record;
  Future<List<DivineVideoClip>?> recordCell(
    BuildContext captureContext, {
    required double cellAspectRatio,
    required int maxClips,
  }) async {
    final takes = await capture(
      captureContext,
      cellAspectRatio: cellAspectRatio,
      maxClips: maxClips,
    );
    if (!captureContext.mounted ||
        !isActive() ||
        takes == null ||
        takes.isEmpty) {
      return null;
    }
    if (takes.length == 1) return takes;

    // Several stop/start cuts are one reaction, rather than extra cells.
    final overlay = OverlayEntry(
      builder: (_) => BlocBuilder<LibraryReactionCubit, LibraryReactionState>(
        bloc: reaction,
        builder: (_, state) => state.status == LibraryReactionStatus.merging
            ? const _ReactionMergeProgress()
            : const SizedBox.shrink(),
      ),
    );
    Overlay.of(captureContext, rootOverlay: true).insert(overlay);
    DivineVideoClip? merged;
    try {
      merged = await reaction.combine(takes);
    } finally {
      overlay.remove();
      overlay.dispose();
    }
    if (!captureContext.mounted || !isActive()) return null;
    if (merged == null) {
      ScaffoldMessenger.of(captureContext).showSnackBar(
        DivineSnackbarContainer.snackBar(
          captureContext.l10n.videoEditorMergeFailed,
          error: true,
        ),
      );
      return null;
    }
    return [merged];
  }

  try {
    final takes = await recordCell(
      context,
      cellAspectRatio: source.targetAspectRatio.value / 2,
      maxClips: 1,
    );
    if (!context.mounted ||
        !isActive() ||
        takes == null ||
        takes.isEmpty ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    final clips = [source, takes.single];
    final result =
        await (showLayout?.call(context, clips, pick, recordCell) ??
            VideoEditorSplitScreenLayoutScreen.push(
              context,
              aspectRatio: source.targetAspectRatio,
              initialClips: clips,
              pickFromLibrary: pick,
              recordWithCamera: recordCell,
              bakeCapturedChromaKey: manager.bakeCapturedChromaKey,
              deferFileCleanup: editor.deferFileCleanup,
            ));
    if (result == null) return;
    if (!context.mounted ||
        !isActive() ||
        ModalRoute.of(context)?.isCurrent == false) {
      await reaction.cleanupFiles(
        result.ownedFilePaths.whereType<String>().toList(),
      );
      return;
    }
    manager.insertClip(0, result);
    // Queue before the editor can publish/discard and flush this session.
    reaction.adoptGeneratedFiles();
    if (openEditor != null) {
      await openEditor(context);
    } else {
      await const VideoEditorRouteData(from: VideoEditorScreen.libraryOrigin)
          .push<void>(context);
    }
  } finally {
    await reaction.cleanupGeneratedFiles();
    await reaction.close();
  }
}

class _ReactionMergeProgress extends StatelessWidget {
  const _ReactionMergeProgress();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: BlockSemantics(
      child: AbsorbPointer(
        child: Material(
          color: context.vineColors.surface,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                const DivineCircularProgressIndicator(),
                Text(
                  context.l10n.videoEditorMergeProgressLabel,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
