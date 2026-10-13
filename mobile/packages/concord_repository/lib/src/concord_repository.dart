// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/sealed_chat_transport.dart';

abstract interface class RelayGateway {
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter);
  Future<void> publish(Map<String, dynamic> event);
}

abstract interface class AccountScopedStore {
  Future<void> put(String key, String value);
  Future<String?> get(String key);
  Future<void> remove(String key);
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
  Future<void> remove(String k) async => _data.remove(scoped(k));
  @override
  Future<void> clearAccount() async =>
      _data.removeWhere((k, _) => k.startsWith('concord:v1:$pubkey:'));
}

class ConcordRepository {
  ConcordRepository({
    required this.relay,
    required this.store,
    required this.cipher,
    this.sealedTransport,
  });
  final RelayGateway relay;
  final AccountScopedStore store;
  final StreamCipher cipher;

  /// Live sealed-send transport (kind 1059 wraps). When present, sends
  /// prefer it over the legacy synchronous envelope path.
  final SealedChatTransport? sealedTransport;
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
      final meta = (await store.get('meta:$id'))?.split('|');
      final expiresAt = meta != null && meta.length > 3
          ? int.tryParse(meta[3])
          : null;
      if (expiresAt == null || now < expiresAt) {
        kept.add(id);
        continue;
      }
      _pendingIds.remove(id);
      for (final key in ['msg', 'meta', 'sent']) {
        await store.remove('$key:$id');
      }
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

  /// Sends a kind-9 rumor through the sealed plane: the transport seals
  /// it with the async session signer and publishes a kind-1059 wrap.
  /// Persists before publish so an interrupted send stays recoverable.
  Future<Map<String, dynamic>> sendSealedMessage({
    required String channelId,
    required String author,
    required String body,
    required int createdAt,
    required int ms,
    required String streamSeedHex,
    required String streamPubkey,
    int epoch = 0,
    int? expiresAt,
  }) async {
    final transport = sealedTransport;
    if (transport == null) {
      throw StateError('sealed transport requires the active Divine signer');
    }
    final tags = <List<String>>[
      ['channel', channelId],
      ['epoch', '$epoch'],
      ['ms', '$ms'],
      if (expiresAt != null) ['expiration', '$expiresAt'],
    ];
    final id = computeEventId(
      pubkey: author,
      createdAt: createdAt,
      kind: 9,
      tags: tags,
      content: body,
    );
    final rumor = <String, dynamic>{
      'id': id,
      'kind': 9,
      'pubkey': author,
      'created_at': createdAt,
      'tags': tags,
      'content': body,
    };
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
    final wrap = await transport.sendRumor(
      rumor: rumor,
      streamSeedHex: streamSeedHex,
      streamPubkey: streamPubkey,
    );
    await store.put('sent:$id', '1');
    _pendingIds.remove(id);
    return wrap;
  }

  /// Opens a received kind-1059 wrap through the sealed transport.
  Future<Map<String, dynamic>> openSealedIncoming({
    required Map<String, dynamic> wrap,
    required String streamSeedHex,
    required String streamPubkey,
  }) {
    final transport = sealedTransport;
    if (transport == null) {
      throw StateError('sealed transport requires the active Divine signer');
    }
    return transport.openIncoming(
      wrap: wrap,
      streamSeedHex: streamSeedHex,
      streamPubkey: streamPubkey,
    );
  }

  void ingestControl(ControlEvent c) => _controls.add(c);
  FoldedThread timeline({required int now}) =>
      foldControls(_messages, _controls, now: now);
  Future<void> acceptInvite(String communityId) =>
      store.put('invite:$communityId', 'accepted');
  Future<bool> hasAcceptedInvite(String communityId) async =>
      await store.get('invite:$communityId') == 'accepted';
}
