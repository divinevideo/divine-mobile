// ABOUTME: Video Event model for NIP-71 compliant video events - OpenVine uses kind 34236 (addressable short videos)
// ABOUTME: Parses video metadata from Nostr events with support for kinds 22, 21, 34236, 34235

import 'dart:developer' as developer;
import 'dart:io';

import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/thumbnail_api_service.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/m3u8_resolver_service.dart';

/// Represents a video event (NIP-71 compliant kinds 22, 34236)
class VideoEvent {
  // approved, flagged, etc.

  const VideoEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.content,
    required this.timestamp,
    this.title,
    this.videoUrl,
    this.thumbnailUrl,
    this.duration,
    this.dimensions,
    this.mimeType,
    this.sha256,
    this.fileSize,
    this.hashtags = const [],
    this.publishedAt,
    this.rawTags = const {},
    this.vineId,
    this.group,
    this.altText,
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
  });

  /// Create VideoEvent from Nostr event
  factory VideoEvent.fromNostrEvent(Event event) {
    if (!NIP71VideoKinds.isVideoKind(event.kind)) {
      throw ArgumentError(
        'Event must be a NIP-71 video kind (${NIP71VideoKinds.getAllVideoKinds().join(', ')})',
      );
    }

    developer.log(
      '🔍 DEBUG: Parsing Kind ${event.kind} event ${event.id}',
      name: 'VideoEvent',
    );
    developer.log(
      '🔍 DEBUG: Event has ${event.tags.length} tags',
      name: 'VideoEvent',
    );
    developer.log(
      '🔍 DEBUG: Event content: ${event.content.length > 100 ? "${event.content.substring(0, 100)}..." : event.content}',
      name: 'VideoEvent',
    );

    final tags = <String, String>{};
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

    // Parse event tags according to NIP-71
    // Handle both List<String> and List<dynamic> from different nostr implementations
    for (var i = 0; i < event.tags.length; i++) {
      final tagRaw = event.tags[i];
      if ((tagRaw as List).isEmpty) continue;

      // Convert List<dynamic> to List<String> safely
      final tag = tagRaw.map((e) => e.toString()).toList();

      final tagName = tag[0];
      final tagValue = (tag.length > 1) ? tag[1] : '';

      developer.log(
        '🔍 DEBUG: Tag [$i]: $tagName = "$tagValue" (${tag.length} elements)',
        name: 'VideoEvent',
      );

      switch (tagName) {
        case 'url':
          developer.log(
            '🔍 DEBUG: Found url tag with value: $tagValue',
            name: 'VideoEvent',
          );
          // Check if this is a valid video URL
          if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            if (tagValue.contains('apt.openvine.co')) {
              // Fix typo: apt.openvine.co -> api.openvine.co
              final fixedUrl = tagValue.replaceAll(
                'apt.openvine.co',
                'api.openvine.co',
              );
              developer.log(
                '🔧 FIXED: Corrected apt.openvine.co to api.openvine.co: $fixedUrl',
                name: 'VideoEvent',
              );
              videoUrlCandidates.add(fixedUrl);
            } else {
              videoUrlCandidates.add(tagValue);
              developer.log(
                '✅ Added video URL candidate from url tag: $tagValue',
                name: 'VideoEvent',
              );
            }
          } else {
            developer.log(
              '⚠️ WARNING: Invalid URL in url tag: $tagValue',
              name: 'VideoEvent',
            );
          }
        case 'streaming':
          // Handle streaming tag with HLS/DASH URLs
          // Format: ["streaming", "url", "format"] e.g., ["streaming", "https://cdn.divine.video/.../video.m3u8", "hls"]
          if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
            developer.log(
              '✅ Added video URL candidate from streaming tag: $tagValue',
              name: 'VideoEvent',
            );
          }
        case 'imeta':
          developer.log(
            '🔍 DEBUG: Found imeta tag with ${tag.length} elements',
            name: 'VideoEvent',
          );
          developer.log(
            '🔍 DEBUG: Full imeta tag contents: $tag',
            name: 'VideoEvent',
          );
          // Parse imeta tag which contains comma-separated metadata
          // Ensure we have a List<String> for the parser
          final iMetaTag = List<String>.from(tag);
          _parseImetaTag(iMetaTag, (key, value) {
            developer.log(
              '🔍 DEBUG: imeta key="$key" value="$value"',
              name: 'VideoEvent',
            );
            switch (key) {
              case 'url':
                developer.log(
                  '🔍 DEBUG: imeta URL value: $value',
                  name: 'VideoEvent',
                );
                // Check if this is a valid video URL and add to candidates
                if (value.isNotEmpty && _isValidVideoUrl(value)) {
                  if (value.contains('apt.openvine.co')) {
                    // Fix typo: apt.openvine.co -> api.openvine.co
                    final fixedUrl = value.replaceAll(
                      'apt.openvine.co',
                      'api.openvine.co',
                    );
                    developer.log(
                      '🔧 FIXED: Corrected apt.openvine.co to api.openvine.co in imeta: $fixedUrl',
                      name: 'VideoEvent',
                    );
                    videoUrlCandidates.add(fixedUrl);
                  } else {
                    videoUrlCandidates.add(value);
                    developer.log(
                      '✅ Added video URL candidate from imeta url: $value',
                      name: 'VideoEvent',
                    );
                  }
                } else {
                  developer.log(
                    '⚠️ WARNING: Invalid URL in imeta: $value',
                    name: 'VideoEvent',
                  );
                }
              // POSTEL'S LAW: Accept various video URL keys that different clients may use
              case 'hls':
              case 'dash':
              case 'stream':
              case 'streaming':
              case 'fallback':
              case 'mp4':
              case 'video':
                // Alternative video URL keys - add as candidates if valid
                if (value.isNotEmpty && _isValidVideoUrl(value)) {
                  videoUrlCandidates.add(value);
                  developer.log(
                    '✅ Added video URL candidate from imeta $key: $value',
                    name: 'VideoEvent',
                  );
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
                // Thumbnail URL
                thumbnailUrl ??= value;
              case 'image':
                // NIP-92 uses 'image' for thumbnail in imeta
                thumbnailUrl ??= value;
                developer.log(
                  '✅ Set thumbnailUrl from imeta image tag: $value',
                  name: 'VideoEvent',
                );
              case 'blurhash':
                // Blurhash for progressive loading
                blurhash ??= value;
              case 'duration':
                duration ??= double.tryParse(value)?.round();
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
          thumbnailUrl = tagValue as String?;
        case 'preview':
          // Animated GIF preview - store separately, don't use as main thumbnail
          // GIFs auto-play and would make the grid look chaotic
          // We could use this for hover effects or preview on long-press in the future
          if (tagValue.isNotEmpty && tagValue.endsWith('.gif')) {
            // Store in tags for potential future use but don't use as main thumbnail
            tags['preview_gif'] = tagValue;
            developer.log(
              '✅ Found preview GIF tag (not using as thumbnail): $tagValue',
              name: 'VideoEvent',
            );
          }
        case 'image':
          // Alternative to 'thumb' tag - some clients use 'image' instead
          thumbnailUrl ??= tagValue as String?;
        case 'd':
          // Replaceable event ID - original vine ID
          vineId = tagValue as String?;
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
          // NIP-25 reference - might contain media URLs
          // Also handle "r" tags with type annotation (e.g., ["r", "url", "video"] or ["r", "url", "thumbnail"])
          if (tag.length >= 3) {
            final url = tagValue;
            final type = tag[2];
            developer.log(
              '🔍 DEBUG: Found r tag with type annotation: url="$url" type="$type"',
              name: 'VideoEvent',
            );

            if (type == 'video' && url.isNotEmpty && _isValidVideoUrl(url)) {
              videoUrl ??= url;
              developer.log(
                '✅ Found video URL in r tag with type annotation: $url',
                name: 'VideoEvent',
              );
            } else if (type == 'thumbnail' &&
                url.isNotEmpty &&
                !url.contains('picsum.photos')) {
              thumbnailUrl ??= url;
              developer.log(
                '✅ Found thumbnail URL in r tag with type annotation: $url',
                name: 'VideoEvent',
              );
            }
          } else if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            // Fallback: if no type annotation, treat as video URL
            videoUrlCandidates.add(tagValue);
            developer.log(
              '✅ Added video URL candidate from r tag: $tagValue',
              name: 'VideoEvent',
            );
          }
        case 'e':
          // Event reference - check if it's a media URL in disguise
          if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
            developer.log(
              '✅ Added video URL candidate from e tag: $tagValue',
              name: 'VideoEvent',
            );
          }
        case 'i':
          // External identity - sometimes used for media
          if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
            developer.log(
              '✅ Added video URL candidate from i tag: $tagValue',
              name: 'VideoEvent',
            );
          }
        default:
          // POSTEL'S LAW: Check if any unknown tag contains a valid video URL
          if (tagValue.isNotEmpty && _isValidVideoUrl(tagValue)) {
            videoUrlCandidates.add(tagValue);
            developer.log(
              '✅ Added video URL candidate from unknown tag "$tagName": $tagValue',
              name: 'VideoEvent',
            );
          }
      }

      // Store all tags for potential future use
      tags[tagName] = tagValue;
    }

    final createdAtTimestamp = event.createdAt is DateTime
        ? (event.createdAt as DateTime).millisecondsSinceEpoch ~/ 1000
        : int.tryParse(event.createdAt.toString()) ?? 0;

    developer.log('🔍 DEBUG: Final parsing results:', name: 'VideoEvent');
    developer.log('🔍 DEBUG: videoUrl = $videoUrl', name: 'VideoEvent');
    developer.log('🔍 DEBUG: thumbnailUrl = $thumbnailUrl', name: 'VideoEvent');

    // DEBUG: Log the exact videoUrl being passed to VideoEvent constructor
    if (videoUrl?.contains('cdn.divine.video') == true) {
      developer.log(
        '⚠️ SUSPICIOUS: Found cdn.divine.video URL: $videoUrl',
        name: 'VideoEvent',
      );
    }
    developer.log('🔍 DEBUG: duration = $duration', name: 'VideoEvent');

    // POSTEL'S LAW: Be liberal in what you accept
    // Apply comprehensive fallback logic to find video URLs
    if (videoUrl == null || videoUrl.isEmpty) {
      developer.log(
        '🔧 FALLBACK: No video URL found in tags, searching content...',
        name: 'VideoEvent',
      );
      videoUrl = _extractVideoUrlFromContent(event.content);
      if (videoUrl != null) {
        developer.log(
          '✅ FALLBACK: Found video URL in content: $videoUrl',
          name: 'VideoEvent',
        );
      }
    }

    // Select best video URL from all candidates
    if (videoUrlCandidates.isNotEmpty) {
      videoUrl = _selectBestVideoUrl(videoUrlCandidates);
      developer.log(
        '🎯 Selected best video URL from ${videoUrlCandidates.length} candidates: $videoUrl',
        name: 'VideoEvent',
      );
    } else {
      // If no candidates found, use the old fallback method
      developer.log(
        '🔧 FALLBACK: No URL candidates found, searching all tags for any potential video URL...',
        name: 'VideoEvent',
      );
      videoUrl = _findAnyVideoUrlInTags(event.tags);
      if (videoUrl != null) {
        developer.log(
          '✅ FALLBACK: Found potential video URL in tags: $videoUrl',
          name: 'VideoEvent',
        );
      }
    }

    // Note: Removed Classic Vine hardening that was forcing api.openvine.co URLs
    // The URL selection logic above now properly handles cdn.divine.video URLs from imeta tags

    // If we still have a broken apt.openvine.co URL (shouldn't happen now), fix it
    if (videoUrl?.contains('apt.openvine.co') == true) {
      final fixedUrl = videoUrl!.replaceAll(
        'apt.openvine.co',
        'api.openvine.co',
      );
      developer.log(
        '🔧 FINAL FIX: Corrected remaining apt.openvine.co to api.openvine.co: $fixedUrl',
        name: 'VideoEvent',
      );
      videoUrl = fixedUrl;
    }

    developer.log(
      '🔍 DEBUG: hasVideo = ${videoUrl != null && videoUrl.isNotEmpty}',
      name: 'VideoEvent',
    );

    // Use 'd' tag if available, otherwise fallback to event ID
    // Many relays don't include 'd' tags on NIP-71 addressable events
    if (vineId == null || vineId.isEmpty) {
      developer.log(
        '⚠️ WARNING: NIP-71 addressable event missing "d" tag, using event ID as fallback',
        name: 'VideoEvent',
      );
      vineId = event.id; // Use event ID as unique identifier
    }

    // DEBUG: Log full event for cdn.divine.video thumbnails
    if (thumbnailUrl != null && thumbnailUrl!.contains('cdn.divine.video')) {
      developer.log(
        '🔍 DEBUG cdn.divine.video thumbnail found!',
        name: 'VideoEvent',
      );
      developer.log('🔍 Event ID: ${event.id}', name: 'VideoEvent');
      developer.log('🔍 Event Kind: ${event.kind}', name: 'VideoEvent');
      developer.log('🔍 Event Pubkey: ${event.pubkey}', name: 'VideoEvent');
      developer.log('🔍 Thumbnail URL: $thumbnailUrl', name: 'VideoEvent');
      developer.log('🔍 Video URL: $videoUrl', name: 'VideoEvent');
      developer.log('🔍 Full Event Tags JSON:', name: 'VideoEvent');
      for (var i = 0; i < event.tags.length; i++) {
        developer.log('🔍   Tag[$i]: ${event.tags[i]}', name: 'VideoEvent');
      }
      developer.log('🔍 Event Content: ${event.content}', name: 'VideoEvent');
      developer.log(
        '🔍 Event CreatedAt: ${event.createdAt}',
        name: 'VideoEvent',
      );
    }

    // Generate fallback thumbnail URL if none provided
    developer.log('🖼️ Thumbnail URL: $thumbnailUrl', name: 'VideoEvent');
    final String? finalThumbnailUrl =
        thumbnailUrl ?? _generateFallbackThumbnailUrl(videoUrl, event.id);

    if (finalThumbnailUrl != thumbnailUrl) {
      developer.log(
        '🔧 FALLBACK: Generated thumbnail URL: $finalThumbnailUrl',
        name: 'VideoEvent',
      );
    }

    return VideoEvent(
      id: event.id,
      pubkey: event.pubkey,
      createdAt: createdAtTimestamp,
      content: event.content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp * 1000),
      title: title,
      videoUrl: videoUrl,
      thumbnailUrl: finalThumbnailUrl,
      duration: duration,
      dimensions: dimensions,
      mimeType: mimeType,
      sha256: sha256,
      fileSize: fileSize,
      hashtags: hashtags,
      publishedAt: publishedAt,
      rawTags: tags,
      vineId: vineId,
      group: group,
      altText: altText,
      blurhash: blurhash,
      isRepost: false,
      reposterId: null,
      reposterPubkey: null,
      repostedAt: null,
      originalLoops: originalLoops,
      originalLikes: originalLikes,
      originalComments: originalComments,
      originalReposts: originalReposts,
      expirationTimestamp: expirationTimestamp,
    );
  }
  final String id;
  final String pubkey;
  final int createdAt;
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
  final DateTime timestamp;
  final String? publishedAt;
  final Map<String, String> rawTags;

  // Vine-specific fields from NIP-71 spec
  final String? vineId; // 'd' tag - original vine ID for replaceable events
  final String? group; // 'h' tag - group/community identification
  final String? altText; // 'alt' tag - accessibility text
  final String? blurhash; // 'blurhash' tag - for progressive image loading

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
  final int?
  expirationTimestamp; // NIP-40 expiration timestamp (Unix timestamp in seconds)

  /// NIP-40: Check if this event has expired
  /// Returns true if expiration timestamp is set and current time >= expiration
  bool get isExpired {
    if (expirationTimestamp == null) return false;
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return nowTimestamp >= expirationTimestamp!;
  }

  /// ProofMode: Get verification level from tags (NIP-145)
  String? get proofModeVerificationLevel {
    return rawTags['verification'];
  }

  /// ProofMode: Get proof manifest from tags (NIP-145)
  String? get proofModeManifest {
    return rawTags['proofmode'];
  }

  /// ProofMode: Get device attestation from tags (NIP-145)
  String? get proofModeDeviceAttestation {
    return rawTags['device_attestation'];
  }

  /// ProofMode: Get PGP public key fingerprint from tags (NIP-145)
  String? get proofModePgpFingerprint {
    return rawTags['pgp_fingerprint'];
  }

  /// ProofMode: Check if video has any proof
  bool get hasProofMode {
    return proofModeVerificationLevel != null ||
        proofModeManifest != null ||
        proofModePgpFingerprint != null;
  }

  /// ProofMode: Check if video is verified mobile (highest level)
  bool get isVerifiedMobile {
    return proofModeVerificationLevel == 'verified_mobile';
  }

  /// ProofMode: Check if video is verified web (medium level)
  bool get isVerifiedWeb {
    return proofModeVerificationLevel == 'verified_web';
  }

  /// ProofMode: Check if video has basic proof (low level)
  bool get hasBasicProof {
    return proofModeVerificationLevel == 'basic_proof';
  }

  /// Original Vine: Check if this is a recovered original vine
  bool get isOriginalVine {
    return originalLoops != null && originalLoops! > 0;
  }

  /// Check if this is original content (not a repost)
  bool get isOriginalContent {
    return !isRepost;
  }

  /// Check if we should show the Original Content badge
  /// Show for original content that is NOT a vintage recovered vine
  /// AND does NOT have ProofMode verification (those show ProofMode badge instead)
  bool get shouldShowOriginalBadge {
    return isOriginalContent && !isOriginalVine && !hasProofMode;
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

  /// Enhanced comparator that combines multiple engagement metrics
  /// Uses embedded metrics from imported vine data
  /// Priority based on combined engagement: loops + (comments * 3) + (likes * 2) + (reposts * 2.5)
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

    // Final tiebreaker: created_at (though most will have same timestamp from import)
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
    double score = 0.0;
    score += loops * 1.0; // Base weight for views/loops
    score += comments * 3.0; // Comments show high engagement
    score += likes * 2.0; // Likes show appreciation
    score += reposts * 2.5; // Reposts help spread content

    return score;
  }

  /// Parse imeta tag which contains space-separated key-value pairs
  /// NIP-71 format: ["imeta", "key1 value1", "key2 value2", ...]
  static void _parseImetaTag(
    List<String> tag,
    void Function(String key, String value) onKeyValue,
  ) {
    // Skip the first element which is "imeta"
    // Support TWO formats:
    // 1. OLD: ["imeta", "url https://...", "m video/mp4", ...]  (space-separated key-value)
    // 2. NEW: ["imeta", "url", "https://...", "m", "video/mp4", ...] (positional key-value pairs)

    // Detect format by checking if tag[1] contains a space
    if (tag.length > 1) {
      final firstElement = tag[1];
      final hasSpace = firstElement.contains(' ');

      if (hasSpace) {
        // OLD FORMAT: space-separated key-value within each element
        for (var i = 1; i < tag.length; i++) {
          final element = tag[i];
          final spaceIndex = element.indexOf(' ');
          if (spaceIndex > 0) {
            final key = element.substring(0, spaceIndex);
            final value = element.substring(spaceIndex + 1);
            onKeyValue(key, value);
          }
        }
      } else {
        // NEW FORMAT: positional key-value pairs (tag[i] is key, tag[i+1] is value)
        for (var i = 1; i < tag.length - 1; i += 2) {
          final key = tag[i];
          final value = tag[i + 1];
          onKeyValue(key, value);
        }
      }
    }
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

  /// Get relative time string (e.g., "2 hours ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }

  /// Get pubkey for display
  String get displayPubkey {
    return pubkey;
  }

  /// Check if this event has video content
  bool get hasVideo => videoUrl?.isNotEmpty ?? false;

  /// Get effective thumbnail URL with fallback generation
  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }

    // NO MORE FAKE PICSUM SHIT!
    // Return null so we use proper video icon placeholder
    return null;
  }

  /// Get thumbnail URL from API service with automatic generation
  /// This method provides an async fallback that generates thumbnails when missing
  Future<String?> getApiThumbnailUrl({
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) async {
    // First check if we already have a thumbnail URL
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl;
    }

    // Use the new thumbnail API service for automatic generation
    return ThumbnailApiService.getThumbnailWithFallback(
      id,
      timeSeconds: timeSeconds,
      size: size,
    );
  }

  /// Get thumbnail URL synchronously from API service (no generation)
  /// This method provides immediate URL construction without async calls
  String getApiThumbnailUrlSync({
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) {
    // First check if we already have a thumbnail URL
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return thumbnailUrl!;
    }

    // Generate API URL (may or may not exist, but provides proper fallback)
    return ThumbnailApiService.getThumbnailUrl(
      id,
      timeSeconds: timeSeconds,
      size: size,
    );
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

  /// Check if video format is supported on current platform
  /// WebM is not supported on iOS/macOS (AVPlayer limitation)
  bool get isSupportedOnCurrentPlatform {
    // WebM only works on Android and Web, not iOS/macOS
    if (isWebM) {
      return !Platform.isIOS && !Platform.isMacOS;
    }
    // All other formats (MP4, MOV, M4V, HLS) work on all platforms
    return true;
  }

  /// Create a copy with updated fields
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
    DateTime? timestamp,
    String? publishedAt,
    Map<String, String>? rawTags,
    String? vineId,
    String? group,
    String? altText,
    String? blurhash,
    bool? isRepost,
    String? reposterId,
    String? reposterPubkey,
    List<String>? reposterPubkeys,
    DateTime? repostedAt,
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
    timestamp: timestamp ?? this.timestamp,
    publishedAt: publishedAt ?? this.publishedAt,
    rawTags: rawTags ?? this.rawTags,
    vineId: vineId ?? this.vineId,
    group: group ?? this.group,
    altText: altText ?? this.altText,
    blurhash: blurhash ?? this.blurhash,
    isRepost: isRepost ?? this.isRepost,
    reposterId: reposterId ?? this.reposterId,
    reposterPubkey: reposterPubkey ?? this.reposterPubkey,
    reposterPubkeys: reposterPubkeys ?? this.reposterPubkeys,
    repostedAt: repostedAt ?? this.repostedAt,
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
      'time: $relativeTime'
      ')';

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

  /// Check if a URL is a valid video URL
  static bool _isValidVideoUrl(String url) {
    if (url.isEmpty) return false;

    // Fix common typo: apt.openvine.co -> api.openvine.co
    String correctedUrl = url;
    if (url.contains('apt.openvine.co')) {
      correctedUrl = url.replaceAll('apt.openvine.co', 'api.openvine.co');
    }

    try {
      final uri = Uri.parse(correctedUrl);

      // Must be HTTP or HTTPS
      if (!['http', 'https'].contains(uri.scheme.toLowerCase())) {
        return false;
      }

      // Must have a valid host
      if (uri.host.isEmpty) return false;

      // Accept any valid HTTP/HTTPS URL
      // This is an open protocol - people can host videos anywhere
      // The video player will determine if it can actually play the content
      return true;
    } catch (e) {
      developer.log(
        '🔍 INVALID URL (parse error): $correctedUrl - error: $e',
        name: 'VideoEvent',
      );
      return false;
    }
  }

  /// Score video URL by format preference
  /// Higher scores = better format preference
  /// For short videos (6 seconds): MP4 is ALWAYS better than HLS
  /// - MP4: Single file, fast download, universal support
  /// - HLS: Manifest + segments, slower, overkill for short videos
  static int _scoreVideoUrl(String url) {
    final urlLower = url.toLowerCase();

    // Reject broken vine.co URLs immediately (but NOT openvine.co, divine.video, etc.)
    // Only reject URLs that are ACTUALLY from the dead vine.co domain
    if (urlLower.contains('//vine.co/') ||
        urlLower.contains('//www.vine.co/') ||
        urlLower.startsWith('vine.co/'))
      return -1;

    // POSTEL'S LAW: Deprioritize known broken URL patterns
    // The cdn.divine.video/*/manifest/video.m3u8 pattern is often broken
    // Prefer stream.divine.video HLS or direct MP4 files
    if (urlLower.contains('cdn.divine.video') &&
        urlLower.contains('/manifest/'))
      return 5;

    // ALWAYS prefer MP4 over HLS for short videos (6 seconds)
    // HLS adaptive bitrate is pointless for content this short
    // MP4 is simpler, faster (single file vs manifest + segments)

    // Direct MP4 from cdn.divine.video (blob storage) - highest priority
    if (urlLower.contains('.mp4') && urlLower.contains('cdn.divine.video'))
      return 115;

    // Any other MP4 - still preferred
    if (urlLower.contains('.mp4')) return 110;

    // BunnyStream HLS (stream.divine.video) - reliable streaming
    if (urlLower.contains('.m3u8') && urlLower.contains('stream.divine.video'))
      return 105;

    // Generic HLS fallback
    if (urlLower.contains('.m3u8') || urlLower.contains('hls')) return 100;

    // WebM is good for web
    if (urlLower.contains('.webm')) return 90;

    // MOV is decent but large
    if (urlLower.contains('.mov')) return 70;

    // AVI is supported but not optimal
    if (urlLower.contains('.avi')) return 60;

    // DASH can be problematic
    if (urlLower.contains('.mpd') || urlLower.contains('dash')) return 10;

    // Generic URLs get medium priority
    return 50;
  }

  /// Select the best video URL from multiple candidates
  static String? _selectBestVideoUrl(List<String> candidates) {
    if (candidates.isEmpty) return null;

    // Score all candidates and pick the highest scoring one
    String? bestUrl;
    int bestScore = -1;

    for (final url in candidates) {
      final isValid = _isValidVideoUrl(url);
      if (isValid) {
        final score = _scoreVideoUrl(url);
        developer.log('🎯 URL score: $score for $url', name: 'VideoEvent');
        if (score > bestScore) {
          bestScore = score;
          bestUrl = url;
        }
      }
    }

    if (bestUrl != null) {
      developer.log(
        '✅ Selected best video URL (score: $bestScore): $bestUrl',
        name: 'VideoEvent',
      );
    }

    return bestUrl;
  }

  /// Extract video URL from event content text (fallback strategy)
  static String? _extractVideoUrlFromContent(String content) {
    // Look for URLs in the content using regex
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(content);

    for (final match in matches) {
      var url = match.group(0);
      if (url != null) {
        // Fix common typo: apt.openvine.co -> api.openvine.co
        if (url.contains('apt.openvine.co')) {
          url = url.replaceAll('apt.openvine.co', 'api.openvine.co');
        }
        if (_isValidVideoUrl(url)) {
          return url;
        }
      }
    }

    return null;
  }

  /// Find any potential video URL in all tags (aggressive fallback)
  static String? _findAnyVideoUrlInTags(List<dynamic> tags) {
    for (final tagRaw in tags) {
      if (tagRaw is! List || tagRaw.isEmpty) continue;

      final tag = tagRaw.map((e) => e.toString()).toList();

      // Check all tag values for potential URLs
      for (var i = 1; i < tag.length; i++) {
        var value = tag[i];
        if (value.isNotEmpty) {
          // Fix common typo: apt.openvine.co -> api.openvine.co
          if (value.contains('apt.openvine.co')) {
            value = value.replaceAll('apt.openvine.co', 'api.openvine.co');
          }
          if (_isValidVideoUrl(value)) {
            return value;
          }
        }
      }
    }

    return null;
  }

  /// Generate fallback thumbnail URL when none is provided
  static String? _generateFallbackThumbnailUrl(
    String? videoUrl,
    String eventId,
  ) {
    // If no video URL, can't generate thumbnail
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    // Fix common typo: apt.openvine.co -> api.openvine.co
    String correctedUrl = videoUrl;
    if (videoUrl.contains('apt.openvine.co')) {
      correctedUrl = videoUrl.replaceAll('apt.openvine.co', 'api.openvine.co');
    }

    try {
      final uri = Uri.parse(correctedUrl);

      // For api.openvine.co videos, use the thumbnail API service
      if (uri.host.contains('api.openvine.co') ||
          uri.host.contains('apt.openvine.co')) {
        // Extract video ID from path like /media/12345
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty &&
            pathSegments.first == 'media' &&
            pathSegments.length > 1) {
          final videoId = pathSegments[1];
          return ThumbnailApiService.getThumbnailUrl(videoId);
        }
      }

      // For other video hosts, try to generate a thumbnail URL pattern
      if (uri.host.contains('blossom.primal.net') ||
          uri.host.contains('primal.net')) {
        // Primal uses a thumbnail service with .jpg extension
        final videoPath = uri.path;
        if (videoPath.endsWith('.mp4')) {
          final basePath = videoPath.substring(0, videoPath.length - 4);
          return 'https://${uri.host}$basePath.jpg';
        }
      }

      // For nostr.build, they have a thumbnail pattern
      if (uri.host.contains('nostr.build')) {
        final videoPath = uri.path;
        if (videoPath.contains('/av/')) {
          // nostr.build thumbnail pattern: replace /av/ with /i/ and change extension
          final thumbnailPath = videoPath
              .replaceAll('/av/', '/i/')
              .replaceAll('.mp4', '.jpg');
          return 'https://${uri.host}$thumbnailPath';
        }
      }

      developer.log(
        '🔧 FALLBACK: Could not generate thumbnail URL for video host: ${uri.host}',
        name: 'VideoEvent',
      );
      return null;
    } catch (e) {
      developer.log(
        '🔧 FALLBACK: Error generating thumbnail URL: $e',
        name: 'VideoEvent',
      );
      return null;
    }
  }

  /// Resolve m3u8 URLs to direct MP4 URLs for better playback
  ///
  /// For short videos, HLS adaptive streaming is overkill. This method:
  /// 1. Checks if videoUrl is an m3u8 playlist
  /// 2. If so, fetches and parses the playlist
  /// 3. Returns the lowest bandwidth MP4 variant
  /// 4. Otherwise returns the original videoUrl
  ///
  /// Returns the best playable URL (either resolved MP4 or original URL)
  /// Returns null if resolution fails
  static Future<String?> resolvePlayableUrl(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    // Check if this is an m3u8 URL
    final urlLower = videoUrl.toLowerCase();
    if (!urlLower.contains('.m3u8') && !urlLower.contains('/hls/')) {
      // Not an m3u8 URL, return as-is
      return videoUrl;
    }

    developer.log(
      '🎬 Attempting to resolve m3u8 URL to MP4: $videoUrl',
      name: 'VideoEvent',
    );

    // Try to resolve to MP4
    final resolver = M3u8ResolverService();
    final resolvedUrl = await resolver.resolveM3u8ToMp4(videoUrl);

    if (resolvedUrl != null) {
      developer.log('✅ Resolved m3u8 to MP4: $resolvedUrl', name: 'VideoEvent');
      return resolvedUrl;
    } else {
      developer.log(
        '⚠️ Failed to resolve m3u8, using original URL: $videoUrl',
        name: 'VideoEvent',
      );
      return videoUrl; // Fallback to original if resolution fails
    }
  }

  /// Get the best playable URL for this video
  ///
  /// This is an async convenience method that resolves m3u8 URLs to MP4.
  /// Use this when preparing to play a video.
  Future<String?> getPlayableUrl() async {
    return resolvePlayableUrl(videoUrl);
  }
}

/// Exception thrown when parsing video events
class VideoEventException implements Exception {
  const VideoEventException(this.message);
  final String message;

  @override
  String toString() => 'VideoEventException: $message';
}
