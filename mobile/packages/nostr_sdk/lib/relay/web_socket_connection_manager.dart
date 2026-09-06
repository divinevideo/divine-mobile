// ABOUTME: Manages WebSocket connections with on-demand reconnection.
// ABOUTME: Single responsibility class for WebSocket lifecycle, designed for testability.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state for the WebSocket
enum ConnectionState { disconnected, connecting, connected }

/// Configuration for WebSocket connection behavior
class WebSocketConfig {
  /// Maximum number of send-path reconnection attempts before giving up.
  final int maxReconnectAttempts;

  /// Base delay for send-path reconnect backoff (doubles each attempt).
  final Duration baseReconnectDelay;

  /// Maximum delay between send-path reconnection attempts.
  final Duration maxReconnectDelay;

  /// Maximum time one send may spend reconnecting when it has no deadline.
  final Duration reconnectBudget;

  /// Timeout for initial connection attempt
  final Duration connectionTimeout;

  /// Maximum time to wait for a WebSocket close handshake.
  final Duration closeTimeout;

  /// Interval for heartbeat checks (0 to disable)
  ///
  /// When enabled, the connection manager periodically checks if the
  /// connection appears idle (no messages received). If idle for longer
  /// than [idleTimeout], the connection is considered dead and will be
  /// disconnected.
  final Duration heartbeatInterval;

  /// Maximum time without receiving a message before connection is
  /// considered dead
  ///
  /// Only applies when [heartbeatInterval] is non-zero.
  /// Set to Duration.zero to disable idle detection.
  final Duration idleTimeout;

  const WebSocketConfig({
    this.maxReconnectAttempts = 10,
    this.baseReconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(minutes: 5),
    this.reconnectBudget = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 10),
    this.closeTimeout = const Duration(seconds: 2),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
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
/// Manages a single WebSocket connection with on-demand reconnection and
/// idle detection.
///
/// Reconnects on demand when a message is sent while disconnected. A stream
/// error or closure marks the connection disconnected so the next send can
/// start that bounded reconnect attempt.
///
/// Idle Detection (heartbeat):
/// - Tracks when the last message was received
/// - Periodically checks if connection has been idle beyond [idleTimeout]
/// - Forces disconnect when idle, enabling reconnection on next send
/// - Configure via [WebSocketConfig.heartbeatInterval] and [idleTimeout]
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

  /// Set by [dispose] before its first await, so a connect that is already
  /// in flight can tell that its owner is gone by the time it resumes.
  bool _disposed = false;

  // Timers
  Timer? _heartbeatTimer;

  // Activity tracking for idle detection
  DateTime? _lastActivityAt;

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

  /// When the last message was received (or connection established)
  DateTime? get lastActivityAt => _lastActivityAt;

  /// Duration since last activity (or null if never connected)
  Duration? get idleDuration {
    if (_lastActivityAt == null) return null;
    return DateTime.now().difference(_lastActivityAt!);
  }

  /// Whether the connection appears idle (no activity beyond timeout)
  bool get isIdle {
    if (_state != ConnectionState.connected) return false;
    if (config.idleTimeout == Duration.zero) return false;
    final idle = idleDuration;
    if (idle == null) return false;
    return idle > config.idleTimeout;
  }

  /// Logger function, can be overridden for testing
  void Function(String message) log;

  static void _defaultLog(String message) {
    developer.log('[WebSocketConnectionManager] $message');
  }

  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_disposed) {
      log('Connect refused: $url - manager is disposed');
      return false;
    }

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

  Future<bool> _doConnect({DateTime? deadline}) async {
    if (_disposed) {
      log('Connect refused: $url - manager is disposed');
      return false;
    }

    if (_deadlineExpired(deadline)) return false;

    _setState(ConnectionState.connecting);

    WebSocketChannel? channel;
    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw ArgumentError('Invalid WebSocket URL scheme: ${uri.scheme}');
      }

      log('Connecting to $url');
      channel = _channelFactory.create(uri);
      _channel = channel;

      // Wait for the WebSocket handshake to complete. Without this,
      // IOWebSocketChannel.connect() returns immediately and DNS/TLS
      // failures surface as unhandled async errors in the zone instead
      // of being caught here.
      final handshakeTimeout = _remainingOr(config.connectionTimeout, deadline);
      if (handshakeTimeout == Duration.zero) throw TimeoutException('deadline');
      await channel.ready.timeout(handshakeTimeout);

      // A dispose, a disconnect, or a newer connect can all run inside the
      // handshake window, and each of them detaches this channel. Adopting it
      // anyway would arm a heartbeat `Timer.periodic` and hold a live socket
      // that no owner can reach — so nothing could ever close either (#7367).
      if (_disposed || !identical(_channel, channel)) {
        log('Discarding socket for $url: its owner went away mid-handshake');
        await _closeOrphanedChannel(channel);
        return false;
      }

