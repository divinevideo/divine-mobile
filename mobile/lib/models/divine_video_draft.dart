// ABOUTME: Data model for Vine drafts that users save before publishing
// ABOUTME: Includes video file path, metadata, publish status, and timestamps

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:models/models.dart'
    show
        AspectRatio,
        AudioEvent,
        ClipSourceCredit,
        InspiredByInfo,
        NativeProofData;
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/caption_mention.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/utils/draft_audio_path_resolver.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

enum PublishStatus { draft, publishing, failed, published }

class DivineVideoDraft {
  const DivineVideoDraft({
    required this.id,
    required this.clips,
    required this.title,
    required this.description,
    required this.hashtags,
    required this.selectedApproach,
    required this.createdAt,
    required this.lastModified,
    required this.publishStatus,
    required this.publishAttempts,
    this.publishError,
    this.sourceDraftId,
    this.allowAudioReuse = false,
    this.expireTime,
    this.proofManifestJson,
    this.editorStateHistory = const {},
    this.editorEditingParameters = const {},
    this.finalRenderedClip,
    this.collaboratorPubkeys = const {},
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.captionMentions = const [],
    this.clipSourceCredits = const [],
    this.selectedSound,
    this.audioShareAttribution,
    this.contentWarning,
    this.videoReplyContext,
    this.shareReplyToFeed = false,
    this.thumbnailTimestamp,
    this.customThumbnailPath,
  });

  factory DivineVideoDraft.create({
    required List<DivineVideoClip> clips,
    required String title,
    required String description,
    required Set<String> hashtags,
    required String selectedApproach,
    bool allowAudioReuse = false,
    Duration? expireTime,
    String? id,
    String? proofManifestJson,
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    DivineVideoClip? finalRenderedClip,
    Set<String> collaboratorPubkeys = const {},
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    List<CaptionMention> captionMentions = const [],
    List<ClipSourceCredit> clipSourceCredits = const [],
    AudioEvent? selectedSound,
    AudioShareAttribution? audioShareAttribution,
    String? contentWarning,
    VideoReplyContext? videoReplyContext,
    bool shareReplyToFeed = false,
    Duration? thumbnailTimestamp,
    String? customThumbnailPath,
  }) {
    final now = DateTime.now();
    return DivineVideoDraft(
      id: id ?? 'draft_${now.millisecondsSinceEpoch}',
      clips: clips,
      title: title,
      description: description,
      hashtags: hashtags,
      selectedApproach: selectedApproach,
      createdAt: now,
      lastModified: now,
      allowAudioReuse: allowAudioReuse,
      expireTime: expireTime,
      publishStatus: PublishStatus.draft,
      publishAttempts: 0,
      proofManifestJson: proofManifestJson,
      editorStateHistory: editorStateHistory ?? const {},
      editorEditingParameters: editorEditingParameters ?? const {},
      finalRenderedClip: finalRenderedClip,
      collaboratorPubkeys: collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: inspiredByNpub,
      captionMentions: captionMentions,
      clipSourceCredits: clipSourceCredits,
      selectedSound: selectedSound,
      audioShareAttribution: audioShareAttribution,
      contentWarning: contentWarning,
      videoReplyContext: videoReplyContext,
      shareReplyToFeed: shareReplyToFeed,
      thumbnailTimestamp: thumbnailTimestamp,
      customThumbnailPath: customThumbnailPath,
    );
  }

