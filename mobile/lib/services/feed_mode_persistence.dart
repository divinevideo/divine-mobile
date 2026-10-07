// ABOUTME: Device-lifetime ownership of account-scoped Home preferences.
// ABOUTME: Preserves accepted selections across route and account replacement.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

const legacyHomeFeedModeKey = 'selected_feed_mode';

/// Explicitly owned by DeviceScope and injected into every account container.
/// Coordinators are reused by complete account pubkey so pending old writers
/// and returning Home pages always share the latest accepted selection.
class FeedModePersistenceRegistry {
  FeedModePersistenceRegistry({required SharedPreferences? sharedPreferences})
    : _preferences = sharedPreferences;

  final SharedPreferences? _preferences;
  final Map<String?, FeedModePersistenceCoordinator> _accounts = {};
  FeedModePersistenceCoordinator? _active;

  FeedModePersistenceCoordinator forAccount(String? userPubkey) {
    final coordinator = _accounts.putIfAbsent(userPubkey, () {
      late final FeedModePersistenceCoordinator created;
      return created = FeedModePersistenceCoordinator(
        sharedPreferences: _preferences,
        userPubkey: userPubkey,
        mayClearLegacy: () => identical(_active, created),
        clearLegacy: () => _clearLegacy(created),
        onClaim: () => _active = created,
      );
    });
    return coordinator;
  }

  Future<void> _clearLegacy(FeedModePersistenceCoordinator account) async {
    final owner = account._owner;
    if (!identical(_active, account) || owner == null) return;
    final guest = forAccount(null);
    final generation = guest._generation;
    final clear = await guest._prepare(null, guest._owner);
    if (identical(_active, account) &&
        identical(owner, account._owner) &&
        generation == guest._generation &&
        clear.accept()) {
      return;
    }
    // A guest can claim the global namespace during the native removal itself.
    // Its latest accepted choice must win even if that removal completes last.
    await clear.discard();
  }

  void dispose() {
    _active = null;
    for (final coordinator in _accounts.values) {
      coordinator.dispose();
    }
    _accounts.clear();
  }
}

/// A replaceable bloc releases only its own lease, never the device coordinator.
class FeedModePersistenceLease {
  FeedModePersistenceLease._(this._coordinator);
  final FeedModePersistenceCoordinator _coordinator;

  String? get savedValue => _coordinator._savedValue;
  Future<void> persist(String value) => _coordinator._persist(value, this);
  Future<ProvisionalFeedModeWrite> prepare(String value) =>
      _coordinator._prepare(value, this);

  void release() {
    if (identical(_coordinator._owner, this)) _coordinator._owner = null;
  }
}

/// Account-scoped selection ownership retained above a replaceable Home bloc.
///
/// SharedPreferences changes its cache before a platform write finishes. Home
/// therefore reads the accepted selection while writes are pending. Automatic
/// fallback/migration writes remain provisional until their bloc can accept
/// the exact snapshot; obsolete native completions repair the latest choice.
class FeedModePersistenceCoordinator {
  FeedModePersistenceCoordinator({
    required SharedPreferences? sharedPreferences,
    required String? userPubkey,
    bool Function()? mayClearLegacy,
    Future<void> Function()? clearLegacy,
    void Function()? onClaim,
  }) : _preferences = sharedPreferences,
       _userPubkey = userPubkey,
       _mayClearLegacy = mayClearLegacy,
       _clearLegacy = clearLegacy,
       _onClaim = onClaim;

  final SharedPreferences? _preferences;
  final String? _userPubkey;
  final bool Function()? _mayClearLegacy;
  final Future<void> Function()? _clearLegacy;
  final void Function()? _onClaim;
  Object? _owner;
  String? _acceptedValue;
  int _generation = 0;
  int _pendingWrites = 0;
  bool _retired = false;

  /// Retires device ownership. A replaceable Page/bloc only releases its lease;
  /// pending writes still repair their own key after device disposal.
  void dispose() {
    _retired = true;
    _owner = null;
  }

