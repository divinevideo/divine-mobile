import 'dart:async';

import 'package:account_state_repository/account_state_repository.dart';
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
  }) : _client = client,
       _preferences = preferences,
       _signer = signer;

  final NostrClient _client;
  final SharedPreferences _preferences;
  final NostrSigner Function() _signer;
  final _accounts = <String, AccountStateRepository>{};

  AccountStateRepository _account(String pubkey) => _accounts.putIfAbsent(
    pubkey,
    () => AccountStateRepository(
      nostrClient: _client,
      sharedPreferences: _preferences,
      pubkey: pubkey,
      signer: _signer,
      namespace: 'divine:badge-dismissals',
      payloadEntriesKey: 'decisions',
      entryValueKey: 'hidden',
      cacheKeyPrefix: 'badge_dismissal_event_',
      defaultMergeRule: AccountStateMergeRule.falseWinsTie,
    ),
  );

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
  Future<void> close() async {
    await Future.wait(_accounts.values.map((account) => account.close()));
    _accounts.clear();
  }
}
