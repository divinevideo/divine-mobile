// ABOUTME: Requires positive owner/version evidence for canonical My List writes.
// ABOUTME: Bounds explicit publication intents and fresh-key creation to one session.

import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';

class _DefaultPublicationIntent {
  const _DefaultPublicationIntent({
    required this.owner,
    required this.value,
    this.baselineEventId,
    this.creationPermit,
  });

  final String owner;
  final String value;
  final String? baselineEventId;
  final FreshAccountListCreationPermit? creationPermit;
}

/// One operation may undo only its own unpersisted publication reservation.
class CuratedDefaultMutationReservation {
  CuratedDefaultMutationReservation._(this._rollback);
  final void Function() _rollback;
  bool _released = false;

  void rollback() {
    if (_released) return;
    _released = true;
    _rollback();
  }
}

/// Reserved-coordinate rights are distinct from ordinary list readiness.
///
/// Neither an empty cache nor a completed relay request establishes absence.
/// Imported/restored identities need an authenticated readable revision; fresh
/// creation requires the opaque permit issued by actual key generation.
class CuratedDefaultPublicationAuthority {
  CuratedDefaultPublicationAuthority({
    required String? Function() currentOwner,
    required bool Function() isCurrentSession,
    required bool Function() canWriteCurrentCache,
    required bool Function(String owner) wasDeleted,
    required FreshAccountListCreationPermit? Function() takeCreationPermit,
  }) : _currentOwner = currentOwner,
       _isCurrentSession = isCurrentSession,
       _canWriteCurrentCache = canWriteCurrentCache,
       _wasDeleted = wasDeleted,
       _takeCreationPermit = takeCreationPermit;

  static const defaultId = 'my_vine_list';
  final String? Function() _currentOwner;
  final bool Function() _isCurrentSession;
  final bool Function() _canWriteCurrentCache;
  final bool Function(String owner) _wasDeleted;
  final FreshAccountListCreationPermit? Function() _takeCreationPermit;
  Event? _newestObserved;
  CuratedList? _decodedBaseline;
  _DefaultPublicationIntent? _intent;

  bool _owns(String? owner) =>
      owner != null &&
      _isCurrentSession() &&
      _currentOwner() == owner &&
      !_wasDeleted(owner);

  /// Authentication precedes both revision selection and opaque retirement.
  bool authenticates(Event event, String? owner) =>
      event.kind == 30005 &&
      event.pubkey == owner &&
      CuratedListConverter.extractDTag(event) == defaultId &&
      event.tags.where((tag) => tag.isNotEmpty && tag[0] == 'd').length == 1 &&
      event.isValid &&
      event.isSigned;

  bool _olderThan(Event incoming, Event existing) =>
      incoming.id != existing.id &&
      (incoming.createdAt < existing.createdAt ||
          (incoming.createdAt == existing.createdAt &&
              incoming.id.compareTo(existing.id) > 0));

  /// Retires the old revision before awaiting an external decryptor.
  /// Re-reading the same authenticated version preserves its existing proof.
  void beginObservation(Event incoming) {
    if (!_isCurrentSession() || !authenticates(incoming, _currentOwner())) {
      return;
    }
    final previous = _newestObserved;
    if (previous != null &&
        (_olderThan(incoming, previous) || incoming.id == previous.id)) {
      return;
    }
    _newestObserved = Event.fromJson(
      jsonDecode(jsonEncode(incoming.toJson())) as Map<String, dynamic>,
    );
    _decodedBaseline = null;
    _intent = null;
  }

  /// A newer genuine opaque revision revokes the previous decoded baseline.
  void observe(Event incoming, UnsealedItemTags items) {
    final owner = _currentOwner();
    if (!_isCurrentSession() || !authenticates(incoming, owner)) return;
    final previous = _newestObserved;
    if (previous != null && _olderThan(incoming, previous)) return;
    final priorIntent = _intent;
    final event = Event.fromJson(
      jsonDecode(jsonEncode(incoming.toJson())) as Map<String, dynamic>,
    );
    _newestObserved = event;
    _decodedBaseline = null;
    _intent = null;
    if (!_owns(owner) ||
        items.status == UnsealItemTagsStatus.failed ||
        (items.status == UnsealItemTagsStatus.unsealed &&
            !items.hasCompleteItemSnapshot)) {
      return;
    }
    if (items.status == UnsealItemTagsStatus.notSealed &&
        CuratedListConverter.isEncryptedItemPayload(event.content)) {
      return;
    }
    final tags = items.status == UnsealItemTagsStatus.unsealed
        ? items.tags
        : event.tags
              .where(
                (tag) => tag.isNotEmpty && (tag[0] == 'e' || tag[0] == 'a'),
              )
              .toList();
    if (!_fullyKnownItems(tags)) return;
    final decoded = CuratedListConverter.fromEvent(
      event,
      privateTags: items.tags,
      isPrivateEvent: items.status == UnsealItemTagsStatus.unsealed,
    );
    if (decoded == null || decoded.pubkey != owner || decoded.id != defaultId) {
      return;
    }
    _decodedBaseline = decoded;
    // A repeated version or a genuine echo of this exact outgoing value may
    // preserve its intent. It cannot grant permission for another payload.
    if (priorIntent != null &&
        priorIntent.owner == owner &&
        (priorIntent.baselineEventId == event.id ||
            priorIntent.value == _value(decoded))) {
      _intent = _DefaultPublicationIntent(
        owner: priorIntent.owner,
        value: priorIntent.value,
        baselineEventId: event.id,
      );
    }
  }

