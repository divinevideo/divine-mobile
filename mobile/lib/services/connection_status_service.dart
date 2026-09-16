// ABOUTME: Holds relay connection state and publishes it to UI and services
// ABOUTME: Fed by callers via updateRelayStatus; it polls nothing itself

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Callback type for reconnect events
typedef OnReconnectCallback = void Function();

/// Holds relay connection state and publishes changes to its listeners.
///
/// This is a passive store: it learns about connectivity only through
/// [updateRelayStatus], and performs no polling or probing of its own.
///
/// Nothing currently calls [updateRelayStatus], so [isOnline] stays at its
/// initial `true` for the life of the app even when every relay is down,
/// tracked in #8331. Until that is wired up, treat [isOnline] as "not known
/// to be offline" rather than as a live signal.
class ConnectionStatusService extends ChangeNotifier {
  ConnectionStatusService();

  bool _isConnected = true;
  bool _isConnecting = false;
  final Map<String, bool> _relayStatuses = {};

  final _statusController = StreamController<bool>.broadcast();

  /// Callbacks to invoke when connection is restored (offline -> online)
  final List<OnReconnectCallback> _reconnectCallbacks = [];

  /// Whether we have any network connectivity
  bool get isConnected => _isConnected;

  /// Alias for isConnected for backward compatibility
  bool get isOnline => _isConnected;

  /// Whether we are currently attempting to connect
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

  /// Updates the status of a specific relay
  void updateRelayStatus(String relayUrl, bool isConnected) {
    final wasConnected = _isConnected;
    _relayStatuses[relayUrl] = isConnected;

    // Update overall connection status
    final newConnectionStatus = _relayStatuses.values.any((status) => status);
    if (newConnectionStatus != _isConnected) {
      _isConnected = newConnectionStatus;
      _statusController.add(_isConnected);

      // Trigger reconnect callbacks if transitioning from offline to online
      if (!wasConnected && _isConnected) {
        _triggerReconnectCallbacks();
      }

      notifyListeners();
    } else if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  /// Register a callback to be invoked when connection is restored.
  ///
  /// Returns a function that can be called to unregister the callback.
  VoidCallback registerOnReconnectCallback(OnReconnectCallback callback) {
    _reconnectCallbacks.add(callback);
    return () => _reconnectCallbacks.remove(callback);
  }

  /// Unregister a reconnect callback
  void unregisterOnReconnectCallback(OnReconnectCallback callback) {
    _reconnectCallbacks.remove(callback);
  }

  /// Trigger all registered reconnect callbacks
  void _triggerReconnectCallbacks() {
    for (final callback in _reconnectCallbacks) {
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
    runDetached(
      _statusController.close(),
      'close the connection status stream',
      logName: 'ConnectionStatusService',
      category: LogCategory.system,
    );
    super.dispose();
  }
}
