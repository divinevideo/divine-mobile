// ABOUTME: Serializes sign-out behind a durable account activation fence.
// ABOUTME: Retires verified logout without authorizing unknown recovery records.

part of '../auth_service.dart';

extension _AccountSignOut on AuthService {
  Future<void> _signOutWithActivation({
    required bool deleteKeys,
    required bool abortOnKeyDeletionFailure,
    required bool deleteLocalUserData,
  }) async {
    final owner = currentPublicKeyHex;
    final leavingNpub = currentNpub;
    final state = _activation;
    final previous = state.ticket;
    final receipt = committedAccountActivationReceipt;
    final verifiedBunkerUrl =
        receipt?.isCurrent == true &&
            receipt?.ownerPubkey == owner &&
            _currentIdentity is BunkerNostrIdentity &&
            _currentIdentity?.pubkey == owner &&
            _authSource == AuthenticationSource.bunker
        ? _bunkerSigner?.info.toString()
        : null;
    _retireAccountActivation();
    state.metadataIsCurrent = null;
    state.identityIsCurrent = null;
    state.entryPrepared = false;
    if (owner == null) {
      await _signOutWithoutOwner(
        deleteKeys: deleteKeys,
        abortOnKeyDeletionFailure: abortOnKeyDeletionFailure,
        deleteLocalUserData: deleteLocalUserData,
      );
      return;
    }
    final generation = state.generation;
    final prefs = await SharedPreferences.getInstance();
    final coordinator = AccountActivationCoordinator.forPreferences(prefs);
    state.coordinator = coordinator;
    final ticket = await coordinator.begin(
      ownerPubkey: owner,
      previousTicket: previous,
      isCurrent: () =>
          !state.disposed &&
          state.generation == generation &&
          (state.frameIsCurrent?.call() ?? true),
    );
    state.ticket = ticket;
    try {
      await coordinator.runGuardedStorage(ticket, () async {
        void ensureCurrent() => coordinator.ensureCurrent(ticket);
        final credentials = await _verifiedSignOutCredentials(
          owner,
          ensureCurrent,
          verifiedBunkerUrl: verifiedBunkerUrl,
        );
        await _signOutNative(
          deleteKeys: deleteKeys,
          abortOnKeyDeletionFailure: abortOnKeyDeletionFailure,
          deleteLocalUserData: deleteLocalUserData,
          credentials: credentials,
          ensureCurrent: ensureCurrent,
        );
        await _verifySignOutCredentialAbsence(
          ensureCurrent,
          deletedOwner: deleteKeys ? owner : null,
        );
      });
      await coordinator.runGuardedStorage(ticket, () async {
        await prefs.reload();
        coordinator.ensureCurrent(ticket);
        if (_currentIdentity != null ||
            _currentKeyContainer != null ||
            prefs.get('current_user_pubkey_hex') != null ||
            prefs.containsKey(PendingAccountCleanup.storageKey) ||
            prefs.containsKey(TermsAcceptanceKeys.ageVerified16Plus) ||
            prefs.containsKey(TermsAcceptanceKeys.termsAcceptedAt) ||
            UserDataCleanupService.userSpecificKeys.any(prefs.containsKey) ||
            prefs.get(kSessionRecoveryAnchorKey) !=
                (!deleteKeys ? leavingNpub : null)) {
          throw const UserDataCleanupException(
            'Could not verify complete sign out',
          );
        }
      });
      await coordinator.completeSignOut(ticket);
      coordinator.ensureCurrent(ticket);
      _setAuthState(AuthState.unauthenticated);
      state.changes.add(null);
    } on Object {
      coordinator.retire(ticket);
      if (_currentIdentity == null &&
          _currentKeyContainer == null &&
          state.generation == generation) {
        _setAuthState(AuthState.unauthenticated);
      }
      rethrow;
    }
  }

