// ABOUTME: Monitors network connectivity and relay connection status
// ABOUTME: Provides reactive connection state updates for UI components

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Monitors connection status for relays and network connectivity
class ConnectionStatusService extends ChangeNotifier {
  ConnectionStatusService() {
    _startMonitoring();
  }

  bool _isConnected = true;
  bool _isConnecting = false;
  final Map<String, bool> _relayStatuses = {};

  final _statusController = StreamController<bool>.broadcast();
  Timer? _monitoringTimer;

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
    if (_relayStatuses.isEmpty) return 0;
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
      notifyListeners();
    } else if (wasConnected != _isConnected) {
      notifyListeners();
    }
  }

  /// Sets the connecting state
  void setConnecting(bool connecting) {
    if (_isConnecting != connecting) {
      _isConnecting = connecting;
      notifyListeners();
    }
  }

  /// Forces a connection check
  Future<void> checkConnection() async {
    setConnecting(true);

    // Simulate connection check - in real implementation, this would
    // ping relays or check network connectivity
    await Future.delayed(const Duration(milliseconds: 100));

    setConnecting(false);
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

  /// Starts periodic monitoring of connection status
  void _startMonitoring() {
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => checkConnection(),
    );
  }

  /// Stops monitoring and cleans up resources
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  @override
  void dispose() {
    stopMonitoring();
    _statusController.close();
    super.dispose();
  }
}
