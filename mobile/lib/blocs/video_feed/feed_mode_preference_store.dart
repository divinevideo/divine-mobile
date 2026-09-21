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

/// Persists and restores the selected [VideoFeedSource] for [VideoFeedBloc].
class FeedModePreferenceStore {
  FeedModePreferenceStore({
    required SharedPreferences? sharedPreferences,
    required String? userPubkey,
    required FollowRepository followRepository,
    required CuratedListRepository curatedListRepository,
  }) : _sharedPreferences = sharedPreferences,
       _userPubkey = userPubkey,
       _followRepository = followRepository,
       _curatedListRepository = curatedListRepository;

  final SharedPreferences? _sharedPreferences;
  final String? _userPubkey;
  final FollowRepository _followRepository;
  final CuratedListRepository _curatedListRepository;

  /// Account-scoped key the selected source is stored under.
  String get key => _userPubkey == null
      ? _legacyFeedModeKey
      : '${_legacyFeedModeKey}_$_userPubkey';

  /// The persisted source, or [VideoFeedSource.fromMode] of [fallbackMode] when
  /// nothing is stored.
  ///
  /// A stored people list is restored only while it is still among
  /// [followedPeopleLists]; otherwise the feed falls back to For You, as it
  /// does for a curated list that is no longer subscribed.
  VideoFeedSource restoreSource(
    FeedMode fallbackMode, {
    List<PeopleListSearchResult> followedPeopleLists = const [],
  }) {
    final saved = savedValue();
    if (saved == null) {
      return VideoFeedSource.fromMode(fallbackMode);
    }
    return sourceFromValue(saved, followedPeopleLists: followedPeopleLists) ??
        const VideoFeedSource.forYou();
  }

  /// The stored persistence value for the active account, migrating a legacy
  /// global value conservatively when safe.
  String? savedValue() {
    final prefs = _sharedPreferences;
    if (prefs == null) return null;

    final scoped = prefs.getString(key);
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
    // A people list never resolves here: the legacy key predates them and
    // [sourceFromValue] is given no followed lists to match against.
    if (migratedSource.type == VideoFeedSourceType.subscribedList) {
      return null;
    }

    unawaited(persist(migratedSource));
    return migratedSource.persistenceValue;
  }

  /// Resolves a persisted value to a [VideoFeedSource], or `null` when unknown.
  VideoFeedSource? sourceFromValue(
    String saved, {
    List<PeopleListSearchResult> followedPeopleLists = const [],
  }) {
    if (saved.startsWith(VideoFeedSource.peopleListPersistencePrefix)) {
      for (final followed in followedPeopleLists) {
        final source = VideoFeedSource.peopleList(
          listId: followed.list.id,
          listName: followed.list.name,
          listOwnerPubkey: followed.ownerPubkey,
        );
        if (source.persistenceValue == saved) return source;
      }
      return null;
    }
    if (saved.startsWith('list:')) {
      final listId = saved.substring('list:'.length);
      final list = _curatedListRepository.getListById(listId);
      if (list != null) {
        return VideoFeedSource.subscribedList(
          listId: list.id,
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
  Future<void> persist(VideoFeedSource source) async {
    final prefs = _sharedPreferences;
    if (prefs == null) return;
    await prefs.setString(key, source.persistenceValue);
    if (_userPubkey != null) {
      await prefs.remove(_legacyFeedModeKey);
    }
  }
}
