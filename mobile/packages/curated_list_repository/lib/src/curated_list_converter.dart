// ABOUTME: Converts between Nostr events and CuratedList models.
// ABOUTME: Handles NIP-51 kind 30005 parsing including e-tags and
// ABOUTME: a-tags for addressable video references (NIP-71).

import 'dart:convert';

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, NIP04, NIP44V2;

/// NIP-71 addressable video kind numbers accepted in `a` tags.
const Set<int> _nip71AddressableVideoKinds = {
  NIP71VideoKinds.addressableNormalVideo,
  NIP71VideoKinds.addressableShortVideo,
};

/// Utility for converting between Nostr events and [CuratedList] models.
///
/// Handles NIP-51 kind 30005 event parsing, including:
/// - `e` tags for event ID video references
/// - `a` tags for addressable video references (NIP-71 kinds)
/// - Metadata tags: title, description, image, thumbnail, playorder
/// - Collaboration tags: collaborative, collaborator
abstract final class CuratedListConverter {
  /// Selects the newest revision of each author's d-tag before decoding.
  /// Equal timestamps use the lowest event ID, as for Nostr replaceable events.
  static List<Event> latestRevisions(List<Event> events) {
    final latest = <String, Event>{};
    for (final event in events) {
      final dTag = extractDTag(event);
      if (dTag == null) continue;
      final coordinate = '${event.pubkey}:$dTag';
      final previous = latest[coordinate];
      if (previous == null ||
          event.createdAt > previous.createdAt ||
          (event.createdAt == previous.createdAt &&
              event.id.compareTo(previous.id) < 0)) {
        latest[coordinate] = event;
      }
    }
    return latest.values.toList();
  }

  /// Preserves both device copies of an unpublished owned coordinate.
  /// The caller persists this private-preferred union before backfilling it.
  static CuratedList mergeUnpublished(
    CuratedList local,
    CuratedList relay, {
    required DateTime mergedAt,
  }) {
    final relayIsNewer =
        relay.updatedAt.millisecondsSinceEpoch ~/ 1000 >
        local.updatedAt.millisecondsSinceEpoch ~/ 1000;
    final preferred = relayIsNewer ? relay : local;
    final other = relayIsNewer ? local : relay;
    final items = <String>{...preferred.videoEventIds, ...other.videoEventIds};
    final isPublic = local.isPublic && relay.isPublic;
    final collaborative = local.isCollaborative || relay.isCollaborative;
    final privacyConflict = !isPublic && collaborative;
    final isCollaborative = collaborative && !privacyConflict;
    return preferred.copyWith(
      pubkey: relay.pubkey,
      videoEventIds: items.toList(growable: false),
      createdAt: local.createdAt,
      updatedAt: mergedAt,
      isCollaborative: isCollaborative,
      allowedCollaborators: privacyConflict
          ? const []
          : {
              ...local.allowedCollaborators,
              ...relay.allowedCollaborators,
            }.toList(growable: false),
      isPublic: isPublic,
      clearNostrEventId: true,
      pendingRepublish: false,
      pendingPlaintextEventIds: {
        ...local.pendingPlaintextEventIds,
        if (relay.isPublic && !isPublic && relay.nostrEventId != null)
          relay.nostrEventId!,
      }.toList(growable: false),
    );
  }

