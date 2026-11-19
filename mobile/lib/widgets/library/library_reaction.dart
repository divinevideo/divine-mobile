// ABOUTME: Starts a reaction from a saved clip using the camera and layout tools.
// ABOUTME: Keeps the unfinished draft and the source footage before a new session.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/library_reaction/library_reaction_cubit.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/social_providers.dart';
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
import 'package:openvine/widgets/library/library_reaction_progress_host.dart';
import 'package:unified_logger/unified_logger.dart' show Log, LogCategory;

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
  Future<void> Function(
    BuildContext context,
    CreationAnalyticsSession analyticsSession,
  )?
  openEditor,
}) async {
  final router = GoRouter.maybeOf(context);
  bool hasCreationRoute() =>
      router != null &&
      hasCreationSessionInRouteStack(
        router.routerDelegate.currentConfiguration,
      );

  if (hasCreationRoute()) return;
  final editor = ref.read(videoEditorProvider.notifier);
  final publish = ref.read(videoPublishProvider.notifier);
  final manager = ref.read(clipManagerProvider.notifier);
  final analytics = ref.read(creationAnalyticsTrackerProvider);
  final owner = ref.read(authServiceProvider).currentPublicKeyHex;
  // Capture the connection before navigation; cleanup can outlive its widget.
  final database = cleanupAbandoned == null ? ref.read(databaseProvider) : null;

  bool isActive() =>
      context.mounted &&
      ref.read(authServiceProvider).currentPublicKeyHex == owner &&
      identical(ref.read(clipManagerProvider.notifier), manager);

  bool canOpenCamera() =>
      isActive() &&
      ModalRoute.of(context)?.isCurrent != false &&
      !hasCreationRoute();

  // A full recorder session must not consume the reaction's recording budget.
  // Keep edits in a draft and give unedited footage its own Library rows
  // before clearing the autosave that may be the only reference to it.
  final String? keptDraftId;
  try {
    final library = ref.read(clipLibraryServiceProvider);
    keptDraftId = await editor.keepAutosaveAsDraft(
      retainUneditedClips: (clips) async {
        if (!isActive()) {
          throw StateError('The reaction source account changed');
        }
        for (final clip in clips) {
          if (!clip.isPlaceholder && !clip.isFreezeFrame) {
            await library.retainClip(clip);
          }
        }
      },
    );
  } catch (error, stackTrace) {
    Log.warning(
      'Could not keep the active draft before recording a library reaction',
      name: 'LibraryReaction',
      category: LogCategory.video,
      error: error,
      stackTrace: stackTrace,
    );
    if (context.mounted && canOpenCamera()) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoMetadataFailedToSaveSnackbar,
          error: true,
        ),
      );
    }
    return;
  }
  if (!canOpenCamera()) {
    if (keptDraftId != null) await editor.discardKeptDraft(keptDraftId);
    return;
  }
  await publish.clearAll();
  if (!context.mounted || !canOpenCamera() || manager.clips.isNotEmpty) {
    return;
  }
  final reaction = LibraryReactionCubit(
    deferFileCleanup: editor.deferFileCleanup,
    bakeCapturedChromaKey: manager.bakeCapturedChromaKey,
    draftsDao: database?.draftsDao,
    clipsDao: database?.clipsDao,
    mergeTakes: mergeTakes,
    extractThumbnail: extractThumbnail,
    cleanupFiles: cleanupAbandoned,
  );
  final analyticsSession = CreationAnalyticsSession();

  void abandonAnalytics() {
    unawaited(analytics.creationAbandoned(session: analyticsSession));
  }

  Future<T> withProgress<T>(
    BuildContext progressContext,
    Future<T> Function() work, {
    VoidCallback? onLeave,
  }) async {
    final ownerRoute = ModalRoute.of(progressContext);
    Future<void> leaveProgress() async {
      if (!progressContext.mounted || ownerRoute?.isCurrent == false) return;
      abandonAnalytics();
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

    final hideProgress = LibraryReactionProgressHost.show(
      progressContext,
      BlocBuilder<LibraryReactionCubit, LibraryReactionState>(
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
    StreamSubscription<Object?>? routeExit;
    var dismissed = false;
    void dismiss() {
      if (dismissed) return;
      dismissed = true;
      hideProgress?.call();
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
            abandonAnalytics();
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
    // Keep the original account's stores even when this route has left.
    final library = ref.read(clipLibraryServiceProvider);
    final draftStorage = ref.read(draftStorageServiceProvider);
    final route = editorRecorderRoute(
      VideoRecorderRoute(
        fromEditor: true,
        entryPoint: CreationEntryPoint.library,
        cropGuideAspectRatio: cellAspectRatio,
        analyticsSession: analyticsSession,
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
    var retentionFailed = false;
    Future<List<DivineVideoClip>> extract() =>
        extraction ??= manager.extractClips(
          takeIds,
          retain: (takes) async {
            try {
              for (final take in takes) {
                await library.retainClip(take);
              }
            } catch (_) {
              retentionFailed = true;
              rethrow;
            }
          },
        );
    void abandon() {
      if (!manager.isSessionCurrent(generation)) return;
      final snapshots = manager.clips
          .where((clip) => takeIds.contains(clip.id))
          .toList(growable: false);
      if (snapshots.isEmpty) return;
      final recovery = DivineVideoDraft.create(
        clips: snapshots,
        title: '',
        description: '',
        hashtags: const {},
        selectedApproach: 'video',
      );
      final retained = editor.retainAbandonedReaction(() async {
        final unsaved = <DivineVideoClip>[];
        for (final clip in snapshots) {
          try {
            await library.retainClip(clip);
          } catch (error, stackTrace) {
            Log.warning(
              'Could not retain reaction recording in the Library',
              name: 'LibraryReaction',
              category: LogCategory.video,
              error: error,
              stackTrace: stackTrace,
            );
            unsaved.add(clip);
          }
        }
        if (unsaved.isNotEmpty) {
          await draftStorage.saveDraft(recovery.copyWith(clips: unsaved));
        }
      });
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
      final settled = extraction;
      runDetached(
        retained.then<void>((_) {
          if (paths.isEmpty) return Future<void>.value();
          if (settled == null) return reaction.cleanupFiles(paths);
          return settled.then<void>(
            (_) => reaction.cleanupFiles(paths),
            onError: (Object _, StackTrace _) => reaction.cleanupFiles(paths),
          );
        }),
        'retain abandoned reaction recordings and clean their metadata',
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
      if (retentionFailed) abandon();
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
    if (!isActive() || result != true || takes.isEmpty) return null;
    if (analytics.activeRecorderMode(analyticsSession) case final mode?) {
      unawaited(
        analytics.recordingCompleted(
          session: analyticsSession,
          mode: mode,
          clipCount: takes.length,
          duration: takes.fold(
            Duration.zero,
            (duration, take) => duration + take.budgetDuration,
          ),
          hasSound: ref.read(videoEditorProvider).selectedSound != null,
          hasColorMask: takes.any(
            (take) => take.captureChromaKey != null || take.chromaKey != null,
          ),
        ),
      );
    }
    return takes;
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
    if (!captureContext.mounted ||
        !isActive() ||
        ModalRoute.of(captureContext)?.isCurrent == false) {
      return null;
    }
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
      await openEditor(context, analyticsSession);
    } else {
      await VideoEditorRouteData(
        from: VideoEditorScreen.libraryOrigin,
        $extra: analyticsSession,
      ).push<void>(context);
    }
  } finally {
    abandonAnalytics();
    await reaction.cleanupGeneratedFiles();
    await reaction.close();
  }
}

class _ReactionProgress extends StatelessWidget {
  const _ReactionProgress({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
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
