// ABOUTME: Platform-specific implementation for web platform
// ABOUTME: Provides WebSocket channel creation without dart:io dependencies

import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a WebSocket channel for web platform (no custom SSL handling needed)
WebSocketChannel createSecureWebSocketChannel(Uri wsUrl) {
  return WebSocketChannel.connect(wsUrl);
}

/// Creates a standard WebSocket channel for web platform
WebSocketChannel createWebSocketChannel(Uri wsUrl) {
  return WebSocketChannel.connect(wsUrl);
}