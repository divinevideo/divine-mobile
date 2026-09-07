// ABOUTME: Riverpod provider for managing video editor state with text overlays and export tracking
// ABOUTME: Exposes EditorNotifier for state mutations and reactive EditorState updates

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart' show ClipsDao, DraftsDao;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart'
    show
        AudioEvent,
        ClipSourceCredit,
        InspiredByInfo,
        NativeProofData,
        VideoEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/preferences_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/file_cleanup_service.dart';
import 'package:openvine/services/video_editor/video_editor_audio_render.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/core/models/video/progress_model.dart';
import 'package:unified_logger/unified_logger.dart';

/// Debug-only escape hatch to exercise the "regenerate or post without
/// provenance" prompt without a configured signing server. Enable with
/// `--dart-define=DIVINE_FORCE_C2PA_PROMPT=true`.
///
/// Off by default and ignored outside debug builds, so CI, integration tests,
/// and release are never affected (#6058).
const bool kForceC2paPromptInDebug =
    kDebugMode && bool.fromEnvironment('DIVINE_FORCE_C2PA_PROMPT');

/// Result of a [VideoEditorNotifier.saveAsDraft] attempt.
///
/// Replaces a bare `bool` so the UI can tell a real failure apart from a
/// no-op, and so the failure cause stops hiding behind a generic snackbar.
enum DraftSaveOutcome {
  /// The draft was persisted to local storage.
  saved,

  /// A save was already in flight, so this call did nothing. The save button is
  /// normally disabled while saving, so this is a defensive case.
  alreadyInProgress,

  /// The write exceeded [VideoEditorConstants.draftSaveTimeout] — typically
  /// slow or wedged local storage.
  timedOut,

  /// The write threw an unexpected error. The cause is logged and reported to
  /// Crashlytics.
  failed,
}

final videoEditorProvider =
    NotifierProvider<VideoEditorNotifier, VideoEditorProviderState>(
      VideoEditorNotifier.new,
    );

/// Exposes the composite render+proof progress stream for the current draft.
///
/// The widget layer should watch this provider instead of importing
/// [VideoEditorRenderService] directly, keeping the UI/service boundary clean.
final StreamProvider<ProgressModel> videoEditorCompositeProgressProvider =
    StreamProvider.autoDispose<ProgressModel>((ref) {
      // draftId is set once during initialization and does not change within a
      // session, so a one-time read is sufficient.
      final draftId = ref.read(videoEditorProvider.notifier).draftId;
      return VideoEditorRenderService.compositeProgressStreamById(draftId);
    });

/// Manages video editor state and operations.
///
/// Handles:
/// - Draft loading and saving
/// - Clip selection and navigation
/// - Clip editing (splitting, trimming)
/// - Playback control
/// - Video rendering and export
/// - Metadata management
class VideoEditorNotifier extends Notifier<VideoEditorProviderState> {
  /// Debounce duration for metadata autosave to prevent excessive saves.
  static const Duration _autosaveDebounce = Duration(milliseconds: 800);

  /// Current draft ID for save/load operations.
  String? _draftId;
  String get draftId => _draftId ?? VideoEditorConstants.autoSaveId;
  set draftId(String? id) {
    _draftId = id;
  }

  Timer? _autosaveTimer;

  /// Clip/thumbnail files an autosave stopped referencing this session.
  ///
  /// They may still be reachable through the editor's undo/redo history (e.g.
  /// the pre-split source clip after a split), so deleting them mid-session
  /// breaks undo/redo — it lands on a clip whose source file is gone. We hold
  /// them here and reap them at editor-session end via
  /// [_flushDeferredFileCleanup] ([reset], with [build]'s `onDispose` as a
  /// teardown safety net), once the history that could resurrect them no longer
  /// exists. The reaper still runs each path through the reference check, so a
  /// file the user restored (and a later autosave re-referenced) is kept.
  final Set<String> _deferredFileCleanup = {};

  /// DAOs captured while a valid [Ref] is in scope, so the teardown reaper can
  /// run from `onDispose` without reading providers after disposal.
  DraftsDao? _deferredCleanupDraftsDao;
  ClipsDao? _deferredCleanupClipsDao;
  final Set<Future<void>> _pendingDeferredCleanup = {};

  /// Get clip manager notifier.
  ClipManagerNotifier get _clipManager =>
      ref.read(clipManagerProvider.notifier);

  /// Get clips from clip manager.
  List<DivineVideoClip> get _clips => ref.read(clipManagerProvider).clips;

  DraftStorageService get _draftService =>
      ref.read(draftStorageServiceProvider);

  bool get isAutosavedDraft => state.isAutosavedDraft;

  int _renderGeneration = 0;
  Future<void>? _activeRenderFuture;

  /// When true, [triggerAutosave] is a no-op.
  ///
  /// Set to `true` by [initFromPublishedVideo] and intentionally never reset.
  /// The edit flow runs inside an isolated [ProviderScope], so this notifier
  /// instance is never reused for the capture flow. Draft writes are not
  /// meaningful in the edit flow — the user is updating a published event, not
  /// accumulating a new draft — so suppressing autosave for the lifetime of the
  /// notifier is the correct behaviour.
  bool _suppressAutosave = false;

  // === LIFECYCLE ===

