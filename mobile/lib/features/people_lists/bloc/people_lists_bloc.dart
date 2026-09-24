// ABOUTME: Global auth-scoped BLoC that exposes the owner's people lists.
// ABOUTME: Subscribes to PeopleListsRepository and applies optimistic changes.

import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

part 'people_lists_event.dart';
part 'people_lists_mutation.dart';
part 'people_lists_state.dart';

/// Signature for a clock used by [PeopleListsBloc] to stamp optimistic
/// `updatedAt` values and mutation ids. Injected via the constructor so
/// tests can supply a deterministic clock.
typedef PeopleListsClock = DateTime Function();

/// Global, auth-scoped BLoC that owns the authenticated user's people
/// lists.
///
/// The bloc subscribes to [PeopleListsRepository.watchLists] for the
/// currently authenticated owner, rebuilds the
/// [PeopleListsState.listIdsByPubkey] reverse index whenever the snapshot
/// changes, and applies optimistic updates for user-initiated mutations
/// before the repository returns.
///
/// It depends only on the repository, an owner-pubkey stream, a repository
/// stream, and an enabled stream — it does not import other BLoCs. Owner
/// transitions cancel the prior subscription, clear pending mutations, and
/// start a new subscription plus an out-of-band sync.
///
/// ## Feature-flag lifecycle
///
/// The bloc is registered unconditionally above `MaterialApp.router`, so it
/// outlives `FeatureFlag.curatedLists` going off (#6477). While the flag is
/// off it holds no repository subscription, runs no `syncOwner`, and publishes
/// nothing — it only keeps following the owner so that turning the flag back
/// on wires up the account that is signed in *then* (#6494).
///
/// ## Failure recovery contract
///
/// A mutation that throws — or comes back unsubmitted — transitions
/// [PeopleListsState.status] to [PeopleListsStatus.failure] and reports any
/// error via `addError`. The status automatically recovers to
/// [PeopleListsStatus.ready] once all pending mutations drain without a fresh
/// failure, so the UI does not stay stuck on `failure` when subsequent
/// mutations succeed or the repository stream never re-emits.
///
/// A result that lands after the bloc tore down the state its mutation was
/// issued against writes nothing at all — see [_resultStillApplies]. A rollback
/// that does apply undoes only its own mutation rather than restoring a
/// pre-flight snapshot, so it cannot revert a repository emission that arrived
/// meanwhile — see [_emitRollback].
class PeopleListsBloc extends Bloc<PeopleListsEvent, PeopleListsState> {
  /// Creates a new bloc instance.
  ///
  /// [ownerPubkeyStream] must emit `null` when unauthenticated and the
  /// full hex pubkey of the current owner when authenticated. The caller
  /// typically adapts an auth service's state stream into this shape so
  /// the bloc has no Flutter or Riverpod dependency.
  ///
  /// [repositoryStream] must emit each successive [PeopleListsRepository]
  /// instance. Required rather than optional: this bloc is built once in the
  /// app shell while `peopleListsRepositoryProvider` rebuilds on every identity
  /// change, so a caller that omits the stream silently reverts #6480. Pass
  /// `const Stream.empty()` when the repository genuinely cannot change.
  ///
  /// [enabledStream] must emit whether `FeatureFlag.curatedLists` is enabled,
  /// seeded with its current value. Required for the same reason
  /// [repositoryStream] is: this bloc outlives the flag, so a caller that omits
  /// the stream silently reverts #6494 and leaves a disabled feature syncing in
  /// the background. Pass `Stream.value(true)` when the flag genuinely cannot
  /// change.
  ///
  /// [clock] stamps optimistic `updatedAt` values and mutation ids.
  /// Defaults to [DateTime.now] in UTC. Tests inject a fixed clock for
  /// determinism.
  PeopleListsBloc({
    required PeopleListsRepository repository,
    required Stream<String?> ownerPubkeyStream,
    required Stream<PeopleListsRepository> repositoryStream,
    required Stream<bool> enabledStream,
    String? initialOwnerPubkey,
    PeopleListsClock? clock,
  }) : _repository = repository,
       _ownerPubkeyStream = ownerPubkeyStream,
       _repositoryStream = repositoryStream,
       _enabledStream = enabledStream,
       _clock = clock ?? _defaultClock,
       super(PeopleListsState(ownerPubkey: initialOwnerPubkey)) {
    on<PeopleListsStarted>(_onStarted);
    on<PeopleListsEnabledChanged>(_onEnabledChanged, transformer: sequential());
    on<PeopleListsRepositoryChanged>(
      _onRepositoryChanged,
      transformer: sequential(),
    );
    on<PeopleListsOwnerChanged>(_onOwnerChanged, transformer: sequential());
    on<PeopleListsRepositoryListsChanged>(_onRepositoryListsChanged);
    on<PeopleListsCreateRequested>(
      _onCreateRequested,
      transformer: droppable(),
    );
    on<PeopleListsDeleteRequested>(
      _onDeleteRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyAddRequested>(
      _onPubkeyAddRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyRemoveRequested>(
      _onPubkeyRemoveRequested,
      transformer: sequential(),
    );
    on<PeopleListsPubkeyToggleRequested>(
      _onPubkeyToggleRequested,
      transformer: sequential(),
    );
  }

  static DateTime _defaultClock() => DateTime.now().toUtc();

  /// The repository the bloc currently operates on.
  ///
  /// Mutable by design. `state_management.md` bans mutable bloc fields for
  /// *state*, but an injected dependency is configuration, and this one has to
  /// be swappable: the app-shell `BlocProvider.create:` runs once while the
  /// underlying provider rebuilds on every identity change.
  /// `NotificationBadgeCubit` carries the same mutable-dependency shape for
  /// the same reason.
  PeopleListsRepository _repository;
  final Stream<String?> _ownerPubkeyStream;
  final Stream<PeopleListsRepository> _repositoryStream;
  final Stream<bool> _enabledStream;
  final PeopleListsClock _clock;

  StreamSubscription<String?>? _ownerSubscription;
  StreamSubscription<List<UserList>>? _listsSubscription;
  StreamSubscription<PeopleListsRepository>? _repositorySubscription;
  StreamSubscription<bool>? _enabledSubscription;

  @override
  Future<void> close() async {
    await _ownerSubscription?.cancel();
    await _listsSubscription?.cancel();
    await _repositorySubscription?.cancel();
    await _enabledSubscription?.cancel();
    return super.close();
  }

  // --------------------------------------------------------------------------
  // Stream wiring
  // --------------------------------------------------------------------------

  Future<void> _onStarted(
    PeopleListsStarted event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _ownerSubscription?.cancel();
    _ownerSubscription = _ownerPubkeyStream.listen(
      (ownerPubkey) =>
          addIfOpen(PeopleListsOwnerChanged(ownerPubkey: ownerPubkey)),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );

    await _repositorySubscription?.cancel();
    _repositorySubscription = _repositoryStream.listen(
      (repository) =>
          addIfOpen(PeopleListsRepositoryChanged(repository: repository)),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );

    await _enabledSubscription?.cancel();
    _enabledSubscription = _enabledStream.listen(
      (enabled) => addIfOpen(PeopleListsEnabledChanged(enabled: enabled)),
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
      },
    );

    final currentOwner = state.ownerPubkey;
    if (currentOwner != null && currentOwner.isNotEmpty) {
      addIfOpen(PeopleListsOwnerChanged(ownerPubkey: currentOwner));
    }
  }

  /// Starts or stops all people-list work when `FeatureFlag.curatedLists`
  /// flips.
  ///
  /// Turning the flag off cannot be expressed by dropping the `BlocProvider`:
  /// a conditional entry changes the app-shell provider chain's shape and
  /// re-inflates everything below it (#6477). So the already-constructed bloc
  /// has to stand down on its own — otherwise its cache subscription and
  /// `syncOwner` calls keep running for the rest of the session (#6494).
  void _onEnabledChanged(
    PeopleListsEnabledChanged event,
    Emitter<PeopleListsState> emit,
  ) {
    if (event.enabled == state.enabled) return;

    if (!event.enabled) {
      _stopWatchingLists();
      // Drops the snapshot and any pending mutations, but keeps the owner: the
      // owner stream is not seeded, so state is the only place a later flag-on
      // can learn who is signed in.
      //
      // Dropping `pendingMutations` is also what stops a mutation still in
      // flight from applying any result to state that has been torn down — see
      // [_resultStillApplies].
      emit(PeopleListsState(ownerPubkey: state.ownerPubkey, enabled: false));
      return;
    }

    final owner = state.ownerPubkey;
    if (owner == null || owner.isEmpty) {
      emit(state.copyWith(enabled: true));
      return;
    }

    emit(state.copyWith(status: PeopleListsStatus.loading, enabled: true));
    // Re-subscribing goes through the owner bucket so [_onOwnerChanged] stays
    // the only handler that opens a lists subscription.
    addIfOpen(const PeopleListsOwnerChanged.rewire());
  }

  /// Re-points the bloc at a freshly built repository.
  ///
  /// Swaps the field only, then hands the actual re-subscription to
  /// [_onOwnerChanged] via [PeopleListsOwnerChanged.rewire]. Doing the swap
  /// inline instead would give [_listsSubscription] a second writer in a
  /// different event bucket — `sequential()` orders events only within a
  /// bucket, so a re-subscription landing inside `_onOwnerChanged`'s `await`
  /// would be orphaned and outlive [close].
  ///
  /// Routing through the owner bucket also queues the re-wire *behind* any
  /// pending owner change, so a swap that arrives mid-account-switch resolves
  /// against the owner that is arriving rather than the one that is leaving.
  void _onRepositoryChanged(
    PeopleListsRepositoryChanged event,
    Emitter<PeopleListsState> emit,
  ) {
    if (identical(_repository, event.repository)) return;
    _repository = event.repository;
    addIfOpen(const PeopleListsOwnerChanged.rewire());
  }

  /// Subscribes to [ownerPubkey]'s lists on the current repository.
  StreamSubscription<List<UserList>> _watchOwner(String ownerPubkey) {
    return _repository
        .watchLists(ownerPubkey: ownerPubkey)
        .listen(
          (lists) => addIfOpen(
            PeopleListsRepositoryListsChanged(
              ownerPubkey: ownerPubkey,
              lists: lists,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
          },
        );
  }

  /// Closes [_listsSubscription], if any.
  ///
  /// Called from [_onOwnerChanged] and [_onEnabledChanged], both of which are
  /// deliberately synchronous: what would orphan a subscription is a *writer
  /// that suspends* between reading and nulling the field, not a second writer
  /// (#6482). Do not make either handler `async`. `cancel()` stops delivery to
  /// the listener synchronously — its future only reports resource cleanup, so
  /// nothing depends on awaiting it.
  void _stopWatchingLists() {
    unawaited(_listsSubscription?.cancel());
    _listsSubscription = null;
  }

  /// Opens [_listsSubscription] — the only handler that does.
  ///
  /// Deliberately synchronous, for the reason spelled out on
  /// [_stopWatchingLists].
  ///
  /// A re-wire ([PeopleListsOwnerChanged.rewire]) reuses the owner already in
  /// state and deliberately emits nothing: the repository swap fires on every
  /// cold-start auth flip, and blanking the state would flicker
  /// `PeopleListMembershipIndicator` on every profile header. The re-opened
  /// `watchLists` subscription re-emits the current snapshot immediately from
  /// the shared cache.
  void _onOwnerChanged(
    PeopleListsOwnerChanged event,
    Emitter<PeopleListsState> emit,
  ) {
    final newOwner = event.isRewire ? state.ownerPubkey : event.ownerPubkey;
    if (!event.isRewire &&
        newOwner == state.ownerPubkey &&
        state.status != PeopleListsStatus.initial) {
      return;
    }

    _stopWatchingLists();

    if (newOwner == null || newOwner.isEmpty) {
      if (!event.isRewire) {
        emit(PeopleListsState(enabled: state.enabled));
      }
      return;
    }

    // Flag off: keep following the owner so a later flag-on wires up whoever is
    // signed in then, but open no subscription and run no sync.
    if (!state.enabled) {
      if (!event.isRewire) {
        emit(PeopleListsState(ownerPubkey: newOwner, enabled: false));
      }
      return;
    }

    if (!event.isRewire) {
      emit(
        PeopleListsState(
          status: PeopleListsStatus.loading,
          ownerPubkey: newOwner,
          enabled: state.enabled,
        ),
      );
    }

    _listsSubscription = _watchOwner(newOwner);

    // On the old repository this reached a disposed NostrClient, whose
    // queryEvents returns an empty list, so the owner's lists silently stopped
    // syncing from relays (#6480).
    unawaited(_repository.syncOwner(ownerPubkey: newOwner));

    // The lists this viewer follows go stale the same way, as their owners
    // add and remove members, and they feed Home's feed selector.
    runDetached(
      _repository.syncFollowedLists(viewerPubkey: newOwner),
      'sync followed people lists',
      logName: 'PeopleListsBloc',
      category: LogCategory.relay,
    );
  }

  void _onRepositoryListsChanged(
    PeopleListsRepositoryListsChanged event,
    Emitter<PeopleListsState> emit,
  ) {
    // Ignore late emissions from a previous owner, or ones already queued when
    // the feature was turned off.
    if (!state.enabled || event.ownerPubkey != state.ownerPubkey) {
      return;
    }

    emit(
      state.copyWith(
        status: PeopleListsStatus.ready,
        lists: event.lists,
        listIdsByPubkey: _buildReverseIndex(event.lists),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Mutation handlers
  // --------------------------------------------------------------------------

  Future<void> _onCreateRequested(
    PeopleListsCreateRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final owner = state.activeOwnerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    final mutation = _buildMutation(PeopleListsMutationKind.createList);
    emit(_withMutation(state, mutation, status: PeopleListsStatus.submitting));

    try {
      final result = await _repository.createList(
        ownerPubkey: owner,
        name: event.name,
        description: event.description,
        imageUrl: event.imageUrl,
        initialPubkeys: event.initialPubkeys,
      );
      if (!_resultStillApplies(mutation, owner)) return;
      if (!result.submitted) {
        emit(_withoutMutation(state, mutation.id, failed: true));
        return;
      }
      emit(_withoutMutation(state, mutation.id, resultEventId: result.eventId));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!_resultStillApplies(mutation, owner)) return;
      emit(_withoutMutation(state, mutation.id, failed: true));
    }
  }

  Future<void> _onDeleteRequested(
    PeopleListsDeleteRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final owner = state.activeOwnerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.deleteList,
      listId: event.listId,
    );
    final removedIndex = state.lists.indexWhere(
      (list) => list.id == event.listId,
    );
    final removedList = removedIndex == -1 ? null : state.lists[removedIndex];

    // Optimistically remove the list and any reverse-index entries.
    final optimisticLists = state.lists
        .where((list) => list.id != event.listId)
        .toList(growable: false);
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    List<UserList> undo(List<UserList> lists) =>
        _restoreList(lists, removedList, removedIndex);

    try {
      final result = await _repository.deleteList(
        ownerPubkey: owner,
        listId: event.listId,
      );
      if (!_resultStillApplies(mutation, owner)) return;
      if (!result.submitted) {
        _emitRollback(emit, mutation.id, undo);
        return;
      }
      emit(_withoutMutation(state, mutation.id, resultEventId: result.eventId));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!_resultStillApplies(mutation, owner)) return;
      _emitRollback(emit, mutation.id, undo);
    }
  }

  Future<void> _onPubkeyAddRequested(
    PeopleListsPubkeyAddRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _performAdd(listId: event.listId, pubkey: event.pubkey, emit: emit);
  }

  Future<void> _onPubkeyRemoveRequested(
    PeopleListsPubkeyRemoveRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    await _performRemove(
      listId: event.listId,
      pubkey: event.pubkey,
      emit: emit,
    );
  }

  Future<void> _onPubkeyToggleRequested(
    PeopleListsPubkeyToggleRequested event,
    Emitter<PeopleListsState> emit,
  ) async {
    final currentMembers =
        state.listIdsByPubkey[event.pubkey] ?? const <String>{};
    final alreadyMember = currentMembers.contains(event.listId);

    // Run the shared add/remove helpers inline. The handler is
    // registered with `sequential()`, so a rapid double-tap is serialized
    // and each invocation reads the up-to-date state instead of
    // re-dispatching a stale action.
    if (alreadyMember) {
      await _performRemove(
        listId: event.listId,
        pubkey: event.pubkey,
        emit: emit,
      );
    } else {
      await _performAdd(listId: event.listId, pubkey: event.pubkey, emit: emit);
    }
  }

  // --------------------------------------------------------------------------
  // Shared add/remove implementation
  // --------------------------------------------------------------------------

  Future<void> _performAdd({
    required String listId,
    required String pubkey,
    required Emitter<PeopleListsState> emit,
  }) async {
    final owner = state.activeOwnerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is already a member.
    final currentMembers = state.listIdsByPubkey[pubkey] ?? const <String>{};
    if (currentMembers.contains(listId)) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.addPubkey,
      listId: listId,
      pubkey: pubkey,
    );
    final optimisticLists = _applyOptimisticAdd(
      state.lists,
      listId: listId,
      pubkey: pubkey,
      now: _clock(),
    );
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    List<UserList> undo(List<UserList> lists) => _applyOptimisticRemove(
      lists,
      listId: listId,
      pubkey: pubkey,
      now: _clock(),
    );

    try {
      final result = await _repository.addPubkey(
        ownerPubkey: owner,
        listId: listId,
        pubkey: pubkey,
      );
      if (!_resultStillApplies(mutation, owner)) return;
      if (result.status == PeopleListPublishStatus.failed) {
        _emitRollback(emit, mutation.id, undo);
        return;
      }
      emit(_withoutMutation(state, mutation.id, resultEventId: result.eventId));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!_resultStillApplies(mutation, owner)) return;
      _emitRollback(emit, mutation.id, undo);
    }
  }