  Future<void> _signOutWithoutOwner({
    required bool deleteKeys,
    required bool abortOnKeyDeletionFailure,
    required bool deleteLocalUserData,
  }) async {
    final state = _activation;
    final generation = state.generation;
    final prefs = await SharedPreferences.getInstance();
    final coordinator = AccountActivationCoordinator.forPreferences(prefs);
    final reservation = await coordinator.reserveOwnerlessSignOut(
      isCurrent: () =>
          !state.disposed &&
          state.generation == generation &&
          currentPublicKeyHex == null &&
          (state.frameIsCurrent?.call() ?? true),
    );
    // A PRIMARY key without an authenticated owner is retained evidence, not
    // permission for an ownerless actor to remove someone else's login.
    final hasStoredKeys = await coordinator.runOwnerlessSignOutStorage(
      reservation,
      () async {
        if (prefs.containsKey(PendingAccountCleanup.storageKey)) {
          throw const UserDataCleanupException(
            'Ownerless sign out cannot retire unidentified cleanup evidence',
          );
        }
        return _keyStorage.hasKeysStrict();
      },
    );
    if (hasStoredKeys) {
      throw const UserDataCleanupException(
        'Ownerless sign out cannot remove unidentified login material',
      );
    }
    final credentials = await coordinator.runOwnerlessSignOutStorage(
      reservation,
      () => _verifiedSignOutCredentials(
        null,
        () => coordinator.ensureOwnerlessSignOutCurrent(reservation),
      ),
    );
    // Do not hold the storage queue across arbitrary outgoing callbacks. A
    // replacement account can commit; the reservation then denies this actor.
    await _runBeforeSessionTeardownCallbacks();
    await coordinator.runOwnerlessSignOutStorage(
      reservation,
      () => _signOutNative(
        deleteKeys: deleteKeys,
        abortOnKeyDeletionFailure: abortOnKeyDeletionFailure,
        deleteLocalUserData: deleteLocalUserData,
        runTeardownCallbacks: false,
        credentials: credentials,
        ensureCurrent: () =>
            coordinator.ensureOwnerlessSignOutCurrent(reservation),
      ),
    );
    await coordinator.runOwnerlessSignOutStorage(reservation, () async {
      await prefs.reload();
      coordinator.ensureOwnerlessSignOutCurrent(reservation);
      await _verifySignOutCredentialAbsence(
        () => coordinator.ensureOwnerlessSignOutCurrent(reservation),
      );
      if (await _keyStorage.hasKeysStrict()) {
        throw const UserDataCleanupException(
          'Ownerless sign out retained unidentified login material',
        );
      }
      coordinator.ensureOwnerlessSignOutCurrent(reservation);
      if (_currentIdentity != null ||
          _currentKeyContainer != null ||
          prefs.containsKey(PendingAccountCleanup.storageKey) ||
          prefs.containsKey(TermsAcceptanceKeys.ageVerified16Plus) ||
          prefs.containsKey(TermsAcceptanceKeys.termsAcceptedAt) ||
          UserDataCleanupService.userSpecificKeys.any(prefs.containsKey) ||
          prefs.containsKey(kSessionRecoveryAnchorKey)) {
        throw const UserDataCleanupException(
          'Could not verify complete ownerless sign out',
        );
      }
    });
    coordinator.completeOwnerlessSignOut(reservation);
    _setAuthState(AuthState.unauthenticated);
    state.changes.add(null);
  }

  Future<void> _deleteSignOutLogin(
    String? owner,
    void Function() ensureCurrent,
  ) async {
    ensureCurrent();
    if (owner != null) {
      await _keyStorage.deleteOwnedLoginStrict(
        owner,
        ensureCurrent: ensureCurrent,
      );
      ensureCurrent();
      return;
    }
    // An ownerless actor has no account-local archive it can attribute.
    if (await _keyStorage.hasKeysStrict()) {
      throw const UserDataCleanupException(
        'Ownerless sign out cannot remove unidentified login material',
      );
    }
    ensureCurrent();
  }

  static const _signOutCredentialKeys = [
    'keycast_session',
    'keycast_refresh_token',
    'keycast_auth_handle',
    'bunker_info',
    'amber_pubkey',
    'amber_package',
  ];

  List<String> _signOutArchiveKeys(String owner) => [
    'keycast_session_$owner',
    'bunker_info_$owner',
    'amber_pubkey_$owner',
    'amber_package_$owner',
  ];

