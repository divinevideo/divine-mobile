import 'dart:async';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:badge_repository/src/nip58_badge_models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local persistence failures remain visible to badge callers.
class BadgeDismissalSyncException implements Exception {
  const BadgeDismissalSyncException(this.message);
  final String message;
  @override
  String toString() => 'BadgeDismissalSyncException: $message';
}

/// Compatibility facade for the original encrypted badge namespace and schema.
class BadgeDismissalSync {
  BadgeDismissalSync({
    required NostrClient client,
    required SharedPreferences preferences,
    required NostrSigner Function() signer,
    this.onAccountCreated,
  }) : _client = client,
       _preferences = preferences,
       _signer = signer;

  /// Registers the exact owner's local write drain before any account work.
  final void Function(String owner, Future<void> Function() close)?
  onAccountCreated;

  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  final _accounts = <String, AccountStateRepository>{};

  final _closedOwners = <String>{};
  final _compatibilityWrites = <String, Set<Future<void>>>{};
  bool _closed = false;

  AccountStateRepository _account(String pubkey) {
    if (_closed || _closedOwners.contains(pubkey)) {
      throw StateError('Badge account state is closed');
    }
    final existing = _accounts[pubkey];
    if (existing != null) return existing;
    final account = AccountStateRepository(
      nostrClient: _client,
      sharedPreferences: _preferences,
      pubkey: pubkey,
      signer: _signer,
      namespace: 'divine:badge-dismissals',
      payloadEntriesKey: 'decisions',
      entryValueKey: 'hidden',
      cacheKeyPrefix: 'badge_dismissal_event_',
    );
    _accounts[pubkey] = account;
    onAccountCreated?.call(pubkey, () => _closeAccount(pubkey));
    if (_closed || _closedOwners.contains(pubkey)) {
      throw StateError('Badge account state is closed');
    }
    return account;
  }

  Set<String> _hidden(AccountStateRepository account) => {
    for (final entry in account.values.entries)
      if (entry.value == true) entry.key,
  };

  /// Displays a verified durable union before best-effort repair completes.
  Future<Set<String>> load(String pubkey, FutureOr<Set<String>> local) async {
    final account = _account(pubkey);
    final localFuture = Future<Set<String>>.value(local)..ignore();
    final displayed = Completer<Set<String>>();
    Future<void> seed() async {
      final choices = await localFuture;
      await account.seed({for (final coordinate in choices) coordinate: true});
    }

    unawaited(() async {
      try {
        await account.synchronize(
          beforeMerge: seed,
          onReconciled: () {
            if (!displayed.isCompleted) displayed.complete(_hidden(account));
          },
        );
        if (!displayed.isCompleted) displayed.complete(_hidden(account));
      } on Object catch (_) {
        try {
          await seed();
          if (!displayed.isCompleted) displayed.complete(_hidden(account));
        } on Object catch (error, stack) {
          if (!displayed.isCompleted) displayed.completeError(error, stack);
        }
      }
    }());
    return displayed.future;
  }

  /// Commits locally before returning; relay failures retain pending work.
  Future<Set<String>> setHidden(
    String pubkey,
    Set<String> local,
    String coordinate, {
    required bool hidden,
  }) async {
    final account = _account(pubkey);
    try {
      await account.seed({for (final legacy in local) legacy: true});
      await account.setValue(coordinate, hidden);
    } on AccountStateException {
      throw const BadgeDismissalSyncException('Could not save decisions');
    }
    unawaited(account.synchronize().catchError((Object _) {}));
    return _hidden(account);
  }

  Future<void> synchronize(String pubkey) => _account(pubkey).synchronize();
  Future<void> start(String pubkey) => _account(pubkey).start();
  Future<void> _closeAccount(String pubkey) async {
    _closedOwners.add(pubkey);
    await _accounts[pubkey]?.close();
    while (_compatibilityWrites[pubkey]?.isNotEmpty ?? false) {
      await Future.wait(_compatibilityWrites[pubkey]!.toList());
    }
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait(_accounts.keys.map(_closeAccount));
  }

  /// Compatibility inputs must be erased alongside the encrypted journal.
  static Iterable<String> localCompatibilityKeys(String pubkey) => [
    _coordinatesKey(pubkey),
    _awardsKey(pubkey),
  ];

  static String _coordinatesKey(String pubkey) =>
      'dismissed_badge_coordinates_$pubkey';
  static String _awardsKey(String pubkey) => 'dismissed_badge_awards_$pubkey';

  Set<String> storedCoordinates(String pubkey) {
    _account(pubkey);
    return (_preferences.getStringList(_coordinatesKey(pubkey)) ??
            const <String>[])
        .toSet();
  }

  Future<void> _writeCompatibility(
    String pubkey,
    Future<void> Function() action,
  ) {
    _account(pubkey);
    final pending = _compatibilityWrites.putIfAbsent(pubkey, () => {});
    final operation = Future<void>.sync(action);
    late final Future<void> settled;
    settled = operation
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => pending.remove(settled));
    pending.add(settled);
    return operation;
  }

  Future<void> writeCoordinates(String pubkey, Set<String> coordinates) =>
      _writeCompatibility(pubkey, () async {
        if (!await _preferences.setStringList(
          _coordinatesKey(pubkey),
          coordinates.toList(growable: false),
        )) {
          throw const BadgeDismissalSyncException('Could not save badge cache');
        }
      });

  /// Retires legacy award IDs only after their coordinates have been saved.
  Future<Set<String>> localCoordinates(
    String pubkey,
    List<Nip58BadgeAward> awards,
  ) async {
    final dismissed = storedCoordinates(pubkey);
    final legacyIds =
        (_preferences.getStringList(_awardsKey(pubkey)) ?? const <String>[])
            .toSet();
    if (legacyIds.isEmpty) return dismissed;
    final retired = <String>{};
    for (final award in awards) {
      if (legacyIds.contains(award.event.id)) {
        retired.add(award.event.id);
        dismissed.add(award.definitionCoordinate);
      }
    }
    if (retired.isEmpty) return dismissed;
    legacyIds.removeAll(retired);
    await writeCoordinates(pubkey, dismissed);
    await _writeCompatibility(pubkey, () async {
      final saved = legacyIds.isEmpty
          ? await _preferences.remove(_awardsKey(pubkey))
          : await _preferences.setStringList(
              _awardsKey(pubkey),
              legacyIds.toList(growable: false),
            );
      if (!saved) {
        throw const BadgeDismissalSyncException('Could not retire badge cache');
      }
    });
    return dismissed;
  }
}