  Future<void> _performRemove({
    required String listId,
    required String pubkey,
    required Emitter<PeopleListsState> emit,
  }) async {
    final owner = state.activeOwnerPubkey;
    if (owner == null || owner.isEmpty) {
      return;
    }

    // No-op when the pubkey is not a member.
    final currentMembers = state.listIdsByPubkey[pubkey] ?? const <String>{};
    if (!currentMembers.contains(listId)) {
      return;
    }

    final mutation = _buildMutation(
      PeopleListsMutationKind.removePubkey,
      listId: listId,
      pubkey: pubkey,
    );
    final removedIndex = _memberIndex(
      state.lists,
      listId: listId,
      pubkey: pubkey,
    );

    final optimisticLists = _applyOptimisticRemove(
      state.lists,
      listId: listId,
      pubkey: pubkey,
      now: _clock(),
    );
    emit(
      _withMutation(
        state.copyWith(
          lists: optimisticLists,
          listIdsByPubkey: _buildReverseIndex(optimisticLists),
        ),
        mutation,
        status: PeopleListsStatus.submitting,
      ),
    );

    List<UserList> undo(List<UserList> lists) => _restorePubkey(
      lists,
      listId: listId,
      pubkey: pubkey,
      index: removedIndex,
      now: _clock(),
    );

    try {
      final result = await _repository.removePubkey(
        ownerPubkey: owner,
        listId: listId,
        pubkey: pubkey,
      );
      if (!_resultStillApplies(mutation, owner)) return;
      if (result.status == PeopleListPublishStatus.failed) {
        _emitRollback(emit, mutation.id, undo);
        return;
      }
      emit(_withoutMutation(state, mutation.id, resultEventId: result.eventId));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      if (!_resultStillApplies(mutation, owner)) return;
      _emitRollback(emit, mutation.id, undo);
    }
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  /// Whether a mutation result that arrived after an `await` may still be
  /// written to state.
  ///
  /// Mutation outcomes and rollbacks are only valid for the state that issued
  /// them. In between, the bloc may have torn that state down — an account
  /// switch, a sign-out, or `FeatureFlag.curatedLists` going off each emit a
  /// fresh state with an empty `pendingMutations`. Applying a result there can
  /// write one owner's lists or mutation status onto whoever is signed in by
  /// then (#6504).
  ///
  /// The mutation lookup is what actually detects a teardown; the owner check
  /// keeps the guard honest if a future teardown ever preserves the map.
  bool _resultStillApplies(PeopleListsMutation mutation, String owner) {
    return state.activeOwnerPubkey == owner &&
        state.pendingMutations.containsKey(mutation.id);
  }

  /// Emits the failure state for [mutationId] with [undo] applied to the
  /// *current* lists.
  ///
  /// Rollbacks used to restore a whole `lists`/`listIdsByPubkey` snapshot
  /// captured before the round-trip. That snapshot also loses to a repository
  /// emission that lands mid-flight — `_onRepositoryListsChanged` keeps
  /// `pendingMutations`, so the guard passes and the restore drops whatever
  /// arrived meanwhile (a list synced from a relay, another device's edit).
  ///
  /// Undoing just this mutation's own change instead leaves everything else
  /// alone. The repository writes its cache only after a successful publish, so
  /// a mid-flight emission carries the pre-mutation truth and every [undo] here
  /// is a no-op against it — which also makes the rollback order-independent.
  void _emitRollback(
    Emitter<PeopleListsState> emit,
    String mutationId,
    List<UserList> Function(List<UserList> lists) undo,
  ) {
    final restored = undo(state.lists);
    emit(
      _withoutMutation(state, mutationId, failed: true).copyWith(
        lists: restored,
        listIdsByPubkey: _buildReverseIndex(restored),
      ),
    );
  }

  /// Builds a mutation record with a unique id.
  ///
  /// The id combines the clock's microsecond epoch with the mutation
  /// kind and target — unique without needing a mutable counter on the
  /// bloc instance (forbidden by `rules/state_management.md`). The clock
  /// is injected so tests can feed a monotonically increasing sequence.
  PeopleListsMutation _buildMutation(
    PeopleListsMutationKind kind, {
    String? listId,
    String? pubkey,
  }) {
    final stamp = _clock().microsecondsSinceEpoch;
    final suffix = listId != null
        ? '-$listId'
        : (pubkey != null ? '-$pubkey' : '');
    return PeopleListsMutation(
      id: 'mut-$stamp-${kind.name}$suffix',
      kind: kind,
      listId: listId,
      pubkey: pubkey,
    );
  }

  PeopleListsState _withMutation(
    PeopleListsState current,
    PeopleListsMutation mutation, {
    PeopleListsStatus? status,
  }) {
    final next = Map<String, PeopleListsMutation>.from(current.pendingMutations)
      ..[mutation.id] = mutation;
    return current.copyWith(status: status, pendingMutations: next);
  }

  PeopleListsState _withoutMutation(
    PeopleListsState current,
    String mutationId, {
    String? resultEventId,
    bool failed = false,
  }) {
    final next = Map<String, PeopleListsMutation>.from(current.pendingMutations)
      ..remove(mutationId);
    // Recovery contract: a fresh failure pins `failure`; otherwise, once
    // the last pending mutation drains, reset any sticky `failure` back
    // to `ready` so the UI isn't stuck if the repository never re-emits.
    final PeopleListsStatus nextStatus;
    if (failed) {
      nextStatus = PeopleListsStatus.failure;
    } else if (next.isEmpty) {
      nextStatus = PeopleListsStatus.ready;
    } else {
      nextStatus = current.status;
    }
    return current.copyWith(
      status: nextStatus,
      pendingMutations: next,
      lastSubmittedEventId: resultEventId,
    );
  }

  /// Rebuilds the pubkey→listIds reverse index from [lists].
  static Map<String, Set<String>> _buildReverseIndex(List<UserList> lists) {
    final index = <String, Set<String>>{};
    for (final list in lists) {
      for (final pubkey in list.pubkeys) {
        (index[pubkey] ??= <String>{}).add(list.id);
      }
    }
    return index;
  }

  /// Position of [pubkey] within [listId]'s members, or `-1` when absent.
  static int _memberIndex(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
  }) {
    for (final list in lists) {
      if (list.id == listId) return list.pubkeys.indexOf(pubkey);
    }
    return -1;
  }

