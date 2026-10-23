import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A field's conflict policy. Latest writes use deterministic value ties.
enum AccountStateMergeRule { latest, numericMaximum, falseWinsTie }

class AccountStateException implements Exception {
  const AccountStateException(this.message);
  final String message;
  @override
  String toString() => 'AccountStateException: $message';
}

typedef _Entry = ({Object? value, int updatedAt});

/// Account-scoped, durable per-field state encrypted to self using NIP-44/78.
///
/// Local persistence and network synchronization have separate queues: a slow
/// relay never holds up an edit. Every retained signed source is stored before
/// relay repair; unreadable schemas remain a durable publication barrier.
class AccountStateRepository {
  AccountStateRepository({
    required NostrClient nostrClient,
    required SharedPreferences sharedPreferences,
    required this.pubkey,
    required NostrSigner Function() signer,
    required this.namespace,
    String payloadEntriesKey = 'entries',
    String entryValueKey = 'value',
    String? cacheKeyPrefix,
    Map<String, AccountStateMergeRule> mergeRules = const {},
    AccountStateMergeRule defaultMergeRule = AccountStateMergeRule.latest,
  }) : _client = nostrClient,
       _preferences = sharedPreferences,
       _signer = signer,
       _payloadEntriesKey = payloadEntriesKey,
       _entryValueKey = entryValueKey,
       _cachePrefix = cacheKeyPrefix ?? 'account_state_${namespace}_',
       _mergeRules = Map.of(mergeRules),
       _defaultMergeRule = defaultMergeRule {
    _restore();
  }

  final String pubkey;
  final String namespace;
  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  final String _payloadEntriesKey;
  final String _entryValueKey;
  final String _cachePrefix;
  final Map<String, AccountStateMergeRule> _mergeRules;
  final AccountStateMergeRule _defaultMergeRule;
  Map<String, _Entry> _entries = {};
  List<Event> _events = [];
  final _decoded = <String, Map<String, _Entry>>{};
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  Future<void> _writes = Future<void>.value();
  Future<void> _syncs = Future<void>.value();
  StreamSubscription<Event>? _incoming;
  StreamSubscription<Map<String, RelayConnectionStatus>>? _statuses;
  bool _pending = false;
  bool _closed = false;
  bool _started = false;
  int _revision = 0;
  String get _cacheKey => '$_cachePrefix$pubkey';
  String get _stateKey => '${_cacheKey}_state';

  /// Keys belonging to one account, including the original badge cache.
  static Iterable<String> localAccountKeys(
    SharedPreferences preferences,
    String pubkey,
  ) => preferences.getKeys().where(
    (key) =>
        (key.startsWith('account_state_') ||
            key.startsWith('badge_dismissal_event_')) &&
        (key.endsWith('_$pubkey') || key.endsWith('_${pubkey}_state')),
  );

  Object? value(String key) => values[key];
  bool contains(String key) => _entries.containsKey(key);
  Map<String, Object?> get values => Map.unmodifiable({
    for (final entry in _entries.entries)
      entry.key: _copyValue(entry.value.value),
  });
  Stream<Map<String, Object?>> get changes => _controller.stream;
  bool get hasPendingChanges => _pending;

  Future<void> setValue(String key, Object? value) => setValues({key: value});

  Future<void> setValues(Map<String, Object?> values) {
    // Copy before queueing so callers cannot mutate the intended write.
    final copied = {
      for (final entry in values.entries) entry.key: _copyValue(entry.value),
    };
    return _write(() async {
      _ensureOpen();
      final next = Map.of(_entries);
      for (final entry in copied.entries) {
        final previous = next[entry.key];
        if (previous != null && _equal(previous.value, entry.value)) continue;
        final candidate = (
          value: entry.value,
          updatedAt: math.max(
            DateTime.now().millisecondsSinceEpoch,
            (previous?.updatedAt ?? 0) + 1,
          ),
        );
        if (_rule(entry.key) == AccountStateMergeRule.numericMaximum &&
            previous != null &&
            !_wins(entry.key, candidate, previous)) {
          continue;
        }
        next[entry.key] = candidate;
      }
      if (_same(next, _entries)) return;
      await _save(next, _events, pending: true);
      if (_closed) return;
      _entries = next;
      _pending = true;
      _revision++;
      _emit();
      if (_started) _backgroundSync();
    });
  }

