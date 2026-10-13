// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';

abstract interface class RelayGateway {
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter);
  Future<void> publish(Map<String, dynamic> event);
}

abstract interface class AccountScopedStore {
  Future<void> put(String key, String value);
  Future<String?> get(String key);
  Future<void> clearAccount();
}

/// In-memory store; the app binds this to db_client/protected storage
/// keyed `concord:v1:<pubkey>` so account switches isolate data.
class InMemoryConcordStore implements AccountScopedStore {
  InMemoryConcordStore(this.pubkey);
  final String pubkey;
  final _data = <String, String>{};
  String scoped(String k) => 'concord:v1:$pubkey:$k';
  @override
  Future<void> put(String k, String v) async => _data[scoped(k)] = v;
  @override
  Future<String?> get(String k) async => _data[scoped(k)];
  @override
  Future<void> clearAccount() async =>
      _data.removeWhere((k, _) => k.startsWith('concord:v1:$pubkey:'));
}

class ConcordRepository {
  ConcordRepository({
    required this.relay,
    required this.store,
    required this.cipher,
  });
  final RelayGateway relay;
  final AccountScopedStore store;
  final StreamCipher cipher;
  final _messages = <ChatMessage>[];
  final _controls = <ControlEvent>[];

  Future<StreamEnvelope> send({
    required String communityId,
    required String channelId,
    required String author,
    required String body,
    required int createdAt,
  }) async {
    final streamId = deriveStreamId(communityId, channelId);
    final id = deriveMessageId(streamId, author, createdAt, body);
    _messages.add(
      ChatMessage(
        id: id,
        channelId: channelId,
        author: author,
        body: body,
        createdAt: createdAt,
      ),
    );
    final env = StreamEnvelope.seal(
      cipher,
      streamId: streamId,
      plaintext: body,
      createdAt: createdAt,
    );
    await relay.publish(env.toEventJson(author));
    await store.put('msg:$id', body);
    return env;
  }

  void ingestControl(ControlEvent c) => _controls.add(c);
  FoldedThread timeline({required int now}) =>
      foldControls(_messages, _controls, now: now);
  Future<void> acceptInvite(String communityId) =>
      store.put('invite:$communityId', 'accepted');
  Future<bool> hasAcceptedInvite(String communityId) async =>
      await store.get('invite:$communityId') == 'accepted';
}
