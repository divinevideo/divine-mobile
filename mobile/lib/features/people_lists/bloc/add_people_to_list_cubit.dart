// ABOUTME: Screen-scoped Cubit for the add-people-to-list picker.
// ABOUTME: Seeds candidates from FollowRepository, subscribes to following
// ABOUTME: and follower streams, and resolves profile metadata lazily.

import 'dart:async';

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

/// Cubit backing the full-screen add-people picker for a people list.
///
/// Responsibilities:
///   * seed candidates from [FollowRepository.followingPubkeys];
///   * subscribe to [FollowRepository.followingStream] and
///     [FollowRepository.watchMyFollowers] for live relationship updates;
///   * merge both sides into a single map keyed by full-hex pubkey;
///   * mark candidates whose pubkey appears in [existingMemberPubkeys] as
///     [PeopleListCandidate.isAlreadyInList] so the UI can render them
///     pre-checked and disabled;
///   * resolve [ProfileRepository] metadata for each candidate without
///     blocking the picker — cached profiles are used when present, and
///     a fresh fetch is fired-and-forgotten for the rest.
class AddPeopleToListCubit extends Cubit<AddPeopleToListState>
    with CloseGuardedEmit<AddPeopleToListState> {
  /// Creates a new cubit scoped to a single picker instance.
  ///
  /// [existingMemberPubkeys] should contain the full-hex pubkeys already in
  /// the target list. Pass an empty list for a fresh list.
  /// [initialState] may transfer a snapshot only within the same owner, list,
  /// and follow source when constructor-injected dependencies are refreshed.
  AddPeopleToListCubit({
    required FollowRepository followRepository,
    required UserRankingSignalsLoader rankingSignalsLoader,
    required ProfileRepository? profileRepository,
    required List<String> existingMemberPubkeys,
    AddPeopleToListState initialState = const AddPeopleToListState(),
  }) : _followRepository = followRepository,
       _rankingSignalsLoader = rankingSignalsLoader,
       _profileRepository = profileRepository,
       _existingMembers = existingMemberPubkeys.toSet(),
       super(
         _eligibleSnapshot(
           initialState,
           rankingSignalsLoader,
           existingMemberPubkeys,
         ),
       ) {
    _candidatesByPubkey.addEntries(
      state.candidates.map(
        (candidate) => MapEntry(candidate.pubkey, candidate),
      ),
    );
  }

  /// Retained snapshots must come from the same owner, list, and follow source.
  /// Revalidate before the replacement Cubit can expose any retained row.
  static AddPeopleToListState _eligibleSnapshot(
    AddPeopleToListState snapshot,
    UserRankingSignalsLoader loader,
    List<String> existingMembers,
  ) {
    final candidates = snapshot.candidates
        .where((candidate) => loader.isEligible(candidate.pubkey))
        .map(
          (candidate) => candidate.copyWith(
            isAlreadyInList:
                candidate.isAlreadyInList ||
                existingMembers.contains(candidate.pubkey),
          ),
        )
        .toList();
    final keys = candidates.map((candidate) => candidate.pubkey).toSet();
    return snapshot.copyWith(
      candidates: List.unmodifiable(candidates),
      selectedPubkeys: Set.unmodifiable(
        snapshot.selectedPubkeys.where(keys.contains),
      ),
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
  final Set<String> _existingMembers;

  StreamSubscription<List<String>>? _followingSub;
  StreamSubscription<FollowersSnapshot>? _followerSub;

  /// Candidate map keyed by full-hex pubkey. Holds the canonical relationship
  /// flags + resolved profile metadata; `state.candidates` is derived from
  /// this map at every emit so sort order and filter inputs stay in sync.
  final Map<String, PeopleListCandidate> _candidatesByPubkey = {};

  /// Load candidates. Emits [AddPeopleToListStatus.ready] on success and
  /// [AddPeopleToListStatus.failure] on error.
  Future<void> started() async {
    if (isClosed) return;
    final snapshot = state;
    final revision = snapshot.loadRevision + 1;
    emitIfOpen(
      state.copyWith(
        status: snapshot.candidatePositions.isEmpty
            ? AddPeopleToListStatus.loading
            : AddPeopleToListStatus.ready,
        loadRevision: revision,
      ),
    );
    try {
      await _followingSub?.cancel();
      if (!_isCurrent(revision)) return;
      await _followerSub?.cancel();
      if (!_isCurrent(revision)) return;
      final initialFollowing = _followRepository.followingPubkeys;
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
      // Keep canonical rows live while refreshing; confirmation callbacks may
      // have updated them since the initial snapshot was captured.
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

  /// Toggle whether [pubkey] is selected for batch-add.
  ///
  /// Candidates already in the list
  /// ([PeopleListCandidate.isAlreadyInList]) still toggle here, but the
  /// view layer is expected to filter them out.
  void candidateToggled(String pubkey) {
    final next = Set<String>.from(state.selectedPubkeys);
    if (!next.add(pubkey)) {
      next.remove(pubkey);
    }
    emitIfOpen(state.copyWith(selectedPubkeys: next));
  }

  /// Clear only members confirmed by the repository; failed choices stay selected.
  void additionsConfirmed(Set<String> pubkeys) {
    _existingMembers.addAll(pubkeys);
    for (final pubkey in pubkeys) {
      final candidate = _candidatesByPubkey[pubkey];
      if (candidate != null) {
        _candidatesByPubkey[pubkey] = candidate.copyWith(isAlreadyInList: true);
      }
    }
    emitIfOpen(
      state.copyWith(
        selectedPubkeys: state.selectedPubkeys.difference(pubkeys),
        candidates: _sortedCandidates(),
      ),
    );
  }

  /// Re-run the loader after a prior failure.
  void retryRequested() {
    unawaited(started());
  }

  @override
  Future<void> close() async {
    // Mark the Cubit closed before subscription cancellation can yield, so a
    // replacement never competes with pending profile/ranking work.
    final closing = super.close();
    await _followingSub?.cancel();
    await _followerSub?.cancel();
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
            isAlreadyInList:
                existing.isAlreadyInList || _existingMembers.contains(pubkey),
          )
        : PeopleListCandidate(
            pubkey: pubkey,
            isFollowing: isFollowing ?? false,
            isFollower: isFollower ?? false,
            isAlreadyInList: _existingMembers.contains(pubkey),
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
      unawaited(_hydrateProfiles(newlyAdded, state.loadRevision));
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
      unawaited(_hydrateProfiles(newlyAdded, state.loadRevision));
    }

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
        .where((candidate) => _isEligibleCandidate(candidate.pubkey))
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
        selectedPubkeys: Set.unmodifiable(
          state.selectedPubkeys.where(
            (key) => candidates.any((candidate) => candidate.pubkey == key),
          ),
        ),
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
