// ABOUTME: Reads/writes the persisted home-feed source (a FeedMode or curated
// ABOUTME: list selection), account-scoped, with conservative migration off the
// ABOUTME: legacy global key. Extracted from VideoFeedBloc (epic #4339).

part of 'video_feed_bloc.dart';

/// Legacy SharedPreferences key for persisting the selected feed mode.
///
/// New authenticated sessions use a pubkey-scoped key so switching accounts
/// cannot carry a previous account's Following/list selection into a newly
/// imported key with a different social graph.
const String _legacyFeedModeKey = legacyHomeFeedModeKey;

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
    if (!_coordinator.matches(
      sharedPreferences: sharedPreferences,
      userPubkey: userPubkey,
    )) {
      throw ArgumentError(
        'The persistence coordinator must match the account and preferences.',
      );
    }
    _lease = _coordinator.claim();
  }

  final SharedPreferences? _sharedPreferences;
  final String? _userPubkey;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;
  final FeedModePersistenceCoordinator _coordinator;
  late final FeedModePersistenceLease _lease;

  /// Account-scoped key the selected source is stored under.
  String get key => _coordinator.key;

  String? get _savedScopedValue => _lease.savedValue;

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
      _lease.persist(source.persistenceValue);

  Future<ProvisionalFeedModeWrite> _prepare(VideoFeedSource source) =>
      _lease.prepare(source.persistenceValue);

  void _release() => _lease.release();
}
