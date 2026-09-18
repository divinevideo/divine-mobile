// ABOUTME: Holds relay connection state and publishes it to UI and services
// ABOUTME: Fed by relayConnectionStatusBridge; it polls nothing itself

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback type for reconnect events
typedef OnReconnectCallback = void Function();

/// Holds relay connection state and publishes changes to its listeners.
///
/// This is a passive store: it learns about connectivity only through
/// [updateRelayStatuses], which `relayConnectionStatusBridge` drives from
/// `NostrClient.relayStatusStream` (#8331). It performs no polling or probing
/// of its own; the only timer it arms is the offline grace window below, and
/// only in response to an update.
///
/// "Online" here means **relay reachability**, not device connectivity: at
/// least one configured relay is `connected` or `authenticated`. That is the
/// right question for the Nostr reads and writes this gates — a device with
/// working wifi and no reachable relay cannot publish a like. Code that needs
/// *device* state asks `connectivity_plus` instead, as the C2PA prompt in
/// `video_metadata_screen.dart` does.
///
/// The two directions are deliberately asymmetric. Going **offline** waits out
/// [offlineGrace], because every ordinary reconnect passes through a window
/// where no relay is connected yet and flapping offline there would queue work
/// that was about to succeed. Going **online** is immediate, so a recovered
/// relay unblocks writes at once.
class ConnectionStatusService extends ChangeNotifier {
  /// Creates the store. [offlineGrace] is how long every relay must stay
  /// unreachable before this reports offline.
  ///
  /// The default clears both timings this has to survive: a relay dial
  /// measured at ~110 ms on loopback, and the 2 s repair debounce in
  /// `ConnectivityTransitionMonitor`.
  ConnectionStatusService({
    this.offlineGrace = const Duration(seconds: 5),
  });

  /// How long every relay must be unreachable before [isOnline] turns false.
  final Duration offlineGrace;

  bool _isConnected = true;
  bool _isConnecting = false;
  Map<String, bool> _relayStatuses = {};
  Timer? _offlineTimer;
  bool _disposed = false;

  final _statusController = StreamController<bool>.broadcast();

  /// Callbacks to invoke when connection is restored (offline -> online)
  final List<OnReconnectCallback> _reconnectCallbacks = [];

  /// Whether any configured relay is currently reachable
  bool get isConnected => _isConnected;

  /// Alias for isConnected for backward compatibility
  bool get isOnline => _isConnected;

  /// Whether at least one relay is currently dialling
  bool get isConnecting => _isConnecting;

  /// Status of individual relays
  Map<String, bool> get relayStatuses => Map.from(_relayStatuses);

  /// Stream of connection status changes
  Stream<bool> get statusStream => _statusController.stream;

  /// Number of connected relays
  int get connectedRelayCount =>
      _relayStatuses.values.where((status) => status).length;

  /// Total number of configured relays
  int get totalRelayCount => _relayStatuses.length;

  /// Connection health as a percentage (0.0 to 1.0)
  double get connectionHealth {
    if (_relayStatuses.isEmpty) return 0.0;
    return connectedRelayCount / totalRelayCount;
  }

  /// Replaces the known relay statuses with [statuses].
  ///
  /// Whole-map rather than per-relay: the client's stream reports the entire
  /// pool each time, and a per-relay setter could never *remove* a relay the
  /// user de-configured. A stale `true` left behind that way would pin
  /// [isOnline] online forever, which is the failure this method exists to end.
  ///
  /// An empty map is treated as "nothing known yet", not as offline. The first
  /// status frame at cold start arrives before the relay list does (~74 ms
  /// apart, measured), and reporting offline in that gap would queue work on
  /// every launch.
  void updateRelayStatuses(Map<String, bool> statuses) {
    // The bridge cancels its subscription through runProviderDetached, which
    // is not awaited, so a status frame can still arrive after teardown. The
    // stream controller is closed by then and would throw on add.
    if (_disposed) return;
    _relayStatuses = Map<String, bool>.from(statuses);
    if (_relayStatuses.isEmpty) return;

    final anyConnected = _relayStatuses.values.any((status) => status);
    if (anyConnected) {
      _offlineTimer?.cancel();
      _offlineTimer = null;
      if (!_isConnected) _applyConnected(true);
      return;
    }

    // Every relay is unreachable. Wait out the grace window before saying so;
    // a reconnect that lands inside it cancels the timer above.
    if (!_isConnected || (_offlineTimer?.isActive ?? false)) return;
    _offlineTimer = Timer(offlineGrace, () {
      _offlineTimer = null;
      // Same rule as above, re-checked at the edge: only evidence moves this,
      // and an empty pool is not evidence. Without the emptiness check a pool
      // that drained to nothing while the timer was armed would go offline on
      // a path the synchronous branch refuses.
      if (_relayStatuses.isEmpty) return;
      if (_relayStatuses.values.any((status) => status)) return;
      _applyConnected(false);
    });
  }

  void _applyConnected(bool connected) {
    _isConnected = connected;
    Log.info(
      'Relay connectivity ${connected ? 'restored' : 'lost'}: '
      '$connectedRelayCount of $totalRelayCount relays reachable',
      name: 'ConnectionStatusService',
      category: LogCategory.relay,
    );
    _statusController.add(_isConnected);
    if (connected) _triggerReconnectCallbacks();
    notifyListeners();
  }

  /// Register a callback to be invoked when connection is restored.
  ///
  /// Returns a function that can be called to unregister the callback.
  VoidCallback registerOnReconnectCallback(OnReconnectCallback callback) {
    _reconnectCallbacks.add(callback);
    return () => _reconnectCallbacks.remove(callback);
  }

  /// Trigger all registered reconnect callbacks
  void _triggerReconnectCallbacks() {
    for (final callback in List.of(_reconnectCallbacks)) {
      try {
        callback();
      } catch (e) {
        // Don't let one callback failure break others
        Log.warning(
          'Reconnect callback error: $e',
          name: 'ConnectionStatusService',
          category: LogCategory.relay,
        );
      }
    }
  }

  /// Sets the connecting state
  void setConnecting(bool connecting) {
    if (_isConnecting != connecting) {
      _isConnecting = connecting;
      notifyListeners();
    }
  }

  /// Gets connection information for debugging/analytics
  Map<String, dynamic> getConnectionInfo() {
    return {
      'isConnected': _isConnected,
      'isConnecting': _isConnecting,
      'connectedRelayCount': connectedRelayCount,
      'totalRelayCount': totalRelayCount,
      'connectionHealth': connectionHealth,
      'relayStatuses': Map.from(_relayStatuses),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _offlineTimer?.cancel();
    _offlineTimer = null;
    runDetached(
      _statusController.close(),
      'close the connection status stream',
      logName: 'ConnectionStatusService',
      category: LogCategory.system,
    );
    super.dispose();
  }
}