  /// Parses a Nostr [Event] into a [CuratedList].
  ///
  /// Returns `null` if the event cannot be parsed (e.g. missing d-tag).
  ///
  /// [privateTags] carries the item tags a caller decrypted out of
  /// [Event.content] for a NIP-51 private list. Passing them appends their
  /// references to [CuratedList.videoEventIds]. When [isPrivateEvent] is not
  /// supplied, a list is treated as private whenever it either has decrypted
  /// private tags or has the NIP-51 sealed-item shape: item tags omitted from
  /// public tags and non-empty content.
  static CuratedList? fromEvent(
    Event event, {
    List<List<String>>? privateTags,
    bool? isPrivateEvent,
  }) {
    try {
      final dTag = extractDTag(event);
      if (dTag == null) return null;

      String? title;
      String? description;
      String? imageUrl;
      String? thumbnailEventId;
      String? playOrderStr;
      final tags = <String>[];
      final videoEventIds = <String>[];
      var isCollaborative = false;
      final allowedCollaborators = <String>[];

      final eventTags = event.tags
          .map((dynamic tag) => (tag as List<dynamic>).cast<String>())
          .toList(growable: false);
      final isPrivate =
          isPrivateEvent ??
          (privateTags != null ||
              _hasSealedItemShape(eventTags, event.content));
      final rawTags = [...eventTags, ...?privateTags];

      for (final tag in rawTags) {
        if (tag.isEmpty) continue;

        switch (tag[0]) {
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
          case 'a':
            if (tag.length > 1 && _isAddressableVideoReference(tag[1])) {
              videoEventIds.add(tag[1]);
            }
          case 'collaborative':
            if (tag.length > 1 && tag[1] == 'true') {
              isCollaborative = true;
            }
          case 'collaborator':
            if (tag.length > 1) allowedCollaborators.add(tag[1]);
        }
      }

      // Use title, fall back to first line of content, then default. A
      // private list's content is ciphertext, so it is never borrowed.
      final contentFirstLine = isPrivate ? '' : event.content.split('\n').first;
      final name =
          title ??
          (contentFirstLine.isNotEmpty ? contentFirstLine : 'Untitled List');

      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        event.createdAt * 1000,
        isUtc: true,
      );

      return CuratedList(
        id: dTag,
        name: name,
        pubkey: event.pubkey,
        description: description ?? (isPrivate ? null : event.content),
        isPublic: !isPrivate,
        imageUrl: imageUrl,
        videoEventIds: videoEventIds,
        createdAt: timestamp,
        updatedAt: timestamp,
        nostrEventId: event.id,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrderStr != null
            ? PlayOrderExtension.fromString(playOrderStr)
            : PlayOrder.chronological,
      );
    } on Object catch (_) {
      return null;
    }
  }

  static bool _hasSealedItemShape(List<List<String>> tags, String content) {
    if (!isEncryptedItemPayload(content)) return false;
    return !tags.any(
      (tag) => tag.isNotEmpty && (tag.first == 'e' || tag.first == 'a'),
    );
  }

  /// Whether [content] has the exact binary envelope shape of NIP-44 v2.
  ///
  /// This does not decrypt or authenticate the payload. It only distinguishes
  /// encrypted list items from ordinary descriptions without broad base64
  /// heuristics leaking into production behavior.
  static bool isNip44Payload(String content) {
    try {
      // Bounded to the u16 ceiling rather than the decrypt-side default: this
      // is a classifier run over relay-supplied event content, and a private
      // item payload is itself capped at that size before publishing
      // (`CuratedListRelayGateway.privateItemPayloadFits`). Without the bound
      // an oversized event would be base64-decoded here just to answer a
      // boolean, instead of being rejected by a length comparison (#7331).
      NIP44V2.decodePayload(
        content,
        maxPlaintextSize: NIP44V2.maxU16PlaintextSize,
      );
      return true;
    } on Object {
      return false;
    }
  }

  /// Whether [content] is either the current NIP-44 envelope or the legacy
  /// NIP-04 `ciphertext?iv=...` form allowed by NIP-51 readers.
  static bool isEncryptedItemPayload(String content) {
    return isNip44Payload(content) || NIP04.isEncrypted(content);
  }

  /// Converts a [CuratedList] to Nostr event tags for publishing.
  ///
  /// Returns a list of tag arrays suitable for creating a kind 30005
  /// event, with every video reference in the public tags. A private list
  /// publishes [toPublicMetadataTags] instead and carries [toItemTags]
  /// encrypted in the event content.
  static List<List<String>> toEventTags(CuratedList list) => [
    ...toPublicMetadataTags(list),
    ...toItemTags(list),
  ];

  /// The tags describing [list] itself, without any video reference.
  ///
  /// These stay readable on a relay even for a private list: NIP-51 hides a
  /// list's items, not the fact that the list exists or what it is called.
  static List<List<String>> toPublicMetadataTags(CuratedList list) {
    return _toMetadataTags(list, includeThumbnail: true);
  }

  /// Public metadata for a private list, excluding item-derived fields.
  ///
  /// A thumbnail is itself a video reference, so publishing it beside an
  /// encrypted item set would reveal one member of the private list.
  static List<List<String>> toPrivateMetadataTags(CuratedList list) {
    return _toMetadataTags(list, includeThumbnail: false);
  }

  static List<List<String>> _toMetadataTags(
    CuratedList list, {
    required bool includeThumbnail,
  }) {
    final tags = <List<String>>[
      ['d', list.id],
      ['title', list.name],
    ];

    if (list.description != null && list.description!.isNotEmpty) {
      tags.add(['description', list.description!]);
    }

    if (list.imageUrl != null && list.imageUrl!.isNotEmpty) {
      tags.add(['image', list.imageUrl!]);
    }

    for (final tag in list.tags) {
      tags.add(['t', tag]);
    }

    if (list.isCollaborative) {
      tags.add(['collaborative', 'true']);
      for (final collaborator in list.allowedCollaborators) {
        tags.add(['collaborator', collaborator]);
      }
    }

    if (includeThumbnail && list.thumbnailEventId != null) {
      tags.add(['thumbnail', list.thumbnailEventId!]);
    }

    tags.add(['playorder', list.playOrder.value]);

    return tags;
  }

  /// Whether [list]'s private item payload fits what NIP-44 can encrypt.
  ///
  /// A private list is sealed with a SINGLE NIP-44 encryption — unlike NIP-17,
  /// which encrypts twice — and this client writes only the 2-byte u16 length
  /// prefix, so the sealed plaintext cannot exceed
  /// [NIP44V2.maxU16PlaintextSize]. Lives beside [toItemTags] because it
  /// measures exactly what that produces (#7331).
  static bool privateItemPayloadFits(CuratedList list) {
    return utf8.encode(jsonEncode(toItemTags(list))).length <=
        NIP44V2.maxU16PlaintextSize;
  }

  /// Whether adding [videoEventId] to [list] would push it past
  /// [privateItemPayloadFits], so the add cannot succeed however often it is
  /// retried.
  ///
  /// Public lists are unsealed and therefore unbounded here.
  static bool wouldExceedPrivateItemLimit(
    CuratedList list,
    String videoEventId,
  ) {
    if (list.isPublic || list.videoEventIds.contains(videoEventId)) {
      return false;
    }
    return !privateItemPayloadFits(
      list.copyWith(videoEventIds: [...list.videoEventIds, videoEventId]),
    );
  }

  /// The video-reference tags for [list].
  ///
  /// For a private list these are JSON-encoded and NIP-44 encrypted into the
  /// event content instead of being published as tags.
  static List<List<String>> toItemTags(CuratedList list) => [
    for (final videoReference in list.videoEventIds)
      if (_isAddressableVideoReference(videoReference))
        ['a', videoReference]
      else
        ['e', videoReference],
  ];

  /// Extracts the `d` tag value from an [event].
  ///
  /// Returns `null` if no d-tag is present.
  static String? extractDTag(Event event) {
    for (final dynamic rawTag in event.tags) {
      final tag = (rawTag as List<dynamic>).cast<String>();
      if (tag.length >= 2 && tag[0] == 'd') {
        return tag[1];
      }
    }
    return null;
  }

  static bool _isAddressableVideoReference(String value) {
    final parts = value.split(':');
    final kind = int.tryParse(parts.first);
    final dTag = parts.length >= 3 ? parts.sublist(2).join(':') : '';

    return parts.length >= 3 &&
        kind != null &&
        _nip71AddressableVideoKinds.contains(kind) &&
        parts[1].isNotEmpty &&
        dTag.isNotEmpty;
  }
}
