// ABOUTME: Extension methods for CuratedList
// ABOUTME: Provides methods to extract event tags for Nostr event creation

import 'package:openvine/services/curated_list_service.dart';

extension CuratedListExt on CuratedList {
  List<List<String>> getEventTags() {
    // Create NIP-51 kind 30005 tags
    final tags = <List<String>>[
      ['d', id], // Identifier for replaceable event
      ['title', name],
      ['client', 'diVine'],
    ];

    // Add description if present
    if (description != null && description!.isNotEmpty) {
      tags.add(['description', description!]);
    }

    // Add image if present
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      tags.add(['image', imageUrl!]);
    }

    // Add tags for categorization
    for (final tag in this.tags) {
      tags.add(['t', tag]);
    }

    // Add collaboration settings
    if (isCollaborative) {
      tags.add(['collaborative', 'true']);
      for (final collaborator in allowedCollaborators) {
        tags.add(['collaborator', collaborator]);
      }
    }

    // Add thumbnail if present
    if (thumbnailEventId != null) {
      tags.add(['thumbnail', thumbnailEventId!]);
    }

    // Add play order setting
    tags.add(['playorder', playOrder.value]);

    // Add video events as 'e' tags
    for (final videoEventId in videoEventIds) {
      tags.add(['e', videoEventId]);
    }

    return tags;
  }
}
