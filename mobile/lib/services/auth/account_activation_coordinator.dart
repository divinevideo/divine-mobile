// ABOUTME: Proves account activation with durable metadata and live authority.
// ABOUTME: Failed or retired transitions remain fenced across async settlement.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// The activation stopped belonging to the live account or mounted host.
class AccountActivationRetiredException implements Exception {
  const AccountActivationRetiredException();
}

/// A capability owned by one coordinator; callers cannot reconstruct it.
class AccountActivationTicket {
  AccountActivationTicket._(this.ownerPubkey, this._token, this._isCurrent);

  final String ownerPubkey;
  final String _token;
  final bool Function() _isCurrent;
  bool _settled = false;
  bool _signedOut = false;
}

/// Durable settlement is useful only while its original authority stays live.
class AccountActivationReceipt {
  AccountActivationReceipt._(this._coordinator, this._ticket);

  final AccountActivationCoordinator _coordinator;
  final AccountActivationTicket _ticket;

  String get ownerPubkey => _ticket.ownerPubkey;
  bool get isCurrent => _coordinator._isCommitted(_ticket);
}

/// Reserves only ownerless cleanup; it cannot identify or authenticate a user.
class OwnerlessSignOutReservation {
  OwnerlessSignOutReservation._(
    this._activeAtStart,
    this._recordAtStart,
    this._isCurrent,
  );

  final AccountActivationTicket? _activeAtStart;
  final Object? _recordAtStart;
  final bool Function() _isCurrent;
  bool _failed = false;
}

/// Owner-scoped cleanup authority, independent of authenticated authority.
/// Only the coordinator can create this capability on its native queue.
class AccountCleanupStorageLease {
  AccountCleanupStorageLease._(
    this._coordinator,
    this.removedOwnerPubkey,
    this._isCurrent,
  ) : _activeAtStart = _coordinator._active,
      _ownerlessAtStart = _coordinator._ownerlessSignOut,
      _record = _coordinator._preferences.get(
        AccountActivationCoordinator.storageKey,
      ),
      _owner = _coordinator._preferences.get('current_user_pubkey_hex'),
      _uncertain = _coordinator._uncertain,
      _verifiedRecord = _coordinator._verifiedRecord;

  final AccountActivationCoordinator _coordinator;
  final String removedOwnerPubkey;
  final bool Function() _isCurrent;
  AccountActivationTicket? _activeAtStart;
  final OwnerlessSignOutReservation? _ownerlessAtStart;
  Object? _record;
  Object? _owner;
  bool _uncertain;
  String? _verifiedRecord;
  bool _closed = false;

  void ensureCurrent() => _coordinator._ensureAccountCleanupCurrent(this);

  /// Verifies that terminal retirement can affect only the removed owner.
  Future<void> verifyRetiredOwnerRemoval() =>
      _coordinator._verifyRetiredOwnerRemoval(this);

  /// Called only after actual native login and private-data cleanup succeeded.
  /// Retires owned metadata and intent, never an authenticated receipt/permit.
  Future<void> completeRetiredOwnerRemoval() =>
      _coordinator._completeRetiredOwnerRemoval(this);
}

/// Device-scoped activation gate shared by outgoing and incoming containers.
///
/// The retained record is evidence, not a permission on a later process. A new
/// process must prove its restored identity again. Reading the gate never
/// writes, removes an intent, or treats an absent cleanup marker as settlement.
class AccountActivationCoordinator {
  AccountActivationCoordinator._(this._preferences);

  static const storageKey = 'pending_account_activation';
  // This device-wide security receipt survives outgoing-account data cleanup.
  static const List<String> deviceScopedPrefsKeys = [storageKey];
  static final _instances = Expando<AccountActivationCoordinator>();

  factory AccountActivationCoordinator.forPreferences(
    SharedPreferences prefs,
  ) => _instances[prefs] ??= AccountActivationCoordinator._(prefs);

