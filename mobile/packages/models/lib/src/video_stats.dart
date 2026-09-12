// ABOUTME: Data model for Funnelcake API video stats response.
// ABOUTME: Represents video metadata with engagement metrics from the
// ABOUTME: ClickHouse-backed analytics API.

import 'package:meta/meta.dart';
import 'package:models/src/engagement_count_parser.dart';
import 'package:models/src/video_event.dart';
import 'package:models/src/video_url_resolver.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Video with engagement metrics from Funnelcake API.
///
/// This model represents the combined event data and stats returned
/// by the Funnelcake REST API. It includes both the video metadata
/// (from the Nostr event) and engagement metrics (from ClickHouse).
@immutable
class VideoStats {
  /// Creates a new [VideoStats] instance.
  const VideoStats({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.dTag,
    required this.title,
    required this.thumbnail,
    required this.videoUrl,
    required this.reactions,
    required this.comments,
    required this.reposts,
    required this.engagementScore,
    this.publishedAt,
    this.eventCreatedAt,
    this.description,
    this.sha256,
    this.authorName,
    this.authorAvatar,
    this.blurhash,
    this.dimensions,
    this.trendingScore,
    this.loops,
    this.views,
    this.embeddedLikes,
    this.embeddedComments,
    this.embeddedReposts,
    this.eventTags = const [],
    this.rawTags = const {},
    this.contentWarningLabels = const [],
    this.textTrackRef,
    this.textTrackContent,
    this.categories = const [],
    this.collaboratorPubkeys = const [],
    this.proofSummary,
    List<String> moderationLabels = const [],
    @Deprecated('Use moderationLabels') List<String>? contentLabels,
  }) : moderationLabels = contentLabels ?? moderationLabels;

