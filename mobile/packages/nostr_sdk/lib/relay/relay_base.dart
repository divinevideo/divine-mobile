// ABOUTME: Base relay implementation using WebSocketConnectionManager.
// ABOUTME: Handles Nostr message parsing and delegates connection management.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'client_connected.dart';
import 'platform_websocket_factory.dart';
import 'relay.dart';
import 'relay_diagnostics.dart';
import 'web_socket_connection_manager.dart';

class RelayBase extends Relay {
  WebSocketConnectionManager? _connectionManager;
  StreamSubscription<ConnectionState>? _stateSubscription;
  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<String>? _errorSubscription;
  final WebSocketChannelFactory? _channelFactory;

  RelayBase(
    super.url,
    super.relayStatus, {
    WebSocketChannelFactory? channelFactory,
    super.diagnosticsSink,
  }) : _channelFactory = channelFactory;

  /// Tracks whether doConnect is in progress to avoid duplicate onConnected calls
  bool _isConnecting = false;

  /// Whether [dispose] has run.
  ///
  /// [doConnect] creates the connection manager lazily, so without this a
  /// connect on a disposed relay would mint a *fresh* manager — one the
  /// manager's own disposed guard cannot catch, because that guard lives on
  /// the instance [dispose] threw away. The socket and heartbeat timer it
  /// opened would then belong to a relay nothing references (#7367).
  bool _disposed = false;

  bool _connectionIsFresh = true;

  @override
  bool get connectionIsFresh => _connectionIsFresh;

  @override
  Future<bool> doConnect() async {
    if (_disposed) {
      log("connect refused: $url - relay is disposed");
      return false;
    }

    // If already connected, return true
    if (_connectionManager != null && _connectionManager!.isConnected) {
      log("connect break: $url - already connected");
      _connectionIsFresh = false;
      return true;
    }
    _connectionIsFresh = true;

    try {
      _isConnecting = true;
      getRelayInfo(url);
      log("Connect begin: $url");

      // Create connection manager if needed
      _connectionManager ??= WebSocketConnectionManager(
        url: url,
        channelFactory:
            _channelFactory ?? const PlatformWebSocketChannelFactory(),
        logger: (msg) {
          log("[$url] $msg");
          diagnose(
            RelayDiagnosticSite.connectionLifecycle,
            connectionDiagnosticLevelFor(msg),
            msg,
          );
        },
      );

      // Set up stream listeners
      _setupStreamListeners();

      // Connect
      final result = await _connectionManager!.connect();

      if (result) {
        log("Connect complete: $url");
        // Explicitly set connected status here since the stream listener
        // may not have processed the state change yet when we return
        relayStatus.connected = ClientConnected.connected;
      }

      _isConnecting = false;
      return result;
    } catch (e) {
      _isConnecting = false;
      log("Connect error: $e");
      onError(e.toString(), reconnect: true);
      return false;
    }
  }

  /// Phrases [WebSocketConnectionManager] uses when a connection attempt
  /// did not succeed.
  ///
  /// The manager reports its outcome in prose, so this list has to track the
  /// wording it actually emits. `timed out` is the one that reads like a
  /// duplicate and is not: the manager renders a `Duration` after
  /// `Connection timed out after`, so that line carries no `timeout`
  /// substring, and the same holds for `Max reconnect attempts reached`,
  /// `Connect abandoned` and `stopping before attempt`. Those four are how a
  /// relay actually gives up, so without them a relay that timed out on every
  /// handshake and then spent its reconnect budget reaches a support export
  /// at the same severity as an ordinary `Connecting to` line.
  static const List<String> _connectionFailurePhrases = [
    'error',
    'failed',
    'timeout',
    'timed out',
    'abandoned',
    'exhausted',
    'max reconnect attempts',
    'stopping before attempt',
  ];

  /// Severity for a [WebSocketConnectionManager] log line.
  @visibleForTesting
  static RelayDiagnosticLevel connectionDiagnosticLevelFor(String message) {
    final normalized = message.toLowerCase();
    for (final phrase in _connectionFailurePhrases) {
      if (normalized.contains(phrase)) return RelayDiagnosticLevel.warning;
    }
    return RelayDiagnosticLevel.info;
  }

