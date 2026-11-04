// ABOUTME: Merges the signals that make a failed profile load worth retrying:
// ABOUTME: a relay connecting, the network coming back, the app resuming.

import 'package:async/async.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/connectivity_transition_monitor.dart';
import 'package:openvine/utils/relay_connected_transitions.dart';

/// Signals that a failed profile load is worth retrying now: a relay newly
/// connects (including a relay server coming back while the phone stayed
/// online), the device's network comes back, or the app returns to the
/// foreground.
///
/// A broadcast stream that can be listened to again after every listener
/// cancels, as long as [connectivity] and [foregroundResumes] are broadcast:
/// profile cubits come and go, and more than one can be alive at once.
Stream<void> profileFeedRetryTriggers({
  required Stream<Map<String, RelayConnectionStatus>> relayStatuses,
  required Map<String, RelayConnectionStatus> initialRelayStatuses,
  required Stream<ConnectivityTransition> connectivity,
  required Stream<void> foregroundResumes,
}) => StreamGroup.mergeBroadcast<void>([
  relayConnectedTransitions(relayStatuses, initial: initialRelayStatuses),
  connectivity
      .where((transition) => transition == ConnectivityTransition.online)
      .map<void>((_) {}),
  foregroundResumes,
]);
