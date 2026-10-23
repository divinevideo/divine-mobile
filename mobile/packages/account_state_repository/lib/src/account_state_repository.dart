import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:account_state_repository/src/account_state_storage.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// A field's conflict policy. Latest writes use deterministic value ties.
enum AccountStateMergeRule { latest, numericMaximum }

class AccountStateException implements Exception {
  const AccountStateException(this.message, {this.retryable = false});
  final String message;
  final bool retryable;
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
    this.perFieldSnapshots = false,
    AccountStateStorage? storage,
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
    _ready = storage == null ? Future<void>.value() : _restoreStorage(storage);
  }

  final String pubkey;
  final String namespace;
  final bool perFieldSnapshots;
  AccountStateStorage? _storage;
  late final Future<void> _ready;
  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  final String _payloadEntriesKey;
  final String _entryValueKey;
  final String _cachePrefix;
  final Map<String, AccountStateMergeRule> _mergeRules;
  final AccountStateMergeRule _defaultMergeRule;
  Map<String, _Entry> _entries = {};
  final _fieldTags = <String, String>{};
  List<Event> _events = [];
  final _receivedSources = <String, Event>{};
  final _decoded =
      <String, ({String fingerprint, Map<String, _Entry> entries})>{};
  final _verifiedSources = <String, String>{};
  final _controller = StreamController<Map<String, Object?>>.broadcast();
  Future<void> _writes = Future<void>.value();
  Future<void> _syncs = Future<void>.value();
  StreamSubscription<Event>? _incoming;
  StreamSubscription<Map<String, RelayConnectionStatus>>? _statuses;
  bool _pending = false;
  bool _closed = false;
  bool _started = false;
  bool _backgroundRunning = false;
  bool _backgroundRequested = false;
  Future<void>? _closing;
  String? _unreadableState;
  int _revision = 0;
  Timer? _retryTimer;
  var _retrySeconds = 1;
  String get _cacheKey => '$_cachePrefix$pubkey';
  String get _stateKey => '${_cacheKey}_state';
  String get _quarantineKey => 'account_state_quarantine_${namespace}_$pubkey';

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

  Object? value(String key) => _copyValue(_entries[key]?.value);
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
    await _ready;
    _ensureOpen();
    if (_started) return;
    _started = true;
    _incoming = _client.subscribe(_filters).listen((event) {
      if (_closed ||
          !_belongs(event) ||
          _events.any((known) => known.id == event.id) ||
          _receivedSources.containsKey(event.id)) {
        return;
      }
      // Receipt itself is an overwrite barrier, even if its journal write
      // fails. Keep the source in memory until a later durable write succeeds.
      _receivedSources[event.id] = event;
      unawaited(
        _write(() async {
          if (_closed) return;
          final events = _unionEvents([..._events, ..._receivedSources.values]);
          await _save(_entries, events, pending: _pending);
          if (_closed) return;
          _installSources(events);
          _backgroundSync();
        }).catchError((Object _) => _scheduleRetry()),
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
    if (_closed) return;
    _backgroundRequested = true;
    if (_backgroundRunning) return;
    _backgroundRunning = true;
    unawaited(_drainBackgroundSyncs());
  }

  Future<void> _drainBackgroundSyncs() async {
    try {
      do {
        _backgroundRequested = false;
        try {
          await synchronize();
        } on Object {
          // synchronize owns retry classification and persistence barriers.
        }
      } while (!_closed && _backgroundRequested);
    } finally {
      _backgroundRunning = false;
    }
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
    _syncs = result.then<void>(
      (_) {
        _clearRetry();
        // An older publication's success cannot cancel persistence retry for a
        // source that arrived while its acknowledgment was outstanding.
        if (_receivedSources.isNotEmpty) _scheduleRetry();
      },
      onError: (Object error, StackTrace _) {
        if (error is FormatException ||
            (error is AccountStateException && !error.retryable)) {
          _clearRetry();
          if (_receivedSources.isNotEmpty) _scheduleRetry(sourcesOnly: true);
        } else {
          _scheduleRetry();
        }
      },
    );
    return result;
  }

  void _scheduleRetry({bool sourcesOnly = false}) {
    if (!_started ||
        _closed ||
        _retryTimer != null ||
        (!_pending &&
            _entries.isEmpty &&
            _events.isEmpty &&
            _receivedSources.isEmpty)) {
      return;
    }
    _retryTimer = Timer(Duration(seconds: _retrySeconds), () {
      _retryTimer = null;
      if (sourcesOnly) {
        unawaited(
          _persistReceivedSources().then((_) {
            _clearRetry();
            if (_receivedSources.isNotEmpty) _scheduleRetry(sourcesOnly: true);
          }, onError: (Object _) => _scheduleRetry(sourcesOnly: true)),
        );
      } else {
        _backgroundSync();
      }
    });
    _retrySeconds = math.min(_retrySeconds * 2, 60);
  }

  void _clearRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retrySeconds = 1;
  }

  Future<void> _persistReceivedSources() => _write(() async {
    if (_closed || _receivedSources.isEmpty) return;
    // Receipt already verified signature, namespace and account. Persisting
    // this encrypted signed source never requires signer authorization.
    final sources = _unionEvents([..._events, ..._receivedSources.values]);
    await _save(_entries, sources, pending: _pending);
    if (!_closed) _installSources(sources);
  });

  Future<void> _synchronize({
    Future<void> Function()? beforeMerge,
    void Function()? onReconciled,
  }) async {
    await _ready;
    if (_closed) return;
    await _persistReceivedSources();
    if (_closed) return;
    final signer = await _checkedSigner();
    if (_closed) return;
    final read = perFieldSnapshots
        ? await _readFields()
        : await _client.queryEventsDetailed(
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
      final events = _unionEvents([
        ..._events,
        ..._receivedSources.values,
        ...read.events,
      ]);
      await _save(_entries, events, pending: _pending);
      if (!_closed) _installSources(events);
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
      if (perFieldSnapshots) {
        final tags = <String>{};
        for (final event in candidates) {
          if (tags.add(event.dTagValue) && !retained.contains(event)) {
            retained.add(event);
          }
        }
      }
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
      _installSources(sources);
      _emit();
      publishing = Map.of(merged);
      revision = _revision;
    });
    if (_closed) return;
    onReconciled?.call();
    if (read.noRelays || read.timedOut) {
      throw const AccountStateException(
        'Incomplete account state read',
        retryable: true,
      );
    }
    final latest = candidates.isEmpty ? null : candidates.first;
    final latestEntries = latest == null
        ? <String, _Entry>{}
        : snapshots[latest.id]!;
    // New sources arriving during decoding must be decoded before any repair.
    if (_hasNewSources(snapshots.keys.toSet())) {
      _backgroundSync();
      return;
    }
    if (perFieldSnapshots) {
      await _publishFields(
        signer,
        publishing,
        candidates,
        snapshots,
        read.events,
        revision,
      );
      return;
    }
    Event? confirmed;
    if (!_same(publishing, latestEntries)) {
      final content = await _signerRequest(
        () => signer.nip44Encrypt(
          pubkey,
          jsonEncode({'version': 1, _payloadEntriesKey: _encode(publishing)}),
        ),
        'Could not encrypt account state',
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
      final signed = await _signerRequest(
        () => signer.signEvent(unsigned),
        'Could not sign account state',
      );
      if (_closed) return;
      if (signed == null || signed.id != expectedId || !_belongs(signed)) {
        throw const AccountStateException('Could not sign account state');
      }
      _remember(signed.id, jsonEncode(signed.toJson()), publishing);
      await _checkedSigner();
      if (_closed) return;
      if (!await _confirmCurrent(signed, snapshots.keys.toSet())) return;
      confirmed = signed;
    } else if (latest != null &&
        !read.events.any((event) => event.id == latest.id)) {
      await _checkedSigner();
      if (_closed) return;
      if (!await _confirmCurrent(latest, snapshots.keys.toSet())) return;
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
      _installSources(events);
      _pending = pending;
    });
  }

  bool _isFieldTag(String tag) =>
      RegExp('^${RegExp.escape(namespace)}/field/[0-9a-f]{64}\$').hasMatch(tag);

  void _learnFieldTag(String key, String tag) {
    final previous = _fieldTags[key];
    if (previous == null || tag.compareTo(previous) < 0) _fieldTags[key] = tag;
  }

  String _newFieldTag() {
    final random = math.Random.secure();
    final address = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '$namespace/field/$address';
  }

  Future<void> _publishFields(
    NostrSigner signer,
    Map<String, _Entry> publishing,
    List<Event> candidates,
    Map<String, Map<String, _Entry>> snapshots,
    List<Event> remoteEvents,
    int revision,
  ) async {
    final sources = snapshots.keys.toSet();
    final keys = publishing.keys.toList()..sort();
    if (keys.any((key) => !_fieldTags.containsKey(key))) {
      await _write(() async {
        if (_closed) return;
        final previous = Map<String, String>.of(_fieldTags);
        for (final key in keys) {
          _fieldTags.putIfAbsent(key, _newFieldTag);
        }
        try {
          // Save all new opaque addresses in one transaction before signing.
          await _save(_entries, _events, pending: _pending);
        } on Object {
          _fieldTags
            ..clear()
            ..addAll(previous);
          rethrow;
        }
      });
    }
    for (final key in keys) {
      if (_closed) return;
      if (_hasNewSources(sources)) {
        _backgroundSync();
        return;
      }
      final tag = _fieldTags[key]!;
      final matching = candidates.where((event) => event.dTagValue == tag);
      final latest = matching.isEmpty ? null : matching.first;
      final field = {key: publishing[key]!};
      Event? confirmed;
      if (latest == null || !_same(field, snapshots[latest.id]!)) {
        final plaintext = jsonEncode({
          'version': 1,
          _payloadEntriesKey: _encode(field),
        });
        if (utf8.encode(plaintext).length > 65535) {
          Log.warning(
            'Account state field exceeds NIP-44 plaintext limit; pending intent retained',
            name: 'AccountStateRepository',
            category: LogCategory.system,
          );
          throw const AccountStateException(
            'Account state field exceeds NIP-44 plaintext limit',
          );
        }
        final content = await _signerRequest(
          () => signer.nip44Encrypt(pubkey, plaintext),
          'Could not encrypt account state',
        );
        if (_closed) return;
        if (content == null || content.isEmpty) {
          throw const AccountStateException('Could not encrypt account state');
        }
        final unsigned = Event(
          pubkey,
          EventKind.appSpecificData,
          [
            ['d', tag],
          ],
          content,
          createdAt: math.max(
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
            (latest?.createdAt ?? 0) + 1,
          ),
        );
        final expected = unsigned.id;
        final signed = await _signerRequest(
          () => signer.signEvent(unsigned),
          'Could not sign account state',
        );
        if (_closed) return;
        if (signed == null || signed.id != expected || !_belongs(signed)) {
          throw const AccountStateException('Could not sign account state');
        }
        _remember(signed.id, jsonEncode(signed.toJson()), field);
        await _checkedSigner();
        if (_closed || !await _confirmCurrent(signed, sources)) return;
        confirmed = signed;
      } else if (!remoteEvents.any((event) => event.id == latest.id)) {
        await _checkedSigner();
        if (_closed || !await _confirmCurrent(latest, sources)) return;
        confirmed = latest;
      }
      if (confirmed != null) {
        final accepted = confirmed;
        // Commit every acknowledged shard independently. A later refusal or
        // network failure must not republish already acknowledged siblings.
        await _write(() async {
          if (_closed) return;
          final events = _unionEvents([
            ..._events.where(
              (event) => event.dTagValue != tag || !sources.contains(event.id),
            ),
            accepted,
          ]);
          await _save(_entries, events, pending: _pending);
          if (!_closed) _installSources(events);
        });
        sources.add(accepted.id);
      }
    }
    await _write(() async {
      if (_closed || _hasNewSources(sources)) return;
      final pending = revision != _revision && _pending;
      await _save(_entries, _events, pending: pending);
      if (!_closed) _pending = pending;
    });
  }

  void _restoreFieldTags(Object? value) {
    if (value == null) return;
    for (final entry in (value as Map<String, dynamic>).entries) {
      final tag = entry.value as String;
      if (!_isFieldTag(tag)) {
        throw const FormatException('Invalid local shard address');
      }
      _learnFieldTag(entry.key, tag);
    }
  }

  Future<void> _restoreStorage(AccountStateStorage storage) async {
    final saved = await storage.read();
    if (saved != null) {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      if (data['version'] != 1) {
        throw const FormatException('Unsupported durable account state');
      }
      final entries = _parse(data['entries']);
      _restoreFieldTags(data['fieldTags']);
      _merge(entries, _entries);
      _entries = entries;
      _pending = _pending || data['pending'] == true;
      _events = _unionEvents([..._parseEvents(data['events']), ..._events]);
    }
    _storage = storage;
    await _save(_entries, _events, pending: _pending);
    // Only retire readable migration inputs after the durable transaction.
    for (final key in [_stateKey, _cacheKey]) {
      final raw = _preferences.getString(key);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (key == _stateKey) {
          final data = decoded as Map<String, dynamic>;
          if (data['version'] != 1) continue;
          _parse(data['entries']);
          _parseEvents(data['events']);
        } else {
          _parseEvents(decoded);
        }
      } on Object {
        continue;
      }
      await _preferences.remove(key);
    }
    _emit();
  }

  Future<({List<Event> events, bool timedOut, bool noRelays})>
  _readFields() async {
    // The existing pager retains cap/exhaustion evidence which the one-shot
    // query API reduces to terminal-frame settlement. Its finite defaults are
    // 500 events/page, 50 pages and two minutes for the whole walk.
    final read = await _client.readAllEvents(_filters.single);
    if (!read.isComplete) {
      Log.warning(
        'Account state shard discovery incomplete; publication deferred',
        name: 'AccountStateRepository',
        category: LogCategory.relay,
      );
    }
    return (
      events: read.events,
      timedOut: !read.isComplete,
      noRelays: read.stoppedBy == QueryEnd.noRelay,
    );
  }

  List<Filter> get _filters => [
    Filter(
      authors: [pubkey],
      kinds: [EventKind.appSpecificData],
      d: perFieldSnapshots ? null : [namespace],
    ),
  ];

  Future<T> _signerRequest<T>(
    Future<T> Function() request,
    String failure,
  ) async {
    try {
      return await request();
    } on Object {
      throw AccountStateException(failure);
    }
  }

  Future<NostrSigner> _checkedSigner() => _signerRequest(() async {
    final signer = _signer();
    if (await signer.getPublicKey() != pubkey) {
      throw const AccountStateException('Signer does not match account');
    }
    return signer;
  }, 'Signer does not match account or is unavailable');

  bool _hasNewSources(Set<String> known) =>
      _events.any((source) => !known.contains(source.id)) ||
      _receivedSources.keys.any((id) => !known.contains(id));

  void _installSources(List<Event> persisted) {
    for (final source in persisted) {
      _receivedSources.remove(source.id);
    }
    _events = _unionEvents([...persisted, ..._receivedSources.values]);
    final ids = _events.map((event) => event.id).toSet();
    _verifiedSources.removeWhere((id, _) => !ids.contains(id));
    _decoded.removeWhere((id, _) => !ids.contains(id));
  }

  Future<bool> _confirmCurrent(Event event, Set<String> sources) async {
    Future<void>? publication;
    // Fence all incoming source writes already queued during asynchronous
    // encryption/signing/signer checks. Check and send in the same synchronous
    // turn, then release the local queue before waiting for network response.
    await _write(() async {
      if (_closed) return;
      if (_hasNewSources(sources)) {
        _backgroundSync();
        return;
      }
      publication = _confirm(event)..ignore();
    });
    if (publication == null) return false;
    await publication;
    return !_closed;
  }

  Future<void> _confirm(Event event) async {
    final result = await _client.publishEventAwaitOk(event);
    if (!result.acceptedByAny) {
      throw const AccountStateException(
        'No relay confirmed account state',
        retryable: true,
      );
    }
  }

  Future<Map<String, _Entry>> _decode(NostrSigner signer, Event event) async {
    final fingerprint = jsonEncode(event.toJson());
    final known = _decoded[event.id];
    if (known != null && known.fingerprint == fingerprint) return known.entries;
    final plaintext = await _signerRequest(
      () => signer.nip44Decrypt(pubkey, event.content),
      'Could not decrypt account state',
    );
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
    if (event.dTagValue != namespace) {
      if (entries.length != 1 || !_isFieldTag(event.dTagValue)) {
        throw const FormatException('Invalid account state shard');
      }
      _learnFieldTag(entries.keys.single, event.dTagValue);
    }
    _remember(event.id, fingerprint, entries);
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
        _restoreFieldTags(data['fieldTags']);
        _pending = data['pending'] == true;
        _events = _parseEvents(data['events']);
      } on Object catch (error) {
        Log.warning(
          'Unreadable legacy account journal preserved (${error.runtimeType})',
          name: 'AccountStateRepository',
          category: LogCategory.storage,
        );
        _unreadableState = state;
        _fieldTags.clear();
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
  bool _belongs(Event event) {
    if (event.pubkey != pubkey ||
        event.kind != EventKind.appSpecificData ||
        !(event.dTagValue == namespace ||
            (perFieldSnapshots && _isFieldTag(event.dTagValue)))) {
      return false;
    }
    // Event is mutable in nostr_sdk. Reuse verification only when every
    // serialized signed byte is unchanged, never merely by ID/object identity.
    final fingerprint = jsonEncode(event.toJson());
    if (_verifiedSources[event.id] == fingerprint) return true;
    if (!event.isValid || !event.isSigned) return false;
    _verifiedSources[event.id] = fingerprint;
    return true;
  }

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
      'fieldTags': _fieldTags,
      'events': events,
    });
    final storage = _storage;
    if (storage != null) {
      await storage.write(encoded);
      return;
    }
    final unreadable = _unreadableState;
    if (unreadable != null) {
      final sources = _quarantinedSources(
        _preferences.getString(_quarantineKey),
      );
      if (!sources.contains(unreadable)) sources.add(unreadable);
      // Preserve unreadable bytes before replacing the journal. The fixed key
      // belongs to localAccountKeys and is removed by explicit owner erasure.
      await _writePreference(_quarantineKey, jsonEncode(sources));
    }
    await _writePreference(_stateKey, encoded);
    _unreadableState = null;
  }

  List<String> _quarantinedSources(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>().toList();
    } on Object {
      // A damaged archive is itself a recovery source; never discard it.
      return [raw];
    }
  }

  Future<void> _writePreference(String key, String value) async {
    final previous = _preferences.getString(key);
    try {
      if (!await _preferences.setString(key, value)) {
        throw const AccountStateException(
          'Could not save account state',
          retryable: true,
        );
      }
    } on Object catch (error, stack) {
      // SharedPreferences changes its cache before the platform write. Restore
      // that cache for both rejected and thrown writes. A rollback's platform
      // failure must not replace the original error; its cache change is eager
      // too, so the previous local value is restored even if it throws.
      try {
        if (previous == null) {
          await _preferences.remove(key);
        } else {
          await _preferences.setString(key, previous);
        }
      } on Object catch (_) {
        // Preserve the original persistence error and stack.
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  Future<void> _write(Future<void> Function() operation) {
    final result = _writes.then((_) async {
      await _ready;
      await operation();
    });
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
  void _remember(String id, String fingerprint, Map<String, _Entry> entries) {
    // A shard set has no fixed source count. Retain exactly the durable source
    // working set, pruned by _installSources, rather than an eight-item LRU.
    // Event is mutable, so an ID alone must never authorize a decoded hit.
    _decoded[id] = (fingerprint: fingerprint, entries: entries);
  }

  void _emit() {
    if (!_closed) _controller.add(values);
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Account state repository is closed');
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _clearRetry();
    await _incoming?.cancel();
    await _statuses?.cancel();
    // Drain local storage, including asynchronous migration, before an owner
    // erasure can delete its rows. Network acknowledgments never gate close.
    try {
      await _ready;
    } on Object {
      /* Preserve the original readiness error. */
    }
    await _writes;
    await _controller.close();
  }
}
