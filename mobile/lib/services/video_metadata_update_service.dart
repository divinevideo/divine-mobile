// ABOUTME: Service that orchestrates the video-metadata-edit republish flow.
// ABOUTME: Extracts all business logic from the presentation layer into the service layer.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:characters/characters.dart';
import 'package:collection/collection.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart'
    show
        ClipSourceCredit,
        VideoEvent,
        clipSourceCreditTagMarker,
        withSoundCreditLines;
import 'package:nostr_client/nostr_client.dart' show Nip89ClientTag;
import 'package:nostr_sdk/nip92/imeta_tag.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/published_video_editor_seed.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/newest_video_revision.dart';
import 'package:openvine/utils/nostr_replacement_timestamp.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart' show VideosRepository;

/// Result returned by [VideoMetadataUpdateService.updateVideo].
sealed class VideoUpdateResult {
  const VideoUpdateResult();
}

/// The re-publish succeeded.
class VideoUpdateSuccess extends VideoUpdateResult {
  const VideoUpdateSuccess({
    required this.updatedEvent,
    required this.inviteFailureCount,
  });

  final VideoEvent updatedEvent;

  /// Number of collaborator invites that failed to send (may be 0).
  final int inviteFailureCount;
}

/// The re-publish failed with an unrecoverable error.
class VideoUpdateFailure extends VideoUpdateResult {
  const VideoUpdateFailure(this.reason);

  /// Why it failed. The exception itself is logged by the service and never
  /// travels to the UI — see `.claude/rules/error_handling.md`.
  final VideoMetadataUpdateError reason;
}

/// Carries a [VideoMetadataUpdateError] out of the deep call chain to the one
/// handler at the end of `updateVideo`. Private: nothing outside this file
/// needs to catch it, and the code is what escapes.
class _VideoUpdateException implements Exception {
  const _VideoUpdateException(this.reason, this.message);

  final VideoMetadataUpdateError reason;
  final String message;

  @override
  String toString() => 'VideoUpdateException(${reason.name}): $message';
}

/// The relays could not say what the newest revision of the video is: one
/// did not answer in full, or none holds it. Replacing it now could delete a
/// newer revision, so nothing was published.
class VideoUpdateOriginalUnavailable extends VideoUpdateResult {
  const VideoUpdateOriginalUnavailable();
}

/// Tag names the metadata-edit flow always rebuilds from the editor state
/// or re-derives from the original event's parsed fields.
const _editRebuiltTagNames = {
  'd',
  'imeta',
  'title',
  'summary',
  't',
  'published_at',
  'duration',
  'alt',
  'allow_audio_reuse',
  'allow_video_reuse',
};

/// Whether [tag] is rebuilt by the edit flow instead of copied verbatim.
///
/// Every other tag on the original event — audio-attribution `e` tags,
/// engagement counts, expiration, relay hints, ProofMode/C2PA
/// provenance, reply threading, subtitle text-tracks, … — is preserved
/// unchanged so a metadata edit does not drop data it does not own. The tags
/// come from the newest revision on the relays, so a tag another device added
/// after the editor opened survives too.
///
/// [isVideoReply] gates the inspired-by a-tag: the edit flow only rebuilds
/// that tag for non-reply videos (see the rebuild block in `updateVideo`),
/// so on a reply the inspired-by a-tag must be preserved rather than stripped
/// — otherwise it would be dropped with no replacement.
bool _isEditRebuiltTag(List<String> tag, {required bool isVideoReply}) {
  if (tag.isEmpty) return false;
  final name = tag.first;
  if (_editRebuiltTagNames.contains(name)) return true;
  // NIP-36 / NIP-32 content-warning group.
  if (name == 'content-warning') return true;
  if (name == 'L' && tag.length >= 2 && tag[1] == 'content-warning') {
    return true;
  }
  if (name == 'l' && tag.length >= 3 && tag[2] == 'content-warning') {
    return true;
  }
  // Collaborator p-tags; mention/reply p-tags are preserved.
  if (name == 'p' &&
      tag.length >= 4 &&
      tag[3].toLowerCase() == 'collaborator') {
    return true;
  }
  // Inspired-by p-tags mirror the inspired-by a-tag's lifecycle: owned by
  // the edit flow on non-reply videos (stripped here, re-emitted from the
  // editor state) so clearing or changing attribution updates the tag. On a
  // reply, emission is suppressed too, so preserve verbatim — otherwise the
  // tag would be dropped with no replacement.
  if (!isVideoReply &&
      name == 'p' &&
      tag.length >= 4 &&
      tag[3].toLowerCase() == inspiredByPTagMarker) {
    return true;
  }
  // Inspired-by a-tags (publish writes a 'mention' marker, edit writes
  // 'inspired-by' unless it keeps the same video). Only owned on non-reply
  // videos; on a reply these are reply-threading metadata (or a genuine
  // inspired-by the edit flow cannot represent) and are preserved verbatim.
  // Unmarked reply-root a-tags are preserved either way. Match the marker case-insensitively to mirror the
  // parser and the collaborator check above.
  if (!isVideoReply &&
      name == 'a' &&
      tag.length >= 4 &&
      (tag[3].toLowerCase() == 'mention' ||
          tag[3].toLowerCase() == 'inspired-by') &&
      tag[1].startsWith('${NIP71VideoKinds.addressableShortVideo}:')) {
    return true;
  }
  // clip-source tags are factual provenance for reused footage. The metadata
  // edit flow preserves them, then re-derives missing clip-source p-tags from
  // the preserved a-tags so clearing manual attribution does not erase creator
  // notification targets.
  return false;
}

