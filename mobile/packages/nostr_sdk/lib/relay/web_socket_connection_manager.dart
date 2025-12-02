// ABOUTME: Manages WebSocket connections with automatic reconnection and heartbeat.
// ABOUTME: Single responsibility class for WebSocket lifecycle, designed for testability.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state for the WebSocket
enum ConnectionState { disconnected, connecting, connected }

/// Configuration for WebSocket connection behavior
class WebSocketConfig {
  /// Interval between heartbeat pings
  final Duration pingInterval;

  /// Timeout waiting for pong response
  final Duration pongTimeout;

  /// Maximum number of reconnection attempts before giving up
  final int maxReconnectAttempts;

  /// Base delay for exponential backoff (doubles each attempt)
  final Duration baseReconnectDelay;

  /// Maximum delay between reconnection attempts
  final Duration maxReconnectDelay;

  /// Timeout for initial connection attempt
  final Duration connectionTimeout;

  const WebSocketConfig({
    this.pingInterval = const Duration(seconds: 30),
    this.pongTimeout = const Duration(seconds: 10),
    this.maxReconnectAttempts = 10,
    this.baseReconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(minutes: 5),
    this.connectionTimeout = const Duration(seconds: 30),
  });

  /// Default configuration
  static const WebSocketConfig defaultConfig = WebSocketConfig();
}

/// Factory for creating WebSocket channels, injectable for testing
abstract class WebSocketChannelFactory {
  WebSocketChannel create(Uri uri);
}

/// Default factory using web_socket_channel
class DefaultWebSocketChannelFactory implements WebSocketChannelFactory {
  const DefaultWebSocketChannelFactory();

  @override
  WebSocketChannel create(Uri uri) {
    return WebSocketChannel.connect(uri);
  }
}

/// {@template web_socket_connection_manager}
/// Manages a single WebSocket connection with automatic reconnection and heartbeat.
///
/// Designed for testability with:
/// - Injectable WebSocketChannelFactory for mocking
/// - Stream-based state and message notifications
/// - Configurable timeouts and retry behavior
/// - Clear separation from protocol-specific logic
/// {@endtemplate}
class WebSocketConnectionManager {
  /// {@macro web_socket_connection_manager}
  WebSocketConnectionManager({
    required this.url,
    this.config = WebSocketConfig.defaultConfig,
    WebSocketChannelFactory? channelFactory,
    void Function(String)? logger,
  }) : _channelFactory =
           channelFactory ?? const DefaultWebSocketChannelFactory(),
       log = logger ?? _defaultLog;

  final String url;
  final WebSocketConfig config;
  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  // State management
  ConnectionState _state = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;

  // Timers
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  bool _awaitingPong = false;

  // Fixed ping subscription ID to avoid leaking subscriptions on the relay
  late final String _pingSubId = '_ping_${hashCode.toRadixString(16)}';

  // Stream controllers for external consumers
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of connection state changes
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// Stream of received messages (raw strings)
  Stream<String> get messageStream => _messageController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Current connection state
  ConnectionState get state => _state;

  /// Whether currently connected
  bool get isConnected => _state == ConnectionState.connected;

  /// Number of reconnection attempts made
  int get reconnectAttempts => _reconnectAttempts;

  /// Logger function, can be overridden for testing
  void Function(String message) log;

