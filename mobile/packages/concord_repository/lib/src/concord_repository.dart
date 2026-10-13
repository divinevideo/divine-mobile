// MPL-2.0
import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/src/sealed_chat_transport.dart';
import 'package:concord_repository/src/websocket_relay.dart';

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
  final _sealed = <String, Map<String, dynamic>>{};

  List<String> get pendingIds => List.unmodifiable(_pendingIds);

  Future<void> _restoreOutbox() async {
    final saved = await store.get('sealed');
    if (saved == null) return;
    final records = jsonDecode(saved) as Map<String, dynamic>;
    _sealed.clear();
    for (final entry in records.entries) {
      final record = Map<String, dynamic>.from(entry.value as Map);
      _sealed[entry.key] = record;
      if (record['pending'] == true) _pendingIds.add(entry.key);
    }
  }

  final _changes = StreamController<void>.broadcast();
  Stream<void> get changes => _changes.stream;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _expiryTimer;
  Future<void> _writes = Future.value();
  bool _closed = false;
  bool _ready = false;
  bool _requiresRestore = false;
  String? _channelId;
  int _epoch = 0;
  late String _streamSeedHex;
  late String _streamPubkey;
  int Function() _now = () => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (!_closed) _changes.add(null);
  }

  Future<void> _record(String id, Map<String, dynamic> record) =>
      _serial(() async {
        if (_closed) throw StateError('chat is closed');
        final updated = {..._sealed, id: record};
        await store.put('sealed', jsonEncode(updated));
        _sealed[id] = record;
        _pendingIds.remove(id);
        if (record['pending'] == true) _pendingIds.add(id);
        _notify();
      });

  Future<void> _acknowledge(String id) => _serial(() async {
    final current = _sealed[id];
    if (_closed || current == null || current['pending'] != true) return;
    final updated = {...current, 'pending': false};
    await store.put('sealed', jsonEncode({..._sealed, id: updated}));
    _sealed[id] = updated;
    _pendingIds.remove(id);
    _notify();
  });

  /// Restores encrypted history and owns the selected channel subscription.
  Future<void> startChannel({
    required String channelId,
    required int epoch,
    required String streamSeedHex,
    required String streamPubkey,
    int Function()? now,
  }) async {
    if (_closed) throw StateError('chat is closed');
    _ready = false;
    _requiresRestore = true;
    await _subscription?.cancel();
    if (_closed) return;
    _subscription = null;
    _expiryTimer?.cancel();
    _channelId = channelId;
    _epoch = epoch;
    _streamSeedHex = streamSeedHex;
    _streamPubkey = streamPubkey;
    if (now != null) _now = now;
    await restore();
    if (_closed) return;
    await purgeExpired(now: _now());
    if (_closed) return;
    _controls.clear();
    for (final record in _sealed.values.toList()) {
      await _openRecord(Map<String, dynamic>.from(record['wrap'] as Map));
    }
    if (_closed) return;
    _ready = true;
    _subscription = sealedTransport!
        .subscribeWraps(streamPubkey: streamPubkey)
        .listen(
          (wrap) => unawaited(
            ingestSealedWrap(wrap).catchError((Object error, StackTrace stack) {
              if (!_closed) _changes.addError(error, stack);
            }),
          ),
          onError: (Object error, StackTrace stack) {
            if (!_closed) _changes.addError(error, stack);
          },
        );
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(
        purgeExpired(now: _now()).catchError((Object error, StackTrace stack) {
          if (!_closed) _changes.addError(error, stack);
        }),
      );
    });
    _notify();
  }

  String? _tag(Map<String, dynamic> rumor, String name) {
    for (final tag in (rumor['tags'] as List).cast<List<dynamic>>()) {
      if (tag.length >= 2 && tag[0] == name) return tag[1] as String;
    }
    return null;
  }

  int? _expiration(Map<String, dynamic> rumor) {
    if (rumor['kind'] == 5 || rumor['kind'] == 1740) return null;
    final expiration = _tag(rumor, 'expiration');
    if (expiration == null) return null;
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(expiration)) {
      throw const FormatException('invalid expiration');
    }
    return int.tryParse(expiration);
  }

  Future<Map<String, dynamic>> _open(Map<String, dynamic> wrap) async {
    final opened = await openSealedIncoming(
      wrap: wrap,
      expectedChannelId: _channelId!,
      expectedEpoch: _epoch,
      streamSeedHex: _streamSeedHex,
      streamPubkey: _streamPubkey,
    );
    final rumor = opened['rumor'] as Map<String, dynamic>;
    if (_tag(rumor, 'channel') != _channelId ||
        _tag(rumor, 'epoch') != '$_epoch') {
      throw const FormatException('channel binding mismatch');
    }
    return rumor;
  }

  Future<void> _openRecord(Map<String, dynamic> wrap) async {
    try {
      final rumor = await _open(wrap);
      if (!_closed) _applyRumor(rumor);
    } on FormatException {
      // Invalid local records never become timeline state.
    }
  }

  /// Validates, deduplicates and persists only unexpired encrypted events.
  Future<void> ingestSealedWrap(Map<String, dynamic> wrap) async {
    if (_closed) return;
    Map<String, dynamic> rumor;
    try {
      rumor = await _open(wrap);
    } on FormatException {
      return;
    }
    final expiration = _expiration(rumor);
    if (expiration != null && expiration <= _now()) return;
    if (!const {9, 1111, 5, 7, 3302}.contains(rumor['kind'])) return;
    final id = rumor['id'] as String;
    await _serial(() async {
      if (_closed) return;
      final existing = _sealed[id];
      if (existing != null) {
        if (existing['pending'] == true) {
          final acknowledged = {...existing, 'pending': false};
          await store.put('sealed', jsonEncode({..._sealed, id: acknowledged}));
          _sealed[id] = acknowledged;
          _pendingIds.remove(id);
          _notify();
        }
        return;
      }
      final record = <String, dynamic>{
        'wrap': wrap,
        'pending': false,
        'expiresAt': expiration,
      };
      await store.put('sealed', jsonEncode({..._sealed, id: record}));
      _sealed[id] = record;
      _applyRumor(rumor);
      _notify();
    });
  }

  void _applyRumor(Map<String, dynamic> rumor) {
    final id = rumor['id'] as String;
    final kind = rumor['kind'] as int;
    final expiresAt = _expiration(rumor);
    if (expiresAt != null && expiresAt <= _now()) return;
    if (kind == 9 || kind == 1111) {
      if (_messages.any((m) => m.id == id)) return;
      _messages.add(
        ChatMessage(
          id: id,
          channelId: _channelId!,
          author: rumor['pubkey'] as String,
          body: rumor['content'] as String,
          createdAt: rumor['created_at'] as int,
          ms: int.tryParse(_tag(rumor, 'ms') ?? '0') ?? 0,
          expiresAt: expiresAt,
          threadRootId: kind == 1111 ? _tag(rumor, 'E') : null,
        ),
      );
      return;
    }
    final type = switch (kind) {
      5 => ControlType.delete,
      7 => ControlType.reaction,
      3302 => ControlType.edit,
      _ => null,
    };
    if (type == null) return;
    for (final tag in (rumor['tags'] as List).cast<List<dynamic>>()) {
      if (tag.length < 2 || tag[0] != 'e') continue;
      _controls.add(
        ControlEvent(
          type: type,
          id: id,
          targetId: tag[1] as String,
          createdAt: rumor['created_at'] as int,
          ms: int.tryParse(_tag(rumor, 'ms') ?? '0') ?? 0,
          actor: rumor['pubkey'] as String,
          body: rumor['content'] as String,
          emoji: rumor['content'] as String,
        ),
      );
    }
  }

  Future<void> close() async {
    _closed = true;
    _expiryTimer?.cancel();
    await _subscription?.cancel();
    if (relay case final WebSocketRelayGateway gateway) await gateway.close();
    await _writes;
    await _changes.close();
  }

  /// Restores persisted messages after an offline restart and returns
  /// ids whose publish was interrupted (still pending) for retry.
  Future<List<String>> restore() async {
    _messages.clear();
    _pendingIds.clear();
    _controls.clear();
    await _restoreOutbox();
    final index = await store.get('index');
    if (index == null || index.isEmpty) return List.unmodifiable(_pendingIds);
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
  Future<void> retryPending({String? messageId}) async {
    await purgeExpired(now: _now());
    for (final id in [
      ..._pendingIds,
    ].where((id) => messageId == null || id == messageId)) {
      final sealed = _sealed[id];
      if (sealed != null) {
        try {
          await relay.publish(Map<String, dynamic>.from(sealed['wrap'] as Map));
        } on Object {
          if (_sealed[id]?['pending'] != false) rethrow;
        }
        await _acknowledge(id);
        continue;
      }
      final saved = await store.get('outgoing:$id');
      if (saved == null) {
        throw StateError('pending message has no saved envelope');
      }
      await relay.publish(jsonDecode(saved) as Map<String, dynamic>);
      await store.put('sent:$id', '1');
      _pendingIds.remove(id);
    }
  }

  /// Purges expired messages from memory and the account-scoped store.
  Future<void> purgeExpired({required int now}) async {
    await _serial(() async {
      if (_closed) return;
      final expired = _sealed.entries
          .where(
            (e) =>
                e.value['expiresAt'] is int &&
                (e.value['expiresAt'] as int) <= now,
          )
          .map((e) => e.key)
          .toSet();
      if (expired.isEmpty) return;
      final kept = {..._sealed}..removeWhere((id, _) => expired.contains(id));
      await store.put('sealed', jsonEncode(kept));
      _sealed
        ..clear()
        ..addAll(kept);
      _pendingIds.removeWhere(expired.contains);
      _messages.removeWhere((m) => expired.contains(m.id));
      _controls.clear();
      for (final record in _sealed.values) {
        if (_channelId != null) {
          await _openRecord(Map<String, dynamic>.from(record['wrap'] as Map));
        }
      }
      _notify();
    });
    if (_closed) return;
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
      for (final key in ['msg', 'meta', 'sent', 'outgoing']) {
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
    await store.put('outgoing:$id', jsonEncode(env.toEventJson(author)));
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
    if (_closed || (_requiresRestore && !_ready)) {
      throw StateError('chat history has not loaded');
    }
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
    final wrap = await transport.prepareRumor(
      rumor: rumor,
      streamSeedHex: streamSeedHex,
      streamPubkey: streamPubkey,
    );
    await _record(id, {'wrap': wrap, 'pending': true, 'expiresAt': expiresAt});
    _messages.add(
      ChatMessage(
        id: id,
        channelId: channelId,
        author: author,
        body: body,
        createdAt: createdAt,
        ms: ms,
        expiresAt: expiresAt,
      ),
    );
    _notify();
    try {
      await relay.publish(wrap);
    } on Object {
      if (_sealed[id]?['pending'] != false) rethrow;
    }
    await _acknowledge(id);
    return wrap;
  }

  /// Opens a received kind-1059 wrap through the sealed transport.
  Future<Map<String, dynamic>> openSealedIncoming({
    required Map<String, dynamic> wrap,
    required String expectedChannelId,
    required int expectedEpoch,
    required String streamSeedHex,
    required String streamPubkey,
  }) {
    final transport = sealedTransport;
    if (transport == null) {
      throw StateError('sealed transport requires the active Divine signer');
    }
    return transport.openIncoming(
      wrap: wrap,
      expectedChannelId: expectedChannelId,
      expectedEpoch: expectedEpoch,
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
