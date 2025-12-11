// ABOUTME: Manages relay configuration, connections, and status for the app.
// ABOUTME: Wraps RelayPool to provide persistence, status streams, clean API.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/relay_connection_status.dart';
import 'package:nostr_client/src/models/relay_manager_config.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// {@template relay_manager}
/// Manages relay configuration and connection status.
///
/// Provides:
/// - Configured vs connected relay distinction
/// - Persistence of relay configuration
/// - Reactive status streams for UI binding
/// - Default relay handling
///
/// This class wraps [RelayPool] from nostr_sdk and adds app-level
/// functionality like persistence and reactive status updates.
/// {@endtemplate}
class RelayManager {
  /// {@macro relay_manager}
  RelayManager({
    required RelayManagerConfig config,
    required RelayPool relayPool,
    @visibleForTesting Relay Function(String url)? relayFactory,
  }) : _config = config,
       _relayPool = relayPool,
       _relayFactory = relayFactory;

  final RelayManagerConfig _config;
  final RelayPool _relayPool;
  final Relay Function(String url)? _relayFactory;

  /// Configured relay URLs (user's list, persisted)
  final List<String> _configuredRelays = [];

  /// Status for each relay
  final Map<String, RelayConnectionStatus> _relayStatuses = {};

  /// Stream controller for status updates
  final _statusController =
      StreamController<Map<String, RelayConnectionStatus>>.broadcast();

  /// Timer for periodic status polling
  Timer? _statusPollTimer;

  /// Whether the manager has been initialized
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  /// The default relay URL that cannot be removed
  String get defaultRelayUrl => _config.defaultRelayUrl;

  /// List of relay URLs the user has configured (including default)
  List<String> get configuredRelays => List.unmodifiable(_configuredRelays);

  /// List of relay URLs currently connected
  List<String> get connectedRelays {
    return _relayPool
        .activeRelays()
        .map((r) => r.url)
        .where(_configuredRelays.contains)
        .toList();
  }

  /// Number of configured relays
  int get configuredRelayCount => _configuredRelays.length;

  /// Number of connected relays
  int get connectedRelayCount => connectedRelays.length;

  /// Whether at least one relay is connected
  bool get hasConnectedRelay => connectedRelayCount > 0;

  /// Stream of relay status updates for UI binding
  Stream<Map<String, RelayConnectionStatus>> get statusStream =>
      _statusController.stream;

  /// Current status map (snapshot)
  Map<String, RelayConnectionStatus> get currentStatuses =>
      Map.unmodifiable(_relayStatuses);

  /// Whether the manager has been initialized
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the relay manager
  ///
  /// Loads persisted relay configuration and connects to all configured relays.
  /// If no relays are persisted, uses the default relay.
  Future<void> initialize() async {
    if (_initialized) {
      _log('Already initialized');
      return;
    }

    _log('Initializing RelayManager');

    // Load persisted relays
    final storage = _config.storage;
    if (storage != null) {
      final savedRelays = await storage.loadRelays();
      _configuredRelays.addAll(savedRelays);
      _log('Loaded ${savedRelays.length} relays from storage');
    }

    // Ensure default relay is always included
    if (!_configuredRelays.contains(_config.defaultRelayUrl)) {
      _configuredRelays.insert(0, _config.defaultRelayUrl);
      _log('Added default relay: ${_config.defaultRelayUrl}');
    }

    // Initialize status for all configured relays
    for (final url in _configuredRelays) {
      _relayStatuses[url] = RelayConnectionStatus.disconnected(
        url,
        isDefault: url == _config.defaultRelayUrl,
      );
    }

    // Connect to all configured relays
    await _connectToConfiguredRelays();

    // Start status polling
    _startStatusPolling();

    _initialized = true;
    _notifyStatusChange();
    _log('RelayManager initialized with ${_configuredRelays.length} relays');
  }