      // Set up message listener
      _channelSubscription = channel.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );

      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;

      // Track connection time as initial activity
      _lastActivityAt = DateTime.now();

      // Start heartbeat timer if configured
      _startHeartbeat();

      log('Connected to $url');

      return true;
    } on WebSocketChannelException catch (e) {
      log('Connection failed (WebSocket): $e');
      _emitError('Connection failed: $e');
      _detachChannel(channel);
      _setState(ConnectionState.disconnected);
      return false;
    } on TimeoutException {
      log('Connection timed out before its allowed deadline');
      _emitError('Connection timed out');
      // Clean up the channel that never finished connecting
      await _closeOrphanedChannel(channel);
      _detachChannel(channel);
      _setState(ConnectionState.disconnected);
      return false;
    } catch (e) {
      log('Connection failed: $e');
      _emitError('Connection failed: $e');
      _detachChannel(channel);
      _setState(ConnectionState.disconnected);
      return false;
    }
  }

  /// Clears [_channel] unless something else already installed a different
  /// one, so a failing connect cannot null out a channel it does not own.
  ///
  /// A null [channel] means creation itself failed and there is no attempt
  /// left to keep — the field is cleared, as it always was.
  void _detachChannel(WebSocketChannel? channel) {
    if (channel == null || identical(_channel, channel)) _channel = null;
  }

  /// Closes a socket that no longer has an owner.
  Future<void> _closeOrphanedChannel(WebSocketChannel? channel) async {
    if (channel == null) return;
    await _closeSink(channel, description: 'orphaned channel');
  }

  /// Publishes to [errorStream] unless teardown already closed it.
  void _emitError(String message) {
    if (_errorController.isClosed) return;
    _errorController.add(message);
  }

  void _onMessage(dynamic message) {
    _lastActivityAt = DateTime.now();
    if (_messageController.isClosed) return;
    if (message is String) {
      _messageController.add(message);
    } else {
      _messageController.add(message.toString());
    }
  }

  void _onStreamError(dynamic error) {
    log('Stream error: $error');
    _emitError('Stream error: $error');
    _handleDisconnect();
  }

  void _onStreamDone() {
    log('Stream closed by remote');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _stopHeartbeat();

    // Must close the sink, not just drop the reference: the idle heartbeat
    // and checkHealth() tear down a *live* socket, and cancelling the stream
    // subscription alone leaves the underlying connection open forever.
    // Fire-and-forget because every caller is synchronous; _closeChannel
    // detaches _channel before its first await, so a reconnect racing this
    // close keeps its fresh channel.
    unawaited(_closeChannel());

    _setState(ConnectionState.disconnected);
    // No automatic reconnection - reconnect happens on-demand when sending
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _stopHeartbeat();

    await _closeChannel();
    _setState(ConnectionState.disconnected);
    log('Disconnected from $url');
  }

  Future<void> _closeChannel() async {
    _channelSubscription?.cancel();
    _channelSubscription = null;

    // Detach before the first await so callers that do not await this future
    // cannot have a later _doConnect's channel nulled out when the close
    // finally completes.
    final channel = _channel;
    _channel = null;
    if (channel == null) return;

    await _closeSink(channel, description: 'channel');
  }

  Future<void> _closeSink(
    WebSocketChannel channel, {
    required String description,
  }) async {
    try {
      await channel.sink.close().timeout(config.closeTimeout);
    } on TimeoutException {
      log('Timed out closing $description after ${config.closeTimeout}');
    } catch (e) {
      log('Error closing $description: $e');
    }
  }

  /// Send a message through the WebSocket.
  ///
  /// If disconnected, attempts to reconnect first (unless [skipReconnect]
  /// is true). Set [skipReconnect] to true for query fan-out paths where
  /// blocking on reconnection would delay all other relay queries.
  /// Returns true if message was sent, false if send failed.
  Future<bool> send(
    String message, {
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (_deadlineExpired(deadline)) return false;

    // Try to reconnect if disconnected
    if (_state == ConnectionState.disconnected) {
      if (skipReconnect) {
        log('Disconnected, skipping reconnect (skipReconnect=true)');
        return false;
      }
      log('Disconnected, attempting reconnect before send');
      final connected = await _tryReconnect(deadline: deadline);
      if (_deadlineExpired(deadline)) return false;
      if (!connected) {
        log('Reconnect failed, cannot send');
        return false;
      }
    }

    // Wait if currently connecting
    if (_state == ConnectionState.connecting) {
      log('Connecting, waiting before send');
      final connected = await _waitForConnection(deadline: deadline);
      if (_deadlineExpired(deadline)) return false;
      if (!connected) {
        log('Connection failed, cannot send');
        return false;
      }
    }

    if (_deadlineExpired(deadline)) return false;
    return _doSend(message);
  }

  bool _deadlineExpired(DateTime? deadline) {
    return deadline != null && !DateTime.now().isBefore(deadline);
  }

  /// Send a message synchronously (no reconnection attempt).
  ///
  /// Returns true if message was sent, false if not connected.

  bool _doSend(String message) {
    if (_channel == null) return false;

    try {
      _channel!.sink.add(message);
      return true;
    } catch (e) {
      log('Send error: $e');
      _emitError('Send error: $e');
      _handleDisconnect();
      return false;
    }
  }

  /// Send a JSON-encodable message asynchronously (with reconnection)
  Future<bool> sendJson(
    dynamic data, {
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (_deadlineExpired(deadline)) return false;

    final String encoded;
    try {
      encoded = jsonEncode(data);
    } catch (e) {
      log('JSON encode error: $e');
      _emitError('JSON encode error: $e');
      return false;
    }

    // Sending stays outside the try: [send] reports its own failures as
    // `false` plus a 'Send error' on [errorStream], and reporting one of
    // those as a JSON encode error would be wrong.
    return send(encoded, skipReconnect: skipReconnect, deadline: deadline);
  }

  /// Send a JSON-encodable message synchronously (no reconnection)

  // --- Reconnection ---

  Future<bool> _tryReconnect({DateTime? deadline}) async {
    final effectiveDeadline =
        deadline ?? DateTime.now().add(config.reconnectBudget);
    while (_shouldReconnect && _state == ConnectionState.disconnected) {
      if (_deadlineExpired(effectiveDeadline)) return false;
      if (_reconnectAttempts >= config.maxReconnectAttempts) {
        log('Max reconnect attempts reached for $url');
        _emitError('Max reconnect attempts reached');
        return false;
      }

      // Exponential backoff: base * 2^attempts, capped at max
      final delayMs =
          (config.baseReconnectDelay.inMilliseconds *
                  (1 << _reconnectAttempts.clamp(0, 8)))
              .clamp(0, config.maxReconnectDelay.inMilliseconds);
      final delay = Duration(milliseconds: delayMs);

      _reconnectAttempts++;
      log(
        'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/${config.maxReconnectAttempts})',
      );

      final wait = _remainingOr(delay, effectiveDeadline);
      if (wait == Duration.zero) return false;
      await Future<void>.delayed(wait);

      if (!_shouldReconnect || _deadlineExpired(effectiveDeadline)) {
        return false;
      }

      final connected = await _doConnect(deadline: effectiveDeadline);
      if (connected) return true;
    }

    return _state == ConnectionState.connected;
  }

  Duration _remainingOr(Duration fallback, DateTime? deadline) {
    if (deadline == null) return fallback;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      return Duration.zero;
    }
    if (remaining < fallback) return remaining;
    return fallback;
  }

  Future<bool> _waitForConnection({DateTime? deadline}) async {
    final waitTimeout = _connectionWaitTimeout(deadline);
    if (waitTimeout == Duration.zero) return false;

    // Wait up to connectionTimeout for connection to complete
    final completer = Completer<bool>();
    StreamSubscription<ConnectionState>? sub;

    sub = stateStream.listen((state) {
      if (state == ConnectionState.connected) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (state == ConnectionState.disconnected) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    // Also check current state
    if (_state == ConnectionState.connected) {
      sub.cancel();
      return true;
    }

    final result = await completer.future.timeout(
      waitTimeout,
      onTimeout: () {
        sub?.cancel();
        return false;
      },
    );

    return result;
  }

  Duration _connectionWaitTimeout(DateTime? deadline) {
    if (deadline == null) return config.connectionTimeout;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      return Duration.zero;
    }
    if (remaining < config.connectionTimeout) return remaining;
    return config.connectionTimeout;
  }

  /// Reset reconnection state, allowing fresh attempts
  void resetReconnection() {
    _reconnectAttempts = 0;
  }

  /// Force immediate reconnection, resetting backoff
  Future<bool> reconnect() async {
    if (_disposed) {
      log('Reconnect refused: $url - manager is disposed');
      return false;
    }

    resetReconnection();
    _shouldReconnect = true;
    // Neither resetReconnection nor _closeChannel touches the heartbeat, so
    // without this a reconnect that fails leaves the previous connection's
    // Timer.periodic running with nothing to beat on. disconnect() and
    // _handleDisconnect both stop it; this is the sibling that did not.
    _stopHeartbeat();
    await _closeChannel();
    _setState(ConnectionState.disconnected);
    return _doConnect();
  }

  // --- Heartbeat / Idle Detection ---

  void _startHeartbeat() {
    if (config.heartbeatInterval == Duration.zero) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      _onHeartbeat();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onHeartbeat() {
    if (_state != ConnectionState.connected) return;
    if (config.idleTimeout == Duration.zero) return;

    final idle = idleDuration;
    if (idle != null && idle > config.idleTimeout) {
      log(
        'Connection idle for ${idle.inSeconds}s (timeout: '
        '${config.idleTimeout.inSeconds}s), forcing disconnect',
      );
      _handleDisconnect();
    }
  }

  /// Check if the connection is healthy and force disconnect if idle.
  ///
  /// Returns true if the connection is healthy (connected and not idle),
  /// false if disconnected or was disconnected due to idle timeout.
  bool checkHealth() {
    if (_state != ConnectionState.connected) return false;

    if (isIdle) {
      log('Health check failed: connection idle, forcing disconnect');
      _handleDisconnect();
      return false;
    }

    return true;
  }

  // --- State management ---

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  /// Dispose of resources
  ///
  /// [_disposed] is set before the first await so a connect that is already
  /// in flight sees it the moment it resumes.
  Future<void> dispose() async {
    _disposed = true;
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _errorController.close();
  }
}
