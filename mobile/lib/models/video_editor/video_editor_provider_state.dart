// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

import 'package:flutter/widgets.dart';
import 'package:models/models.dart' show AudioEvent, InspiredByInfo;
import 'package:openvine/extensions/complete_parameters_extensions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Immutable state model for the video editor.
///
/// Manages the complete editing state including:
/// - Playback position and clip navigation
/// - UI interaction states (editing, reordering, playing)
/// - Audio settings
/// - Processing status
class VideoEditorProviderState {
  /// Creates a video editor state with optional initial values.
  VideoEditorProviderState({
    this.isProcessing = false,
    this.renderFailed = false,
    this.c2paSigningFailed = false,
    this.isSavingDraft = false,
    this.isAutosavedDraft = true,
    this.allowAudioReuse = false,
    this.audioShareAttribution,
    this.shareReplyToFeed = false,
    this.title = '',
    this.description = '',
    this.tags = const {},
    this.expiration = .notExpire,
    this.metadataLimitReached = false,
    this.finalRenderedClip,
    this.editorStateHistory = const {},
    this.editorEditingParameters,
    this.collaboratorPubkeys = const {},
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.captionMentions = const [],
    this.selectedSound,
    this.seedSelectedSoundAsAudioTrack = false,
    this.contentWarnings = const {},
    this.proofManifestJson,
    this.thumbnailTimestamp,
    this.customThumbnailPath,
    GlobalKey? deleteButtonKey,
  }) : deleteButtonKey = deleteButtonKey ?? GlobalKey();

  /// Whether a long-running operation (e.g., export, processing) is in
  /// progress.
  final bool isProcessing;

  /// Whether the last render attempt failed to produce a [finalRenderedClip].
  ///
  /// Drives the metadata screen's failure overlay (error + retry) instead of an
  /// endless spinner, so a failed generation can be restarted in place (#6058).
  /// Cleared when a new render starts and whenever [finalRenderedClip] is set or
  /// invalidated.
  final bool renderFailed;

  /// Whether the render produced a clip but no usable content credential /
  /// provenance manifest was attached.
  ///
  /// This is the broad "provenance could not be confirmed" condition, not a
  /// pure signing-error signal: it is true both when C2PA signing itself failed
  /// and when signing succeeded but the ProofMode manifest could not be
  /// generated or read (see [VideoEditorNotifier.c2paSigningFailedFor]). Either
  /// way the output cannot be confirmed as Human-Made, so the same recovery
  /// prompt applies.
  ///
  /// Only ever true in builds with signing configured (never in CI). Drives the
  /// "try again or post without provenance" prompt on the metadata screen
  /// (#6058). Cleared once the user acts on it, when a new render starts, and
  /// whenever [finalRenderedClip] is invalidated.
  final bool c2paSigningFailed;

  /// Whether a draft save operation is currently in progress.
  final bool isSavingDraft;

  /// Whether this session is an autosaved draft (vs. a user-saved draft).
  final bool isAutosavedDraft;

  /// GlobalKey for the delete button to enable hit testing.
  final GlobalKey deleteButtonKey;

  /// Video post title displayed in metadata screen.
  final String title;

  /// Video post description providing additional context.
  final String description;

  /// List of hashtags/tags associated with the video for discovery.
  final Set<String> tags;

  /// Whether the audio from the original video can be reused in other videos.
  final bool allowAudioReuse;

  /// Public credit for audio the user chooses to share with this post.
  ///
  /// This is publishable metadata and is intentionally separate from private
  /// saved-library labels and hashtags.
  final AudioShareAttribution? audioShareAttribution;

  /// Whether a video reply should also be eligible for normal feed display.
  ///
  /// The recording is still a single NIP-71 event with reply tags; this only
  /// controls the app-specific visibility marker on that event.
  final bool shareReplyToFeed;

  /// Expiration setting determining when the video post expires.
  final VideoMetadataExpiration expiration;

  /// Whether the 64KB metadata limit was reached during the last update.
  final bool metadataLimitReached;

  /// The final rendered clip after all editing and processing operations are
  /// complete.
  /// This represents the video output ready for publishing.
  final DivineVideoClip? finalRenderedClip;

  /// Serialized state history from ProImageEditor for undo/redo restoration.
  final Map<String, dynamic> editorStateHistory;

  /// Serialized editing parameters (filters, drawings, etc.) from ProImageEditor.
  final CompleteParameters? editorEditingParameters;

