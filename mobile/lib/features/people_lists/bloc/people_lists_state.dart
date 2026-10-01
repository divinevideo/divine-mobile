// ABOUTME: State for PeopleListsBloc tracking owner-scoped people lists.
// ABOUTME: Holds status, owner pubkey, lists, reverse index, pending mutations.

part of 'people_lists_bloc.dart';

/// Status of the global people-lists bloc.
enum PeopleListsStatus {
  /// No owner pubkey has been observed yet.
  initial,

  /// Loading lists for the current owner.
  loading,

  /// Lists have been loaded (or are streaming) for the current owner.
  ready,

  /// A mutation is in flight.
  submitting,

  /// A recent operation failed. The bloc recovers to [ready] once all
  /// pending mutations drain.
  failure,
}

/// Whether the owner relay read established absence conclusively.
enum PeopleListsOwnerReadStatus { pending, settled, failed }

/// What came of one [PeopleListsPicksApplied]: how many of its writes a
/// relay refused and the bloc rolled back.
///
/// Carries a [sequence] that grows with every outcome, so a sheet that
/// applied picks can reject stale outcomes. [requestId] distinguishes two
/// overlapping visits applying picks for the same person.
class PeopleListsPicksOutcome extends Equatable {
  /// Creates an outcome record.
  const PeopleListsPicksOutcome({
    required this.requestId,
    required this.sequence,
    required this.pubkey,
    required this.refused,
  });

  /// Identifies the exact batch this outcome completes.
  final Object requestId;

  /// Grows by one per outcome, starting at 1.
  final int sequence;

  /// The full hex pubkey the picks were about. Never truncated.
  final String pubkey;

  /// How many of the picks a relay refused.
  final int refused;

  @override
  List<Object?> get props => [requestId, sequence, pubkey, refused];
}

/// State of [PeopleListsBloc].
///
/// Holds the authenticated owner's editable people lists, a reverse index
/// from pubkey → list IDs for O(1) membership checks, and in-flight
/// [PeopleListsMutation] records so the UI can render optimistic changes.
///
/// Per `rules/state_management.md`, no error text or exception objects are
/// stored here. Errors are reported via `addError` on the bloc and surfaced
/// through [PeopleListsStatus.failure]; translated strings live in the UI.
class PeopleListsState extends Equatable {
  /// Creates a new state value.
  const PeopleListsState({
    this.status = PeopleListsStatus.initial,
    this.ownerPubkey,
    this.lists = const [],
    this.listIdsByPubkey = const {},
    this.pendingMutations = const {},
    this.lastSubmittedEventId,
    this.enabled = true,
    this.ownerReadStatus = PeopleListsOwnerReadStatus.settled,
    this.lastPicksOutcome,
  });

  /// Current status of the bloc.
  final PeopleListsStatus status;

  /// Full hex pubkey of the authenticated owner, or `null` when
  /// unauthenticated. Never truncated.
  final String? ownerPubkey;

  /// Editable people lists owned by [ownerPubkey], latest snapshot.
  final List<UserList> lists;

  /// Settlement of the active owner's relay read, independently of cache.
  final PeopleListsOwnerReadStatus ownerReadStatus;

  /// Whether absence can be concluded from the current owner snapshot.
  ///
  /// An initial cached snapshot alone does not establish absence: the relay
  /// read must also settle. Existing cached lists remain available during a
  /// pending or failed read. With no active owner no snapshot is expected.
  bool get listsKnown =>
      activeOwnerPubkey == null ||
      activeOwnerPubkey!.isEmpty ||
      (ownerReadStatus == PeopleListsOwnerReadStatus.settled &&
          status != PeopleListsStatus.initial &&
          status != PeopleListsStatus.loading);

  /// Reverse membership index — full pubkey → set of list IDs that
  /// currently contain that pubkey. Pubkeys are never truncated.
  final Map<String, Set<String>> listIdsByPubkey;

  /// In-flight mutations keyed by stable mutation id.
  final Map<String, PeopleListsMutation> pendingMutations;

  /// The id of the most recent event acknowledged by at least one relay.
  /// The repository waits for relay acceptance before reporting submission.
  final String? lastSubmittedEventId;

  /// Whether the curated-lists feature is currently enabled.
  ///
  /// Defaults to `true`; the bloc's `enabledStream` corrects it on the seed it
  /// receives at startup. While `false` the bloc holds no repository
  /// subscription and runs no sync — see [activeOwnerPubkey].
  final bool enabled;

  /// The outcome of the last [PeopleListsPicksApplied], if any.
  final PeopleListsPicksOutcome? lastPicksOutcome;

  /// The owner the bloc may do repository work for.
  ///
  /// [ownerPubkey] while [enabled], `null` while the feature is off. Mutation
  /// handlers read this rather than [ownerPubkey] so a disabled feature
  /// publishes nothing, reusing the unauthenticated no-op path instead of
  /// adding a second guard to each handler.
  String? get activeOwnerPubkey => enabled ? ownerPubkey : null;

  /// Creates a copy with updated fields.
  PeopleListsState copyWith({
    PeopleListsStatus? status,
    String? ownerPubkey,
    bool clearOwnerPubkey = false,
    List<UserList>? lists,
    Map<String, Set<String>>? listIdsByPubkey,
    Map<String, PeopleListsMutation>? pendingMutations,
    String? lastSubmittedEventId,
    bool clearLastSubmittedEventId = false,
    bool? enabled,
    PeopleListsOwnerReadStatus? ownerReadStatus,
    PeopleListsPicksOutcome? lastPicksOutcome,
  }) {
    return PeopleListsState(
      status: status ?? this.status,
      ownerPubkey: clearOwnerPubkey ? null : (ownerPubkey ?? this.ownerPubkey),
      lists: lists ?? this.lists,
      listIdsByPubkey: listIdsByPubkey ?? this.listIdsByPubkey,
      pendingMutations: pendingMutations ?? this.pendingMutations,
      lastSubmittedEventId: clearLastSubmittedEventId
          ? null
          : (lastSubmittedEventId ?? this.lastSubmittedEventId),
      enabled: enabled ?? this.enabled,
      ownerReadStatus: ownerReadStatus ?? this.ownerReadStatus,
      lastPicksOutcome: lastPicksOutcome ?? this.lastPicksOutcome,
    );
  }

  @override
  List<Object?> get props => [
    status,
    ownerPubkey,
    lists,
    listIdsByPubkey,
    pendingMutations,
    lastSubmittedEventId,
    enabled,
    ownerReadStatus,
    lastPicksOutcome,
  ];
}
