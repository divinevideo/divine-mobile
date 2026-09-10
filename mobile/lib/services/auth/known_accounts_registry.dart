// ABOUTME: Persistent registry of previously used accounts — the multi-account
// ABOUTME: welcome-screen picker source. Owns known-accounts CRUD, the one-time
// ABOUTME: legacy migration, and the restorable-account filter. Extracted from
// ABOUTME: AuthService (#4741, repository tier).

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart' show SecureKeyStorage;
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/signer_secure_store.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owns the persisted "known accounts" registry that backs the multi-account
/// welcome-screen picker: reading/writing [kKnownAccountsKey], the one-time
/// legacy migration, add/update/remove, and the restorable-account filter.
///
/// Extracted from `AuthService` (#4741, repository tier). Unlike
/// [OAuthSessionCoordinator] this collaborator is STATELESS — every method
/// reads [SharedPreferences] fresh, so there is no cached state to detach on
/// sign-out. The facade retains all session state (`_authSource`, auth-state
/// guards, restore orchestration) and calls into this registry for the pure
/// storage rules, so `multi_account` behavior is preserved exactly.
class KnownAccountsRegistry {
  KnownAccountsRegistry({
    required SecureKeyStorage keyStorage,
    required SignerSecureStore signerStore,
    required FlutterSecureStorage? flutterSecureStorage,
  }) : _keyStorage = keyStorage,
       _signerStore = signerStore,
       _flutterSecureStorage = flutterSecureStorage;

  final SecureKeyStorage _keyStorage;
  final SignerSecureStore _signerStore;
  final FlutterSecureStorage? _flutterSecureStorage;

  /// The pubkey of the account this device was most recently active as, or
  /// null when the registry has never been written.
  ///
  /// Every successful session bumps `lastUsedAt` through [upsert] — including
  /// the bunker and Amber *reconnect* paths, which is what makes this a
  /// signal that holds for every authentication source.
  ///
  /// Synchronous, and therefore deliberately not [getKnownAccounts]: that one
  /// is async because a first read runs the one-time legacy migration, and a
  /// caller that only wants to know which account was last active must not
  /// trigger a migration as a side effect. A device whose registry has never
  /// been written simply has no answer here.
  static String? mostRecentlyUsedPubkeyHex(SharedPreferences preferences) {
    final raw = preferences.getString(kKnownAccountsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      if (decoded.isEmpty) return null;
      final accounts = decoded.map(KnownAccount.fromJson).toList()
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return accounts.first.pubkeyHex;
    } on Object catch (e) {
      Log.warning(
        'mostRecentlyUsedPubkeyHex: unreadable known accounts: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      return null;
    }
  }

  /// Returns all previously used accounts, most-recently-used first.
  ///
  /// On first read (the `known_accounts` key has never been written) runs a
  /// one-time migration that checks for a legacy session and persists the
  /// result so the migration never runs again.
  Future<List<KnownAccount>> getKnownAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kKnownAccountsKey);
      Log.info(
        'getKnownAccounts: raw=${raw == null ? 'null' : '${raw.length} chars'}',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );

      // null  → key never written → run one-time migration
      // empty → key was written but all accounts removed → no migration
      if (raw == null) {
        return await _migrateLegacyAccount(prefs);
      }
      if (raw.isEmpty) return [];

