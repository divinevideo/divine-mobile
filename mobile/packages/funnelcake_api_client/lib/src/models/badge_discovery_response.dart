import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

/// One indexed badge and its public video previews.
typedef IndexedBadgeCard = ({
  Event definition,
  int holderCount,
  int followerCount,
  List<BadgeVideoPreview> videos,
});

/// Thumbnail metadata for opening a public video by exact event ID.
typedef BadgeVideoPreview = ({
  String id,
  String pubkey,
  String title,
  String thumbnail,
  int createdAt,
  int kind,
  List<List<String>> tags,
  List<String> moderationLabels,
  bool verifiedArchive,
  bool archiveProvenanceAvailable,
});

/// Maximum cards returned in one discovery page.
const badgeDiscoveryPageLimit = 48;

/// Maximum indexed clips on each badge card.
const badgeDiscoveryClipLimit = 3;

/// Largest Unix timestamp representable by Dart's DateTime on every platform.
const _maxPreviewTimestamp = 8640000000000;

/// Parses the bounded discovery page without treating malformed data as empty.
List<IndexedBadgeCard> parseBadgeDiscoveryResponse(Map<String, dynamic> json) {
  final badges = json['badges'] as List<dynamic>;
  if (badges.length > badgeDiscoveryPageLimit) {
    throw const FormatException('Badge discovery page exceeds its limit');
  }
  return badges
      .map((value) {
        final badge = value as Map<String, dynamic>;
        final event = badge['definition'] as Map<String, dynamic>;
        final videos = badge['videos'] as List<dynamic>;
        if (event['sig'] is! String ||
            videos.length > badgeDiscoveryClipLimit) {
          throw const FormatException('Invalid indexed badge card');
        }
        return (
          definition: Event.fromJson(event),
          holderCount: badge['holder_count'] as int,
          followerCount: badge['follower_count'] as int,
          videos: videos
              .map<BadgeVideoPreview?>((value) {
                final video = value as Map<String, dynamic>;
                final createdAt = video['created_at'] as int;
                if (createdAt < 0 || createdAt > _maxPreviewTimestamp) {
                  throw const FormatException(
                    'Invalid badge preview timestamp',
                  );
                }
                final tags = (video['tags'] as List<dynamic>)
                    .map((tag) => List<String>.from(tag as List<dynamic>))
                    .toList(growable: false);
                // VideoEvent uses the last singleton tag, including an empty
                // final tag, and falls back to created_at for nonnumeric text.
                String? publishedAt;
                for (final tag in tags) {
                  if (tag.isNotEmpty && tag.first == 'published_at') {
                    publishedAt = tag.length > 1 ? tag[1] : '';
                  }
                }
                final effectiveTimestamp =
                    int.tryParse(publishedAt ?? '') ?? createdAt;
                if (effectiveTimestamp < -_maxPreviewTimestamp ||
                    effectiveTimestamp > _maxPreviewTimestamp) {
                  Log.warning(
                    'Skipping badge discovery clip ${video['id']} '
                    'with invalid published_at',
                    name: 'FunnelcakeApiClient',
                  );
                  return null;
                }
                return (
                  id: video['id'] as String,
                  pubkey: video['pubkey'] as String,
                  title: video['title'] as String,
                  thumbnail: video['thumbnail'] as String,
                  createdAt: createdAt,
                  kind: video['kind'] as int,
                  moderationLabels: List<String>.from(
                    video['moderation_labels'] as List<dynamic>,
                  ),
                  verifiedArchive: video['verified_archive'] as bool,
                  archiveProvenanceAvailable:
                      video['archive_provenance_available'] as bool,
                  tags: tags,
                );
              })
              .whereType<BadgeVideoPreview>()
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}
