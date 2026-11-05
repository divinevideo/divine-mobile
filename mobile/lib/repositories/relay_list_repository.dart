// ABOUTME: Publishes the user's configured relay set as NIP-65 kind:10002.
// ABOUTME: Keeps relay-list event construction and retry state out of UI/BLoC.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const _relayListSignTimeout = Duration(seconds: 10);

/// Settings add/remove/restore awaits this publish before it can show the
/// user a result, so the OK wait is capped well below
/// [NostrClient.publishEventAwaitOk]'s 15s default: stacked on the signer
/// timeout that would leave the screen silent for 25s. A relay that has not
/// answered by now is not about to, and the dirty flag retries next session.
const _relayListPublishTimeout = Duration(seconds: 5);

const _dirtyRelayListPublishPrefix = 'relay_list_publish_dirty_';

enum RelayListPublishStatus {
  published,
  skippedNoKeys,
  skippedNonProduction,
  skippedNotDirty,
  failed,
}

class RelayListPublishResult {
  const RelayListPublishResult._({
    required this.status,
    this.error,
    this.stackTrace,
  });

  const RelayListPublishResult.published()
    : this._(status: RelayListPublishStatus.published);

  const RelayListPublishResult.skippedNoKeys()
    : this._(status: RelayListPublishStatus.skippedNoKeys);

  const RelayListPublishResult.skippedNonProduction()
    : this._(status: RelayListPublishStatus.skippedNonProduction);

  const RelayListPublishResult.skippedNotDirty()
    : this._(status: RelayListPublishStatus.skippedNotDirty);

  const RelayListPublishResult.failed(Object error, StackTrace stackTrace)
    : this._(
        status: RelayListPublishStatus.failed,
        error: error,
        stackTrace: stackTrace,
      );

  final RelayListPublishStatus status;
  final Object? error;
  final StackTrace? stackTrace;

  bool get synced => status == RelayListPublishStatus.published;
  bool get localOnly => switch (status) {
    RelayListPublishStatus.skippedNoKeys ||
    RelayListPublishStatus.failed => true,
    RelayListPublishStatus.published ||
    RelayListPublishStatus.skippedNonProduction ||
    RelayListPublishStatus.skippedNotDirty => false,
  };
}

final _relayListWrites = Expando<Future<void>>();

/// The source accepted by an indexer before it necessarily appears in reads.
/// Bootstrap and settings share it as well as their serialization queue.
Event? readAcceptedRelayList(SharedPreferences preferences, String pubkey) {
  final encoded = preferences.getString('relay_list_last_accepted_$pubkey');
  return encoded == null
      ? null
      : Event.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
}

/// Retains an accepted source across client recreation and process restarts.
Future<void> storeAcceptedRelayList(
  SharedPreferences preferences,
  Event event,
) async {
  await preferences.setString(
    'relay_list_last_accepted_${event.pubkey}',
    jsonEncode(event.toJson()),
  );
}

/// Serializes every kind-10002 read/write on a client, including bootstrap.
Future<T> serializeRelayListWrite<T>(
  NostrClient client,
  Future<T> Function() operation,
) {
  final result = (_relayListWrites[client] ?? Future<void>.value()).then(
    (_) => operation(),
  );
  _relayListWrites[client] = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace _) {},
  );
  return result;
}

class RelayListRepository {
  RelayListRepository({
    required NostrClient nostrClient,
    required EnvironmentConfig environment,
    required RelayDiscoveryService relayDiscoveryService,
    required SharedPreferences sharedPreferences,
    required List<DiscoveredRelay> Function() discoveredRelays,
  }) : _nostrClient = nostrClient,
       _environment = environment,
       _relayDiscoveryService = relayDiscoveryService,
       _sharedPreferences = sharedPreferences,
       _discoveredRelays = discoveredRelays;

  final NostrClient _nostrClient;
  final EnvironmentConfig _environment;
  final RelayDiscoveryService _relayDiscoveryService;
  final SharedPreferences _sharedPreferences;
  final List<DiscoveredRelay> Function() _discoveredRelays;

