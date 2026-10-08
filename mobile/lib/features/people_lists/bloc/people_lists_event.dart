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

/// Base for writes serialized together across all mutation types.
sealed class PeopleListsMutationRequested extends PeopleListsEvent {
  const PeopleListsMutationRequested();
}

/// Outcome belonging to one request, independently of global refresh state.
enum PeopleListsOperationResult { succeeded, failed, cancelled }

class _QueuedPeopleListsMutation extends PeopleListsEvent {
  _QueuedPeopleListsMutation(this.request, this.session, this.owner);
  final PeopleListsMutationRequested request;
  final int session;
  final String? owner;
  final completion = Completer<PeopleListsOperationResult>();
  @override
  List<Object?> get props => [completion];
}

/// Requests creation of a new people list.
class PeopleListsCreateRequested extends PeopleListsMutationRequested {
  /// Creates a create-list request.
  const PeopleListsCreateRequested({
    required this.expectedOwnerPubkey,
    required this.name,
    this.description,
    this.imageUrl,
    this.initialPubkeys = const [],
  });

  /// The account captured when the create form opened.
  final String expectedOwnerPubkey;

  /// Display name for the new list.
  final String name;

  /// Optional description text.
  final String? description;

  /// Optional image URL.
  final String? imageUrl;

  /// Full-hex pubkeys to seed the list with.
  final List<String> initialPubkeys;

  @override
  List<Object?> get props => [
    expectedOwnerPubkey,
    name,
    description,
    imageUrl,
    initialPubkeys,
  ];
}

/// Changes the public name and description of an owned list.
class PeopleListsUpdateRequested extends PeopleListsMutationRequested {
  const PeopleListsUpdateRequested({
    required this.expectedOwnerPubkey,
    required this.listId,
    required this.name,
    required this.description,
  });
  final String expectedOwnerPubkey;
  final String listId;
  final String name;
  final String description;
  @override
  List<Object?> get props => [expectedOwnerPubkey, listId, name, description];
}

/// Requests deletion of a people list.
class PeopleListsDeleteRequested extends PeopleListsMutationRequested {
  /// Creates a delete-list request.
  const PeopleListsDeleteRequested({required this.listId});

  /// The full addressable id of the list to delete.
  final String listId;

  @override
  List<Object?> get props => [listId];
}

/// Requests adding a pubkey to an existing list.
class PeopleListsPubkeyAddRequested extends PeopleListsMutationRequested {
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
class PeopleListsPubkeyRemoveRequested extends PeopleListsMutationRequested {
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

/// Toggles a pubkey's membership in a list (add if absent, remove if
/// present).
class PeopleListsPubkeyToggleRequested extends PeopleListsMutationRequested {
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

/// Retries an inconclusive owner read without clearing cached lists.
class PeopleListsOwnerSyncRequested extends PeopleListsEvent {
  const PeopleListsOwnerSyncRequested();
}

/// Carries the result of a particular repository/account read session.
class PeopleListsOwnerSyncCompleted extends PeopleListsEvent {
  const PeopleListsOwnerSyncCompleted({
    required this.session,
    required this.failed,
  });
  final int session;
  final bool failed;
  @override
  List<Object?> get props => [session, failed];
}