  /// Re-inserts [list] at [index], unless it is already back.
  static List<UserList> _restoreList(
    List<UserList> lists,
    UserList? list,
    int index,
  ) {
    if (list == null) return lists;
    if (lists.any((candidate) => candidate.id == list.id)) return lists;
    final restored = List<UserList>.of(lists)
      ..insert(index.clamp(0, lists.length), list);
    return restored.toList(growable: false);
  }

  /// Re-inserts [pubkey] into [listId] at [index], unless it is already back.
  static List<UserList> _restorePubkey(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
    required int index,
    required DateTime now,
  }) {
    if (index < 0) return lists;
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (list.pubkeys.contains(pubkey)) return list;
          final pubkeys = List<String>.of(list.pubkeys)
            ..insert(index.clamp(0, list.pubkeys.length), pubkey);
          return list.copyWith(pubkeys: pubkeys, updatedAt: now);
        })
        .toList(growable: false);
  }

  static List<UserList> _applyOptimisticAdd(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
    required DateTime now,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: [...list.pubkeys, pubkey],
            updatedAt: now,
          );
        })
        .toList(growable: false);
  }

  static List<UserList> _applyOptimisticRemove(
    List<UserList> lists, {
    required String listId,
    required String pubkey,
    required DateTime now,
  }) {
    return lists
        .map((list) {
          if (list.id != listId) return list;
          if (!list.pubkeys.contains(pubkey)) return list;
          return list.copyWith(
            pubkeys: list.pubkeys.where((p) => p != pubkey).toList(),
            updatedAt: now,
          );
        })
        .toList(growable: false);
  }
}
