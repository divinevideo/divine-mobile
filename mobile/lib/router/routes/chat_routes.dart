// MPL-2.0
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';

class _NoopRelay implements RelayGateway {
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> f) =>
      const Stream.empty();
  @override
  Future<void> publish(Map<String, dynamic> e) async {}
}

class _IdentityCipher implements StreamCipher {
  @override
  String seal(String p, String s) => base64.encode(utf8.encode(p));
  @override
  String open(String c, String s) => utf8.decode(base64.decode(c));
}

/// POC routes; relay/signer binding replaces _NoopRelay with the active
/// session's nostr client without any new login flow.
List<RouteBase> chatRoutes() => [
  GoRoute(
    path: ChatScreen.path,
    name: 'chat',
    builder: (ctx, st) => BlocProvider(
      create: (_) => ChatCubit(
        ConcordRepository(
          relay: _NoopRelay(),
          store: InMemoryConcordStore('poc'),
          cipher: _IdentityCipher(),
        ),
      ),
      child: const ChatScreen(),
    ),
  ),
];