  void _setupStreamListeners() {
    // Cancel existing subscriptions
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();

    // Listen for state changes
    _stateSubscription = _connectionManager!.stateStream.listen((state) {
      final wasDisconnected =
          relayStatus.connected != ClientConnected.connected;

      switch (state) {
        case ConnectionState.connected:
          relayStatus.connected = ClientConnected.connected;
          // Flush pending messages on reconnection, but NOT during initial connect
          // (relay.connect() will call onConnected after doConnect returns)
          if (wasDisconnected && !_isConnecting) {
            // A disconnected -> connected transition is a new socket by
            // definition, including the one `forceReconnect` drives without
            // going through `doConnect`.
            _connectionIsFresh = true;
            onConnected(source: 'stateStream-reconnect');
          }
        case ConnectionState.connecting:
          relayStatus.connected = ClientConnected.connecting;
        case ConnectionState.disconnected:
          relayStatus.connected = ClientConnected.disconnect;
      }
      if (relayStatusCallback != null) {
        relayStatusCallback!();
      }
    });

    // Listen for messages
    _messageSubscription = _connectionManager!.messageStream.listen((message) {
      if (onMessage != null) {
        try {
          final List<dynamic> json = jsonDecode(message);

          // Log AUTH-related messages for debugging
          if (json.isNotEmpty && json[0] == 'AUTH') {
            log("📡 Raw message from $url: $json");
          }

          onMessage!(this, json);
        } catch (e) {
          log("Message parse error: $e");
        }
      }
    });

    // Listen for errors
    _errorSubscription = _connectionManager!.errorStream.listen((error) {
      log("Connection error: $error");
      relayStatus.onError();
    });
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (_connectionManager == null) {
      return false;
    }

    try {
      // Log AUTH-related messages for debugging
      if (message.isNotEmpty && message[0] == 'AUTH') {
        log("🔐 AUTH response sent, waiting for relay confirmation...");
      }

      // Defensive serialization: Ensure all data is JSON-serializable
      final sanitizedMessage = sanitizeForJson(message);
      final result = await _connectionManager!.sendJson(
        sanitizedMessage,
        skipReconnect: skipReconnect,
        deadline: deadline,
      );
      if (!result && queueIfFailed) {
        pendingMessages.add(message);
      }
      return result;
    } catch (e) {
      if (queueIfFailed) {
        pendingMessages.add(message);
      }
      onError(e.toString(), reconnect: true);
    }

    return false;
  }

  /// Recursively sanitize data structures to ensure JSON serializability
  @protected
  dynamic sanitizeForJson(dynamic data) {
    if (data == null) {
      return null;
    } else if (data is String || data is num || data is bool) {
      return data;
    } else if (data is List) {
      return data.map((item) => sanitizeForJson(item)).toList();
    } else if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        // Ensure keys are strings
        final stringKey = key.toString();
        result[stringKey] = sanitizeForJson(value);
      });
      return result;
    } else {
      // For any other type, try to convert to JSON-compatible format
      try {
        // If it has a toJson method, use it
        final toJsonResult = data.toJson();
        if (toJsonResult != null) {
          return sanitizeForJson(toJsonResult);
        }
      } catch (e) {
        // Ignore toJson errors and fall through
      }

      // As last resort, convert to string
      return data.toString();
    }
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
    await _connectionManager?.disconnect();
  }

  /// Check if the connection is healthy (connected and not idle).
  ///
  /// Returns true if healthy, false if disconnected or idle.
  /// If idle, forces disconnect to enable reconnection on next operation.
  bool checkHealth() {
    if (_connectionManager == null) return false;
    return _connectionManager!.checkHealth();
  }

  /// Whether the connection appears idle (no recent activity).
  bool get isIdle => _connectionManager?.isIdle ?? false;

  /// When the last message was received from this relay.
  DateTime? get lastActivityAt => _connectionManager?.lastActivityAt;

  /// Whether the connection still reports `connected` yet has received no
  /// inbound frame since [since].
  ///
  /// This is the signature of a half-open "zombie" socket left behind by a
  /// connectivity flap: outbound frames buffer into a dead TCP connection
  /// without erroring, so the socket keeps claiming to be connected while
  /// nothing ever arrives. A connection stamps its activity clock at connect
  /// time, so a socket (re)established after [since] never reads as silent.
  bool isSilentSince(DateTime since) {
    final manager = _connectionManager;
    if (manager == null || !manager.isConnected) return false;
    final lastInbound = manager.lastActivityAt;
    return lastInbound == null || !lastInbound.isAfter(since);
  }

  /// Force-cycle the underlying WebSocket connection.
  ///
  /// Unlike [connect], this bypasses [doConnect]'s already-connected
  /// short-circuit, which would keep a zombie socket alive. The fresh
  /// connection starts unauthenticated, so the auth flag is reset the same
  /// way [Relay.connect] resets it.
  Future<bool> forceReconnect() async {
    final manager = _connectionManager;
    relayStatus.authed = false;
    if (manager == null) return connect();
    return manager.reconnect();
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionManager?.dispose();
    _connectionManager = null;
    super.dispose();
  }
}