  /// Applies the explicit settings edit to a fresh relay list. Calls without
  /// an edit conservatively add configured relays; absence from this device's
  /// connection pool never implies the user removed a relay on another client.
  Future<RelayListPublishResult> publishConfiguredRelayList({
    String? addedRelay,
    String? removedRelay,
  }) {
    final pubkey = _nostrClient.publicKey;
    final configured = List<String>.of(_nostrClient.configuredRelays);
    return serializeRelayListWrite(
      _nostrClient,
      () => _publishConfiguredRelayList(
        pubkey,
        configured,
        addedRelay: addedRelay,
        removedRelay: removedRelay,
      ),
    );
  }

  Future<RelayListPublishResult> _publishConfiguredRelayList(
    String pubkey,
    List<String> configured, {
    String? addedRelay,
    String? removedRelay,
  }) async {
    if (!_nostrClient.hasKeys ||
        pubkey.isEmpty ||
        _nostrClient.publicKey != pubkey) {
      return const RelayListPublishResult.skippedNoKeys();
    }

    if (!_environment.isProduction) {
      Log.info(
        'Skipping kind:10002 publish outside production so environment-locked '
        'relay lists do not replace a user production list (#3183)',
        name: 'RelayListRepository',
        category: LogCategory.relay,
      );
      return const RelayListPublishResult.skippedNonProduction();
    }

    try {
      final pending = _pending(pubkey);
      if (addedRelay != null) {
        _putDelta(pending, addedRelay, true);
      } else if (removedRelay != null) {
        _putDelta(pending, removedRelay, false);
      } else if (pending.isEmpty) {
        for (final relay in configured) {
          _putDelta(pending, relay, true);
        }
      }
      await _sharedPreferences.setString(
        _pendingKey(pubkey),
        jsonEncode(pending),
      );
      await _markDirty(pubkey);
      final result = await _publishForPubkey(pubkey, pending);
      if (result.synced) {
        await _clearDirty(pubkey);
        await _sharedPreferences.remove(_pendingKey(pubkey));
      } else if (result.localOnly) {
        await _markDirty(pubkey);
      }
      return result;
    } catch (e, stackTrace) {
      await _markDirty(pubkey);
      Log.error(
        'kind:10002 relay-list publish failed: $e',
        name: 'RelayListRepository',
        category: LogCategory.relay,
        error: e,
        stackTrace: stackTrace,
      );
      return RelayListPublishResult.failed(e, stackTrace);
    }
  }

  Future<RelayListPublishResult> retryDirtyPublish() async {
    final pubkey = _nostrClient.publicKey;
    if (!_nostrClient.hasKeys || pubkey.isEmpty) {
      return const RelayListPublishResult.skippedNoKeys();
    }
    // Nothing pending is a no-op, not a failed sync — reporting it as
    // localOnly would make the retry bridge warn about a publish it never
    // attempted.
    if (!isDirty(pubkey)) return const RelayListPublishResult.skippedNotDirty();
    return publishConfiguredRelayList();
  }

  bool isDirty(String pubkey) =>
      (_sharedPreferences.getBool(_dirtyKey(pubkey)) ?? false) ||
      _sharedPreferences.containsKey(_pendingKey(pubkey));

  Map<String, bool> _pending(String pubkey) {
    final encoded = _sharedPreferences.getString(_pendingKey(pubkey));
    if (encoded == null) return {};
    return Map<String, bool>.from(jsonDecode(encoded) as Map);
  }

  String _pendingKey(String pubkey) => 'relay_list_publish_pending_$pubkey';

  void _putDelta(Map<String, bool> pending, String url, bool present) {
    pending.removeWhere((known, _) => relayUrlsEquivalent(known, url));
    pending[url] = present;
  }

