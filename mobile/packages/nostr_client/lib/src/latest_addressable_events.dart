// ABOUTME: The newest version of each addressable event the app read or
// ABOUTME: published, shared by writers that replace the same event.

import 'dart:async';

import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// The newest version of each addressable event the app read or published,
/// shared by the writers that replace the same event.
///
/// Divine's relay acknowledges a publish before it stores it, so a writer
/// that replaces an event right after another writer published it can read
/// the older version back and build on it, dropping the other writer's
/// change. Writers sharing one store build on the newest version either of
/// them has seen.
///
/// Callers remember only events they checked: signed by the expected author,
/// with a valid id and signature.
class LatestAddressableEvents {
  final _events = <String, Event>{};
  final _operations = <String, Future<void>>{};

  /// Serializes the whole read/modify/publish operation at one coordinate.
  /// An accepted revision alone cannot protect a second writer while the
  /// first writer is still awaiting its relay acknowledgement.
  Future<T> run<T>({
    required String pubkey,
    required int kind,
    required String dTag,
    required Future<T> Function() operation,
  }) {
    final key = _key(pubkey, kind, dTag);
    final result = (_operations[key] ?? Future<void>.value()).then(
      (_) => operation(),
    );
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _operations[key] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_operations[key], tail)) {
          unawaited(_operations.remove(key));
        }
      }),
    );
    return result;
  }

  /// The newest version known of [pubkey]'s event of [kind] whose `d` tag is
  /// [dTag], or `null` when none is.
  Event? latest({
    required String pubkey,
    required int kind,
    required String dTag,
  }) => _events[_key(pubkey, kind, dTag)];

  /// Keeps [event] when it is newer than the version known: a later
  /// `created_at`, or of two signed in the same second the lower id, the one
  /// relays keep (NIP-01).
  void remember(Event event) {
    final key = _key(event.pubkey, event.kind, event.dTagValue);
    final known = _events[key];
    if (known == null || isNewer(event, than: known)) {
      // A copy, so a caller changing its event cannot change the store.
      _events[key] = Event.fromJson(event.toJson());
    }
  }

  /// Whether [event] replaces [than]: a later `created_at`, or the lower id
  /// of two signed in the same second.
  static bool isNewer(Event event, {required Event than}) =>
      event.createdAt != than.createdAt
      ? event.createdAt > than.createdAt
      : event.id.compareTo(than.id) < 0;

  static String _key(String pubkey, int kind, String dTag) =>
      '$pubkey:$kind:$dTag';
}