  /// Creates a [VideoStats] from JSON response.
  ///
  /// Handles the nested format returned by Funnelcake API:
  /// `{ "event": {...}, "stats": {...} }`
  ///
  /// Also handles the quirks of the Funnelcake response format:
  /// - IDs returned as byte arrays (ASCII codes) instead of strings
  /// - Unix timestamps instead of ISO strings
  /// - Stats in various field name formats
  factory VideoStats.fromJson(Map<String, dynamic> json) {
    // Handle nested format: { "event": {...}, "stats": {...} }
    final eventData = json['event'] as Map<String, dynamic>? ?? json;
    final statsData = json['stats'] as Map<String, dynamic>? ?? json;

    // Parse id - funnelcake returns as byte array (ASCII codes), not string
    String id;
    final rawId = eventData['id'];
    if (rawId is List) {
      id = String.fromCharCodes(rawId.cast<int>());
    } else {
      id = rawId?.toString() ?? '';
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    id = id.toLowerCase();

    // Parse pubkey - same format as id
    String pubkey;
    final rawPubkey = eventData['pubkey'];
    if (rawPubkey is List) {
      pubkey = String.fromCharCodes(rawPubkey.cast<int>());
    } else {
      pubkey = rawPubkey?.toString() ?? '';
    }
    // Normalize to lowercase per NIP-01 (Funnelcake may return uppercase hex)
    pubkey = pubkey.toLowerCase();

    // Parse created_at - funnelcake returns Unix timestamp (int), not ISO
    late final DateTime createdAt;
    int? eventCreatedAt;
    final rawCreatedAt = eventData['created_at'];
    if (rawCreatedAt is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        rawCreatedAt * 1000,
        isUtc: true,
      );
      eventCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt is String) {
      final parsedCreatedAt = DateTime.tryParse(rawCreatedAt)?.toUtc();
      createdAt = parsedCreatedAt ?? DateTime.now().toUtc();
      eventCreatedAt = parsedCreatedAt == null
          ? null
          : parsedCreatedAt.millisecondsSinceEpoch ~/ 1000;
    } else {
      createdAt = DateTime.now().toUtc();
    }

    // Parse archival loops from multiple possible sources. embedded_loops /
    // original_loops come first because nested stats objects also carry a
    // live computed `loops` value that must not shadow the Vine-era count.
    int? loops;
    final directLoops =
        statsData['embedded_loops'] ??
        json['embedded_loops'] ??
        json['original_loops'] ??
        statsData['loops'] ??
        statsData['total_loops'] ??
        statsData['computed_loops'] ??
        json['loops'] ??
        json['total_loops'] ??
        json['computed_loops'];
    if (directLoops is int) {
      loops = directLoops;
    } else if (directLoops is double) {
      loops = directLoops.toInt();
    } else if (directLoops is String) {
      loops = int.tryParse(directLoops);
    }

    // Also check event tags for loops if not found directly
    if (loops == null && eventData['tags'] is List) {
      final tags = eventData['tags'] as List<dynamic>;
      for (final tag in tags) {
        if (tag is List && tag.length >= 2 && tag[0] == 'loops') {
          loops = int.tryParse(tag[1].toString());
          break;
        }
      }
    }

    // Extract title, thumbnail, sha256 from tags if not in root
    var title = eventData['title']?.toString() ?? '';
    var thumbnail = eventData['thumbnail']?.toString() ?? '';
    var videoUrl = eventData['video_url']?.toString() ?? '';
    var dTag =
        _firstNonEmptyString([
          eventData['d_tag'],
          eventData['dTag'],
          eventData['addressable_d_tag'],
          eventData['addressableDTag'],
          json['d_tag'],
          json['dTag'],
          json['addressable_d_tag'],
          json['addressableDTag'],
          _dTagFromAddressableId(eventData['addressable_id']),
          _dTagFromAddressableId(eventData['addressableId']),
          _dTagFromAddressableId(json['addressable_id']),
          _dTagFromAddressableId(json['addressableId']),
        ]) ??
        '';
    var sha256 = eventData['sha256']?.toString() ?? json['sha256']?.toString();

    // Parse description from event content (NIP-71: content = description)
    var description = eventData['content']?.toString();
    if (description != null && description.isEmpty) description = null;

    // Parse view counts from multiple possible sources
    int? views;
    final directViews =
        statsData['views'] ??
        statsData['view_count'] ??
        statsData['total_views'] ??
        json['views'] ??
        json['view_count'] ??
        json['total_views'];
    if (directViews is int) {
      views = directViews;
    } else if (directViews is double) {
      views = directViews.toInt();
    } else if (directViews is String) {
      views = int.tryParse(directViews);
    }

    // Parse text-track fields from API response (text_track_ref,
    // text_track_content are top-level fields on video endpoints).
    var textTrackRef =
        json['text_track_ref']?.toString() ??
        eventData['text_track_ref']?.toString() ??
        statsData['text_track_ref']?.toString();
    if (textTrackRef != null && textTrackRef.isEmpty) textTrackRef = null;

    var textTrackContent =
        json['text_track_content']?.toString() ??
        eventData['text_track_content']?.toString() ??
        statsData['text_track_content']?.toString();
    if (textTrackContent != null && textTrackContent.isEmpty) {
      textTrackContent = null;
    }

    var dimensions =
        eventData['dimensions']?.toString() ??
        eventData['dim']?.toString() ??
        json['dimensions']?.toString() ??
        json['dim']?.toString() ??
        statsData['dimensions']?.toString() ??
        statsData['dim']?.toString();
    if (dimensions != null && dimensions.isEmpty) dimensions = null;

    final moderationLabels = _parseModerationLabels(
      json['moderation_labels'] ??
          eventData['moderation_labels'] ??
          statsData['moderation_labels'],
    );
    final proofSummary = _parseProofSummary(
      json['proof'] ?? eventData['proof'] ?? statsData['proof'],
    );
    // Also check for blurhash and summary in tags (NIP-71 standard)
    // Collect ALL tags into rawTags so nothing is lost (ProofMode, C2PA, etc.)
    String? blurhashFromTag;
    String? summaryFromTag;
    int? publishedAt;
    final rawTags = <String, String>{};
    final eventTags = <List<String>>[];
    final contentWarningLabels = <String>[];
    final collaboratorPubkeys = <String>[];

    if (eventData['tags'] is List) {
      final tags = eventData['tags'] as List<dynamic>;
      for (final tag in tags) {
        if (tag is List) {
          final normalizedTag = tag.map((value) => value.toString()).toList();
          if (normalizedTag.isEmpty) continue;
          eventTags.add(normalizedTag);
          if (normalizedTag.length < 2) continue;
          final tagName = normalizedTag[0];
          final tagValue = normalizedTag[1];

          // Store every tag in rawTags for downstream consumers
          rawTags[tagName] = tagValue;

          if (tagName == 'title' && title.isEmpty) title = tagValue;
          if ((tagName == 'thumb' || tagName == 'thumbnail') &&
              thumbnail.isEmpty) {
            thumbnail = tagValue;
          }
          if (tagName == 'url' && videoUrl.isEmpty) videoUrl = tagValue;
          if (tagName == 'd' && dTag.isEmpty) dTag = tagValue;
          if (tagName == 'x' && (sha256 == null || sha256.isEmpty)) {
            sha256 = tagValue; // x tag often contains sha256 hash
          }
          if (tagName == 'blurhash' && blurhashFromTag == null) {
            blurhashFromTag = tagValue;
          }
          if (tagName == 'imeta') {
            parseImetaTag(List<String>.from(tag.map((e) => e.toString())), (
              key,
              value,
            ) {
              if (key == 'blurhash' &&
                  blurhashFromTag == null &&
                  value.isNotEmpty) {
                blurhashFromTag = value;
              }
              if (key == 'dim' && dimensions == null && value.isNotEmpty) {
                dimensions = value;
              }
            });
          }
          if (tagName == 'dim' && dimensions == null) {
            dimensions = tagValue;
          }
          if (tagName == 'summary' && summaryFromTag == null) {
            summaryFromTag = tagValue;
          }
          if (tagName == 'published_at' && publishedAt == null) {
            publishedAt = int.tryParse(tagValue);
          }
          if (tagName == 'views' && views == null) {
            views = int.tryParse(tagValue);
          }
          if (tagName == 'text-track' && textTrackRef == null) {
            textTrackRef = tagValue;
          }
          if (tagName == 'content-warning' &&
              tagValue.isNotEmpty &&
              !contentWarningLabels.contains(tagValue)) {
            contentWarningLabels.add(tagValue);
          }
          if (tagName == 'l' &&
              tag.length >= 3 &&
              tag[2].toString() == 'content-warning' &&
              tagValue.isNotEmpty &&
              !contentWarningLabels.contains(tagValue)) {
            contentWarningLabels.add(tagValue);
          }
          if (tagName == 'p' && tagValue.isNotEmpty) {
            final normalized = tagValue.toLowerCase();
            final role = tag.length >= 4 && tag[3] is String
                ? (tag[3] as String).toLowerCase()
                : null;
            if (role == 'collaborator' &&
                normalized != pubkey &&
                !collaboratorPubkeys.contains(normalized)) {
              collaboratorPubkeys.add(normalized);
            }
          }
        }
      }
    }

    // Fall back to summary tag if content is empty
    description ??= summaryFromTag;

    // Funnelcake list/stats rows send published_at as a top-level field and
    // omit `tags`. The tag loop above never runs, so without this fallback
    // every REST-loaded video has publishedAt == null and New pagination
    // walks event created_at instead of original publication time.
    // Tags stay authoritative when present (NIP-71).
    publishedAt ??= _parseOptionalUnixSeconds(
      eventData['published_at'] ??
          json['published_at'] ??
          statsData['published_at'],
    );
    if (publishedAt != null) {
      rawTags.putIfAbsent('published_at', () => publishedAt.toString());
    }

    // Normalize empty sha256 to null
    if (sha256 != null && sha256.isEmpty) sha256 = null;

    // Fall back to d_tag as sha256 for Blossom-uploaded videos.
    // The REST API doesn't return sha256 or raw tags, but d_tag IS the
    // content hash for Blossom uploads (64 hex chars).
    if (sha256 == null && dTag.length == 64 && _isHex(dTag)) {
      sha256 = dTag;
    }

    // Parse author_name for classic Vines
    var authorName =
        eventData['author_name']?.toString() ?? json['author_name']?.toString();
    if (authorName != null && authorName.isEmpty) authorName = null;

    // Parse author_avatar for profile pictures
    var authorAvatar =
        eventData['author_avatar']?.toString() ??
        json['author_avatar']?.toString();
    if (authorAvatar != null && authorAvatar.isEmpty) authorAvatar = null;

    // Parse blurhash for thumbnail placeholders.
    // Use firstWhere so that empty strings from the API don't shadow the
    // blurhashFromTag value extracted from the Nostr imeta/blurhash tags.
    final blurhash = [
      eventData['blurhash']?.toString(),
      json['blurhash']?.toString(),
      blurhashFromTag,
    ].firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);

