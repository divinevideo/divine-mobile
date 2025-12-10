// ABOUTME: Base relay implementation using WebSocketConnectionManager.
// ABOUTME: Handles Nostr message parsing and delegates connection management.

import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'client_connected.dart';
import 'platform_websocket_factory.dart';
import 'relay.dart';
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
  }) : _channelFactory = channelFactory;

  @override
  Future<bool> doConnect() async {
    // If already connected, return true
    if (_connectionManager != null && _connectionManager!.isConnected) {
      log("connect break: $url - already connected");
      return true;
    }

    try {
      getRelayInfo(url);
      log("Connect begin: $url");

      // Create connection manager if needed
      _connectionManager ??= WebSocketConnectionManager(
        url: url,
        channelFactory:
            _channelFactory ?? const PlatformWebSocketChannelFactory(),
        logger: (msg) => log("[$url] $msg"),
      );

      // Set up stream listeners
      _setupStreamListeners();

      // Connect
      final result = await _connectionManager!.connect();

      if (result) {
        log("Connect complete: $url");
      }

      return result;
    } catch (e) {
      log("Connect error: $e");
      onError(e.toString(), reconnect: true);
      return false;
    }
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
          // Flush pending messages on reconnection
          if (wasDisconnected) {
            onConnected();
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
  bool send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
  }) {
    if (_connectionManager == null) {
      return false;
    }

    if (forceSend == true || _connectionManager!.isConnected) {
      try {
        // Log AUTH-related messages for debugging
        if (message.isNotEmpty && message[0] == 'AUTH') {
          log("🔐 AUTH response sent, waiting for relay confirmation...");
        }

        // Defensive serialization: Ensure all data is JSON-serializable
        final sanitizedMessage = sanitizeForJson(message);
        return _connectionManager!.sendJson(sanitizedMessage);
      } catch (e) {
        onError(e.toString(), reconnect: true);
      }
    } else if (queueIfFailed) {
      pendingMessages.add(message);
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

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionManager?.dispose();
    _connectionManager = null;
    super.dispose();
  }
}
