// ABOUTME: State for AddPeopleToListCubit backing the add-people picker.
// ABOUTME: Holds candidates and the search query; derives the filtered
// ABOUTME: visibleCandidates list for the UI.

import 'package:equatable/equatable.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';

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
    this.query = '',
    this.candidates = const [],
  });

  /// Lifecycle status driving UI reactions.
  final AddPeopleToListStatus status;

  /// Current search-input text. Normalised trimming / casing happens in
  /// [visibleCandidates] at read time.
  final String query;

  /// Full deterministic list of candidates, already sorted by relationship
  /// (mutual first, following-only, follower-only) and then by display name
  /// / pubkey.
  final List<PeopleListCandidate> candidates;

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
    String? query,
    List<PeopleListCandidate>? candidates,
  }) {
    return AddPeopleToListState(
      status: status ?? this.status,
      query: query ?? this.query,
      candidates: candidates ?? this.candidates,
    );
  }

  @override
  List<Object?> get props => [status, query, candidates];
}
