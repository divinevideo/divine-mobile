// ABOUTME: Service that orchestrates the video-metadata-edit republish flow.
// ABOUTME: Extracts all business logic from the presentation layer into the service layer.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:models/models.dart'
    show ClipSourceCredit, VideoEvent, clipSourceCreditTagMarker;
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata_update_error.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_service.dart';
import 'package:openvine/services/personal_event_cache_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_event_tag_source.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/nostr_replacement_timestamp.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:unified_logger/unified_logger.dart';

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

/// The original event could not be loaded with the raw tags required for a
/// lossless addressable-event replacement.
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
};

/// Whether [tag] is rebuilt by the edit flow instead of copied verbatim.
///
/// Every other tag on the original event — audio-attribution `e` tags,
/// engagement counts, expiration, client, relay hints, ProofMode/C2PA
/// provenance, reply threading, subtitle text-tracks, … — is preserved
/// unchanged so a metadata edit does not drop data it does not own. Publishing
/// is refused unless the raw tags are available (see [_sourceOriginalTags]).
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
  // 'inspired-by'). Only owned on non-reply videos; on a reply these are
  // reply-threading metadata (or a genuine inspired-by the edit flow cannot
  // represent) and are preserved verbatim. Unmarked reply-root a-tags are
  // preserved either way. Match the marker case-insensitively to mirror the
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
/// - Extracts video URLs from the original event's imeta tags.
/// - Optionally uploads a new thumbnail to Blossom.
/// - Assembles the replacement NIP-71 Nostr event.
/// - Signs and publishes the event.
/// - Updates the in-process event caches.
/// - Sends post-publish collaborator invites.
///
/// All dependencies are constructor-injected for testability.
class VideoMetadataUpdateService {
  const VideoMetadataUpdateService({
    required AuthService authService,
    required BlossomUploadService blossomService,
    required NostrClient nostrService,
    required PersonalEventCacheService personalEventCache,
    required VideoEventService videoEventService,
    required CollaboratorInviteService collaboratorInviteService,
  }) : _authService = authService,
       _blossomService = blossomService,
       _nostrService = nostrService,
       _personalEventCache = personalEventCache,
       _videoEventService = videoEventService,
       _collaboratorInviteService = collaboratorInviteService;

  final AuthService _authService;
  final BlossomUploadService _blossomService;
  final NostrClient _nostrService;
  final PersonalEventCacheService _personalEventCache;
  final VideoEventService _videoEventService;
  final CollaboratorInviteService _collaboratorInviteService;

