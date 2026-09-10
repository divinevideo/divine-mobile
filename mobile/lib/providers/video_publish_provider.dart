// ABOUTME: Riverpod provider for managing video publish screen state
// ABOUTME: Controls playback, mute state, and position tracking

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dm_repository/dm_repository.dart'
    show CollaboratorInviteRetrySummary;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/post_publish/post_publish_experiment.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/publish_error_kind_l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/layer_rasterizer_provider.dart';
import 'package:openvine/providers/post_publish_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/cawg_verifier_client.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';
import 'package:openvine/services/video_editor/draft_render_parameters_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show CompleteParameters;
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Provider for video publish screen state management.
final videoPublishProvider =
    NotifierProvider<VideoPublishNotifier, VideoPublishProviderState>(
      VideoPublishNotifier.new,
    );

({String path, VideoDetailRouteExtra extra}) videoReplyPublishDestinationFor(
  VideoReplyContext context,
) => (
  path: VideoDetailScreen.pathForId(
    context.rootAddressableId ?? context.rootEventId,
  ),
  extra: const VideoDetailRouteExtra(autoOpenComments: true),
);

@visibleForTesting
MentionResolutionService? createVideoPublishMentionResolutionService(
  ProfileRepository? profileRepository,
) {
  if (profileRepository == null) return null;
  return MentionResolutionService(profileRepository: profileRepository);
}

/// Manages video publish screen state including playback and position.
class VideoPublishNotifier extends Notifier<VideoPublishProviderState> {
  /// Source-draft ids with a publish currently in flight. Lives outside
  /// [state] because [clearAll] intentionally resets the state ~600ms
  /// after navigation while the publish future keeps running for 20s+;
  /// a state-based guard reopens in that window and admits duplicate
  /// publishes of the same draft (#6018).
  final Set<String> _inFlightSourceDraftIds = {};

  DraftStorageService get _draftService =>
      ref.read(draftStorageServiceProvider);
  CawgVerifierClient get _cawgVerifierClient =>
      ref.read(cawgVerifierClientProvider);

  @override
  VideoPublishProviderState build() {
    return const VideoPublishProviderState();
  }

  /// Social verification remains optional. Prefer OAuth when supported, then
  /// fall back to public proof so publish never depends on a single method.
  @visibleForTesting
  List<VerifierRequiredMethod> preferredSocialVerificationMethods({
    required bool supportsOAuth,
  }) {
    if (supportsOAuth) {
      return const <VerifierRequiredMethod>[
        VerifierRequiredMethod.oauth,
        VerifierRequiredMethod.publicProof,
      ];
    }

    return const <VerifierRequiredMethod>[VerifierRequiredMethod.publicProof];
  }

  /// Fetches optional verifier-issued identity metadata without blocking
  /// creator-binding-only publish.
  Future<VerifierClaimBundle?> fetchOptionalVerifiedIdentity(
    VerifierClaimRequest request,
  ) async {
    final bundle = await _cawgVerifierClient.verifyClaims(request);
    if (bundle != null) {
      return bundle;
    }

    Log.info(
      'Identity verifier unavailable, continuing without CAWG overlay',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );
    return null;
  }

  @visibleForTesting
  bool shouldAttachCreatorIdentityProof(String? proofManifestJson) {
    if (proofManifestJson == null || proofManifestJson.isEmpty) {
      return true;
    }

    try {
      final decoded = jsonDecode(proofManifestJson);
      if (decoded is! Map<String, dynamic>) {
        return true;
      }

      final proofData = NativeProofData.fromJson(decoded);
      return !proofData.hasCreatorIdentityMetadata;
    } catch (_) {
      return true;
    }
  }

