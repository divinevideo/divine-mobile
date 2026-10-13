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
  final _pendingIds = <String>[];

  /// Restores persisted messages after an offline restart and returns
  /// ids whose publish was interrupted (still pending) for retry.
  Future<List<String>> restore() async {
    _messages.clear();
    _pendingIds.clear();
    final index = await store.get('index');
    if (index == null || index.isEmpty) return const [];
    for (final id in index.split(',')) {
      final body = await store.get('msg:$id');
      if (body == null) continue;
      final meta = (await store.get('meta:$id'))?.split('|');
      _messages.add(
        ChatMessage(
          id: id,
          channelId: meta != null && meta.isNotEmpty ? meta[0] : '',
          author: meta != null && meta.length > 1 ? meta[1] : '',
          body: body,
          createdAt: meta != null && meta.length > 2
              ? int.tryParse(meta[2]) ?? 0
              : 0,
          expiresAt: meta != null && meta.length > 3
              ? int.tryParse(meta[3])
              : null,
        ),
      );
      if (await store.get('sent:$id') != '1') _pendingIds.add(id);
    }
    return List.unmodifiable(_pendingIds);
  }

  /// Republishes messages whose publish was interrupted before restart.
  Future<void> retryPending() async {
    for (final id in [..._pendingIds]) {
      final m = _messages.where((x) => x.id == id).firstOrNull;
      if (m == null) continue;
      final env = StreamEnvelope.seal(
        cipher,
        streamId: deriveStreamId('', m.channelId),
        plaintext: m.body,
        createdAt: m.createdAt,
      );
      await relay.publish(env.toEventJson(m.author));
      await store.put('sent:$id', '1');
      _pendingIds.remove(id);
    }
  }

  /// Purges expired messages from memory and the account-scoped store.
  Future<void> purgeExpired({required int now}) async {
    _messages.removeWhere((m) => m.isExpiredAt(now));
    final index = await store.get('index');
    if (index == null) return;
    final kept = <String>[];
    for (final id in index.split(',').where((e) => e.isNotEmpty)) {
      if (_messages.any((m) => m.id == id)) kept.add(id);
    }
    await store.put('index', kept.join(','));
  }

  Future<StreamEnvelope> send({
    required String communityId,
    required String channelId,
    required String author,
    required String body,
    required int createdAt,
    int? expiresAt,
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
        expiresAt: expiresAt,
      ),
    );
    final env = StreamEnvelope.seal(
      cipher,
      streamId: streamId,
      plaintext: body,
      createdAt: createdAt,
    );
    // Persist before publish so an interrupted publish is recoverable.
    await store.put('msg:$id', body);
    await store.put(
      'meta:$id',
      '$channelId|$author|$createdAt|${expiresAt ?? ''}',
    );
    final index = await store.get('index');
    await store.put(
      'index',
      [if (index != null && index.isNotEmpty) index, id].join(','),
    );
    _pendingIds.add(id);
    await relay.publish(env.toEventJson(author));
    await store.put('sent:$id', '1');
    _pendingIds.remove(id);
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
