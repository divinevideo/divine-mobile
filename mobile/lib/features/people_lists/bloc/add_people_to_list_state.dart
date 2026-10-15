// ABOUTME: State for AddPeopleToListCubit backing the add-people picker.
// ABOUTME: Holds candidates, search query, and selection; derives a filtered
// ABOUTME: and sorted visibleCandidates list for the UI.

import 'package:equatable/equatable.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:user_ranking/user_ranking.dart';

/// Lifecycle status for the add-people picker screen.
enum AddPeopleToListStatus {
  /// No load has been attempted yet.
  initial,

  /// A load is in progress. Candidates may be empty or stale.
  loading,

  /// Candidates were loaded successfully. [AddPeopleToListState.candidates]
  /// may still be empty when the authenticated user has no following /
  /// followers.
  ready,

  /// The loader threw. The UI should surface a retry affordance.
  failure,
}

/// State emitted by [AddPeopleToListCubit].
class AddPeopleToListState extends Equatable {
  /// Creates an immutable state snapshot.
  const AddPeopleToListState({
    this.status = AddPeopleToListStatus.initial,
    this.rankingSignals = const {},
    this.candidatePositions = const {},
    this.rankingCandidatePubkeys = const {},
    this.loadRevision = 0,
    this.query = '',
    this.candidates = const [],
    this.selectedPubkeys = const {},
  });

  /// Lifecycle status driving UI reactions.
  final AddPeopleToListStatus status;

  /// Eligible local ranking snapshot for candidate presentation.
  final Map<String, UserRankingSignals> rankingSignals;

  /// First-visible positions, retained when relationship or metadata changes.
  final Map<String, int> candidatePositions;

  /// Keys submitted in the initial snapshot; successful omissions stay excluded.
  final Set<String> rankingCandidatePubkeys;

  /// Identifies the active load so obsolete asynchronous work is discarded.
  final int loadRevision;

  /// Current search-input text. Normalised trimming / casing happens in
  /// [visibleCandidates] at read time.
  final String query;

  /// Candidates in first-visible ranked order. Later arrivals append.
  final List<PeopleListCandidate> candidates;

  /// Pubkeys the user has toggled on in this session.
  ///
  /// Candidates already in the target list are not tracked here — they are
  /// surfaced via [PeopleListCandidate.isAlreadyInList] instead.
  final Set<String> selectedPubkeys;

  /// Candidates filtered by [query]. Always derived; never cached.
  ///
  /// Matches on display name (case-insensitive), handle (case-insensitive),
  /// and pubkey prefix (case-sensitive — pubkeys are lowercase hex).
  List<PeopleListCandidate> get visibleCandidates {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return candidates;

    final needle = trimmed.toLowerCase();
    return candidates.where((c) {
      final name = c.displayName?.toLowerCase();
      if (name != null && name.contains(needle)) return true;
      final handle = c.handle?.toLowerCase();
      if (handle != null && handle.contains(needle)) return true;
      if (c.pubkey.startsWith(trimmed)) return true;
      return false;
    }).toList();
  }

  /// Returns a copy with the provided fields replaced.
  AddPeopleToListState copyWith({
    AddPeopleToListStatus? status,
    Map<String, UserRankingSignals>? rankingSignals,
    Map<String, int>? candidatePositions,
    Set<String>? rankingCandidatePubkeys,
    int? loadRevision,
    String? query,
    List<PeopleListCandidate>? candidates,
    Set<String>? selectedPubkeys,
  }) {
    return AddPeopleToListState(
      status: status ?? this.status,
      rankingSignals: rankingSignals ?? this.rankingSignals,
      candidatePositions: candidatePositions ?? this.candidatePositions,
      rankingCandidatePubkeys:
          rankingCandidatePubkeys ?? this.rankingCandidatePubkeys,
      loadRevision: loadRevision ?? this.loadRevision,
      query: query ?? this.query,
      candidates: candidates ?? this.candidates,
      selectedPubkeys: selectedPubkeys ?? this.selectedPubkeys,
    );
  }

  @override
  List<Object?> get props => [
    status,
    query,
    candidates,
    selectedPubkeys,
    rankingSignals,
    candidatePositions,
    rankingCandidatePubkeys,
    loadRevision,
  ];
}