  Future<RelayListPublishResult> _publishForPubkey(
    String pubkey,
    Map<String, bool> pending,
  ) async {
    final read = await _nostrClient.queryEventsDetailed(
      [
        Filter(authors: [pubkey], kinds: [EventKind.relayListMetadata]),
      ],
      useCache: false,
      requireAllRelaysSettled: true,
      tempRelays: _environment.indexerRelays,
    );
    if (read.noRelays || read.timedOut) {
      throw StateError('Cannot replace a relay list after an incomplete read');
    }
    Event? base;
    for (final event in [
      ...read.events,
      ?readAcceptedRelayList(_sharedPreferences, pubkey),
    ]) {
      if (event.pubkey != pubkey || event.kind != EventKind.relayListMetadata) {
        continue;
      }
      if (base == null ||
          event.createdAt > base.createdAt ||
          (event.createdAt == base.createdAt &&
              event.id.compareTo(base.id) < 0)) {
        base = event;
      }
    }
    final tags = [
      for (final tag in base?.tags ?? const <List<String>>[])
        if (!(tag.length >= 2 &&
            tag[0] == 'r' &&
            pending.entries.any(
              (edit) => !edit.value && relayUrlsEquivalent(edit.key, tag[1]),
            )))
          List<String>.of(tag),
    ];
    for (final edit in pending.entries) {
      if (!edit.value ||
          tags.any(
            (tag) =>
                tag.length >= 2 &&
                tag[0] == 'r' &&
                relayUrlsEquivalent(tag[1], edit.key),
          )) {
        continue;
      }
      tags.add(_buildRelayTags([edit.key]).single);
    }
    if (_nostrClient.publicKey != pubkey) {
      throw StateError('Account changed during relay-list read');
    }
    final unsigned = Event(
      pubkey,
      EventKind.relayListMetadata,
      tags,
      base?.content ?? '',
      createdAt: math.max(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        (base?.createdAt ?? 0) + 1,
      ),
    );

    final Event? signed;
    try {
      signed = await _nostrClient.signer
          .signEvent(unsigned)
          .timeout(_relayListSignTimeout);
    } on TimeoutException catch (e, stackTrace) {
      Log.warning(
        'kind:10002 relay-list publish signer timed out after '
        '${_relayListSignTimeout.inSeconds}s: $e',
        name: 'RelayListRepository',
        category: LogCategory.relay,
      );
      return RelayListPublishResult.failed(e, stackTrace);
    }

    if (signed == null ||
        signed.sig.isEmpty ||
        signed.pubkey != pubkey ||
        _nostrClient.publicKey != pubkey) {
      return RelayListPublishResult.failed(
        StateError('Signer returned an unsigned kind:10002 event'),
        StackTrace.current,
      );
    }

    final targetRelays = _publishTargets();
    final outcome = await _nostrClient.publishEventAwaitOk(
      signed,
      targetRelays: targetRelays,
      timeout: _relayListPublishTimeout,
    );
    final acceptedByIndexer = outcome.acceptedBy.any(
      _environment.indexerRelays.contains,
    );
    if (!acceptedByIndexer) {
      return RelayListPublishResult.failed(
        StateError('kind:10002 accepted by no indexer: ${outcome.summary}'),
        StackTrace.current,
      );
    }

    // Relay acceptance can precede serving the event, even across a restart.
    await storeAcceptedRelayList(_sharedPreferences, signed);
    final npub = Nip19.encodePubKey(pubkey);
    await _relayDiscoveryService.clearCache(npub);
    Log.info(
      'Published kind:10002 relay list for ${pubkeyForLogs(pubkey)} to an indexer',
      name: 'RelayListRepository',
      category: LogCategory.relay,
    );
    return const RelayListPublishResult.published();
  }

  List<List<String>> _buildRelayTags(List<String> configuredRelays) {
    final discovered = _discoveredRelays();
    return configuredRelays
        .map((relayUrl) {
          final marker = _markerFor(relayUrl, discovered);
          if (marker == null) return <String>['r', relayUrl];
          return <String>['r', relayUrl, marker];
        })
        .toList(growable: false);
  }

  String? _markerFor(String relayUrl, List<DiscoveredRelay> discovered) {
    for (final relay in discovered) {
      if (!relayUrlsEquivalent(relay.url, relayUrl)) continue;
      if (relay.read && !relay.write) return 'read';
      if (!relay.read && relay.write) return 'write';
      return null;
    }
    return null;
  }

  List<String> _publishTargets() {
    final targets = <String>{}
      ..addAll(_nostrClient.configuredRelays)
      ..addAll(_environment.indexerRelays);
    return targets.toList(growable: false);
  }

  Future<void> _markDirty(String pubkey) =>
      _sharedPreferences.setBool(_dirtyKey(pubkey), true);

  Future<void> _clearDirty(String pubkey) =>
      _sharedPreferences.remove(_dirtyKey(pubkey));

  String _dirtyKey(String pubkey) => '$_dirtyRelayListPublishPrefix$pubkey';
}
