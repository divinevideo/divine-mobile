// ABOUTME: Binds activation receipts and creation permission to real auth state.
// ABOUTME: Keeps delayed or retired account setup from granting list authority.

part of '../auth_service.dart';

final _activationStates = Expando<_AccountActivationState>();

class _AccountActivationState {
  int generation = 0;
  bool disposed = false;
  bool awaitsHost = false;
  bool entryPrepared = false;
  bool Function()? frameIsCurrent;
  bool Function()? hostIsCurrent;
  bool Function()? metadataIsCurrent;
  bool Function()? identityIsCurrent;
  void Function()? nostrConnectAttempt;
  final changes = StreamController<AccountActivationReceipt?>.broadcast();
  AccountActivationCoordinator? coordinator;
  AccountActivationTicket? ticket;
  AccountActivationReceipt? receipt;
  FreshAccountListCreationPermit? freshPermit;
}

class _FreshAccountCreationOrigin {
  const _FreshAccountCreationOrigin(this.keys);
  final SecureKeyContainer keys;
}

class _AccountActivationEntry {
  const _AccountActivationEntry(
    this.ticket,
    this.coordinator,
    this.ensureCurrent,
  );
  final AccountActivationTicket ticket;
  final AccountActivationCoordinator coordinator;
  final void Function() ensureCurrent;
}

class _AccountPrimaryMutation<T> {
  const _AccountPrimaryMutation(this.value, this.entry);
  final T value;
  final _AccountActivationEntry entry;
}

/// Proves the original live identity before it is retired for one switch.
/// A pubkey label or an incoming account cannot construct rollback authority.
class AccountRollbackAuthority {
  AccountRollbackAuthority._(
    this._auth,
    this._identity,
    this._keys,
    this._generation,
    this._hostIsCurrent,
  );

  final AuthService _auth;
  final NostrIdentity _identity;
  final SecureKeyContainer _keys;
  final bool Function() _hostIsCurrent;
  int _generation;
  bool _retiredForSwitch = false;

  String get ownerPubkey => _identity.pubkey;

  bool get isCurrent =>
      !_auth._activation.disposed &&
      _auth._activation.generation == _generation &&
      _hostIsCurrent() &&
      _auth.isAuthenticated &&
      identical(_identity, _auth._currentIdentity) &&
      identical(_keys, _auth._currentKeyContainer);

  void ensureCurrent() {
    if (!isCurrent) {
      throw const AccountActivationRetiredException();
    }
  }

  /// Deliberate retirement cannot authorize a later or different auth entry.
  void retireForSwitch() {
    ensureCurrent();
    if (_retiredForSwitch) {
      throw const AccountActivationRetiredException();
    }
    _auth._retireAccountActivation();
    _generation = _auth._activation.generation;
    _retiredForSwitch = true;
  }

  Future<AccountActivationTicket> beginRollback(
    SharedPreferences preferences,
    AccountActivationTicket failedTicket,
  ) async {
    ensureCurrent();
    if (!_retiredForSwitch) {
      throw const AccountActivationRetiredException();
    }
    return AccountActivationCoordinator.forPreferences(preferences).begin(
      ownerPubkey: ownerPubkey,
      isCurrent: () => isCurrent,
      expectedPredecessor: failedTicket,
    );
  }
}

/// One-use permission from the actual new-key generation path.
///
/// Importing keys, restored sessions, source labels and local list absence
/// cannot construct this capability. Consuming it does not freeze authority:
/// the guarded operation must still recheck [isCurrentFor] after each await.
class FreshAccountListCreationPermit {
  FreshAccountListCreationPermit._(this.ownerPubkey, this._isCurrent);

  final String ownerPubkey;
  final bool Function() _isCurrent;
  bool _consumed = false;

  bool isCurrentFor(String owner) => owner == ownerPubkey && _isCurrent();

  bool consumeFor(String owner) {
    if (_consumed || !isCurrentFor(owner)) {
      return false;
    }
    _consumed = true;
    return true;
  }
}

extension AccountActivationAuthority on AuthService {
  _AccountActivationState get _activation =>
      _activationStates[this] ??= _AccountActivationState();

  /// Positive owner proof, independent of cleanup-marker absence.
  String? get committedAccountOwnerPubkey {
    final receipt = _activation.receipt;
    return isAuthenticated &&
            receipt?.isCurrent == true &&
            receipt!.ownerPubkey == currentPublicKeyHex
        ? receipt.ownerPubkey
        : null;
  }

