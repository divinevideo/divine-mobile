// ABOUTME: Supplies explicit protocol completion for owned-list relay fixtures.
// ABOUTME: Stream teardown, errors and cancellation never stand in for EOSE.

import 'package:nostr_sdk/event.dart';

/// Emits a complete owned-list snapshot and calls its actual EOSE callback.
/// Negative teardown/error/timeout/cancellation cases must use their raw stream.
Stream<Event> completedOwnedListSnapshot(
  Invocation invocation,
  Iterable<Event> events,
) async* {
  final onEose = invocation.namedArguments[#onEose];
  if (invocation.namedArguments[#closeOnEose] != true ||
      onEose is! void Function()) {
    throw StateError('Owned-list fixture requires explicit EOSE wiring');
  }
  for (final event in events) {
    yield event;
  }
  onEose();
}
