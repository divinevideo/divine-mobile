// ABOUTME: Carries a room call's sealed connection messages over the app's
// ABOUTME: relays as ephemeral events, live only

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/collab_room/call/collab_room_call_signal.dart';

/// Sends and receives a call's connection messages.
abstract interface class CollabRoomCallTransport {
  /// The messages signed by [author] from [since] (Unix seconds) on.
  Stream<Event> watch(String author, {required int since});

  /// Sends [event].
  ///
  /// Throws a [CollabRoomCallException] when no relay took it.
  Future<void> publish(Event event);
}

/// A [CollabRoomCallTransport] over the app's [NostrClient].
class NostrCollabRoomCallTransport implements CollabRoomCallTransport {
  /// Creates a transport over [client].
  const NostrCollabRoomCallTransport(this._client);

  final NostrClient _client;

  @override
  Stream<Event> watch(String author, {required int since}) => _client.subscribe(
    [
      Filter(
        kinds: const [collabRoomCallSignalKind],
        authors: [author],
        since: since,
      ),
    ],
    handleDeletionRequests: false,
  );

  @override
  Future<void> publish(Event event) async {
    final result = await _client.publishEvent(event);
    if (result is! PublishSuccess) {
      throw const CollabRoomCallException('No relay accepted the call signal');
    }
  }
}