  /// Creates the publish service with callbacks wired to this notifier.
  Future<VideoPublishService> _createPublishService({
    required OnProgressChanged onProgressChanged,
  }) async {
    return VideoPublishService(
      uploadManager: ref.read(uploadManagerProvider),
      authService: ref.read(authServiceProvider),
      videoEventPublisher: ref.read(videoEventPublisherProvider),
      blossomService: ref.read(blossomUploadServiceProvider),
      draftService: _draftService,
      mentionResolutionService: createVideoPublishMentionResolutionService(
        ref.read(profileRepositoryProvider),
      ),
      collaboratorInviteService: CollaboratorInviteService(
        dmRepository: ref.read(dmRepositoryProvider),
        l10n: currentAppL10n(ref.read(sharedPreferencesProvider)),
      ),
      languagePreferenceService: ref.read(languagePreferenceServiceProvider),
      performanceMonitor: ref.read(performanceMonitoringServiceProvider),
      onProgressChanged: ({required String draftId, required double progress}) {
        setUploadProgress(draftId: draftId, progress: progress);
        onProgressChanged(draftId: draftId, progress: progress);
      },
    );
  }

  /// Resets all video-related providers.
  ///
  /// Clears recorder, editor, clip manager, and publish state.
  Future<void> clearAll({bool keepAutosavedDraft = false}) async {
    Log.debug(
      '🧹 Clearing all video providers',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );
    try {
      // The recorder bloc is screen-scoped; it resets to initial state when its
      // screen unmounts/remounts, so clearAll no longer resets it here (a
      // Notifier must not dispatch into VideoRecorderBloc).
      ref.read(videoReplyContextProvider.notifier).clear();
      reset();

      // The editor owns autosave deletion and starts deferred cleanup only
      // after that row is gone. Keeping the autosave here and deleting it after
      // reset would let cleanup permanently skip files the stale row protects.
      await Future.wait([
        ref.read(clipManagerProvider.notifier).clearSessionClips(),
        ref
            .read(videoEditorProvider.notifier)
            .reset(keepAutosavedDraft: keepAutosavedDraft),
      ]);
    } catch (error, stackTrace) {
      Log.error(
        '❌ Failed to clear video providers: $error',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resumes any pending publish drafts that were interrupted.
  ///
  /// Called on app startup to query only drafts with `publishing` or `failed`
  /// status and surface them to the user via [BackgroundPublishFailed].
  Future<void> resumePendingPublishes(BuildContext context) async {
    final List<DivineVideoDraft> pendingDrafts;
    try {
      pendingDrafts = await _draftService.getDraftsByPublishStatuses(const {
        PublishStatus.publishing,
        PublishStatus.failed,
      });
    } catch (e) {
      Log.error(
        '❌ Failed to load drafts for pending publish resume: $e',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return;
    }
    if (!context.mounted) return;

    if (pendingDrafts.isEmpty) {
      Log.debug(
        '✅ No pending publish drafts found',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🔄 Found ${pendingDrafts.length} pending publish draft(s), resuming...',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );

    final backgroundPublishBloc = context.read<BackgroundPublishBloc>();

    for (final draft in pendingDrafts) {
      // Check if video file still exists before attempting resume
      // Stop-motion drafts have no rendered video until publish, so there is
      // no file to verify here — skip the existence check for them.
      final firstClipVideo = draft.clips.isNotEmpty
          ? draft.clips.first.video
          : null;
      if (!kIsWeb && firstClipVideo != null) {
        try {
          final videoPath = await firstClipVideo.safeFilePath();
          final videoFile = File(videoPath);
          if (!videoFile.existsSync()) {
            Log.warning(
              '⚠️ Pending publish draft ${draft.id} references missing video file: $videoPath',
              name: 'VideoPublishNotifier',
              category: LogCategory.video,
            );
            if (draft.sourceDraftId != null) {
              await _draftService.deleteDraft(draft.id);
              continue;
            }
          }
        } catch (e) {
          Log.warning(
            '⚠️ Could not verify video file for draft ${draft.id}: $e',
            name: 'VideoPublishNotifier',
            category: LogCategory.video,
          );
          if (draft.sourceDraftId != null) {
            await _draftService.deleteDraft(draft.id);
            continue;
          }
        }
      }

      Log.info(
        '📤 Surfacing interrupted draft: ${draft.id}',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );

      backgroundPublishBloc.add(
        BackgroundPublishFailed(
          draft: draft,
          error:
              PublishError.fromPersistedString(draft.publishError) ??
              const PublishError(PublishErrorKind.interrupted),
        ),
      );
    }
  }

  /// Updates upload progress (0.0 to 1.0).
  void setUploadProgress({required String draftId, required double progress}) {
    state = state.copyWith(uploadProgress: progress);

    if (progress == 0.0 || progress == 1.0 || (progress * 100) % 10 == 0) {
      Log.info(
        '📊 Upload progress: ${(progress * 100).toStringAsFixed(0)}%',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Sets error state with user message.
  void setError(String userMessage) {
    state = state.copyWith(publishState: .error, errorMessage: userMessage);

    Log.error(
      '❌ Publish error: $userMessage',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }

  /// Clears any error state.
  void clearError() {
    state = state.copyWith(publishState: .idle, errorMessage: '');
  }

  @visibleForTesting
  String collaboratorInviteWarningMessage(
    AppLocalizations l10n,
    int failedCount,
  ) {
    return l10n.videoPublishCollaboratorInviteWarning(failedCount);
  }

  /// Picks the snackbar line for a finished collaborator-invite retry.
  ///
  /// Transient failures (still queued) take priority; a confirmed #176 policy
  /// block is terminal and reported apart from "still needs to send"; otherwise
  /// every invite was delivered.
  @visibleForTesting
  String collaboratorInviteRetryResultMessage(
    AppLocalizations l10n,
    CollaboratorInviteRetrySummary summary,
  ) {
    if (summary.failureCount > 0) {
      return collaboratorInviteWarningMessage(l10n, summary.failureCount);
    }
    if (summary.blockedCount > 0) {
      return l10n.profileCollaboratorInviteBlockedResult(summary.blockedCount);
    }
    return l10n.profileCollaboratorInviteRetryResult(0);
  }

  /// Publishes the video with ProofMode attestation and navigates to
  /// profile on success.
  Future<void> publishVideo(
    BuildContext context,
    DivineVideoDraft draft,
  ) async {
    final sourceDraftId = draft.sourceDraftId ?? draft.id;
    if (state.publishState == .preparing ||
        _inFlightSourceDraftIds.contains(sourceDraftId)) {
      Log.warning(
        '⚠️ Publish already in progress, ignoring duplicate request',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      return;
    }

    _inFlightSourceDraftIds.add(sourceDraftId);
    state = state.copyWith(publishState: .preparing);
    final creationTracker = ref.read(creationAnalyticsTrackerProvider);
    final recorderMode =
        creationTracker.activeMode ?? VideoRecorderMode.capture;

    try {
      await creationTracker.publishStarted(recorderMode);
      if (!context.mounted) {
        await creationTracker.publishFailed(
          mode: recorderMode,
          reason: 'context_unmounted',
        );
        return;
      }

      Log.info(
        '📝 Starting video publish process',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      DivineVideoClip? finalRenderedClip = draft.finalRenderedClip;
      String? proofManifestJson = draft.proofManifestJson;

      // Stop-motion clips are stored as frames; render them to an mp4 (≥1s)
      // on demand here so every downstream consumer sees a normal video clip.
      // The failure copy is read up front (before any await, so no
      // BuildContext-across-async-gap) but only when a stop-motion render is
      // actually needed — a normal publish never depends on l10n being wired
      // up, and materialize is a no-op passthrough for a clip that already
      // has a video. A draft with no render of its own goes through
      // renderVideoToClip below, which materializes its own stop-motion clips
      // and reports an assembly failure the same way as any other render
      // failure — so that path needs the copy too.
      final needsStopMotionRender =
          (finalRenderedClip?.isStopMotion ?? false) ||
          (finalRenderedClip == null &&
              draft.clips.any((clip) => clip.isStopMotion));
      final stopMotionFailedMessage = needsStopMotionRender
          ? context.l10n.videoRecorderStopMotionAssembleFailed
          : null;

      if (finalRenderedClip != null && finalRenderedClip.isStopMotion) {
        DivineVideoClip? materialized;
        try {
          materialized = await StopMotionRenderService.materialize(
            finalRenderedClip,
          );
        } on RenderCanceledException {
          materialized = null;
        }
        if (materialized == null) {
          setError(stopMotionFailedMessage!);
          await creationTracker.publishFailed(
            mode: recorderMode,
            reason: 'stop_motion_render_failed',
          );
          return;
        }
        finalRenderedClip = materialized;
      }

      if (finalRenderedClip == null) {
        // Always render, never publish a source clip as-is. A draft persists
        // its editing parameters through `CompleteParameters.toMap`, which
        // drops the captured layers, timed filters, tune adjustments and audio
        // tracks — so the parameters restored from storage describe far less
        // than the user authored. `buildForDraft` rebuilds them (re-baking the
        // layers offscreen) before the render.
        //
        // The old shortcut of publishing a lone clip directly skipped the
        // render entirely and shipped the raw recording: no overlays, and no
        // trim, speed or volume either. That is what #5203 papered over by
        // hiding the Post action; rendering here is the actual fix.
        Log.info(
          '🎬 Rendering ${draft.clips.length} clip(s) for publish',
          name: 'VideoPublishNotifier',
          category: LogCategory.video,
        );

        final CompleteParameters? parameters;
        try {
          parameters = await DraftRenderParametersService(
            rasterizer: ref.read(layerRasterizerProvider),
          ).buildForDraft(draft);
        } on DraftOverlayRestoreException catch (error) {
          // The draft has overlays we cannot reproduce. Publishing anyway would
          // ship a video silently missing text/stickers the user can still see
          // in the draft — the #5203 failure — and a Nostr event cannot be
          // quietly corrected. Point them at the editor, which re-renders and
          // repopulates whatever went missing.
          Log.warning(
            '⚠️ Blocking publish: $error',
            name: 'VideoPublishNotifier',
            category: LogCategory.video,
          );
          final message = currentAppL10n(
            ref.read(sharedPreferencesProvider),
          ).publishErrorOverlaysUnavailable;
          setError(message);
          _showPublishError(message);
          await creationTracker.publishFailed(
            mode: recorderMode,
            reason: 'overlays_unavailable',
          );
          return;
        }

        final (DivineVideoClip, String?) result;
        try {
          result = await VideoEditorRenderService.renderVideoToClip(
            clips: draft.clips,
            parameters: parameters,
            editorStateHistory: draft.editorStateHistory,
            taskId: draft.id,
          );
        } on VideoRenderFailedException catch (error) {
          // `setError` alone is invisible here: nothing on screen reads the
          // error state, so the `.preparing` scrim would just vanish (#6058).
          // A draft whose stop-motion assembly failed has its own copy; every
          // other failure gets the generic one.
          final assemblyFailed =
              error.reason == VideoRenderFailureReason.stopMotionAssembly;
          final message =
              (assemblyFailed ? stopMotionFailedMessage : null) ??
              currentAppL10n(
                ref.read(sharedPreferencesProvider),
              ).publishErrorMessage(PublishErrorKind.generic);
          setError(message);
          _showPublishError(message);
          await creationTracker.publishFailed(
            mode: recorderMode,
            reason: assemblyFailed
                ? 'stop_motion_render_failed'
                : 'render_failed',
          );
          return;
        }

        final (clip, proofJson) = result;
        finalRenderedClip = clip;
        proofManifestJson = proofJson;

        Log.info(
          '✅ Video rendered successfully for publish',
          name: 'VideoPublishNotifier',
          category: LogCategory.video,
        );
      }

      if (shouldAttachCreatorIdentityProof(proofManifestJson)) {
        proofManifestJson = await _refreshProofWithCreatorIdentity(
          clip: finalRenderedClip,
          existingProofManifestJson: proofManifestJson,
        );
      }

      final publishDraft = draft.copyWith(
        id:
            '${VideoEditorConstants.publishPrefixId}_'
            '${DateTime.now().microsecondsSinceEpoch}',
        finalRenderedClip: finalRenderedClip,
        proofManifestJson: proofManifestJson,
        publishStatus: PublishStatus.publishing,
        clearPublishError: true,
        sourceDraftId: draft.sourceDraftId ?? draft.id,
        publishAttempts: draft.publishAttempts + 1,
      );

      Log.debug(
        '💾 Saving publish draft: ${publishDraft.id}',
        name: 'VideoPublishNotifier',
        category: .video,
      );
      await _draftService.saveDraft(publishDraft);

      Log.info(
        '📤 Uploading video',
        name: 'VideoPublishNotifier',
        category: .video,
      );

      if (!context.mounted) {
        await creationTracker.publishFailed(
          mode: recorderMode,
          reason: 'context_unmounted',
        );
        return;
      }

      final backgroundPublishBloc = context.read<BackgroundPublishBloc>();
      final publishService = await _createPublishService(
        onProgressChanged: ({required draftId, required progress}) {
          backgroundPublishBloc.add(
            BackgroundPublishProgressChanged(
              draftId: draftId,
              progress: progress,
            ),
          );
        },
      );

      final publishmentProcess = publishService.publishVideo(
        draft: publishDraft,
      );
      final videoReplyContext = publishDraft.videoReplyContext;
      final isVideoReply = videoReplyContext != null;
      backgroundPublishBloc.add(
        BackgroundPublishRequested(
          draft: publishDraft,
          publishmentProcess: publishmentProcess,
        ),
      );
      var didNavigate = false;
      final postPublishExperiment = ref.read(postPublishExperimentProvider);

      if (context.mounted && videoReplyContext != null) {
        final destination = videoReplyPublishDestinationFor(videoReplyContext);
        context.go(destination.path, extra: destination.extra);
        unawaited(
          postPublishExperiment.screenShown(
            publishId: publishDraft.id,
            destination: 'video_reply',
            variant: PostPublishVariant.control,
          ),
        );
        didNavigate = true;
      } else {
        // Navigate to current user's profile
        final authService = ref.read(authServiceProvider);
        final currentNpub = authService.currentNpub;
        if (currentNpub != null && context.mounted) {
          context.go(ProfileScreenRouter.pathForNpub(currentNpub));
          final variant = postPublishExperiment.variantForUser(
            authService.currentPublicKeyHex,
          );
          unawaited(
            postPublishExperiment.screenShown(
              publishId: publishDraft.id,
              destination: 'profile',
              variant: variant,
              isExperimentExposure: true,
            ),
          );
          didNavigate = true;
        }
      }

      if (isVideoReply) {
        ref.read(videoReplyContextProvider.notifier).clear();
      }

      if (didNavigate) {
        // Clear editor state after navigation animation completes (~350ms).
        // Draft is already saved for background upload.
        Future.delayed(const Duration(milliseconds: 600), clearAll);
      }

      final result = await publishmentProcess;

      // Handle result
      switch (result) {
        case PublishSuccess():
          await creationTracker.publishSucceeded(recorderMode);
          Log.info(
            '🎉 Video published successfully',
            name: 'VideoPublishNotifier',
            category: .video,
          );
          if (result.hasInviteWarnings) {
            _showCollaboratorInviteWarning(warnings: result.inviteWarnings);
          }
          if (result.audioReuseDegraded) {
            _showAudioReuseDegradedWarning();
          }

        case PublishError(:final kind, :final serverName, :final rawFallback):
          final l10n = currentAppL10n(ref.read(sharedPreferencesProvider));
          final message =
              rawFallback ??
              l10n.publishErrorMessage(kind, serverName: serverName);
          setError(message);
          await creationTracker.publishFailed(
            mode: recorderMode,
            reason: kind.name,
          );
          Log.error(
            '❌ Publish failed: $message',
            name: 'VideoPublishNotifier',
            category: .video,
          );
      }
    } catch (error, stackTrace) {
      Log.error(
        '❌ Failed to publish video: $error',
        name: 'VideoPublishNotifier',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
      // Clear the `.preparing` guard so the re-entry guard doesn't reject every
      // retry, and surface the failure with a snackbar. This catch fires on a
      // pre-handoff throw — before the background publish bloc receives the
      // process — so nothing else would tell the user it failed (#6058).
      final l10n = currentAppL10n(ref.read(sharedPreferencesProvider));
      final message = l10n.publishErrorMessage(PublishErrorKind.generic);
      setError(message);
      _showPublishError(message);
      await creationTracker.publishFailed(
        mode: recorderMode,
        reason: 'unexpected_error',
      );
    } finally {
      _inFlightSourceDraftIds.remove(sourceDraftId);
      Log.info(
        '🏁 Publish process completed',
        name: 'VideoPublishNotifier',
        category: .video,
      );
    }
  }

  /// Surfaces a publish failure the user would otherwise not see — the catch
  /// path clears the `.preparing` overlay but has no on-screen consumer of the
  /// error state, so without this the spinner just vanishes silently (#6058).
  void _showPublishError(String message) {
    final targetContext = NavigatorKeys.root.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(targetContext);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// The publish succeeded but the reusable sound the creator opted into did
  /// not. Saying so beats a plain success snackbar that hides a dropped
  /// sharing choice — the sound can still be attached by editing the video.
  void _showAudioReuseDegradedWarning() {
    final targetContext = NavigatorKeys.root.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    final messenger = ScaffoldMessenger.maybeOf(targetContext);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(targetContext.l10n.publishAudioReuseDegradedWarning),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  /// Warns that some collaborator invites did not go out, offering a retry.
  ///
  /// Resolves l10n nullably for the same reason as the publish-success
  /// snackbar in `main.dart`: a deactivated root element still reports
  /// `mounted` while every ancestor lookup returns null (#7289).
  void _showCollaboratorInviteWarning({
    required List<CollaboratorInviteWarning> warnings,
  }) {
    final targetContext = NavigatorKeys.root.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    final l10n = Localizations.of<AppLocalizations>(
      targetContext,
      AppLocalizations,
    );
    final messenger = ScaffoldMessenger.maybeOf(targetContext);
    if (l10n == null || messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(collaboratorInviteWarningMessage(l10n, warnings.length)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n.profileCollaboratorInviteRetryAction,
          onPressed: () {
            unawaited(
              _retryCollaboratorInvites(
                messenger: messenger,
                warnings: warnings,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _retryCollaboratorInvites({
    required ScaffoldMessengerState messenger,
    required List<CollaboratorInviteWarning> warnings,
  }) async {
    final targetContext = NavigatorKeys.root.currentContext;
    if (targetContext == null || !targetContext.mounted) return;
    final l10n = Localizations.of<AppLocalizations>(
      targetContext,
      AppLocalizations,
    );
    if (l10n == null) return;
    final repository = ref.read(collaboratorInviteRecoveryRepositoryProvider);
    if (repository == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileCollaboratorInviteRetryUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final summary = await repository.retryPendingCollaboratorInvitesForVideo(
      videoAddress: warnings.first.videoAddress,
      collaboratorPubkeys: warnings.map(
        (warning) => warning.collaboratorPubkey,
      ),
    );
    final message = collaboratorInviteRetryResultMessage(l10n, summary);
    messenger.showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<String?> _refreshProofWithCreatorIdentity({
    required DivineVideoClip clip,
    String? existingProofManifestJson,
  }) async {
    final filePath = await clip.requireVideo.safeFilePath();

    Log.info(
      '🔐 Generating proof manifest for video',
      name: 'VideoPublishNotifier',
      category: LogCategory.video,
    );

    try {
      final creatorBindingAssertion = await _createCreatorBindingAssertion(
        filePath: filePath,
      );
      if (creatorBindingAssertion == null) {
        return existingProofManifestJson;
      }

      final profile = ref.read(authServiceProvider).currentProfile;
      final claimedNip05 = profile?.nip05;
      VerifierClaimBundle? verifierBundle;
      final verifierRequest = _buildVerifierClaimRequest(
        creatorBindingAssertion: creatorBindingAssertion,
        nip05: claimedNip05,
      );
      if (_hasOptionalVerifierClaims(verifierRequest)) {
        verifierBundle = await fetchOptionalVerifiedIdentity(verifierRequest);
      }

      final proofData = await NativeProofModeService.proofFile(
        File(filePath),
        creatorBindingAssertion: creatorBindingAssertion,
        cawgIdentityAssertion: verifierBundle?.identityAssertionPayload,
        verifiedIdentityBundle: verifierBundle?.toJson(),
      );

      final proofManifestJson = proofData != null
          ? jsonEncode(proofData)
          : null;
      if (proofManifestJson != null) {
        Log.info(
          '✅ Proof manifest generated successfully',
          name: 'VideoPublishNotifier',
          category: LogCategory.video,
        );
        return proofManifestJson;
      }

      Log.warning(
        '⚠️ Proof manifest generation returned null',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return existingProofManifestJson;
    } catch (error, stackTrace) {
      Log.warning(
        'Failed to attach creator identity proof metadata: '
        '$error\n$stackTrace',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return existingProofManifestJson;
    }
  }

  Future<NostrCreatorBindingAssertion?> _createCreatorBindingAssertion({
    required String filePath,
  }) async {
    try {
      final hardBindingValue =
          await NativeProofModeService.generateSha256FileHash(filePath);
      final assertion = await ref
          .read(nostrCreatorBindingServiceProvider)
          .createAssertion(
            claims: _buildCreatorBindingClaims(
              nip05: ref.read(authServiceProvider).currentProfile?.nip05,
            ),
            hardBinding: CreatorBindingHardBinding(
              alg: 'sha256',
              value: hardBindingValue,
            ),
            referencedAssertions: const <String>[
              'c2pa.actions.v2',
              'cawg.training-mining',
            ],
          );

      if (assertion == null) {
        // Expected for OAuth-only identities while the Keycast backend
        // does not yet expose `sign_canonical`, and for NIP-46 / NIP-55
        // remote signers whose protocols don't include canonical signing.
        // Logged at debug because it isn't an error condition.
        Log.debug(
          'Canonical signing not supported by current identity; '
          'skipping creator-binding assertion.',
          name: 'VideoPublishNotifier',
          category: LogCategory.video,
        );
      }
      return assertion;
    } catch (error, stackTrace) {
      Log.warning(
        'Failed to create creator-binding assertion: $error\n$stackTrace',
        name: 'VideoPublishNotifier',
        category: LogCategory.video,
      );
      return null;
    }
  }

  CreatorBindingClaims _buildCreatorBindingClaims({
    String? nip05,
    String? website,
  }) {
    return CreatorBindingClaims(nip05: nip05, website: website);
  }

  VerifierClaimRequest _buildVerifierClaimRequest({
    required NostrCreatorBindingAssertion creatorBindingAssertion,
    String? nip05,
    String? website,
  }) {
    return VerifierClaimRequest(
      pubkey: creatorBindingAssertion.pubkey,
      nip05: nip05,
      website: website,
      creatorBindingAssertionLabel: creatorBindingAssertion.assertionLabel,
      creatorBindingPayloadJson: creatorBindingAssertion.payloadJson,
    );
  }

  bool _hasOptionalVerifierClaims(VerifierClaimRequest request) {
    return request.nip05 != null ||
        request.website != null ||
        request.socialHandles.isNotEmpty;
  }

  /// Resets state to initial values.
  void reset() {
    state = const VideoPublishProviderState();

    Log.info(
      '🔄 Video publish state reset',
      name: 'VideoPublishNotifier',
      category: .video,
    );
  }
}