List<ClipSourceCredit> _clipSourceCreditsFromPreservedTags(
  Iterable<List<String>> tags,
) {
  final credits = <ClipSourceCredit>[];
  final seen = <String>{};

  for (final tag in tags) {
    if (tag.length < 4 ||
        tag[0] != 'a' ||
        tag[3].toLowerCase() != clipSourceCreditTagMarker ||
        !tag[1].startsWith('${NIP71VideoKinds.addressableShortVideo}:')) {
      continue;
    }

    final credit = ClipSourceCredit.fromAddressableId(
      addressableId: tag[1],
      relayUrl: tag[2].isEmpty ? null : tag[2],
    );
    if (seen.add(credit.identityKey)) credits.add(credit);
  }

  return credits;
}

/// Sends collaborator invites to any pubkeys added since the last publish.
///
/// Returns a map of pubkey → [CollaboratorInviteResult] for each *new*
/// collaborator. Collaborators already present in [previousCollaboratorPubkeys]
/// are skipped.
Future<Map<String, CollaboratorInviteResult>>
sendPostPublishCollaboratorInvites({
  required CollaboratorInviteService inviteService,
  required VideoEvent video,
  required Iterable<String> previousCollaboratorPubkeys,
  required Iterable<String> updatedCollaboratorPubkeys,
  String relayHint = collaboratorInviteRelayHint,
}) async {
  final previous = canonicalCollaboratorPubkeys(
    identifiers: previousCollaboratorPubkeys,
    creatorIdentifier: video.pubkey,
  );
  final updated = canonicalCollaboratorPubkeys(
    identifiers: updatedCollaboratorPubkeys,
    creatorIdentifier: video.pubkey,
  );
  final newCollaborators = updated
      .where((pubkey) => !previous.contains(pubkey))
      .toSet();
  if (newCollaborators.isEmpty) return const {};

  final videoAddress =
      '${NIP71VideoKinds.addressableShortVideo}:${video.pubkey}:${video.stableId}';
  final results = <String, CollaboratorInviteResult>{};
  for (final pubkey in newCollaborators) {
    try {
      results[pubkey] = await inviteService.sendInvite(
        collaboratorPubkey: pubkey,
        creatorPubkey: video.pubkey,
        videoAddress: videoAddress,
        title: video.title,
        thumbnailUrl: video.thumbnailUrl,
        relayHint: relayHint,
      );
    } on Object catch (e, stackTrace) {
      Log.warning(
        'Failed to send post-publish collaborator invite: $e\n$stackTrace',
        name: 'VideoMetadataUpdateService',
        category: LogCategory.video,
      );
      results[pubkey] = CollaboratorInviteResult(
        success: false,
        error: e.toString(),
      );
    }
  }
  return results;
}