  final SharedPreferences _preferences;
  final _changes = StreamController<void>.broadcast(sync: true);
  AccountActivationTicket? _active;
  OwnerlessSignOutReservation? _ownerlessSignOut;
  String? _verifiedRecord;
  bool _uncertain = false;
  Future<void> _storageTail = Future<void>.value();
  bool _notifying = false;
  bool _notificationQueued = false;

  Stream<void> get changes => _changes.stream;

  void _notifyChanges() {
    if (_notifying) {
      if (!_notificationQueued) {
        _notificationQueued = true;
        scheduleMicrotask(() {
          if (!_notificationQueued) {
            return;
          }
          _notificationQueued = false;
          _notifyChanges();
        });
      }
      return;
    }
    _notificationQueued = false;
    _notifying = true;
    try {
      _changes.add(null);
    } finally {
      _notifying = false;
    }
  }

  bool get hasUnresolvedActivation {
    if (_ownerlessSignOut != null) {
      return true;
    }
    final active = _active;
    if (active != null) {
      if (active._signedOut &&
          _isLive(active) &&
          _preferences.get(storageKey) == _verifiedRecord &&
          _preferences.get('current_user_pubkey_hex') == null) {
        return false;
      }
      return !_isCommitted(active);
    }
    return _uncertain || _preferences.containsKey(storageKey);
  }

  String? get committedOwnerPubkey {
    final active = _active;
    return active != null && _isCommitted(active) ? active.ownerPubkey : null;
  }

  bool _isLive(AccountActivationTicket ticket) {
    if (!identical(_active, ticket) || _uncertain) {
      return false;
    }
    try {
      return ticket._isCurrent();
    } on Object {
      return false;
    }
  }

  bool _isCommitted(AccountActivationTicket ticket) =>
      ticket._settled &&
      _isLive(ticket) &&
      _preferences.get(storageKey) == _verifiedRecord;

  void ensureCurrent(AccountActivationTicket ticket) {
    if (!_isLive(ticket)) {
      throw const AccountActivationRetiredException();
    }
  }

  /// Verifies a native ownerless state without replacing retained evidence.
  Future<OwnerlessSignOutReservation> reserveOwnerlessSignOut({
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) {
      throw const AccountActivationRetiredException();
    }
    final active = _active;
    final reservation = _ownerlessSignOut;
    final record = _preferences.get(storageKey);
    if (hasUnresolvedActivation ||
        committedOwnerPubkey != null ||
        _preferences.get('current_user_pubkey_hex') != null) {
      throw StateError('Ownerless sign out cannot clear another account');
    }
    await _preferences.reload();
    if (!isCurrent() ||
        !identical(active, _active) ||
        !identical(reservation, _ownerlessSignOut)) {
      throw const AccountActivationRetiredException();
    }
    if (hasUnresolvedActivation ||
        committedOwnerPubkey != null ||
        _preferences.get(storageKey) != record ||
        _preferences.get('current_user_pubkey_hex') != null) {
      throw StateError('Ownerless sign out requires verified account absence');
    }
    final next = OwnerlessSignOutReservation._(active, record, isCurrent);
    _ownerlessSignOut = next;
    _notifyChanges();
    return next;
  }

  void ensureOwnerlessSignOutCurrent(OwnerlessSignOutReservation reservation) {
    var current = false;
    try {
      current = reservation._isCurrent();
    } on Object {
      // A retired host or disposed auth object has no cleanup authority.
    }
    if (!current ||
        reservation._failed ||
        !identical(_ownerlessSignOut, reservation) ||
        !identical(_active, reservation._activeAtStart) ||
        _preferences.get(storageKey) != reservation._recordAtStart ||
        _preferences.get('current_user_pubkey_hex') != null) {
      throw const AccountActivationRetiredException();
    }
  }

