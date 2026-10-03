// ABOUTME: Events for the PeopleListsBloc.
// ABOUTME: Covers startup, owner transitions, and user-driven mutations.

part of 'people_lists_bloc.dart';

/// Base class for all [PeopleListsBloc] events.
sealed class PeopleListsEvent extends Equatable {
  const PeopleListsEvent();

  @override
  List<Object?> get props => const [];
}

/// Triggers the bloc to begin observing the owner pubkey stream.
class PeopleListsStarted extends PeopleListsEvent {
  /// Creates a startup event.
  const PeopleListsStarted();
}

/// Internal event emitted when the injected repository stream hands over a
/// new [PeopleListsRepository] instance.
///
/// The app-shell provider rebuilds its repository on every identity change and
/// the old one's `NostrClient` is disposed, so the bloc must re-point rather
/// than keep its constructor-time capture (#6480).
class PeopleListsRepositoryChanged extends PeopleListsEvent {
  /// Creates a repository-change event.
  const PeopleListsRepositoryChanged({required this.repository});

  /// The repository instance the bloc should use from now on.
  final PeopleListsRepository repository;

  @override
  List<Object?> get props => [repository];
}

/// Internal event emitted when the injected enabled stream reports that
/// `FeatureFlag.curatedLists` flipped.
///
/// The app-shell `BlocProvider` is deliberately unconditional — a conditional
/// entry changed the provider chain's shape and re-inflated the Navigator on
/// every flip (#6477) — so a bloc constructed while the flag was on outlives
/// the flag going off. This event is how it stops (#6494).
class PeopleListsEnabledChanged extends PeopleListsEvent {
  /// Creates a feature-enabled-change event.
  const PeopleListsEnabledChanged({required this.enabled});

  /// Whether the curated-lists feature is enabled from now on.
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// Internal event emitted when the owner pubkey stream changes.
///
/// Also carries the repository re-wire (see [PeopleListsOwnerChanged.rewire]).
/// Both cases are handled in this one `sequential()` bucket so the lists
/// subscription has a single writer — `sequential()` orders events only within
/// a bucket, so a second handler mutating it would interleave.
class PeopleListsOwnerChanged extends PeopleListsEvent {
  /// Creates an owner-change event.
  const PeopleListsOwnerChanged({required this.ownerPubkey}) : isRewire = false;

  /// Re-opens the lists subscription on the current repository without
  /// changing the owner.
  ///
  /// The owner is resolved from state when the event is *handled*, not when it
  /// is dispatched, so a re-wire queued behind a pending owner change picks up
  /// the settled owner instead of the one that was leaving.
  const PeopleListsOwnerChanged.rewire() : ownerPubkey = null, isRewire = true;

  /// The new owner pubkey (full hex), or `null` when unauthenticated.
  ///
  /// Always `null` for a [PeopleListsOwnerChanged.rewire]; read the owner from
  /// state instead.
  final String? ownerPubkey;

  /// Whether this is a repository re-wire rather than a real owner change.
  final bool isRewire;

  @override
  List<Object?> get props => [ownerPubkey, isRewire];
}

/// Internal event emitted whenever the repository publishes a new set of
/// lists for the active owner.
class PeopleListsRepositoryListsChanged extends PeopleListsEvent {
  /// Creates a repository-lists-changed event.
  const PeopleListsRepositoryListsChanged({
    required this.ownerPubkey,
    required this.lists,
  });

  /// The owner pubkey whose lists changed. Full hex; never truncated.
  final String ownerPubkey;

  /// The new list snapshot from the repository.
  final List<UserList> lists;

  @override
  List<Object?> get props => [ownerPubkey, lists];
}

/// Requests creation of a new people list.
class PeopleListsCreateRequested extends PeopleListsEvent {
  /// Creates a create-list request.
  const PeopleListsCreateRequested({
    required this.name,
    this.description,
    this.imageUrl,
    this.initialPubkeys = const [],
  });

  /// Display name for the new list.
  final String name;

  /// Optional description text.
  final String? description;

  /// Optional image URL.
  final String? imageUrl;

  /// Full-hex pubkeys to seed the list with.
  final List<String> initialPubkeys;

  @override
  List<Object?> get props => [name, description, imageUrl, initialPubkeys];
}

/// Requests deletion of a people list.
class PeopleListsDeleteRequested extends PeopleListsEvent {
  /// Creates a delete-list request.
  const PeopleListsDeleteRequested({required this.listId});

  /// The full addressable id of the list to delete.
  final String listId;

  @override
  List<Object?> get props => [listId];
}

/// Requests adding a pubkey to an existing list.
class PeopleListsPubkeyAddRequested extends PeopleListsEvent {
  /// Creates an add-pubkey request.
  const PeopleListsPubkeyAddRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to add. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}

/// Requests removal of a pubkey from an existing list.
class PeopleListsPubkeyRemoveRequested extends PeopleListsEvent {
  /// Creates a remove-pubkey request.
  const PeopleListsPubkeyRemoveRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to remove. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}

/// Applies the add-to-lists sheet's picks for one person in one go: adds
/// them to [addListIds] and removes them from [removeListIds], in order,
/// then records a [PeopleListsPicksOutcome] on the state saying how many
/// of those writes a relay refused.
class PeopleListsPicksApplied extends PeopleListsEvent {
  /// Creates the request.
  const PeopleListsPicksApplied({
    required this.requestId,
    required this.ownerPubkey,
    required this.pubkey,
    required this.addListIds,
    required this.removeListIds,
  }) : _session = null;

  PeopleListsPicksApplied._dispatched(
    PeopleListsPicksApplied request,
    this._session,
  ) : requestId = request.requestId,
      ownerPubkey = request.ownerPubkey,
      pubkey = request.pubkey,
      addListIds = request.addListIds,
      removeListIds = request.removeListIds;

  /// The bloc session at dispatch, before the sequential handler can wait.
  final int? _session;

  /// Identifies this batch, even when another visit picks the same lists.
  final Object requestId;

  /// The authenticated owner who submitted these picks.
  final String ownerPubkey;

  /// The full hex pubkey the picks are about. Never truncated.
  final String pubkey;

  /// Ids of the lists to add the person to.
  final Set<String> addListIds;

  /// Ids of the lists to remove the person from.
  final Set<String> removeListIds;

  @override
  List<Object?> get props => [
    requestId,
    ownerPubkey,
    pubkey,
    addListIds,
    removeListIds,
    _session,
  ];
}

/// Toggles a pubkey's membership in a list (add if absent, remove if
/// present).
class PeopleListsPubkeyToggleRequested extends PeopleListsEvent {
  /// Creates a toggle-pubkey request.
  const PeopleListsPubkeyToggleRequested({
    required this.listId,
    required this.pubkey,
  });

  /// The target list's id.
  final String listId;

  /// The full hex pubkey to toggle. Never truncated.
  final String pubkey;

  @override
  List<Object?> get props => [listId, pubkey];
}