/// Orchestrates the video-metadata-edit republish flow.
///
/// Responsibilities:
/// - Preserves the original event's imeta variants and updates the thumbnail.
/// - Optionally uploads a new thumbnail to Blossom.
/// - Assembles the replacement NIP-71 Nostr event.
/// - Signs the event and publishes it, succeeding only once a relay accepts it.
/// - Updates the in-process event caches.
/// - Sends post-publish collaborator invites.
///
/// All dependencies are constructor-injected for testability.
class VideoMetadataUpdateService {
  const VideoMetadataUpdateService({
    required AuthService authService,
    required BlossomUploadService blossomService,
    required SignedEventRelayPublisher relayPublisher,
    required PersonalEventCacheService personalEventCache,
    required VideoEventService videoEventService,
    required VideosRepository videosRepository,
    required CollaboratorInviteService collaboratorInviteService,
  }) : _authService = authService,
       _blossomService = blossomService,
       _relayPublisher = relayPublisher,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _videosRepository = videosRepository,
       _collaboratorInviteService = collaboratorInviteService;

  final AuthService _authService;
  final BlossomUploadService _blossomService;
  final SignedEventRelayPublisher _relayPublisher;
  final PersonalEventCacheService _personalEventCache;
  final VideoEventService _videoEventService;
  final VideosRepository _videosRepository;
  final CollaboratorInviteService _collaboratorInviteService;

  /// Re-publishes [originalVideo] with the metadata from [editorState].
  ///
  /// The replacement is built from the newest revision the relays hold, not
  /// from [originalVideo], which is the one the editor opened: another device
  /// may have replaced it since. A field the editor left as it was seeded
  /// takes the newest revision's value. Pass [editorBaseline] when the screen
  /// has seen a newer revision since it seeded the form. When the relays cannot say
  /// what is newest, nothing is published and the result is
  /// [VideoUpdateOriginalUnavailable] (#11250).
  ///
  /// If [newThumbnailFile] is non-null, it is uploaded to Blossom before
  /// the event is signed; on upload failure the original thumbnail URL is
  /// kept and the republish continues.
  ///
  /// [initialCollaboratorPubkeys] is used to determine which collaborators
  /// are new (and therefore need an invite DM).
  Future<VideoUpdateResult> updateVideo({
    required VideoEvent originalVideo,
    required VideoEditorProviderState editorState,
    required Set<String> initialCollaboratorPubkeys,
    VideoEvent? editorBaseline,
    File? newThumbnailFile,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.notAuthenticated,
          'User not authenticated',
        );
      }

      var latest = await newestVideoRevision(
        _videosRepository,
        originalVideo,
        logName: 'VideoMetadataUpdateService',
      );
      if (latest == null) return const VideoUpdateOriginalUnavailable();

      String? uploadedThumbnailUrl;
      if (newThumbnailFile != null) {
        final beforeUpload = latest.id == originalVideo.id
            ? originalVideo
            : VideoEvent.fromNostrEvent(latest, permissive: true);
        _imetaTagsForEdit(latest.tags, fallback: beforeUpload);
        final uploadResult = await _blossomService.uploadImage(
          imageFile: newThumbnailFile,
          nostrPubkey: _authService.currentPublicKeyHex ?? '',
        );
        if (uploadResult.success && uploadResult.cdnUrl != null) {
          uploadedThumbnailUrl = uploadResult.cdnUrl;
        } else {
          Log.error(
            'Thumbnail upload failed during video update; keeping original',
            name: 'VideoMetadataUpdateService',
            category: LogCategory.video,
          );
        }

        // A subtitle or sound may have been published while Blossom was
        // uploading. Use the last revision we saw as the floor for this read.
        latest = await newestVideoRevision(
          _videosRepository,
          beforeUpload.copyWith(eventCreatedAt: latest.createdAt),
          logName: 'VideoMetadataUpdateService',
        );
        if (latest == null) return const VideoUpdateOriginalUnavailable();
      }

      final video = VideoEvent.fromNostrEvent(latest, permissive: true);
      final latestEditorState = editorStateFromPublishedVideo(video);
      // A REST row can omit signed tags even when its event ID matches.
      final edits = _rebaseEdits(
        editorState,
        opened: editorStateFromPublishedVideo(editorBaseline ?? originalVideo),
        latest: latestEditorState,
      );
      // A republish is Divine's own publish: the signer stamps attribution
      // from the current preference (#8176).
      final originalTags = Nip89ClientTag.withoutClientTag(latest.tags);

