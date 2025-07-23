// ABOUTME: Test data builder for creating Nostr event instances for testing
// ABOUTME: Supports all event types used in OpenVine with proper tag structures

import 'dart:convert';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Builder class for creating test Nostr events
class NostrEventBuilder {
  NostrEventBuilder({
    String? id,
    this.pubkey = 'test-pubkey',
    int? createdAt,
    this.kind = 1,
    List<List<String>>? tags,
    this.content = '',
    String? sig,
  })  : id = id ?? _generateEventId(),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        tags = tags ??
            [
              ['h', 'vine']
            ], // Always include vine tag
        sig = sig ?? _generateSignature();
  String id;
  String pubkey;
  int createdAt;
  int kind;
  List<List<String>> tags;
  String content;
  String sig;

  static String _generateEventId() =>
      DateTime.now().millisecondsSinceEpoch.toString();

  static String _generateSignature() =>
      'test-signature-${DateTime.now().millisecondsSinceEpoch}';

  /// Build the Event instance
  Event build() => Event(
        id,
        kind,
        tags,
        content,
      );

  /// Create a profile event (Kind 0)
  NostrEventBuilder profile({
    required String name,
    String? displayName,
    String? picture,
    String? about,
  }) {
    kind = 0;
    final profileData = {
      'name': name,
      if (displayName != null) 'display_name': displayName,
      if (picture != null) 'picture': picture,
      if (about != null) 'about': about,
    };
    content = jsonEncode(profileData);
    return this;
  }

  /// Create a text note event (Kind 1)
  NostrEventBuilder textNote(String text) {
    kind = 1;
    content = text;
    return this;
  }

  /// Create a contact list event (Kind 3)
  NostrEventBuilder contactList(List<String> pubkeys) {
    kind = 3;
    tags = [
      ['h', 'vine'],
      ...pubkeys.map((p) => ['p', p]),
    ];
    return this;
  }

  /// Create a repost event (Kind 6)
  NostrEventBuilder repost({
    required String originalEventId,
    required String originalPubkey,
  }) {
    kind = 6;
    tags = [
      ['h', 'vine'],
      ['e', originalEventId],
      ['p', originalPubkey],
    ];
    return this;
  }

  /// Create a reaction event (Kind 7)
  NostrEventBuilder reaction({
    required String targetEventId,
    required String targetPubkey,
    String emoji = '❤️',
  }) {
    kind = 7;
    content = emoji;
    tags = [
      ['h', 'vine'],
      ['e', targetEventId],
      ['p', targetPubkey],
    ];
    return this;
  }

  /// Create a video event (Kind 22)
  NostrEventBuilder video({
    required String videoUrl,
    String? title,
    String? thumbnailUrl,
    String? gifUrl,
    int duration = 6,
  }) {
    kind = 22;
    final videoData = {
      'url': videoUrl,
      'duration': duration,
      if (title != null) 'title': title,
      if (thumbnailUrl != null) 'thumbnail': thumbnailUrl,
      if (gifUrl != null) 'gif': gifUrl,
    };
    content = jsonEncode(videoData);
    tags = [
      ['h', 'vine'],
      ['url', videoUrl],
      if (title != null) ['title', title],
      ['duration', duration.toString()],
    ];
    return this;
  }

  /// Add custom tags
  NostrEventBuilder withTags(List<List<String>> customTags) {
    // Always ensure vine tag is present
    final hasVineTag = customTags.any(
      (tag) => tag.length >= 2 && tag[0] == 'h' && tag[1] == 'vine',
    );
    if (!hasVineTag) {
      tags = [
        ['h', 'vine'],
        ...customTags
      ];
    } else {
      tags = customTags;
    }
    return this;
  }

  /// Create from a specific user
  NostrEventBuilder fromUser(String userPubkey) {
    pubkey = userPubkey;
    return this;
  }

  /// Set specific timestamp
  NostrEventBuilder at(DateTime dateTime) {
    createdAt = dateTime.millisecondsSinceEpoch ~/ 1000;
    return this;
  }

  /// Create multiple events
  static List<Event> buildMany({
    required int count,
    required int kind,
    String Function(int index)? contentGenerator,
  }) =>
      List.generate(
        count,
        (index) => NostrEventBuilder(
          kind: kind,
          content: contentGenerator?.call(index) ?? 'Event $index',
        ).build(),
      );
}
