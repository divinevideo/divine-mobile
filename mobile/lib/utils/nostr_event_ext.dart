// ABOUTME: Extension methods for Nostr Event
// ABOUTME: Provides methods to convert Nostr Event to CuratedList

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/curated_list_service.dart';

extension NostrEventExt on Event {
  CuratedList toCuratedList() {
    // Extract list metadata from tags
    String? dTag;
    String? title;
    String? description;
    String? imageUrl;
    String? thumbnailEventId;
    String? playOrderStr;
    final tags = <String>[];
    final videoEventIds = <String>[];
    bool isCollaborative = false;
    final allowedCollaborators = <String>[];

    for (final tag in this.tags) {
      if (tag.isEmpty) continue;

      switch (tag[0]) {
        case 'd':
          if (tag.length > 1) dTag = tag[1];
        case 'title':
          if (tag.length > 1) title = tag[1];
        case 'description':
          if (tag.length > 1) description = tag[1];
        case 'image':
          if (tag.length > 1) imageUrl = tag[1];
        case 'thumbnail':
          if (tag.length > 1) thumbnailEventId = tag[1];
        case 'playorder':
          if (tag.length > 1) playOrderStr = tag[1];
        case 't':
          if (tag.length > 1) tags.add(tag[1]);
        case 'e':
          if (tag.length > 1) videoEventIds.add(tag[1]);
        case 'collaborative':
          if (tag.length > 1 && tag[1] == 'true') isCollaborative = true;
        case 'collaborator':
          if (tag.length > 1) allowedCollaborators.add(tag[1]);
      }
    }

    if (dTag == null) {
      throw Exception('List event missing d tag: $id');
    }

    // Use title or fall back to content or default
    final contentFirstLine = content.split('\n').first;
    final name =
        title ??
        (contentFirstLine.isNotEmpty ? contentFirstLine : 'Untitled List');

    return CuratedList(
      id: dTag,
      name: name,
      description: description ?? content,
      imageUrl: imageUrl,
      videoEventIds: videoEventIds,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      isPublic: true, // Lists from relays are public
      nostrEventId: id,
      tags: tags,
      isCollaborative: isCollaborative,
      allowedCollaborators: allowedCollaborators,
      thumbnailEventId: thumbnailEventId,
      playOrder: playOrderStr != null
          ? PlayOrderExtension.fromString(playOrderStr)
          : PlayOrder.chronological,
    );
  }
}
