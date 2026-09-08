// ABOUTME: Model for NIP-51 curated video lists (kind 30005).
// ABOUTME: Represents user-created collections with playlist features,
// ABOUTME: collaboration support, and mixed video references
// ABOUTME: (event IDs + addressable coordinates).

import 'package:equatable/equatable.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

/// Ordering options for playlist playback.
enum PlayOrder {
  /// Order by date added (oldest first).
  chronological,

  /// Reverse chronological order (newest first).
  reverse,

  /// Custom manual order set by the user.
  manual,

  /// Randomized order.
  shuffle,
}

/// Serialization helpers for [PlayOrder].
extension PlayOrderExtension on PlayOrder {
  /// Converts this [PlayOrder] to its string representation.
  String get value {
    switch (this) {
      case PlayOrder.chronological:
        return 'chronological';
      case PlayOrder.reverse:
        return 'reverse';
      case PlayOrder.manual:
        return 'manual';
      case PlayOrder.shuffle:
        return 'shuffle';
    }
  }

  /// Parses a string into a [PlayOrder], defaulting to
  /// [PlayOrder.chronological].
  static PlayOrder fromString(String value) {
    switch (value) {
      case 'chronological':
        return PlayOrder.chronological;
      case 'reverse':
        return PlayOrder.reverse;
      case 'manual':
        return PlayOrder.manual;
      case 'shuffle':
        return PlayOrder.shuffle;
      default:
        return PlayOrder.chronological;
    }
  }
}

/// A curated list of videos with playlist features.
///
/// Represents a NIP-51 kind 30005 event containing references to video events.
/// Video references in [videoEventIds] are mixed:
/// - **Event IDs**: 64-character hex strings
/// - **Addressable coordinates**: `kind:pubkey:d-tag` format
///   (NIP-71 kinds 34235 and 34236)
///
/// [isPublic] decides which half of the event carries the references: a
/// public list puts them in `e`/`a` tags, a private one seals them into the
/// event content with NIP-44. Both are published, so both survive a device.
class CuratedList extends Equatable {
  /// Creates a curated list, normalizing [name] and [description] to
  /// well-formed UTF-16.
  ///
  /// Both come from a kind-30005 event that anyone may author — a
  /// collaborative list, or someone else's list surfaced by search — and both
  /// render as plain `Text`. A lone surrogate there throws `Invalid
  /// argument(s): string is not well-formed UTF-16` out of Flutter's
  /// paragraph builder, so the constructor is the display boundary, matching
  /// `UserProfile` and `VideoEvent`.
  CuratedList({
    required this.id,
    required String name,
    required this.videoEventIds,
    required this.createdAt,
    required this.updatedAt,
    this.pubkey,
    String? description,
    this.imageUrl,
    this.isPublic = true,
    this.nostrEventId,
    this.pendingRepublish = false,
    this.tags = const [],
    this.isCollaborative = false,
    this.allowedCollaborators = const [],
    this.thumbnailEventId,
    this.thumbnailUrls = const [],
    this.playOrder = PlayOrder.chronological,
  }) : name = sanitizeUtf16(name),
       description = sanitizeUtf16OrNull(description);

  /// Creates a [CuratedList] from a JSON map.
  factory CuratedList.fromJson(Map<String, dynamic> json) => CuratedList(
    id: json['id'] as String,
    name: json['name'] as String,
    pubkey: json['pubkey'] as String?,
    description: json['description'] as String?,
    imageUrl: json['imageUrl'] as String?,
    videoEventIds: List<String>.from(json['videoEventIds'] as List? ?? []),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    isPublic: json['isPublic'] as bool? ?? true,
    nostrEventId: json['nostrEventId'] as String?,
    pendingRepublish: json['pendingRepublish'] as bool? ?? false,
    tags: List<String>.from(json['tags'] as List? ?? []),
    isCollaborative: json['isCollaborative'] as bool? ?? false,
    allowedCollaborators: List<String>.from(
      json['allowedCollaborators'] as List? ?? [],
    ),
    thumbnailEventId: json['thumbnailEventId'] as String?,
    thumbnailUrls: List<String>.from(json['thumbnailUrls'] as List? ?? []),
    playOrder: PlayOrderExtension.fromString(
      json['playOrder'] as String? ?? 'chronological',
    ),
  );

  /// The list identifier (Nostr d-tag).
  final String id;