      final decoded = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final accounts = decoded.map(KnownAccount.fromJson).toList()
        ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
      return accounts;
    } catch (e) {
      Log.warning(
        'Failed to load known accounts: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      return [];
    }
  }

  /// One-time migration from the old single-account auth system.
  ///
  /// Checks for a legacy session stored under the old `authentication_source`
  /// key and, if found, creates a [KnownAccount] entry for it.
  ///
  /// Additionally, always checks [SecureKeyStorage] for an automatic/anonymous
  /// identity. A user may have started with an automatic account and later
  /// switched to bunker/OAuth — the old automatic keys are still in storage
  /// even though `authentication_source` was overwritten.
  ///
  /// The result is persisted to [kKnownAccountsKey] so this migration never
  /// runs again.
  Future<List<KnownAccount>> _migrateLegacyAccount(
    SharedPreferences prefs,
  ) async {
    Log.info(
      'known_accounts key absent — running one-time legacy migration',
      name: 'KnownAccountsRegistry',
      category: LogCategory.auth,
    );

    final rawAuthSource = prefs.getString(kAuthenticationSourceKey);
    final source = AuthenticationSource.fromCode(rawAuthSource);
    Log.info(
      'Legacy migration: rawAuthSource=$rawAuthSource, '
      'resolved=${source.name}',
      name: 'KnownAccountsRegistry',
      category: LogCategory.auth,
    );

    if (source == AuthenticationSource.none) {
      // Fresh install or explicit logout — still check for automatic keys.
      Log.info(
        'Legacy migration: source=none, checking automatic keys...',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      final accounts = await _migrateAutomaticKeys([]);
      Log.info(
        'Legacy migration: source=none, automatic keys check '
        'returned ${accounts.length} account(s)',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      await _persistMigrationResult(prefs, accounts);
      return accounts;
    }

    final accounts = <KnownAccount>[];

    // 1. Recover the account matching the persisted auth source.
    String? pubkeyHex;
    try {
      switch (source) {
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
          final keyContainer = await _keyStorage.getKeyContainer();
          pubkeyHex = keyContainer?.publicKeyHex;

        case AuthenticationSource.amber:
          final amberInfo = await _signerStore.loadAmber();
          pubkeyHex = amberInfo?.pubkey;

        case AuthenticationSource.bunker:
          final bunkerInfo = await _signerStore.loadBunker();
          pubkeyHex = bunkerInfo?.userPubkey;

        case AuthenticationSource.divineOAuth:
          final session = await KeycastSession.load(_flutterSecureStorage);
          pubkeyHex = session?.userPubkey;

        case AuthenticationSource.nip07:
          // NIP-07 was introduced after the legacy migration; no archived
          // hint to recover. Leave pubkeyHex null so this path is skipped.
          break;

        case AuthenticationSource.none:
          break;
      }
    } catch (e) {
      Log.warning(
        'Legacy migration failed to read old session: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }

    if (pubkeyHex != null && pubkeyHex.length == 64) {
      final now = DateTime.now();
      accounts.add(
        KnownAccount(
          pubkeyHex: pubkeyHex,
          authSource: source,
          addedAt: now,
          lastUsedAt: now,
        ),
      );
      Log.info(
        'Legacy migration: created entry for '
        'pubkey=${pubkeyForLogs(pubkeyHex)}, source=${source.name}',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }

    // 2. Always check for automatic keys that may belong to a different
    //    identity than the current auth source (e.g. user started with an
    //    anonymous account, then later logged in via bunker/OAuth).
    if (source != AuthenticationSource.automatic &&
        source != AuthenticationSource.importedKeys) {
      await _migrateAutomaticKeys(accounts);
    }

    if (accounts.isEmpty) {
      Log.info(
        'Legacy migration: no recoverable session found',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }

    await _persistMigrationResult(prefs, accounts);
    return accounts;
  }

  /// Checks [SecureKeyStorage] for automatic/anonymous keys and adds a
  /// [KnownAccount] entry if found and not already in [accounts].
  ///
  /// Returns [accounts] for convenience (mutates in place).
  Future<List<KnownAccount>> _migrateAutomaticKeys(
    List<KnownAccount> accounts,
  ) async {
    try {
      Log.info(
        'Legacy migration: _migrateAutomaticKeys — '
        'calling _keyStorage.getKeyContainer()...',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      final keyContainer = await _keyStorage.getKeyContainer();
      final hex = keyContainer?.publicKeyHex;
      Log.info(
        'Legacy migration: _migrateAutomaticKeys — '
        'keyContainer=${keyContainer != null}, '
        'hex=${hex != null ? '${hex.length} chars' : 'null'}',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
      if (hex != null &&
          hex.length == 64 &&
          !accounts.any((a) => a.pubkeyHex == hex)) {
        final now = DateTime.now();
        accounts.add(
          KnownAccount(
            pubkeyHex: hex,
            authSource: AuthenticationSource.automatic,
            addedAt: now,
            lastUsedAt: now,
          ),
        );
        Log.info(
          'Legacy migration: recovered automatic keys — pubkey=$hex',
          name: 'KnownAccountsRegistry',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.warning(
        'Legacy migration: failed to check automatic keys: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }
    return accounts;
  }

  /// Persists the migration result to seal it permanently.
  Future<void> _persistMigrationResult(
    SharedPreferences prefs,
    List<KnownAccount> accounts,
  ) async {
    await prefs.setString(
      kKnownAccountsKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  /// Adds or updates an account in the known accounts registry.
  ///
  /// Called after successful authentication to record which pubkey was used
  /// and which [AuthenticationSource] authenticated it.
  Future<void> upsert(
    String pubkeyHex,
    AuthenticationSource source,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await getKnownAccounts();
      final now = DateTime.now();

      final index = accounts.indexWhere((a) => a.pubkeyHex == pubkeyHex);
      if (index >= 0) {
        accounts[index] = accounts[index].copyWith(
          authSource: source,
          lastUsedAt: now,
        );
      } else {
        accounts.add(
          KnownAccount(
            pubkeyHex: pubkeyHex,
            authSource: source,
            addedAt: now,
            lastUsedAt: now,
          ),
        );
      }

      final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
      await prefs.setString(kKnownAccountsKey, json);

      Log.info(
        'Updated known accounts registry '
        '(total=${accounts.length}, pubkey=${pubkeyForLogs(pubkeyHex)}, source=${source.name})',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    } catch (e) {
      Log.warning(
        'Failed to update known accounts: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }
  }

  /// Removes an account from the known accounts registry.
  Future<void> remove(String pubkeyHex) async {
    try {
      await removeStrict(pubkeyHex);
    } catch (e) {
      Log.warning(
        'Failed to remove from known accounts: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }
  }

  /// Removes an account and propagates [FormatException], [TypeError], and
  /// [StateError] when the registry cannot be decoded or persisted.
  Future<void> removeStrict(String pubkeyHex) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kKnownAccountsKey);
    final accounts = raw == null
        ? await _migrateLegacyAccount(prefs)
        : raw.isEmpty
        ? <KnownAccount>[]
        : (jsonDecode(raw) as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map(KnownAccount.fromJson)
              .toList();
    accounts.removeWhere((a) => a.pubkeyHex == pubkeyHex);

    final json = jsonEncode(accounts.map((a) => a.toJson()).toList());
    if (!await prefs.setString(kKnownAccountsKey, json)) {
      throw StateError('Could not persist known accounts');
    }

    Log.info(
      'Removed ${pubkeyForLogs(pubkeyHex)} from known accounts '
      '(remaining=${accounts.length})',
      name: 'KnownAccountsRegistry',
      category: LogCategory.auth,
    );
  }

  /// Overwrites the persisted registry with [accounts] verbatim (in the order
  /// given — callers that need MRU order sort first).
  ///
  /// Used by sign-out recovery to prune the registry to the restorable set.
  /// Throws [StateError] when the registry cannot be persisted.
  Future<void> persist(List<KnownAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      kKnownAccountsKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    )) {
      throw StateError('Could not persist known accounts');
    }
  }

  /// Resets recovery preferences and keeps restorable accounts in MRU order.
  /// Throws when secure storage or preferences cannot be read or persisted.
  Future<int> resetRecoveryPreferences({
    required String lastUsedNpubKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getKnownAccounts();
    final restorable = (await restorableAccounts(accounts))
      ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    await persist(restorable);
    if (!await prefs.setString(
      kAuthenticationSourceKey,
      AuthenticationSource.none.code,
    )) {
      throw StateError('Could not reset the authentication source');
    }
    if (prefs.containsKey(lastUsedNpubKey) &&
        !await prefs.remove(lastUsedNpubKey)) {
      throw StateError('Could not clear the last-used account');
    }
    return restorable.length;
  }

  /// Filters [accounts] to those that still have restorable local login
  /// material on this device (a local nsec, or an archived remote-signer
  /// session). Non-restorable sources ([AuthenticationSource.none]/`nip07`)
  /// are always dropped.
  Future<List<KnownAccount>> restorableAccounts(
    List<KnownAccount> accounts,
  ) async {
    final restorable = <KnownAccount>[];
    for (final account in accounts) {
      switch (account.authSource) {
        case AuthenticationSource.automatic:
        case AuthenticationSource.importedKeys:
          if (await _hasRestorableLocalKey(account)) {
            restorable.add(account);
          }
        case AuthenticationSource.amber:
        case AuthenticationSource.bunker:
        case AuthenticationSource.divineOAuth:
          if (await _hasRestorableSignerArchive(account)) {
            restorable.add(account);
          }
        case AuthenticationSource.none:
        case AuthenticationSource.nip07:
          break;
      }
    }
    return restorable;
  }

  Future<bool> _hasRestorableLocalKey(KnownAccount account) async {
    final npub = NostrKeyUtils.encodePubKey(account.pubkeyHex);
    try {
      final identityContainer = await _keyStorage.getIdentityKeyContainer(npub);
      if (identityContainer?.publicKeyHex == account.pubkeyHex) {
        return true;
      }

      if (await _keyStorage.hasKeys()) {
        final primaryContainer = await _keyStorage.getKeyContainer();
        if (primaryContainer?.publicKeyHex == account.pubkeyHex) {
          return true;
        }
      }
    } catch (e) {
      Log.warning(
        'signOut: failed to verify local nsec for ${pubkeyForLogs(account.pubkeyHex)}: $e',
        name: 'KnownAccountsRegistry',
        category: LogCategory.auth,
      );
    }
    return false;
  }

  Future<bool> _hasRestorableSignerArchive(KnownAccount account) =>
      _signerStore.hasArchive(account.pubkeyHex, account.authSource);
}