  /// Pubkeys of collaborators to tag in the published video.
  final Set<String> collaboratorPubkeys;

  /// Reference to a specific video that inspired this one (a-tag).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference for general "Inspired By" a creator.
  final String? inspiredByNpub;

  /// Accounts picked from the caption's mention autocomplete.
  final List<CaptionMention> captionMentions;

  /// Currently selected sound for the video.
  /// Contains the full AudioEvent data including URL, title, and start offset.
  /// This is persisted in drafts and used for audio playback during editing.
  final AudioEvent? selectedSound;

  /// Audio that will be credited at publish time, including editor tracks.
  AudioEvent? get audioForAttribution {
    if (selectedSound != null) return selectedSound;
    final tracks = editorEditingParameters?.audioTracksFromMeta ?? const [];
    return tracks.isEmpty ? null : tracks.first;
  }

  /// Whether [selectedSound] was recorded against in the recorder and should
  /// be seeded into the editor timeline as a concrete audio track.
  ///
  /// Generic editor/draft sound state is not enough to infer this. Lip-sync
  /// uses this handoff flag so restoring a draft or selecting audio elsewhere
  /// cannot accidentally create a duplicate editor track.
  final bool seedSelectedSoundAsAudioTrack;

  /// NIP-32 content warning labels for sensitive content self-labeling.
  final Set<ContentLabel> contentWarnings;

  /// ProofMode attestation manifest JSON for the final rendered clip.
  final String? proofManifestJson;

  /// User-selected cover position in the rendered video timeline.
  ///
  /// Persisted independently of [finalRenderedClip] so the chosen cover
  /// survives a re-render — when the clip is invalidated and rebuilt (e.g.
  /// reopening a draft and pressing Done), the rendered clip is recreated at
  /// its default frame, but this timestamp re-applies the selected cover.
  final Duration? thumbnailTimestamp;

  /// Absolute path to the user-selected cover image.
  ///
  /// Kept separate from [finalRenderedClip] so cover displays (drafts list,
  /// profile grid) survive the rendered clip being cleared on invalidation.
  final String? customThumbnailPath;

  /// Whether the video is valid and ready to be posted.
  ///
  /// Returns true if:
  /// - Metadata is within the 64KB limit
  /// - Final rendered clip is available
  bool get isValidToPost =>
      !metadataLimitReached &&
      !isProcessing &&
      finalRenderedClip != null &&
      hasValidPublicAudioAttribution;

  bool get requiresPublicAudioAttribution =>
      allowAudioReuse &&
      !reusesExternalAudio &&
      audioForAttribution?.externalSource == null;

  bool get hasValidPublicAudioAttribution =>
      !requiresPublicAudioAttribution ||
      (audioShareAttribution?.isValid ?? false);

  /// Whether the video's audio is reused from *another creator* — a sound the
  /// user is not entitled to re-offer for reuse.
  ///
  /// True only when the selected sound (recorder flow) or an added editor
  /// timeline track references another creator's Nostr event: a reused
  /// original sound (`video_<eventId>`) or a published Kind 1063, i.e. it has
  /// an [AudioEvent.attributionEventId]. Bundled "divine" sounds, self-imported
  /// audio, voice-over takes, and the video's own clip-anchored original sound
  /// are all the user's own to offer, so they keep the toggle.
  ///
  /// In the reused-from-another case "Publish this sound" ([allowAudioReuse])
  /// is a no-op — the publisher references the source event instead of
  /// republishing the audio under the reusing user — so the metadata toggle is
  /// hidden to match.
  bool get reusesExternalAudio {
    bool isReusedFromAnotherCreator(AudioEvent audio) =>
        !audio.isClipAnchoredOriginalSound && audio.attributionEventId != null;
    final sound = selectedSound;
    if (sound != null && isReusedFromAnotherCreator(sound)) return true;
    final tracks = editorEditingParameters?.audioTracksFromMeta ?? const [];
    return tracks.any(isReusedFromAnotherCreator);
  }

