// ABOUTME: Comment model representing a single comment or reply in a video thread
// ABOUTME: Contains metadata for threading, author info, and Nostr event relationships

import 'package:hive_ce/hive.dart';

part 'comment.g.dart';

@HiveType(typeId: 3)
class Comment {
  const Comment({
    required this.id,
    required this.content,
    required this.authorPubkey,
    required this.createdAt,
    required this.rootEventId,
    required this.rootAuthorPubkey,
    this.replyToEventId,
    this.replyToAuthorPubkey,
  });

  /// Hive serialization
  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    content: json['content'] as String,
    authorPubkey: json['authorPubkey'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    rootEventId: json['rootEventId'] as String,
    replyToEventId: json['replyToEventId'] as String?,
    rootAuthorPubkey: json['rootAuthorPubkey'] as String,
    replyToAuthorPubkey: json['replyToAuthorPubkey'] as String?,
  );

  /// Unique comment ID (Nostr event ID)
  @HiveField(0)
  final String id;

  /// Comment text content
  @HiveField(1)
  final String content;

  /// Author's public key (hex format)
  @HiveField(2)
  final String authorPubkey;

  /// When the comment was created
  @HiveField(3)
  final DateTime createdAt;

  /// The root event ID this comment is replying to (usually a video)
  @HiveField(4)
  final String rootEventId;

  /// If this is a reply, the ID of the comment being replied to
  @HiveField(5)
  final String? replyToEventId;

  /// Public key of the root event author
  @HiveField(6)
  final String rootAuthorPubkey;

  /// If this is a reply, the public key of the comment author being replied to
  @HiveField(7)
  final String? replyToAuthorPubkey;

  /// Whether this is a top-level comment (not a reply)
  bool get isTopLevel =>
      replyToEventId == null || replyToEventId == rootEventId;

  /// Whether this is a reply to another comment
  bool get isReply => !isTopLevel;

  /// Get the author's public key for display
  String get shortAuthorPubkey => authorPubkey;

  /// Get relative time string (e.g., "2h ago", "1d ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  /// Create a copy with updated fields
  Comment copyWith({
    String? id,
    String? content,
    String? authorPubkey,
    DateTime? createdAt,
    String? rootEventId,
    String? replyToEventId,
    String? rootAuthorPubkey,
    String? replyToAuthorPubkey,
  }) => Comment(
    id: id ?? this.id,
    content: content ?? this.content,
    authorPubkey: authorPubkey ?? this.authorPubkey,
    createdAt: createdAt ?? this.createdAt,
    rootEventId: rootEventId ?? this.rootEventId,
    replyToEventId: replyToEventId ?? this.replyToEventId,
    rootAuthorPubkey: rootAuthorPubkey ?? this.rootAuthorPubkey,
    replyToAuthorPubkey: replyToAuthorPubkey ?? this.replyToAuthorPubkey,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'authorPubkey': authorPubkey,
    'createdAt': createdAt.toIso8601String(),
    'rootEventId': rootEventId,
    'replyToEventId': replyToEventId,
    'rootAuthorPubkey': rootAuthorPubkey,
    'replyToAuthorPubkey': replyToAuthorPubkey,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Comment(id: $id, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, author: $shortAuthorPubkey)';
}
