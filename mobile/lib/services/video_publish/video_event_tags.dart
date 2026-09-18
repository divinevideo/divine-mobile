// ABOUTME: Pure tag builders for a NIP-71 video event: reply threading, text
// ABOUTME: tracks, descriptive metadata, and creator credits.

import 'package:models/models.dart'
    show
        ClipSourceCredit,
        InspiredByInfo,
        videoReplyVisibilityFeedValue,
        videoReplyVisibilityTagName;
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/utils/collaborator_tags.dart';
import 'package:openvine/utils/inspired_by_tags.dart';

/// Appends the NIP-22 threading tags that mark a video as a reply.
///
/// Uppercase `E`/`K`/`P`/`A` name the root; lowercase `e`/`k`/`p` name the
/// direct parent — the parent comment when [context] has one, otherwise the
/// root itself (plus its `a` coordinate). [addReplyToFeed] additionally opts
/// the reply into the discovery feed.
void addVideoReplyTags(
  List<List<String>> tags,
  VideoReplyContext context, {
  required bool addReplyToFeed,
}) {
  tags
    ..add(['E', context.rootEventId, '', context.rootAuthorPubkey])
    ..add(['K', context.rootEventKind.toString()])
    ..add(['P', context.rootAuthorPubkey]);

  final rootAddressableId = context.rootAddressableId;
  if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
    tags.add(['A', rootAddressableId, '']);
  }

  final parentCommentId = context.parentCommentId;
  if (parentCommentId != null && parentCommentId.isNotEmpty) {
    tags
      ..add([
        'e',
        parentCommentId,
        '',
        context.parentAuthorPubkey ?? context.rootAuthorPubkey,
      ])
      ..add(['k', EventKind.comment.toString()])
      ..add(['p', context.parentAuthorPubkey ?? context.rootAuthorPubkey]);
  } else {
    tags
      ..add(['e', context.rootEventId, '', context.rootAuthorPubkey])
      ..add(['k', context.rootEventKind.toString()])
      ..add(['p', context.rootAuthorPubkey]);

    if (rootAddressableId != null && rootAddressableId.isNotEmpty) {
      tags.add(['a', rootAddressableId, '']);
    }
  }

  if (addReplyToFeed) {
    tags.add(const [
      videoReplyVisibilityTagName,
      videoReplyVisibilityFeedValue,
    ]);
  }
}

/// Appends one closed-caption `text-track` tag per ref, so the first publish
/// and a later subtitle republish carry the same tag shape.
void addTextTrackTags(
  List<List<String>> tags, {
  required Iterable<String> refs,
  required String lang,
}) {
  for (final ref in refs) {
    tags.add([
      'text-track',
      ref,
      AppConstants.defaultRelayUrl,
      'captions',
      lang,
    ]);
  }
}

/// Appends the descriptive tags of a video: title, summary, hashtags, NIP-32
/// language and content-warning labels, `published_at`, duration, the
/// accessibility `alt` text, and an optional NIP-40 expiration.
void addVideoMetadataTags(
  List<List<String>> tags, {
  required PendingUpload upload,
  required DateTime publishedAt,
  String? language,
  String? contentWarning,
  int? expirationTimestamp,
}) {
  final title = upload.title;
  final description = upload.description;
  if (title != null) tags.add(['title', title]);
  if (description != null) tags.add(['summary', description]);

  for (final hashtag in upload.hashtags ?? const <String>[]) {
    tags.add(['t', hashtag]);
  }

  // NIP-32 language self-labeling.
  if (language != null && language.isNotEmpty) {
    tags
      ..add(['L', 'ISO-639-1'])
      ..add(['l', language, 'ISO-639-1']);
  }

  // NIP-32 content-warning self-labeling (NIP-36).
  if (contentWarning != null && contentWarning.isNotEmpty) {
    final warnings = contentWarning.split(',').map((value) => value.trim());
    tags
      ..add(['content-warning', warnings.first])
      ..add(['L', 'content-warning']);
    for (final warning in warnings) {
      tags.add(['l', warning, 'content-warning']);
    }
  }

  tags.add([
    'published_at',
    (publishedAt.millisecondsSinceEpoch ~/ 1000).toString(),
  ]);

  final duration = upload.videoDuration;
  if (duration != null) {
    tags.add(['duration', duration.inSeconds.toString()]);
  }

  // Alt text for accessibility: the title, else the description.
  tags.add(['alt', title ?? description ?? 'Short video']);

  if (expirationTimestamp != null) {
    tags.add(['expiration', expirationTimestamp.toString()]);
  }
}

/// Appends the creator-credit tags: collaborator and mention `p` tags, the
/// Inspired By `a` tag, clip-source `a` tags, and the notifying `p` tags for
/// inspired-by and clip-source creators.
///
/// [selfPubkeyHex] is the publishing account; a creator never credits
/// themselves. Reply videos ([isReply]) never carry new inspired-by or
/// clip-source `p` tags: the model credits their content reference and any
/// legacy `p` tags in About, while the edit flow cannot own a new `p` tag
/// there. Emitting one would notify a creator the editor could never
/// un-credit.
void addVideoCreditTags(
  List<List<String>> tags, {
  required String? selfPubkeyHex,
  required bool isReply,
  List<String> collaboratorPubkeys = const [],
  List<String> mentionedPubkeys = const [],
  String? inspiredByAddressableId,
  String? inspiredByRelayUrl,
  List<String> inspiredByNpubs = const [],
  List<ClipSourceCredit> clipSourceCredits = const [],
}) {
  tags
    ..addAll(buildCollaboratorPTags(collaboratorPubkeys))
    ..addAll(
      buildMentionPTags(
        mentionedPubkeys,
        excludedPubkeys: collaboratorPubkeys,
      ),
    );

  final inspiredByCreatorPubkey = inspiredByAddressableId == null
      ? null
      : InspiredByInfo(
          addressableId: inspiredByAddressableId,
        ).creatorPubkey.trim().toLowerCase();
  final normalizedSelfPubkey = selfPubkeyHex?.trim().toLowerCase();
  final shouldEmitInspiredByATag =
      inspiredByAddressableId != null &&
      (inspiredByCreatorPubkey == null ||
          inspiredByCreatorPubkey.isEmpty ||
          inspiredByCreatorPubkey != normalizedSelfPubkey);

  // Inspired By a-tag (specific video reference)
  if (shouldEmitInspiredByATag) {
    tags.add([
      'a',
      inspiredByAddressableId,
      inspiredByRelayUrl ?? inspiredByPTagRelayHint,
      'mention',
    ]);
  }

  tags.addAll(
    buildClipSourceCreditATags(
      clipSourceCredits: clipSourceCredits,
      selfPubkey: normalizedSelfPubkey,
    ),
  );

  // p-tag the inspired-by creator(s) so they are notifiable. Added after
  // the collaborator/mention p-tags so those win dedup and caption
  // @token resolution keeps matching caption mentions first.
  if (isReply) return;
  tags
    ..addAll(
      buildInspiredByPTags(
        existingTags: tags,
        addressableId: inspiredByAddressableId,
        npubs: inspiredByNpubs,
        relayHint: inspiredByRelayUrl,
        selfPubkey: selfPubkeyHex,
      ),
    )
    ..addAll(
      buildClipSourceCreditPTags(
        existingTags: tags,
        clipSourceCredits: clipSourceCredits,
        selfPubkey: selfPubkeyHex,
      ),
    );
}
