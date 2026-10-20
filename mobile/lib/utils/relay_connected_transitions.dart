// ABOUTME: Turns the relay pool's status snapshots into one event per
// ABOUTME: snapshot in which a relay newly connects.

import 'package:nostr_client/nostr_client.dart';

/// Emits once for each snapshot of [statuses] in which a relay is connected
/// that was not connected in the snapshot before it.
///
/// [initial] is the snapshot to compare the first one with, so relays already
/// connected when listening starts do not fire. A later snapshot with the
/// same connected set, or with only a relay that dropped, emits nothing. Each
/// listener keeps its own comparison and subscribes to [statuses] the moment
/// it listens; a broadcast stream does not replay, which is what [initial]
/// stands in for.
///
/// The DM retry sweeps wake on this (#8516). Unlike the phone's network
/// change, it also fires when a relay server comes back while the phone
/// stayed online, and only once a relay can actually take a send.
Stream<void> relayConnectedTransitions(
  Stream<Map<String, RelayConnectionStatus>> statuses, {
  Map<String, RelayConnectionStatus> initial = const {},
}) {
  return Stream<void>.multi((controller) {
    var connected = _connectedUrls(initial);
    final subscription = statuses.listen(
      (snapshot) {
        final now = _connectedUrls(snapshot);
        final newlyConnected = now.difference(connected).isNotEmpty;
        connected = now;
        if (newlyConnected) controller.add(null);
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    controller
      ..onPause = subscription.pause
      ..onResume = subscription.resume
      ..onCancel = subscription.cancel;
  });
}

Set<String> _connectedUrls(Map<String, RelayConnectionStatus> statuses) => {
  for (final MapEntry(key: url, value: status) in statuses.entries)
    if (status.isConnected) url,
};