    // Live Divine engagement. embedded_* archival counts are parsed into
    // their own fields below so the two sources can be summed for display
    // without double-counting (classic Vines carry both).
    final reactions = statsData['reactions'] ?? json['reactions'] ?? 0;
    final comments = statsData['comments'] ?? json['comments'] ?? 0;
    final reposts = statsData['reposts'] ?? json['reposts'] ?? 0;

    final embeddedLikes = tryParseEngagementCount(
      statsData['embedded_likes'] ?? json['embedded_likes'] ?? json['likes'],
    );
    final embeddedComments = tryParseEngagementCount(
      statsData['embedded_comments'] ?? json['embedded_comments'],
    );
    final embeddedReposts = tryParseEngagementCount(
      statsData['embedded_reposts'] ?? json['embedded_reposts'],
    );

    // Parse platform from Funnelcake (server-controlled, not user-settable).
    // "vine" indicates a genuine Vine archive import.
    final platform =
        json['platform']?.toString() ?? eventData['platform']?.toString();
    if (platform != null && platform.isNotEmpty) {
      rawTags['platform'] = platform;
    }

    // Funnelcake list/stats rows expose ProofMode/C2PA/verification as
    // top-level fields, not inside `event.tags`, so the tag loop above never
    // captures them. Map them under the same keys the VideoEvent proof getters
    // read so REST/feed-loaded videos keep their verification signals instead
    // of decaying to an unverified shell (which also poisons the shared cache
    // for the detail view). Relay-shaped payloads already carry the tags, so
    // only fill keys the tag loop didn't set.
    for (final key in const [
      'verification',
      'proofmode',
      'device_attestation',
      'c2pa_manifest_id',
    ]) {
      if (rawTags.containsKey(key)) continue;
      final value = eventData[key] ?? json[key] ?? statsData[key];
      if (value is String && value.isNotEmpty) {
        rawTags[key] = value;
      }
    }