  /// Imports only absent legacy fields at timestamp zero.
  Future<void> seed(Map<String, Object?> values) {
    final copied = {
      for (final entry in values.entries) entry.key: _copyValue(entry.value),
    };
    return _write(() async {
      _ensureOpen();
      final next = Map.of(_entries);
      for (final entry in copied.entries) {
        next.putIfAbsent(entry.key, () => (value: entry.value, updatedAt: 0));
      }
      if (_same(next, _entries)) return;
      await _save(next, _events, pending: true);
      if (_closed) return;
      _entries = next;
      _pending = true;
      _revision++;
      _emit();
    });
  }

  Future<void> start() async {
    _ensureOpen();
    if (_started) return;
    _started = true;
    _incoming = _client.subscribe(_filters).listen((event) {
      if (_closed ||
          !_belongs(event) ||
          _events.any((known) => known.id == event.id)) {
        return;
      }
      unawaited(
        _write(() async {
          if (_closed) return;
          final events = _unionEvents([..._events, event]);
          await _save(_entries, events, pending: _pending);
          if (_closed) return;
          _events = events;
          _backgroundSync();
        }).catchError((Object _) {}),
      );
    }, onError: (Object _) {});
    var connected = <String>{};
    _statuses = _client.relayStatusStream.listen((statuses) {
      final next = {
        for (final entry in statuses.entries)
          if (entry.value.isConnected) entry.key,
      };
      if (next.difference(connected).isNotEmpty) _backgroundSync();
      connected = next;
    }, onError: (Object _) {});
    _backgroundSync();
  }

  void _backgroundSync() {
    if (!_closed) unawaited(synchronize().catchError((Object _) {}));
  }