  // ---------------------------------------------------------------------------
  // Relay Management
  // ---------------------------------------------------------------------------

  /// Add a relay to the configuration and connect to it
  ///
  /// Returns true if the relay was added and connected successfully.
  /// Returns false if the relay URL is invalid or already configured.
  Future<bool> addRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
      return false;
    }

    if (_configuredRelays.contains(normalizedUrl)) {
      _log('Relay already configured: $normalizedUrl');
      return false;
    }

    _log('Adding relay: $normalizedUrl');

    // Add to configured list
    _configuredRelays.add(normalizedUrl);

    // Initialize status
    _relayStatuses[normalizedUrl] = RelayConnectionStatus.connecting(
      normalizedUrl,
    );
    _notifyStatusChange();

    // Connect to the relay
    final success = await _connectToRelay(normalizedUrl);

    // Update status based on connection result
    if (success) {
      _updateRelayStatus(normalizedUrl, RelayState.connected);
    } else {
      _updateRelayStatus(
        normalizedUrl,
        RelayState.error,
        errorMessage: 'Failed to connect',
      );
    }
    _notifyStatusChange();

    // Persist configuration
    await _saveConfiguration();

    return success;
  }

  /// Remove a relay from the configuration
  ///
  /// Returns true if the relay was removed.
  /// Returns false if the relay is the default relay or not configured.
  Future<bool> removeRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
      return false;
    }

    if (normalizedUrl == _config.defaultRelayUrl) {
      _log('Cannot remove default relay: $normalizedUrl');
      return false;
    }

    if (!_configuredRelays.contains(normalizedUrl)) {
      _log('Relay not configured: $normalizedUrl');
      return false;
    }

    _log('Removing relay: $normalizedUrl');

    // Disconnect from the relay
    _relayPool.remove(normalizedUrl);

    // Remove from configured list and statuses
    _configuredRelays.remove(normalizedUrl);
    _relayStatuses.remove(normalizedUrl);

    // Persist configuration
    await _saveConfiguration();

    _notifyStatusChange();
    return true;
  }

  /// Check if a relay URL is configured
  bool isRelayConfigured(String url) {
    final normalizedUrl = _normalizeUrl(url);
    return normalizedUrl != null && _configuredRelays.contains(normalizedUrl);
  }

  /// Check if a relay is currently connected
  bool isRelayConnected(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) return false;

    final status = _relayStatuses[normalizedUrl];
    return status?.isConnected ?? false;
  }

  /// Get the status of a specific relay
  RelayConnectionStatus? getRelayStatus(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) return null;
    return _relayStatuses[normalizedUrl];
  }

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  /// Retry connecting to all disconnected relays
  Future<void> retryDisconnectedRelays() async {
    _log('Retrying disconnected relays');

    final disconnected = _configuredRelays.where((url) {
      final status = _relayStatuses[url];
      return status != null && !status.isConnected;
    }).toList();

    for (final url in disconnected) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    for (final url in disconnected) {
      final success = await _connectToRelay(url);
      if (success) {
        _updateRelayStatus(url, RelayState.connected);
      } else {
        _updateRelayStatus(
          url,
          RelayState.error,
          errorMessage: 'Reconnection failed',
        );
      }
    }

    _notifyStatusChange();
  }

  /// Reconnect to a specific relay
  Future<bool> reconnectRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null || !_configuredRelays.contains(normalizedUrl)) {
      return false;
    }

    _log('Reconnecting to relay: $normalizedUrl');
    _updateRelayStatus(normalizedUrl, RelayState.connecting);
    _notifyStatusChange();

    // Disconnect first
    _relayPool.remove(normalizedUrl);

    // Reconnect
    final success = await _connectToRelay(normalizedUrl);

    if (success) {
      _updateRelayStatus(normalizedUrl, RelayState.connected);
    } else {
      _updateRelayStatus(
        normalizedUrl,
        RelayState.error,
        errorMessage: 'Reconnection failed',
      );
    }

    _notifyStatusChange();
    return success;
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Dispose of resources
  Future<void> dispose() async {
    _log('Disposing RelayManager');
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    await _statusController.close();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Private Methods
  // ---------------------------------------------------------------------------

  Future<void> _connectToConfiguredRelays() async {
    for (final url in _configuredRelays) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    for (final url in _configuredRelays) {
      final success = await _connectToRelay(url);
      if (success) {
        _updateRelayStatus(url, RelayState.connected);
      } else {
        _updateRelayStatus(
          url,
          RelayState.error,
          errorMessage: 'Failed to connect',
        );
      }
    }
    _notifyStatusChange();
  }

  Future<bool> _connectToRelay(String url) async {
    try {
      // Create relay instance
      Relay relay;
      if (_relayFactory != null) {
        relay = _relayFactory(url);
      } else {
        relay = RelayBase(
          url,
          RelayStatus(url),
          channelFactory: _config.webSocketChannelFactory,
        );
      }

      // Add to pool and connect
      final success = await _relayPool.add(relay);
      _log('Connect to $url: ${success ? 'success' : 'failed'}');
      return success;
    } on Exception catch (e) {
      _log('Error connecting to $url: $e');
      return false;
    }
  }

  void _updateRelayStatus(
    String url,
    RelayState state, {
    String? errorMessage,
  }) {
    final current = _relayStatuses[url];
    if (current == null) return;

    final isError = state == RelayState.error;
    final newErrorCount = isError ? current.errorCount + 1 : 0;

    final lastConnected = state == RelayState.connected
        ? DateTime.now()
        : current.lastConnectedAt;

    _relayStatuses[url] = current.copyWith(
      state: state,
      errorCount: newErrorCount,
      errorMessage: errorMessage,
      lastConnectedAt: lastConnected,
      lastErrorAt: isError ? DateTime.now() : current.lastErrorAt,
    );
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncStatusFromRelayPool();
    });
  }

  void _syncStatusFromRelayPool() {
    var changed = false;

    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      final currentStatus = _relayStatuses[url];

      if (currentStatus == null) continue;

      RelayState newState;
      if (relay == null) {
        newState = RelayState.disconnected;
      } else {
        final connected = relay.relayStatus.connected;
        final authed = relay.relayStatus.authed;

        if (connected == ClientConnected.connected) {
          newState = authed ? RelayState.authenticated : RelayState.connected;
        } else if (connected == ClientConnected.connecting) {
          newState = RelayState.connecting;
        } else {
          newState = RelayState.disconnected;
        }
      }

      if (currentStatus.state != newState) {
        final isNowConnected =
            newState == RelayState.connected ||
            newState == RelayState.authenticated;
        final lastConnected = isNowConnected
            ? DateTime.now()
            : currentStatus.lastConnectedAt;

        _relayStatuses[url] = currentStatus.copyWith(
          state: newState,
          lastConnectedAt: lastConnected,
        );
        changed = true;
      }
    }

    if (changed) {
      _notifyStatusChange();
    }
  }

  void _notifyStatusChange() {
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_relayStatuses));
    }
  }

  Future<void> _saveConfiguration() async {
    final storage = _config.storage;
    if (storage != null) {
      await storage.saveRelays(_configuredRelays);
      _log('Saved ${_configuredRelays.length} relays to storage');
    }
  }

  String? _normalizeUrl(String url) {
    var normalized = url.trim();

    // Ensure wss:// prefix
    if (!normalized.startsWith('wss://') && !normalized.startsWith('ws://')) {
      normalized = 'wss://$normalized';
    }

    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Basic validation
    try {
      final uri = Uri.parse(normalized);
      if (uri.host.isEmpty) return null;
      return normalized;
    } on FormatException {
      return null;
    }
  }

  void _log(String message) {
    developer.log('[RelayManager] $message');
  }
}