  AccountActivationReceipt? get _committedAccountActivationReceipt =>
      committedAccountOwnerPubkey == null ? null : _activation.receipt;

  FreshAccountListCreationPermit? takeFreshAccountListCreationPermit() {
    final permit = _activation.freshPermit;
    if (permit == null || !permit.isCurrentFor(permit.ownerPubkey)) {
      return null;
    }
    _activation.freshPermit = null;
    return permit;
  }

  void bindAccountActivationHost(bool Function() isCurrent) {
    _activation.frameIsCurrent = isCurrent;
  }

  void Function() _beginAuthAttempt() {
    final state = _activation;
    state.generation += 1;
    state.receipt = null;
    state.freshPermit = null;
    state.changes.add(null);
    return _captureAuthAttempt();
  }

  void Function() _captureAuthAttempt() {
    final state = _activation;
    final generation = state.generation;
    return () {
      if (state.disposed ||
          state.generation != generation ||
          state.frameIsCurrent?.call() == false) {
        throw const AccountActivationRetiredException();
      }
    };
  }

  AccountRollbackAuthority captureAccountRollbackAuthority({
    required bool Function() hostIsCurrent,
  }) {
    final identity = _currentIdentity;
    final keys = _currentKeyContainer;
    if (identity == null ||
        keys == null ||
        _committedAccountActivationReceipt?.isCurrent != true ||
        !hostIsCurrent()) {
      throw const AccountActivationRetiredException();
    }
    return AccountRollbackAuthority._(
      this,
      identity,
      keys,
      _activation.generation,
      hostIsCurrent,
    );
  }

  _AccountActivationEntry _captureActivationEntry(
    AccountActivationTicket ticket,
    AccountActivationCoordinator coordinator,
    int generation,
  ) => _AccountActivationEntry(ticket, coordinator, () {
    if (_activation.disposed ||
        _activation.generation != generation ||
        !identical(_activation.ticket, ticket) ||
        _activation.frameIsCurrent?.call() == false) {
      throw const AccountActivationRetiredException();
    }
    coordinator.ensureCurrent(ticket);
  });