  /// Shares the native-operation queue with real account activation.
  Future<T> runOwnerlessSignOutStorage<T>(
    OwnerlessSignOutReservation reservation,
    Future<T> Function() operation,
  ) async {
    final previous = _storageTail;
    final finished = Completer<void>();
    _storageTail = finished.future;
    await previous;
    try {
      ensureOwnerlessSignOutCurrent(reservation);
      final result = await operation();
      ensureOwnerlessSignOutCurrent(reservation);
      return result;
    } on Object {
      if (identical(_ownerlessSignOut, reservation)) {
        reservation._failed = true;
        _notifyChanges();
      }
      rethrow;
    } finally {
      finished.complete();
    }
  }

  /// Releases cleanup only; no authenticated receipt or durable owner is made.
  void completeOwnerlessSignOut(OwnerlessSignOutReservation reservation) {
    ensureOwnerlessSignOutCurrent(reservation);
    _ownerlessSignOut = null;
    _notifyChanges();
  }

  /// Records intent before cleanup, signer mutation or session metadata writes.
  Future<AccountActivationTicket> begin({
    required String ownerPubkey,
    required bool Function() isCurrent,
    AccountActivationTicket? previousTicket,
    bool replaceLiveAccount = false,
    bool recoverInterruptedOwner = false,
    AccountActivationTicket? expectedPredecessor,
    void Function(AccountActivationTicket)? onTicket,
  }) async {
    if (!isCurrent()) {
      throw const AccountActivationRetiredException();
    }
    if (expectedPredecessor != null &&
        !identical(_active, expectedPredecessor)) {
      throw const AccountActivationRetiredException();
    }
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(ownerPubkey)) {
      throw ArgumentError.value(ownerPubkey, 'ownerPubkey');
    }
    // A real identity takes priority before any native read or write. An old
    // ownerless teardown may still be waiting on an outgoing callback.
    if (_ownerlessSignOut != null) {
      _ownerlessSignOut = null;
      _notifyChanges();
    }
    // A cold process has no ticket capable of superseding retained evidence.
    // Resume only a well-formed terminal record for the exact native owner;
    // interrupted, damaged and foreign records require explicit recovery.
    String? recoveredToken;
    if (_active == null && _preferences.containsKey(storageKey)) {
      final before = _preferences.get(storageKey);
      _uncertain = true;
      await _preferences.reload();
      if (!isCurrent() || _preferences.get(storageKey) != before) {
        throw StateError('Account activation evidence could not be verified');
      }
      final raw = _preferences.get(storageKey);
      Object? decoded;
      try {
        decoded = raw is String ? jsonDecode(raw) : null;
      } on FormatException {
        throw StateError('Account activation evidence is unreadable');
      }
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != 1 ||
          decoded['token'] is! String ||
          !RegExp(r'^[0-9a-f]{48}$').hasMatch(decoded['token'] as String) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(
            decoded['ownerPubkey'] is String
                ? decoded['ownerPubkey'] as String
                : '',
          ) ||
          (decoded['phase'] != 'signedOut' &&
              decoded['ownerPubkey'] != ownerPubkey) ||
          !const [
            'pending',
            'identityReady',
            'committed',
            'signedOut',
          ].contains(decoded['phase']) ||
          (decoded['phase'] != 'committed' &&
              decoded['phase'] != 'signedOut' &&
              !recoverInterruptedOwner) ||
          (decoded['phase'] == 'committed' &&
              _preferences.get('current_user_pubkey_hex') != ownerPubkey) ||
          (decoded['phase'] == 'signedOut' &&
              _preferences.get('current_user_pubkey_hex') != null)) {
        throw StateError('Account activation evidence requires recovery');
      }
      if (decoded['phase'] != 'committed' && decoded['phase'] != 'signedOut') {
        recoveredToken = decoded['token'] as String;
      }
    }
    final active = _active;
    if (expectedPredecessor != null &&
        !identical(active, expectedPredecessor)) {
      throw const AccountActivationRetiredException();
    }
    if (!replaceLiveAccount &&
        active != null &&
        !active._signedOut &&
        _isLive(active) &&
        !identical(active, previousTicket)) {
      throw StateError('Another account activation is still authoritative');
    }
    final token =
        recoveredToken ??
        List<int>.generate(
          24,
          (_) => Random.secure().nextInt(256),
        ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final ticket = AccountActivationTicket._(ownerPubkey, token, isCurrent);
    _active = ticket;
    _verifiedRecord = null;
    _uncertain = false;
    onTicket?.call(ticket);
    _notifyChanges();
    await _record(ticket, 'pending');
    return ticket;
  }

  Future<void> markIdentityReady(AccountActivationTicket ticket) =>
      _record(ticket, 'identityReady');

  Future<AccountActivationReceipt> commit(
    AccountActivationTicket ticket,
  ) async {
    await _record(ticket, 'committed');
    ensureCurrent(ticket);
    ticket._settled = true;
    final receipt = AccountActivationReceipt._(this, ticket);
    _notifyChanges();
    return receipt;
  }

  /// Only a verified logout may stop gating later explicit authentication.
  /// This terminal record never grants an authenticated owner receipt.
  Future<void> completeSignOut(AccountActivationTicket ticket) async {
    ensureCurrent(ticket);
    if (_preferences.get('current_user_pubkey_hex') != null) {
      throw StateError('The outgoing session is still persisted');
    }
    await _record(ticket, 'signedOut');
    ensureCurrent(ticket);
    ticket._signedOut = true;
    ticket._settled = false;
    _notifyChanges();
  }

  /// Revocation preserves durable evidence and cannot retire a newer ticket.
  void retire(AccountActivationTicket? ticket) {
    if (ticket == null || !identical(_active, ticket)) {
      return;
    }
    if (!ticket._settled && _uncertain) {
      return;
    }
    ticket._settled = false;
    _uncertain = true;
    _notifyChanges();
  }

  Future<T> runGuardedStorage<T>(
    AccountActivationTicket ticket,
    Future<T> Function() operation,
  ) async {
    final previous = _storageTail;
    final finished = Completer<void>();
    _storageTail = finished.future;
    await previous;
    try {
      ensureCurrent(ticket);
      final result = await operation();
      ensureCurrent(ticket);
      return result;
    } on Object {
      retire(ticket);
      rethrow;
    } finally {
      finished.complete();
    }
  }

  /// Serializes inactive-owner cleanup without retiring another live account.
  Future<T> runAccountCleanupStorage<T>({
    required String removedOwnerPubkey,
    required bool Function() isCurrent,
    required Future<T> Function(AccountCleanupStorageLease lease) operation,
  }) async {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(removedOwnerPubkey)) {
      throw ArgumentError.value(removedOwnerPubkey, 'removedOwnerPubkey');
    }
    final lease = AccountCleanupStorageLease._(
      this,
      removedOwnerPubkey,
      isCurrent,
    );
    if (_active case final active?
        when _isCommitted(active) && active.ownerPubkey == removedOwnerPubkey) {
      throw StateError('The active account must use verified sign out');
    }
    lease.ensureCurrent();
    final previous = _storageTail;
    final finished = Completer<void>();
    _storageTail = finished.future;
    await previous;
    try {
      lease.ensureCurrent();
      final result = await operation(lease);
      lease.ensureCurrent();
      return result;
    } finally {
      // An Alice-only refusal preserves Bob's unrelated ticket and receipt.
      lease._closed = true;
      finished.complete();
    }
  }

  void _ensureAccountCleanupActor(AccountCleanupStorageLease lease) {
    var current = false;
    try {
      current = lease._isCurrent();
    } on Object {
      // A disposed or retired host has no target-cleanup authority.
    }
    if (lease._closed ||
        !identical(lease._coordinator, this) ||
        !current ||
        !identical(_active, lease._activeAtStart) ||
        !identical(_ownerlessSignOut, lease._ownerlessAtStart) ||
        _uncertain != lease._uncertain ||
        _verifiedRecord != lease._verifiedRecord) {
      throw const AccountActivationRetiredException();
    }
  }

  void _ensureAccountCleanupCurrent(AccountCleanupStorageLease lease) {
    _ensureAccountCleanupActor(lease);
    if (_preferences.get(storageKey) != lease._record ||
        _preferences.get('current_user_pubkey_hex') != lease._owner) {
      throw const AccountActivationRetiredException();
    }
  }

  void _validateRetiredOwnerRemoval(AccountCleanupStorageLease lease) {
    final owner = lease.removedOwnerPubkey;
    if (_ownerlessSignOut != null ||
        (lease._owner != null && lease._owner != owner) ||
        (_active != null && _active!.ownerPubkey != owner)) {
      throw StateError('Local removal cannot retire another account');
    }
    final raw = lease._record;
    if (raw == null) return;
    Object? decoded;
    try {
      decoded = raw is String ? jsonDecode(raw) : null;
    } on FormatException {
      throw StateError('Local account activation evidence is unreadable');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] is! int ||
        decoded['version'] != 1 ||
        decoded['token'] is! String ||
        !RegExp(r'^[0-9a-f]{48}$').hasMatch(decoded['token'] as String) ||
        decoded['ownerPubkey'] != owner ||
        !const [
          'pending',
          'identityReady',
          'committed',
          'signedOut',
        ].contains(decoded['phase'])) {
      throw StateError(
        'Local account activation evidence cannot be attributed',
      );
    }
  }

  Future<void> _verifyRetiredOwnerRemoval(
    AccountCleanupStorageLease lease,
  ) async {
    lease.ensureCurrent();
    await _preferences.reload();
    lease.ensureCurrent();
    _validateRetiredOwnerRemoval(lease);
  }

  Future<void> _completeRetiredOwnerRemoval(
    AccountCleanupStorageLease lease,
  ) async {
    await _verifyRetiredOwnerRemoval(lease);
    final owner = lease.removedOwnerPubkey;
    if (lease._owner == owner) {
      final removed = await _preferences.remove('current_user_pubkey_hex');
      _ensureAccountCleanupActor(lease);
      if (!removed) {
        throw StateError('Could not remove retired account metadata');
      }
      await _preferences.reload();
      _ensureAccountCleanupActor(lease);
      if (_preferences.get('current_user_pubkey_hex') != null ||
          _preferences.get(storageKey) != lease._record) {
        throw StateError('Retired account metadata removal did not persist');
      }
      lease._owner = null;
      lease.ensureCurrent();
    }
    if (lease._record != null) {
      lease.ensureCurrent();
      final removed = await _preferences.remove(storageKey);
      _ensureAccountCleanupActor(lease);
      if (!removed) {
        throw StateError('Could not retire local account activation');
      }
      await _preferences.reload();
      _ensureAccountCleanupActor(lease);
      if (_preferences.get(storageKey) != null ||
          _preferences.get('current_user_pubkey_hex') != null) {
        throw StateError('Local account retirement did not persist');
      }
      lease._record = null;
    }
    lease.ensureCurrent();
    if (_active?.ownerPubkey == owner) {
      _active = null;
      lease._activeAtStart = null;
    }
    _verifiedRecord = null;
    lease._verifiedRecord = null;
    _uncertain = false;
    lease._uncertain = false;
    // No receipt, authentication or fresh-list creation authority is issued.
    _notifyChanges();
    lease.ensureCurrent();
  }

  Future<void> _record(AccountActivationTicket ticket, String phase) =>
      runGuardedStorage(ticket, () async {
        final encoded = jsonEncode({
          'version': 1,
          'token': ticket._token,
          'ownerPubkey': ticket.ownerPubkey,
          'phase': phase,
        });
        final written = await _preferences.setString(storageKey, encoded);
        ensureCurrent(ticket);
        if (!written) {
          throw StateError('Could not persist account activation');
        }
        await _preferences.reload();
        ensureCurrent(ticket);
        if (_preferences.get(storageKey) != encoded) {
          throw StateError('Account activation readback did not match');
        }
        _verifiedRecord = encoded;
      });
}
