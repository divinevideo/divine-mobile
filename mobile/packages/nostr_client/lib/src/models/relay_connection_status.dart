// ABOUTME: Data model representing the connection status of a single relay.
// ABOUTME: Used by RelayManager to track and expose relay states to the UI.

import 'package:equatable/equatable.dart';

/// Connection state for a relay
enum RelayState {
  /// Not connected to the relay
  disconnected,

  /// Currently attempting to connect
  connecting,

  /// WebSocket connection established
  connected,

  /// Connected and authenticated via NIP-42
  authenticated,

  /// Connection failed with error
  error,
}

/// {@template relay_connection_status}
/// Represents the current connection status of a single relay.
///
/// Used by RelayManager to provide reactive status updates to the UI.
/// {@endtemplate}
class RelayConnectionStatus extends Equatable {
  /// {@macro relay_connection_status}
  const RelayConnectionStatus({
    required this.url,
    required this.state,
    this.isDefault = false,
    this.isConfigured = true,
    this.lastConnectedAt,
    this.lastErrorAt,
    this.errorCount = 0,
    this.errorMessage,
  });

  /// Creates a disconnected status for a URL
  factory RelayConnectionStatus.disconnected(
    String url, {
    bool isDefault = false,
  }) {
    return RelayConnectionStatus(
      url: url,
      state: RelayState.disconnected,
      isDefault: isDefault,
    );
  }

  /// Creates a connecting status for a URL
  factory RelayConnectionStatus.connecting(
    String url, {
    bool isDefault = false,
  }) {
    return RelayConnectionStatus(
      url: url,
      state: RelayState.connecting,
      isDefault: isDefault,
    );
  }

  /// Creates a connected status for a URL
  factory RelayConnectionStatus.connected(
    String url, {
    bool isDefault = false,
  }) {
    return RelayConnectionStatus(
      url: url,
      state: RelayState.connected,
      isDefault: isDefault,
      lastConnectedAt: DateTime.now(),
    );
  }

  /// The relay URL (e.g., wss://relay.example.com)
  final String url;

  /// Current connection state
  final RelayState state;

  /// Whether this is the default relay that cannot be removed
  final bool isDefault;

  /// Whether this relay is in the user's configured list
  final bool isConfigured;

  /// When the relay was last successfully connected
  final DateTime? lastConnectedAt;

  /// When the last error occurred
  final DateTime? lastErrorAt;

  /// Number of consecutive errors
  final int errorCount;

  /// Most recent error message, if any
  final String? errorMessage;

  /// Whether the relay is currently connected (connected or authenticated)
  bool get isConnected =>
      state == RelayState.connected || state == RelayState.authenticated;

  /// Whether the relay has an error state
  bool get hasError => state == RelayState.error;

  /// Creates a copy with updated fields
  RelayConnectionStatus copyWith({
    String? url,
    RelayState? state,
    bool? isDefault,
    bool? isConfigured,
    DateTime? lastConnectedAt,
    DateTime? lastErrorAt,
    int? errorCount,
    String? errorMessage,
  }) {
    return RelayConnectionStatus(
      url: url ?? this.url,
      state: state ?? this.state,
      isDefault: isDefault ?? this.isDefault,
      isConfigured: isConfigured ?? this.isConfigured,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      errorCount: errorCount ?? this.errorCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    url,
    state,
    isDefault,
    isConfigured,
    errorCount,
  ];

  @override
  String toString() {
    return 'RelayConnectionStatus(url: $url, state: $state, '
        'isDefault: $isDefault, isConfigured: $isConfigured)';
  }
}