      // A pubkey promoted from a plain mention to a collaborator in this
      // edit changes role: drop its stale 'mention' p-tag so it is not
      // double-listed alongside the rebuilt 'collaborator' p-tag.
      final collaboratorPubkeys = canonicalCollaboratorPubkeys(
        identifiers: edits.collaboratorPubkeys,
        creatorIdentifier: _authService.currentPublicKeyHex,
      );
      if (collaboratorPubkeys.length > VideoEditorConstants.maxCollaborators) {
        final existingCollaborators = canonicalCollaboratorPubkeys(
          identifiers: video.collaboratorPubkeys,
          creatorIdentifier: _authService.currentPublicKeyHex,
        );
        if (collaboratorPubkeys.difference(existingCollaborators).isNotEmpty) {
          // Do not silently discard either device's collaborator choices.
          throw const _VideoUpdateException(
            VideoMetadataUpdateError.concurrentEditsOverLimit,
            'Concurrent edits exceed the collaborator limit',
          );
        }
      }
      // The merged set only passes the limit when this edit added a tag the
      // newest revision lacks, and publishing would drop it silently.
      final mergedHashtags = edits.tags
          .map(HashtagExtractor.normalizeVideoHashtag)
          .whereType<String>()
          .toSet();
      if (mergedHashtags.length > HashtagExtractor.maxHashtagsPerVideo) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.concurrentEditsOverLimit,
          'Concurrent edits exceed the hashtag limit',
        );
      }
      bool isPromotedMentionPTag(List<String> tag) {
        if (tag.length < 4 ||
            tag.first != 'p' ||
            tag[3].toLowerCase() != 'mention') {
          return false;
        }
        return collaboratorPubkeys.contains(normalizeToHex(tag[1].trim()));
      }

      // Preserve every tag the edit flow does not own; the owned ones are
      // rebuilt from the editor state below.
      final isVideoReply = video.isVideoReply;
      final preservedTags = originalTags
          .where(
            (tag) =>
                !_isEditRebuiltTag(tag, isVideoReply: isVideoReply) &&
                !isPromotedMentionPTag(tag),
          )
          .toList();

      final tags = <List<String>>[];

      // Required 'd' tag — must match the original to replace the event.
      tags.add(['d', latest.dTagValue]);

      final imetaTags = _imetaTagsForEdit(originalTags, fallback: video);
      final thumbnailUrl = uploadedThumbnailUrl;
      tags.addAll(
        thumbnailUrl == null
            ? imetaTags
            : imetaTags.map((tag) => _replaceImetaThumbnail(tag, thumbnailUrl)),
      );

      // Always written, even empty: the relay rejects a video event with no
      // `title` tag, and first publish writes `["title", ""]` for untitled
      // videos.
      tags.add(['title', edits.title.trim()]);

      // Other clients can publish a summary distinct from the caption.
      final signedSummaries = originalTags
          .where((tag) => tag.firstOrNull == 'summary')
          .toList();
      final summary = edits.description.trim();
      if (edits.description == latestEditorState.description &&
          signedSummaries.isNotEmpty) {
        tags.addAll(signedSummaries);
      } else if (summary.isNotEmpty) {
        tags.add([
          'summary',
          withSoundCreditLines(
            summary,
            video.soundCredits.map((credit) => credit.line),
          ),
        ]);
      }

      for (final hashtag in HashtagExtractor.normalizeVideoHashtags(
        edits.tags,
      )) {
        tags.add(['t', hashtag]);
      }

      // Mirror the NIP-36 / NIP-32 tag group written at original publish.
      if (edits.contentWarnings.isNotEmpty) {
        tags
          ..add(['content-warning', edits.contentWarnings.first.value])
          ..add(['L', 'content-warning']);
        for (final label in edits.contentWarnings) {
          tags.add(['l', label.value, 'content-warning']);
        }
      }

      if (video.publishedAt != null) {
        tags.add(['published_at', video.publishedAt!]);
      }
      if (video.duration != null) {
        tags.add(['duration', video.duration.toString()]);
      }
      if (video.altText != null) {
        tags.add(['alt', video.altText!]);
      }

      tags.addAll(buildCollaboratorPTags(collaboratorPubkeys));

      // The parser exposes an unmarked lowercase reply-root a-tag through
      // inspiredByVideo too. Do not turn that parent reference into creator
      // attribution when republishing a video reply.
      if (edits.inspiredByVideo case final inspiredBy? when !isVideoReply) {
        // Publish marks the a-tag 'mention', and an Add yours answer counts
        // as joining its chain only while it does, so an edit that keeps the
        // same video keeps that marker.
        final keepsMention = originalTags.any(
          (tag) =>
              tag.length >= 4 &&
              tag[0] == 'a' &&
              tag[1] == inspiredBy.addressableId &&
              tag[3].toLowerCase() == 'mention',
        );
        tags.add([
          'a',
          inspiredBy.addressableId,
          inspiredBy.relayUrl ?? '',
          if (keepsMention) 'mention' else 'inspired-by',
        ]);
      }

      tags.add(['allow_audio_reuse', edits.allowAudioReuse.toString()]);
      tags.add([
        'allow_video_reuse',
        edits.offersVideoReuse.toString(),
      ]);

      tags.addAll(preservedTags);
      tags.addAll(
        buildClipSourceCreditPTags(
          existingTags: tags,
          clipSourceCredits: _clipSourceCreditsFromPreservedTags(preservedTags),
          selfPubkey: _authService.currentPublicKeyHex,
        ),
      );

      // p-tag the inspired-by creator(s) so they are notifiable. Emitted
      // after [preservedTags] so preserved caption-mention p-tags win dedup
      // and @token resolution. Reply-gated like the a-tag above; on a reply
      // any legacy inspired-by p-tag is preserved verbatim instead. Unlike
      // the sibling a-tag (which keeps its shipped `relayUrl ?? ''` shape),
      // the p-tag deliberately falls back to the default relay so a usable
      // hint always accompanies the notify tag.
      if (!isVideoReply) {
        tags.addAll(
          buildInspiredByPTags(
            existingTags: tags,
            addressableId: edits.inspiredByVideo?.addressableId,
            npubs: edits.inspiredByNpubs,
            relayHint: edits.inspiredByVideo?.relayUrl,
            selfPubkey: _authService.currentPublicKeyHex,
          ),
        );
      }

      // An edit cannot change the sounds, so their credit lines stay as
      // published; the editor never showed them.
      final content = withInspiredByContentReference(
        withSoundCreditLines(
          edits.description.trim(),
          video.soundCredits.map((credit) => credit.line),
        ),
        edits.inspiredByNpubs,
      );

      // Use raw Nostr created_at, not the stable NIP-71 published_at value
      // exposed through VideoEvent.createdAt, so relays accept replacements.
      final event = await _authService.createAndSignEvent(
        kind: latest.kind,
        content: content,
        tags: tags,
        createdAt: nextReplacementCreatedAtAfter(latest.createdAt),
      );

      if (event == null) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.couldNotSign,
          'Failed to create updated event',
        );
      }

      // Waits for a relay's NIP-01 `OK`: a socket write alone is not
      // acceptance, and a rejected edit must not be reported or cached as
      // published.
      final outcome = await _relayPublisher.publishViaWebSocket(event);
      if (outcome != EventPublishOutcome.published) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.publishRejected,
          'No relay accepted the updated event',
        );
      }

      _personalEventCache.cacheUserEvent(event);

      final updatedVideoEvent = VideoEvent.fromNostrEvent(
        event,
        permissive: true,
      );
      _videoEventService.updateVideoEvent(updatedVideoEvent);

      final inviteFailureCount = await _sendCollaboratorInvites(
        video: updatedVideoEvent,
        // Collaborators the newest revision already credits were invited when
        // it was published.
        initialCollaboratorPubkeys: {
          ...initialCollaboratorPubkeys,
          ...video.collaboratorPubkeys,
        },
        updatedCollaboratorPubkeys: collaboratorPubkeys,
      );

      return VideoUpdateSuccess(
        updatedEvent: updatedVideoEvent,
        inviteFailureCount: inviteFailureCount,
      );
    } on Object catch (e) {
      Log.error(
        'Failed to update video: $e',
        name: 'VideoMetadataUpdateService',
        category: LogCategory.video,
      );
      return VideoUpdateFailure(
        e is _VideoUpdateException
            ? e.reason
            : VideoMetadataUpdateError.generic,
      );
    }
  }

  /// Keeps media variants separate so URLs, MIME types, and hashes stay
  /// associated with their own rendition. A legacy top-level video URL
  /// can provide the playable media when no imeta tag has one.
  static List<List<String>> _imetaTagsForEdit(
    List<List<String>> originalTags, {
    required VideoEvent fallback,
  }) {
    final imetaTags = <List<String>>[];
    var hasPlayableUrl = false;
    for (final tag in originalTags) {
      if (tag.isEmpty || tag.first != 'imeta') continue;
      final filtered = <String>['imeta'];
      var removedLocalUrl = false;
      parseImetaTag(tag, (key, value) {
        if (key == 'url') {
          if (!_isHttpUrl(value)) {
            removedLocalUrl = true;
            return;
          }
          hasPlayableUrl = true;
        }
        filtered.add('$key $value');
      });
      if (removedLocalUrl && filtered.length == 1) continue;
      imetaTags.add(removedLocalUrl ? filtered : tag);
    }
    if (hasPlayableUrl) return imetaTags;
    final url = fallback.videoUrl;
    if (!_isHttpUrl(url)) {
      throw const _VideoUpdateException(
        VideoMetadataUpdateError.noPlayableVideoUrl,
        'Cannot update video: no valid HTTP video URLs found',
      );
    }
    return [
      [
        'imeta',
        'url $url',
        'm video/mp4',
        if (fallback.thumbnailUrl case final thumbnail?) 'image $thumbnail',
        if (fallback.blurhash case final blurhash?) 'blurhash $blurhash',
        if (fallback.dimensions case final dimensions?) 'dim $dimensions',
        if (fallback.sha256 case final sha256?) 'x $sha256',
        if (fallback.fileSize case final fileSize?) 'size $fileSize',
      ],
      ...imetaTags,
    ];
  }

  static List<String> _replaceImetaThumbnail(
    List<String> tag,
    String thumbnailUrl,
  ) {
    final updated = ['imeta'];
    parseImetaTag(tag, (key, value) {
      if (key != 'image' && key != 'thumb') updated.add('$key $value');
    });
    return updated..add('image $thumbnailUrl');
  }

  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Sends DM invites to newly added collaborators and returns the failure
  /// count (0 means all invites succeeded or there were no new collaborators).
  Future<int> _sendCollaboratorInvites({
    required VideoEvent video,
    required Set<String> initialCollaboratorPubkeys,
    required Set<String> updatedCollaboratorPubkeys,
  }) async {
    final results = await sendPostPublishCollaboratorInvites(
      inviteService: _collaboratorInviteService,
      video: video,
      previousCollaboratorPubkeys: initialCollaboratorPubkeys,
      updatedCollaboratorPubkeys: updatedCollaboratorPubkeys,
    );
    return results.values
        .where((result) => !result.success && !result.retryablePending)
        .length;
  }
}

