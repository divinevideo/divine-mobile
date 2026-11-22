// ABOUTME: Platform-specific implementation for non-web platforms (iOS, Android, desktop)
// ABOUTME: Provides access to IOWebSocketChannel and HttpClient for SSL certificate handling

import 'dart:io';

import 'package:nostr_sdk/utils/loopback_host.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Creates a WebSocket channel for non-web platforms.
///
/// Remote hosts go through platform certificate validation; self-signed
/// certificates are tolerated only for local-stack loopback hosts in debug
/// builds.
HttpClient createSecureWebSocketHttpClient() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (cert, host, port) =>
      allowsLocalBadCertificateHost(host);
  return httpClient;
}

/// Creates a WebSocket channel for non-web platforms.
WebSocketChannel createSecureWebSocketChannel(Uri wsUrl) {
  return IOWebSocketChannel.connect(
    wsUrl,
    customClient: createSecureWebSocketHttpClient(),
  );
}

/// Creates a standard WebSocket channel for non-web platforms
WebSocketChannel createWebSocketChannel(Uri wsUrl) {
  return WebSocketChannel.connect(wsUrl);
}
