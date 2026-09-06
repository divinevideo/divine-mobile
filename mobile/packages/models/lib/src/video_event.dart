// ABOUTME: Video Event model for NIP-71 compliant video events
// OpenVine uses kind 34236 (addressable short videos)
// Parses video metadata from Nostr events with support for
// kinds 22, 21, 34236, 34235

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:models/src/nip71_video_kinds.dart';
import 'package:models/src/video_attribution.dart';
import 'package:models/src/video_url_resolver.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

String? _usableThumbnailUrl(Object? value) {
  final url = value?.toString();
  if (url == null || url.isEmpty) return null;
  if (!VideoUrlResolver.isValidVideoUrl(url)) return null;
  if (VideoUrlResolver.isKnownDeadMediaUrl(url)) return null;
  return url;
}

/// Compact backend-computed ProofMode verification result for feed/list rows.
@immutable
class ProofVerificationSummary {
  const ProofVerificationSummary({
    required this.status,
    required this.version,
    this.level,
    this.checkedAt,
    this.checks = const {},
  });

  factory ProofVerificationSummary.fromJson(Map<String, dynamic> json) {
    final rawChecks = json['checks'];
    final checks = rawChecks is Map<String, dynamic>
        ? rawChecks.map(
            (key, value) => MapEntry(key, value is bool ? value : null),
          )
        : const <String, bool?>{};

    final checkedAt = json['checked_at'];
    final checkedAtSeconds = (checkedAt as num?)?.toInt();
    return ProofVerificationSummary(
      status: json['status']?.toString() ?? 'unknown',
      level: json['level']?.toString(),
      checkedAt: checkedAtSeconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              checkedAtSeconds * 1000,
              isUtc: true,
            ),
      version: (json['version'] as num?)?.toInt() ?? 0,
      checks: checks,
    );
  }

  final String status;
  final String? level;
  final DateTime? checkedAt;
  final int version;
  final Map<String, bool?> checks;

  bool get isUnknown => status == 'unknown';
  bool get isInvalid => status == 'invalid';
  bool get isPresent => status == 'present';
  bool get isVerified => status == 'verified';
  bool get canUseAsProofSignal => isPresent || isVerified;
  bool get hasUsableProofmode =>
      canUseAsProofSignal &&
      proofmodePresent == true &&
      proofmodeParseOk != false;
  bool get hasUsableDeviceAttestation =>
      canUseAsProofSignal &&
      deviceAttestationPresent == true &&
      deviceAttestationValid != false;
  bool get hasUsablePgpSignature =>
      canUseAsProofSignal &&
      pgpSignaturePresent == true &&
      pgpSignatureValid != false;
  bool get hasUsableC2paManifest =>
      canUseAsProofSignal &&
      c2paManifestPresent == true &&
      c2paManifestValid != false;
  bool get hasProofSignal =>
      hasUsableProofmode ||
      hasUsableDeviceAttestation ||
      hasUsablePgpSignature ||
      hasUsableC2paManifest;
  bool get shouldShowBasicProofTier =>
      hasProofSignal && level != 'verified_mobile' && level != 'verified_web';

  bool? get proofmodePresent => checks['proofmode_present'];
  bool? get proofmodeParseOk => checks['proofmode_parse_ok'];
  bool? get pgpSignaturePresent => checks['pgp_signature_present'];
  bool? get pgpSignatureValid => checks['pgp_signature_valid'];
  bool? get deviceAttestationPresent => checks['device_attestation_present'];
  bool? get deviceAttestationValid => checks['device_attestation_valid'];
  bool? get c2paManifestPresent => checks['c2pa_manifest_present'];
  bool? get c2paManifestValid => checks['c2pa_manifest_valid'];

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status,
    'level': level,
    'checked_at': checkedAt == null
        ? null
        : checkedAt!.millisecondsSinceEpoch ~/ 1000,
    'version': version,
    'checks': checks,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProofVerificationSummary &&
        other.status == status &&
        other.level == level &&
        other.checkedAt == checkedAt &&
        other.version == version &&
        _nullableBoolMapEquals(other.checks, checks);
  }

  @override
  int get hashCode {
    final checkHashes =
        checks.entries
            .map((entry) => Object.hash(entry.key, entry.value))
            .toList()
          ..sort();
    return Object.hash(
      status,
      level,
      checkedAt,
      version,
      Object.hashAll(checkHashes),
    );
  }
}

bool _nullableBoolMapEquals(
  Map<String, bool?> first,
  Map<String, bool?> second,
) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

/// Represents a video event (NIP-71 compliant kinds 22, 34236)
@immutable
class VideoEvent {
  // approved, flagged, etc.

