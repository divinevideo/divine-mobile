// ABOUTME: Removes only verified inactive-owner login and private data copies.
// ABOUTME: Preserves another account's live authority and uncertain evidence.

part of '../auth_service.dart';

extension _AccountLocalRemoval on AuthService {
  Future<void> _deleteInactiveLocalAccount(String pubkeyHex) async {
    final npub = NostrKeyUtils.encodePubKey(pubkeyHex);
    final state = _activation;
    final generation = state.generation;
    final identity = _currentIdentity;
    final keys = _currentKeyContainer;
    final liveOwner = currentPublicKeyHex;
    final receipt = committedAccountActivationReceipt;
    bool isCurrent() =>
        !state.disposed &&
        state.generation == generation &&
        state.frameIsCurrent?.call() != false &&
        identical(identity, _currentIdentity) &&
        identical(keys, _currentKeyContainer) &&
        currentPublicKeyHex == liveOwner &&
        (liveOwner == null ||
            (isAuthenticated &&
                receipt?.ownerPubkey == liveOwner &&
                receipt?.isCurrent == true));
    if (!isCurrent()) {
      throw const AccountActivationRetiredException();
    }
    final prefs = await SharedPreferences.getInstance();
    if (!isCurrent()) {
      throw const AccountActivationRetiredException();
    }
    final coordinator = AccountActivationCoordinator.forPreferences(prefs);
    await coordinator.runAccountCleanupStorage<void>(
      removedOwnerPubkey: pubkeyHex,
      isCurrent: isCurrent,
      operation: (lease) async {
        final ensureCurrent = lease.ensureCurrent;
        await prefs.reload();
        ensureCurrent();
        final storedOwner = prefs.get('current_user_pubkey_hex');
        if (storedOwner != liveOwner &&
            !(liveOwner == null && storedOwner == pubkeyHex)) {
          throw const UserDataCleanupException(
            'Could not verify the active account during local removal',
          );
        }
        Object? cleanupError;
        Object? loginError;
        // Verified private copies are still removed even if another damaged
        // record prevents proving complete deletion. The retained evidence and
        // failure remain available for a later repair; Bob stays authenticated.
        try {
          await _userDataCleanupService.deleteAccountData(
            pubkeyHex,
            userNpub: npub,
            preserveActiveSession: liveOwner != null,
          );
        } on Object catch (error) {
          ensureCurrent();
          cleanupError = error;
        }
        ensureCurrent();
        try {
          await CacheSync.invalidatePrefix(pubkeyHex);
        } on Object catch (error, stackTrace) {
          ensureCurrent();
          cleanupError ??= error;
          _reportStorageError(
            error,
            stackTrace,
            'deleteLocalAccount invalidation',
          );
        }
        ensureCurrent();
        try {
          await _signerStore.clearAccount(
            pubkeyHex,
            ensureCurrent: ensureCurrent,
          );
        } on Object catch (error) {
          ensureCurrent();
          loginError = error;
        }
        ensureCurrent();
        try {
          await _deleteStoredLoginForAccount(
            pubkeyHex,
            ensureCurrent: ensureCurrent,
          );
        } on Object catch (error) {
          ensureCurrent();
          loginError ??= error;
        }
        ensureCurrent();
        // Retain the account entry until native proof is complete: removing it
        // sooner can conceal damaged credentials from the recovery flow.
        if (loginError != null) {
          throw const SecureKeyStorageException(
            'Local account deletion incomplete',
          );
        }
        if (cleanupError != null) {
          throw UserDataCleanupException(
            'Local account data cleanup failed',
            cleanupError,
          );
        }
        try {
          await prefs.reload();
          ensureCurrent();
          // Unknown registry rows keep removal incomplete before its retained
          // device activation evidence can be retired.
          _readKnownAccountRemovalRows(prefs.get(kKnownAccountsKey));
          if (liveOwner == null) {
            await lease.verifyRetiredOwnerRemoval();
            ensureCurrent();
            await _clearInactiveRecoveryReferences(prefs, npub, ensureCurrent);
            ensureCurrent();
            await lease.completeRetiredOwnerRemoval();
            ensureCurrent();
          }
          await _removeVerifiedKnownAccount(prefs, pubkeyHex, ensureCurrent);
        } on AccountActivationRetiredException {
          rethrow;
        } on Object catch (error) {
          throw UserDataCleanupException(
            'Local account recovery cleanup failed',
            error,
          );
        }
      },
    );
  }

  Future<void> _clearInactiveRecoveryReferences(
    SharedPreferences prefs,
    String npub,
    void Function() ensureCurrent,
  ) async {
    ensureCurrent();
    final wasLastUsed = prefs.get(kLastUsedNpubKey) == npub;
    for (final key in [kSessionRecoveryAnchorKey, kLastUsedNpubKey]) {
      if (prefs.get(key) != npub) continue;
      if (!await prefs.remove(key)) {
        ensureCurrent();
        throw StateError('Could not remove the retired account reference');
      }
      ensureCurrent();
      await prefs.reload();
      ensureCurrent();
      if (prefs.get(key) != null) {
        throw StateError('Retired account reference removal did not persist');
      }
    }
    if (wasLastUsed) {
      if (!await prefs.setString(
        kAuthenticationSourceKey,
        AuthenticationSource.none.code,
      )) {
        ensureCurrent();
        throw StateError('Could not reset the retired authentication source');
      }
      ensureCurrent();
      await prefs.reload();
      ensureCurrent();
      if (prefs.get(kAuthenticationSourceKey) !=
          AuthenticationSource.none.code) {
        throw StateError(
          'Retired authentication source readback did not match',
        );
      }
    }
  }

  Future<void> _removeVerifiedKnownAccount(
    SharedPreferences prefs,
    String pubkeyHex,
    void Function() ensureCurrent,
  ) async {
    ensureCurrent();
    final raw = prefs.get(kKnownAccountsKey);
    if (raw == null) return;
    final accounts = _readKnownAccountRemovalRows(raw);
    final filtered = accounts.where(
      (account) => account['pubkeyHex'] != pubkeyHex,
    );
    if (filtered.length == accounts.length) return;
    await prefs.reload();
    ensureCurrent();
    if (prefs.get(kKnownAccountsKey) != raw) {
      throw StateError('The account registry changed during removal');
    }
    final encoded = jsonEncode(filtered.toList());
    if (!await prefs.setString(kKnownAccountsKey, encoded)) {
      throw StateError('Could not persist account removal');
    }
    ensureCurrent();
    await prefs.reload();
    ensureCurrent();
    if (prefs.get(kKnownAccountsKey) != encoded) {
      throw StateError('Account removal readback did not match');
    }
  }

  List<Map<String, dynamic>> _readKnownAccountRemovalRows(Object? raw) {
    if (raw == null) return [];
    if (raw is! String) throw StateError('The account registry is unreadable');
    final decoded = raw.isEmpty ? <dynamic>[] : jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      throw StateError('The account registry is unreadable');
    }
    return decoded.map((value) {
      if (value is! Map<String, dynamic>) {
        throw StateError('The account registry is unreadable');
      }
      final account = KnownAccount.fromJson(value);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(account.pubkeyHex)) {
        throw StateError('The account registry owner is unreadable');
      }
      // Preserve every field of another owner's entry instead of rewriting it
      // through a model serializer while removing the target entry.
      return value;
    }).toList();
  }
}
