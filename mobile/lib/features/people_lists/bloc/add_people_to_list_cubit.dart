// ABOUTME: Screen-scoped Cubit for the add-people-to-list picker.
// ABOUTME: Seeds candidates from FollowRepository, subscribes to following
// ABOUTME: and follower streams, and resolves profile metadata lazily.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
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
  AddPeopleToListCubit({
    required FollowRepository followRepository,
    required ProfileRepository? profileRepository,
    required List<String> existingMemberPubkeys,
  }) : _followRepository = followRepository,
       _profileRepository = profileRepository,
       _existingMembers = existingMemberPubkeys.toSet(),
       super(const AddPeopleToListState());

  final FollowRepository _followRepository;
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
    emitIfOpen(state.copyWith(status: AddPeopleToListStatus.loading));
    try {
      _candidatesByPubkey.clear();

      // 1. Seed from cached following list so candidates appear immediately.
      final initialFollowing = _followRepository.followingPubkeys;
      for (final pubkey in initialFollowing) {
        _upsertCandidate(pubkey, isFollowing: true);
      }

      // 2. Subscribe to the following stream for live updates. The stream
      // replays the current value for late subscribers (BehaviorSubject),
      // so later follow/unfollow deltas flow through the same sink.
      await _followingSub?.cancel();
      _followingSub = _followRepository.followingStream.listen(
        _applyFollowingDelta,
        onError: _onStreamError,
      );

      // 3. Subscribe to my-followers stream. watchMyFollowers() yields
      // cached data instantly (when available) and then fresh data from
      // network sources.
      await _followerSub?.cancel();
      _followerSub = _followRepository.watchMyFollowers().listen(
        _applyFollowerDelta,
        onError: _onStreamError,
      );

      // Resolve profile metadata for seeded pubkeys off the critical path.
      unawaited(_hydrateProfiles(_candidatesByPubkey.keys.toList()));

      emitIfOpen(
        state.copyWith(
          status: AddPeopleToListStatus.ready,
          candidates: _sortedCandidates(),
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(status: AddPeopleToListStatus.failure));
    }
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

  /// Re-run the loader after a prior failure.
  void retryRequested() {
    unawaited(started());
  }

  @override
  Future<void> close() async {
    await _followingSub?.cancel();
    await _followerSub?.cancel();
    return super.close();
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
            isAlreadyInList: _existingMembers.contains(pubkey),
          );
    _candidatesByPubkey[pubkey] = updated;
    return updated;
  }

  void _applyFollowingDelta(List<String> followingPubkeys) {
    final newSet = followingPubkeys.toSet();
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

    if (newlyAdded.isNotEmpty) unawaited(_hydrateProfiles(newlyAdded));

    emitIfOpen(
      state.copyWith(
        status: AddPeopleToListStatus.ready,
        candidates: _sortedCandidates(),
      ),
    );
  }

  void _applyFollowerDelta(FollowersSnapshot result) {
    final followerSet = result.pubkeys.toSet();
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

    if (newlyAdded.isNotEmpty) unawaited(_hydrateProfiles(newlyAdded));

    emitIfOpen(
      state.copyWith(
        status: AddPeopleToListStatus.ready,
        candidates: _sortedCandidates(),
      ),
    );
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
  Future<void> _hydrateProfiles(List<String> pubkeys) async {
    final repo = _profileRepository;
    if (repo == null) return;

    var changed = false;
    for (final pk in pubkeys) {
      try {
        final cached = await repo.getCachedProfile(pubkey: pk);
        if (cached != null && _applyProfile(pk, cached)) {
          changed = true;
        } else {
          unawaited(_fetchFreshAndApply(pk));
        }
      } catch (error, stackTrace) {
        addError(error, stackTrace);
      }
    }

    if (changed) {
      emitIfOpen(state.copyWith(candidates: _sortedCandidates()));
    }
  }

  Future<void> _fetchFreshAndApply(String pubkey) async {
    final repo = _profileRepository;
    if (repo == null) return;
    try {
      final profile = await repo.fetchFreshProfile(pubkey: pubkey);
      if (profile != null && _applyProfile(pubkey, profile)) {
        emitIfOpen(state.copyWith(candidates: _sortedCandidates()));
      }
    } catch (error, stackTrace) {
      // Deliberate fallback: if the fetch fails, the candidate keeps its
      // null display metadata so the UI can render a pubkey-derived
      // fallback. The failure is still surfaced via addError for logging.
      addError(error, stackTrace);
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

  /// Deterministic, stable sort used for [AddPeopleToListState.candidates].
  List<PeopleListCandidate> _sortedCandidates() {
    final list = _candidatesByPubkey.values.toList();
    list.sort(_compareCandidates);
    return List.unmodifiable(list);
  }

  static int _compareCandidates(PeopleListCandidate a, PeopleListCandidate b) {
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