  @override
  VideoEditorProviderState build() {
    ref.onDispose(() {
      _autosaveTimer?.cancel();
      // Safety net for files [reset] didn't already reap (e.g. a crash before
      // session end). Best-effort and fire-and-forget: the container is tearing
      // down. On mobile this often never fires (OS kill), which is why [reset]
      // is the primary reaper.
      _startDeferredFileCleanup();
      Log.debug(
        '🧹 VideoEditorNotifier disposed',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    });
    final audioSharingEnabled = ref
        .read(audioSharingPreferenceServiceProvider)
        .isAudioSharingEnabled;
    return VideoEditorProviderState(allowAudioReuse: audioSharingEnabled);
  }

  /// Invalidate the final rendered clip when content changes.
  ///
  /// Called by ClipManager when clips change, or when editor parameters
  /// change, to ensure a re-render is required before publishing.
  /// Also deletes the rendered file from disk since it's stored in Documents.
  void invalidateFinalRenderedClip() {
    final clip = state.finalRenderedClip;
    if (clip == null) return;

    Log.debug(
      '🔄 Invalidating final rendered clip due to content change',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    if (state.isProcessing) {
      cancelRenderVideo();
    }

    state = state.copyWith(clearFinalRenderedClip: true);

    // Delete the old rendered file from disk to free up space
    final db = ref.read(databaseProvider);
    unawaited(
      FileCleanupService.deleteRecordingClipFiles(
        clip,
        draftsDao: db.draftsDao,
        clipsDao: db.clipsDao,
      ),
    );
  }

  /// Initialize the video editor with an optional draft.
  ///
  /// Loads existing draft data if [draftId] is provided, including clips
  /// and metadata.
  Future<void> initialize({String? draftId}) async {
    // Reset old editing states but keep metadata
    final audioSharingEnabled = ref
        .read(audioSharingPreferenceServiceProvider)
        .isAudioSharingEnabled;
    state = state.copyWith(
      isProcessing: false,
      renderFailed: false,
      c2paSigningFailed: false,
      isSavingDraft: false,
      allowAudioReuse: audioSharingEnabled,
    );

    // If the editor screen is opened from a draft, we initialize it here.
    if (draftId != null && draftId.isNotEmpty) {
      await restoreDraft(draftId);
    } else {
      Log.info(
        '🎬 Initializing video editor (no draft)',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      final accountLabelService = ref.read(accountLabelServiceProvider);
      await accountLabelService.initialized;
      final accountLabels = accountLabelService.defaultVideoLabels;
      if (accountLabels.isNotEmpty) {
        state = state.copyWith(contentWarnings: accountLabels);
        Log.info(
          '⚠️ Auto-selected content warnings from account labels: '
          '${accountLabels.map((label) => label.value).join(", ")}',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      }
    }
    this.draftId = draftId ?? VideoEditorConstants.autoSaveId;
    state = state.copyWith(
      isAutosavedDraft: this.draftId == VideoEditorConstants.autoSaveId,
    );
  }

  /// Reset editor state and metadata to defaults.
  ///
  /// Also cancels any pending autosave and deletes the autosaved draft
  /// unless [keepAutosavedDraft] is true.
  ///
  /// This is the editor-session boundary (publish, discard, start-over), so it
  /// reaps any [_deferredFileCleanup] now that the undo/redo history protecting
  /// those files is gone. [build]'s `onDispose` only fires at container
  /// teardown (app shutdown), which a mobile OS kill routinely skips — relying
  /// on it alone would leak the deferred files for the whole app run.
  Future<void> reset({bool keepAutosavedDraft = false}) async {
    Log.debug(
      '🔄 Resetting editor state',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    final audioSharingEnabled = ref
        .read(audioSharingPreferenceServiceProvider)
        .isAudioSharingEnabled;
    state = VideoEditorProviderState(allowAudioReuse: audioSharingEnabled);
    _autosaveTimer?.cancel();
    _startDeferredFileCleanup();
    draftId = null;
    if (!keepAutosavedDraft) {
      await removeAutosavedDraft();
    }
  }

  // === METADATA ===

  /// Update video metadata (title, description, tags).
  ///
  /// Validates and enforces the 64KB size limit. Rejects updates that exceed
  /// the limit and sets metadataLimitReached flag.
  /// Update video metadata (title, description, tags).
  ///
  /// Validates and enforces the 64KB size limit. Rejects updates that exceed
  /// the limit and sets metadataLimitReached flag.
  ///
  /// Automatically extracts hashtags from title and description.
  /// A hashtag is detected when followed by a non-alphanumeric character
  /// or at end of string (e.g., "#hot ", "#hot", "text #hot.").
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    Log.debug(
      '📝 Updated video metadata',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    // Use raw values for hashtag extraction (before trim)
    final rawTitle = title ?? state.title;
    final rawDescription = description ?? state.description;

    // Trim for storage (but after hashtag extraction). Truncate by
    // grapheme clusters via `characters` so we never split inside a
    // surrogate pair or combining sequence (emoji, flags, etc.).
    final cleanedTitle = rawTitle.trim();
    final trimmedDescription = rawDescription.trim();
    final cleanedDescription = trimmedDescription.characters
        .take(VideoEditorConstants.descriptionLimit)
        .toString();
    const tagLimit = VideoEditorConstants.tagLimit;

    // Only extract hashtags when text changes, not when tags are manually edited
    final Set<String> allTags;
    if (tags != null) {
      // User manually edited tags - use only what they provided
      allTags = tags
          .map((tag) => tag.replaceAll(RegExp('[^a-zA-Z0-9]'), ''))
          .where((tag) => tag.isNotEmpty)
          .take(tagLimit)
          .toSet();
    } else {
      // Text changed - compare old and new hashtags to only update changed ones
      final hashtagPattern = RegExp('#([a-zA-Z0-9]+)(?![a-zA-Z0-9])');

      // Extract hashtags from OLD text
      final oldText = '${state.title} ${state.description}';
      final oldHashtags = hashtagPattern
          .allMatches(oldText)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toSet();

      // Extract hashtags from NEW text
      final newText = '$rawTitle $rawDescription';
      final newHashtags = hashtagPattern
          .allMatches(newText)
          .map((m) => m.group(1))
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toSet();

      // Find which hashtags were removed and which were added
      final removedHashtags = oldHashtags.difference(newHashtags);
      final addedHashtags = newHashtags.difference(oldHashtags);

      // Update tags: remove old ones, add new ones, keep manually added tags
      allTags = state.tags
          .difference(removedHashtags)
          .union(addedHashtags)
          .take(tagLimit)
          .toSet();
    }

    // Calculate total size in bytes (UTF-8 encoded)
    // Calculate total size
    const maxBytes = 64 * 1024; // 64KB
    final titleBytes = utf8.encode(cleanedTitle).length;
    final descriptionBytes = utf8.encode(cleanedDescription).length;
    final tagsBytes = allTags.isEmpty
        ? 0
        : allTags.fold<int>(0, (sum, tag) => sum + utf8.encode(tag).length);
    final totalBytes = titleBytes + descriptionBytes + tagsBytes;

    // Check if limit is exceeded
    if (totalBytes > maxBytes) {
      Log.warning(
        '⚠️ Metadata exceeds 64KB limit ($totalBytes bytes) - update rejected',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      state = state.copyWith(metadataLimitReached: true);
      return;
    }

    // Update metadata if within limit
    state = state.copyWith(
      title: cleanedTitle,
      description: cleanedDescription,
      tags: allTags,
      metadataLimitReached: false,
    );

    triggerAutosave();
  }

  /// Set video expiration time option.
  void setExpiration(VideoMetadataExpiration expiration) {
    Log.debug(
      '⏰ Set expiration: ${expiration.name}',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    state = state.copyWith(expiration: expiration);
    triggerAutosave();
  }

  /// Set NIP-32 content warning labels for the current video.
  void setContentWarnings(Set<ContentLabel> labels) {
    state = state.copyWith(contentWarnings: Set<ContentLabel>.of(labels));
    triggerAutosave();
  }

  /// Set whether this post publishes its original audio as a reusable sound.
  void setAllowAudioReuse(bool allowAudioReuse) {
    if (state.allowAudioReuse == allowAudioReuse) return;
    state = state.copyWith(allowAudioReuse: allowAudioReuse);
    triggerAutosave();
  }

  /// Update durable public credit for audio shared with the current post.
  void setAudioShareAttribution(AudioShareAttribution? attribution) {
    if (state.audioShareAttribution == attribution) return;
    state = state.copyWith(
      audioShareAttribution: attribution,
      clearAudioShareAttribution: attribution == null,
    );
    triggerAutosave();
  }

  /// Set whether a video reply should also be eligible for normal feed display.
  void setShareReplyToFeed(bool shareReplyToFeed) {
    if (state.shareReplyToFeed == shareReplyToFeed) return;
    state = state.copyWith(shareReplyToFeed: shareReplyToFeed);
    triggerAutosave();
  }

  // === COLLABORATORS & INSPIRED BY ===

  /// Add a collaborator pubkey to the video.
  ///
  /// Enforces a maximum of [maxCollaborators] collaborators.
  /// Silently ignores duplicates.
  void addCollaborator(String pubkey) {
    if (state.collaboratorPubkeys.length >=
        VideoEditorConstants.maxCollaborators) {
      return;
    }
    if (state.collaboratorPubkeys.contains(pubkey)) return;
    state = state.copyWith(
      collaboratorPubkeys: {...state.collaboratorPubkeys, pubkey},
    );
    triggerAutosave();
  }

  /// Remove a collaborator pubkey from the video.
  void removeCollaborator(String pubkey) {
    state = state.copyWith(
      collaboratorPubkeys: state.collaboratorPubkeys
          .where((p) => p != pubkey)
          .toSet(),
    );
    triggerAutosave();
  }

  /// Set the "Inspired By" reference to a specific video (a-tag).
  void setInspiredByVideo(InspiredByInfo info) {
    state = state.copyWith(inspiredByVideo: info, clearInspiredByNpub: true);
    triggerAutosave();
  }

  /// Set the "Inspired By" reference to a person (NIP-27 npub in content).
  void setInspiredByPerson(String npub) {
    state = state.copyWith(inspiredByNpub: npub, clearInspiredByVideo: true);
    triggerAutosave();
  }

  /// Clear all "Inspired By" attribution.
  void clearInspiredBy() {
    state = state.copyWith(
      clearInspiredByVideo: true,
      clearInspiredByNpub: true,
    );
    triggerAutosave();
  }

  // === SOUND MANAGEMENT ===

  /// Select a sound for the video.
  ///
  /// This updates the editor's local state. The sound is persisted
  /// in drafts and used for audio playback during editing.
  void selectSound(AudioEvent? sound) {
    if (sound == state.selectedSound) return;

    state = state.copyWith(
      selectedSound: sound,
      clearSelectedSound: sound == null,
      seedSelectedSoundAsAudioTrack: false,
      clearAudioShareAttribution: true,
    );
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Select a recorder-backed sound that should become an editor audio track.
  ///
  /// Lip-sync records clips while playing this sound, then mutes those clips
  /// before opening the editor. The selected sound must therefore be seeded
  /// into the editor timeline exactly once on editor initialization.
  void selectRecorderAudioTrack(AudioEvent? sound) {
    if (sound == state.selectedSound &&
        state.seedSelectedSoundAsAudioTrack == (sound != null)) {
      return;
    }

    state = state.copyWith(
      selectedSound: sound,
      clearSelectedSound: sound == null,
      seedSelectedSoundAsAudioTrack: sound != null,
      clearAudioShareAttribution: true,
    );
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Clear the currently selected sound.
  void clearSound() {
    state = state.copyWith(
      clearSelectedSound: true,
      clearAudioShareAttribution: true,
    );
    invalidateFinalRenderedClip();
    triggerAutosave();
  }

  /// Update the start offset of the currently selected sound.
  void updateSoundStartOffset(Duration offset) {
    if (state.selectedSound != null &&
        offset != state.selectedSound?.startOffset) {
      state = state.copyWith(
        selectedSound: state.selectedSound!.copyWith(startOffset: offset),
      );
      invalidateFinalRenderedClip();
      triggerAutosave();
    }
  }

  /// Create a VineDraft from the rendered clip with metadata.
  ///
  /// When a sound is selected via [selectedSoundProvider], automatically
  /// populates [selectedAudioEventId] and [selectedAudioRelay] for the
  /// publisher to add an `["e", ..., "audio"]` tag. Also auto-populates
  /// [inspiredByVideo] from the sound's [sourceVideoReference] if not
  /// already set, falling back to a single imported clip source when every
  /// provenance-bearing clip agrees.
  DivineVideoDraft getActiveDraft({bool isAutosave = false, String? draftId}) {
    // Read selected sound from local state. The recorder flow sets
    // [selectedSound]; the editor's "add music" flow instead appends reused
    // sounds as timeline tracks, so fall back to the first attributable track
    // for the publish draft. Skipped for autosave to keep draft round-trips
    // from re-seeding an editor track as the recorder's selected sound.
    final selectedSound =
        state.selectedSound ??
        (isAutosave ? null : _attributionSoundFromEditorTracks());

    // Auto-populate inspired-by from selected sound's source video.
    // Sound wins because the existing audio attribution flow already exposes
    // that credit in metadata and publish tags.
    var inspiredByVideo = state.inspiredByVideo;
    if (inspiredByVideo == null &&
        selectedSound?.sourceVideoReference != null) {
      inspiredByVideo = InspiredByInfo(
        addressableId: selectedSound!.sourceVideoReference!,
        relayUrl: selectedSound.sourceVideoRelay,
      );
    }
    inspiredByVideo ??= _attributionSourceFromClips();
    final clipSourceCredits = _clipSourceCreditsFromClips();

    return DivineVideoDraft.create(
      id:
          draftId ??
          (isAutosave ? VideoEditorConstants.autoSaveId : this.draftId),
      clips: _clips,
      title: state.title,
      description: state.description,
      hashtags: state.tags,
      allowAudioReuse: state.allowAudioReuse,
      audioShareAttribution: state.audioShareAttribution,
      expireTime: state.expiration.value,
      selectedApproach: 'video',
      editorStateHistory: state.editorStateHistory,
      editorEditingParameters: state.editorEditingParameters?.toMap(),
      collaboratorPubkeys: state.collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: state.inspiredByNpub,
      // Always the timeline's own credits, never a remembered set: a credit is
      // a factual claim about footage that is *in* this video, and drafts
      // persist each clip's credits on the clip itself. Falling back to the
      // restored draft's credits when the timeline has none would re-publish a
      // credit — and notify its creator — for a reused clip the user deleted.
      clipSourceCredits: clipSourceCredits,
      selectedSound: selectedSound,
      contentWarning: ContentLabel.toCsv(state.contentWarnings),
      finalRenderedClip: state.finalRenderedClip,
      proofManifestJson: state.proofManifestJson,
      // Prefer the persisted cover so the selection survives a re-render that
      // resets finalRenderedClip's thumbnail to its default frame. When no
      // cover was picked, fall back to the rendered clip's own cover so the
      // drafts-list / profile-grid thumbnail keeps showing after the clip is
      // later invalidated and cleared (see #5181).
      thumbnailTimestamp:
          state.thumbnailTimestamp ??
          state.finalRenderedClip?.thumbnailTimestamp,
      customThumbnailPath:
          state.customThumbnailPath ?? state.finalRenderedClip?.thumbnailPath,
      videoReplyContext: ref.read(videoReplyContextProvider),
      shareReplyToFeed: state.shareReplyToFeed,
    );
  }

  // === EDITOR STATE PERSISTENCE ===

  /// Update the editor state history for undo/redo functionality.
  ///
  /// This stores the serialized state history from ProImageEditor,
  /// allowing users to restore their editing progress when reopening a draft.
  void updateEditorStateHistory(Map<String, dynamic> stateHistory) {
    if (mapEquals(state.editorStateHistory, stateHistory)) return;

    Log.debug(
      '📜 Updated editor state history',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    invalidateFinalRenderedClip();
    state = state.copyWith(editorStateHistory: stateHistory);
    triggerAutosave();
  }

  /// Update the editor editing parameters (filters, drawings, etc.).
  ///
  /// This stores the serialized editing parameters from ProImageEditor,
  /// enabling restoration of all applied effects when reopening a draft.
  void updateEditorEditingParameters(CompleteParameters editingParameters) {
    final old = state.editorEditingParameters;
    if (old != null) {
      final diffs = old.diff(editingParameters);
      // `diff` compares the render-time `audioTracks` field, which is empty in
      // the editor's complete-callback parameters — it is only populated later
      // in `_buildRenderParameters`. Audio add/remove instead lives in the
      // `audio` meta key, so compare that too; otherwise a complete whose only
      // change is audio is invisible here and the snapshot (and the reuse
      // toggle / publish attribution that read it) go stale (#6057).
      final audioMetaChanged = !listEquals(
        old.audioTracksFromMeta,
        editingParameters.audioTracksFromMeta,
      );
      // Captions live in the `captions` meta key only (never in a diffed
      // field), so a captions-only change needs the same explicit compare.
      final captionMetaChanged =
          old.captionTrackFromMeta != editingParameters.captionTrackFromMeta;
      if (diffs.isEmpty && !audioMetaChanged && !captionMetaChanged) {
        Log.debug(
          '🎨 Editor editing parameters unchanged - skipping update',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
        return;
      }
      Log.debug(
        '🎨 Editor editing parameters changed: '
        '${[...diffs, if (audioMetaChanged) 'audioMeta', if (captionMetaChanged) 'captionMeta'].join(", ")}',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    } else {
      Log.debug(
        '🎨 Editor editing parameters set (was null)',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    }
    invalidateFinalRenderedClip();
    state = state.copyWith(editorEditingParameters: editingParameters);
    triggerAutosave();
  }

  // === DRAFT PERSISTENCE ===

  /// Set the draft ID for saving/loading.
  ///
  /// Associates this editing session with a persistent draft for auto-save.
  void setDraftId(String id) {
    Log.debug(
      '💾 Set draft ID: $id',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    draftId = id;
    state = state.copyWith(
      isAutosavedDraft: id == VideoEditorConstants.autoSaveId,
    );
  }

  /// Trigger autosave with debounce to prevent excessive saves.
  ///
  /// Can be called from other providers (e.g., ClipManager) to trigger
  /// autosave after changes. Uses debouncing to batch rapid changes.
  /// Seed state from an already-published [VideoEvent] for editing.
  ///
  /// Autosave is suppressed (and remains suppressed for the lifetime of this
  /// notifier) so that no draft is written while editing an already-published
  /// event. Must be called after the notifier is created (e.g. from a child
  /// widget's [State.initState]).
  void initFromPublishedVideo(VideoEvent video) {
    _suppressAutosave = true;

    // Strip any appended NIP-27 inspired-by line before displaying the
    // description in the edit form. Empty-caption publishes trim the leading
    // newlines, so the attribution line can also be the entire content —
    // mirror the parse regex in VideoEvent.fromNostrEvent.
    var content = video.content;
    final npubPattern = RegExp(r'(^|\n\n)Inspired by nostr:npub1[a-z0-9]+\s*$');
    content = content.replaceFirst(npubPattern, '');

    state = VideoEditorProviderState(
      // Getter falls back to rawTags so the toggle survives a cache round-trip.
      allowAudioReuse: video.allowAudioReuse,
      title: video.title ?? '',
      description: content,
      tags: video.hashtags.toSet(),
      contentWarnings: video.contentWarningLabels
          .map(ContentLabel.fromValue)
          .whereType<ContentLabel>()
          .toSet(),
      collaboratorPubkeys: video.collaboratorPubkeys.toSet(),
      inspiredByVideo: video.inspiredByVideo,
      inspiredByNpub: video.inspiredByNpub,
    );
  }

  void triggerAutosave() {
    if (_suppressAutosave) return;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDebounce, () {
      if (!ref.mounted) return;
      Log.debug(
        '💾 Triggering autosave',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      autosaveChanges();
    });
  }

  /// Immediately persist a debounced autosave that has not fired yet.
  ///
  /// Returns `false` when there is no pending autosave or the write fails.
  Future<bool> flushPendingAutosave() async {
    final timer = _autosaveTimer;
    if (timer == null || !timer.isActive) return false;

    timer.cancel();
    _autosaveTimer = null;
    return autosaveChanges();
  }

  /// Automatically save the current video project state.
  ///
  /// This method is typically called periodically or on significant changes
  /// to prevent data loss. Unlike [saveAsDraft], autosave uses a fixed
  /// [autoSaveId] to maintain a single recovery point.
  Future<bool> autosaveChanges() async {
    final clipCount = _clips.length;
    final hasTitle = state.title.isNotEmpty;

    Log.info(
      '💾 Autosaving draft (clips: $clipCount, has title: $hasTitle)',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      if (clipCount == 0) {
        await removeAutosavedDraft();
        return false;
      }

      final draft = getActiveDraft(isAutosave: isAutosavedDraft);
      // Defer orphan cleanup: files this autosave drops may still be reachable
      // through the live undo/redo history (see [_deferredFileCleanup]).
      final db = ref.read(databaseProvider);
      _deferredCleanupDraftsDao = db.draftsDao;
      _deferredCleanupClipsDao = db.clipsDao;
      await _draftService.saveDraft(
        draft,
        deferOrphanCleanup: (paths) =>
            _deferredFileCleanup.addAll(paths.whereType<String>()),
      );

      Log.info(
        '✅ Autosave completed - $clipCount clip(s), '
        'title: "${state.title.isEmpty ? "(empty)" : state.title}"',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      return true;
    } catch (e, stackTrace) {
      Log.error(
        '❌ Autosave failed: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Reap the clip/thumbnail files deferred during this session (see
  /// [_deferredFileCleanup]). Runs at editor-session end ([reset]) and as a
  /// teardown safety net ([build]'s `onDispose`); both call it, and it clears
  /// the set so a second call is a no-op. Each path still goes through the
  /// draft/library reference check, so anything a surviving draft (or the
  /// library) references is kept — only genuinely-orphaned files are removed.
  Future<void> _flushDeferredFileCleanup() async {
    if (_deferredFileCleanup.isEmpty) return;
    final draftsDao = _deferredCleanupDraftsDao;
    final clipsDao = _deferredCleanupClipsDao;
    if (draftsDao == null || clipsDao == null) return;

    final paths = _deferredFileCleanup.toList();
    _deferredFileCleanup.clear();
    await FileCleanupService.deleteFilesIfUnreferenced(
      paths,
      draftsDao: draftsDao,
      clipsDao: clipsDao,
    );
  }

  /// Starts a best-effort cleanup without blocking the editor lifecycle.
  ///
  /// Every active operation remains tracked independently so a cleanup
  /// started by [reset] cannot be hidden by a later no-op cleanup from
  /// [build]'s `onDispose` callback.
  void _startDeferredFileCleanup() {
    late final Future<void> operation;
    operation = () async {
      try {
        await _flushDeferredFileCleanup();
      } finally {
        _pendingDeferredCleanup.remove(operation);
      }
    }();
    _pendingDeferredCleanup.add(operation);
    unawaited(operation);
  }

  /// Queue clip-owned files that became unreachable in the live editor state.
  ///
  /// The actual delete waits for [_flushDeferredFileCleanup] so undo/redo and
  /// the autosave row have time to stop referencing the old paths first.
  void deferFileCleanup(Iterable<String?> paths) {
    final validPaths = paths.whereType<String>().where(
      (path) => path.isNotEmpty,
    );
    final db = ref.read(databaseProvider);
    _deferredCleanupDraftsDao = db.draftsDao;
    _deferredCleanupClipsDao = db.clipsDao;
    _deferredFileCleanup.addAll(validPaths);
  }

  /// Test hook: the set of files awaiting cleanup.
  @visibleForTesting
  Set<String> get deferredFileCleanupForTest => _deferredFileCleanup;

  /// Completes when every deferred cleanup currently in flight completes.
  @visibleForTesting
  Future<void> get pendingDeferredCleanupForTest async {
    await Future.wait(_pendingDeferredCleanup.toList());
  }

  /// Save the current video project as a draft.
  ///
  /// Persists clips and metadata to local storage for later editing and returns
  /// a [DraftSaveOutcome] describing the result — [DraftSaveOutcome.saved],
  /// [DraftSaveOutcome.alreadyInProgress] (a save was already running, so this
  /// call was a no-op), [DraftSaveOutcome.timedOut] (the write exceeded
  /// [VideoEditorConstants.draftSaveTimeout]), or [DraftSaveOutcome.failed] (the
  /// write threw; the cause is logged and reported to Crashlytics).
  ///
  /// The write is bounded so a stalled save can't wedge the button. The
  /// autosave cleanup that follows is deliberately *not* bounded (see the call
  /// site): it must run to completion, so a stalled cleanup keeps the save in
  /// flight — and the button disabled — until it lands.
  Future<DraftSaveOutcome> saveAsDraft({
    bool enforceCreateNewDraft = false,
  }) async {
    if (state.isSavingDraft) return DraftSaveOutcome.alreadyInProgress;

    state = state.copyWith(isSavingDraft: true);

    final draftId = enforceCreateNewDraft
        ? 'draft_${DateTime.now().microsecondsSinceEpoch}'
        : this.draftId;

    Log.info(
      '💾 Saving draft: $draftId',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    try {
      await _draftService
          .saveDraft(getActiveDraft(draftId: draftId))
          .timeout(VideoEditorConstants.draftSaveTimeout);

      // Drop the now-redundant autosave recovery point. This must run to
      // completion — never timed out or fire-and-forget: the delete targets the
      // fixed `draft_autosave` id, so an abandoned one that resolved later would
      // wipe the recovery point of whatever editor session is active by then,
      // corrupting that session. Blocking here (the button stays disabled until
      // it lands) is the safe trade-off; only the write above needs a timeout.
      await removeAutosavedDraft();

      Log.info(
        '✅ Draft saved successfully: $draftId',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return DraftSaveOutcome.saved;
    } on TimeoutException catch (e, stackTrace) {
      // Slow/wedged local storage is an environmental failure, not a bug — log
      // it for the unified log export but keep it out of Crashlytics.
      Log.error(
        '❌ Draft save timed out after '
        '${VideoEditorConstants.draftSaveTimeout.inSeconds}s: $draftId',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      return DraftSaveOutcome.timedOut;
    } catch (e, stackTrace) {
      // An unexpected write failure: origin/main always saves, so this is a real
      // defect. Report it so the actual cause stops hiding behind a generic
      // "Failed to save" snackbar.
      Log.error(
        '❌ Failed to save draft: $e',
        name: 'VideoEditorNotifier',
        category: .video,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(
        ref
            .read(crashReportingServiceProvider)
            .recordError(
              e,
              stackTrace,
              reason: 'VideoEditorNotifier.saveAsDraft',
            ),
      );
      return DraftSaveOutcome.failed;
    } finally {
      // Always clear the flag — a timed-out or failed save must re-enable the
      // save button. Guard against a dispose that races the timeout.
      if (ref.mounted) {
        state = state.copyWith(isSavingDraft: false);
      }
    }
  }

  /// Restore a draft from local storage.
  ///
  /// Loads clips and metadata from the specified draft. If [draftId] is null,
  /// restores from [autoSaveId] to recover an autosaved session.
  /// Invalid clips (missing video files) are automatically filtered out,
  /// and missing thumbnails are regenerated.
  ///
  /// Returns `true` if the draft was restored successfully with at least
  /// one clip, `false` if the draft was not found or had no valid clips.
  Future<bool> restoreDraft([String? draftId]) async {
    draftId ??= VideoEditorConstants.autoSaveId;
    Log.info(
      '🎬 Restoring draft: $draftId',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );

    final draft = await _draftService.getDraftById(draftId);
    if (draft == null) {
      Log.warning(
        '⚠️ Draft not found or has no valid clips: $draftId',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      return false;
    }

    // Drop clips whose source video file is gone. A draft can outlive its
    // media: a clip removed mid-session has its file deleted by
    // FileCleanupService, yet the draft's persisted undo history can still
    // carry it. Restoring such a clip hands a dead path to the native player,
    // which fails the whole composition (COMPOSITION_ERROR) and freezes the
    // editor — so an orphaned clip must never re-enter the timeline.
    // Stop-motion clips are salvaged per still instead: unreadable frames
    // are dropped and the clip survives while one readable still remains.
    final restorableClips = [
      for (final clip in draft.clips)
        if (clip.isStopMotion)
          ?StopMotionFrameOps.sanitizedClip(clip)
        else if (clip.hasResolvableVideoFile)
          clip,
    ];
    if (restorableClips.length != draft.clips.length) {
      Log.warning(
        '⚠️ Dropped ${draft.clips.length - restorableClips.length} clip(s) '
        'with missing source files while restoring draft: $draftId',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    }

    // Regenerate missing thumbnails
    final clipsWithThumbnails = <DivineVideoClip>[];
    for (final clip in restorableClips) {
      final thumbnailPath = clip.thumbnailPath;
      final thumbnailExists =
          thumbnailPath != null && File(thumbnailPath).existsSync();

      if (thumbnailExists) {
        clipsWithThumbnails.add(clip);
        continue;
      }

      // Stop-motion clips have no video to extract from; their first still is
      // already a usable thumbnail image. Repair from it instead of reaching
      // for requireVideo, which throws on a frames-only clip.
      if (clip.isStopMotion) {
        final frames = clip.stopMotionFrames;
        final firstFramePath = frames != null && frames.isNotEmpty
            ? frames.first.path
            : null;
        clipsWithThumbnails.add(
          firstFramePath != null
              ? clip.copyWith(thumbnailPath: firstFramePath)
              : clip,
        );
        continue;
      }

      Log.info(
        '🖼️ Regenerating thumbnail for clip ${clip.id}',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );

      final videoPath = clip.requireVideo.file!.path;
      final result = await VideoThumbnailService.extractThumbnail(
        videoPath: videoPath,
        targetTimestamp: clip.thumbnailTimestamp,
      );
      if (result != null) {
        clipsWithThumbnails.add(clip.copyWith(thumbnailPath: result.path));
      } else {
        Log.warning(
          '⚠️ Failed to regenerate thumbnail for clip ${clip.id}',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
        // Keep clip even without thumbnail
        clipsWithThumbnails.add(clip);
      }
    }

    // Validate finalRenderedClip - only restore if file still exists
    DivineVideoClip? validFinalRenderedClip;
    final finalClip = draft.finalRenderedClip;
    if (finalClip != null) {
      if (finalClip.hasResolvableVideoFile) {
        validFinalRenderedClip = finalClip;
        Log.info(
          '✅ Restored final rendered clip',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      } else {
        Log.info(
          '⚠️ Final rendered clip file missing, will re-render',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      }
    }

    state = state.copyWith(
      title: draft.title,
      description: draft.description,
      tags: draft.hashtags,
      allowAudioReuse: draft.allowAudioReuse,
      audioShareAttribution: draft.audioShareAttribution,
      shareReplyToFeed: draft.shareReplyToFeed,
      expiration: VideoMetadataExpiration.fromDuration(draft.expireTime),
      editorStateHistory: draft.editorStateHistory,
      editorEditingParameters: completeParametersFromDraftMap(
        draft.editorEditingParameters,
      ),
      collaboratorPubkeys: withoutPublicIdentifier(
        draft.collaboratorPubkeys,
        ref.read(authServiceProvider).currentPublicKeyHex ?? '',
      ),
      inspiredByVideo: draft.inspiredByVideo,
      inspiredByNpub: draft.inspiredByNpub,
      selectedSound: draft.selectedSound,
      seedSelectedSoundAsAudioTrack: false,
      contentWarnings: draft.contentWarnings,
      finalRenderedClip: validFinalRenderedClip,
      clearFinalRenderedClip: validFinalRenderedClip == null,
      thumbnailTimestamp: draft.thumbnailTimestamp,
      clearThumbnailTimestamp: draft.thumbnailTimestamp == null,
      customThumbnailPath: draft.customThumbnailPath,
      clearCustomThumbnailPath: draft.customThumbnailPath == null,
    );

    // Restoring is read-only: don't autosave here. An autosave would bump the
    // draft's lastModified (reordering it to the top of the drafts list as if
    // freshly saved) and invalidate/delete the finalRenderedClip we just
    // restored above — mutating a draft the user only opened to view (#5956).
    _clipManager.replaceClips(clipsWithThumbnails, autosave: false);
    if (clipsWithThumbnails.isEmpty) {
      Log.warning(
        '⚠️ Draft restored with no clips',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
      return false;
    }

    // Matching the recorder's aspect ratio to the restored clips (so the user
    // can't mix ratios) is owned by the recorder View after restoreDraft()
    // returns — see video_recorder_screen.dart. A Notifier must not dispatch
    // into VideoRecorderBloc.
    Log.info(
      '✅ Draft loaded with ${clipsWithThumbnails.length} clip(s)',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );
    return true;
  }

  /// Delete the autosaved draft from local storage.
  ///
  /// Called when the user explicitly discards the autosaved session or
  /// after successfully publishing a video.
  Future<void> removeAutosavedDraft() async {
    try {
      if (!await _draftService.draftExists(VideoEditorConstants.autoSaveId)) {
        return;
      }
      await _draftService.deleteDraft(VideoEditorConstants.autoSaveId);
      Log.debug(
        '🗑️ Deleted autosaved draft',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    } catch (e) {
      Log.warning(
        '⚠️ Failed to delete autosaved draft: $e',
        name: 'VideoEditorNotifier',
        category: .video,
      );
    }
  }

  // === RENDERING & PUBLISHING ===

  /// Update the selected cover for the rendered clip.
  ///
  /// Records [thumbnailTimestamp] on the state as well as the clip so the
  /// chosen cover survives a later re-render (which rebuilds the clip with its
  /// default thumbnail) and reaches publishing via [getActiveDraft].
  void updateCover({
    required String thumbnailPath,
    required Duration thumbnailTimestamp,
  }) {
    final finalRenderedClip = state.finalRenderedClip;
    if (finalRenderedClip == null) {
      Log.warning(
        '⚠️ Cannot update thumbnail - final clip not found',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      return;
    }
    state = state.copyWith(
      thumbnailTimestamp: thumbnailTimestamp,
      customThumbnailPath: thumbnailPath,
      finalRenderedClip: finalRenderedClip.copyWith(
        thumbnailPath: thumbnailPath,
        thumbnailTimestamp: thumbnailTimestamp,
      ),
    );
    Log.debug(
      '🖼️  Updated cover thumbnail',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    autosaveChanges();
  }

  /// Set the processing state.
  ///
  /// Use this to mark that video processing has started before calling
  /// [startRenderVideo], or to reset the state after processing completes.
  void setProcessing(bool isProcessing) {
    if (state.isProcessing == isProcessing) return;
    state = state.copyWith(isProcessing: isProcessing);
  }

  /// Render all clips into final video and prepare for publishing.
  ///
  /// Combines all clips, applies audio settings, and creates the final
  /// rendered clip for publishing.
  Future<void> startRenderVideo() {
    if (state.finalRenderedClip != null) {
      setProcessing(false);
      return Future<void>.value();
    }

    Log.info(
      '🎬 Starting final video render',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    // Clear any prior failure explicitly: setProcessing is a no-op when
    // isProcessing is already true (e.g. set by the editor before navigation).
    state = state.copyWith(
      isProcessing: true,
      renderFailed: false,
      c2paSigningFailed: false,
    );

    final generation = ++_renderGeneration;
    late final Future<void> renderFuture;
    renderFuture = _runRenderVideo(generation).whenComplete(() {
      if (identical(_activeRenderFuture, renderFuture)) {
        _activeRenderFuture = null;
      }
    });
    _activeRenderFuture = renderFuture;
    return renderFuture;
  }

  Future<void> _runRenderVideo(int generation) async {
    // Capture the monitor and render inputs up front: a final render can settle
    // well after the user backs out (dispose cancels via cancelRenderVideo, but
    // the future still completes), by which point this notifier may be disposed
    // and `ref.read` would throw — the captured instance stays valid. The trace
    // is operation-scoped: this render owns the returned handle, so an
    // overlapping render gets its own trace instead of stopping or
    // re-attributing this one, and start stays fire-and-forget so render
    // dispatch is synchronous (the overlapping-render test relies on that).
    final performance = ref.read(performanceMonitoringServiceProvider);
    final trace = performance.startOperationTrace('video_generation');
    final clipCount = _clips.length;
    final aspectRatio = _clips.isEmpty
        ? null
        : _clips.first.targetAspectRatio.name;
    void tagOutcome(String outcome) => trace.putAttribute('outcome', outcome);

    try {
      final renderParameters = _buildRenderParameters();

      final result = await VideoEditorRenderService.renderVideoToClip(
        clips: _clips,
        parameters: renderParameters,
        editorStateHistory: state.editorStateHistory,
        taskId: draftId,
      );

      // A newer render was started or the user cancelled while this one was
      // running — tag this render's own trace so the console can exclude
      // non-completing renders from the generation-time distribution.
      if (generation != _renderGeneration) {
        tagOutcome('incomplete');
        return;
      }

      tagOutcome('success');

      final (finalRenderedClip, proofManifestJson) = result;

      Log.info(
        '✅ Video rendered successfully - duration: '
        '${finalRenderedClip.duration.inSeconds}s',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      final signingConfigured =
          C2paSigningService.isSigningConfigured || kForceC2paPromptInDebug;
      final c2paSigningFailed = c2paSigningFailedFor(
        signingConfigured: signingConfigured,
        proofManifestJson: proofManifestJson,
      );
      Log.debug(
        '🔐 C2PA prompt gate — configured: $signingConfigured, '
        'hasProof: ${proofManifestJson != null}, failed: $c2paSigningFailed',
        name: 'VideoEditorNotifier',
        category: .video,
      );

      state = state.copyWith(
        isProcessing: false,
        renderFailed: false,
        c2paSigningFailed: c2paSigningFailed,
        finalRenderedClip: finalRenderedClip,
        proofManifestJson: proofManifestJson,
      );
      autosaveChanges();
    } on VideoRenderFailedException catch (error) {
      // A newer render owns the processing flag now — leave it alone.
      if (generation != _renderGeneration) {
        tagOutcome('incomplete');
        return;
      }
      trace.putAttribute('failure_reason', error.traceValue);
      // A cancel without a generation bump is teardown cancelling in-flight
      // native tasks, not a render that could not produce a video — it belongs
      // in the same bucket as a superseded render. The retry affordance still
      // comes up, since the export genuinely did not finish.
      tagOutcome(
        error.reason == VideoRenderFailureReason.canceled
            ? 'incomplete'
            : 'failed',
      );
      Log.warning(
        '⚠️ Video render produced no video: ${error.traceValue}',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      state = state.copyWith(isProcessing: false, renderFailed: true);
    } catch (error, stackTrace) {
      // A newer render owns the processing flag now — leave it alone.
      if (generation != _renderGeneration) {
        tagOutcome('incomplete');
        return;
      }
      tagOutcome('error');
      trace.putAttribute('failure_reason', error.runtimeType.toString());
      // Surface the failure (e.g. a hung/failed C2PA proof step) as an error +
      // retry so the user can restart the render instead of being stuck on the
      // processing overlay (#6058).
      Log.error(
        '❌ Video render failed',
        name: 'VideoEditorNotifier',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
      state = state.copyWith(isProcessing: false, renderFailed: true);
    } finally {
      // This render owns its trace handle, so tag and stop it unconditionally.
      // Stop fire-and-forget so a trace.stop() platform round-trip doesn't gate
      // the render's completion.
      trace.putAttribute('clip_count', '$clipCount');
      if (aspectRatio != null) {
        trace.putAttribute('aspect_ratio', aspectRatio);
      }
      unawaited(trace.stop());
    }
  }

  /// Whether a rendered clip lacks a usable content credential in a build where
  /// signing is configured.
  ///
  /// The only signal available here is [proofManifestJson], which
  /// [NativeProofModeService.proofFile] returns null (or without a
  /// `c2paManifestId`) for *both* a genuine C2PA signing failure *and* the case
  /// where signing succeeded but the ProofMode manifest could not be generated
  /// or read. This helper deliberately treats that whole set as "provenance
  /// could not be confirmed" rather than trying to distinguish the two — the
  /// recovery is identical (re-sign or post as-is), and a re-sign re-runs the
  /// proof step regardless. So a true result means "no confirmable
  /// content-credential manifest", not strictly "signing threw".
  ///
  /// [signingConfigured] is [C2paSigningService.isSigningConfigured]; passed in
  /// so the decision is pure and testable. Returns false whenever signing isn't
  /// configured (CI / unconfigured builds), so those never prompt.
  @visibleForTesting
  static bool c2paSigningFailedFor({
    required bool signingConfigured,
    required String? proofManifestJson,
  }) {
    if (!signingConfigured) return false;
    if (proofManifestJson == null || proofManifestJson.isEmpty) return true;
    try {
      final decoded = jsonDecode(proofManifestJson);
      if (decoded is! Map<String, dynamic>) return true;
      final manifestId = NativeProofData.fromJson(decoded).c2paManifestId;
      return manifestId == null || manifestId.isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Clears the pending C2PA-missing prompt once the user has decided to post
  /// without a content credential (#6058).
  void acknowledgeC2paSigningFailure() {
    if (!state.c2paSigningFailed) return;
    state = state.copyWith(c2paSigningFailed: false);
  }

  /// Re-attempts C2PA signing on the already-rendered clip without re-encoding
  /// the video — the render succeeded, only the content credential failed
  /// (#6058). Falls back to a full render if there is no rendered clip.
  Future<void> retryC2paSigning() {
    final clip = state.finalRenderedClip;
    // No rendered clip to re-sign (defensive: the prompt that calls this only
    // appears once a clip exists) — fall back to a full render.
    if (clip == null) return startRenderVideo();

    state = state.copyWith(isProcessing: true, c2paSigningFailed: false);

    final generation = ++_renderGeneration;
    late final Future<void> future;
    future = _runReproof(generation, clip).whenComplete(() {
      if (identical(_activeRenderFuture, future)) {
        _activeRenderFuture = null;
      }
    });
    _activeRenderFuture = future;
    return future;
  }

  Future<void> _runReproof(int generation, DivineVideoClip clip) async {
    try {
      final refreshed = await VideoEditorRenderService.reproofRenderedClip(
        clip: clip,
        clips: _clips,
        editorStateHistory: state.editorStateHistory,
      );

      // A newer render/re-sign superseded this one — discard.
      if (generation != _renderGeneration) return;

      final proofManifestJson = refreshed ?? state.proofManifestJson;
      final signingConfigured =
          C2paSigningService.isSigningConfigured || kForceC2paPromptInDebug;
      state = state.copyWith(
        isProcessing: false,
        proofManifestJson: proofManifestJson,
        c2paSigningFailed: c2paSigningFailedFor(
          signingConfigured: signingConfigured,
          proofManifestJson: proofManifestJson,
        ),
      );
      autosaveChanges();
    } catch (error, stackTrace) {
      if (generation != _renderGeneration) return;
      Log.error(
        '❌ C2PA re-sign failed',
        name: 'VideoEditorNotifier',
        category: .video,
        error: error,
        stackTrace: stackTrace,
      );
      // The re-sign itself errored — offer the prompt again.
      state = state.copyWith(isProcessing: false, c2paSigningFailed: true);
    }
  }

  /// Cancel an ongoing video render operation.
  Future<void> cancelRenderVideo() async {
    final generation = ++_renderGeneration;
    final activeRender = _activeRenderFuture;
    await VideoEditorRenderService.cancelTask(draftId);
    if (activeRender != null) {
      try {
        await activeRender;
      } catch (e) {
        Log.debug(
          'Render future completed after cancellation: $e',
          name: 'VideoEditorNotifier',
          category: LogCategory.video,
        );
      }
    }
    if (generation == _renderGeneration) {
      state = state.copyWith(
        isProcessing: false,
        renderFailed: false,
        c2paSigningFailed: false,
      );
    }
  }

  /// Waits until the current render has completed or cancellation teardown has
  /// unwound. Used by codec-heavy UI surfaces before rebuilding preview
  /// decoders.
  Future<void> waitForRenderIdle() async {
    final activeRender = _activeRenderFuture;
    if (activeRender == null) return;
    try {
      await activeRender;
    } catch (e) {
      Log.debug(
        'Render future completed while waiting for idle: $e',
        name: 'VideoEditorNotifier',
        category: LogCategory.video,
      );
    }
  }

  /// Publish the video to the Nostr network.
  ///
  /// Requires [finalRenderedClip] to be available. Throws [StateError] if
  /// no rendered clip exists.
  Future<void> postVideo(BuildContext context) async {
    if (state.finalRenderedClip == null) {
      Log.error(
        '❌ Cannot post video: no final rendered clip available',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      throw StateError('Cannot post video without a rendered clip');
    } else if (!state.isValidToPost) {
      Log.error(
        '❌ Cannot post video: metadata invalid '
        '(title empty: ${state.title.isEmpty}, '
        'limit reached: ${state.metadataLimitReached})',
        name: 'VideoEditorNotifier',
        category: .video,
      );
      throw StateError('Cannot post video with invalid metadata');
    }

    Log.info(
      '📤 Starting video publish',
      name: 'VideoEditorNotifier',
      category: .video,
    );

    await ref
        .read(videoPublishProvider.notifier)
        .publishVideo(context, getActiveDraft());
  }

  // === PRIVATE HELPERS ===

  /// The reused sound to attribute when publishing a video assembled through
  /// the editor's "add music" flow, which appends sounds as timeline tracks
  /// rather than setting the recorder's [selectedSound].
  ///
  /// Returns the first added track that references a real Nostr event — a
  /// published or imported Kind 1063 sound, or another video's original sound
  /// (`video_<eventId>`). Skips the video's own clip-anchored audio, which
  /// credits no other creator.
  AudioEvent? _attributionSoundFromEditorTracks() {
    final tracks =
        state.editorEditingParameters?.audioTracksFromMeta ?? const [];
    for (final track in tracks) {
      if (track.isClipAnchoredOriginalSound) continue;
      if (track.attributionEventId != null) return track;
    }
    return null;
  }

  /// The imported clip source to credit when the timeline has exactly one
  /// attributable source. Clips without provenance are local/original material
  /// and do not conflict with the reused source; multiple reused sources do.
  InspiredByInfo? _attributionSourceFromClips() {
    final credits = _clipSourceCreditsFromClips()
        .where((credit) => credit.hasAddressableSource)
        .toList();
    if (credits.length != 1) return null;
    return credits.single.inspiredByInfo;
  }

  List<ClipSourceCredit> _clipSourceCreditsFromClips() {
    final credits = <ClipSourceCredit>[];
    final seen = <String>{};

    for (final clip in _clips) {
      for (final credit in clip.sourceCredits) {
        if (seen.add(credit.identityKey)) credits.add(credit);
      }
    }

    return credits;
  }

  /// Build render parameters for video export.
  ///
  /// Combines editor editing parameters with custom audio track if selected.
  /// Returns null if no parameters or sound track are configured.
  CompleteParameters? _buildRenderParameters() {
    final soundTrack = state.selectedSound;

    final baseParams =
        state.editorEditingParameters ?? CompleteParameters.fromMap({});

    final audioEvents = baseParams.audioTracksFromMeta;
    final audioTracks = buildRenderAudioTracks(
      metaTracks: audioEvents,
      selectedSound: soundTrack,
    );

    // Surface the resolution result so a silent export (no audio) is
    // diagnosable from logs instead of failing quietly — the common cause is
    // an empty/unparsable `audio` meta key.
    Log.info(
      'Render audio: ${audioEvents.length} track(s) in meta, '
      '${audioTracks.length} resolved for muxing',
      name: 'VideoEditorNotifier',
      category: LogCategory.video,
    );

    return baseParams.copyWith(audioTracks: audioTracks);
  }
}
