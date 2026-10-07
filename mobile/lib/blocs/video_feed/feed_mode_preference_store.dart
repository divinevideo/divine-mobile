// ABOUTME: Reads/writes the persisted home-feed source (a FeedMode or curated
// ABOUTME: list selection), account-scoped, with conservative migration off the
// ABOUTME: legacy global key. Extracted from VideoFeedBloc (epic #4339).

part of 'video_feed_bloc.dart';

/// Legacy SharedPreferences key for persisting the selected feed mode.
///
/// New authenticated sessions use a pubkey-scoped key so switching accounts
/// cannot carry a previous account's Following/list selection into a newly
/// imported key with a different social graph.
const _legacyFeedModeKey = 'selected_feed_mode';

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
  }) : _preferences = sharedPreferences,
       _userPubkey = userPubkey;

  final SharedPreferences? _preferences;
  final String? _userPubkey;
  Object? _owner;
  String? _acceptedValue;
  int _generation = 0;
  int _pendingWrites = 0;
  bool _retired = false;

  /// Retires this account scope when its provider is removed. Pending writes
  /// still repair their own key, but cannot clear a later guest's preference.
  void dispose() {
    _retired = true;
    _owner = null;
  }

  String get key => _userPubkey == null
      ? _legacyFeedModeKey
      : '${_legacyFeedModeKey}_$_userPubkey';

  String? get _savedValue {
    if (_pendingWrites == 0) _acceptedValue = _preferences?.getString(key);
    return _acceptedValue;
  }

  void _claim(Object owner) {
    if (_retired) throw StateError('The Home persistence scope is retired.');
    // Capture storage before the next bloc claims any still-pending writes.
    _savedValue;
    _owner = owner;
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
    if (_userPubkey != null && !_retired) {
      await prefs.remove(_legacyFeedModeKey);
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

  Future<_ProvisionalFeedModeWrite> _prepare(String value, Object owner) async {
    if (!identical(owner, _owner)) {
      return _ProvisionalFeedModeWrite(this, value, owner, active: false);
    }
    _savedValue;
    ++_pendingWrites;
    try {
      await _write(value);
      return _ProvisionalFeedModeWrite(this, value, owner, active: true);
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
class _ProvisionalFeedModeWrite {
  _ProvisionalFeedModeWrite(
    this._coordinator,
    this._value,
    this._owner, {
    required bool active,
  }) : _active = active;

  final FeedModePersistenceCoordinator _coordinator;
  final String _value;
  final Object _owner;
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

/// Persists and restores the selected [VideoFeedSource] for [VideoFeedBloc].
class FeedModePreferenceStore {
  FeedModePreferenceStore({
    required SharedPreferences? sharedPreferences,
    required String? userPubkey,
    required FollowRepository followRepository,
    required CuratedListRepository curatedListRepository,
    FeedModePersistenceCoordinator? persistenceCoordinator,
  }) : _sharedPreferences = sharedPreferences,
       _userPubkey = userPubkey,
       _followRepository = followRepository,
       _curatedListRepository = curatedListRepository,
       _coordinator =
           persistenceCoordinator ??
           FeedModePersistenceCoordinator(
             sharedPreferences: sharedPreferences,
             userPubkey: userPubkey,
           ) {
    if (!identical(_coordinator._preferences, sharedPreferences) ||
        _coordinator._userPubkey != userPubkey) {
      throw ArgumentError(
        'The persistence coordinator must match the account and preferences.',
      );
    }
    _coordinator._claim(_owner);
  }

  final SharedPreferences? _sharedPreferences;
  final String? _userPubkey;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;
  final FeedModePersistenceCoordinator _coordinator;
  final Object _owner = Object();

  /// Account-scoped key the selected source is stored under.
  String get key => _coordinator.key;

  String? get _savedScopedValue => _coordinator._savedValue;

  /// The persisted source, or [VideoFeedSource.fromMode] of [fallbackMode] when
  /// nothing is stored.
  VideoFeedSource restoreSource(FeedMode fallbackMode) {
    final saved = savedValue();
    if (saved == null) {
      return VideoFeedSource.fromMode(fallbackMode);
    }
    return sourceFromValue(saved) ?? const VideoFeedSource.forYou();
  }

  /// The stored persistence value for the active account, migrating a legacy
  /// global value conservatively when safe.
  String? savedValue() {
    final prefs = _sharedPreferences;
    if (prefs == null) return null;

    final scoped = _savedScopedValue;
    if (scoped != null) return scoped;

    // Only unauthenticated/test callers should keep reading the legacy global
    // key directly. Authenticated sessions migrate it conservatively below.
    if (_userPubkey == null) {
      return prefs.getString(_legacyFeedModeKey);
    }

    final legacy = prefs.getString(_legacyFeedModeKey);
    if (legacy == null) return null;

    final migratedSource = sourceFromValue(legacy);
    if (migratedSource == null) return null;

    // The bug fixed here: a newly imported key could inherit another account's
    // Following mode and land on an empty feed. Only migrate Following when
    // the current account already has a non-empty following list.
    if (migratedSource.type == VideoFeedSourceType.following &&
        _followRepository.followingPubkeys.isEmpty) {
      return null;
    }

    // A legacy list preference cannot be proven to belong to the authenticated
    // account because the curated-list bridge can briefly hold stale data
    // across account switches. Only restore list selections from scoped keys.
    if (migratedSource.type == VideoFeedSourceType.subscribedList) {
      return null;
    }

    unawaited(persist(migratedSource));
    return migratedSource.persistenceValue;
  }

  /// Resolves a persisted value to a [VideoFeedSource], or `null` when unknown.
  VideoFeedSource? sourceFromValue(String saved) {
    if (saved.startsWith('list:')) {
      final listId = saved.substring('list:'.length);
      final list = _curatedListRepository.getListById(listId);
      if (list != null &&
          (list.authorScopedId == listId ||
              _curatedListRepository.hasCompleteSubscriptionSnapshot)) {
        return VideoFeedSource.subscribedList(
          listId: list.authorScopedId,
          listName: list.name,
        );
      }
      return null;
    }
    if (saved == FeedMode.following.name) {
      return const VideoFeedSource.following();
    }
    if (saved == FeedMode.latest.name) {
      return const VideoFeedSource.newVideos();
    }
    if (saved == FeedMode.forYou.name) {
      return const VideoFeedSource.forYou();
    }
    if (saved == FeedMode.classic.name) {
      return const VideoFeedSource.classic();
    }
    return null;
  }

  /// Writes [source] to the scoped key and clears the legacy global key for
  /// authenticated sessions.
  Future<void> persist(VideoFeedSource source) =>
      _coordinator._persist(source.persistenceValue, _owner);

  Future<_ProvisionalFeedModeWrite> _prepare(VideoFeedSource source) =>
      _coordinator._prepare(source.persistenceValue, _owner);
}
