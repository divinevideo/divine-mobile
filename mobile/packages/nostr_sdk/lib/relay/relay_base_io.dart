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

/// RFC 6455 ping interval for non-web relay WebSockets.
///
/// dart:io closes a socket whose pong does not arrive within one interval, so
/// a dead link is noticed sooner, and the pings keep NAT and carrier mappings
/// open. Pongs never reach the stream, so they do not reset the idle timer in
/// `WebSocketConnectionManager`.
const Duration kRelayWebSocketPingInterval = Duration(seconds: 30);

/// Creates a WebSocket channel for non-web platforms.
WebSocketChannel createSecureWebSocketChannel(Uri wsUrl) {
  return IOWebSocketChannel.connect(
    wsUrl,
    pingInterval: kRelayWebSocketPingInterval,
    customClient: createSecureWebSocketHttpClient(),
  );
}

/// Creates a standard WebSocket channel for non-web platforms
WebSocketChannel createWebSocketChannel(Uri wsUrl) {
  return IOWebSocketChannel.connect(
    wsUrl,
    pingInterval: kRelayWebSocketPingInterval,
  );
}
