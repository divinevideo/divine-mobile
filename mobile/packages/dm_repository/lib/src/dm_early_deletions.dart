// ABOUTME: Kind-5 deletions that named a DM before it was stored, held in
// ABOUTME: memory until it is, so arrival order cannot undo a retraction.

import 'dart:collection';

import 'package:nostr_sdk/event.dart';

/// Kind-5 deletions that named a message the account had not stored yet,
/// held until it is.
///
/// A deletion and the message it names travel apart, from different relays
/// or out of order on one, and either can arrive first. Each deletion is held
/// once per target, so another author's deletion of the same target never
/// replaces it. A sender chooses the targets, so at most [capacity] are held
/// and the oldest is dropped past that.
class DmEarlyDeletions {
  /// Holds at most [capacity] (target, deletion) pairs.
  DmEarlyDeletions({required this.capacity});

  /// Most pairs held at once.
  final int capacity;

  /// In arrival order, oldest first.
  final LinkedHashMap<({String target, String deletionId}), Event> _held =
      LinkedHashMap();

  /// Holds [deletion] until [target] is stored.
  void hold(String target, Event deletion) {
    final key = (target: target, deletionId: deletion.id);
    if (_held.containsKey(key)) return;
    _held[key] = deletion;
    while (_held.length > capacity) {
      _held.remove(_held.keys.first);
    }
  }

  /// Hands over every deletion held for [target], oldest first, and holds
  /// none of them afterwards.
  List<Event> take(String target) {
    if (_held.isEmpty) return const [];
    final taken = <Event>[];
    _held.removeWhere((key, deletion) {
      if (key.target != target) return false;
      taken.add(deletion);
      return true;
    });
    return taken;
  }

  /// Drops everything held.
  void clear() => _held.clear();
}