  /// Normalizes the free-text fields to well-formed UTF-16.
  ///
  /// Same display boundary as the `UserProfile` constructor: note content and
  /// titles arrive as remote relay text, and a lone surrogate anywhere in
  /// them throws `Invalid argument(s): string is not well-formed UTF-16` out
  /// of the native paragraph builder. The [displayContent] / [displayTitle]
  /// getters below still apply the combining-character cap for rendering,
  /// but they cannot be the crash boundary on their own because callers
  /// legitimately read the raw fields too — `VideoPerformance.fromVideo`
  /// renders `title` straight from the model, and measurement passes never
  /// reach a display getter at all.
  ///
  /// [content] and [altText] are round-tripped back to relays on the
  /// metadata-edit and subtitle-republish paths, so sanitizing them does
  /// rewrite what gets re-signed. That is deliberate: `Event._getId` runs
  /// `json.encode` before `utf8.encode`, and that escapes an unpaired
  /// surrogate as the six literal characters `\ud83d` rather than
  /// substituting for it, so what we re-sign today re-poisons every client
  /// that parses it back. The combining-character cap is a different case —
  /// it would rewrite valid text a user typed — and stays on the display
  /// getters for that reason.
  ///
  /// [hashtags] is sanitized element-wise for the same reason: `t` tag values
  /// are free-form relay text and every hashtag chip renders one verbatim.
  ///
  /// The remaining identifier, URL, and tag fields are left untouched — they
  /// are either hex (`id`, `pubkey`, `sha256`) or structural. [categories] is
  /// derived locally and is always empty for relay-sourced events.
  VideoEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required String content,
    required this.timestamp,
    this.eventCreatedAt,
    String? title,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.dimensions,
    this.mimeType,
    this.sha256,
    this.fileSize,
    List<String> hashtags = const [],
    this.categories = const [],
    this.publishedAt,
    this.rawTags = const {},
    this.vineId,
    this.addressableDTag,
    this.group,
    String? altText,
    this.blurhash,
    this.isRepost = false,
    this.reposterId,
    this.reposterPubkey,
    this.reposterPubkeys,
    this.repostedAt,
    this.isFlaggedContent = false,
    this.moderationStatus,
    this.originalLoops,
    this.originalLikes,
    this.originalComments,
    this.originalReposts,
    this.expirationTimestamp,
    this.audioEventId,
    this.audioEventRelay,
    this.nostrLikeCount,
    this.nostrCommentCount,
    this.nostrRepostCount,
    String? authorName,
    this.authorAvatar,
    this.collaboratorPubkeys = const [],
    this.inspiredByVideo,
    this.inspiredByNpub,
    this.inspiredByPubkeys = const [],
    this.clipSourceCredits = const [],
    this.nostrEventTags = const [],
    this.textTrackRef,
    this.textTrackRefs = const [],
    this.textTrackContent,
    this.contentWarningLabels = const [],
    this.moderationLabels = const [],
    this.warnLabels = const [],
    this.proofSummary,
    this.eventKind,
    this.sourceRelay,
  }) : content = sanitizeUtf16(content),
       title = sanitizeUtf16OrNull(title),
       altText = sanitizeUtf16OrNull(altText),
       authorName = sanitizeUtf16OrNull(authorName),
       hashtags = sanitizeUtf16List(hashtags);

  /// Reconstructs a [VideoEvent] from a map produced by [toJson].
  ///
  /// Inverse of [toJson], used to rehydrate cached feed snapshots.
  ///
  /// `moderationLabels` is persisted and restored because it is a hard
  /// content-filter "hide" signal — dropping it would let a moderated video
  /// slip through the content-preference filter on cold start when the user's
  /// preferences changed between sessions. The remaining omitted fields
  /// (`nostrEventTags`, `warnLabels`) fall back to their defaults: `warnLabels`
  /// is recomputed by the warning-labels resolver on read, and `nostrEventTags`
  /// is heavy republishing state the content-label path does not consult.
  factory VideoEvent.fromJson(Map<String, dynamic> json) {
    List<String> stringList(Object? value) =>
        (value as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        const [];
    int? optInt(Object? value) => (value as num?)?.toInt();
    DateTime? optDate(Object? value) =>
        value == null ? null : DateTime.parse(value as String);

    final createdAt = optInt(json['createdAt']) ?? 0;
    final timestamp = json['timestamp'];
    final textTrackRef = json['textTrackRef'] as String?;
    final textTrackRefs = stringList(json['textTrackRefs']);
    final rawTags =
        (json['rawTags'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value.toString()),
        ) ??
        const <String, String>{};
    final persistedAddressableDTag = json['addressableDTag'] as String?;
    final rawDTag = rawTags['d'];
    return VideoEvent(
      id: json['id'] as String? ?? '',
      pubkey: json['pubkey'] as String? ?? '',
      createdAt: createdAt,
      content: json['content'] as String? ?? '',
      timestamp: timestamp is String
          ? DateTime.parse(timestamp)
          : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true),
      title: json['title'] as String?,
      videoUrl: json['videoUrl'] as String?,
      thumbnailUrl: _usableThumbnailUrl(json['thumbnailUrl']),
      duration: optInt(json['duration']),
      dimensions: json['dimensions'] as String?,
      mimeType: json['mimeType'] as String?,
      sha256: json['sha256'] as String?,
      fileSize: optInt(json['fileSize']),
      hashtags: stringList(json['hashtags']),
      categories: stringList(json['categories']),
      eventCreatedAt: optInt(json['eventCreatedAt']),
      publishedAt: json['publishedAt'] as String?,
      rawTags: rawTags,
      vineId: json['vineId'] as String?,
      addressableDTag:
          persistedAddressableDTag != null &&
              persistedAddressableDTag.isNotEmpty
          ? persistedAddressableDTag
          : rawDTag != null && rawDTag.isNotEmpty
          ? rawDTag
          : null,
      group: json['group'] as String?,
      altText: json['altText'] as String?,
      blurhash: json['blurhash'] as String?,
      isRepost: json['isRepost'] as bool? ?? false,
      reposterId: json['reposterId'] as String?,
      reposterPubkey: json['reposterPubkey'] as String?,
      reposterPubkeys: json['reposterPubkeys'] == null
          ? null
          : stringList(json['reposterPubkeys']),
      repostedAt: optDate(json['repostedAt']),
      isFlaggedContent: json['isFlaggedContent'] as bool? ?? false,
      moderationStatus: json['moderationStatus'] as String?,
      originalLoops: optInt(json['originalLoops']),
      originalLikes: optInt(json['originalLikes']),
      originalComments: optInt(json['originalComments']),
      originalReposts: optInt(json['originalReposts']),
      expirationTimestamp: optInt(json['expirationTimestamp']),
      audioEventId: json['audioEventId'] as String?,
      audioEventRelay: json['audioEventRelay'] as String?,
      nostrLikeCount: optInt(json['nostrLikeCount']),
      nostrCommentCount: optInt(json['nostrCommentCount']),
      nostrRepostCount: optInt(json['nostrRepostCount']),
      authorName: json['authorName'] as String?,
      authorAvatar: json['authorAvatar'] as String?,
      collaboratorPubkeys: stringList(json['collaboratorPubkeys']),
      inspiredByVideo: json['inspiredByVideo'] == null
          ? null
          : InspiredByInfo.fromJson(
              json['inspiredByVideo'] as Map<String, dynamic>,
            ),
      inspiredByNpub: json['inspiredByNpub'] as String?,
      inspiredByPubkeys:
          (json['inspiredByPubkeys'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
      clipSourceCredits: ClipSourceCredit.listFromJson(
        json['clipSourceCredits'],
      ),
      textTrackRef: textTrackRef,
      textTrackRefs: textTrackRefs.isNotEmpty
          ? textTrackRefs
          : [if (textTrackRef != null && textTrackRef.isNotEmpty) textTrackRef],
      textTrackContent: json['textTrackContent'] as String?,
      contentWarningLabels: stringList(json['contentWarningLabels']),
      moderationLabels: stringList(json['moderationLabels']),
      eventKind: optInt(json['eventKind']),
      sourceRelay: json['sourceRelay'] as String?,
      proofSummary: json['proofSummary'] == null
          ? null
          : ProofVerificationSummary.fromJson(
              json['proofSummary'] as Map<String, dynamic>,
            ),
    );
  }

  /// Create VideoEvent from Nostr event
  ///
  /// [permissive] - When true, accepts all NIP-71 video kinds (21, 22, 34235,
  /// 34236) instead of just kind 34236. Use this when parsing videos from
  /// external sources like curated lists created by other clients.
  factory VideoEvent.fromNostrEvent(Event event, {bool permissive = false}) {
    final isValid = permissive
        ? NIP71VideoKinds.isAcceptableVideoKind(event.kind)
        : NIP71VideoKinds.isVideoKind(event.kind);

    if (!isValid) {
      final acceptedKinds = permissive
          ? NIP71VideoKinds.getAllAcceptableVideoKinds()
          : NIP71VideoKinds.getAllVideoKinds();
      throw ArgumentError(
        'Event must be a NIP-71 video kind (${acceptedKinds.join(', ')})',
      );
    }

    final rawTags = <String, String>{};
    final hashtags = <String>[];
    final videoUrlCandidates = <String>[]; // Collect all video URL candidates
    String? videoUrl;
    String? thumbnailUrl;
    String? title;
    int? duration;
    String? dimensions;
    String? mimeType;
    String? sha256;
    int? fileSize;
    String? publishedAt;
    String? vineId;
    String? group;
    String? altText;
    String? blurhash;
    int? originalLoops;
    int? originalLikes;
    int? originalComments;
    int? originalReposts;
    int? expirationTimestamp;
    String? audioEventId;
    String? audioEventRelay;
    String? sourceRelay;
    String? addressableDTag;
    final collaboratorPubkeys = <String>[];
    InspiredByInfo? inspiredByVideo;
    final inspiredByPubkeys = <String>[];
    final clipSourceCredits = <ClipSourceCredit>[];
    final textTrackRefsLocal = <String>[];
    final contentWarningLabels = <String>[];

    // Parse event tags according to NIP-71
    // Handle both List<String> and List<dynamic>
    // from different nostr implementations
    for (var i = 0; i < event.tags.length; i++) {
      final tagRaw = event.tags[i];
      if ((tagRaw as List).isEmpty) continue;

      // Convert List<dynamic> to List<String> safely
      final tag = tagRaw.map((e) => e).toList();

      final tagName = tag[0];
      final tagValue = (tag.length > 1) ? tag[1] : '';

      switch (tagName) {
        case 'url':
          // Check if this is a valid video URL
          if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(VideoUrlResolver.fixOpenvineTypo(tagValue));
          }
        case 'streaming':
          // Handle streaming tag with HLS/DASH URLs
          // Format: ["streaming", "url", "format"] e.g., ["streaming", "https://cdn.divine.video/.../video.m3u8", "hls"]
          if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
          }
        case 'imeta':
          // Parse imeta tag which contains comma-separated metadata
          // Ensure we have a List<String> for the parser
          final iMetaTag = List<String>.from(tag);
          parseImetaTag(iMetaTag, (key, value) {
            switch (key) {
              case 'url':
                // Check if this is a valid video URL and add to candidates
                if (value.isNotEmpty &&
                    VideoUrlResolver.isValidVideoUrl(value)) {
                  videoUrlCandidates.add(
                    VideoUrlResolver.fixOpenvineTypo(value),
                  );
                }
              // POSTEL'S LAW: Accept various video URL keys that
              // different clients may use
              case 'hls':
              case 'dash':
              case 'stream':
              case 'streaming':
              case 'fallback':
              case 'mp4':
              case 'video':
                // Alternative video URL keys - add as candidates if valid
                if (value.isNotEmpty &&
                    VideoUrlResolver.isValidVideoUrl(value)) {
                  videoUrlCandidates.add(value);
                }
              case 'm':
                mimeType ??= value;
              case 'x':
                sha256 ??= value;
              case 'size':
                fileSize ??= int.tryParse(value);
              case 'dim':
                dimensions ??= value;
              case 'thumb':
                final thumbnail = _usableThumbnailUrl(value);
                if (thumbnail != null) {
                  thumbnailUrl ??= thumbnail;
                }
              case 'image':
                // NIP-92 uses 'image' for thumbnail in imeta
                final thumbnail = _usableThumbnailUrl(value);
                if (thumbnail != null) {
                  thumbnailUrl ??= thumbnail;
                }
              case 'blurhash':
                // Blurhash for progressive loading
                blurhash ??= value;
              case 'duration':
                final parsedDuration = double.tryParse(value);
                if (parsedDuration != null && parsedDuration.isFinite) {
                  duration ??= parsedDuration.round();
                }
            }
          });
        case 'title':
          title = tagValue as String?;
        case 'published_at':
          publishedAt = tagValue as String?;
        case 'duration':
          duration = int.tryParse(tagValue);
        case 'dim':
          dimensions = tagValue as String?;
        case 'm':
          mimeType = tagValue as String?;
        case 'x':
          sha256 = tagValue as String?;
        case 'size':
          fileSize = int.tryParse(tagValue);
        case 'thumb':
          // Thumbnail URL - prefer static thumbnails for grid display
          final thumbnail = _usableThumbnailUrl(tagValue);
          if (thumbnail != null) {
            thumbnailUrl = thumbnail;
          }
        case 'preview':
          // Animated GIF preview - store separately, don't use as main
          // thumbnail. GIFs auto-play and would make the grid look chaotic.
          // We could use this for hover effects or preview on long-press.
          if (tagValue.isNotEmpty && tagValue.endsWith('.gif')) {
            // Store in tags for potential future use
            rawTags['preview_gif'] = tagValue;
          }
        case 'image':
          // Alternative to 'thumb' tag - some clients use 'image' instead
          final thumbnail = _usableThumbnailUrl(tagValue);
          if (thumbnail != null) {
            thumbnailUrl ??= thumbnail;
          }
        case 'd':
          // Replaceable event ID - original vine ID
          vineId = tagValue as String?;
          addressableDTag = tagValue as String?;
        case 'vine_id':
          // Some clients use 'vine_id' instead of 'd' for the original Vine ID
          vineId ??= tagValue as String?;
        case 'h':
          // Group/community tag
          group = tagValue as String?;
        case 'alt':
          // Accessibility text
          altText = tagValue as String?;
        case 'blurhash':
          // Blurhash for progressive image loading
          blurhash = tagValue as String?;
        case 'loops':
          // Original loop count from classic Vine
          originalLoops = int.tryParse(tagValue);
        case 'likes':
          // Original like count from classic Vine
          originalLikes = int.tryParse(tagValue);
        case 'comments':
          // Original comment count from classic Vine
          originalComments = int.tryParse(tagValue);
        case 'reposts':
          // Original repost count from classic Vine
          originalReposts = int.tryParse(tagValue);
        case 'expiration':
          // NIP-40 expiration timestamp (Unix timestamp in seconds)
          expirationTimestamp = int.tryParse(tagValue);
        case 't':
          if (tagValue.isNotEmpty) {
            hashtags.add(tagValue);
          }
        case 'r':
          // NIP-25 reference - might contain media URLs. Also handle "r" tags
          // with type annotation (e.g., ["r", "url", "video"])
          if (tagValue.startsWith('wss://') || tagValue.startsWith('ws://')) {
            // Relay hint for this event; keep the first one seen.
            sourceRelay ??= tagValue;
          } else if (tag.length >= 3) {
            final url = tagValue;
            final type = tag[2];

            if (type == 'video' &&
                url.isNotEmpty &&
                VideoUrlResolver.isValidVideoUrl(url)) {
              videoUrl ??= url;
            } else if (type == 'thumbnail' &&
                _usableThumbnailUrl(url) != null &&
                !url.contains('picsum.photos')) {
              thumbnailUrl ??= url;
            }
          } else if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            // Fallback: if no type annotation, treat as video URL
            videoUrlCandidates.add(tagValue);
          }
        case 'e':
          // Event reference - check for audio reference marker
          // Format: ["e", "<audio-event-id>", "<relay>", "audio"]
          // The marker can be at index 2 (no relay) or index 3 (with relay)
          // Also recognize bundled sound IDs (prefixed "bundled_") even
          // without the "audio" marker for backward compatibility.
          // Only use the first audio reference found
          if (audioEventId == null && tagValue.isNotEmpty) {
            if (tag.length >= 3) {
              final marker = tag.length >= 4 ? tag[3] : tag[2];
              if (marker == 'audio') {
                audioEventId = tagValue;
                if (tag.length >= 4 && tag[2].isNotEmpty) {
                  audioEventRelay = tag[2];
                }
              }
            }
            // Bundled sounds may lack the "audio" marker
            if (audioEventId == null && tagValue.startsWith('bundled_')) {
              audioEventId = tagValue;
              if (tag.length >= 3 && tag[2].isNotEmpty) {
                audioEventRelay = tag[2];
              }
            }
          }
          // Also check if it's a media URL in disguise (legacy behavior)
          if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
          }
        case 'i':
          // External identity - sometimes used for media
          if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
          }
        case 'p':
          // Divine collaborator p-tag convention on NIP-71 video events:
          // ["p", "<pubkey>", "<relay>", "collaborator"]
          final normalizedPubkey = tagValue.toLowerCase();
          final normalizedAuthorPubkey = event.pubkey.toLowerCase();
          if (normalizedPubkey.isNotEmpty &&
              normalizedPubkey != normalizedAuthorPubkey) {
            final role = tag.length >= 4 ? tag[3].toLowerCase() : null;
            if (role == 'collaborator' &&
                !collaboratorPubkeys.contains(normalizedPubkey)) {
              collaboratorPubkeys.add(normalizedPubkey);
            } else if (role == inspiredByPTagMarker) {
              if (!inspiredByPubkeys.contains(normalizedPubkey)) {
                inspiredByPubkeys.add(normalizedPubkey);
              }
            } else if (role == clipSourceCreditTagMarker) {
              _addClipSourceCredit(
                clipSourceCredits,
                ClipSourceCredit(
                  authorPubkey: normalizedPubkey,
                  relayUrl: tag.length >= 3 && tag[2].isNotEmpty
                      ? tag[2]
                      : null,
                ),
              );
            }
          }
        case 'a':
          // NIP-33 addressable event reference
          // Format: ['a', '34236:<pubkey>:<d-tag>', '<relay>', 'mention']
          if (tagValue.isNotEmpty && tagValue.startsWith('34236:')) {
            final relayHint = tag.length > 2 ? tag[2] : null;
            final relayUrl = relayHint != null && relayHint.isNotEmpty
                ? relayHint
                : null;
            final marker = tag.length >= 4 ? tag[3].toLowerCase() : null;
            if (marker == clipSourceCreditTagMarker) {
              _addClipSourceCredit(
                clipSourceCredits,
                ClipSourceCredit.fromAddressableId(
                  addressableId: tagValue,
                  relayUrl: relayUrl,
                ),
              );
            } else {
              inspiredByVideo ??= InspiredByInfo(
                addressableId: tagValue,
                relayUrl: relayUrl,
              );
            }
          }
        case 'content-warning':
          // NIP-36 content-warning tag
          // Format: ['content-warning', '<reason>']
          if (tagValue.isNotEmpty && !contentWarningLabels.contains(tagValue)) {
            contentWarningLabels.add(tagValue);
          }
        case 'l':
          // NIP-32 label tag — only collect content-warning namespace
          // Format: ['l', '<label>', 'content-warning']
          if (tag.length >= 3 &&
              tag[2] == 'content-warning' &&
              tagValue.isNotEmpty &&
              !contentWarningLabels.contains(tagValue)) {
            contentWarningLabels.add(tagValue);
          }
        case 'text-track':
          // Subtitle/caption track reference
          // Format: ['text-track', '<coords-or-url>', '<relay>', 'captions',
          //          '<lang>']
          if (tagValue.isNotEmpty) {
            textTrackRefsLocal.add(tagValue);
          }
        default:
          // POSTEL'S LAW: Check if any unknown tag contains a valid video URL
          if (tagValue.isNotEmpty &&
              VideoUrlResolver.isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
          }
      }

      // Store all tags for potential future use
      rawTags[tagName] = tagValue;
    }

    // Resolve the Inspired By person from the trailing NIP-27 attribution
    // line the publisher appends ("Inspired by nostr:npub1..."). Anchored to
    // the end of content and to a preceding blank line (or start of content,
    // for empty-caption publishes) so a prose nostr:npub mention is never
    // mistaken for attribution. Keep in sync with the strip regex in
    // video_editor_provider.dart.
    String? inspiredByNpub;
    final npubPattern = RegExp(
      r'(?:^|\n\n)Inspired by nostr:(npub1[a-z0-9]+)\s*$',
    );
    final npubMatch = npubPattern.firstMatch(event.content);
    if (npubMatch != null) {
      inspiredByNpub = npubMatch.group(1);
    }

    final createdAtTimestamp = event.createdAt is DateTime
        ? (event.createdAt as DateTime).millisecondsSinceEpoch ~/ 1000
        : int.tryParse(event.createdAt.toString()) ?? 0;

    final publishedAtTimestamp = int.tryParse(publishedAt ?? '');
    final effectiveTimestamp = publishedAtTimestamp ?? createdAtTimestamp;

    // POSTEL'S LAW: Be liberal in what you accept
    // Apply comprehensive fallback logic to find video URLs
    if (videoUrl == null || videoUrl.isEmpty) {
      videoUrl = VideoUrlResolver.extractVideoUrlFromContent(event.content);
    }

    // Select best video URL from all candidates
    if (videoUrlCandidates.isNotEmpty) {
      videoUrl = VideoUrlResolver.selectBestVideoUrl(videoUrlCandidates);
    } else {
      // If no candidates found, use the old fallback method
      videoUrl = VideoUrlResolver.findAnyVideoUrlInTags(event.tags);
    }

    // Note: Removed Classic Vine hardening that was forcing api.openvine.co
    // URLs. The URL selection logic above now properly handles cdn.divine.video
    // URLs from imeta tags.

    // If we still have a broken apt.openvine.co URL, fix it
    if (videoUrl?.contains('apt.openvine.co') ?? false) {
      videoUrl = VideoUrlResolver.fixOpenvineTypo(videoUrl!);
    }

    // Use 'd' tag if available, otherwise fallback to event ID
    // Many relays don't include 'd' tags on NIP-71 addressable events
    if (vineId == null || vineId.isEmpty) {
      vineId = event.id; // Use event ID as unique identifier
    }

    if (sourceRelay == null) {
      for (final source in event.sources) {
        final trimmed = source.trim();
        if (trimmed.isNotEmpty) {
          sourceRelay = trimmed;
          break;
        }
      }
    }

    return VideoEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: effectiveTimestamp,
      content: event.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        effectiveTimestamp * 1000,
        isUtc: true,
      ),
      title: title,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      dimensions: dimensions,
      mimeType: mimeType,
      sha256: sha256,
      fileSize: fileSize,
      hashtags: hashtags,
      eventCreatedAt: createdAtTimestamp,
      publishedAt: publishedAt,
      rawTags: rawTags,
      vineId: vineId,
      addressableDTag: addressableDTag != null && addressableDTag.isNotEmpty
          ? addressableDTag
          : null,
      group: group,
      altText: altText,
      blurhash: blurhash,
      originalLoops: originalLoops,
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      expirationTimestamp: expirationTimestamp,
      audioEventId: audioEventId,
      audioEventRelay: audioEventRelay,
      collaboratorPubkeys: collaboratorPubkeys,
      inspiredByVideo: inspiredByVideo,
      inspiredByNpub: inspiredByNpub,
      inspiredByPubkeys: inspiredByPubkeys,
      clipSourceCredits: clipSourceCredits,
      nostrEventTags: event.tags
          .map((t) => (t as List).map((e) => e.toString()).toList())
          .toList(),
      textTrackRef: textTrackRefsLocal.isNotEmpty
          ? textTrackRefsLocal.first
          : null,
      textTrackRefs: textTrackRefsLocal,
      contentWarningLabels: contentWarningLabels,
      eventKind: event.kind,
      sourceRelay: sourceRelay,
    );
  }

  static void _addClipSourceCredit(
    List<ClipSourceCredit> credits,
    ClipSourceCredit credit,
  ) {
    if (credit.authorPubkey.isEmpty) return;
    final authorPubkey = credit.authorPubkey.toLowerCase();
    if (!credit.hasAddressableSource &&
        credits.any(
          (existing) =>
              existing.hasAddressableSource &&
              existing.authorPubkey.toLowerCase() == authorPubkey,
        )) {
      return;
    }
    if (credit.hasAddressableSource) {
      credits.removeWhere(
        (existing) =>
            !existing.hasAddressableSource &&
            existing.authorPubkey.toLowerCase() == authorPubkey,
      );
    }
    if (credits.any((existing) => existing.identityKey == credit.identityKey)) {
      return;
    }
    credits.add(credit);
  }

  final String id;
  final String pubkey;
  final int createdAt;

  /// The Nostr event's own `created_at`, in seconds.
  ///
  /// Null when this instance was not built from a relay event; prefer
  /// [nostrCreatedAt], which falls back to [createdAt].
  final int? eventCreatedAt;

  final String content;
  final String? title;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? duration; // in seconds
  final String? dimensions; // WIDTHxHEIGHT
  final String? mimeType;
  final String? sha256;
  final int? fileSize;
  final List<String> hashtags;

  /// VLM-classified category names from Funnelcake (e.g., "animals", "music").
  ///
  // TODO(api): Populate from Funnelcake once the API returns per-video
  // categories. Currently always empty for relay-sourced events.
  final List<String> categories;

  final DateTime timestamp;
  final String? publishedAt;
  final Map<String, String> rawTags;

  // Vine-specific fields from NIP-71 spec
  final String? vineId; // 'd' tag - original vine ID for replaceable events

  /// The real NIP-33 `d` tag value carried by this event.
  ///
  /// Null when the source event or REST row had no non-empty `d` tag. Unlike
  /// [vineId], this is never filled from `vine_id` and never falls back to the
  /// event id, so protocol coordinate builders can distinguish a missing `d`.
  final String? addressableDTag;

  final String? group; // 'h' tag - group/community identification
  final String? altText; // 'alt' tag - accessibility text
  final String? blurhash; // 'blurhash' tag - for progressive image loading

  /// The NIP-71 event kind this video was parsed from (22, 34236, …).
  ///
  /// Preserved so consumers (e.g. building a NIP-18 `q` citation in a DM) can
  /// distinguish an addressable event (`naddr`/coordinate) from a regular one
  /// (`nevent`/id). Null for events rehydrated from pre-migration caches; use
  /// [shareKind] for a safe value.
  final int? eventKind;

  /// A relay hint (`wss://`/`ws://`) where this event was advertised or
  /// received. Prefers an `r` tag when present, then falls back to SDK
  /// receive-source metadata. Used as a relay hint when citing the video.
  final String? sourceRelay;

  // Repost metadata fields
  final bool isRepost;
  final String? reposterId;
  final String? reposterPubkey; // Singular for backward compatibility
  final List<String>? reposterPubkeys; // Plural for multiple reposters
  final DateTime? repostedAt;

  // Content moderation fields
  final bool
  isFlaggedContent; // Content flagged as potentially adult/inappropriate
  final String? moderationStatus;

  // Original Vine metrics (from imported data)
  final int? originalLoops; // Original loop count from classic Vine
  final int? originalLikes; // Original like count from classic Vine
  final int? originalComments; // Original comment count from classic Vine
  final int? originalReposts; // Original repost count from classic Vine
  // NIP-40 expiration timestamp (Unix timestamp in seconds)
  final int? expirationTimestamp;

  // Audio reference fields (Kind 1063 audio events)
  /// Event ID of referenced audio track (Kind 1063)
  final String? audioEventId;

  /// Optional relay hint for fetching the audio event
  final String? audioEventRelay;

  // Live engagement metrics from Nostr
  /// Live like/reaction count from Nostr (updated in real-time)
  final int? nostrLikeCount;

  /// Live comment/reply count from Nostr/Funnelcake.
  final int? nostrCommentCount;

  /// Live repost count from Nostr/Funnelcake.
  final int? nostrRepostCount;

  // Author metadata from API (classic Vines)
  /// Author display name (from Funnelcake API for classic Viners)
  final String? authorName;

  /// Author avatar URL (from Funnelcake API for classic Viners)
  final String? authorAvatar;

  // Attribution fields (collaborators and Inspired By)
  /// Pubkeys of collaborators from Divine's collaborator-marked `p` tags.
  final List<String> collaboratorPubkeys;

  /// Reference to the video that inspired this one (a-tag with 34236: prefix).
  final InspiredByInfo? inspiredByVideo;

  /// NIP-27 npub reference in content
  /// (Inspired By a person, not a specific video).
  final String? inspiredByNpub;

  /// Every creator credited by an `inspired-by`-marked `p` tag.
  ///
  /// The NIP-27 content line names only the first, for clients that render
  /// inline references; these tags carry the whole set and are what makes
  /// more than one creator creditable.
  final List<String> inspiredByPubkeys;

  /// Factual credits for clips reused from published videos.
  final List<ClipSourceCredit> clipSourceCredits;

  /// Original event tags as `List<List<String>>` for republishing.
  /// Preserved from the Nostr event so we can rebuild the event with new tags.
  final List<List<String>> nostrEventTags;

  /// Addressable coordinates or URL for text-track subtitle reference.
  /// Format: `39307:<pubkey>:subtitles:<video-d-tag>` or HTTP URL.
  final String? textTrackRef;

  /// All `text-track` references in tag order, for read-time fallback.
  /// `textTrackRef` mirrors the first entry for back-compat.
  final List<String> textTrackRefs;

  /// Embedded VTT content from funnelcake REST API (skips relay fetch).
  final String? textTrackContent;

  /// NIP-32 content-warning self-labels on this video.
  ///
  /// Parsed from `["l", "<label>", "content-warning"]` tags and
  /// `["content-warning", "<reason>"]` tags. Empty if no warnings.
  final List<String> contentWarningLabels;

  /// ML-generated moderation labels from Funnelcake's classifier.
  ///
  /// These are separate from [contentWarningLabels] (author self-labels)
  /// because ML labels are noisy and should only trigger "hide" filtering,
  /// not "warn" blur overlays that block autoplay.
  final List<String> moderationLabels;

  /// Content warning labels that triggered the "warn" filter preference.
  ///
  /// Set during feed processing based on user's per-category filter settings.
  /// When non-empty, the video should be shown with a blur overlay.
  final List<String> warnLabels;

  /// Compact proof verification summary returned by Funnelcake REST feeds.
  final ProofVerificationSummary? proofSummary;

  /// Generic `p` tags that mark users mentioned by this video.
  ///
  /// Collaborator `p` tags are intentionally excluded; those are rendered by
  /// [collaboratorPubkeys] and have separate confirmation semantics.
  List<String> get mentionedPubkeys {
    final seen = <String>{};
    final pubkeys = <String>[];

    for (final tag in nostrEventTags) {
      if (tag.length < 4 || tag[0] != 'p') continue;
      if (tag[3].toLowerCase() != 'mention') continue;

      final pubkey = tag[1].trim().toLowerCase();
      if (pubkey.isEmpty || pubkey == this.pubkey.toLowerCase()) continue;
      if (!seen.add(pubkey)) continue;

      pubkeys.add(pubkey);
    }

    return pubkeys;
  }

  /// Whether the creator marked this video's audio as reusable.
  ///
  /// Reads the editor-owned `allow_audio_reuse` marker. Prefers
  /// [nostrEventTags] but falls back to [rawTags], so the flag survives a
  /// JSON-cache round-trip — [nostrEventTags] is intentionally not persisted
  /// through `toJson`/`fromJson`, but [rawTags] is, which keeps the edit form
  /// from seeding the toggle `false` on a cache-rehydrated video.
  bool get allowAudioReuse =>
      _firstNostrTagValue('allow_audio_reuse') == 'true';

  /// Whether this video has any content warnings.
  bool get hasContentWarning => contentWarningLabels.isNotEmpty;

  /// Whether this video should show a content warning overlay.
  bool get shouldShowWarning => warnLabels.isNotEmpty;

  /// Whether this video has subtitle/caption data available.
  ///
  /// Returns true if any subtitle source exists: embedded VTT content,
  /// a text-track reference (Kind 39307), or a sha256 hash (Blossom server
  /// auto-generates VTT at `{server}/{sha256}/vtt`).
  bool get hasSubtitles =>
      (textTrackRef != null && textTrackRef!.isNotEmpty) ||
      (textTrackContent != null && textTrackContent!.isNotEmpty) ||
      (sha256 != null && sha256!.isNotEmpty);

  /// Whether this video has collaborators.
  bool get hasCollaborators => collaboratorPubkeys.isNotEmpty;

  /// Whether this video has any Inspired By attribution.
  ///
  /// NIP-22 video replies also carry lowercase parent tags. Those are reply
  /// metadata, not creator attribution, so reply videos should render their
  /// parent context instead of the Inspired By treatment.
  bool get hasInspiredBy =>
      !isVideoReply &&
      (inspiredByVideo != null ||
          inspiredByNpub != null ||
          inspiredByPubkeys.isNotEmpty ||
          clipSourceCredits.isNotEmpty);

  /// Hex pubkey of the primary inspiring creator, resolved from explicit
  /// inspired-by metadata first and factual clip-source credits second.
  ///
  /// Returns `null` when there is no inspired-by attribution or the npub
  /// cannot be decoded.
  String? get inspiredByCreatorPubkey {
    if (isVideoReply) return null;
    if (inspiredByVideo != null) return inspiredByVideo!.creatorPubkey;
    if (inspiredByNpub != null) {
      final hex = Nip19.decode(inspiredByNpub!);
      if (hex.isNotEmpty) return hex;
    }
    if (inspiredByPubkeys.isNotEmpty) {
      return inspiredByPubkeys.first;
    }
    if (clipSourceCredits.isNotEmpty) {
      return clipSourceCredits.first.authorPubkey;
    }
    return null;
  }

  /// NIP-40: Check if this event has expired
  /// Returns true if expiration timestamp is set and current time >= expiration
  bool get isExpired {
    if (expirationTimestamp == null) return false;
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowTimestamp >= expirationTimestamp!;
  }

  /// Stable identifier for this video event.
  /// For addressable events (Kind 34236), returns the vineId (d tag).
  /// Falls back to event id for non-addressable events.
  String get stableId => vineId ?? id;

  /// The timestamp a NIP-09 deletion bound must be measured against:
  /// [eventCreatedAt] when known, else [createdAt].
  ///
  /// [createdAt] prefers the `published_at` tag, and an edit re-emits the
  /// original publication's value while minting a new event under the same
  /// `d` tag. Comparing that against a deletion request would treat a
  /// republished clip as older than the deletion and hide it for good.
  int get nostrCreatedAt => eventCreatedAt ?? createdAt;

  /// Best-effort NIP-71 kind for citing this video.
  ///
  /// Returns [eventKind] when known; otherwise infers from addressability —
  /// a present `d` tag implies the addressable short-video kind (34236), and
  /// its absence implies the regular short-video kind (22).
  int get shareKind =>
      eventKind ??
      (vineId != null
          ? NIP71VideoKinds.addressableShortVideo
          : NIP71VideoKinds.shortVideo);

  /// Whether this video is an addressable event (referenced by coordinate).
  bool get isAddressableShareKind =>
      shareKind == NIP71VideoKinds.addressableShortVideo ||
      shareKind == NIP71VideoKinds.addressableNormalVideo;

  /// Display-sanitized video content (zalgo caps, well-formed UTF-16).
  String get displayContent => sanitizeForDisplay(content);

  /// Display-sanitized video title. Returns `null` when no title is set.
  String? get displayTitle => title != null ? sanitizeForDisplay(title!) : null;

  /// Zalgo-safe embedded author name for display.
  ///
  /// Returns `null` when no embedded author name is set. Profile display-name
  /// getters have their own sanitizer path.
  String? get displayAuthorName =>
      authorName != null ? sanitizeForDisplay(authorName!) : null;

  /// Root event id from an uppercase NIP-22 reply tag.
  ///
  /// Lowercase reply tags describe nearest-parent threading and mentions.
  /// Uppercase tags are the root reference, which is what the app needs for
  /// showing video replies in feeds and linking back to the original video.
  String? get replyRootEventId => _firstNostrTagValue('E');

  /// Root addressable id from an uppercase NIP-22 reply tag.
  ///
  /// Returns only NIP-71 video address tags so arbitrary non-video replies do
  /// not get treated as video replies by feed or comment UI.
  String? get replyRootAddressableId {
    final addressableId = _firstNostrTagValue('A');
    if (addressableId == null) return null;

    final kind = _kindFromAddressableId(addressableId);
    if (kind == null || !NIP71VideoKinds.isAcceptableVideoKind(kind)) {
      return null;
    }

    return addressableId;
  }

  /// Root Nostr kind from an uppercase NIP-22 reply tag.
  int? get replyRootKind {
    final explicitKind = int.tryParse(_firstNostrTagValue('K') ?? '');
    if (explicitKind != null) {
      return NIP71VideoKinds.isAcceptableVideoKind(explicitKind)
          ? explicitKind
          : null;
    }

    final addressableId = replyRootAddressableId;
    return addressableId == null ? null : _kindFromAddressableId(addressableId);
  }

  /// Whether this NIP-71 video is a reply to another NIP-71 video.
  bool get isVideoReply {
    final hasRootReference =
        replyRootEventId != null || replyRootAddressableId != null;
    if (!hasRootReference) return false;

    final kind = replyRootKind;
    return kind != null && NIP71VideoKinds.isAcceptableVideoKind(kind);
  }

  /// Best route id for opening the root video this event replies to.
  ///
  /// Addressable ids are preferred because kind 34236 videos are addressable
  /// events and the route can fetch them even after replacement.
  String? get replyRootRouteId {
    if (!isVideoReply) return null;
    return replyRootAddressableId ?? replyRootEventId;
  }

  /// Total likes combining original Vine likes and live Nostr reactions.
  int get totalLikes => (originalLikes ?? 0) + (nostrLikeCount ?? 0);

  /// Total loops combining archived Vine loops and live diVine views.
  int get totalLoops =>
      (originalLoops ?? 0) + (int.tryParse(rawTags['views'] ?? '') ?? 0);

  /// Whether this video carries any loop-count metadata.
  ///
  /// Used by the fullscreen player to decide whether to render
  /// `"$totalLoops loops"` or fall back to relative time. Returns true when
  /// any of the three loop-related fields is present, even when the
  /// derived [totalLoops] is zero (a deliberate `0` count is still
  /// metadata).
  bool get hasLoopMetadata =>
      originalLoops != null ||
      rawTags.containsKey('loops') ||
      rawTags.containsKey('views');

  /// Whether this video carries any archival Vine-era engagement metrics.
  ///
  /// Used by the metadata sheet to decide whether to show the per-source
  /// (Vine vs Divine) engagement breakdown for classic Vines.
  bool get hasOriginalVineMetrics =>
      originalLoops != null ||
      originalLikes != null ||
      originalComments != null ||
      originalReposts != null;

  /// Returns true if this video has an audio reference (Kind 1063).
  bool get hasAudioReference => audioEventId != null;

  /// ProofMode: Get verification level from tags (NIP-145)
  String? get proofModeVerificationLevel {
    final rawLevel = rawTags['verification'];
    if (rawLevel != null && rawLevel.isNotEmpty) return rawLevel;
    if (proofSummary?.isVerified != true) return null;
    final summaryLevel = proofSummary?.level;
    return summaryLevel != null && summaryLevel.isNotEmpty
        ? summaryLevel
        : null;
  }

  /// ProofMode: Get proof manifest from tags (NIP-145)
  String? get proofModeManifest {
    final rawManifest = rawTags['proofmode'];
    if (rawManifest != null && rawManifest.isNotEmpty) return rawManifest;
    return null;
  }

  /// ProofMode: Get device attestation from tags (NIP-145)
  String? get proofModeDeviceAttestation {
    final rawAttestation = rawTags['device_attestation'];
    if (rawAttestation != null && rawAttestation.isNotEmpty) {
      return rawAttestation;
    }
    return null;
  }

  /// ProofMode: Get PGP signature from the embedded `proofmode` manifest.
  ///
  /// Reads `pgpSignature` from the JSON payload of the `proofmode` tag.
  /// The standalone `pgp_fingerprint` tag is only published when the
  /// publisher could derive a fingerprint from a stored public key —
  /// the manifest's `pgpSignature` field is the load-bearing signal that
  /// the video was actually PGP-signed.
  String? get proofModePgpFingerprint {
    final signature = proofModeManifestJson?['pgpSignature'];
    if (signature is String && signature.isNotEmpty) return signature;
    return null;
  }

  /// ProofMode: Get C2PA Manifest Id
  String? get proofModeC2paManifestId {
    final rawManifestId = rawTags['c2pa_manifest_id'];
    if (rawManifestId != null && rawManifestId.isNotEmpty) {
      return rawManifestId;
    }
    return null;
  }

  /// Parsed `proofmode` tag manifest, or `null` when the tag is missing or
  /// not a JSON object.
  ///
  /// The `proofmode` Nostr tag carries the full `NativeProofData` JSON, so
  /// it is the source of truth for proof signals (`pgpSignature`,
  /// `sensorDataCsv`, `deviceAttestation`, `c2paManifestId`) that the
  /// publisher may not have additionally surfaced as standalone tags.
  Map<String, dynamic>? get proofModeManifestJson {
    final manifest = proofModeManifest;
    if (manifest == null || manifest.isEmpty) return null;
    try {
      final decoded = jsonDecode(manifest);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// User-signed creator binding hint emitted alongside ProofMode metadata.
  bool get hasCreatorIdentityBinding {
    return rawTags['identity_binding'] == 'nostr_creator';
  }

  /// Optional verifier that issued a portable CAWG identity overlay.
  String? get identityVerifier {
    return rawTags['identity_verifier'];
  }

  /// Whether this video advertises a portable CAWG identity overlay.
  bool get hasPortableIdentity {
    return rawTags['identity_portable'] == 'cawg';
  }

  /// Field names inside a `proofmode` manifest JSON that represent an actual
  /// proof signal. A manifest that carries none of these (e.g. only a
  /// `videoHash`) is an empty `unverified` shell, not proof.
  static const _proofManifestSignalFields = <String>[
    'pgpSignature',
    'deviceAttestation',
    'c2paManifestId',
    'sensorDataCsv',
  ];

  /// Whether this video has any ProofMode manifest signal, either as a raw tag
  /// or as a compact backend summary.
  ///
  /// The publisher writes a `proofmode` tag unconditionally — even for an
  /// `unverified` upload whose manifest holds only a `videoHash` — so the raw
  /// branch inspects the manifest *content* rather than mere tag presence. A
  /// manifest that parses to JSON without any proof field is not a signal; an
  /// opaque (non-JSON) value is kept as a signal so older or third-party
  /// manifests are not silently dropped.
  bool get hasProofModeManifest {
    return _rawProofModeManifestCarriesProof ||
        proofSummary?.hasUsableProofmode == true;
  }

  bool get _rawProofModeManifestCarriesProof {
    final rawManifest = proofModeManifest;
    if (rawManifest == null) return false;
    final Object? decoded;
    try {
      decoded = jsonDecode(rawManifest);
    } on FormatException {
      return true;
    }
    if (decoded is! Map<String, dynamic>) return false;
    final manifest = decoded;
    return _proofManifestSignalFields.any((field) {
      final value = manifest[field];
      return value is String && value.isNotEmpty;
    });
  }

  /// Whether this video has any device-attestation signal, either as a raw tag
  /// or as a compact backend summary.
  bool get hasProofModeDeviceAttestation {
    return proofModeDeviceAttestation != null ||
        proofSummary?.hasUsableDeviceAttestation == true;
  }

  /// Whether this video has any PGP-signature signal, either as a raw manifest
  /// or as a compact backend summary.
  bool get hasProofModePgpFingerprint {
    return proofModePgpFingerprint != null ||
        proofSummary?.hasUsablePgpSignature == true;
  }

  /// Whether this video has any C2PA-manifest signal, either as a raw tag or
  /// as a compact backend summary.
  bool get hasProofModeC2paManifestId {
    return proofModeC2paManifestId != null ||
        proofSummary?.hasUsableC2paManifest == true;
  }

  bool get hasAddressableDTag =>
      addressableDTag != null && addressableDTag!.isNotEmpty;

  String? get addressableId => hasAddressableDTag
      ? AId(
          kind: EventKind.videoVertical,
          pubkey: pubkey,
          dTag: addressableDTag!,
        ).toAString()
      : null;

  /// Canonical identity for feed/session deduplication.
  ///
  /// Addressable short-video events can be republished with a new event id
  /// while still representing the same logical `kind:pubkey:d-tag` video.
  /// Falling back to [id] preserves behavior for non-addressable/legacy rows.
  String get feedDedupKey => (addressableId ?? id).toLowerCase();

  /// ProofMode: Check if video has any proof
  bool get hasProofMode {
    return (proofModeVerificationLevel != null &&
            proofModeVerificationLevel != 'unverified') ||
        hasProofModeManifest ||
        hasProofModePgpFingerprint ||
        hasProofModeDeviceAttestation ||
        hasProofModeC2paManifestId;
  }

  /// ProofMode: Check if video is verified mobile (highest level)
  bool get isVerifiedMobile {
    final rawLevel = rawTags['verification'];
    if (rawLevel != null && rawLevel.isNotEmpty) {
      return rawLevel == 'verified_mobile';
    }
    return proofSummary?.isVerified == true &&
        proofSummary?.level == 'verified_mobile';
  }

  /// ProofMode: Check if video is verified web (medium level)
  bool get isVerifiedWeb {
    final rawLevel = rawTags['verification'];
    if (rawLevel != null && rawLevel.isNotEmpty) {
      return rawLevel == 'verified_web';
    }
    return proofSummary?.isVerified == true &&
        proofSummary?.level == 'verified_web';
  }

  /// ProofMode: Check if video has basic proof (low level)
  bool get hasBasicProof {
    final rawLevel = rawTags['verification'];
    if (rawLevel != null && rawLevel.isNotEmpty) {
      return rawLevel == 'basic_proof';
    }
    return proofSummary?.shouldShowBasicProofTier == true;
  }

  /// Original Vine: Check if this is a recovered original vine from the
  /// Internet Archive.  Uses the server-controlled `platform` field from
  /// Funnelcake (set to "vine" for genuine archive imports).  This cannot
  /// be spoofed by publishing a crafted Nostr event because `platform` is
  /// relay metadata, not a user-settable tag.
  bool get isOriginalVine {
    return rawTags['platform'] == 'vine';
  }

  /// All hashtags including the synthetic "classic" tag for original Vines.
  List<String> get allHashtags => [if (isOriginalVine) 'classic', ...hashtags];

  /// True when this is a genuine Vine archive import without a usable original
  /// publish date.
  bool get hasUnknownOriginalDate {
    if (!isOriginalVine) return false;

    final taggedPublishedAt = int.tryParse(rawTags['published_at'] ?? '');
    if (taggedPublishedAt != null && taggedPublishedAt > 0) return false;

    return createdAt <= 0 || createdAt >= _vineShutdownAtUtcSeconds;
  }

  /// Check if this is original content (not a repost)
  bool get isOriginalContent {
    return !isRepost;
  }

  /// Comparator: items with no loop count first (new vines),
  /// then items with loop count sorted by amount desc.
  /// Within groups, break ties by most recent createdAt.
  static int compareByLoopsThenTime(VideoEvent a, VideoEvent b) {
    final aLoops = a.originalLoops;
    final bLoops = b.originalLoops;

    final aHasLoops = aLoops != null && aLoops > 0;
    final bHasLoops = bLoops != null && bLoops > 0;

    if (aHasLoops != bHasLoops) {
      // Items without loop count (or zero loops) should come first
      return aHasLoops ? 1 : -1;
    }

    if (!aHasLoops && !bHasLoops) {
      // Both have no loops: newest first
      return b.createdAt.compareTo(a.createdAt);
    }

    // Both have loops: sort by loops desc, then newest first
    final loopsCompare = bLoops!.compareTo(aLoops!);
    if (loopsCompare != 0) return loopsCompare;
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Enhanced comparator that combines multiple engagement metrics.
  /// Uses embedded metrics from imported vine data. Priority based on
  /// combined engagement: loops + (comments*3) + (likes*2) + (reposts*2.5)
  static int compareByEngagementScore(VideoEvent a, VideoEvent b) {
    // Calculate engagement scores using embedded metrics
    final aScore = _calculateEngagementScore(a);
    final bScore = _calculateEngagementScore(b);

    // Higher score wins
    final scoreCompare = bScore.compareTo(aScore);
    if (scoreCompare != 0) return scoreCompare;

    // If scores are equal, fall back to higher loop count
    final loopCompare = (b.originalLoops ?? 0).compareTo(a.originalLoops ?? 0);
    if (loopCompare != 0) return loopCompare;

    // Final tiebreaker: created_at (though most will have same timestamp
    // from import)
    return b.createdAt.compareTo(a.createdAt);
  }

  /// Calculate weighted engagement score for a video
  /// Uses metrics embedded in the vine import tags
  /// Weights are designed to prioritize meaningful engagement:
  /// - Loops (views): base metric, weight 1.0
  /// - Comments: high engagement, weight 3.0
  /// - Likes: medium engagement, weight 2.0
  /// - Reposts: amplification, weight 2.5
  static double _calculateEngagementScore(VideoEvent event) {
    // Use embedded metrics from imported vine data
    final loops = event.originalLoops ?? 0;
    final comments = event.originalComments ?? 0;
    final likes = event.originalLikes ?? 0;
    final reposts = event.originalReposts ?? 0;

    // Calculate weighted score
    var score = 0.0;
    score += loops * 1.0; // Base weight for views/loops
    score += comments * 3.0; // Comments show high engagement
    score += likes * 2.0; // Likes show appreciation
    score += reposts * 2.5; // Reposts help spread content

    return score;
  }

  static const int _vineShutdownAtUtcSeconds = 1484611200;

  /// Whether [key] names a video URL inside an `imeta` tag.
  ///
  /// Mirrors the `url`-plus-POSTEL'S-LAW-alternates set that
  /// `fromNostrEvent` collects as video URL candidates.
  static bool _isImetaVideoUrlKey(String key) => switch (key) {
    'url' ||
    'hls' ||
    'dash' ||
    'stream' ||
    'streaming' ||
    'fallback' ||
    'mp4' ||
    'video' => true,
    _ => false,
  };

  /// Video URLs advertised in this event's `imeta` tags, deduplicated.
  ///
  /// Uses the same key set ([_isImetaVideoUrlKey]) and
  /// [VideoUrlResolver.isValidVideoUrl] validation as `fromNostrEvent`'s
  /// candidate collection, so imeta URL extraction can't drift from the URL
  /// actually selected into [videoUrl]. Handles both the space-separated
  /// (`"url https://…"`) and positional (`"url", "https://…"`) encodings.
  List<String> get imetaVideoUrls {
    final urls = <String>[];
    for (final tag in nostrEventTags) {
      if (tag.isEmpty || tag.first != 'imeta') continue;
      parseImetaTag(tag, (key, value) {
        final url = value.trim();
        if (_isImetaVideoUrlKey(key) && VideoUrlResolver.isValidVideoUrl(url)) {
          urls.add(url);
        }
      });
    }
    return urls.toSet().toList(growable: false);
  }

  /// Extract width from dimensions string
  int? get width {
    if (dimensions == null) return null;
    final parts = dimensions!.split('x');
    return parts.isNotEmpty ? int.tryParse(parts[0]) : null;
  }

  /// Extract height from dimensions string
  int? get height {
    if (dimensions == null) return null;
    final parts = dimensions!.split('x');
    return parts.length > 1 ? int.tryParse(parts[1]) : null;
  }

  /// Check if video is in portrait orientation
  bool get isPortrait {
    if (width == null || height == null) return false;
    return height! > width!;
  }

  String? _firstNostrTagValue(String tagName) {
    for (final tag in nostrEventTags) {
      if (tag.length < 2 || tag.first != tagName) continue;

      final value = tag[1].trim();
      if (value.isNotEmpty) return value;
    }

    final rawValue = rawTags[tagName]?.trim();
    return rawValue != null && rawValue.isNotEmpty ? rawValue : null;
  }

  int? _kindFromAddressableId(String addressableId) {
    final separatorIndex = addressableId.indexOf(':');
    final kindText = separatorIndex == -1
        ? addressableId
        : addressableId.substring(0, separatorIndex);
    return int.tryParse(kindText);
  }

  /// Get file size in MB
  double? get fileSizeMB {
    if (fileSize == null) return null;
    return fileSize! / (1024 * 1024);
  }

  /// Get formatted duration string (e.g., "0:15")
  String get formattedDuration {
    if (duration == null) return '';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get pubkey for display
  String get displayPubkey {
    return pubkey;
  }

  /// Check if this event has video content
  bool get hasVideo => videoUrl?.isNotEmpty ?? false;

  /// Get effective thumbnail URL
  ///
  /// Returns the thumbnailUrl if set, otherwise null. Callers should render a
  /// blurhash or placeholder when this is null.
  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }
    return null;
  }

  /// Check if video URL is a GIF
  bool get isGif {
    if (mimeType != null) {
      return mimeType!.toLowerCase() == 'image/gif';
    }
    if (videoUrl != null) {
      return videoUrl?.toLowerCase().endsWith('.gif') ?? false;
    }
    return false;
  }

  /// Check if video URL is MP4
  bool get isMp4 {
    if (mimeType != null) {
      return mimeType!.toLowerCase() == 'video/mp4';
    }
    if (videoUrl != null) {
      return videoUrl?.toLowerCase().endsWith('.mp4') ?? false;
    }
    return false;
  }

  /// Check if video is WebM format
  bool get isWebM {
    if (mimeType != null && mimeType!.toLowerCase().contains('webm')) {
      return true;
    }
    if (videoUrl != null) {
      return videoUrl?.toLowerCase().endsWith('.webm') ?? false;
    }
    return false;
  }

  /// Create a copy with updated fields
  ///
  /// Use [clearOriginalLoops], [clearOriginalLikes], [clearOriginalComments],
  /// and [clearOriginalReposts] to explicitly set those fields to null.
  /// This is needed because passing null normally keeps the existing value.
  VideoEvent copyWith({
    String? id,
    String? pubkey,
    int? createdAt,
    String? content,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    String? mimeType,
    String? sha256,
    int? fileSize,
    List<String>? hashtags,
    List<String>? categories,
    DateTime? timestamp,
    int? eventCreatedAt,
    String? publishedAt,
    Map<String, String>? rawTags,
    String? vineId,
    String? addressableDTag,
    bool clearAddressableDTag = false,
    String? group,
    String? altText,
    String? blurhash,
    bool? isRepost,
    String? reposterId,
    String? reposterPubkey,
    List<String>? reposterPubkeys,
    DateTime? repostedAt,
    bool? isFlaggedContent,
    String? moderationStatus,
    int? originalLoops,
    int? originalLikes,
    int? originalComments,
    int? originalReposts,
    bool clearOriginalLoops = false,
    bool clearOriginalLikes = false,
    bool clearOriginalComments = false,
    bool clearOriginalReposts = false,
    int? expirationTimestamp,
    String? audioEventId,
    String? audioEventRelay,
    int? nostrLikeCount,
    int? nostrCommentCount,
    int? nostrRepostCount,
    String? authorName,
    String? authorAvatar,
    List<String>? collaboratorPubkeys,
    InspiredByInfo? inspiredByVideo,
    String? inspiredByNpub,
    List<String>? inspiredByPubkeys,
    List<ClipSourceCredit>? clipSourceCredits,
    List<List<String>>? nostrEventTags,
    String? textTrackRef,
    List<String>? textTrackRefs,
    String? textTrackContent,
    List<String>? contentWarningLabels,
    List<String>? moderationLabels,
    List<String>? warnLabels,
    ProofVerificationSummary? proofSummary,
    int? eventKind,
    String? sourceRelay,
  }) => VideoEvent(
    id: id ?? this.id,
    pubkey: pubkey ?? this.pubkey,
    createdAt: createdAt ?? this.createdAt,
    content: content ?? this.content,
    title: title ?? this.title,
    videoUrl: videoUrl ?? this.videoUrl,
    thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    duration: duration ?? this.duration,
    dimensions: dimensions ?? this.dimensions,
    mimeType: mimeType ?? this.mimeType,
    sha256: sha256 ?? this.sha256,
    fileSize: fileSize ?? this.fileSize,
    hashtags: hashtags ?? this.hashtags,
    categories: categories ?? this.categories,
    timestamp: timestamp ?? this.timestamp,
    eventCreatedAt: eventCreatedAt ?? this.eventCreatedAt,
    publishedAt: publishedAt ?? this.publishedAt,
    rawTags: rawTags ?? this.rawTags,
    vineId: vineId ?? this.vineId,
    addressableDTag: clearAddressableDTag
        ? null
        : (addressableDTag ?? this.addressableDTag),
    group: group ?? this.group,
    altText: altText ?? this.altText,
    blurhash: blurhash ?? this.blurhash,
    isRepost: isRepost ?? this.isRepost,
    reposterId: reposterId ?? this.reposterId,
    reposterPubkey: reposterPubkey ?? this.reposterPubkey,
    reposterPubkeys: reposterPubkeys ?? this.reposterPubkeys,
    repostedAt: repostedAt ?? this.repostedAt,
    isFlaggedContent: isFlaggedContent ?? this.isFlaggedContent,
    moderationStatus: moderationStatus ?? this.moderationStatus,
    originalLoops: clearOriginalLoops
        ? null
        : (originalLoops ?? this.originalLoops),
    originalLikes: clearOriginalLikes
        ? null
        : (originalLikes ?? this.originalLikes),
    originalComments: clearOriginalComments
        ? null
        : (originalComments ?? this.originalComments),
    originalReposts: clearOriginalReposts
        ? null
        : (originalReposts ?? this.originalReposts),
    expirationTimestamp: expirationTimestamp ?? this.expirationTimestamp,
    audioEventId: audioEventId ?? this.audioEventId,
    audioEventRelay: audioEventRelay ?? this.audioEventRelay,
    nostrLikeCount: nostrLikeCount ?? this.nostrLikeCount,
    nostrCommentCount: nostrCommentCount ?? this.nostrCommentCount,
    nostrRepostCount: nostrRepostCount ?? this.nostrRepostCount,
    authorName: authorName ?? this.authorName,
    authorAvatar: authorAvatar ?? this.authorAvatar,
    collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
    inspiredByVideo: inspiredByVideo ?? this.inspiredByVideo,
    inspiredByNpub: inspiredByNpub ?? this.inspiredByNpub,
    inspiredByPubkeys: inspiredByPubkeys ?? this.inspiredByPubkeys,
    clipSourceCredits: clipSourceCredits ?? this.clipSourceCredits,
    nostrEventTags: nostrEventTags ?? this.nostrEventTags,
    textTrackRef: textTrackRef ?? this.textTrackRef,
    textTrackRefs: textTrackRefs ?? this.textTrackRefs,
    textTrackContent: textTrackContent ?? this.textTrackContent,
    contentWarningLabels: contentWarningLabels ?? this.contentWarningLabels,
    moderationLabels: moderationLabels ?? this.moderationLabels,
    warnLabels: warnLabels ?? this.warnLabels,
    proofSummary: proofSummary ?? this.proofSummary,
    eventKind: eventKind ?? this.eventKind,
    sourceRelay: sourceRelay ?? this.sourceRelay,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoEvent && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'VideoEvent('
      'id: $id, '
      'pubkey: $displayPubkey, '
      'title: $title, '
      'duration: $formattedDuration, '
      'createdAt: $createdAt'
      ')';

  /// Serialize VideoEvent to a JSON-encodable map.
  ///
  /// Explicit allow-list of declared persisted fields. Computed getters,
  /// `hashCode`, and time-dependent values (e.g. `isExpired`) are deliberately
  /// excluded so the output is stable across calls and safe to persist or
  /// transmit. Adding a new persisted field requires updating both this map
  /// and `video_event_to_json_test.dart`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'pubkey': pubkey,
    'createdAt': createdAt,
    'content': content,
    'title': title,
    'videoUrl': videoUrl,
    'thumbnailUrl': thumbnailUrl,
    'duration': duration,
    'dimensions': dimensions,
    'mimeType': mimeType,
    'sha256': sha256,
    'fileSize': fileSize,
    'hashtags': hashtags,
    'categories': categories,
    'timestamp': timestamp.toIso8601String(),
    'eventCreatedAt': eventCreatedAt,
    'publishedAt': publishedAt,
    'rawTags': rawTags,
    'vineId': vineId,
    'addressableDTag': addressableDTag,
    'group': group,
    'altText': altText,
    'blurhash': blurhash,
    'isRepost': isRepost,
    'reposterId': reposterId,
    'reposterPubkey': reposterPubkey,
    'reposterPubkeys': reposterPubkeys,
    'repostedAt': repostedAt?.toIso8601String(),
    'isFlaggedContent': isFlaggedContent,
    'moderationStatus': moderationStatus,
    'originalLoops': originalLoops,
    'originalLikes': originalLikes,
    'originalComments': originalComments,
    'originalReposts': originalReposts,
    'expirationTimestamp': expirationTimestamp,
    'audioEventId': audioEventId,
    'audioEventRelay': audioEventRelay,
    'nostrLikeCount': nostrLikeCount,
    'nostrCommentCount': nostrCommentCount,
    'nostrRepostCount': nostrRepostCount,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'collaboratorPubkeys': collaboratorPubkeys,
    'inspiredByVideo': inspiredByVideo?.toJson(),
    'inspiredByNpub': inspiredByNpub,
    'inspiredByPubkeys': inspiredByPubkeys,
    'clipSourceCredits': clipSourceCredits
        .map((credit) => credit.toJson())
        .toList(),
    'textTrackRef': textTrackRef,
    'textTrackRefs': textTrackRefs,
    'textTrackContent': textTrackContent,
    'contentWarningLabels': contentWarningLabels,
    'moderationLabels': moderationLabels,
    'proofSummary': proofSummary?.toJson(),
    'eventKind': eventKind,
    'sourceRelay': sourceRelay,
  };

  /// Create a VideoEvent instance representing a repost
  /// Used when displaying Kind 6 repost events in the feed
  /// Supports both single and multiple reposters for consolidation
  static VideoEvent createRepostEvent({
    required VideoEvent originalEvent,
    required String repostEventId,
    required String reposterPubkey,
    required DateTime repostedAt,
    List<String>?
    reposterPubkeys, // Optional: list of all reposters for consolidated reposts
  }) => originalEvent.copyWith(
    isRepost: true,
    reposterId: repostEventId,
    reposterPubkey: reposterPubkey,
    reposterPubkeys:
        reposterPubkeys ?? [reposterPubkey], // Default to single reposter
    repostedAt: repostedAt,
  );
}

/// Exception thrown when parsing video events
class VideoEventException implements Exception {
  const VideoEventException(this.message);
  final String message;

  @override
  String toString() => 'VideoEventException: $message';
}
