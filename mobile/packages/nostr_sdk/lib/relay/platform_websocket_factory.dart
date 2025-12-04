// ABOUTME: Platform-specific WebSocketChannelFactory implementation.
// ABOUTME: Handles custom SSL certificate handling for non-web platforms.

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'relay_base_io.dart' if (dart.library.html) 'relay_base_web.dart';
import 'web_socket_connection_manager.dart';

/// {@template platform_websocket_channel_factory}
/// Platform-aware WebSocket channel factory.
///
/// On non-web platforms (iOS, Android, desktop), uses custom SSL handling
/// that accepts self-signed certificates for wss:// connections.
/// On web platform, uses standard WebSocket.connect().
/// {@endtemplate}
class PlatformWebSocketChannelFactory implements WebSocketChannelFactory {
  /// {@macro platform_websocket_channel_factory}
  const PlatformWebSocketChannelFactory();

  @override
  WebSocketChannel create(Uri uri) {
    if (uri.scheme == 'wss' && !kIsWeb) {
      // Use custom SSL handling on non-web platforms
      return createSecureWebSocketChannel(uri);
    } else {
      // Standard WebSocket for ws:// or web platform
      return createWebSocketChannel(uri);
    }
  }
}
