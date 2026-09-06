// ABOUTME: Manages relay configuration, connections, and status for the app.
// ABOUTME: Wraps RelayPool to provide persistence, status streams, clean API.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/relay_add_source.dart';
import 'package:nostr_client/src/models/relay_connection_status.dart';
import 'package:nostr_client/src/models/relay_manager_config.dart';
import 'package:nostr_client/src/models/relay_remove_source.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Normalizes a relay URL into the canonical form used by [RelayManager].
///
/// Accepts explicit `ws://` / `wss://` relay URLs and bare
/// host[:port][/path] values, which are upgraded to `wss://`. Returns `null`
/// for unsupported schemes, malformed URLs, empty hosts, or cleartext
/// non-loopback relays.
String? normalizeRelayUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  // Validate any explicit scheme BEFORE the bare-host upgrade. Without this
  // gate, `http://attacker.example.com` would slip past the prefix check below
  // and be string-prefixed into `wss://http://attacker.example.com` (a URL
  // whose authority parses as host=`http`, path=`//attacker...` - routed to
  // the wrong host rather than rejected).
  String normalized;
  final initial = Uri.tryParse(trimmed);
  if (initial != null && initial.hasAuthority) {
    final scheme = initial.scheme.toLowerCase();
    if (scheme != 'wss' && scheme != 'ws') return null;
    if (initial.path.startsWith('//')) return null;
    normalized = initial.toString();
  } else {
    if (trimmed.contains('://')) return null;
    normalized = 'wss://$trimmed';
  }

  if (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }

  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme == 'ws' && !isLoopbackHost(uri.host)) return null;
  return normalized;
}

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

  /// Known-dead relays that should never be added.
  ///
  /// These relays have DNS failures or are permanently offline.
  /// Adding them causes connection errors and degrades UX.
  /// Users may have these in their NIP-65 relay lists, so we filter them out.
  static const Set<String> _blockedRelayHosts = {
    'index.coracle.social', // DNS dead since ~2024
  };

  /// Check if a relay URL is blocked
  static bool _isBlockedRelay(String url) {
    try {
      final uri = Uri.parse(url);
      return _blockedRelayHosts.contains(uri.host);
    } on FormatException {
      return false;
    }
  }

  /// Whether [url] is admissible under the configured environment lock.
  ///
  /// Returns false for malformed URLs. When `config.allowedRelayHost` is set,
  /// only relays whose host equals it are admitted (non-production lock);
  /// when null, any valid relay is admitted (production). This is the single
  /// source of truth for the rule — callers that bypass [addRelay] (e.g.
  /// one-off `tempRelays` in `NostrClient`) consult it directly.
  bool isRelayAllowed(String url) {
    final normalized = normalizeRelayUrl(url);
    if (normalized == null) return false;
    final allowedHost = _config.allowedRelayHost;
    if (allowedHost == null) return true;
    return Uri.parse(normalized).host == allowedHost;
  }

  final RelayManagerConfig _config;
  final RelayPool _relayPool;
  final Relay Function(String url)? _relayFactory;

  /// Configured relay URLs (user's list, persisted)
  final List<String> _configuredRelays = [];

  /// Relay URLs the user explicitly removed.
  final Set<String> _userRemovedRelays = {};

  /// Status for each relay
  final Map<String, RelayConnectionStatus> _relayStatuses = {};

  /// Stream controller for status updates
  final _statusController =
      StreamController<Map<String, RelayConnectionStatus>>.broadcast();

  /// Timer for periodic status polling
  Timer? _statusPollTimer;

  /// Whether the manager has been initialized
  bool _initialized = false;

  /// Whether persisted user-removal intent has been loaded.
  bool _userRemovedRelaysLoaded = false;

  /// In-flight load of persisted user-removal intent.
  Future<void>? _userRemovedRelaysLoadFuture;

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  /// The environment default relay URL.
  String get defaultRelayUrl => _config.defaultRelayUrl;

  /// List of relay URLs the user has configured.
  List<String> get configuredRelays => List.unmodifiable(_configuredRelays);

  /// List of relay URLs currently connected
  ///
  /// Uses the internal status tracking which is updated synchronously after
  /// successful connection
  List<String> get connectedRelays {
    return _configuredRelays.where((url) {
      final status = _relayStatuses[url];
      return status != null && status.isConnected;
    }).toList();
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

  /// Ensure the user-removal intent ledger has been loaded from storage.
  ///
  /// Idempotent: concurrent callers share a single storage read, and later
  /// calls return immediately once the ledger is loaded.
  ///
  /// [addRelay], [removeRelay], [isUserRemovedRelay] and [initialize] already
  /// await this internally, so suppression is correct without it. Use it only
  /// to warm the ledger ahead of those calls, or to surface a storage read
  /// failure at a point the caller chooses.
  Future<void> ensureUserRemovedRelaysLoaded() =>
      _ensureUserRemovedRelaysLoaded();

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

    final storage = _config.storage;
    if (storage != null) {
      await _ensureUserRemovedRelaysLoaded();

      final savedRelays = await storage.loadRelays();
      // Normalize loaded relays and filter out blocked, duplicate, invalid,
      // disallowed, or user-suppressed relays.
      var blockedCount = 0;
      var droppedCount = 0;
      var userRemovedCount = 0;
      for (final url in savedRelays) {
        final normalized = normalizeRelayUrl(url);
        if (normalized == null) {
          // URL is malformed or now disallowed by the loopback gate
          // (#3362). Drop it from the in-memory list and re-save below so
          // the entry doesn't linger in storage forever.
          droppedCount++;
          continue;
        }
        if (_isBlockedRelay(normalized)) {
          blockedCount++;
          continue;
        }
        if (!isRelayAllowed(normalized)) {
          // Persisted from another environment (e.g. a production relay
          // saved before switching to staging). Drop and re-save below.
          droppedCount++;
          continue;
        }
        if (_userRemovedRelays.contains(normalized)) {
          userRemovedCount++;
          continue;
        }
        if (!_configuredRelays.contains(normalized)) {
          _configuredRelays.add(normalized);
        }
      }
      if (blockedCount > 0) {
        _log('Filtered $blockedCount blocked relays from storage');
      }
      if (droppedCount > 0) {
        _log('Filtered $droppedCount invalid relay URLs from storage');
      }
      if (userRemovedCount > 0) {
        _log('Filtered $userRemovedCount user-removed relays from storage');
      }
      if (blockedCount > 0 || droppedCount > 0 || userRemovedCount > 0) {
        // Persist the filtered list so removed entries don't reappear
        // on the next launch.
        await storage.saveRelays(_configuredRelays);
        _log('Saved filtered relay list to storage');
      }
      _log('Loaded ${_configuredRelays.length} relays from storage');
    }

    // Add the environment default unless the user explicitly removed it.
    final normalizedDefault = normalizeRelayUrl(_config.defaultRelayUrl);
    if (normalizedDefault != null &&
        isRelayAllowed(normalizedDefault) &&
        !_userRemovedRelays.contains(normalizedDefault) &&
        !_configuredRelays.contains(normalizedDefault)) {
      _configuredRelays.insert(0, normalizedDefault);
      _log('Added default relay: $normalizedDefault');
    }

    // Initialize status for all configured relays
    for (final url in _configuredRelays) {
      _relayStatuses[url] = RelayConnectionStatus.disconnected(
        url,
        isDefault: url == normalizedDefault,
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
  /// Returns false if the relay URL is invalid, blocked, or already configured.
  Future<bool> addRelay(
    String url, {
    RelayAddSource source = RelayAddSource.automatic,
  }) async {
    await _ensureUserRemovedRelaysLoaded();

    final normalizedUrl = normalizeRelayUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
      return false;
    }

    // Block known-dead relays
    if (_isBlockedRelay(normalizedUrl)) {
      _log('Blocked dead relay: $normalizedUrl');
      return false;
    }

    // Reject relays outside the configured environment host.
    if (!isRelayAllowed(normalizedUrl)) {
      _log('Relay not allowed in this environment: $normalizedUrl');
      return false;
    }

    if (source == RelayAddSource.automatic &&
        _userRemovedRelays.contains(normalizedUrl)) {
      _log('Skipping user-removed automatic relay: $normalizedUrl');
      return false;
    }

    if (source == RelayAddSource.user) {
      await _clearUserRemovedRelay(normalizedUrl);
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
  /// Returns false if the relay URL is invalid or not configured.
  Future<bool> removeRelay(
    String url, {
    required RelayRemoveSource source,
  }) async {
    await _ensureUserRemovedRelaysLoaded();

    final normalizedUrl = normalizeRelayUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
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
    if (source == RelayRemoveSource.user) {
      _userRemovedRelays.add(normalizedUrl);
      await _saveUserRemovedRelays();
    }

    _notifyStatusChange();
    return true;
  }

  /// Check if a relay URL is configured
  bool isRelayConfigured(String url) {
    final normalizedUrl = normalizeRelayUrl(url);
    return normalizedUrl != null && _configuredRelays.contains(normalizedUrl);
  }

  /// Check if a relay URL is currently suppressed by user-removal intent.
  Future<bool> isUserRemovedRelay(String url) async {
    await _ensureUserRemovedRelaysLoaded();
    final normalizedUrl = normalizeRelayUrl(url);
    return normalizedUrl != null && _userRemovedRelays.contains(normalizedUrl);
  }

  /// Check if a relay is currently connected
  bool isRelayConnected(String url) {
    final normalizedUrl = normalizeRelayUrl(url);
    if (normalizedUrl == null) return false;

    final status = _relayStatuses[normalizedUrl];
    return status?.isConnected ?? false;
  }

  /// Get the status of a specific relay
  RelayConnectionStatus? getRelayStatus(String url) {
    final normalizedUrl = normalizeRelayUrl(url);
    if (normalizedUrl == null) return null;
    return _relayStatuses[normalizedUrl];
  }

  // ---------------------------------------------------------------------------
  // Per-Relay SDK Counters
  // ---------------------------------------------------------------------------

  /// Returns per-relay counters from the SDK's [RelayStatus].
  ///
  /// These are the actual per-relay statistics tracked by the SDK:
  /// - `eventsReceived`: events received from this specific relay
  /// - `queriesSent`: queries/subscriptions sent to this specific relay
  /// - `errors`: error count for this specific relay
  Map<String, ({int eventsReceived, int queriesSent, int errors})>
  getRelayPoolCounters() {
    final result =
        <String, ({int eventsReceived, int queriesSent, int errors})>{};
    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      if (relay != null) {
        result[url] = (
          eventsReceived: relay.relayStatus.noteReceived,
          queriesSent: relay.relayStatus.queryNum,
          errors: relay.relayStatus.error,
        );
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  /// Aggregate bound on one reconnect sweep.
  ///
  /// Parallelising already bounds a healthy sweep at roughly one connect
  /// (a 10s handshake timeout plus a 2s orphan close). The socket layer also
  /// bounds each send-path reconnect, while this shorter aggregate stop keeps
  /// a sweep across multiple hosts from holding a DM send's inbox lookup open
  /// indefinitely (#7091).
  @visibleForTesting
  static Duration reconnectSweepBudget = const Duration(seconds: 15);

  /// Reconnects disconnected relays and checks connected relays for health.
  ///
  /// Concurrent callers share the underlying sweep for the full lifetime of
  /// its dials. Each caller stops waiting at the sweep's original aggregate
  /// deadline, while late dial results continue updating their own relay
  /// status. `_connectToRelay` replaces the prior relay object, so clearing the
  /// single-flight latch when only the caller deadline expires would let the
  /// next caller start duplicate sockets against the same hosts (#7091).
  Future<void> retryDisconnectedRelays() {
    final inFlight = _retryInFlight;
    if (inFlight != null) return _waitForRetrySweep(inFlight);
    _retryDeadline = DateTime.now().add(reconnectSweepBudget);
    final sweep = _runRetrySweep();
    late final Future<void> tracked;
    tracked = sweep.whenComplete(() {
      if (identical(_retryInFlight, tracked)) {
        _retryInFlight = null;
        _retryDeadline = null;
      }
    });
    _retryInFlight = tracked;
    return _waitForRetrySweep(tracked);
  }

  Future<void>? _retryInFlight;
  DateTime? _retryDeadline;

  Future<void> _waitForRetrySweep(Future<void> sweep) async {
    final deadline = _retryDeadline;
    if (deadline == null) return sweep;
    final remaining = deadline.difference(DateTime.now());
    try {
      await sweep.timeout(remaining.isNegative ? Duration.zero : remaining);
    } on TimeoutException {
      _log(
        'Reconnect sweep exceeded ${reconnectSweepBudget.inSeconds}s; '
        'hosts still dialling remain in flight',
      );
    }
  }

  Future<void> _runRetrySweep() async {
    _log('Retrying disconnected relays');

    // First, check health of all "connected" relays to detect dead connections
    _checkRelayHealth();

    final disconnected = _configuredRelays.where((url) {
      final status = _relayStatuses[url];
      return status != null && !status.isConnected;
    }).toList();

    for (final url in disconnected) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    // Connect in PARALLEL, as _connectToConfiguredRelays already does for the
    // startup path. Each result owns only its relay's status: the aggregate
    // caller deadline must not turn unresolved dials into failures, and a dial
    // that succeeds after that deadline is still the live pooled connection.
    await Future.wait(
      disconnected.map((url) async {
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
        _notifyStatusChange();
      }),
    );
  }

  /// Check health of all connected relays and disconnect any that are idle.
  ///
  /// This detects "zombie" connections that appear connected but have actually
  /// died silently (common with WebSockets after ~2 minutes of idle time).
  void _checkRelayHealth() {
    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      if (relay == null) continue;

      // Check if the relay supports health checks (RelayBase)
      if (relay is RelayBase) {
        final healthy = relay.checkHealth();
        if (!healthy) {
          _log('Relay $url failed health check, marking as disconnected');
          _updateRelayStatus(url, RelayState.disconnected);
        }
      }
    }
  }

  /// Force reconnect all relays (disconnect first, then reconnect)
  ///
  /// Use this when WebSocket connections may have been silently dropped
  /// (e.g., after app backgrounding).
  Future<void> forceReconnectAll() async {
    _log('Force reconnecting all relays');

    // Create a copy to avoid concurrent modification during async iteration
    final relaysToReconnect = List<String>.from(_configuredRelays);

    // First disconnect all
    for (final url in relaysToReconnect) {
      _relayPool.remove(url);
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    // Then reconnect all
    for (final url in relaysToReconnect) {
      final success = await _connectToRelay(url);
      if (success) {
        _updateRelayStatus(url, RelayState.connected);
        _log('Force reconnected to $url');
      } else {
        _updateRelayStatus(
          url,
          RelayState.error,
          errorMessage: 'Force reconnection failed',
        );
        _log('Force reconnection failed for $url');
      }
    }

    _notifyStatusChange();
  }

  /// Reconnect to a specific relay
  Future<bool> reconnectRelay(String url) async {
    final normalizedUrl = normalizeRelayUrl(url);
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
    // Create a copy to avoid concurrent modification during async iteration
    final relaysToConnect = List<String>.from(_configuredRelays);

    for (final url in relaysToConnect) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    // Connect to all relays in PARALLEL instead of sequential.
    // This reduces startup from O(n * timeout) to O(max timeout).
    final results = await Future.wait(
      relaysToConnect.map((url) async {
        final success = await _connectToRelay(url);
        return MapEntry(url, success);
      }),
    );

    // Update statuses based on results
    for (final entry in results) {
      if (entry.value) {
        _updateRelayStatus(entry.key, RelayState.connected);
      } else {
        _updateRelayStatus(
          entry.key,
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

      // Remove the old (possibly dead) relay from the pool first so that
      // add() doesn't short-circuit on a duplicate URL. Without this,
      // a stale relay object stays in the pool and no events flow through.
      _relayPool.remove(url);

      // Add to pool and connect – autoSubscribe ensures any active
      // subscriptions are resent to the newly connected relay so that
      // queries (e.g. follower counts) don't silently miss data.
      final success = await _relayPool.add(relay, autoSubscribe: true);
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

  Future<void> _saveUserRemovedRelays() async {
    final storage = _config.storage;
    if (storage != null) {
      await storage.saveRemovedRelays(_userRemovedRelays.toList());
      _log('Saved ${_userRemovedRelays.length} user-removed relays to storage');
    }
  }

  Future<void> _ensureUserRemovedRelaysLoaded() async {
    if (_userRemovedRelaysLoaded) return;
    final existingLoad = _userRemovedRelaysLoadFuture;
    if (existingLoad != null) return existingLoad;

    final loadFuture = _loadUserRemovedRelays();
    _userRemovedRelaysLoadFuture = loadFuture;
    try {
      await loadFuture;
    } catch (_) {
      _userRemovedRelaysLoadFuture = null;
      rethrow;
    }
  }

  Future<void> _loadUserRemovedRelays() async {
    final storage = _config.storage;
    if (storage == null) {
      _userRemovedRelaysLoaded = true;
      return;
    }

    final savedRemovedRelays = await storage.loadRemovedRelays();
    final normalizedRelays = <String>{};
    for (final url in savedRemovedRelays) {
      final normalized = normalizeRelayUrl(url);
      if (normalized != null && isRelayAllowed(normalized)) {
        normalizedRelays.add(normalized);
      }
    }

    _userRemovedRelays
      ..clear()
      ..addAll(normalizedRelays);

    if (savedRemovedRelays.length != normalizedRelays.length ||
        !_setsEqual(normalizedRelays, savedRemovedRelays.toSet())) {
      await storage.saveRemovedRelays(_userRemovedRelays.toList());
      _log('Saved filtered user-removed relay list to storage');
    }
    _userRemovedRelaysLoaded = true;
  }

  bool _setsEqual<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _clearUserRemovedRelay(String normalizedUrl) async {
    if (_userRemovedRelays.remove(normalizedUrl)) {
      await _saveUserRemovedRelays();
    }
  }

  void _log(String message) {
    developer.log('[RelayManager] $message');
  }
}
