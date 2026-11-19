import 'package:nostr_sdk/nostr_sdk.dart';

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
});

/// Parses the bounded discovery page without treating malformed data as empty.
List<IndexedBadgeCard> parseBadgeDiscoveryResponse(Map<String, dynamic> json) {
  final badges = json['badges'] as List<dynamic>;
  if (badges.length > 48) {
    throw const FormatException('Badge discovery page exceeds its limit');
  }
  return badges
      .map((value) {
        final badge = value as Map<String, dynamic>;
        final event = badge['definition'] as Map<String, dynamic>;
        final videos = badge['videos'] as List<dynamic>;
        if (event['sig'] is! String || videos.length > 3) {
          throw const FormatException('Invalid indexed badge card');
        }
        return (
          definition: Event.fromJson(event),
          holderCount: badge['holder_count'] as int,
          followerCount: badge['follower_count'] as int,
          videos: videos
              .map((value) {
                final video = value as Map<String, dynamic>;
                return (
                  id: video['id'] as String,
                  pubkey: video['pubkey'] as String,
                  title: video['title'] as String,
                  thumbnail: video['thumbnail'] as String,
                );
              })
              .toList(growable: false),
        );
      })
      .toList(growable: false);
}
