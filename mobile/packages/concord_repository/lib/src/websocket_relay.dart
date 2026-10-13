// MPL-2.0
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:concord_repository/src/concord_repository.dart';

/// Real relay gateway over a WebSocket (Nostr REQ/EVENT framing).
/// Bound in the app to the POC relay URL; session/signing stay in the
/// signer adapter, this class only moves frames.
class WebSocketRelayGateway implements RelayGateway {
  WebSocketRelayGateway(this.url);
  final String url;
  WebSocket? _ws;
  final _subs = <String, StreamController<Map<String, dynamic>>>{};
  final _pendingReqs = <String, Map<String, dynamic>>{};
  var _counter = 0;

  Future<void> connect() async {
    if (_ws != null) return;
    _ws = await WebSocket.connect(url);
    _ws!.listen((data) {
      try {
        final msg = jsonDecode(data as String) as List<dynamic>;
        if (msg.length >= 3 && msg[0] == 'EVENT') {
          _subs[msg[1] as String]?.add(
            Map<String, dynamic>.from(msg[2] as Map),
          );
        }
      } on FormatException {
        // Ignore malformed relay frames.
      }
    });
    for (final entry in _pendingReqs.entries) {
      _ws!.add(jsonEncode(['REQ', entry.key, entry.value]));
    }
    _pendingReqs.clear();
  }

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    final id = 'concord-${_counter++}';
    final controller = StreamController<Map<String, dynamic>>();
    _subs[id] = controller;
    final ws = _ws;
    if (ws != null) {
      ws.add(jsonEncode(['REQ', id, filter]));
    } else {
      _pendingReqs[id] = filter;
    }
    controller.onCancel = () {
      _ws?.add(jsonEncode(['CLOSE', id]));
      _subs.remove(id);
      _pendingReqs.remove(id);
    };
    return controller.stream;
  }

  @override
  Future<void> publish(Map<String, dynamic> event) async {
    await connect();
    _ws!.add(jsonEncode(['EVENT', event]));
  }

  Future<void> close() async {
    for (final id in _subs.keys.toList()) {
      _ws?.add(jsonEncode(['CLOSE', id]));
    }
    _subs.clear();
    _pendingReqs.clear();
    await _ws?.close();
    _ws = null;
  }
}