/// [edited], moved from the revision it was seeded from onto a newer one: a
/// field this edit left as [opened] seeded it takes [latest]'s value, so a
/// change another device made to a field this edit did not touch survives.
VideoEditorProviderState _rebaseEdits(
  VideoEditorProviderState edited, {
  required VideoEditorProviderState opened,
  required VideoEditorProviderState latest,
}) {
  T pick<T>(T Function(VideoEditorProviderState state) field) =>
      const DeepCollectionEquality().equals(field(edited), field(opened))
      ? field(latest)
      : field(edited);
  // Any metadata change makes the editor store the title and caption trimmed,
  // and the caption cut to the description limit. When another device changed
  // the text, a value that differs from the seed only by that was not edited
  // here, so the newer text wins.
  String pickText(
    String Function(VideoEditorProviderState state) field, {
    int? limit,
  }) {
    final seeded = field(opened);
    final value = field(edited);
    if (value == seeded) return field(latest);
    if (field(latest) == seeded) return value;
    final trimmed = seeded.trim();
    final normalized = limit == null
        ? trimmed
        : trimmed.characters.take(limit).toString();
    return value == normalized ? field(latest) : value;
  }

  Set<T> applySetEdits<T>(
    Set<T> Function(VideoEditorProviderState state) field,
  ) {
    final before = field(opened);
    final after = field(edited);
    return field(latest).difference(before.difference(after))
      ..addAll(after.difference(before));
  }

  final inspiredByVideo = pick((state) => state.inspiredByVideo);
  return edited.copyWith(
    title: pickText((state) => state.title),
    description: pickText(
      (state) => state.description,
      limit: VideoEditorConstants.descriptionLimit,
    ),
    tags: applySetEdits((state) => state.tags),
    contentWarnings: applySetEdits((state) => state.contentWarnings),
    collaboratorPubkeys: applySetEdits((state) => state.collaboratorPubkeys),
    inspiredByVideo: inspiredByVideo,
    clearInspiredByVideo: inspiredByVideo == null,
    inspiredByNpubs: pick((state) => state.inspiredByNpubs),
    allowAudioReuse: pick((state) => state.allowAudioReuse),
    allowVideoReuse: pick((state) => state.allowVideoReuse),
  );
}
