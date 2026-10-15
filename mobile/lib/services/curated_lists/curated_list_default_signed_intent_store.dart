// ABOUTME: Retains a signed canonical-list intent across interrupted delivery.
// ABOUTME: Only explicit Sync may use it; cached flags never grant authority.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:nostr_sdk/event.dart';

class CuratedDefaultSignedIntentStore {
  const CuratedDefaultSignedIntentStore(this._events);
  final PersonalEventsDao _events;

  bool _isSignedDefault(Event event, String owner) =>
      event.pubkey == owner &&
      event.kind == 30005 &&
      event.tags.where((tag) => tag.isNotEmpty && tag.first == 'd').length ==
          1 &&
      event.tags.any(
        (tag) => tag.length == 2 && tag.first == 'd' && tag[1] == defaultListId,
      ) &&
      event.isValid &&
      event.isSigned;

  Future<bool> save(Event event) async {
    if (!_isSignedDefault(event, event.pubkey)) return false;
    await _events.upsertPersonalEvent(event, retainForRetry: true);
    final stored = await read(event.pubkey);
    return stored?.id == event.id && stored?.sig == event.sig;
  }

  Future<Event?> read(String owner) async {
    try {
      final event = await _events.getRetryEvent(
        pubkey: owner,
        kind: 30005,
        dTag: defaultListId,
      );
      return event != null && _isSignedDefault(event, owner) ? event : null;
    } on FormatException {
      // Keep unreadable evidence for recovery without granting authority.
      return null;
    }
  }
}