  /// Display name of the list.
  final String name;

  /// Creator's public key for attribution.
  final String? pubkey;

  /// Identity across authors. Every account owns a `my_vine_list`, so the
  /// d-tag alone conflates lists from different accounts; a local-only list
  /// has no author yet and keys on its d-tag alone.
  String get authorScopedId => '${pubkey ?? ''}:$id';

  /// Optional description of the list.
  final String? description;

  /// Optional cover image URL.
  final String? imageUrl;

  /// Video references — mixed event IDs (64-char hex) and addressable
  /// coordinates (`kind:pubkey:d-tag`).
  final List<String> videoEventIds;

  /// When the list was created.
  final DateTime createdAt;

  /// When the list was last updated.
  final DateTime updatedAt;

  /// Whether this list's video references are readable by anyone.
  ///
  /// `false` publishes them NIP-44 encrypted to the owner instead of as plain
  /// tags. The event envelope and list metadata stay public either way. A
  /// relay that retained or rejected replacement of an earlier public event
  /// may also continue serving that event's plaintext item tags.
  final bool isPublic;

  /// The Nostr event ID when published to relays.
  final String? nostrEventId;

  /// Whether a local edit failed to publish and should be retried.
  final bool pendingRepublish;

  /// Tags for categorization and discovery.
  final List<String> tags;

  /// Whether others can add videos to this list.
  final bool isCollaborative;

  /// Public keys allowed to collaborate on this list.
  final List<String> allowedCollaborators;

  /// Featured video event ID used as thumbnail.
  final String? thumbnailEventId;

  /// Resolved thumbnail URLs for the first videos in the list.
  ///
  /// Populated by the repository layer after resolving video event IDs
  /// to their thumbnail images. Used by search cards for stacked previews.
  final List<String> thumbnailUrls;

  /// How videos should be ordered during playback.
  final PlayOrder playOrder;

  /// Creates a copy of this list with the given fields replaced.
  ///
  /// Passing `null` leaves a nullable field unchanged. To null one out, set
  /// its `clear*` flag to `true`.
  CuratedList copyWith({
    String? id,
    String? name,
    String? pubkey,
    String? description,
    bool clearDescription = false,
    String? imageUrl,
    List<String>? videoEventIds,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    String? nostrEventId,
    bool clearNostrEventId = false,
    bool? pendingRepublish,
    List<String>? tags,
    bool? isCollaborative,
    List<String>? allowedCollaborators,
    String? thumbnailEventId,
    List<String>? thumbnailUrls,
    PlayOrder? playOrder,
  }) => CuratedList(
    id: id ?? this.id,
    name: name ?? this.name,
    pubkey: pubkey ?? this.pubkey,
    description: clearDescription ? null : description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    videoEventIds: videoEventIds ?? this.videoEventIds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isPublic: isPublic ?? this.isPublic,
    nostrEventId: clearNostrEventId ? null : nostrEventId ?? this.nostrEventId,
    pendingRepublish: pendingRepublish ?? this.pendingRepublish,
    tags: tags ?? this.tags,
    isCollaborative: isCollaborative ?? this.isCollaborative,
    allowedCollaborators: allowedCollaborators ?? this.allowedCollaborators,
    thumbnailEventId: thumbnailEventId ?? this.thumbnailEventId,
    thumbnailUrls: thumbnailUrls ?? this.thumbnailUrls,
    playOrder: playOrder ?? this.playOrder,
  );

  /// Converts this list to a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'pubkey': pubkey,
    'description': description,
    'imageUrl': imageUrl,
    'videoEventIds': videoEventIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
    'nostrEventId': nostrEventId,
    'pendingRepublish': pendingRepublish,
    'tags': tags,
    'isCollaborative': isCollaborative,
    'allowedCollaborators': allowedCollaborators,
    'thumbnailEventId': thumbnailEventId,
    'thumbnailUrls': thumbnailUrls,
    'playOrder': playOrder.value,
  };

  @override
  List<Object?> get props => [
    id,
    name,
    pubkey,
    description,
    imageUrl,
    videoEventIds,
    createdAt,
    updatedAt,
    isPublic,
    nostrEventId,
    pendingRepublish,
    tags,
    isCollaborative,
    allowedCollaborators,
    thumbnailEventId,
    thumbnailUrls,
    playOrder,
  ];
}
