// ABOUTME: Model for NIP-51 video curation sets (kind 30005)
// ABOUTME: Represents curated collections of videos with metadata and referenced video events

import 'package:nostr_sdk/event.dart';

/// NIP-51 Video Curation Set
/// Kind 30005: Groups of videos picked by users as interesting and/or belonging to the same category
class CurationSet {
  // Should be 30005 for video curation sets

  const CurationSet({
    required this.id,
    required this.curatorPubkey,
    required this.videoIds,
    required this.createdAt,
    this.title,
    this.description,
    this.imageUrl,
    this.eventKind = 30005,
  });

  /// Create CurationSet from Nostr event
  factory CurationSet.fromNostrEvent(Event event) {
    if (event.kind != 30005) {
      throw ArgumentError(
        'Invalid event kind for video curation set: ${event.kind}',
      );
    }

    String? setId;
    String? title;
    String? description;
    String? imageUrl;
    final videoIds = <String>[];

    // Parse tags
    for (final tag in event.tags) {
      final tagList = tag as List<dynamic>;
      if (tagList.isEmpty) continue;

      switch (tagList[0]) {
        case 'd':
          if (tagList.length > 1) setId = tagList[1] as String?;
        case 'title':
          if (tagList.length > 1) title = tagList[1] as String?;
        case 'description':
          if (tagList.length > 1) description = tagList[1] as String?;
        case 'image':
          if (tagList.length > 1) imageUrl = tagList[1] as String?;
        case 'a':
          // Video reference: "a", "kind:pubkey:identifier"
          if (tagList.length > 1) {
            final parts = (tagList[1] as String).split(':');
            if (parts.length >= 3 &&
                (parts[0] == '22' ||
                    parts[0] == '34236' ||
                    parts[0] == '34235')) {
              // NIP-71 video events (kind 22, 34236, 34235)
              // For addressable references, we need the full coordinate
              // Format: kind:pubkey:d-tag
              final coordinate = tagList[1] as String;
              videoIds.add(coordinate);
            }
          }
        case 'e':
          // Direct event reference
          if (tagList.length > 1) {
            videoIds.add(tagList[1] as String);
          }
      }
    }

    return CurationSet(
      id: setId ?? 'unnamed',
      curatorPubkey: event.pubkey,
      title: title,
      description: description,
      imageUrl: imageUrl,
      videoIds: videoIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000),
    );
  }
  final String id; // "d" tag identifier
  final String curatorPubkey; // Public key of the curator
  final String? title; // Optional title
  final String? description; // Optional description
  final String? imageUrl; // Optional cover image
  final List<String> videoIds; // List of video event IDs (from "a" tags)
  final DateTime createdAt;
  final int eventKind;

  /// Convert to Nostr event for publishing
  Event toNostrEvent() {
    final tags = <List<String>>[
      ['d', id],
    ];

    if (title != null) tags.add(['title', title!]);
    if (description != null) tags.add(['description', description!]);
    if (imageUrl != null) tags.add(['image', imageUrl!]);

    // Add video references as "a" tags
    for (final videoId in videoIds) {
      // Assuming videos are kind 22 (NIP-71)
      tags.add(['a', '22:$curatorPubkey:$videoId']);
    }

    return Event(
      curatorPubkey,
      eventKind,
      tags,
      description ?? '',
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
    );
  }

  @override
  String toString() =>
      'CurationSet(id: $id, title: $title, curator: $curatorPubkey, videos: ${videoIds.length})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurationSet &&
        other.id == id &&
        other.curatorPubkey == curatorPubkey;
  }

  @override
  int get hashCode => Object.hash(id, curatorPubkey);
}

/// Predefined curation set types for divine
enum CurationSetType {
  editorsPicks(
    'editors_picks',
    "Editor's Picks",
    'Curated collection from divine',
  ),
  trending(
    'trending',
    'Trending',
    'Videos getting the most likes and shares right now',
  );

  const CurationSetType(this.id, this.displayName, this.description);

  final String id;
  final String displayName;
  final String description;
}

/// Sample curation sets for development/testing
class SampleCurationSets {
  static final List<CurationSet> _sampleSets = [
    CurationSet(
      id: CurationSetType.editorsPicks.id,
      curatorPubkey:
          '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
      title: CurationSetType.editorsPicks.displayName,
      description: CurationSetType.editorsPicks.description,
      imageUrl: 'https://example.com/editors-picks.jpg',
      videoIds: [], // Will be populated with actual video IDs
      createdAt: DateTime.now(),
    ),
    CurationSet(
      id: CurationSetType.trending.id,
      curatorPubkey:
          '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
      title: CurationSetType.trending.displayName,
      description: CurationSetType.trending.description,
      imageUrl: 'https://example.com/trending.jpg',
      videoIds: [], // Will be populated with actual video IDs
      createdAt: DateTime.now(),
    ),
  ];

  static List<CurationSet> get all => List.unmodifiable(_sampleSets);

  static CurationSet? getById(String id) {
    try {
      return _sampleSets.firstWhere((set) => set.id == id);
    } catch (e) {
      return null;
    }
  }

  static CurationSet? getByType(CurationSetType type) => getById(type.id);
}
