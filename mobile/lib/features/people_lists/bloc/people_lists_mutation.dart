// ABOUTME: Mutation record for in-flight PeopleListsBloc operations.
// ABOUTME: Tracks pending add/remove/create/delete keyed by stable mutation id.

part of 'people_lists_bloc.dart';

/// Kinds of mutations tracked in [PeopleListsState.pendingMutations].
enum PeopleListsMutationKind {
  /// An add-pubkey mutation targeting an existing list.
  addPubkey,

  /// A remove-pubkey mutation targeting an existing list.
  removePubkey,

  /// A list creation mutation.
  createList,

  /// A public name or description update.
  updateList,

  /// A list deletion mutation.
  deleteList,
}

/// An in-flight mutation applied optimistically to [PeopleListsState].
///
/// Kept in [PeopleListsState.pendingMutations] until the repository call
/// returns. Mutations carry the full Nostr pubkey and list identifier; IDs
/// are never truncated.
class PeopleListsMutation extends Equatable {
  /// Creates a mutation record.
  const PeopleListsMutation({
    required this.id,
    required this.kind,
    this.listId,
    this.pubkey,
  });

  /// Stable mutation identifier (unique per mutation).
  final String id;

  /// The mutation kind.
  final PeopleListsMutationKind kind;

  /// The target list's full addressable identifier, if applicable.
  final String? listId;

  /// The target pubkey (full hex), if applicable.
  final String? pubkey;

  @override
  List<Object?> get props => [id, kind, listId, pubkey];
}
