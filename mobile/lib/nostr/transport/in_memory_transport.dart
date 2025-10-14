// ABOUTME: In-memory Nostr transport for testing and fixtures
// ABOUTME: Allows injecting relay messages without network IO

import 'dart:async';
import 'package:openvine/nostr/transport/nostr_transport.dart';

/// In-memory transport for testing - no network IO
class InMemoryNostrTransport implements NostrTransport {
  final _incomingCtrl = StreamController<String>.broadcast(sync: true);
  final _outgoingCtrl = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get incoming => _incomingCtrl.stream;

  /// Stream of messages sent by client (for test assertions)
  Stream<String> get outgoingFromClient => _outgoingCtrl.stream;

  @override
  void send(String json) {
    if (!_outgoingCtrl.isClosed) {
      _outgoingCtrl.add(json);
    }
  }

  /// Inject a message from relay (for test fixtures)
  void injectFromRelay(String json) {
    if (!_incomingCtrl.isClosed) {
      _incomingCtrl.add(json);
    }
  }

  @override
  void dispose() {
    _incomingCtrl.close();
    _outgoingCtrl.close();
  }
}