  /// Re-publishes [originalVideo] with the metadata from [editorState].
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
    File? newThumbnailFile,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.notAuthenticated,
          'User not authenticated',
        );
      }

      final originalTags = _sourceOriginalTags(originalVideo);
      if (originalTags.isEmpty) {
        return const VideoUpdateOriginalUnavailable();
      }

      // A pubkey promoted from a plain mention to a collaborator in this
      // edit changes role: drop its stale 'mention' p-tag so it is not
      // double-listed alongside the rebuilt 'collaborator' p-tag.
      final collaboratorPubkeys = canonicalCollaboratorPubkeys(
        identifiers: editorState.collaboratorPubkeys,
        creatorIdentifier: _authService.currentPublicKeyHex,
      );
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
      final isVideoReply = originalVideo.isVideoReply;
      final preservedTags = originalTags
          .where(
            (tag) =>
                !_isEditRebuiltTag(tag, isVideoReply: isVideoReply) &&
                !isPromotedMentionPTag(tag),
          )
          .toList();

      final tags = <List<String>>[];

      // Required 'd' tag — must match the original to replace the event.
      tags.add(['d', originalVideo.stableId]);

      final videoUrls = _extractVideoUrls(originalVideo);
      if (videoUrls.isEmpty) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.noPlayableVideoUrl,
          'Cannot update video: no valid HTTP video URLs found',
        );
      }

      final imetaComponents = <String>[];
      for (final url in videoUrls) {
        imetaComponents.add('url $url');
      }
      imetaComponents.add('m video/mp4');

      if (newThumbnailFile != null) {
        final uploadResult = await _blossomService.uploadImage(
          imageFile: newThumbnailFile,
          nostrPubkey: _authService.currentPublicKeyHex ?? '',
        );
        if (uploadResult.success && uploadResult.cdnUrl != null) {
          imetaComponents.add('image ${uploadResult.cdnUrl!}');
        } else {
          Log.error(
            'Thumbnail upload failed during video update; keeping original',
            name: 'VideoMetadataUpdateService',
            category: LogCategory.video,
          );
          if (originalVideo.thumbnailUrl != null) {
            imetaComponents.add('image ${originalVideo.thumbnailUrl!}');
          }
        }
      } else if (originalVideo.thumbnailUrl != null) {
        imetaComponents.add('image ${originalVideo.thumbnailUrl!}');
      }

      if (originalVideo.blurhash != null) {
        imetaComponents.add('blurhash ${originalVideo.blurhash!}');
      }
      if (originalVideo.dimensions != null) {
        imetaComponents.add('dim ${originalVideo.dimensions!}');
      }
      if (originalVideo.sha256 != null) {
        imetaComponents.add('x ${originalVideo.sha256!}');
      }
      if (originalVideo.fileSize != null) {
        imetaComponents.add('size ${originalVideo.fileSize!}');
      }

      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      final title = editorState.title.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      final summary = editorState.description.trim();
      if (summary.isNotEmpty) {
        tags.add(['summary', summary]);
      }

      for (final hashtag in editorState.tags) {
        tags.add(['t', hashtag]);
      }

      // Mirror the NIP-36 / NIP-32 tag group written at original publish.
      if (editorState.contentWarnings.isNotEmpty) {
        tags
          ..add(['content-warning', editorState.contentWarnings.first.value])
          ..add(['L', 'content-warning']);
        for (final label in editorState.contentWarnings) {
          tags.add(['l', label.value, 'content-warning']);
        }
      }

      if (originalVideo.publishedAt != null) {
        tags.add(['published_at', originalVideo.publishedAt!]);
      }
      if (originalVideo.duration != null) {
        tags.add(['duration', originalVideo.duration.toString()]);
      }
      if (originalVideo.altText != null) {
        tags.add(['alt', originalVideo.altText!]);
      }

      tags.addAll(buildCollaboratorPTags(collaboratorPubkeys));

      // The parser exposes an unmarked lowercase reply-root a-tag through
      // inspiredByVideo too. Do not turn that parent reference into creator
      // attribution when republishing a video reply.
      if (editorState.inspiredByVideo != null && !isVideoReply) {
        tags.add([
          'a',
          editorState.inspiredByVideo!.addressableId,
          editorState.inspiredByVideo!.relayUrl ?? '',
          'inspired-by',
        ]);
      }

      if (editorState.allowAudioReuse) {
        tags.add(['allow_audio_reuse', 'true']);
      }

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
            addressableId: editorState.inspiredByVideo?.addressableId,
            npubs: editorState.inspiredByNpubs,
            relayHint: editorState.inspiredByVideo?.relayUrl,
            selfPubkey: _authService.currentPublicKeyHex,
          ),
        );
      }

      final content = withInspiredByContentReference(
        editorState.description.trim(),
        editorState.inspiredByNpubs,
      );

      // Use raw Nostr created_at, not the stable NIP-71 published_at value
      // exposed through VideoEvent.createdAt, so relays accept replacements.
      final event = await _authService.createAndSignEvent(
        kind: NIP71VideoKinds.addressableShortVideo,
        content: content,
        tags: tags,
        createdAt: nextReplacementCreatedAt(originalVideo),
      );

      if (event == null) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.couldNotSign,
          'Failed to create updated event',
        );
      }

      final publishResult = await _nostrService.publishEvent(event);
      if (publishResult is! PublishSuccess) {
        throw const _VideoUpdateException(
          VideoMetadataUpdateError.publishRejected,
          'Failed to publish updated event',
        );
      }
      final publishedEvent = publishResult.event;

      _personalEventCache.cacheUserEvent(publishedEvent);

      final updatedVideoEvent = VideoEvent.fromNostrEvent(publishedEvent);
      _videoEventService.updateVideoEvent(updatedVideoEvent);

      final inviteFailureCount = await _sendCollaboratorInvites(
        video: updatedVideoEvent,
        initialCollaboratorPubkeys: initialCollaboratorPubkeys,
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

  /// Returns the raw tags of the event being edited, for preservation.
  ///
  /// [VideoEvent.nostrEventTags] is empty when the in-memory event was
  /// rehydrated from a JSON cache that omits raw tags (the own-profile grid
  /// and cold-start feed do this). In that case, recover the raw event from
  /// the personal cache so preservation is not silently defeated; if it is
  /// not cached, return an empty list so [updateVideo] can refuse to publish.
  List<List<String>> _sourceOriginalTags(VideoEvent video) {
    return sourceOriginalVideoTags(
      video: video,
      personalEventCache: _personalEventCache,
    );
  }

  /// Extracts all valid HTTP video URLs from the event's imeta tags.
  ///
  /// Handles both the legacy space-separated format
  /// (`['imeta', 'url https://...', ...]`) and the current key-value pair
  /// format (`['imeta', 'url', 'https://...', ...]`).
  ///
  /// Falls back to [VideoEvent.videoUrl] when the raw tags array is empty
  /// (e.g. events loaded from a JSON cache that omits raw tags).
  List<String> _extractVideoUrls(VideoEvent video) {
    final urls = <String>[];
    for (final tag in video.nostrEventTags) {
      if (tag.isEmpty || tag[0] != 'imeta') continue;
      if (tag.length > 1 && tag[1].contains(' ')) {
        // Legacy space-separated format.
        for (var i = 1; i < tag.length; i++) {
          final spaceIdx = tag[i].indexOf(' ');
          if (spaceIdx > 0) {
            final key = tag[i].substring(0, spaceIdx);
            final value = tag[i].substring(spaceIdx + 1);
            if (key == 'url' && _isHttpUrl(value) && !urls.contains(value)) {
              urls.add(value);
            }
          }
        }
      } else {
        // Current key-value pair format.
        for (var i = 1; i < tag.length - 1; i += 2) {
          if (tag[i] == 'url' &&
              _isHttpUrl(tag[i + 1]) &&
              !urls.contains(tag[i + 1])) {
            urls.add(tag[i + 1]);
          }
        }
      }
    }
    if (urls.isEmpty && _isHttpUrl(video.videoUrl)) {
      urls.add(video.videoUrl!);
    }
    return urls;
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