  String get key => _userPubkey == null
      ? legacyHomeFeedModeKey
      : '${legacyHomeFeedModeKey}_$_userPubkey';

  String? get _savedValue {
    if (_pendingWrites == 0) _acceptedValue = _preferences?.getString(key);
    return _acceptedValue;
  }

  bool matches({
    required SharedPreferences? sharedPreferences,
    required String? userPubkey,
  }) => identical(_preferences, sharedPreferences) && _userPubkey == userPubkey;

  FeedModePersistenceLease claim() {
    if (_retired) throw StateError('The Home persistence scope is retired.');
    // Capture storage before the next bloc claims any still-pending writes.
    _savedValue;
    final lease = FeedModePersistenceLease._(this);
    _owner = lease;
    _onClaim?.call();
    return lease;
  }

  Future<void> _write(String? value) async {
    final prefs = _preferences;
    if (prefs == null) return;
    final persisted = value == null
        ? await prefs.remove(key)
        : await prefs.setString(key, value);
    if (!persisted) {
      throw StateError('The Home selection could not be persisted.');
    }
    if (_userPubkey != null &&
        !_retired &&
        _owner != null &&
        (_mayClearLegacy?.call() ?? true)) {
      final coordinatedClear = _clearLegacy;
      if (coordinatedClear != null) {
        await coordinatedClear();
      } else if (!await prefs.remove(legacyHomeFeedModeKey)) {
        throw StateError('The legacy Home selection could not be cleared.');
      }
    }
  }

  Future<void> _repair(String? written) async {
    var completedValue = written;
    while (completedValue != _acceptedValue) {
      final value = _acceptedValue;
      final generation = _generation;
      await _write(value);
      completedValue = value;
      if (generation == _generation) return;
    }
  }

  Future<void> _persist(String value, Object owner) async {
    if (!identical(owner, _owner)) return;
    _savedValue;
    _acceptedValue = value;
    ++_generation;
    ++_pendingWrites;
    try {
      await _write(value);
      await _repair(value);
    } finally {
      --_pendingWrites;
    }
  }

  Future<ProvisionalFeedModeWrite> _prepare(
    String? value,
    Object? owner,
  ) async {
    if (!identical(owner, _owner)) {
      return ProvisionalFeedModeWrite._(this, value, owner, active: false);
    }
    _savedValue;
    ++_pendingWrites;
    try {
      await _write(value);
      return ProvisionalFeedModeWrite._(this, value, owner, active: true);
    } catch (error, stackTrace) {
      try {
        // The preferences cache already contains the provisional value even
        // when the platform write throws. Restore the accepted choice first.
        await _repair(value);
      } catch (repairError, repairStackTrace) {
        Log.warning(
          'Home could not repair a failed provisional preference write',
          name: 'FeedModePersistenceCoordinator',
          category: LogCategory.storage,
          error: repairError,
          stackTrace: repairStackTrace,
        );
      } finally {
        --_pendingWrites;
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

/// The caller accepts synchronously after checking its snapshot and lifecycle.
/// A discard repairs storage even after that caller's bloc has closed.
class ProvisionalFeedModeWrite {
  ProvisionalFeedModeWrite._(
    this._coordinator,
    this._value,
    this._owner, {
    required bool active,
  }) : _active = active;

  final FeedModePersistenceCoordinator _coordinator;
  final String? _value;
  final Object? _owner;
  bool _active;

  bool accept() {
    if (!_active || !identical(_owner, _coordinator._owner)) return false;
    _coordinator._acceptedValue = _value;
    ++_coordinator._generation;
    --_coordinator._pendingWrites;
    _active = false;
    return true;
  }

  Future<void> discard() async {
    if (!_active) return;
    try {
      await _coordinator._repair(_value);
    } finally {
      --_coordinator._pendingWrites;
      _active = false;
    }
  }
}