  bool hasReadableRevision(Event event) =>
      _owns(event.pubkey) &&
      authenticates(event, _currentOwner()) &&
      _decodedBaseline?.nostrEventId == event.id;

  bool _fullyKnownItems(List<List<String>>? tags) =>
      tags != null &&
      tags.every(
        (tag) =>
            tag.length >= 2 &&
            ((tag[0] == 'e' && RegExp(r'^[0-9a-f]{64}$').hasMatch(tag[1])) ||
                (tag[0] == 'a' &&
                    RegExp(
                      r'^(34235|34236):[0-9a-f]{64}:.+$',
                    ).hasMatch(tag[1]))),
      );

  /// Cached event IDs never establish this right by themselves.
  bool canMutate(CuratedList list) =>
      list.id != defaultId ||
      (_owns(list.pubkey) &&
          _decodedBaseline?.pubkey == list.pubkey &&
          _decodedBaseline?.nostrEventId == _newestObserved?.id &&
          ((list.nostrEventId == _decodedBaseline?.nostrEventId &&
                  _value(list.publicationTarget) ==
                      _value(_decodedBaseline!)) ||
              (_intent?.baselineEventId == _newestObserved?.id &&
                  _intent?.value == _value(list.publicationTarget))));

  String _value(CuratedList list) => jsonEncode([
    list.pubkey,
    list.id,
    list.isPublic,
    if (list.isPublic)
      CuratedListConverter.toEventTags(list)
    else
      CuratedListConverter.toPrivateMetadataTags(list),
    if (list.isPublic)
      (list.description ?? 'Curated video list: ${list.name}')
    else
      CuratedListConverter.toItemTags(list),
  ]);

  /// Binds the explicit delta before its first cache/signing await.
  /// The previous row must match a verified baseline or this exact live intent.
  CuratedDefaultMutationReservation? reserveMutation(
    CuratedList previous,
    CuratedList target,
  ) {
    if (target.id != defaultId) {
      return CuratedDefaultMutationReservation._(() {});
    }
    if (previous.authorScopedId != target.authorScopedId ||
        !canMutate(previous) ||
        !_fullyKnownItems(CuratedListConverter.toItemTags(target))) {
      return null;
    }
    final before = _intent;
    final reserved = _DefaultPublicationIntent(
      owner: target.pubkey!,
      value: _value(target),
      baselineEventId: _newestObserved!.id,
    );
    _intent = reserved;
    return CuratedDefaultMutationReservation._(() {
      if (_owns(reserved.owner) &&
          _newestObserved?.id == reserved.baselineEventId &&
          _decodedBaseline?.nostrEventId == reserved.baselineEventId &&
          _intent?.baselineEventId == reserved.baselineEventId &&
          _intent?.value == reserved.value) {
        _intent = before;
      }
    });
  }

  /// Sync may retry the exact saved creation intent without granting edits.
  bool canRetrySavedPublication(CuratedList list) =>
      canMutate(list) || canPublish(list.publicationTarget);

  /// Sync repeats already verified work; it never infers a different payload.
  bool beginMutation(CuratedList target) =>
      canPublish(target) || reserveMutation(target, target) != null;

  /// Reserved creation never derives permission from an empty local cache.
  bool authorizeCreation(CuratedList target) {
    if (target.id != defaultId || canPublish(target)) return true;
    if (!_owns(target.pubkey) || _newestObserved != null) return false;
    final permit = _takeCreationPermit();
    return permit != null && beginCreation(target, permit);
  }

  /// Explicit intent is separated from implicit startup/backfill retry.
  bool authorizePublication(CuratedList target, {required bool explicit}) =>
      (!explicit || beginMutation(target)) && canPublish(target);

  /// A consumed fresh-key permit is bound to this exact initial value.
  bool beginCreation(
    CuratedList target,
    FreshAccountListCreationPermit permit,
  ) {
    final owner = target.pubkey;
    if (target.id != defaultId ||
        owner == null ||
        !_owns(owner) ||
        _newestObserved != null ||
        !_fullyKnownItems(CuratedListConverter.toItemTags(target)) ||
        !permit.consumeFor(owner)) {
      return false;
    }
    _intent = _DefaultPublicationIntent(
      owner: owner,
      value: _value(target),
      creationPermit: permit,
    );
    return true;
  }

  /// Rechecked after every signing/storage/journal await and before dispatch.
  bool canPublish(CuratedList target) {
    if (!_canWriteCurrentCache()) return false;
    if (target.id != defaultId) return true;
    final intent = _intent;
    if (!_owns(target.pubkey) ||
        intent == null ||
        intent.owner != target.pubkey ||
        intent.value != _value(target)) {
      return false;
    }
    final permit = intent.creationPermit;
    return permit != null
        ? _newestObserved == null && permit.isCurrentFor(intent.owner)
        : _decodedBaseline?.pubkey == intent.owner &&
              _decodedBaseline?.nostrEventId == _newestObserved?.id &&
              intent.baselineEventId == _decodedBaseline?.nostrEventId;
  }

  /// Only a current, genuinely accepted signed send advances local authority.
  /// Retired sends keep their advisory ACK journal without granting new rights.
  void accepted(CuratedList target, Event event) {
    if (target.id != defaultId ||
        !canPublish(target) ||
        !authenticates(event, target.pubkey)) {
      return;
    }
    final previous = _newestObserved;
    if (previous != null && _olderThan(event, previous)) return;
    _newestObserved = Event.fromJson(
      jsonDecode(jsonEncode(event.toJson())) as Map<String, dynamic>,
    );
    _decodedBaseline = target.copyWith(nostrEventId: event.id);
    _intent = null;
  }
}