  Future<_AccountActivationEntry> _prepareAccountRestoreActivation(
    String ownerPubkey, {
    bool replaceLiveAccount = false,
  }) async {
    final state = _activation;
    if (state.awaitsHost) {
      final ticket = state.ticket;
      if (ticket == null || ticket.ownerPubkey != ownerPubkey) {
        throw const AccountActivationRetiredException();
      }
      state.coordinator!.ensureCurrent(ticket);
      return _captureActivationEntry(
        ticket,
        state.coordinator!,
        state.generation,
      );
    }
    final entryIdentity = _currentIdentity;
    final entryKeys = _currentKeyContainer;
    final previousTicket = state.ticket;
    // Revoke list authority before the first native read can suspend or fail.
    state.generation += 1;
    state.receipt = null;
    state.freshPermit = null;
    state.changes.add(null);
    state.metadataIsCurrent = null;
    state.identityIsCurrent = null;
    state.entryPrepared = true;
    final generation = state.generation;
    bool entryIsCurrent() =>
        !state.disposed &&
        state.generation == generation &&
        (state.frameIsCurrent?.call() ?? true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!entryIsCurrent()) {
        throw const AccountActivationRetiredException();
      }
      final coordinator = AccountActivationCoordinator.forPreferences(prefs);
      state.coordinator = coordinator;
      final ticket = await coordinator.begin(
        ownerPubkey: ownerPubkey,
        previousTicket: previousTicket,
        replaceLiveAccount: replaceLiveAccount,
        onTicket: (ticket) {
          if (!entryIsCurrent()) {
            throw const AccountActivationRetiredException();
          }
          state.ticket = ticket;
        },
        recoverInterruptedOwner: true,
        isCurrent: () =>
            !state.disposed &&
            state.generation == generation &&
            (state.frameIsCurrent?.call() ?? true) &&
            (state.metadataIsCurrent?.call() ?? true) &&
            (state.identityIsCurrent?.call() ?? true),
      );
      if (!entryIsCurrent()) {
        throw const AccountActivationRetiredException();
      }
      coordinator.ensureCurrent(ticket);
      return _captureActivationEntry(ticket, coordinator, generation);
    } on AccountActivationRetiredException {
      rethrow;
    } on Object catch (error) {
      // An obsolete read cannot reset a replacement identity or host.
      if (!entryIsCurrent() ||
          !identical(entryIdentity, _currentIdentity) ||
          !identical(entryKeys, _currentKeyContainer)) {
        throw const AccountActivationRetiredException();
      }
      _retireAccountActivation();
      _lastError = 'Could not establish the account safely';
      _resetTentativeSessionAfterCleanupFailure();
      throw UserDataCleanupException(
        'Could not establish the account safely',
        error,
      );
    }
  }

  /// Imports and real generation fence the device before mutating PRIMARY.
  /// The lease includes archive writes, cache updates and durable readback.
  Future<_AccountPrimaryMutation<T>> _mutateAccountPrimary<T>(
    String ownerPubkey,
    Future<T> Function() mutation, {
    bool clearPrimaryFirst = false,
    _AccountActivationEntry? preparedEntry,
  }) => _mutateAccountNative<T>(ownerPubkey, (ensureCurrent) async {
    if (clearPrimaryFirst) {
      await _keyStorage.deleteKeys();
      ensureCurrent();
    }
    final result = await mutation();
    ensureCurrent();
    if (result is SecureKeyContainer && result.publicKeyHex != ownerPubkey) {
      throw StateError('Imported identity does not match its requested owner');
    }
    // Dropping the cache does not dispose a signer held by the leaving account.
    _keyStorage.clearCache();
    final storedKeys = await _keyStorage.getKeyContainer();
    ensureCurrent();
    if (storedKeys?.publicKeyHex != ownerPubkey) {
      throw StateError('PRIMARY identity readback does not match its owner');
    }
    return result;
  }, preparedEntry: preparedEntry);

  Future<_AccountPrimaryMutation<SecureKeyContainer>> _restoreStoredPrimary(
    String ownerPubkey, {
    _AccountActivationEntry? preparedEntry,
  }) => _mutateAccountPrimary(ownerPubkey, () async {
    final switched = await _keyStorage.switchToIdentity(
      NostrKeyUtils.encodePubKey(ownerPubkey),
    );
    if (!switched) {
      throw StateError('Could not restore the requested PRIMARY identity');
    }
    _keyStorage.clearCache();
    final keys = await _keyStorage.getKeyContainer();
    if (keys == null || keys.publicKeyHex != ownerPubkey) {
      throw StateError('Restored PRIMARY identity does not match its owner');
    }
    return keys;
  }, preparedEntry: preparedEntry);

  Future<void> _acceptActivationTerms(_AccountActivationEntry entry) async {
    await _mutateAccountNative<void>(entry.ticket.ownerPubkey, (
      ensureCurrent,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      ensureCurrent();
      await AccountSessionStore(prefs).acceptTerms(
        ensureCurrent: ensureCurrent,
      );
      ensureCurrent();
    }, preparedEntry: entry);
  }

  bool _authAttemptWasRetired(
    void Function() ensureAttempt,
    _AccountActivationEntry? entry,
  ) {
    try {
      (entry?.ensureCurrent ?? ensureAttempt)();
      return false;
    } on AccountActivationRetiredException {
      return true;
    }
  }

  bool get _nostrConnectAttemptIsCurrent {
    final attempt = _activation.nostrConnectAttempt;
    return attempt != null && !_authAttemptWasRetired(attempt, null);
  }

  /// Serializes signer-slot writes under the exact prepared owner and epoch.
  Future<_AccountPrimaryMutation<T>> _mutateAccountNative<T>(
    String ownerPubkey,
    Future<T> Function(void Function() ensureCurrent) mutation, {
    _AccountActivationEntry? preparedEntry,
  }) async {
    final entry =
        preparedEntry ??
        await _prepareAccountRestoreActivation(
          ownerPubkey,
          replaceLiveAccount: true,
        );
    entry.ensureCurrent();
    if (entry.ticket.ownerPubkey != ownerPubkey) {
      throw const AccountActivationRetiredException();
    }
    final state = _activation;
    final ticket = entry.ticket;
    final coordinator = entry.coordinator;
    final generation = state.generation;
    final identity = _currentIdentity;
    final keys = _currentKeyContainer;
    try {
      return await coordinator.runGuardedStorage(ticket, () async {
        entry.ensureCurrent();
        final result = await mutation(entry.ensureCurrent);
        entry.ensureCurrent();
        return _AccountPrimaryMutation(result, entry);
      });
    } on AccountActivationRetiredException {
      rethrow;
    } on Object catch (error) {
      if (state.generation != generation ||
          !identical(state.ticket, ticket) ||
          !identical(identity, _currentIdentity) ||
          !identical(keys, _currentKeyContainer) ||
          state.disposed ||
          state.frameIsCurrent?.call() == false) {
        throw const AccountActivationRetiredException();
      }
      _retireAccountActivation();
      _lastError = 'Could not establish the account safely';
      _resetTentativeSessionAfterCleanupFailure();
      throw UserDataCleanupException(
        'Could not establish the account safely',
        error,
      );
    }
  }

  /// Opens the shared fence before a switch mutates native signer storage.
  Future<void> prepareAccountSwitchActivation(
    SharedPreferences preferences, {
    required String ownerPubkey,
    required bool Function() outgoingHostIsCurrent,
  }) async {
    final state = _activation;
    state.generation += 1;
    state.receipt = null;
    state.freshPermit = null;
    state.metadataIsCurrent = null;
    state.awaitsHost = true;
    state.entryPrepared = true;
    state.identityIsCurrent = null;
    state.hostIsCurrent = outgoingHostIsCurrent;
    final generation = state.generation;
    final coordinator = AccountActivationCoordinator.forPreferences(
      preferences,
    );
    state.coordinator = coordinator;
    state.ticket = await coordinator.begin(
      ownerPubkey: ownerPubkey,
      replaceLiveAccount: true,
      onTicket: (ticket) => state.ticket = ticket,
      // Explicit account selection may resume its known intent; it remains
      // fenced until signInForAccount proves credentials and native metadata.
      recoverInterruptedOwner: true,
      isCurrent: () =>
          !state.disposed &&
          state.generation == generation &&
          state.hostIsCurrent?.call() == true &&
          (state.metadataIsCurrent?.call() ?? true),
    );
    coordinator.ensureCurrent(state.ticket!);
  }

  /// Called only after the host supplies a receipt for a completed frame.
  Future<void> commitAccountSwitchActivation({
    required bool Function() hostIsCurrent,
  }) async {
    final state = _activation;
    final ticket = state.ticket;
    final coordinator = state.coordinator;
    if (!state.awaitsHost ||
        ticket == null ||
        coordinator == null ||
        !isAuthenticated ||
        currentPublicKeyHex != ticket.ownerPubkey) {
      throw StateError('The incoming account has not proved its identity');
    }
    state.hostIsCurrent = hostIsCurrent;
    state.frameIsCurrent = hostIsCurrent;
    final identity = _currentIdentity;
    final keys = _currentKeyContainer;
    final liveHost = state.hostIsCurrent!;
    state.hostIsCurrent = () =>
        liveHost() &&
        isAuthenticated &&
        identical(identity, _currentIdentity) &&
        identical(keys, _currentKeyContainer);
    coordinator.ensureCurrent(ticket);
    state.receipt = await coordinator.commit(ticket);
    coordinator.ensureCurrent(ticket);
    state.awaitsHost = false;
    state.entryPrepared = false;
    state.changes.add(_committedAccountActivationReceipt);
  }

  void _retireAccountActivation() {
    final state = _activation;
    state.generation += 1;
    state.receipt = null;
    state.freshPermit = null;
    state.coordinator?.retire(state.ticket);
    if (!state.changes.isClosed) state.changes.add(null);
  }

  AccountActivationTicket? retireAccountSwitchActivation() {
    final ticket = _activation.ticket;
    _retireAccountActivation();
    return ticket;
  }

  /// A rollback receives authority only after its exact old metadata is read
  /// back and its original rendered container still owns the device.
  Future<void> restoreCurrentAccountActivation(
    SharedPreferences preferences, {
    required bool Function() hostIsCurrent,
    AccountActivationTicket? previousTicket,
  }) async {
    final identity = _currentIdentity;
    final keys = _currentKeyContainer;
    if (!hostIsCurrent() ||
        !isAuthenticated ||
        identity == null ||
        keys == null) {
      throw const AccountActivationRetiredException();
    }
    final state = _activation;
    state.awaitsHost = true;
    state.hostIsCurrent = () =>
        hostIsCurrent() &&
        isAuthenticated &&
        identical(identity, _currentIdentity) &&
        identical(keys, _currentKeyContainer);
    state.generation += 1;
    final generation = state.generation;
    final coordinator = AccountActivationCoordinator.forPreferences(
      preferences,
    );
    state.coordinator = coordinator;
    final ticket = await coordinator.begin(
      ownerPubkey: keys.publicKeyHex,
      previousTicket: previousTicket,
      isCurrent: () =>
          !state.disposed &&
          state.generation == generation &&
          state.hostIsCurrent?.call() == true &&
          (state.metadataIsCurrent?.call() ?? true),
    );
    state.ticket = ticket;
    coordinator.ensureCurrent(ticket);
    await preferences.reload();
    coordinator.ensureCurrent(ticket);
    if (preferences.getString('current_user_pubkey_hex') != keys.publicKeyHex ||
        preferences.getString(kLastUsedNpubKey) != keys.npub ||
        preferences.getString(kAuthenticationSourceKey) != _authSource.code) {
      coordinator.retire(ticket);
      throw StateError('The outgoing session was not durably restored');
    }
    state.metadataIsCurrent = () =>
        preferences.get('current_user_pubkey_hex') == keys.publicKeyHex &&
        preferences.get(kLastUsedNpubKey) == keys.npub &&
        preferences.get(kAuthenticationSourceKey) == _authSource.code;
    state.receipt = await coordinator.commit(ticket);
    coordinator.ensureCurrent(ticket);
    state.awaitsHost = false;
    state.entryPrepared = false;
    state.changes.add(_committedAccountActivationReceipt);
  }

  Future<AccountActivationTicket> _beginSessionActivation(
    SharedPreferences prefs,
    NostrIdentity? identity,
    SecureKeyContainer keys,
  ) async {
    final state = _activation;
    state.metadataIsCurrent = null;
    if (state.disposed ||
        !identical(identity, _currentIdentity) ||
        !identical(keys, _currentKeyContainer)) {
      throw const AccountActivationRetiredException();
    }
    if (state.entryPrepared) {
      state.entryPrepared = false;
      state.identityIsCurrent = () =>
          identical(identity, _currentIdentity) &&
          identical(keys, _currentKeyContainer);
      final ticket = state.ticket;
      if (ticket == null || ticket.ownerPubkey != keys.publicKeyHex) {
        throw StateError('Account switch identity does not match its intent');
      }
      final hostIsCurrent =
          state.hostIsCurrent ??
          () => !state.disposed && (state.frameIsCurrent?.call() ?? true);
      state.hostIsCurrent = () =>
          hostIsCurrent() &&
          identical(identity, _currentIdentity) &&
          identical(keys, _currentKeyContainer);
      state.coordinator!.ensureCurrent(ticket);
      return ticket;
    }
    state.generation += 1;
    state.receipt = null;
    state.freshPermit = null;
    state.changes.add(null);
    final generation = state.generation;
    final coordinator = AccountActivationCoordinator.forPreferences(prefs);
    state.coordinator = coordinator;
    final ticket = await coordinator.begin(
      ownerPubkey: keys.publicKeyHex,
      previousTicket: state.ticket,
      // The real signer has been rebuilt for this exact full owner. Retained
      // pending evidence still cannot grant permission; all native session
      // metadata, cleanup and host settlement must be proved afresh below.
      recoverInterruptedOwner: identity?.pubkey == keys.publicKeyHex,
      isCurrent: () =>
          !state.disposed &&
          state.generation == generation &&
          identical(identity, _currentIdentity) &&
          identical(keys, _currentKeyContainer) &&
          (state.frameIsCurrent?.call() ?? true) &&
          (state.metadataIsCurrent?.call() ?? true),
    );
    state.ticket = ticket;
    coordinator.ensureCurrent(ticket);
    return ticket;
  }

  void _grantFreshAccountListCreationPermit(SecureKeyContainer keys) {
    final receipt = _activation.receipt;
    if (receipt == null ||
        !receipt.isCurrent ||
        committedAccountOwnerPubkey != keys.publicKeyHex) {
      return;
    }
    _activation.freshPermit = FreshAccountListCreationPermit._(
      keys.publicKeyHex,
      () =>
          receipt.isCurrent &&
          isAuthenticated &&
          identical(keys, _currentKeyContainer) &&
          committedAccountOwnerPubkey == keys.publicKeyHex,
    );
  }
}