  /// Creates a copy of this state with updated fields.
  ///
  /// All parameters are optional. Only provided fields will be updated,
  /// others retain their current values.
  ///
  /// Use [clearFinalRenderedClip] = true to explicitly set
  /// [finalRenderedClip] to null.
  /// Use [clearInspiredByVideo] = true to explicitly set
  /// [inspiredByVideo] to null.
  /// Use [clearInspiredByNpub] = true to explicitly set
  /// [inspiredByNpub] to null.
  /// Use [clearSelectedSound] = true to explicitly set
  /// [selectedSound] to null.
  VideoEditorProviderState copyWith({
    bool? isProcessing,
    bool? renderFailed,
    bool? c2paSigningFailed,
    bool? isSavingDraft,
    bool? isAutosavedDraft,
    bool? allowAudioReuse,
    AudioShareAttribution? audioShareAttribution,
    bool clearAudioShareAttribution = false,
    bool? shareReplyToFeed,
    GlobalKey? deleteButtonKey,
    String? title,
    String? description,
    Set<String>? tags,
    VideoMetadataExpiration? expiration,
    bool? metadataLimitReached,
    DivineVideoClip? finalRenderedClip,
    bool clearFinalRenderedClip = false,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    Map<String, dynamic>? editorStateHistory,
    CompleteParameters? editorEditingParameters,
    bool clearEditorEditingParameters = false,
    Set<String>? collaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    bool clearInspiredByVideo = false,
    String? inspiredByNpub,
    List<CaptionMention>? captionMentions,
    bool clearInspiredByNpub = false,
    AudioEvent? selectedSound,
    bool clearSelectedSound = false,
    bool? seedSelectedSoundAsAudioTrack,
    Set<ContentLabel>? contentWarnings,
    Duration? thumbnailTimestamp,
    bool clearThumbnailTimestamp = false,
    String? customThumbnailPath,
    bool clearCustomThumbnailPath = false,
  }) {
    // clearFinalRenderedClip forces renderFailed and c2paSigningFailed back to
    // false below, so passing either as `true` in the same call would be
    // silently dropped. Fail loudly instead of hiding the contradiction.
    assert(
      !clearFinalRenderedClip ||
          (renderFailed != true && c2paSigningFailed != true),
      'clearFinalRenderedClip resets renderFailed and c2paSigningFailed to '
      'false; do not also pass either as true in the same copyWith call.',
    );
    return VideoEditorProviderState(
      isProcessing: isProcessing ?? this.isProcessing,
      // A produced or invalidated clip always ends the failed state.
      renderFailed:
          !clearFinalRenderedClip && (renderFailed ?? this.renderFailed),
      // Invalidating the rendered clip also drops any pending C2PA prompt.
      c2paSigningFailed:
          !clearFinalRenderedClip &&
          (c2paSigningFailed ?? this.c2paSigningFailed),
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isAutosavedDraft: isAutosavedDraft ?? this.isAutosavedDraft,
      allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
      audioShareAttribution: clearAudioShareAttribution
          ? null
          : (audioShareAttribution ?? this.audioShareAttribution),
      shareReplyToFeed: shareReplyToFeed ?? this.shareReplyToFeed,
      deleteButtonKey: deleteButtonKey ?? this.deleteButtonKey,
      title: title ?? this.title,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      expiration: expiration ?? this.expiration,
      metadataLimitReached: metadataLimitReached ?? this.metadataLimitReached,
      finalRenderedClip: clearFinalRenderedClip
          ? null
          : (finalRenderedClip ?? this.finalRenderedClip),
      editorStateHistory: editorStateHistory ?? this.editorStateHistory,
      editorEditingParameters: clearEditorEditingParameters
          ? null
          : editorEditingParameters ?? this.editorEditingParameters,
      collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
      inspiredByVideo: clearInspiredByVideo
          ? null
          : (inspiredByVideo ?? this.inspiredByVideo),
      captionMentions: captionMentions ?? this.captionMentions,
      inspiredByNpub: clearInspiredByNpub
          ? null
          : (inspiredByNpub ?? this.inspiredByNpub),
      selectedSound: clearSelectedSound
          ? null
          : (selectedSound ?? this.selectedSound),
      seedSelectedSoundAsAudioTrack:
          !clearSelectedSound &&
          (seedSelectedSoundAsAudioTrack ?? this.seedSelectedSoundAsAudioTrack),
      contentWarnings: contentWarnings ?? this.contentWarnings,
      proofManifestJson: clearProofManifestJson || clearFinalRenderedClip
          ? null
          : proofManifestJson ?? this.proofManifestJson,
      thumbnailTimestamp: clearThumbnailTimestamp
          ? null
          : (thumbnailTimestamp ?? this.thumbnailTimestamp),
      customThumbnailPath: clearCustomThumbnailPath
          ? null
          : (customThumbnailPath ?? this.customThumbnailPath),
    );
  }
}
