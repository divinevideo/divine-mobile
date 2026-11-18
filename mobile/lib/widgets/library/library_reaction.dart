// ABOUTME: Starts a reaction from a saved clip using the camera and layout tools.
// ABOUTME: Keeps the unfinished draft and the source footage before a new session.

import 'dart:async';

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
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_split_screen_layout_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart' show LogCategory;

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

  Future<T> withProgress<T>(
    BuildContext progressContext,
    Future<T> Function() work, {
    VoidCallback? onLeave,
  }) async {
    final ownerRoute = ModalRoute.of(progressContext);
    Future<void> leaveProgress() async {
      if (!progressContext.mounted || ownerRoute?.isCurrent == false) return;
      if (onLeave != null) {
        runDetached(
          Future<void>.sync(onLeave),
          'release abandoned reaction takes',
          logName: 'LibraryReaction',
          category: LogCategory.ui,
        );
      }
      if (await Navigator.of(progressContext).maybePop()) return;
      if (!progressContext.mounted || ownerRoute?.isCurrent == false) return;
      GoRouter.maybeOf(progressContext)?.go(VideoFeedPage.pathForIndex(0));
    }

    final overlay = OverlayEntry(
      builder: (_) => BlocBuilder<LibraryReactionCubit, LibraryReactionState>(
        bloc: reaction,
        builder: (context, state) => state.isBusy
            ? _ReactionProgress(
                label: state.status == LibraryReactionStatus.preparing
                    ? context.l10n.libraryPreparingVideo
                    : context.l10n.videoEditorMergeProgressLabel,
                onBack: () => runDetached(
                  leaveProgress(),
                  'leave reaction preparation',
                  logName: 'LibraryReaction',
                  category: LogCategory.ui,
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
    Overlay.of(progressContext, rootOverlay: true).insert(overlay);
    StreamSubscription<Object?>? routeExit;
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      overlay.remove();
      overlay.dispose();
      final cancellation = routeExit?.cancel();
      if (cancellation != null) {
        runDetached(
          cancellation,
          'cancel reaction progress route listener',
          logName: 'LibraryReaction',
          category: LogCategory.ui,
        );
      }
    }

    // Back remains available while native processing finishes. Leaving the
    // owning route removes this UI without canceling the take's library save.
    routeExit = ownerRoute?.popped.asStream().cast<Object?>().listen((_) {
      runDetached(
        Future<void>.sync(() {
          try {
            onLeave?.call();
          } finally {
            dismiss();
          }
        }),
        'release reaction progress after route exit',
        logName: 'LibraryReaction',
        category: LogCategory.ui,
      );
    });
    try {
      return await work();
    } finally {
      dismiss();
    }
  }

  Future<List<DivineVideoClip>?> record(
    BuildContext cameraContext, {
    required double cellAspectRatio,
    required int maxClips,
  }) async {
    final generation = manager.sessionGeneration;
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
    if (!manager.isSessionCurrent(generation)) return null;
    final takeIds = manager.clips
        .where((clip) => !initialIds.contains(clip.id))
        .map((clip) => clip.id)
        .toSet();
    if (takeIds.isEmpty) return null;
    Future<List<DivineVideoClip>>? extraction;
    Future<List<DivineVideoClip>> extract() =>
        extraction ??= manager.extractClips(takeIds);
    void abandon() {
      final removed = manager.abandonExtraction(
        takeIds,
        generation: generation,
      );
      final paths = [
        for (final clip in removed)
          if (!clip.isStopMotion) ...[
            clip.thumbnailPath,
            clip.ghostFramePath,
            clip.secondaryCamera?.clip.thumbnailPath,
            clip.secondaryCamera?.compositeThumbnailPath,
          ],
      ].whereType<String>().toList();
      if (paths.isEmpty) return;
      final settled = extraction;
      runDetached(
        settled == null
            ? reaction.cleanupFiles(paths)
            : settled.then<void>(
                (_) => reaction.cleanupFiles(paths),
                onError: (Object _, StackTrace _) =>
                    reaction.cleanupFiles(paths),
              ),
        'clean abandoned reaction metadata',
        logName: 'LibraryReaction',
        category: LogCategory.ui,
      );
    }

    Future<List<DivineVideoClip>> extractWithoutOwner() {
      final pending = extract();
      abandon();
      return pending;
    }

    // Extraction waits for camera processing and its enriched library save.
    // Even a cancelled take stays in the library, outside this timeline.
    final takes =
        isActive() &&
            cameraContext.mounted &&
            ModalRoute.of(cameraContext)?.isCurrent != false
        ? await withProgress(
            cameraContext,
            () => reaction.prepareTakes(extract),
            onLeave: abandon,
          )
        : await extractWithoutOwner();
    if (takes == null) {
      if (cameraContext.mounted &&
          isActive() &&
          ModalRoute.of(cameraContext)?.isCurrent != false) {
        ScaffoldMessenger.of(cameraContext).showSnackBar(
          DivineSnackbarContainer.snackBar(
            cameraContext.l10n.videoEditorClipSaveFailed,
            error: true,
          ),
        );
      }
      return null;
    }
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
        ModalRoute.of(captureContext)?.isCurrent == false ||
        takes == null ||
        takes.isEmpty) {
      return null;
    }
    if (takes.length == 1) return takes;

    // Several stop/start cuts are one reaction, rather than extra cells.
    final merged = await withProgress(
      captureContext,
      () => reaction.combine(takes),
    );
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
    // An own-source layout with no further edits is not an edited draft.
    // Give the confirmed render its own library row before the autosave can
    // be replaced by another session, just as the camera keeps every take.
    final saved = await manager.saveClipToLibrary(result);
    if (!context.mounted ||
        !isActive() ||
        ModalRoute.of(context)?.isCurrent == false) {
      await reaction.cleanupFiles(
        result.ownedFilePaths.whereType<String>().toList(),
      );
      return;
    }
    if (!saved) {
      await reaction.cleanupFiles(
        result.ownedFilePaths.whereType<String>().toList(),
      );
      if (context.mounted &&
          isActive() &&
          ModalRoute.of(context)?.isCurrent != false) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorClipSaveFailed,
            error: true,
          ),
        );
      }
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

class _ReactionProgress extends StatelessWidget {
  const _ReactionProgress({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: BlockSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const AbsorbPointer(child: SizedBox.expand()),
          Material(
            color: context.vineColors.surface,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 16,
                children: [
                  const DivineCircularProgressIndicator(),
                  Text(
                    label,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                  ),
                  DivineButton(
                    label: context.l10n.commonBack,
                    type: .secondary,
                    onPressed: onBack,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
