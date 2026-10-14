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

  /// Closes both streams; safe to call more than once.
  ///
  /// Completes once every listener has received its done event, so a paused
  /// listener holds the future open until it resumes or cancels.
  @override
  Future<void> dispose() async {
    await Future.wait([_incomingCtrl.close(), _outgoingCtrl.close()]);
  }
}