  Future<Map<String, String?>> _readSignOutCredentials(
    void Function() ensureCurrent, {
    Iterable<String>? keys,
  }) async {
    final storage = _flutterSecureStorage ?? const FlutterSecureStorage();
    final values = <String, String?>{};
    for (final key in keys ?? _signOutCredentialKeys) {
      ensureCurrent();
      values[key] = await storage.read(key: key);
      ensureCurrent();
    }
    return values;
  }

  bool _oauthCredentialsBelongTo(String raw, String owner) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        return false;
      }
      return KeycastSession.fromJson(json).userPubkey == owner;
    } on Object {
      return false;
    }
  }

  bool _bunkerCredentialsBelongTo(String raw, String owner) {
    try {
      if (!NostrRemoteSignerInfo.isBunkerUrl(raw)) {
        return false;
      }
      final info = NostrRemoteSignerInfo.parseBunkerUrl(raw);
      return RegExp(r'^[0-9a-f]{64}$').hasMatch(info.remoteSignerPubkey) &&
          info.userPubkey == owner;
    } on Object {
      return false;
    }
  }

  void _verifyAmberCredentials(
    String? pubkey,
    String? package,
    String owner,
  ) {
    if ((pubkey != null && pubkey != owner) ||
        (package != null && (pubkey != owner || package.isEmpty))) {
      throw const UserDataCleanupException(
        'Sign out cannot attribute retained Amber credentials',
      );
    }
  }

  Future<Map<String, String?>> _verifiedSignOutCredentials(
    String? owner,
    void Function() ensureCurrent, {
    String? verifiedBunkerUrl,
  }) async {
    final values = await _readSignOutCredentials(
      ensureCurrent,
      keys: [
        ..._signOutCredentialKeys,
        if (owner != null) ..._signOutArchiveKeys(owner),
      ],
    );
    if (values.values.every((value) => value == null)) {
      return values;
    }
    if (owner == null) {
      throw const UserDataCleanupException(
        'Ownerless sign out cannot attribute retained signer credentials',
      );
    }
    final storage = _flutterSecureStorage ?? const FlutterSecureStorage();
    final oauthKeys = _signOutCredentialKeys.take(3);
    if (oauthKeys.any((key) => values[key] != null)) {
      // Null parsing is unreadable evidence; only captured raw null is absence.
      final session = await KeycastSession.load(storage);
      ensureCurrent();
      if (session?.userPubkey != owner ||
          (values['keycast_refresh_token'] != null &&
              values['keycast_refresh_token'] != session?.refreshToken) ||
          (values['keycast_auth_handle'] != null &&
              values['keycast_auth_handle'] != session?.authorizationHandle)) {
        throw const UserDataCleanupException(
          'Sign out cannot attribute retained OAuth credentials',
        );
      }
    }
    final archivedOAuth = values['keycast_session_$owner'];
    if (archivedOAuth != null &&
        !_oauthCredentialsBelongTo(archivedOAuth, owner)) {
      throw const UserDataCleanupException(
        'Sign out cannot attribute retained OAuth archive',
      );
    }
    final archivedBunker = values['bunker_info_$owner'];
    if (archivedBunker != null &&
        !_bunkerCredentialsBelongTo(archivedBunker, owner) &&
        archivedBunker != verifiedBunkerUrl) {
      throw const UserDataCleanupException(
        'Sign out cannot attribute retained bunker archive',
      );
    }
    final bunker = values['bunker_info'];
    if (bunker != null &&
        bunker != verifiedBunkerUrl &&
        (bunker != archivedBunker ||
            !_bunkerCredentialsBelongTo(bunker, owner))) {
      throw const UserDataCleanupException(
        'Sign out cannot attribute retained bunker credentials',
      );
    }
    _verifyAmberCredentials(
      values['amber_pubkey'],
      values['amber_package'],
      owner,
    );
    _verifyAmberCredentials(
      values['amber_pubkey_$owner'],
      values['amber_package_$owner'],
      owner,
    );
    await _ensureSignOutCredentialsUnchanged(
      values,
      ensureCurrent,
      keys: values.keys,
    );
    return values;
  }

  Future<void> _ensureSignOutCredentialsUnchanged(
    Map<String, String?> expected,
    void Function() ensureCurrent, {
    Iterable<String>? keys,
  }) async {
    final selected = keys ?? _signOutCredentialKeys;
    final actual = await _readSignOutCredentials(ensureCurrent, keys: selected);
    if (selected.any((key) => actual[key] != expected[key])) {
      throw const UserDataCleanupException(
        'Sign out credentials changed before cleanup',
      );
    }
  }

  Future<void> _verifySignOutCredentialAbsence(
    void Function() ensureCurrent, {
    String? deletedOwner,
  }) async {
    final values = await _readSignOutCredentials(
      ensureCurrent,
      keys: [
        ..._signOutCredentialKeys,
        if (deletedOwner != null) ..._signOutArchiveKeys(deletedOwner),
      ],
    );
    if (values.values.any((value) => value != null)) {
      throw const UserDataCleanupException(
        'Sign out native credential cleanup could not be verified',
      );
    }
  }

  Future<void> _archiveAttributedSignerCredentials(
    String owner,
    Map<String, String?> credentials,
    void Function() ensureCurrent,
  ) async {
    final storage = _flutterSecureStorage ?? const FlutterSecureStorage();
    for (final key in const [
      'keycast_session',
      'bunker_info',
      'amber_pubkey',
      'amber_package',
    ]) {
      final raw = credentials[key];
      if (raw == null) {
        continue;
      }
      await _ensureSignOutCredentialsUnchanged(credentials, ensureCurrent);
      final archive = '${key}_$owner';
      final before = await storage.read(key: archive);
      ensureCurrent();
      if (before != credentials[archive]) {
        throw const UserDataCleanupException(
          'Sign out signer archive changed before preservation',
        );
      }
      await storage.write(key: archive, value: raw);
      ensureCurrent();
      final stored = await storage.read(key: archive);
      ensureCurrent();
      if (stored != raw) {
        throw const UserDataCleanupException(
          'Sign out signer archive could not be verified',
        );
      }
    }
  }

  Future<void> _verifySignOutArchivePreservation(
    String owner,
    Map<String, String?> credentials,
    void Function() ensureCurrent,
  ) async {
    final archives = await _readSignOutCredentials(
      ensureCurrent,
      keys: _signOutArchiveKeys(owner),
    );
    for (final key in const [
      'keycast_session',
      'bunker_info',
      'amber_pubkey',
      'amber_package',
    ]) {
      final current = credentials[key];
      if (current != null && archives['${key}_$owner'] != current) {
        throw const UserDataCleanupException(
          'Sign out signer archive could not be verified',
        );
      }
    }
  }

  Future<void> _clearAttributedSignerArchive(
    String owner,
    Map<String, String?> credentials,
    void Function() ensureCurrent,
  ) async {
    final storage = _flutterSecureStorage ?? const FlutterSecureStorage();
    for (final key in _signOutArchiveKeys(owner)) {
      ensureCurrent();
      final current = await storage.read(key: key);
      ensureCurrent();
      if (current != credentials[key]) {
        throw const UserDataCleanupException(
          'Sign out signer archive changed before cleanup',
        );
      }
      if (current != null) {
        await storage.delete(key: key);
        ensureCurrent();
      }
    }
  }

  Future<void> _clearAttributedSignerGlobals(
    Map<String, String?> credentials,
    void Function() ensureCurrent,
  ) async {
    await _ensureSignOutCredentialsUnchanged(credentials, ensureCurrent);
    await _clearOAuthSessionForSignOut();
    ensureCurrent();
    final storage = _flutterSecureStorage ?? const FlutterSecureStorage();
    // The facade's optional injected storage must not make standalone token
    // deletion a no-op. Only a retained exact attributed value is removable;
    // unknown or replaced values remain untouched and keep logout incomplete.
    for (final key in _signOutCredentialKeys) {
      ensureCurrent();
      final current = await storage.read(key: key);
      ensureCurrent();
      if (current == null) {
        continue;
      }
      if (current != credentials[key]) {
        throw const UserDataCleanupException(
          'Sign out credentials changed during cleanup',
        );
      }
      await storage.delete(key: key);
      ensureCurrent();
    }
  }

  Future<void> _signOutNative({
    required Map<String, String?> credentials,
    required void Function() ensureCurrent,
    bool deleteKeys = false,
    bool abortOnKeyDeletionFailure = false,
    bool deleteLocalUserData = false,
    bool runTeardownCallbacks = true,
  }) async {
    final pubkeyAtSignOutStart = _currentKeyContainer?.publicKeyHex;
    Log.info(
      'signOut: starting — '
      'authSource=${_authSource.name}, '
      'deleteKeys=$deleteKeys, '
      'abortOnKeyDeletionFailure=$abortOnKeyDeletionFailure, '
      'deleteLocalUserData=$deleteLocalUserData, '
      'currentPubkey=${_currentKeyContainer?.publicKeyHex ?? "null"}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    if (deleteKeys && abortOnKeyDeletionFailure) {
      await _deleteSignOutLogin(pubkeyAtSignOutStart, ensureCurrent);
    }

    Object? keyDeletionError;
    Object? userDataCleanupError;

    if (runTeardownCallbacks) {
      await _runBeforeSessionTeardownCallbacks();
    }
    ensureCurrent();

    try {
      // Clear TOS acceptance on any logout - user must re-accept when logging
      // back in
      final prefs = await SharedPreferences.getInstance();
      final currentPubkey = _currentKeyContainer?.publicKeyHex;

      final leavingNpub = _currentKeyContainer?.npub;
      if (!deleteKeys && leavingNpub != null) {
        await prefs.setString(
          kSessionRecoveryAnchorKey,
          leavingNpub,
        );
        Log.debug(
          'signOut: recorded session recovery anchor=${pubkeyForLogs(leavingNpub)}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } else {
        // Destructive sign-out: clear any stale anchor so the remaining
        // account's automatic restore is not blocked by the guard in
        // _restoreDivineRpcOrFallbackUnauthenticated.
        await prefs.remove(kSessionRecoveryAnchorKey);
        Log.debug(
          'signOut: cleared session recovery anchor '
          '(deleteKeys=$deleteKeys)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      await prefs.remove(TermsAcceptanceKeys.ageVerified16Plus);
      await prefs.remove(TermsAcceptanceKeys.termsAcceptedAt);

      if (deleteKeys && !deleteLocalUserData && currentPubkey != null) {
        await _userDataCleanupService.markOwnerScopedLegacyDataForUser(
          currentPubkey,
        );
      }
      try {
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: currentPubkey,
          deleteUserData: deleteLocalUserData,
        );
      } catch (e) {
        userDataCleanupError = e;
        Log.error(
          'User data cleanup failed during signOut: $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      await prefs.remove(SharedPreferencesRelayStorage.defaultKey);
      await prefs.remove(SharedPreferencesRelayStorage.defaultRemovedRelaysKey);

      await _relayDiscoveryService.clearCache(_currentKeyContainer?.npub ?? '');

      await prefs.remove('current_user_pubkey_hex');

      if (currentPubkey != null) {
        try {
          await CacheSync.invalidatePrefix(currentPubkey);
        } catch (e, stack) {
          if (deleteLocalUserData) userDataCleanupError ??= e;
          Log.error(
            'CacheSync.invalidatePrefix failed during signOut: $e',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          _reportStorageError(e, stack, 'signOut cache invalidation');
        }
      }

      if (deleteKeys) {
        if (currentPubkey != null) {
          if (deleteLocalUserData) {
            try {
              await _knownAccounts.removeStrict(currentPubkey);
            } catch (e) {
              userDataCleanupError ??= e;
            }
          } else {
            await _knownAccounts.remove(currentPubkey);
          }
          try {
            await _clearAttributedSignerArchive(
              currentPubkey,
              credentials,
              ensureCurrent,
            );
          } catch (e) {
            keyDeletionError ??= e;
          }
        }

        Log.debug(
          '📱️ Deleting local login material',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Isolate key deletion so that a failure does not short-circuit
        // the remaining cleanup (session, signers, auth state). The error
        // is rethrown after cleanup completes so callers can warn the user.
        // Skip if already handled by the pre-flight check above.
        if (!abortOnKeyDeletionFailure) {
          try {
            await _deleteSignOutLogin(currentPubkey, ensureCurrent);
          } catch (e) {
            keyDeletionError = e;
            Log.error(
              'Local login deletion failed during signOut: $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
        }
      } else {
        if (currentPubkey != null) {
          await _archiveAttributedSignerCredentials(
            currentPubkey,
            credentials,
            ensureCurrent,
          );
          await _verifySignOutArchivePreservation(
            currentPubkey,
            credentials,
            ensureCurrent,
          );
        }
        // Logout owns the outgoing session, not another account's PRIMARY
        // or legacy key. The recovery anchor prevents implicit cross-account
        // restoration; retiring this cache never deletes foreign login data.
        _keyStorage.clearCache();
      }

      _currentIdentity = null;
      _currentKeyContainer?.dispose();
      _currentKeyContainer = null;
      _currentProfile = null;
      clearError();

      _onUserRelaysDiscovered = null;
      _onBootstrapRelayListRequested = null;
      _userRelays = [];

      if (_bunkerSigner != null) {
        _bunkerSigner!.close();
        _bunkerSigner = null;
        // Native globals are retired only by the attributed scope below.
      }

      if (_amberSigner != null) {
        _amberSigner!.close();
        _amberSigner = null;
        // Native globals are retired only by the attributed scope below.
      }

      _setKeycastSigner(null);
      _setRpcCapability(AuthRpcCapability.unavailable);

      // Detach any in-flight token refresh so post-signout logins start a
      // fresh attempt instead of joining one issued for the outgoing session.
      // Deliberately leaves _hasExpiredOAuthSession untouched.
      _oauthCoordinator.detach();

      // Neither a callback nor an unbound late native write may redirect this
      // cleanup to foreign or unreadable credentials.
      await _clearAttributedSignerGlobals(credentials, ensureCurrent);

      // Reset recovery prefs AFTER all signer cleanup so removed accounts
      // cannot silently recover. Any remaining restorable accounts stay in the
      // known-account picker instead of being auto-restored.
      if (deleteKeys &&
          (!deleteLocalUserData || userDataCleanupError == null)) {
        try {
          await _resetRecoveryAfterLocalAccountRemoval(
            prefs,
            strict: deleteLocalUserData,
          );
        } catch (e) {
          userDataCleanupError ??= e;
        }
      }

      try {
        final postSignOutHasKeys = await _keyStorage.hasKeys();
        Log.info(
          'signOut complete — '
          'keyStorageHasKeys=$postSignOutHasKeys, '
          'authSource=${_authSource.name}',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (_) {
        Log.info(
          'signOut complete',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error during sign out: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _lastError = 'Sign out failed: $e';

      // In the Remove Keys flow, key deletion has already succeeded before
      // cleanup starts. Do not leave the app in an authenticated in-memory
      // state with no keys on disk if a secondary cleanup step fails.
      if (deleteKeys && abortOnKeyDeletionFailure) {
        await _completeDestructiveSignOutAfterDeletedKeys(
          removedPubkey: pubkeyAtSignOutStart,
          failure: e,
          ensureCurrent: ensureCurrent,
        );
        Error.throwWithStackTrace(e, stackTrace);
      }
      // A remote teardown failure may remain advisory only after the actual
      // in-memory/native cleanup is proved. Local incomplete cleanup is never
      // turned into a successful terminal activation.
      if (_currentIdentity != null || _currentKeyContainer != null) {
        Error.throwWithStackTrace(e, stackTrace);
      }
      try {
        await _verifySignOutCredentialAbsence(
          ensureCurrent,
          deletedOwner: deleteKeys ? pubkeyAtSignOutStart : null,
        );
      } on Object {
        Error.throwWithStackTrace(e, stackTrace);
      }
    }

    // After all cleanup, propagate key deletion failure so callers can
    // warn the user that keys may still be on the device.
    if (keyDeletionError != null) {
      throw SecureKeyStorageException(
        'Signed out but key deletion failed: $keyDeletionError',
      );
    }
    if (userDataCleanupError != null) {
      throw UserDataCleanupException(
        'Signed out but local user data cleanup failed',
        userDataCleanupError,
      );
    }
  }
}
