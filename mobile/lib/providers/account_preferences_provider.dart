// ABOUTME: Binds explicit preference services to the active Nostr account.
// ABOUTME: Keeps auth-dependent lifecycle wiring outside preference construction.

import 'dart:async';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/provider_detached_future.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/account_preference_store.dart';

final accountPreferenceStoreProvider = Provider<AccountPreferenceStore>((ref) {
  final store = AccountPreferenceStore(ref.watch(sharedPreferencesProvider));
  ref.onDispose(store.dispose);
  return store;
});

final accountPreferenceSyncProvider = Provider<AccountStateRepository?>((ref) {
  final identity = ref.watch(
    nostrSessionProvider.select(
      (session) => (
        pubkey: session.pubkey,
        tearingDown: session.phase == NostrSessionPhase.tearingDown,
      ),
    ),
  );
  final store = ref.watch(accountPreferenceStoreProvider);
  final pubkey = identity.pubkey;
  if (pubkey == null || identity.tearingDown) {
    store.detach();
    return null;
  }
  final client = ref.watch(nostrServiceProvider);
  final repository = AccountStateRepository(
    nostrClient: client,
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    pubkey: pubkey,
    signer: () => client.signer,
    namespace: 'divine/preferences/v1',
  );
  ref.onDispose(() {
    store.detach();
    unawaited(repository.close());
  });
  var bound = false;
  void startWhenReady(NostrSessionReadiness session) {
    if (bound &&
        session.isReadyForActiveClient &&
        session.pubkey == pubkey &&
        identical(session.client, client)) {
      runProviderDetached(
        repository.start(),
        'start account preference sync',
        logName: 'AccountPreferences',
      );
    }
  }

  ref.listen(nostrSessionProvider, (_, next) => startWhenReady(next));
  runProviderDetached(
    () async {
      await store.bind(repository);
      if (ref.mounted) {
        bound = true;
        startWhenReady(ref.read(nostrSessionProvider));
      }
    }(),
    'bind account preferences',
    logName: 'AccountPreferences',
  );
  return repository;
});

/// Conversation dismissals retain their own namespace and boundary semantics.
final accountDmStateProvider = Provider<AccountStateRepository?>((ref) {
  final identity = ref.watch(
    nostrSessionProvider.select(
      (session) => (
        pubkey: session.pubkey,
        tearingDown: session.phase == NostrSessionPhase.tearingDown,
      ),
    ),
  );
  final pubkey = identity.pubkey;
  if (pubkey == null || identity.tearingDown) {
    return null;
  }
  final client = ref.watch(nostrServiceProvider);
  final repository = AccountStateRepository(
    nostrClient: client,
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    pubkey: pubkey,
    signer: () => client.signer,
    namespace: 'divine/dm-dismissals/v1',
  );
  ref.onDispose(() => unawaited(repository.close()));
  void startWhenReady(NostrSessionReadiness session) {
    if (session.isReadyForActiveClient &&
        session.pubkey == pubkey &&
        identical(session.client, client)) {
      runProviderDetached(
        repository.start(),
        'start conversation state sync',
        logName: 'AccountPreferences',
      );
    }
  }

  ref.listen(nostrSessionProvider, (_, next) => startWhenReady(next));
  startWhenReady(ref.read(nostrSessionProvider));
  return repository;
});
