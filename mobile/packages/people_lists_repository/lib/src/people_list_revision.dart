// ABOUTME: Shared NIP-01 ordering for people-list relay and cache reads.
// ABOUTME: Newer timestamps win; equal timestamps prefer the lower event id.

import 'package:models/models.dart';

/// Whether [candidate] supersedes [selected] under NIP-01 ordering.
/// Missing event ids leave an equal-timestamp revision unchanged.
bool peopleListRevisionSupersedes(UserList candidate, UserList selected) {
  if (candidate.updatedAt != selected.updatedAt) {
    return candidate.updatedAt.isAfter(selected.updatedAt);
  }
  final candidateId = candidate.nostrEventId;
  final selectedId = selected.nostrEventId;
  if (candidateId == null || selectedId == null) return false;
  return candidateId.compareTo(selectedId) < 0;
}