  static void _defaultLog(String message) {
    // Use print for now, can be replaced with proper logging
    print('[WebSocketConnectionManager] $message');
  }

  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_state == ConnectionState.connected) {
      log('Already connected to $url');
      return true;
    }

    if (_state == ConnectionState.connecting) {
      log('Already connecting to $url');
      return false;
    }

    _shouldReconnect = true;
    return _doConnect();
  }

  Future<bool> _doConnect() async {
    _setState(ConnectionState.connecting);
    _stopHeartbeat();

    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw ArgumentError('Invalid WebSocket URL scheme: ${uri.scheme}');
      }

      log('Connecting to $url');
      _channel = _channelFactory.create(uri);

      // Set up message listener
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );

      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      log('Connected to $url');
      _startHeartbeat();

      return true;
    } catch (e) {
      log('Connection failed: $e');
      _errorController.add('Connection failed: $e');
      _setState(ConnectionState.disconnected);
      _scheduleReconnect();
      return false;
    }
  }

  void _onMessage(dynamic message) {
    // Any message means connection is alive
    _onPongReceived();

    if (message is String) {
      _messageController.add(message);
    } else {
      _messageController.add(message.toString());
    }
  }

  void _onStreamError(dynamic error) {
    log('Stream error: $error');
    _errorController.add('Stream error: $error');
    _handleDisconnect();
  }

  void _onStreamDone() {
    log('Stream closed by remote');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    final wasConnected = _state == ConnectionState.connected;
    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    _setState(ConnectionState.disconnected);

    if (wasConnected && _shouldReconnect) {
      _scheduleReconnect();
    }
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();

    await _closeChannel();
    _setState(ConnectionState.disconnected);
    log('Disconnected from $url');
  }

  Future<void> _closeChannel() async {
    _channelSubscription?.cancel();
    _channelSubscription = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        log('Error closing channel: $e');
      }
      _channel = null;
    }
  }

  /// Send a message through the WebSocket
  ///
  /// Returns true if message was sent, false if not connected
  bool send(String message) {
    if (_state != ConnectionState.connected || _channel == null) {
      log('Cannot send - not connected');
      return false;
    }

    try {
      _channel!.sink.add(message);
      return true;
    } catch (e) {
      log('Send error: $e');
      _errorController.add('Send error: $e');
      _handleDisconnect();
      return false;
    }
  }

  /// Send a JSON-encodable message
  bool sendJson(dynamic data) {
    try {
      final encoded = jsonEncode(data);
      return send(encoded);
    } catch (e) {
      log('JSON encode error: $e');
      _errorController.add('JSON encode error: $e');
      return false;
    }
  }

  // --- Reconnection ---

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return;
    if (!_shouldReconnect) return;

    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      log('Max reconnect attempts reached for $url');
      _errorController.add('Max reconnect attempts reached');
      return;
    }

    // Exponential backoff: base * 2^attempts, capped at max
    final delayMs =
        (config.baseReconnectDelay.inMilliseconds *
                (1 << _reconnectAttempts.clamp(0, 8)))
            .clamp(0, config.maxReconnectDelay.inMilliseconds);
    final delay = Duration(milliseconds: delayMs);

    _reconnectAttempts++;
    log(
      'Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts/${config.maxReconnectAttempts})',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_shouldReconnect && _state == ConnectionState.disconnected) {
        _doConnect();
      }
    });
  }

  /// Reset reconnection state, allowing fresh attempts
  void resetReconnection() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Force immediate reconnection, resetting backoff
  Future<bool> reconnect() async {
    resetReconnection();
    _shouldReconnect = true;
    await _closeChannel();
    _setState(ConnectionState.disconnected);
    return _doConnect();
  }

  // --- Heartbeat ---

  void _startHeartbeat() {
    _stopHeartbeat();
    _awaitingPong = false;

    _pingTimer = Timer.periodic(config.pingInterval, (_) {
      _sendPing();
    });
    log('Heartbeat started');
  }

  void _stopHeartbeat() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _awaitingPong = false;
  }

  void _sendPing() {
    if (_state != ConnectionState.connected) {
      return;
    }

    if (_awaitingPong) {
      log('Still awaiting pong, connection may be stale');
      return;
    }

    _awaitingPong = true;

    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = Timer(config.pongTimeout, () {
      if (_awaitingPong) {
        log('Pong timeout, triggering reconnect');
        _errorController.add('Heartbeat timeout');
        _handleDisconnect();
      }
    });

    final pingMsg = jsonEncode([
      'REQ',
      _pingSubId,
      {'limit': 0},
    ]);

    if (send(pingMsg)) {
      log('Ping sent');
    } else {
      log('Ping failed to send');
      _awaitingPong = false;
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = null;
    }
  }

  void _onPongReceived() {
    if (_awaitingPong) {
      _awaitingPong = false;
      _pongTimeoutTimer?.cancel();
      _pongTimeoutTimer = null;
    }
  }

  // --- State management ---

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _errorController.close();
  }
}