    // Parse categories from Funnelcake VLM classification.
    final categoriesRaw = json['categories'] ?? eventData['categories'];
    final categories = categoriesRaw is List
        ? categoriesRaw.map((e) => e.toString()).toList()
        : <String>[];

    return VideoStats(
      id: id,
      pubkey: pubkey,
      createdAt: createdAt,
      eventCreatedAt: eventCreatedAt,
      publishedAt: publishedAt,
      kind: (eventData['kind'] as int?) ?? 34236,
      dTag: dTag,
      title: title,
      description: description,
      thumbnail: thumbnail,
      videoUrl: videoUrl,
      sha256: sha256,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      dimensions: dimensions,
      reactions: parseEngagementCount(reactions),
      comments: parseEngagementCount(comments),
      reposts: parseEngagementCount(reposts),
      engagementScore: _parseInt(
        statsData['engagement_score'] ?? json['engagement_score'],
      ),
      trendingScore: _parseDouble(
        statsData['trending_score'] ?? json['trending_score'],
      ),
      loops: loops,
      views: views,
      embeddedLikes: embeddedLikes,
      embeddedComments: embeddedComments,
      embeddedReposts: embeddedReposts,
      eventTags: eventTags,
      rawTags: rawTags,
      categories: categories,
      contentWarningLabels: contentWarningLabels,
      collaboratorPubkeys: collaboratorPubkeys,
      textTrackRef: textTrackRef,
      textTrackContent: textTrackContent,
      moderationLabels: moderationLabels,
      proofSummary: proofSummary,
    );
  }

  /// Nostr event ID.
  final String id;

  /// Author's public key (hex format).
  final String pubkey;

  /// When the video was created.
  final DateTime createdAt;

  /// Parsed raw Nostr event `created_at`, or null when the REST value was
  /// missing or invalid and [createdAt] had to use a display fallback.
  final int? eventCreatedAt;

  /// Unix timestamp of when the video was published (`published_at` tag).
  ///
  /// May differ from [createdAt] when the event was updated after initial
  /// publication.
  final int? publishedAt;

  /// Nostr event kind (typically 34236 for vertical videos).
  final int kind;

  /// The `d` tag value (addressable event identifier).
  final String dTag;

  /// Video title.
  final String title;

  /// Video description from event content (NIP-71).
  final String? description;

  /// Thumbnail URL.
  final String thumbnail;

  /// Video URL.
  final String videoUrl;

  /// Content hash for Blossom authentication.
  final String? sha256;

  /// Display name of classic Vine author.
  final String? authorName;

  /// Profile picture URL for author.
  final String? authorAvatar;

  /// Blurhash for placeholder thumbnail.
  final String? blurhash;

  /// Video dimensions from REST or Nostr `dim` metadata.
  final String? dimensions;

  /// Reaction/like count.
  final int reactions;

  /// Comment count.
  final int comments;

  /// Repost count.
  final int reposts;

  /// Combined engagement score.
  final int engagementScore;

  /// Trending score (if available).
  final double? trendingScore;

  /// Original loop count for classic Vines.
  final int? loops;

  /// Live/new view count from Funnelcake analytics.
  final int? views;

  /// Original like count embedded from the Vine archive import.
  final int? embeddedLikes;

  /// Original comment count embedded from the Vine archive import.
  final int? embeddedComments;

  /// Original repost count embedded from the Vine archive import.
  final int? embeddedReposts;

  /// VLM-classified category names from Funnelcake (e.g., "animals", "music").
  ///
  /// Empty until the API includes a `categories` field in video responses.
  final List<String> categories;

  /// Complete ordered Nostr tag array from the REST event payload.
  ///
  /// Unlike [rawTags], this preserves repeated tag names and every component
  /// of structured tags so an addressable event can be republished safely.
  final List<List<String>> eventTags;

  /// All Nostr event tags as a flat map, preserving tags (like ProofMode,
  /// C2PA, verification) that don't have dedicated fields on this model.
  final Map<String, String> rawTags;

  /// Author-applied content warning labels parsed from NIP-32/NIP-36 tags.
  final List<String> contentWarningLabels;

  /// Pubkeys from Divine's collaborator-marked `p` tags whose value differs
  /// from the event author. Empty when the event has no collaborator markers
  /// or when the REST payload did not include tag data.
  final List<String> collaboratorPubkeys;

  /// Addressable coordinates for subtitle event (from `text-track` tag or
  /// API `text_track_ref` field).
  final String? textTrackRef;

  /// Embedded VTT content from API (saves client a relay round-trip).
  final String? textTrackContent;

  /// Resolved moderation labels extracted from REST `moderation_labels`.
  ///
  /// This is the server-resolved trust-and-safety field returned by Funnelcake.
  /// Discovery/classifier metadata remains in REST `content_labels` and is not
  /// promoted into [VideoEvent.contentWarningLabels].
  final List<String> moderationLabels;

  /// Compact backend-computed proof verification result for list/feed cards.
  final ProofVerificationSummary? proofSummary;

  /// Deprecated alias for [moderationLabels].
  @Deprecated('Use moderationLabels')
  List<String> get contentLabels => moderationLabels;

  /// Converts this [VideoStats] to a [VideoEvent] for use in the app.
  ///
  /// Maps the Funnelcake API response fields to the corresponding
  /// [VideoEvent] fields used throughout the application.
  ///
  /// Uses [publishedAt] as the effective timestamp when available,
  /// falling back to [createdAt].
  ///
  /// Propagates the NIP-40 `expiration` tag (if present in [rawTags]) so the
  /// client can honour server-side expiration on REST-loaded videos the same
  /// way it does for relay-loaded videos.
  ///
  /// Propagates [kind] so a REST-loaded video carries the same
  /// [VideoEvent.eventKind] a relay-loaded one gets from `fromNostrEvent`.
  /// Without it every REST video reads as an unknown kind, and the
  /// addressability checks that key on it (view-event drop classification,
  /// [VideoEvent.shareKind]) silently guess 34236.
  VideoEvent toVideoEvent() {
    final effectiveTimestamp =
        publishedAt ?? createdAt.millisecondsSinceEpoch ~/ 1000;
    final normalizedDTag = dTag.isNotEmpty ? dTag : id;
    final expirationTimestamp = int.tryParse(rawTags['expiration'] ?? '');
    final resolvedVideoUrl = _usableVideoUrl(videoUrl, sha256: sha256);
    final resolvedThumbnailUrl = _usableThumbnailUrl(thumbnail);
    // Archival Vine counts: prefer the server-resolved embedded_* fields,
    // fall back to the archive-import event tags for relay-shaped payloads.
    final originalLikes = embeddedLikes ?? int.tryParse(rawTags['likes'] ?? '');
    final originalComments =
        embeddedComments ?? int.tryParse(rawTags['comments'] ?? '');
    final originalReposts =
        embeddedReposts ?? int.tryParse(rawTags['reposts'] ?? '');
    final hashtags = eventTags
        .where((tag) => tag.length >= 2 && tag.first == 't')
        .map((tag) => tag[1])
        .where((tag) => tag.isNotEmpty)
        .toList();
    return VideoEvent(
      id: id,
      pubkey: pubkey,
      createdAt: effectiveTimestamp,
      eventCreatedAt: eventCreatedAt,
      content: description ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        effectiveTimestamp * 1000,
        isUtc: true,
      ),
      title: title.isNotEmpty ? title : null,
      videoUrl: resolvedVideoUrl,
      thumbnailUrl: resolvedThumbnailUrl,
      vineId: normalizedDTag.isNotEmpty ? normalizedDTag : null,
      publishedAt: publishedAt?.toString(),
      sha256: sha256,
      addressableDTag: dTag.isNotEmpty ? dTag : null,
      eventKind: kind,
      authorName: authorName,
      authorAvatar: authorAvatar,
      blurhash: blurhash,
      dimensions: dimensions,
      fileSize: _fileSizeFromEventTags(eventTags),
      originalLikes: originalLikes,
      nostrLikeCount: reactions,
      originalComments: originalComments,
      originalReposts: originalReposts,
      nostrCommentCount: comments,
      nostrRepostCount: reposts,
      originalLoops: loops,
      hashtags: hashtags,
      altText: rawTags['alt'],
      duration: int.tryParse(rawTags['duration'] ?? ''),
      textTrackRef: textTrackRef,
      textTrackContent: textTrackContent,
      categories: categories,
      contentWarningLabels: contentWarningLabels,
      collaboratorPubkeys: collaboratorPubkeys,
      moderationLabels: moderationLabels,
      proofSummary: proofSummary,
      nostrEventTags: eventTags,
      rawTags: {
        ...rawTags,
        // Note: Do NOT inject engagement `loops` here — rawTags['loops']
        // must only exist when the original Nostr event contains a
        // ['loops', ...] tag (i.e., genuine Vine archive imports).
        // The engagement loop count is stored in `originalLoops` instead.
        if (views != null) 'views': views.toString(),
      },
      expirationTimestamp: expirationTimestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoStats && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'VideoStats(id: $id, title: $title)';
}

