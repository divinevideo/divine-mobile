// ABOUTME: Establishes an authenticated session behind its account cleanup gate.
// ABOUTME: Preserves entry eligibility and identity references through async setup.

part of '../auth_service.dart';

/// Captures eligibility at an entry boundary, including an explicitly cold
/// entry. Internal continuations must never recapture a newer live identity.
class _ContinuingAccountSession {
  const _ContinuingAccountSession(this.identity);

  final NostrIdentity? identity;
}

extension _AccountSessionSetup on AuthService {
  _ContinuingAccountSession _captureContinuingAccountSession() =>
      _ContinuingAccountSession(isAuthenticated ? _currentIdentity : null);

  /// An interrupted non-destructive identity sweep stays an entry gate, but
  /// must not tear down the same established live account during refresh.
  bool _canDeferPendingCleanupForLiveSession(
    SharedPreferences prefs, {
    required String incomingPubkey,
    required NostrIdentity? establishedSession,
    required NostrIdentity? tentativeIdentity,
    required SecureKeyContainer expectedKeyContainer,
  }) {
    if (tentativeIdentity == null ||
        !identical(_currentIdentity, tentativeIdentity) ||
        !identical(_currentKeyContainer, expectedKeyContainer) ||
        establishedSession?.pubkey != incomingPubkey ||
        currentPublicKeyHex != incomingPubkey ||
        (_authState != AuthState.authenticated &&
            _authState != AuthState.authenticating) ||
        prefs.getString('current_user_pubkey_hex') != incomingPubkey) {
      return false;
    }
    // getString casts its cached value. A non-string marker must take the
    // existing fail-closed path without catching unrelated TypeErrors here.
    if (prefs.get(PendingAccountCleanup.storageKey) is! String) return false;
    try {
      final pending = PendingAccountCleanup.read(prefs);
      return pending != null &&
          pending.userPubkey == incomingPubkey &&
          pending.isIdentityChange &&
          !pending.deleteUserData;
    } on FormatException {
      // Malformed JSON enters the existing typed cleanup-failure path.
      return false;
      // PendingAccountCleanup.read deliberately rejects persisted invalid
      // intent shapes with StateError; only that parser contract is handled.
      // ignore: avoid_catching_errors
    } on StateError {
      // read() rejects null/invalid intent shape with StateError.
      return false;
    }
  }

