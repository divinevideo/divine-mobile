// ABOUTME: Screen-scoped Cubit for the add-people-to-list picker.
// ABOUTME: Seeds candidates from FollowRepository, subscribes to following
// ABOUTME: and follower streams, and resolves profile metadata lazily.

import 'dart:async';
import 'dart:collection';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/follow_list_ranking.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:user_ranking/user_ranking.dart';

/// Cubit backing the full-screen add-people picker for a people list.
///
/// Responsibilities:
///   * seed candidates from [FollowRepository.followingPubkeys];
///   * subscribe to [FollowRepository.followingStream] and
///     [FollowRepository.watchMyFollowers] for live relationship updates;
///   * merge both sides into a single map keyed by full-hex pubkey;
///   * resolve [ProfileRepository] metadata: initial rows show at once and
///     hydrate in the background, while later arrivals are held back until a
///     cached or fresh profile is ready, with at most four fresh fetches at a
///     time.
class AddPeopleToListCubit extends Cubit<AddPeopleToListState>
    with CloseGuardedEmit<AddPeopleToListState> {
  /// Creates a new cubit scoped to a single picker instance.
  ///
  /// Membership stays in `PeopleListsBloc`, so each row reflects confirmed
  /// additions and removals without retaining a stale membership snapshot.
  /// [initialState] may carry a snapshot over only for the same owner and
  /// list, when constructor-injected dependencies are refreshed.
  AddPeopleToListCubit({
    required FollowRepository followRepository,
    required UserRankingSignalsLoader rankingSignalsLoader,
    required ProfileRepository? profileRepository,
    AddPeopleToListState initialState = const AddPeopleToListState(),
  }) : _followRepository = followRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _profileRepository = profileRepository,
       super(
         _eligibleSnapshot(
           initialState,
           rankingSignalsLoader,
         ),
       ) {
    _candidatesByPubkey.addEntries(
      state.candidates.map(
        (candidate) => MapEntry(candidate.pubkey, candidate),
      ),
    );
  }

  /// Retained snapshots must come from the same owner and list.
  /// Revalidate before the replacement Cubit can expose any retained row.
  static AddPeopleToListState _eligibleSnapshot(
    AddPeopleToListState snapshot,
    UserRankingSignalsLoader loader,
  ) {
    final candidates = snapshot.candidates
        .where((candidate) => loader.isEligible(candidate.pubkey))
        .toList();
    final keys = candidates.map((candidate) => candidate.pubkey).toSet();
    return snapshot.copyWith(
      candidates: List.unmodifiable(candidates),
      rankingSignals: Map.unmodifiable({
        for (final entry in snapshot.rankingSignals.entries)
          if (keys.contains(entry.key)) entry.key: entry.value,
      }),
      candidatePositions: Map.unmodifiable(snapshot.candidatePositions),
    );
  }

  final FollowRepository _followRepository;
  final UserRankingSignalsLoader _rankingSignalsLoader;
  final ProfileRepository? _profileRepository;

  StreamSubscription<List<String>>? _followingSub;
  StreamSubscription<FollowersSnapshot>? _followerSub;

  /// Candidate map keyed by full-hex pubkey. Holds the canonical relationship
  /// flags + resolved profile metadata; `state.candidates` is derived from
  /// this map at every emit so sort order and filter inputs stay in sync.
  final Map<String, PeopleListCandidate> _candidatesByPubkey = {};

  // New relationship rows get permanent positions only once their local
  // signals and display metadata are ready; rows that need a fresh profile
  // fetch are appended in the order those fetches finish.
  final Set<String> _pendingCandidates = {};
  final _profileHydrationQueue =
      Queue<({String pubkey, int revision, UserRankingSignals signals})>();
  int _activeProfileHydrations = 0;
  static const _maxConcurrentProfileHydrations = 4;

  /// Load candidates. Emits [AddPeopleToListStatus.ready] on success and
  /// [AddPeopleToListStatus.failure] on error. Keeps ready candidates visible
  /// while refreshing the live subscriptions.
  Future<void> started() async {
    if (isClosed) return;
    final snapshot = state;
    _pendingCandidates.clear();
    _profileHydrationQueue.clear();
    final revision = snapshot.loadRevision + 1;
    emitIfOpen(
      state.copyWith(
        status: snapshot.status == AddPeopleToListStatus.ready ||
                snapshot.candidatePositions.isNotEmpty
            ? AddPeopleToListStatus.ready
            : AddPeopleToListStatus.loading,
        loadRevision: revision,
      ),
    );
    try {
      // Cancellation may wait for a retired network fetch. The load revision
      // already fences its callbacks, so refresh can attach a new source now.
      unawaited(_followingSub?.cancel().catchError(_onStreamError));
      unawaited(_followerSub?.cancel().catchError(_onStreamError));
      _followingSub = null;
      _followerSub = null;
      // A set: followingPubkeys is a list, and it is probed once per row below.
      final initialFollowing = _followRepository.followingPubkeys.toSet();
      final initialPubkeys = {
        ...initialFollowing,
        ...snapshot.candidates.map((candidate) => candidate.pubkey),
      }.toList();
      final signals = await loadFollowListRankingSignals(
        pubkeys: initialPubkeys,
        loader: _rankingSignalsLoader,
        logName: 'AddPeopleToListCubit',
        onError: (error, stackTrace) =>
            _reportRankingError(error, stackTrace, revision),
      );
      if (!_isCurrent(revision)) return;
      final names = await loadFollowListRankingNames(
        pubkeys: signals.keys,
        loader: _rankingSignalsLoader,
        logName: 'AddPeopleToListCubit',
        onError: (error, stackTrace) =>
            _reportRankingError(error, stackTrace, revision),
      );
      if (!_isCurrent(revision)) return;
      final ranked = rankFollowListSnapshot(
        pubkeys: initialPubkeys,
        signals: signals,
        names: names,
        isEligible: _rankingSignalsLoader.isEligible,
        isSmartOrderReady: snapshot.candidatePositions.isNotEmpty,
        previousSmartOrder:
            (snapshot.candidatePositions.entries.toList()
                  ..sort((a, b) => a.value.compareTo(b.value)))
                .map((entry) => entry.key)
                .toList(),
        now: DateTime.now(),
      );
      // Keep canonical rows live while refreshing so later relationship and
      // profile updates are retained throughout a dependency replacement.
      _candidatesByPubkey.removeWhere(
        (key, _) => !ranked.eligible.contains(key),
      );
      for (final pubkey in ranked.smartOrder) {
        _upsertCandidate(
          pubkey,
          isFollowing: initialFollowing.contains(pubkey),
        );
      }
      final positions = Map<String, int>.of(snapshot.candidatePositions);
      for (final key in ranked.smartOrder) {
        positions.putIfAbsent(key, () => positions.length);
      }
      emitIfOpen(
        state.copyWith(
          rankingSignals: Map.unmodifiable(signals),
          rankingCandidatePubkeys: Set.unmodifiable(initialPubkeys),
          candidatePositions: Map.unmodifiable(positions),
        ),
      );
      _followingSub = _followRepository.followingStream.listen(
        (pubkeys) {
          if (_isCurrent(revision)) _applyFollowingDelta(pubkeys);
        },
        onError: _onStreamError,
      );
      _followerSub = _followRepository.watchMyFollowers().listen(
        (snapshot) {
          if (_isCurrent(revision)) _applyFollowerDelta(snapshot);
        },
        onError: _onStreamError,
      );
      _emitCandidates();
      _rankingSignalsLoader.refreshInBackground(
        state.candidates.map((candidate) => candidate.pubkey).toList(),
      );
      unawaited(_hydrateProfiles(_candidatesByPubkey.keys.toList(), revision));
    } catch (error, stackTrace) {
      if (!_isCurrent(revision)) return;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: AddPeopleToListStatus.failure));
    }
  }

  bool _isCurrent(int revision) => !isClosed && state.loadRevision == revision;

  void _reportRankingError(Object error, StackTrace stackTrace, int revision) {
    if (!_isCurrent(revision)) return;
    addError(
      asReportableError(error, context: 'AddPeopleToListCubit.ranking') ??
          error,
      stackTrace,
    );
  }

  /// Update the current search query.
  void queryChanged(String query) {
    if (query == state.query) return;
    emitIfOpen(state.copyWith(query: query));
  }

  /// Re-run the loader after a prior failure.
  void retryRequested() {
    unawaited(started());
  }

  @override
  Future<void> close() {
    // Mark the Cubit closed before subscription cancellation can yield, so a
    // replacement never competes with pending profile/ranking work.
    final closing = super.close();
    _profileHydrationQueue.clear();
    unawaited(_followingSub?.cancel().catchError(_onStreamError));
    unawaited(_followerSub?.cancel().catchError(_onStreamError));
    return closing;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────────

  PeopleListCandidate _upsertCandidate(
    String pubkey, {
    bool? isFollowing,
    bool? isFollower,
  }) {
    final existing = _candidatesByPubkey[pubkey];
    final updated = existing != null
        ? existing.copyWith(
            isFollowing: isFollowing ?? existing.isFollowing,
            isFollower: isFollower ?? existing.isFollower,
          )
        : PeopleListCandidate(
            pubkey: pubkey,
            isFollowing: isFollowing ?? false,
            isFollower: isFollower ?? false,
          );
    _candidatesByPubkey[pubkey] = updated;
    return updated;
  }

  void _applyFollowingDelta(List<String> followingPubkeys) {
    final newSet = followingPubkeys.where(_isEligibleCandidate).toSet();
    final newlyAdded = <String>[];

    // Set isFollowing=true for everyone in the new set; add missing
    // candidates as needed.
    for (final pk in newSet) {
      final existing = _candidatesByPubkey[pk];
      if (existing == null) newlyAdded.add(pk);
      _upsertCandidate(pk, isFollowing: true);
    }

    // Clear isFollowing for anyone who dropped out of the set.
    for (final pk in _candidatesByPubkey.keys.toList()) {
      if (!newSet.contains(pk) && _candidatesByPubkey[pk]!.isFollowing) {
        _upsertCandidate(pk, isFollowing: false);
      }
    }

    if (newlyAdded.isNotEmpty) {
      _pendingCandidates.addAll(newlyAdded);
      unawaited(_prepareNewCandidates(newlyAdded, state.loadRevision));
    }

    _emitCandidates();
  }

  void _applyFollowerDelta(FollowersSnapshot result) {
    final followerSet = result.pubkeys.where(_isEligibleCandidate).toSet();
    final newlyAdded = <String>[];

    for (final pk in followerSet) {
      final existing = _candidatesByPubkey[pk];
      if (existing == null) newlyAdded.add(pk);
      _upsertCandidate(pk, isFollower: true);
    }

    for (final pk in _candidatesByPubkey.keys.toList()) {
      if (!followerSet.contains(pk) && _candidatesByPubkey[pk]!.isFollower) {
        _upsertCandidate(pk, isFollower: false);
      }
    }

    if (newlyAdded.isNotEmpty) {
      _pendingCandidates.addAll(newlyAdded);
      unawaited(_prepareNewCandidates(newlyAdded, state.loadRevision));
    }

    _emitCandidates();
  }

  Future<void> _prepareNewCandidates(List<String> pubkeys, int revision) async {
    final signals = await loadFollowListRankingSignals(
      pubkeys: pubkeys,
      loader: _rankingSignalsLoader,
      logName: 'AddPeopleToListCubit',
      onError: (error, stackTrace) =>
          _reportRankingError(error, stackTrace, revision),
    );
    if (!_isCurrent(revision)) return;
    final repo = _profileRepository;
    if (repo == null) {
      _publishPreparedCandidates(pubkeys, signals);
      return;
    }
    final cachedByKey = <String, UserProfile>{};
    try {
      final cached = await repo.getCachedProfiles(pubkeys: pubkeys);
      if (!_isCurrent(revision)) return;
      cachedByKey.addEntries(
        cached.map((profile) => MapEntry(profile.pubkey, profile)),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(revision)) return;
      addError(error, stackTrace);
    }
    final ready = <String>[];
    for (final key in pubkeys) {
      if (!signals.containsKey(key) || !_rankingSignalsLoader.isEligible(key)) {
        ready.add(key);
      } else if (cachedByKey[key] case final profile?) {
        _applyProfile(key, profile);
        ready.add(key);
      } else {
        _profileHydrationQueue.add((
          pubkey: key,
          revision: revision,
          signals: signals[key]!,
        ));
      }
    }
    // Rank available names together now; a slow network miss cannot gate them.
    _publishPreparedCandidates(ready, signals);
    _drainProfileHydrationQueue();
  }

  void _drainProfileHydrationQueue() {
    while (_activeProfileHydrations < _maxConcurrentProfileHydrations &&
        _profileHydrationQueue.isNotEmpty) {
      final entry = _profileHydrationQueue.removeFirst();
      if (!_isCurrent(entry.revision)) continue;
      _activeProfileHydrations++;
      unawaited(_hydrateQueuedProfile(entry));
    }
  }

  Future<void> _hydrateQueuedProfile(
    ({String pubkey, int revision, UserRankingSignals signals}) entry,
  ) async {
    try {
      await _fetchFreshAndApply(entry.pubkey, entry.revision);
      if (!_isCurrent(entry.revision)) return;
      // Each completed miss appends after rows already visible. Its fallback
      // position is assigned only after the profile attempt has finished.
      _publishPreparedCandidates([entry.pubkey], {entry.pubkey: entry.signals});
    } finally {
      _activeProfileHydrations--;
      _drainProfileHydrationQueue();
    }
  }

  void _publishPreparedCandidates(
    List<String> pubkeys,
    Map<String, UserRankingSignals> signals,
  ) {
    final keys = pubkeys.toSet();
    final order = rankUsers(
      signals.values.where(
        (signal) =>
            keys.contains(signal.pubkey) &&
            _rankingSignalsLoader.isEligible(signal.pubkey),
      ),
      now: DateTime.now(),
      nameOf: (key) {
        final name = _candidatesByPubkey[key]?.displayName?.trim();
        return name == null || name.isEmpty ? key : name;
      },
    );
    final ordered = order.toSet();
    for (final key in pubkeys) {
      _pendingCandidates.remove(key);
      if (!ordered.contains(key)) _candidatesByPubkey.remove(key);
    }
    final positions = Map<String, int>.of(state.candidatePositions);
    for (final key in order) {
      positions.putIfAbsent(key, () => positions.length);
    }
    emitIfOpen(
      state.copyWith(
        rankingSignals: Map.unmodifiable({
          ...state.rankingSignals,
          for (final key in keys) key: ?signals[key],
        }),
        rankingCandidatePubkeys: Set.unmodifiable({
          ...state.rankingCandidatePubkeys,
          ...pubkeys,
        }),
        candidatePositions: Map.unmodifiable(positions),
      ),
    );
    _emitCandidates();
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    // Stream-level errors are logged but do not tear down the ready state
    // — the seed from followingPubkeys is still valid for selection.
    addError(error, stackTrace);
  }

  /// Hydrate profile metadata for [pubkeys] without blocking the UI.
  ///
  /// Cached profiles are applied synchronously. Missing profiles trigger
  /// a background [ProfileRepository.fetchFreshProfile] — when that
  /// completes (or fails), the candidate row is updated and a new state
  /// is emitted.
  Future<void> _hydrateProfiles(List<String> pubkeys, int revision) async {
    final repo = _profileRepository;
    if (repo == null) return;

    var changed = false;
    for (final pk in pubkeys) {
      try {
        final cached = await repo.getCachedProfile(pubkey: pk);
        if (!_isCurrent(revision)) return;
        if (cached != null && _applyProfile(pk, cached)) {
          changed = true;
        } else {
          unawaited(_fetchFreshAndApply(pk, revision));
        }
      } catch (error, stackTrace) {
        if (!_isCurrent(revision)) return;
        addError(error, stackTrace);
      }
    }

    if (changed && _isCurrent(revision)) {
      emitIfOpen(state.copyWith(candidates: _sortedCandidates()));
    }
  }

  Future<void> _fetchFreshAndApply(String pubkey, int revision) async {
    final repo = _profileRepository;
    if (repo == null) return;
    try {
      final profile = await repo.fetchFreshProfile(pubkey: pubkey);
      if (!_isCurrent(revision)) return;
      if (profile != null && _applyProfile(pubkey, profile)) {
        emitIfOpen(state.copyWith(candidates: _sortedCandidates()));
      }
    } catch (error, stackTrace) {
      // Deliberate fallback: if the fetch fails, the candidate keeps its
      // null display metadata so the UI can render a pubkey-derived
      // fallback. The failure is still surfaced via addError for logging.
      if (_isCurrent(revision)) addError(error, stackTrace);
    }
  }

  /// Apply profile metadata to the candidate. Returns true iff anything
  /// changed.
  bool _applyProfile(String pubkey, UserProfile profile) {
    final existing = _candidatesByPubkey[pubkey];
    if (existing == null) return false;

    final newDisplayName = profile.bestDisplayName;
    final rawHandle = profile.handle;
    final newHandle = rawHandle.isEmpty ? null : rawHandle;
    final newAvatarUrl = profile.picture;

    if (existing.displayName == newDisplayName &&
        existing.handle == newHandle &&
        existing.avatarUrl == newAvatarUrl) {
      return false;
    }

    _candidatesByPubkey[pubkey] = existing.copyWith(
      displayName: newDisplayName,
      handle: newHandle,
      avatarUrl: newAvatarUrl,
    );
    return true;
  }

  bool _isEligibleCandidate(String key) =>
      _rankingSignalsLoader.isEligible(key) &&
      (!state.rankingCandidatePubkeys.contains(key) ||
          state.rankingSignals.containsKey(key));

  /// Deterministic, stable sort used for [AddPeopleToListState.candidates].
  List<PeopleListCandidate> _sortedCandidates() {
    final list = _candidatesByPubkey.values
        .where(
          (candidate) =>
              !_pendingCandidates.contains(candidate.pubkey) &&
              _isEligibleCandidate(candidate.pubkey),
        )
        .toList();
    list.sort(_compareCandidates);
    return List.unmodifiable(list);
  }

  void _emitCandidates() {
    final candidates = _sortedCandidates();
    final positions = Map<String, int>.of(state.candidatePositions);
    for (final candidate in candidates) {
      positions.putIfAbsent(candidate.pubkey, () => positions.length);
    }
    emitIfOpen(
      state.copyWith(
        status: AddPeopleToListStatus.ready,
        candidates: candidates,
        candidatePositions: Map.unmodifiable(positions),
      ),
    );
  }

  int _compareCandidates(PeopleListCandidate a, PeopleListCandidate b) {
    final positionA = state.candidatePositions[a.pubkey];
    final positionB = state.candidatePositions[b.pubkey];
    if (positionA != null || positionB != null) {
      if (positionA == null) return 1;
      if (positionB == null) return -1;
      return positionA.compareTo(positionB);
    }
    final rankA = _relationshipRank(a);
    final rankB = _relationshipRank(b);
    if (rankA != rankB) return rankA.compareTo(rankB);

    final nameA = (a.displayName ?? '').toLowerCase();
    final nameB = (b.displayName ?? '').toLowerCase();
    if (nameA != nameB) return nameA.compareTo(nameB);

    return a.pubkey.compareTo(b.pubkey);
  }

  static int _relationshipRank(PeopleListCandidate candidate) {
    if (candidate.isMutual) return 0;
    if (candidate.isFollowing) return 1;
    if (candidate.isFollower) return 2;
    return 3;
  }
}
