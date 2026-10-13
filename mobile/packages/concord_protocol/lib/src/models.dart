// MPL-2.0
import 'dart:convert';

/// Kind for Community List fragments (per delegated task scope).
const int communityListKind = 33302;

/// A chat message; edits/deletes/reactions arrive as control events.
class ChatMessage {
  ChatMessage({
    required this.id,
    required this.channelId,
    required this.author,
    required this.body,
    required this.createdAt,
    this.threadRootId,
    this.expiresAt,
    this.editedBody,
  });
  final String id;
  final String channelId;
  final String author;
  final String body;
  final int createdAt;
  final String? threadRootId;
  final int? expiresAt;
  final String? editedBody;
  String get effectiveBody => editedBody ?? body;
  bool isExpiredAt(int now) => expiresAt != null && now >= expiresAt!;
  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'author': author,
    'body': effectiveBody,
    'createdAt': createdAt,
    if (threadRootId != null) 'threadRootId': threadRootId,
    if (expiresAt != null) 'expiresAt': expiresAt,
  };
}

/// Control event folded over messages: edit, delete, or reaction.
enum ControlType { edit, delete, reaction }

class ControlEvent {
  ControlEvent({
    required this.type,
    required this.targetId,
    required this.createdAt,
    this.body,
    this.emoji,
    this.actor = '',
  });
  final ControlType type;
  final String targetId;
  final int createdAt;
  final String? body;
  final String? emoji;
  final String actor;
}

/// Kind-33302 Community List fragment preserving unknown fields verbatim.
class CommunityListFragment {
  CommunityListFragment(this.raw);
  factory CommunityListFragment.fromJson(Map<String, dynamic> j) =>
      CommunityListFragment(Map<String, dynamic>.from(j));
  factory CommunityListFragment.decode(String s) =>
      CommunityListFragment.fromJson(jsonDecode(s) as Map<String, dynamic>);
  final Map<String, dynamic> raw;
  int get kind => (raw['kind'] as num?)?.toInt() ?? 0;

  /// Decimal fragment coordinate from the d tag; entries hold community ids.
  String get fragmentIndex {
    for (final t in (raw['tags'] as List? ?? [])) {
      if (t is List && t.length > 1 && t[0] == 'd') return '${t[1]}';
    }
    return '';
  }

  String encode() => jsonEncode(raw);
}