  factory DivineVideoDraft.fromJson(
    Map<String, dynamic> json,
    String documentsPath, {
    bool useOriginalPath = false,
  }) {
    final List<DivineVideoClip> clips = [];

    // Backward compatibility: Handle old draft format with single videoFilePath
    // instead of the newer clips array format
    if (json['videoFilePath'] != null) {
      final now = DateTime.now();
      final targetAspectRatio = AspectRatio.values.firstWhere(
        (e) => e.name == json['aspectRatio'],
        orElse: () => AspectRatio.square,
      );

      clips.add(
        DivineVideoClip(
          id: 'draft_${now.millisecondsSinceEpoch}',
          video: EditorVideo.file(
            resolvePath(
              json['videoFilePath'] as String,
              documentsPath,
              useOriginalPath: useOriginalPath,
            ),
          ),
          duration: .zero,
          recordedAt: DateTime.parse(json['createdAt'] as String),
          originalAspectRatio: targetAspectRatio.value,
          targetAspectRatio: targetAspectRatio,
        ),
      );
    } else {
      clips.addAll(
        List.from(json['clips'] as Iterable? ?? []).map(
          (jsonClip) => DivineVideoClip.fromJson(
            jsonClip as Map<String, dynamic>,
            documentsPath,
            useOriginalPath: useOriginalPath,
          ),
        ),
      );
    }

    return DivineVideoDraft(
      id: json['id'] as String,
      clips: clips,
      title: json['title'] as String,
      description: json['description'] as String,
      hashtags: Set<String>.from(json['hashtags'] as Iterable),
      selectedApproach: json['selectedApproach'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      expireTime: json['expireTime'] != null
          ? Duration(milliseconds: json['expireTime'] as int)
          : null,
      publishStatus: json['publishStatus'] != null
          ? PublishStatus.values.byName(json['publishStatus'] as String)
          : PublishStatus.draft, // Migration: default for old drafts
      allowAudioReuse: json['allowAudioReuse'] as bool? ?? false,
      publishError: json['publishError'] as String?,
      publishAttempts: json['publishAttempts'] as int? ?? 0,
      sourceDraftId: json['sourceDraftId'] as String?,
      proofManifestJson: json['proofManifestJson'] as String?,
      editorStateHistory: resolveAudioPaths(
        (json['editorStateHistory'] as Map<String, dynamic>?) ?? const {},
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      editorEditingParameters: resolveAudioPaths(
        (json['editorEditingParameters'] as Map<String, dynamic>?) ?? const {},
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
      finalRenderedClip: json['finalRenderedClip'] != null
          ? DivineVideoClip.fromJson(
              json['finalRenderedClip'] as Map<String, dynamic>,
              documentsPath,
              useOriginalPath: useOriginalPath,
            )
          : null,
      collaboratorPubkeys: json['collaboratorPubkeys'] != null
          ? Set<String>.from(json['collaboratorPubkeys'] as Iterable)
          : const {},
      inspiredByVideo: json['inspiredByVideo'] != null
          ? InspiredByInfo.fromJson(
              json['inspiredByVideo'] as Map<String, dynamic>,
            )
          : null,
      inspiredByNpub: json['inspiredByNpub'] as String?,
      captionMentions: CaptionMention.listFromJson(json['captionMentions']),
      clipSourceCredits: ClipSourceCredit.listFromJson(
        json['clipSourceCredits'],
      ),
      // New format: full AudioEvent object
      // Old format (selectedAudioEventId/selectedAudioRelay) is ignored -
      // user must re-select sound if loading old draft
      selectedSound: json['selectedSound'] != null
          ? AudioEvent.fromJson(
              resolveAudioPaths(
                json['selectedSound'] as Map<String, dynamic>,
                documentsPath,
                useOriginalPath: useOriginalPath,
              ),
            )
          : null,
      audioShareAttribution: json['audioShareAttribution'] is Map
          ? AudioShareAttribution.fromJson(
              Map<String, dynamic>.from(json['audioShareAttribution'] as Map),
            )
          : null,
      contentWarning: json['contentWarning'] as String?,
      videoReplyContext: json['videoReplyContext'] != null
          ? VideoReplyContext.fromJson(
              json['videoReplyContext'] as Map<String, dynamic>,
            )
          : null,
      shareReplyToFeed: json['shareReplyToFeed'] as bool? ?? false,
      thumbnailTimestamp: json['thumbnailTimestamp'] != null
          ? Duration(milliseconds: json['thumbnailTimestamp'] as int)
          : null,
      customThumbnailPath: resolvePath(
        json['customThumbnailPath'] as String?,
        documentsPath,
        useOriginalPath: useOriginalPath,
      ),
    );
  }

  /// Rebuilds a draft from its [row] and [clipRows].
  ///
  /// Publish bookkeeping is taken from the row columns, not the `data` blob.
  /// `DraftsDao.updatePublishStatus` writes only the columns, so after a
  /// background publish fails or parks a draft the blob still holds the status
  /// from the last full save — and a draft stuck at `publishing` is filtered
  /// out of the library, stranding the video (#6833).
  factory DivineVideoDraft.fromDriftRow({
    required DraftRow row,
    required List<ClipRow> clipRows,
    required String documentsPath,
  }) {
    final draftJson = json.decode(row.data) as Map<String, dynamic>
      ..['publishStatus'] = row.publishStatus
      ..['publishError'] = row.publishError
      ..['publishAttempts'] = row.publishAttempts
      ..['lastModified'] = row.lastModified.toIso8601String();

    // Reconstruct clips from clip rows
    final clips = clipRows.map((clipRow) {
      final clipJson = json.decode(clipRow.data) as Map<String, dynamic>;
      return DivineVideoClip.fromJson(clipJson, documentsPath);
    }).toList();

    final draft = DivineVideoDraft.fromJson(draftJson, documentsPath);
    return draft.copyWith(clips: clips, skipUpdateLastModified: true);
  }

  final List<DivineVideoClip> clips;
  final String id;
  final String title;
  final String description;
  final Set<String> hashtags;
  final String selectedApproach;
  final DateTime createdAt;
  final DateTime lastModified;
  final Duration? expireTime;
  final PublishStatus publishStatus;
  final String? proofManifestJson;
  final String? publishError;
  final String? sourceDraftId;
  final int publishAttempts;
  final bool allowAudioReuse;

  final Map<String, dynamic> editorStateHistory;
  final Map<String, dynamic> editorEditingParameters;

  /// The final rendered clip ready for publishing.
  /// Cached to avoid re-rendering when no changes are made.
  final DivineVideoClip? finalRenderedClip;

  /// Pubkeys of collaborators tagged in this video.
  final Set<String> collaboratorPubkeys;

  /// Reference to a specific video that inspired this one (a-tag).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference for general "Inspired By" a creator.
  final String? inspiredByNpub;

  /// Accounts the author picked from the caption's mention autocomplete.
  ///
  /// Carries the pubkey the author actually chose, which the typed text
  /// cannot express when two accounts share a display name.
  final List<CaptionMention> captionMentions;

  /// Factual credits for clips reused from published videos.
  final List<ClipSourceCredit> clipSourceCredits;

  /// Currently selected audio event for the video.
  /// Contains the full AudioEvent data including URL, title, and start offset.
  /// Persisted to drafts so the sound selection survives app restarts.
  final AudioEvent? selectedSound;

  /// Public credit used only when publishing a reusable audio event.
  final AudioShareAttribution? audioShareAttribution;

  /// Comma-separated NIP-32 content warning labels for this video.
  final String? contentWarning;

  /// Optional NIP-22/NIP-71 reply target for publishing this video into a
  /// comment thread.
  final VideoReplyContext? videoReplyContext;
  final bool shareReplyToFeed;

  /// Position in the video used to generate the thumbnail.
  final Duration? thumbnailTimestamp;

  /// Absolute path to the user-selected cover image.
  ///
  /// Persisted independently of [finalRenderedClip] so the chosen cover
  /// survives the rendered clip being invalidated or cleared (e.g. reopening
  /// a draft and editing it). Stored as a basename in JSON and resolved back
  /// to an absolute path on load, matching the clip path handling (#5181).
  final String? customThumbnailPath;

  /// Check if this draft has ProofMode data
  bool get hasProofMode => proofManifestJson != null;

  /// Get deserialized NativeProofData (null if not present or invalid JSON)
  /// This is the new ProofMode format using native libraries
  NativeProofData? get nativeProof {
    if (proofManifestJson == null) return null;
    try {
      final json = jsonDecode(proofManifestJson!);
      // Check if this is native proof data (has 'videoHash' field)
      if (json is Map<String, dynamic> && json.containsKey('videoHash')) {
        return NativeProofData.fromJson(json);
      }
      return null;
    } catch (e) {
      Log.error(
        'Failed to parse NativeProofData: $e',
        name: 'VineDraft',
        category: LogCategory.system,
      );
      return null;
    }
  }

  DivineVideoDraft copyWith({
    List<DivineVideoClip>? clips,
    String? id,
    String? title,
    String? description,
    Set<String>? hashtags,
    PublishStatus? publishStatus,
    String? publishError,
    bool clearPublishError = false,
    String? sourceDraftId,
    bool clearSourceDraftId = false,
    Duration? expireTime,
    bool? allowAudioReuse,
    int? publishAttempts,
    String? proofManifestJson,
    bool clearProofManifestJson = false,
    Map<String, dynamic>? editorStateHistory,
    Map<String, dynamic>? editorEditingParameters,
    DivineVideoClip? finalRenderedClip,
    bool clearFinalRenderedClip = false,
    Set<String>? collaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    List<CaptionMention>? captionMentions,
    List<ClipSourceCredit>? clipSourceCredits,
    AudioEvent? selectedSound,
    bool clearSelectedSound = false,
    Object? audioShareAttribution = _sentinel,
    Object? contentWarning = _sentinel,
    Object? videoReplyContext = _sentinel,
    bool? shareReplyToFeed,
    Duration? thumbnailTimestamp,
    bool clearThumbnailTimestamp = false,
    String? customThumbnailPath,
    bool clearCustomThumbnailPath = false,
    bool skipUpdateLastModified = false,
  }) => DivineVideoDraft(
    id: id ?? this.id,
    clips: clips ?? this.clips,
    title: title ?? this.title,
    description: description ?? this.description,
    hashtags: hashtags ?? this.hashtags,
    selectedApproach: selectedApproach,
    createdAt: createdAt,
    lastModified: skipUpdateLastModified ? lastModified : DateTime.now(),
    expireTime: expireTime ?? this.expireTime,
    allowAudioReuse: allowAudioReuse ?? this.allowAudioReuse,
    publishStatus: publishStatus ?? this.publishStatus,
    publishError: clearPublishError
        ? null
        : (publishError ?? this.publishError),
    sourceDraftId: clearSourceDraftId
        ? null
        : (sourceDraftId ?? this.sourceDraftId),
    publishAttempts: publishAttempts ?? this.publishAttempts,
    proofManifestJson: clearProofManifestJson
        ? null
        : (proofManifestJson ?? this.proofManifestJson),
    editorStateHistory: editorStateHistory ?? this.editorStateHistory,
    editorEditingParameters:
        editorEditingParameters ?? this.editorEditingParameters,
    finalRenderedClip: clearFinalRenderedClip
        ? null
        : (finalRenderedClip ?? this.finalRenderedClip),
    collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
    inspiredByVideo: inspiredByVideo ?? this.inspiredByVideo,
    inspiredByNpub: inspiredByNpub ?? this.inspiredByNpub,
    captionMentions: captionMentions ?? this.captionMentions,
    clipSourceCredits: clipSourceCredits ?? this.clipSourceCredits,
    selectedSound: clearSelectedSound
        ? null
        : (selectedSound ?? this.selectedSound),
    audioShareAttribution: audioShareAttribution == _sentinel
        ? this.audioShareAttribution
        : audioShareAttribution as AudioShareAttribution?,
    contentWarning: contentWarning == _sentinel
        ? this.contentWarning
        : contentWarning as String?,
    videoReplyContext: videoReplyContext == _sentinel
        ? this.videoReplyContext
        : videoReplyContext as VideoReplyContext?,
    shareReplyToFeed: shareReplyToFeed ?? this.shareReplyToFeed,
    thumbnailTimestamp: clearThumbnailTimestamp
        ? null
        : (thumbnailTimestamp ?? this.thumbnailTimestamp),
    customThumbnailPath: clearCustomThumbnailPath
        ? null
        : (customThumbnailPath ?? this.customThumbnailPath),
  );

  static const _sentinel = Object();

  /// Returns an independent copy of this draft as a brand-new project.
  ///
  /// The copy gets a fresh [id] and `createdAt`/`lastModified` timestamps, and
  /// its publish state is reset (`draft` status, no attempts, no error, no
  /// [sourceDraftId]) so it starts clean. Pass [title] to rename the copy,
  /// otherwise the original title is kept.
  ///
  /// Clip and rendered-file references are shared with the source rather than
  /// copied on disk: clips are immutable inputs — edits produce new files or
  /// live in metadata — so the two projects can be edited independently. This
  /// mirrors how a publish copy shares files with its source, and file
  /// reference-counting keeps shared files alive until the last referencing
  /// draft is deleted.
  DivineVideoDraft duplicate({String? title}) {
    final now = DateTime.now();
    return DivineVideoDraft(
      id: 'draft_${now.microsecondsSinceEpoch}',
      clips: clips,
      title: title ?? this.title,
      description: description,
      hashtags: hashtags,
      selectedApproach: selectedApproach,
      createdAt: now,
      lastModified: now,
      expireTime: expireTime,
      allowAudioReuse: allowAudioReuse,
      publishStatus: PublishStatus.draft,
      publishAttempts: 0,
      proofManifestJson: proofManifestJson,
      editorStateHistory: editorStateHistory,
      editorEditingParameters: editorEditingParameters,
      finalRenderedClip: finalRenderedClip,
      collaboratorPubkeys: collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: inspiredByNpub,
      captionMentions: captionMentions,
      clipSourceCredits: clipSourceCredits,
      selectedSound: selectedSound,
      audioShareAttribution: audioShareAttribution,
      contentWarning: contentWarning,
      videoReplyContext: videoReplyContext,
      shareReplyToFeed: shareReplyToFeed,
      thumbnailTimestamp: thumbnailTimestamp,
      customThumbnailPath: customThumbnailPath,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clips': clips.map((clip) => clip.toJson()).toList(),
    'title': title,
    'description': description,
    'hashtags': hashtags.toList(),
    'selectedApproach': selectedApproach,
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    if (expireTime != null) 'expireTime': expireTime!.inMilliseconds,
    'allowAudioReuse': allowAudioReuse,
    'publishStatus': publishStatus.name,
    'publishError': publishError,
    if (sourceDraftId != null) 'sourceDraftId': sourceDraftId,
    'publishAttempts': publishAttempts,
    'proofManifestJson': proofManifestJson,
    if (editorStateHistory.isNotEmpty)
      'editorStateHistory': toPortableAudioPaths(editorStateHistory),
    if (editorEditingParameters.isNotEmpty)
      'editorEditingParameters': toPortableAudioPaths(editorEditingParameters),
    if (finalRenderedClip != null)
      'finalRenderedClip': finalRenderedClip!.toJson(),
    if (collaboratorPubkeys.isNotEmpty)
      'collaboratorPubkeys': collaboratorPubkeys.toList(),
    if (inspiredByVideo != null) 'inspiredByVideo': inspiredByVideo!.toJson(),
    if (inspiredByNpub != null) 'inspiredByNpub': inspiredByNpub,
    if (captionMentions.isNotEmpty)
      'captionMentions': captionMentions
          .map((mention) => mention.toJson())
          .toList(),
    if (clipSourceCredits.isNotEmpty)
      'clipSourceCredits': clipSourceCredits
          .map((credit) => credit.toJson())
          .toList(),
    if (selectedSound != null)
      'selectedSound': toPortableAudioPaths(selectedSound!.toJson()),
    if (audioShareAttribution != null)
      'audioShareAttribution': audioShareAttribution!.toJson(),
    if (contentWarning != null) 'contentWarning': contentWarning,
    if (videoReplyContext != null)
      'videoReplyContext': videoReplyContext!.toJson(),
    if (shareReplyToFeed) 'shareReplyToFeed': shareReplyToFeed,
    if (thumbnailTimestamp != null)
      'thumbnailTimestamp': thumbnailTimestamp!.inMilliseconds,
    if (customThumbnailPath != null)
      'customThumbnailPath': p.basename(customThumbnailPath!),
  };

  Set<ContentLabel> get contentWarnings => ContentLabel.fromCsv(contentWarning);

  /// Returns a hardcoded English age string.
  ///
  /// Prefer [localizedDisplayDuration] in UI code where
  /// [AppLocalizations] is available.
  @Deprecated('Use localizedDisplayDuration with AppLocalizations instead')
  String get displayDuration {
    final duration = DateTime.now().difference(createdAt);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Path to the thumbnail to display as this draft's cover.
  ///
  /// Prefers the durable user-selected cover, then the rendered clip's cover,
  /// and finally the first source clip's thumbnail.
  String? get coverThumbnailPath =>
      customThumbnailPath ??
      finalRenderedClip?.thumbnailPath ??
      (clips.isNotEmpty ? clips.first.thumbnailPath : null);

  bool get hasTitle => title.trim().isNotEmpty;
  bool get hasDescription => description.trim().isNotEmpty;
  bool get hasHashtags => hashtags.isNotEmpty;
  bool get canRetry => publishStatus == PublishStatus.failed;
  bool get isPublishing => publishStatus == PublishStatus.publishing;

  /// Whether the draft can be posted directly from the library.
  ///
  /// Only requires something to publish. A draft without [finalRenderedClip]
  /// is rendered on demand during publish, with its editor layers, timed
  /// filters, tune adjustments and audio restored from [editorStateHistory]
  /// and [editorEditingParameters] first — so posting no longer depends on a
  /// render happening to be cached.
  bool get canPost => clips.isNotEmpty;

  bool get hasEditorStateEdits {
    if (editorStateHistory.isEmpty) return false;

    return ImportStateHistory.fromMap(
          editorStateHistory,
          configs: ImportEditorConfigs(
            // We just need a simple dummy widgetLoader so we can load
            // the history.
            widgetLoader: (id, {meta}) => const SizedBox(),
          ),
        ).editorPosition !=
        -1;
  }

  /// Whether the draft has been edited beyond its initial recording.
  ///
  /// Checks metadata and editor state but ignores clips.
  /// Note: [allowAudioReuse] is intentionally excluded — it is a publish-time
  /// permission toggle (default `false`), not a content edit, so flipping it
  /// alone should not mark the draft as edited or trigger autosave.
  bool get hasBeenEdited =>
      clips.isNotEmpty &&
      (hasTitle ||
          hasDescription ||
          hasHashtags ||
          hasEditorStateEdits ||
          finalRenderedClip != null ||
          selectedSound != null ||
          audioShareAttribution != null ||
          contentWarning != null ||
          videoReplyContext != null ||
          collaboratorPubkeys.isNotEmpty ||
          inspiredByVideo != null ||
          inspiredByNpub != null ||
          clipSourceCredits.isNotEmpty ||
          expireTime != null);
}