  /// Set up user session after successful authentication.
  ///
  /// Throws [UserDataCleanupException] if the outgoing account's data cannot
  /// be cleared. The incoming account must not be activated in that case.
  Future<void> _setupUserSession(
    SecureKeyContainer keyContainer,
    AuthenticationSource source, {
    required _ContinuingAccountSession? continuingSession,
    bool allowPubkeyOnlyIdentity = false,
    bool claimLegacyRows = true,
    bool followingKnownEmpty = false,
  }) async {
    // Only an explicitly captured entry context permits live deferral.
    // Cold initialization, import and creation callers have no such context;
    // a concurrent operation authenticating during their awaits cannot grant it.
    final establishedSession =
        identical(_currentIdentity, continuingSession?.identity)
        ? continuingSession?.identity
        : null;
    Log.info(
      '_setupUserSession: starting — '
      'pubkey=${keyContainer.publicKeyHex}, source=${source.name}',
      name: 'AuthService',
      category: LogCategory.auth,
    );

    _currentKeyContainer = keyContainer;
    _authSource = source;

    // Clear any stale remote signers that don't match the new auth source.
    // This prevents a Keycast RPC signer from a previous Divine OAuth session
    // from being used when signing events for an anonymous/imported-key account.
    if (source != AuthenticationSource.divineOAuth) {
      _hasExpiredOAuthSession = false;
      _setRpcCapability(AuthRpcCapability.unavailable);
      if (_keycastSigner != null) {
        Log.info(
          '_setupUserSession: clearing stale Keycast signer '
          '(new source=${source.name})',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Never close: same-pubkey swaps (importing your own nsec) keep the live client's RPC open (#5909).
        _setKeycastSigner(null, closePrevious: false);
      }
    }
    if (source != AuthenticationSource.bunker && _bunkerSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale bunker signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _bunkerSigner!.close();
      _bunkerSigner = null;
    }
    if (source != AuthenticationSource.amber && _amberSigner != null) {
      Log.info(
        '_setupUserSession: clearing stale amber signer '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _amberSigner!.close();
      _amberSigner = null;
    }
    if (source != AuthenticationSource.nip07 && _nip07Service != null) {
      Log.info(
        '_setupUserSession: clearing stale NIP-07 service '
        '(new source=${source.name})',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _nip07Service = null;
    }

    // Build atomic identity AFTER stale signers are cleared.
    _currentIdentity = _buildIdentity(
      allowPubkeyOnlyIdentity: allowPubkeyOnlyIdentity,
    );
    // References prove this setup remains current after the preferences await,
    // even when another setup installs the same complete pubkey.
    final tentativeIdentity = _currentIdentity;

    // Create user profile
    _currentProfile = UserProfile(
      npub: keyContainer.npub,
      publicKeyHex: keyContainer.publicKeyHex,
      displayName: keyContainer.npub,
    );

    // Store current user pubkey in SharedPreferences for router redirect checks
    // This allows the router to know which user's following list to check
    try {
      final prefs = await SharedPreferences.getInstance();
      final pubkeyHex = keyContainer.publicKeyHex;

      // Check if we need to clear user-specific data due to identity change
      if (_userDataCleanupService.shouldClearDataForUser(pubkeyHex) &&
          !_canDeferPendingCleanupForLiveSession(
            prefs,
            incomingPubkey: pubkeyHex,
            establishedSession: establishedSession,
            tentativeIdentity: tentativeIdentity,
            expectedKeyContainer: keyContainer,
          )) {
        final oldPubkey = prefs.getString('current_user_pubkey_hex');
        Log.info(
          '_setupUserSession: identity change detected — '
          'clearing shared caches for old pubkey '
          '${pubkeyForLogs(oldPubkey, whenNull: "unknown")} '
          '(owner-scoped drafts/clips/uploads preserved)',
          name: 'AuthService',
          category: LogCategory.auth,
        );
        // Do NOT pass deleteUserData: true here. Owner-scoped rows (drafts,
        // clips, pending uploads) are already invisible to the incoming account
        // because every query filters by ownerPubkey. Deleting them here would
        // cause permanent data loss on account switch and mismatched re-login.
        // Destructive per-user DAO deletion is reserved for account deletion
        // (signOut(deleteKeys: true, deleteLocalUserData: true)).
        await _userDataCleanupService.clearUserSpecificData(
          reason: 'identity_change',
          isIdentityChange: true,
          userPubkey: oldPubkey,
          // deleteUserData omitted — defaults to false. Owner-scoped rows
          // (drafts, clips, uploads) are already invisible to the incoming
          // account via ownerPubkey filtering; no deletion is needed here.
        );
        // restore the TOS acceptance since we wouldn't be here otherwise
        await acceptTerms();
      } else {
        Log.debug(
          '_setupUserSession: same identity — no data cleanup needed',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }
      await prefs.setString('current_user_pubkey_hex', pubkeyHex);

      if (claimLegacyRows) {
        await claimLegacyRowsForCurrentUser();
      }

      await AccountSessionStore(prefs).recordAuthentication(
        source: source,
        npub: keyContainer.npub,
      );

      final hasFollowingCache = await prepareFollowingAuthRedirect(
        prefs,
        pubkeyHex,
        followingKnownEmpty,
      );

      Log.info(
        '_setupUserSession: setting auth state to authenticated',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      _setAuthState(AuthState.authenticated);

      if (_preFetchFollowing != null && !hasFollowingCache) {
        unawaited(() async {
          Log.debug(
            '_setupUserSession: pre-fetching following list...',
            name: 'AuthService',
            category: LogCategory.auth,
          );
          try {
            await _preFetchFollowing(pubkeyHex);
            Log.debug(
              '_setupUserSession: following list pre-fetched',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          } catch (e) {
            Log.warning(
              'Pre-fetch following list failed (will rely on '
              'FollowRepository): $e',
              name: 'AuthService',
              category: LogCategory.auth,
            );
          }
        }());
      }

      // Register this account in the known accounts list
      await _knownAccounts.upsert(pubkeyHex, source);

      // Store identity keys for multi-account switching
      try {
        await _keyStorage.storeIdentityKeyContainer(
          keyContainer.npub,
          keyContainer,
        );
        Log.debug(
          '_setupUserSession: identity keys stored for multi-account',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      } catch (e) {
        // Best-effort — external signers may not have local keys to store
        Log.debug(
          '_setupUserSession: could not store identity keys '
          '(expected for external signers): $e',
          name: 'AuthService',
          category: LogCategory.auth,
        );
      }

      // Run discovery in background - it's not needed for the home feed to start
      // loading. Discovery results (relay list, blossom servers) are only used
      // when editing profile or publishing content.
      unawaited(_performDiscovery());
    } on UserDataCleanupException {
      _resetTentativeSessionAfterCleanupFailure();
      rethrow;
    } catch (e) {
      Log.warning(
        'error in _setupUserSession: $e',
        name: 'AuthService',
        category: LogCategory.auth,
      );
      // Default to awaiting TOS if we can't check
      _setAuthState(AuthState.awaitingTosAcceptance);
    }

    _profileController.add(_currentProfile);

    Log.info(
      'Secure user session established',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.verbose(
      'Profile: ${_currentProfile!.displayName}',
      name: 'AuthService',
      category: LogCategory.auth,
    );
    Log.debug(
      '📱 Security: Hardware-backed storage active',
      name: 'AuthService',
      category: LogCategory.auth,
    );
  }
}