int? _fileSizeFromEventTags(List<List<String>> eventTags) {
  int? fileSize;
  for (final tag in eventTags) {
    if (tag.isEmpty) continue;
    if (tag.first == 'size' && tag.length >= 2) {
      fileSize = int.tryParse(tag[1]);
    } else if (tag.first == 'imeta') {
      parseImetaTag(tag, (key, value) {
        if (key == 'size') fileSize ??= int.tryParse(value);
      });
    }
  }
  return fileSize;
}

List<String> _parseModerationLabels(dynamic value) {
  if (value is! List) return const [];

  final labels = <String>[];
  for (final item in value) {
    final normalized = _normalizeModerationLabel(item.toString().trim());
    if (normalized != null && !labels.contains(normalized)) {
      labels.add(normalized);
    }
  }
  return labels;
}

ProofVerificationSummary? _parseProofSummary(dynamic value) {
  if (value is! Map<String, dynamic>) return null;
  return ProofVerificationSummary.fromJson(value);
}

String? _firstNonEmptyString(Iterable<Object?> values) {
  for (final value in values) {
    final normalized = value?.toString().trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String? _usableVideoUrl(String value, {required String? sha256}) {
  if (value.isEmpty) return null;
  if (!VideoUrlResolver.isKnownDeadMediaUrl(value)) return value;

  final hash = sha256?.trim();
  if (hash != null && hash.length == 64 && _isHex(hash)) {
    return 'https://media.divine.video/$hash';
  }

  return value;
}

String? _usableThumbnailUrl(String value) {
  if (value.isEmpty) return null;
  if (!VideoUrlResolver.isValidVideoUrl(value)) return null;
  if (VideoUrlResolver.isKnownDeadMediaUrl(value)) return null;
  return value;
}

String? _dTagFromAddressableId(Object? value) {
  final addressableId = value?.toString().trim();
  if (addressableId == null || addressableId.isEmpty) return null;

  final parts = addressableId.split(':');
  if (parts.length < 3) return null;
  if (int.tryParse(parts.first) == null) return null;

  final dTag = parts.sublist(2).join(':').trim();
  return dTag.isEmpty ? null : dTag;
}

String? _normalizeModerationLabel(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final normalized = trimmed
      .toLowerCase()
      .replaceAll('_', '-')
      .replaceAll(RegExp(r'\s+'), '-');

  // Keep this alias mapping in sync with ContentLabel.fromValue, which is the
  // canonical app-level moderation label parser.
  switch (normalized) {
    case 'sexual-content':
      return 'sexual';
    case 'pornography':
    case 'explicit':
      return 'porn';
    case 'graphic-violence':
    case 'gore':
      return 'graphic-media';
    case 'nsfw':
      return 'nudity';
    case 'offensive':
    case 'hate-speech':
      return 'hate';
    case 'recreational-drug':
      return 'drugs';
    case 'weapon':
      return 'violence';
  }

  return normalized;
}

/// Safely parses a dynamic value to double.
double? _parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _parseOptionalUnixSeconds(dynamic value) {
  final parsed = switch (value) {
    final int n => n,
    final double n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

final _hexPattern = RegExp(r'^[0-9a-fA-F]+$');

/// Returns `true` if [value] contains only hexadecimal characters.
bool _isHex(String value) => _hexPattern.hasMatch(value);