  /// Flushes pending writes after reading all configured relays.
  ///
  /// Compatibility adapters can resolve legacy inputs in [beforeMerge] while
  /// the remote query runs, then display verified state in [onReconciled]
  /// before best-effort repair finishes. Both hooks run inside the sync queue.
  Future<void> synchronize({
    Future<void> Function()? beforeMerge,
    void Function()? onReconciled,
  }) {
    if (_closed) return Future<void>.value();
    final result = _syncs.then(
      (_) => _synchronize(beforeMerge: beforeMerge, onReconciled: onReconciled),
    );
    _syncs = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _synchronize({
    Future<void> Function()? beforeMerge,
    void Function()? onReconciled,
  }) async {
    if (_closed) return;
    final signer = await _checkedSigner();
    if (_closed) return;
    final read = await _client.queryEventsDetailed(
      _filters,
      useCache: false,
      requireAllRelaysSettled: true,
    );
    if (_closed) return;
    await beforeMerge?.call();
    if (_closed) return;
    // Preserve even an unreadable own-account source before decoding it. A
    // later empty read must never allow this client to erase a newer schema.
    await _write(() async {
      if (_closed) return;
      final events = _unionEvents([..._events, ...read.events]);
      await _save(_entries, events, pending: _pending);
      if (!_closed) _events = events;
    });
    if (_closed) return;
    final candidates = _events.toList()..sort(_newestFirst);
    final snapshots = <String, Map<String, _Entry>>{};
    for (final event in candidates) {
      snapshots[event.id] = await _decode(signer, event);
      if (_closed) return;
    }
    final remote = <String, _Entry>{};
    for (final snapshot in snapshots.values) {
      _merge(remote, snapshot);
    }
    var publishing = <String, _Entry>{};
    var revision = 0;
    await _write(() async {
      if (_closed) return;
      final merged = Map.of(_entries);
      _merge(merged, remote);
      final additional = _events.where(
        (event) => !snapshots.containsKey(event.id),
      );
      final retained = <Event>[];
      if (candidates.isNotEmpty) retained.add(candidates.first);
      final missing = merged.keys.toSet();
      for (final event in candidates) {
        final contributed = snapshots[event.id]!.entries
            .where((entry) {
              final current = merged[entry.key];
              return missing.contains(entry.key) &&
                  current != null &&
                  current.updatedAt == entry.value.updatedAt &&
                  _equal(current.value, entry.value.value);
            })
            .map((entry) => entry.key)
            .toList();
        if (contributed.isEmpty) continue;
        if (!retained.any((known) => known.id == event.id)) retained.add(event);
        missing.removeAll(contributed);
      }
      final sources = _unionEvents([...retained, ...additional]);
      await _save(merged, sources, pending: _pending);
      if (_closed) return;
      _entries = merged;
      _events = sources;
      _emit();
      publishing = Map.of(merged);
      revision = _revision;
    });
    if (_closed) return;
    onReconciled?.call();
    if (read.noRelays || read.timedOut) {
      throw const AccountStateException('Incomplete account state read');
    }
    final latest = candidates.isEmpty ? null : candidates.first;
    final latestEntries = latest == null
        ? <String, _Entry>{}
        : snapshots[latest.id]!;
    // New sources arriving during decoding must be decoded before any repair.
    if (_events.any((event) => !snapshots.containsKey(event.id))) {
      _backgroundSync();
      return;
    }
    Event? confirmed;
    if (!_same(publishing, latestEntries)) {
      final content = await signer.nip44Encrypt(
        pubkey,
        jsonEncode({'version': 1, _payloadEntriesKey: _encode(publishing)}),
      );
      if (_closed) return;
      if (content == null || content.isEmpty) {
        throw const AccountStateException('Could not encrypt account state');
      }
      final unsigned = Event(
        pubkey,
        EventKind.appSpecificData,
        [
          ['d', namespace],
        ],
        content,
        createdAt: math.max(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          (latest?.createdAt ?? 0) + 1,
        ),
      );
      final expectedId = unsigned.id;
      final signed = await signer.signEvent(unsigned);
      if (_closed) return;
      if (signed == null || signed.id != expectedId || !_belongs(signed)) {
        throw const AccountStateException('Could not sign account state');
      }
      await _checkedSigner();
      if (_closed) return;
      await _confirm(signed);
      confirmed = signed;
      _remember(signed.id, publishing);
    } else if (latest != null &&
        !read.events.any((event) => event.id == latest.id)) {
      await _checkedSigner();
      if (_closed) return;
      await _confirm(latest);
      confirmed = latest;
    }
    if (_closed) return;
    await _write(() async {
      if (_closed) return;
      final unchanged = revision == _revision;
      // Compact only after a confirmed snapshot covers every durable field.
      final additional = _events.where(
        (event) => !snapshots.containsKey(event.id),
      );
      final events = _unionEvents([
        if (confirmed != null && _same(publishing, _entries))
          confirmed
        else
          ..._events,
        ...additional,
      ]);
      final pending = !unchanged && _pending;
      await _save(_entries, events, pending: pending);
      if (_closed) return;
      _events = events;
      _pending = pending;
    });
  }

  List<Filter> get _filters => [
    Filter(
      authors: [pubkey],
      kinds: [EventKind.appSpecificData],
      d: [namespace],
    ),
  ];

  Future<NostrSigner> _checkedSigner() async {
    final signer = _signer();
    if (await signer.getPublicKey() != pubkey) {
      throw const AccountStateException('Signer does not match account');
    }
    return signer;
  }

  Future<void> _confirm(Event event) async {
    final result = await _client.publishEventAwaitOk(event);
    if (!result.acceptedByAny) {
      throw const AccountStateException('No relay confirmed account state');
    }
  }

  Future<Map<String, _Entry>> _decode(NostrSigner signer, Event event) async {
    final known = _decoded[event.id];
    if (known != null) return known;
    final plaintext = await signer.nip44Decrypt(pubkey, event.content);
    if (plaintext == null) {
      throw const AccountStateException('Could not decrypt account state');
    }
    final Object? payload;
    try {
      payload = jsonDecode(plaintext);
    } on FormatException {
      throw const FormatException('Invalid account state');
    }
    if (payload is! Map<String, dynamic> ||
        payload['version'] != 1 ||
        payload[_payloadEntriesKey] is! Map<String, dynamic>) {
      throw const FormatException('Unsupported account state');
    }
    final entries = _parse(payload[_payloadEntriesKey]);
    _remember(event.id, entries);
    return entries;
  }

  Map<String, _Entry> _parse(Object? data) {
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid account state entries');
    }
    final entries = <String, _Entry>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic> ||
          !value.containsKey(_entryValueKey) ||
          value['updated_at'] is! int ||
          (value['updated_at'] as int) < 0 ||
          (_entryValueKey == 'hidden' && value[_entryValueKey] is! bool)) {
        throw const FormatException('Invalid account state entry');
      }
      entries[entry.key] = (
        value: value[_entryValueKey],
        updatedAt: value['updated_at'] as int,
      );
    }
    return entries;
  }

  Map<String, Object?> _encode(Map<String, _Entry> entries) => {
    for (final entry in entries.entries)
      entry.key: {
        _entryValueKey: entry.value.value,
        'updated_at': entry.value.updatedAt,
      },
  };

  void _restore() {
    final state = _preferences.getString(_stateKey);
    if (state != null) {
      try {
        final data = jsonDecode(state) as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Invalid local account state');
        }
        _entries = _parse(data['entries']);
        _pending = data['pending'] == true;
        _events = _parseEvents(data['events']);
      } on Object catch (_) {
        _entries = {};
        _pending = false;
        _events = [];
      }
    }
    final legacy = _preferences.getString(_cacheKey);
    if (legacy != null) {
      try {
        _events = _unionEvents([
          ..._events,
          ..._parseEvents(jsonDecode(legacy)),
        ]);
      } on Object catch (_) {
        /* Recover using the durable journal or relay. */
      }
    }
  }

  List<Event> _parseEvents(Object? data) => (data! as List<dynamic>)
      .map((value) => Event.fromJson(value! as Map<String, dynamic>))
      .where(_belongs)
      .toList();
  List<Event> _unionEvents(List<Event> events) => {
    for (final event in events)
      if (_belongs(event)) event.id: event,
  }.values.toList();
  bool _belongs(Event event) =>
      event.pubkey == pubkey &&
      event.kind == EventKind.appSpecificData &&
      event.dTagValue == namespace &&
      event.isValid &&
      event.isSigned;
  static int _newestFirst(Event left, Event right) {
    final time = right.createdAt.compareTo(left.createdAt);
    return time == 0 ? left.id.compareTo(right.id) : time;
  }

  Future<void> _save(
    Map<String, _Entry> entries,
    List<Event> events, {
    required bool pending,
  }) async {
    final encoded = jsonEncode({
      'version': 1,
      'entries': _encode(entries),
      'pending': pending,
      'events': events,
    });
    final previous = _preferences.getString(_stateKey);
    if (!await _preferences.setString(_stateKey, encoded)) {
      // SharedPreferences mutates its cache before the platform write succeeds.
      // Restore that cache too, so a new repository cannot read a failed edit.
      if (previous == null) {
        await _preferences.remove(_stateKey);
      } else {
        await _preferences.setString(_stateKey, previous);
      }
      throw const AccountStateException('Could not save account state');
    }
  }

  Future<void> _write(Future<void> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  AccountStateMergeRule _rule(String key) =>
      _mergeRules[key] ?? _defaultMergeRule;
  bool _wins(String key, _Entry next, _Entry previous) {
    if (_rule(key) == AccountStateMergeRule.numericMaximum &&
        next.value is num &&
        previous.value is num &&
        next.value != previous.value) {
      return (next.value! as num) > (previous.value! as num);
    }
    if (next.updatedAt != previous.updatedAt) {
      return next.updatedAt > previous.updatedAt;
    }
    if (next.value is bool && previous.value is bool) {
      return next.value == false;
    }
    return _canonical(next.value).compareTo(_canonical(previous.value)) > 0;
  }

  void _merge(Map<String, _Entry> target, Map<String, _Entry> source) {
    for (final entry in source.entries) {
      final previous = target[entry.key];
      if (previous == null || _wins(entry.key, entry.value, previous)) {
        target[entry.key] = entry.value;
      }
    }
  }

  static bool _equal(Object? left, Object? right) =>
      _canonical(left) == _canonical(right);
  static bool _same(Map<String, _Entry> left, Map<String, _Entry> right) =>
      left.length == right.length &&
      left.entries.every((entry) {
        final other = right[entry.key];
        return other != null &&
            other.updatedAt == entry.value.updatedAt &&
            _equal(other.value, entry.value.value);
      });
  static String _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return '{${keys.map((key) => '${jsonEncode(key)}:${_canonical(value[key])}').join(',')}}';
    }
    if (value is List) return '[${value.map(_canonical).join(',')}]';
    return jsonEncode(value);
  }

  static Object? _copyValue(Object? value) => jsonDecode(jsonEncode(value));
  void _remember(String id, Map<String, _Entry> entries) {
    _decoded[id] = entries;
    if (_decoded.length > 8) _decoded.remove(_decoded.keys.first);
  }

  void _emit() {
    if (!_closed) _controller.add(values);
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Account state repository is closed');
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _incoming?.cancel();
    await _statuses?.cancel();
    await _controller.close();
  }
}
