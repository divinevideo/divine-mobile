// ABOUTME: Unit tests for PeopleListsBloc global owner-scoped lists state.
// ABOUTME: Covers auth transitions, optimistic mutations, and submitted state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock implements PeopleListsRepository {
  _MockPeopleListsRepository() {
    // Attaching an owner also refreshes the lists they follow. The tests about
    // that refresh verify it; every other test only needs it to complete.
    when(
      () => syncFollowedLists(
        viewerPubkey: any(named: 'viewerPubkey'),
        isCancelled: any(named: 'isCancelled'),
      ),
    ).thenAnswer((_) async {});
  }
}

// Full-length Nostr pubkeys — never truncate.
const String _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const String _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const String _memberAlice =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const String _memberBob =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

final DateTime _frozenNow = DateTime.utc(2026, 4, 20, 12);
DateTime _fixedClock() => _frozenNow;

UserList _buildList({
  required String id,
  required String name,
  required List<String> pubkeys,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: createdAt ?? _frozenNow,
    updatedAt: updatedAt ?? _frozenNow,
  );
}

Future<void> _flush() => pumpEventQueue();

/// The cancellation predicate the bloc handed to the followed-lists refresh it
/// started for [viewerPubkey].
bool Function() _capturedIsCancelled(
  _MockPeopleListsRepository repository,
  String viewerPubkey,
) {
  final captured = verify(
    () => repository.syncFollowedLists(
      viewerPubkey: viewerPubkey,
      isCancelled: captureAny(named: 'isCancelled'),
    ),
  ).captured;
  return captured.single as bool Function();
}

void main() {
  setUpAll(() {
    registerFallbackValue(const <String>[]);
  });

  group(PeopleListsBloc, () {
    late _MockPeopleListsRepository repository;
    late StreamController<String?> ownerPubkeyController;
    late StreamController<bool> enabledController;
    late StreamController<List<UserList>> ownerAListsController;
    late StreamController<List<UserList>> ownerBListsController;

    setUp(() {
      repository = _MockPeopleListsRepository();
      ownerPubkeyController = StreamController<String?>.broadcast();
      enabledController = StreamController<bool>.broadcast();
      ownerAListsController = StreamController<List<UserList>>.broadcast();
      ownerBListsController = StreamController<List<UserList>>.broadcast();

      when(
        () => repository.watchLists(ownerPubkey: _ownerA),
      ).thenAnswer((_) => ownerAListsController.stream);
      when(
        () => repository.watchLists(ownerPubkey: _ownerB),
      ).thenAnswer((_) => ownerBListsController.stream);
      when(
        () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
      ).thenAnswer((_) async {});
    });

    tearDown(() async {
      await ownerPubkeyController.close();
      await enabledController.close();
      if (!ownerAListsController.isClosed) {
        await ownerAListsController.close();
      }
      if (!ownerBListsController.isClosed) {
        await ownerBListsController.close();
      }
    });

    PeopleListsBloc buildBloc({String? initialOwnerPubkey}) {
      return PeopleListsBloc(
        repository: repository,
        ownerPubkeyStream: ownerPubkeyController.stream,
        repositoryStream: const Stream.empty(),
        enabledStream: enabledController.stream,
        initialOwnerPubkey: initialOwnerPubkey,
        clock: _fixedClock,
      );
    }

    test('serializes add and remove through one mutation queue', () async {
      final pending = Completer<PeopleListPublishResult>();
      final entered = Completer<void>();
      when(
        () => repository.addPubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      ).thenAnswer((_) {
        entered.complete();
        return pending.future;
      });
      when(
        () => repository.removePubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      ).thenAnswer(
        (_) async => const PeopleListPublishResult(
          status: PeopleListPublishStatus.submitted,
        ),
      );
      final bloc = buildBloc(initialOwnerPubkey: _ownerA);
      addTearDown(bloc.close);
      addTearDown(() async {
        if (!pending.isCompleted) {
          pending.complete(const PeopleListPublishResult.failed());
        }
        await pumpEventQueue();
      });
      bloc.add(
        PeopleListsRepositoryListsChanged(
          ownerPubkey: _ownerA,
          lists: [_buildList(id: 'crew', name: 'Crew', pubkeys: [])],
        ),
      );
      await _flush();
      bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      );
      await entered.future;
      expect(bloc.state.lists.single.pubkeys, [_memberAlice]);
      expect(bloc.state.pendingMutations, hasLength(1));
      bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      );
      await _flush();
      verifyNever(
        () => repository.removePubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      );
      final removed = bloc.stream.firstWhere(
        (state) =>
            state.pendingMutations.isEmpty &&
            state.lists.single.pubkeys.isEmpty,
      );
      pending.complete(
        const PeopleListPublishResult(
          status: PeopleListPublishStatus.submitted,
        ),
      );
      await removed;
      verify(
        () => repository.removePubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _memberAlice,
        ),
      ).called(1);
      expect(bloc.state.lists.single.pubkeys, isEmpty);
    });

    test(
      'returns each operation outcome across partial batch failure',
      () async {
        final pending = Completer<PeopleListPublishResult>();
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _memberAlice,
          ),
        ).thenAnswer((_) => pending.future);
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(eventId: null),
        );
        final bloc = buildBloc(initialOwnerPubkey: _ownerA);
        addTearDown(bloc.close);
        bloc.add(
          PeopleListsRepositoryListsChanged(
            ownerPubkey: _ownerA,
            lists: [_buildList(id: 'crew', name: 'Crew', pubkeys: [])],
          ),
        );
        await _flush();
        final first = bloc.submit(
          const PeopleListsPubkeyAddRequested(
            listId: 'crew',
            pubkey: _memberAlice,
          ),
        );
        final second = bloc.submit(
          const PeopleListsPubkeyAddRequested(
            listId: 'crew',
            pubkey: _memberBob,
          ),
        );
        await _flush();
        pending.complete(const PeopleListPublishResult.failed());
        expect(await first, PeopleListsOperationResult.failed);
        expect(await second, PeopleListsOperationResult.succeeded);
        expect(bloc.state.lists.single.pubkeys, [_memberBob]);
      },
    );

    for (final teardown in ['flag', 'account', 'close', 'repository']) {
      test(
        '$teardown cancels pending and queued results without publishing queued writes',
        () async {
          final pending = Completer<PeopleListPublishResult>();
          when(
            () => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'crew',
              pubkey: _memberAlice,
            ),
          ).thenAnswer((_) => pending.future);
          final bloc = buildBloc(initialOwnerPubkey: _ownerA);
          bloc.add(
            PeopleListsRepositoryListsChanged(
              ownerPubkey: _ownerA,
              lists: [_buildList(id: 'crew', name: 'Crew', pubkeys: [])],
            ),
          );
          await _flush();
          final first = bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'crew',
              pubkey: _memberAlice,
            ),
          );
          final second = bloc.submit(
            const PeopleListsPubkeyAddRequested(
              listId: 'crew',
              pubkey: _memberBob,
            ),
          );
          await _flush();
          Future<void>? closing;
          switch (teardown) {
            case 'flag':
              bloc.add(const PeopleListsEnabledChanged(enabled: false));
            case 'account':
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerB));
              await _flush();
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerA));
            case 'close':
              closing = bloc.close();
            case 'repository':
              final replacement = _MockPeopleListsRepository();
              when(() => replacement.watchLists(ownerPubkey: _ownerA))
                  .thenAnswer((_) => const Stream.empty());
              when(() => replacement.syncOwner(ownerPubkey: _ownerA))
                  .thenAnswer((_) async {});
              bloc.add(PeopleListsRepositoryChanged(repository: replacement));
          }
          await _flush();
          expect(await first, PeopleListsOperationResult.cancelled);
          expect(await second, PeopleListsOperationResult.cancelled);
          pending.complete(const PeopleListPublishResult.failed());
          await _flush();
          verifyNever(
            () => repository.addPubkey(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: 'crew',
              pubkey: _memberBob,
            ),
          );
          if (teardown != 'close') expect(bloc.state.pendingMutations, isEmpty);
          await (closing ?? bloc.close());
        },
      );
    }

    test(
      'new submissions cancel while close waits for subscription cleanup',
      () async {
        final cleanup = Completer<void>();
        final lists = StreamController<List<UserList>>(
          onCancel: () => cleanup.future,
        );
        when(() => repository.watchLists(ownerPubkey: _ownerA))
            .thenAnswer((_) => lists.stream);
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _memberAlice,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(eventId: null),
        );
        final bloc = buildBloc(initialOwnerPubkey: _ownerA);
        bloc.add(const PeopleListsStarted());
        await _flush();
        await _flush();
        final closing = bloc.close();
        await _flush();
        final result = await bloc.submit(
          const PeopleListsPubkeyAddRequested(
            listId: 'crew',
            pubkey: _memberAlice,
          ),
        );
        cleanup.complete();
        await closing;
        await lists.close();
        expect(result, PeopleListsOperationResult.cancelled);
        verifyNever(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'crew',
            pubkey: _memberAlice,
          ),
        );
      },
    );

    test('empty cache remains unknown until the owner read settles', () async {
      final pending = Completer<void>();
      when(() => repository.syncOwner(ownerPubkey: _ownerA))
          .thenAnswer((_) => pending.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const PeopleListsStarted());
      await _flush();
      ownerPubkeyController.add(_ownerA);
      await _flush();
      ownerAListsController.add([]);
      await _flush();
      expect(bloc.state.status, PeopleListsStatus.ready);
      expect(bloc.state.listsKnown, isFalse);
      expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);
      pending.complete();
      await _flush();
      expect(bloc.state.listsKnown, isTrue);
      expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.settled);
    });

    test(
      'inconclusive owner read is retryable without clearing a cached list',
      () async {
        when(() => repository.syncOwner(ownerPubkey: _ownerA))
            .thenThrow(StateError('offline'));
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        final list = _buildList(
          id: 'crew',
          name: 'Crew',
          pubkeys: [_memberAlice],
        );
        ownerAListsController.add([list]);
        await _flush();
        expect(bloc.state.listsKnown, isFalse);
        expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.failed);
        expect(bloc.state.lists, [list]);
        final retry = Completer<void>();
        when(() => repository.syncOwner(ownerPubkey: _ownerA))
            .thenAnswer((_) => retry.future);
        bloc.add(const PeopleListsOwnerSyncRequested());
        await _flush();
        expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);
        expect(bloc.state.lists, [list]);
        retry.complete();
        await _flush();
        expect(bloc.state.listsKnown, isTrue);
      },
    );

    test('late owner read cannot settle the next account', () async {
      final first = Completer<void>();
      final next = Completer<void>();
      when(() => repository.syncOwner(ownerPubkey: _ownerA))
          .thenAnswer((_) => first.future);
      when(() => repository.syncOwner(ownerPubkey: _ownerB))
          .thenAnswer((_) => next.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const PeopleListsStarted());
      await _flush();
      ownerPubkeyController.add(_ownerA);
      await _flush();
      ownerPubkeyController.add(_ownerB);
      await _flush();
      ownerBListsController.add([]);
      await _flush();
      first.complete();
      await _flush();
      expect(bloc.state.ownerPubkey, _ownerB);
      expect(bloc.state.listsKnown, isFalse);
      next.complete();
      await _flush();
      expect(bloc.state.listsKnown, isTrue);
    });

    test(
      'a late read from an earlier session of the same account cannot settle '
      'the current one',
      () async {
        final firstA = Completer<void>();
        final secondA = Completer<void>();
        when(() => repository.syncOwner(ownerPubkey: _ownerA))
            .thenAnswer((_) => firstA.future);
        final bloc = buildBloc();
        addTearDown(bloc.close);
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerPubkeyController.add(_ownerB);
        await _flush();
        when(() => repository.syncOwner(ownerPubkey: _ownerA))
            .thenAnswer((_) => secondA.future);
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([]);
        await _flush();
        expect(bloc.state.ownerPubkey, _ownerA);
        expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);

        firstA.complete();
        await _flush();
        expect(bloc.state.listsKnown, isFalse);
        expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);

        secondA.complete();
        await _flush();
        expect(bloc.state.listsKnown, isTrue);
      },
    );

    test('a late first read cannot settle a retry still in flight', () async {
      final first = Completer<void>();
      final retry = Completer<void>();
      when(() => repository.syncOwner(ownerPubkey: _ownerA))
          .thenAnswer((_) => first.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const PeopleListsStarted());
      await _flush();
      ownerPubkeyController.add(_ownerA);
      await _flush();
      ownerAListsController.add([]);
      await _flush();
      when(() => repository.syncOwner(ownerPubkey: _ownerA))
          .thenAnswer((_) => retry.future);
      bloc.add(const PeopleListsOwnerSyncRequested());
      await _flush();
      expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);

      first.complete();
      await _flush();
      expect(bloc.state.listsKnown, isFalse);
      expect(bloc.state.ownerReadStatus, PeopleListsOwnerReadStatus.pending);

      retry.complete();
      await _flush();
      expect(bloc.state.listsKnown, isTrue);
    });

    test('initial state is unauthenticated with empty lists', () {
      final bloc = buildBloc();
      expect(bloc.state, equals(const PeopleListsState()));
      expect(bloc.state.ownerPubkey, isNull);
      expect(bloc.state.lists, isEmpty);
      expect(bloc.state.listIdsByPubkey, isEmpty);
      addTearDown(bloc.close);
    });

    blocTest<PeopleListsBloc, PeopleListsState>(
      'loads current account lists when owner pubkey is set',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ]);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.ownerPubkey, equals(_ownerA));
        expect(bloc.state.lists, hasLength(1));
        expect(bloc.state.lists.first.id, equals('list-1'));
        verify(() => repository.syncOwner(ownerPubkey: _ownerA)).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'refreshes the lists the new owner follows',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
      },
      verify: (_) {
        verify(
          () => repository.syncFollowedLists(
            viewerPubkey: _ownerA,
            isCancelled: any(named: 'isCancelled'),
          ),
        ).called(1);
      },
    );

    test('stops the followed-lists refresh when the owner changes', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const PeopleListsStarted());
      await _flush();
      ownerPubkeyController.add(_ownerA);
      await _flush();
      final previousOwnerCancelled = _capturedIsCancelled(repository, _ownerA);
      expect(previousOwnerCancelled(), isFalse);

      ownerPubkeyController.add(_ownerB);
      await _flush();

      expect(previousOwnerCancelled(), isTrue);
      expect(_capturedIsCancelled(repository, _ownerB)(), isFalse);
    });

    test('stops the followed-lists refresh when the bloc closes', () async {
      final bloc = buildBloc();
      bloc.add(const PeopleListsStarted());
      await _flush();
      ownerPubkeyController.add(_ownerA);
      await _flush();
      final cancelled = _capturedIsCancelled(repository, _ownerA);
      expect(cancelled(), isFalse);

      await bloc.close();

      expect(cancelled(), isTrue);
    });

    blocTest<PeopleListsBloc, PeopleListsState>(
      'clears lists and pending mutations on owner pubkey change',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
        pendingMutations: const {
          'mut-1': PeopleListsMutation(
            id: 'mut-1',
            listId: 'list-1',
            pubkey: _memberBob,
            kind: PeopleListsMutationKind.addPubkey,
          ),
        },
      ),
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerB);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.ownerPubkey, equals(_ownerB));
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
        expect(bloc.state.pendingMutations, isEmpty);
        verify(() => repository.syncOwner(ownerPubkey: _ownerB)).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'resets to empty state when owner pubkey becomes null',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(null);
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state, equals(const PeopleListsState()));
        verifyNever(
          () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'builds listIdsByPubkey reverse index from repository lists',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([
          _buildList(
            id: 'list-friends',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
          _buildList(
            id: 'list-favs',
            name: 'Favs',
            pubkeys: const [_memberAlice],
          ),
        ]);
        await _flush();
      },
      verify: (bloc) {
        expect(
          bloc.state.listIdsByPubkey[_memberAlice],
          equals({'list-friends', 'list-favs'}),
        );
        expect(
          bloc.state.listIdsByPubkey[_memberBob],
          equals({'list-friends'}),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'submits an add and updates the reverse index',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '1111111111111111111111111111111111111111111111111111111111111111',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        expect(bloc.state.listIdsByPubkey[_memberBob], equals({'list-1'}));
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'submits a removal and updates the reverse index',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '2222222222222222222222222222222222222222222222222222222222222222',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
          _memberBob: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).called(1);
        expect(bloc.state.listIdsByPubkey.containsKey(_memberAlice), isFalse);
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when add pubkey fails',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenThrow(StateError('relay down'));
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
          },
        );
      },
      errors: () => [isA<StateError>()],
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        final expectedLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lists, equals(expectedLists));
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when add pubkey is not submitted',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) async => const PeopleListPublishResult.failed());
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
          },
        );
      },
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when remove pubkey fails',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenThrow(StateError('relay down'));
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          },
        );
      },
      errors: () => [isA<StateError>()],
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        final expectedLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ];
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lists, equals(expectedLists));
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when remove pubkey is not submitted',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer((_) async => const PeopleListPublishResult.failed());
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          },
        );
      },
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
            _memberBob: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'rejects create fields captured for another account',
      build: buildBloc,
      seed: () => const PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerB,
      ),
      act: (bloc) => bloc.add(
        const PeopleListsCreateRequested(
          expectedOwnerPubkey: _ownerA,
          name: 'Account A fields',
        ),
      ),
      expect: () => <PeopleListsState>[],
      verify: (_) {
        verifyNever(
          () => repository.createList(
            ownerPubkey: any(named: 'ownerPubkey'),
            name: any(named: 'name'),
          ),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for create list before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.createList(
            ownerPubkey: _ownerA,
            name: 'New List',
            initialPubkeys: [_memberAlice],
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '3333333333333333333333333333333333333333333333333333333333333333',
          ),
        );
      },
      seed: () => const PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
      ),
      act: (bloc) => bloc.add(
        const PeopleListsCreateRequested(
          expectedOwnerPubkey: _ownerA,
          name: 'New List',
          initialPubkeys: [_memberAlice],
        ),
      ),
      verify: (bloc) {
        verify(
          () => repository.createList(
            ownerPubkey: _ownerA,
            name: 'New List',
            initialPubkeys: [_memberAlice],
          ),
        ).called(1);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'reports failure when a create is not submitted',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.createList(ownerPubkey: _ownerA, name: 'New List'),
        ).thenAnswer((_) async => const PeopleListPublishResult.failed());
      },
      seed: () => const PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
      ),
      act: (bloc) => bloc.add(
        const PeopleListsCreateRequested(
          expectedOwnerPubkey: _ownerA,
          name: 'New List',
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lastSubmittedEventId, isNull);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'emits optimistic state for delete list before repository returns',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.deleteList(ownerPubkey: _ownerA, listId: 'list-1'),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '4444444444444444444444444444444444444444444444444444444444444444',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) =>
          bloc.add(const PeopleListsDeleteRequested(listId: 'list-1')),
      verify: (bloc) {
        verify(
          () => repository.deleteList(ownerPubkey: _ownerA, listId: 'list-1'),
        ).called(1);
        // Optimistic delete removes the list and any reverse index entries.
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'restores exact prior lists and reverse index when delete publish fails',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.deleteList(ownerPubkey: _ownerA, listId: 'list-1'),
        ).thenAnswer((_) async => const PeopleListPublishResult.failed());
      },
      seed: () {
        final priorLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        return PeopleListsState(
          status: PeopleListsStatus.ready,
          ownerPubkey: _ownerA,
          lists: priorLists,
          listIdsByPubkey: const {
            _memberAlice: {'list-1'},
          },
        );
      },
      act: (bloc) =>
          bloc.add(const PeopleListsDeleteRequested(listId: 'list-1')),
      verify: (bloc) {
        final expectedLists = [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ];
        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.lastSubmittedEventId, isNull);
        expect(bloc.state.lists, equals(expectedLists));
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'list-1'},
          }),
        );
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'reports submitted from repository without claiming relay confirmation',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '5555555555555555555555555555555555555555555555555555555555555555',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        expect(
          bloc.state.lastSubmittedEventId,
          equals(
            '5555555555555555555555555555555555555555555555555555555555555555',
          ),
        );
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'ignores duplicate add no-ops',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyAddRequested(
          listId: 'list-1',
          pubkey: _memberAlice,
        ),
      ),
      verify: (bloc) {
        verifyNever(
          () => repository.addPubkey(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            pubkey: any(named: 'pubkey'),
          ),
        );
      },
      expect: () => const <PeopleListsState>[],
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'ignores duplicate remove no-ops',
      build: buildBloc,
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) => bloc.add(
        const PeopleListsPubkeyRemoveRequested(
          listId: 'list-1',
          pubkey: _memberBob,
        ),
      ),
      verify: (bloc) {
        verifyNever(
          () => repository.removePubkey(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            pubkey: any(named: 'pubkey'),
          ),
        );
      },
      expect: () => const <PeopleListsState>[],
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'toggle adds when member is absent and removes when present',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '6666666666666666666666666666666666666666666666666666666666666666',
          ),
        );
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '7777777777777777777777777777777777777777777777777777777777777777',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      act: (bloc) async {
        // First toggle: Bob is absent → should add.
        bloc.add(
          const PeopleListsPubkeyToggleRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
        // Second toggle: Bob is now present → should remove.
        bloc.add(
          const PeopleListsPubkeyToggleRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
      },
      verify: (bloc) {
        verify(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        verify(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).called(1);
        // Net result: Bob is absent again.
        expect(bloc.state.listIdsByPubkey.containsKey(_memberBob), isFalse);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'recovers from sticky failure once pending mutations drain',
      build: buildBloc,
      setUp: () {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        ).thenThrow(StateError('relay down'));
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer(
          (_) async => const PeopleListPublishResult.submitted(
            eventId: '8888888888888888888888888888888888888888888888888888888888888888',
          ),
        );
      },
      seed: () => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(
            id: 'list-1',
            name: 'Friends',
            pubkeys: const [_memberAlice],
          ),
        ],
        listIdsByPubkey: const {
          _memberAlice: {'list-1'},
        },
      ),
      errors: () => [isA<StateError>()],
      act: (bloc) async {
        // First mutation fails → failure status.
        bloc.add(
          const PeopleListsPubkeyAddRequested(
            listId: 'list-1',
            pubkey: _memberBob,
          ),
        );
        await _flush();
        // Subsequent successful mutation should reset status back to ready.
        bloc.add(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'list-1',
            pubkey: _memberAlice,
          ),
        );
        await _flush();
      },
      verify: (bloc) {
        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.pendingMutations, isEmpty);
      },
    );

    blocTest<PeopleListsBloc, PeopleListsState>(
      'close cancels owner and repository subscriptions',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        await bloc.close();
        // Post-close events must not be observed by the closed bloc; if
        // subscriptions leaked, adding events here would throw because
        // the bloc's internal event controller is closed.
        ownerPubkeyController.add(_ownerB);
        ownerAListsController.add(const []);
        await _flush();
      },
      verify: (bloc) {
        expect(ownerPubkeyController.hasListener, isFalse);
        expect(ownerAListsController.hasListener, isFalse);
      },
    );

    test('owner change cancels previous repository subscription', () async {
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const PeopleListsStarted());
      await _flush();

      ownerPubkeyController.add(_ownerA);
      for (var i = 0; i < 5; i++) {
        await _flush();
      }
      expect(
        ownerAListsController.hasListener,
        isTrue,
        reason: 'owner A stream should have been subscribed',
      );

      ownerPubkeyController.add(_ownerB);
      for (var i = 0; i < 5; i++) {
        await _flush();
      }

      expect(ownerAListsController.hasListener, isFalse);
      expect(ownerBListsController.hasListener, isTrue);
    });

    // #6494: the app-shell BlocProvider is unconditional (#6477), so laziness
    // only gates construction. A bloc built while FeatureFlag.curatedLists was
    // on used to keep its cache subscription and keep calling syncOwner for
    // kind 30000 for the rest of the session after the flag went off.
    group('update', () {
      Future<PeopleListsBloc> startedForOwnerA() async {
        final bloc = buildBloc(initialOwnerPubkey: _ownerA);
        addTearDown(bloc.close);
        bloc.add(
          PeopleListsRepositoryListsChanged(
            ownerPubkey: _ownerA,
            lists: [_buildList(id: 'crew', name: 'Crew', pubkeys: [])],
          ),
        );
        await _flush();
        return bloc;
      }

      const request = PeopleListsUpdateRequested(
        expectedOwnerPubkey: _ownerA,
        listId: 'crew',
        name: 'Crew 2',
        description: 'Who we ride with',
      );

      void stubUpdate(Future<PeopleListPublishResult> Function() answer) {
        when(
          () => repository.updateList(
            ownerPubkey: _ownerA,
            listId: 'crew',
            name: 'Crew 2',
            description: 'Who we ride with',
          ),
        ).thenAnswer((_) => answer());
      }

      test('succeeds once the repository confirms the edit', () async {
        stubUpdate(
          () async =>
              const PeopleListPublishResult.submitted(eventId: 'event-1'),
        );
        final bloc = await startedForOwnerA();

        final result = await bloc.submit(request);

        expect(result, PeopleListsOperationResult.succeeded);
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.status, PeopleListsStatus.ready);
        expect(bloc.state.lastSubmittedEventId, 'event-1');
      });

      test('treats an unchanged edit as settled rather than failed', () async {
        stubUpdate(() async => const PeopleListPublishResult.noop());
        final bloc = await startedForOwnerA();

        final result = await bloc.submit(request);

        expect(result, PeopleListsOperationResult.succeeded);
        expect(bloc.state.status, PeopleListsStatus.ready);
      });

      test('fails when the repository refuses the edit', () async {
        stubUpdate(() async => const PeopleListPublishResult.failed());
        final bloc = await startedForOwnerA();

        final result = await bloc.submit(request);

        expect(result, PeopleListsOperationResult.failed);
        expect(bloc.state.pendingMutations, isEmpty);
        expect(bloc.state.status, PeopleListsStatus.failure);
      });

      test('fails when the repository throws', () async {
        stubUpdate(() async => throw StateError('relay exploded'));
        final bloc = await startedForOwnerA();

        final result = await bloc.submit(request);

        expect(result, PeopleListsOperationResult.failed);
        expect(bloc.state.status, PeopleListsStatus.failure);
        expect(bloc.state.pendingMutations, isEmpty);
      });

      test('cancels an edit made for another account', () async {
        final bloc = await startedForOwnerA();

        final result = await bloc.submit(
          const PeopleListsUpdateRequested(
            expectedOwnerPubkey: _ownerB,
            listId: 'crew',
            name: 'Crew 2',
            description: 'Who we ride with',
          ),
        );

        expect(result, PeopleListsOperationResult.cancelled);
        verifyNever(
          () => repository.updateList(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
          ),
        );
      });
    });

    group(PeopleListsPicksApplied, () {
      PeopleListsState seeded() => PeopleListsState(
        status: PeopleListsStatus.ready,
        ownerPubkey: _ownerA,
        lists: [
          _buildList(id: 'list-1', name: 'Friends', pubkeys: const []),
          _buildList(id: 'list-2', name: 'Work', pubkeys: const []),
          _buildList(
            id: 'list-3',
            name: 'Old',
            pubkeys: const [_memberBob],
          ),
        ],
        listIdsByPubkey: const {
          _memberBob: {'list-3'},
        },
      );

      void stubAdd(String listId, PeopleListPublishResult result) {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: listId,
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) async => result);
      }

      void stubRemove(String listId, PeopleListPublishResult result) {
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: listId,
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) async => result);
      }

      const submitted = PeopleListPublishResult.submitted(
        eventId:
            '3333333333333333333333333333333333333333333333333333333333333333',
      );

      blocTest<PeopleListsBloc, PeopleListsState>(
        'applies every add and remove in order, then records an outcome '
        'with nothing refused',
        build: buildBloc,
        setUp: () {
          stubAdd('list-1', submitted);
          stubAdd('list-2', submitted);
          stubRemove('list-3', submitted);
        },
        seed: seeded,
        act: (bloc) => bloc.add(
          const PeopleListsPicksApplied(
            requestId: 'batch',
            ownerPubkey: _ownerA,
            pubkey: _memberBob,
            addListIds: {'list-1', 'list-2'},
            removeListIds: {'list-3'},
          ),
        ),
        verify: (bloc) {
          verifyInOrder([
            () => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'list-1',
              pubkey: _memberBob,
            ),
            () => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'list-2',
              pubkey: _memberBob,
            ),
            () => repository.removePubkey(
              ownerPubkey: _ownerA,
              listId: 'list-3',
              pubkey: _memberBob,
            ),
          ]);
          expect(bloc.state.listIdsByPubkey[_memberBob], {'list-1', 'list-2'});
          expect(bloc.state.pendingMutations, isEmpty);
          expect(
            bloc.state.lastPicksOutcome,
            const PeopleListsPicksOutcome(
              requestId: 'batch',
              sequence: 1,
              pubkey: _memberBob,
              refused: 0,
            ),
          );
        },
      );

      blocTest<PeopleListsBloc, PeopleListsState>(
        'counts a later pick the relay refused, after an earlier one landed',
        build: buildBloc,
        setUp: () {
          stubAdd('list-1', submitted);
          stubAdd('list-2', const PeopleListPublishResult.failed());
        },
        seed: seeded,
        act: (bloc) => bloc.add(
          const PeopleListsPicksApplied(
            requestId: 'batch',
            ownerPubkey: _ownerA,
            pubkey: _memberBob,
            addListIds: {'list-1', 'list-2'},
            removeListIds: {},
          ),
        ),
        verify: (bloc) {
          // The second add was rolled back; the first stands.
          expect(bloc.state.listIdsByPubkey[_memberBob], {'list-1', 'list-3'});
          expect(bloc.state.lastPicksOutcome?.refused, 1);
          expect(bloc.state.lastPicksOutcome?.pubkey, _memberBob);
        },
      );

      blocTest<PeopleListsBloc, PeopleListsState>(
        'counts a pick whose repository call threw as refused',
        build: buildBloc,
        setUp: () {
          when(
            () => repository.removePubkey(
              ownerPubkey: _ownerA,
              listId: 'list-3',
              pubkey: _memberBob,
            ),
          ).thenThrow(StateError('relay down'));
        },
        seed: seeded,
        act: (bloc) => bloc.add(
          const PeopleListsPicksApplied(
            requestId: 'batch',
            ownerPubkey: _ownerA,
            pubkey: _memberBob,
            addListIds: {},
            removeListIds: {'list-3'},
          ),
        ),
        errors: () => [isA<StateError>()],
        verify: (bloc) {
          expect(bloc.state.listIdsByPubkey[_memberBob], {'list-3'});
          expect(bloc.state.lastPicksOutcome?.refused, 1);
        },
      );

      blocTest<PeopleListsBloc, PeopleListsState>(
        'numbers each outcome after the last, so a sheet can tell its own',
        build: buildBloc,
        setUp: () => stubAdd('list-1', submitted),
        seed: () => seeded().copyWith(
          lastPicksOutcome: const PeopleListsPicksOutcome(
            requestId: 'batch',
            sequence: 7,
            pubkey: _memberAlice,
            refused: 0,
          ),
        ),
        act: (bloc) => bloc.add(
          const PeopleListsPicksApplied(
            requestId: 'batch',
            ownerPubkey: _ownerA,
            pubkey: _memberBob,
            addListIds: {'list-1'},
            removeListIds: {},
          ),
        ),
        verify: (bloc) {
          expect(bloc.state.lastPicksOutcome?.sequence, 8);
          expect(bloc.state.lastPicksOutcome?.pubkey, _memberBob);
        },
      );

      for (final switchOwner in [true, false]) {
        late Completer<PeopleListPublishResult> pending;
        late Completer<void> started;
        blocTest<PeopleListsBloc, PeopleListsState>(
          switchOwner
              ? 'stops the batch when its owner changes during the first write'
              : 'stops the batch across a feature off/on cycle during a write',
          build: buildBloc,
          seed: seeded,
          setUp: () {
            pending = Completer<PeopleListPublishResult>();
            started = Completer<void>();
            when(
              () => repository.addPubkey(
                ownerPubkey: _ownerA,
                listId: 'list-1',
                pubkey: _memberBob,
              ),
            ).thenAnswer((_) {
              started.complete();
              return pending.future;
            });
          },
          act: (bloc) async {
            bloc.add(
              const PeopleListsPicksApplied(
                requestId: 'batch',
                ownerPubkey: _ownerA,
                pubkey: _memberBob,
                addListIds: {'list-1', 'list-2'},
                removeListIds: {'list-3'},
              ),
            );
            await started.future;
            if (switchOwner) {
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerB));
            } else {
              bloc.add(const PeopleListsEnabledChanged(enabled: false));
              await _flush();
              bloc.add(const PeopleListsEnabledChanged(enabled: true));
            }
            await _flush();
            pending.complete(submitted);
          },
          verify: (bloc) {
            verifyNever(
              () => repository.addPubkey(
                ownerPubkey: any(named: 'ownerPubkey'),
                listId: 'list-2',
                pubkey: _memberBob,
              ),
            );
            verifyNever(
              () => repository.removePubkey(
                ownerPubkey: any(named: 'ownerPubkey'),
                listId: 'list-3',
                pubkey: _memberBob,
              ),
            );
            expect(bloc.state.ownerPubkey, switchOwner ? _ownerB : _ownerA);
            expect(bloc.state.pendingMutations, isEmpty);
          },
        );
      }

      for (final transition in ['owner roundtrip', 'feature off/on', 'none']) {
        late Completer<PeopleListPublishResult> pending;
        late Completer<void> started;
        blocTest<PeopleListsBloc, PeopleListsState>(
          transition == 'none'
              ? 'applies a queued batch when its dispatch session stays active'
              : 'cancels a queued batch across $transition before it starts',
          build: buildBloc,
          seed: seeded,
          setUp: () {
            pending = Completer<PeopleListPublishResult>();
            started = Completer<void>();
            when(
              () => repository.addPubkey(
                ownerPubkey: _ownerA,
                listId: 'list-1',
                pubkey: _memberBob,
              ),
            ).thenAnswer((_) {
              started.complete();
              return pending.future;
            });
            stubAdd('list-2', submitted);
            stubRemove('list-3', submitted);
          },
          act: (bloc) async {
            bloc.add(
              const PeopleListsPicksApplied(
                requestId: 'held',
                ownerPubkey: _ownerA,
                pubkey: _memberBob,
                addListIds: {'list-1'},
                removeListIds: {},
              ),
            );
            await started.future;
            final queuedOutcome = bloc.stream.firstWhere(
              (state) => state.lastPicksOutcome?.requestId == 'queued',
            );
            bloc.add(
              const PeopleListsPicksApplied(
                requestId: 'queued',
                ownerPubkey: _ownerA,
                pubkey: _memberBob,
                addListIds: {'list-2'},
                removeListIds: {'list-3'},
              ),
            );
            await _flush();
            if (transition == 'owner roundtrip') {
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerB));
              await _flush();
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerA));
              await _flush();
            } else if (transition == 'feature off/on') {
              bloc.add(const PeopleListsEnabledChanged(enabled: false));
              await _flush();
              bloc.add(const PeopleListsEnabledChanged(enabled: true));
              await _flush();
            }
            if (transition != 'none') {
              bloc.add(
                PeopleListsRepositoryListsChanged(
                  ownerPubkey: _ownerA,
                  lists: seeded().lists,
                ),
              );
              await _flush();
            }
            pending.complete(submitted);
            await queuedOutcome;
          },
          verify: (bloc) {
            Future<PeopleListPublishResult> addCall() => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'list-2',
              pubkey: _memberBob,
            );
            Future<PeopleListPublishResult> removeCall() =>
                repository.removePubkey(
                  ownerPubkey: _ownerA,
                  listId: 'list-3',
                  pubkey: _memberBob,
                );
            if (transition == 'none') {
              verify(addCall).called(1);
              verify(removeCall).called(1);
            } else {
              verifyNever(addCall);
              verifyNever(removeCall);
              expect(bloc.state.listIdsByPubkey[_memberBob], {'list-3'});
            }
            expect(bloc.state.lastPicksOutcome?.requestId, 'queued');
            expect(bloc.state.lastPicksOutcome?.refused, 0);
            expect(bloc.state.ownerPubkey, _ownerA);
            expect(bloc.state.pendingMutations, isEmpty);
          },
        );
      }

      blocTest<PeopleListsBloc, PeopleListsState>(
        'records an outcome even when every pick is a no-op',
        build: buildBloc,
        seed: seeded,
        act: (bloc) => bloc.add(
          const PeopleListsPicksApplied(
            requestId: 'batch',
            ownerPubkey: _ownerA,
            pubkey: _memberBob,
            // Already a member of list-3, so the add is dropped.
            addListIds: {'list-3'},
            removeListIds: {},
          ),
        ),
        verify: (bloc) {
          verifyNever(
            () => repository.addPubkey(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
              pubkey: any(named: 'pubkey'),
            ),
          );
          expect(bloc.state.lastPicksOutcome?.refused, 0);
        },
      );
    });

    group('picks shared queue boundaries', () {
      const picks = PeopleListsPicksApplied(
        requestId: 'shared-queue',
        ownerPubkey: _ownerA,
        pubkey: _memberBob,
        addListIds: {'list-1', 'list-2'},
        removeListIds: {},
      );
      const info = PeopleListsInfoUpdateRequested(
        expectedOwnerPubkey: _ownerA,
        listId: 'list-1',
        name: 'Edited friends',
        description: 'Still here',
      );
      const submitted = PeopleListPublishResult.submitted(
        eventId: _memberAlice,
      );

      Future<PeopleListsBloc> readyBloc() async {
        final bloc = buildBloc(initialOwnerPubkey: _ownerA);
        addTearDown(bloc.close);
        bloc.add(
          PeopleListsRepositoryListsChanged(
            ownerPubkey: _ownerA,
            lists: [
              _buildList(id: 'list-1', name: 'Friends', pubkeys: const []),
              _buildList(id: 'list-2', name: 'Work', pubkeys: const []),
            ],
          ),
        );
        await _flush();
        return bloc;
      }

      void stubInfo(Future<PeopleListPublishResult> Function() answer) {
        when(
          () => repository.updateListInfo(
            ownerPubkey: _ownerA,
            listId: 'list-1',
            name: 'Edited friends',
            description: 'Still here',
          ),
        ).thenAnswer((_) => answer());
      }

      void stubPick(
        String listId,
        Future<PeopleListPublishResult> Function() answer,
      ) {
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: listId,
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) => answer());
      }

      void expectNoPickWrites() {
        verifyNever(
          () => repository.addPubkey(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            pubkey: _memberBob,
          ),
        );
      }

      test('waits for an earlier metadata ACK before starting picks', () async {
        final pending = Completer<PeopleListPublishResult>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(submitted);
        });
        stubInfo(() => pending.future);
        stubPick('list-1', () async => submitted);
        stubPick('list-2', () async => submitted);
        final bloc = await readyBloc();
        final first = bloc.submit(info);
        await _flush();
        final batch = bloc.submit(picks);
        await _flush();
        expectNoPickWrites();
        expect(bloc.state.lastPicksOutcome, isNull);

        pending.complete(submitted);
        expect(await first, PeopleListsOperationResult.succeeded);
        expect(await batch, PeopleListsOperationResult.succeeded);
        expect(bloc.state.lastPicksOutcome?.refused, 0);
        expect(bloc.state.listIdsByPubkey[_memberBob], {'list-1', 'list-2'});
      });

      test(
        'keeps a later metadata edit behind the whole picks request',
        () async {
          final pending = Completer<PeopleListPublishResult>();
          addTearDown(() {
            if (!pending.isCompleted) pending.complete(submitted);
          });
          stubPick('list-1', () => pending.future);
          stubPick('list-2', () async => submitted);
          stubInfo(() async => submitted);
          final bloc = await readyBloc();
          final batch = bloc.submit(picks);
          await _flush();
          final edit = bloc.submit(info);
          await _flush();
          verifyNever(
            () => repository.updateListInfo(
              ownerPubkey: any(named: 'ownerPubkey'),
              listId: any(named: 'listId'),
              name: any(named: 'name'),
              description: any(named: 'description'),
            ),
          );

          pending.complete(submitted);
          expect(await batch, PeopleListsOperationResult.succeeded);
          expect(await edit, PeopleListsOperationResult.succeeded);
          verifyInOrder([
            () => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'list-1',
              pubkey: _memberBob,
            ),
            () => repository.addPubkey(
              ownerPubkey: _ownerA,
              listId: 'list-2',
              pubkey: _memberBob,
            ),
            () => repository.updateListInfo(
              ownerPubkey: _ownerA,
              listId: 'list-1',
              name: 'Edited friends',
              description: 'Still here',
            ),
          ]);
        },
      );

      test('aggregates refusal only after the remaining ACK settles', () async {
        final pending = Completer<PeopleListPublishResult>();
        addTearDown(() {
          if (!pending.isCompleted) pending.complete(submitted);
        });
        stubPick('list-1', () async => const PeopleListPublishResult.failed());
        stubPick('list-2', () => pending.future);
        final bloc = await readyBloc();
        var settled = false;
        final batch = bloc.submit(picks).then((result) {
          settled = true;
          return result;
        });
        await _flush();
        await _flush();
        verify(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'list-2',
            pubkey: _memberBob,
          ),
        ).called(1);
        expect(settled, isFalse);
        expect(bloc.state.lastPicksOutcome, isNull);

        pending.complete(submitted);
        expect(await batch, PeopleListsOperationResult.failed);
        expect(bloc.state.lastPicksOutcome?.refused, 1);
        expect(bloc.state.listIdsByPubkey[_memberBob], {'list-2'});
        expect(bloc.state.pendingMutations, isEmpty);
      });

      for (final boundary in [
        'owner round trip',
        'repository',
        'feature',
        'close',
      ]) {
        test('cancels queued picks at the $boundary boundary', () async {
          final pending = Completer<PeopleListPublishResult>();
          addTearDown(() {
            if (!pending.isCompleted) pending.complete(submitted);
          });
          stubInfo(() => pending.future);
          final bloc = await readyBloc();
          final first = bloc.submit(info);
          await _flush();
          final batch = bloc.submit(picks);
          await _flush();
          final openingEpoch = bloc.mutationSessionEpoch;
          Future<void>? closing;
          switch (boundary) {
            case 'owner round trip':
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerB));
              await _flush();
              bloc.add(const PeopleListsOwnerChanged(ownerPubkey: _ownerA));
            case 'repository':
              final replacement = _MockPeopleListsRepository();
              when(
                () => replacement.watchLists(ownerPubkey: _ownerA),
              ).thenAnswer((_) => const Stream.empty());
              when(
                () => replacement.syncOwner(ownerPubkey: _ownerA),
              ).thenAnswer((_) async {});
              bloc.add(PeopleListsRepositoryChanged(repository: replacement));
            case 'feature':
              bloc.add(const PeopleListsEnabledChanged(enabled: false));
              await _flush();
              bloc.add(const PeopleListsEnabledChanged(enabled: true));
            case 'close':
              closing = bloc.close();
          }
          await _flush();
          expect(bloc.mutationSessionEpoch, greaterThan(openingEpoch));
          expect(await first, PeopleListsOperationResult.cancelled);
          expect(await batch, PeopleListsOperationResult.cancelled);
          expectNoPickWrites();
          expect(bloc.state.lastPicksOutcome, isNull);
          pending.complete(submitted);
          if (closing != null) await closing;
          await _flush();
          expectNoPickWrites();
          expect(bloc.state.lastPicksOutcome, isNull);
        });
      }

      test(
        'rejects picks whose claimed owner differs from the actor',
        () async {
          final bloc = await readyBloc();
          final result = await bloc.submit(
            const PeopleListsPicksApplied(
              requestId: 'other-owner',
              ownerPubkey: _ownerB,
              pubkey: _memberBob,
              addListIds: {'list-1'},
              removeListIds: {},
            ),
          );
          expect(result, PeopleListsOperationResult.cancelled);
          expectNoPickWrites();
          expect(bloc.state.lastPicksOutcome, isNull);
        },
      );

      for (final closeActor in [false, true]) {
        test(
          closeActor
              ? 'close cancels active picks without later writes or stale outcome'
              : 'repository replacement cancels active picks and their stale outcome',
          () async {
            final pending = Completer<PeopleListPublishResult>();
            addTearDown(() {
              if (!pending.isCompleted) pending.complete(submitted);
            });
            stubPick('list-1', () => pending.future);
            final bloc = await readyBloc();
            final batch = bloc.submit(picks);
            await _flush();
            Future<void>? closing;
            if (closeActor) {
              closing = bloc.close();
            } else {
              final replacement = _MockPeopleListsRepository();
              when(
                () => replacement.watchLists(ownerPubkey: _ownerA),
              ).thenAnswer((_) => const Stream.empty());
              when(
                () => replacement.syncOwner(ownerPubkey: _ownerA),
              ).thenAnswer((_) async {});
              bloc.add(PeopleListsRepositoryChanged(repository: replacement));
            }
            await _flush();
            expect(await batch, PeopleListsOperationResult.cancelled);
            pending.complete(submitted);
            if (closing != null) await closing;
            await _flush();
            verifyNever(
              () => repository.addPubkey(
                ownerPubkey: any(named: 'ownerPubkey'),
                listId: 'list-2',
                pubkey: _memberBob,
              ),
            );
            expect(bloc.state.lastPicksOutcome, isNull);
          },
        );
      }
    });

    // #6494: the app-shell BlocProvider is unconditional (#6477), so laziness
    // only gates construction. A bloc built while FeatureFlag.curatedLists was
    // on used to keep its cache subscription and keep calling syncOwner for
    // kind 30000 for the rest of the session after the flag went off.
    group('curated-lists flag lifecycle', () {
      Future<PeopleListsBloc> startedWithOwnerA() async {
        final bloc = buildBloc()..add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        return bloc;
      }

      Future<void> disable() async {
        enabledController.add(false);
        await _flush();
        await _flush();
      }

      test('turning the flag off cancels the lists subscription', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        expect(ownerAListsController.hasListener, isTrue);

        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        await _flush();
        expect(bloc.state.lists, hasLength(1));

        await disable();

        expect(ownerAListsController.hasListener, isFalse);
        expect(bloc.state.lists, isEmpty);
      });

      test('drops a snapshot that crossed the flag-off teardown', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);

        // Same turn, flag first: the cancel is synchronous, but a snapshot the
        // cache already handed over is queued behind the flag event.
        enabledController.add(false);
        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        await _flush();
        await _flush();
        await _flush();

        expect(bloc.state.enabled, isFalse);
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
      });

      test('a later owner change runs no sync while the flag is off', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        await disable();
        clearInteractions(repository);

        ownerPubkeyController.add(_ownerB);
        await _flush();
        await _flush();

        verifyNever(
          () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        );
        verifyNever(
          () => repository.syncFollowedLists(
            viewerPubkey: any(named: 'viewerPubkey'),
            isCancelled: any(named: 'isCancelled'),
          ),
        );
        verifyNever(
          () => repository.watchLists(ownerPubkey: any(named: 'ownerPubkey')),
        );
        expect(ownerBListsController.hasListener, isFalse);
      });

      test(
        'a repository swap runs no sync while off but still lands',
        () async {
          final repositoryController =
              StreamController<PeopleListsRepository>.broadcast();
          addTearDown(repositoryController.close);
          final nextRepository = _MockPeopleListsRepository();
          when(
            () => nextRepository.syncOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          ).thenAnswer((_) async {});
          when(
            () => nextRepository.watchLists(ownerPubkey: _ownerA),
          ).thenAnswer((_) => const Stream<List<UserList>>.empty());

          final bloc = PeopleListsBloc(
            repository: repository,
            ownerPubkeyStream: ownerPubkeyController.stream,
            repositoryStream: repositoryController.stream,
            enabledStream: enabledController.stream,
            clock: _fixedClock,
          )..add(const PeopleListsStarted());
          addTearDown(bloc.close);
          await _flush();
          ownerPubkeyController.add(_ownerA);
          await _flush();
          await disable();

          repositoryController.add(nextRepository);
          await _flush();
          await _flush();

          verifyNever(
            () => nextRepository.syncOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );
          verifyNever(
            () => nextRepository.watchLists(
              ownerPubkey: any(named: 'ownerPubkey'),
            ),
          );

          // The swap must still re-point the field while the feature is off:
          // the flag-on rewires onto whatever `_repository` holds, and the
          // pre-swap instance is bound to a disposed NostrClient (#6480). So
          // `_onRepositoryChanged` deliberately does *not* stand down with the
          // rest of the bloc.
          clearInteractions(repository);
          enabledController.add(true);
          await _flush();
          await _flush();

          verify(
            () => nextRepository.syncOwner(ownerPubkey: _ownerA),
          ).called(1);
          verify(
            () => nextRepository.watchLists(ownerPubkey: _ownerA),
          ).called(1);
          verifyNever(
            () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
          );
        },
      );

      test('mutations publish nothing while the flag is off', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        await disable();

        bloc.add(
          const PeopleListsCreateRequested(
            expectedOwnerPubkey: _ownerA,
            name: 'Friends',
          ),
        );
        await _flush();
        await _flush();

        verifyNever(
          () => repository.createList(
            ownerPubkey: any(named: 'ownerPubkey'),
            name: any(named: 'name'),
          ),
        );
      });

      test('turning the flag back on resubscribes and syncs', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        await disable();
        clearInteractions(repository);

        enabledController.add(true);
        await _flush();
        await _flush();

        expect(ownerAListsController.hasListener, isTrue);
        verify(() => repository.syncOwner(ownerPubkey: _ownerA)).called(1);

        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.lists.single.id, equals('l1'));
      });

      // The flag lives in SharedPreferences, not in auth scope, and
      // `enabledStream` only seeds at subscribe time — so nothing would put
      // `enabled` back to false if a sign-out dropped it. It would silently
      // revert to the field's `true` default and the next sign-in would resume
      // syncing kind 30000 with the feature still off, i.e. #6494 again.
      test('a sign-out while the flag is off keeps the feature off', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        await disable();

        ownerPubkeyController.add(null);
        await _flush();
        await _flush();

        expect(bloc.state.enabled, isFalse);
        expect(bloc.state.ownerPubkey, isNull);

        clearInteractions(repository);
        ownerPubkeyController.add(_ownerB);
        await _flush();
        await _flush();

        verifyNever(
          () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        );
        expect(ownerBListsController.hasListener, isFalse);
      });

      // The owner stream is not seeded, so a flag-on can only learn the current
      // account from state — which is why the bloc keeps following owner changes
      // while it is standing down.
      test('a flag-on syncs the account that signed in while off', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        await disable();

        ownerPubkeyController.add(_ownerB);
        await _flush();
        await _flush();
        clearInteractions(repository);

        enabledController.add(true);
        await _flush();
        await _flush();

        verify(() => repository.syncOwner(ownerPubkey: _ownerB)).called(1);
        verifyNever(() => repository.syncOwner(ownerPubkey: _ownerA));
        expect(ownerBListsController.hasListener, isTrue);
        expect(ownerAListsController.hasListener, isFalse);
      });
    });

    // A rollback undoes only its own mutation. `_onRepositoryListsChanged`
    // keeps `pendingMutations`, so an emission that lands mid-round-trip
    // passes the teardown guard — restoring a pre-flight snapshot there would
    // drop whatever arrived meanwhile.
    group('rollbacks that race a repository emission', () {
      Future<PeopleListsBloc> startedWithOwnerALists(
        List<UserList> lists,
      ) async {
        final bloc = buildBloc()..add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add(lists);
        await _flush();
        return bloc;
      }

      test('a failed delete keeps a list that synced mid-round-trip', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.deleteList(ownerPubkey: _ownerA, listId: 'l1'),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerALists([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        addTearDown(bloc.close);

        bloc.add(const PeopleListsDeleteRequested(listId: 'l1'));
        await _flush();
        expect(bloc.state.lists, isEmpty);

        // l3 arrives from a relay while the deletion is still publishing.
        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
          _buildList(id: 'l3', name: 'From Relay', pubkeys: const [_memberBob]),
        ]);
        await _flush();

        publish.complete(const PeopleListPublishResult.failed());
        await _flush();
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(
          bloc.state.lists.map((list) => list.id).toList(),
          equals(['l1', 'l3']),
        );
        expect(
          bloc.state.listIdsByPubkey,
          equals({
            _memberAlice: {'l1'},
            _memberBob: {'l3'},
          }),
        );
      });

      test('a failed add undoes only its own pubkey', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerALists([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyAddRequested(listId: 'l1', pubkey: _memberBob),
        );
        await _flush();
        expect(bloc.state.lists.single.pubkeys, contains(_memberBob));

        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
          _buildList(id: 'l3', name: 'From Relay', pubkeys: const [_memberBob]),
        ]);
        await _flush();

        publish.complete(const PeopleListPublishResult.failed());
        await _flush();
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        expect(
          bloc.state.lists.map((list) => list.id).toList(),
          equals(['l1', 'l3']),
        );
        // Undone on l1, untouched on the list that arrived meanwhile.
        expect(bloc.state.lists.first.pubkeys, equals([_memberAlice]));
        expect(bloc.state.lists.last.pubkeys, equals([_memberBob]));
      });

      test('a failed remove restores the member at its old index', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerALists([
          _buildList(
            id: 'l1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ]);
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        );
        await _flush();
        expect(bloc.state.lists.single.pubkeys, equals([_memberBob]));

        publish.complete(const PeopleListPublishResult.failed());
        await _flush();
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.failure));
        // Back at index 0, not appended after bob.
        expect(
          bloc.state.lists.single.pubkeys,
          equals([_memberAlice, _memberBob]),
        );
      });

      test('a reconciled add noop keeps the relay member', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerALists([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyAddRequested(listId: 'l1', pubkey: _memberBob),
        );
        await _flush();

        // Reconciliation discovers that another client already added Bob.
        ownerAListsController.add([
          _buildList(
            id: 'l1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ]);
        await _flush();

        publish.complete(const PeopleListPublishResult.noop());
        await _flush();
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(
          bloc.state.lists.single.pubkeys,
          equals([_memberAlice, _memberBob]),
        );
        expect(bloc.state.pendingMutations, isEmpty);
      });

      test('a reconciled remove noop keeps the relay removal', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerALists([
          _buildList(
            id: 'l1',
            name: 'Friends',
            pubkeys: const [_memberAlice, _memberBob],
          ),
        ]);
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        );
        await _flush();

        // Reconciliation discovers that another client already removed Alice.
        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberBob]),
        ]);
        await _flush();

        publish.complete(const PeopleListPublishResult.noop());
        await _flush();
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.lists.single.pubkeys, equals([_memberBob]));
        expect(bloc.state.pendingMutations, isEmpty);
      });
    });

    // #6504: rollbacks are computed from a snapshot captured before the
    // repository round-trip. A teardown in between — flag-off or account
    // switch — drops that snapshot on purpose, so applying it afterwards puts
    // one owner's lists back under whoever is signed in by then.
    group('mutation results that outlive the state they were issued for', () {
      Future<PeopleListsBloc> startedWithOwnerAList() async {
        final bloc = buildBloc()..add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        ownerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        await _flush();
        return bloc;
      }

      test('a delete rollback discards a flag-off teardown snapshot', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.deleteList(ownerPubkey: _ownerA, listId: 'l1'),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerAList();
        addTearDown(bloc.close);

        bloc.add(const PeopleListsDeleteRequested(listId: 'l1'));
        await _flush();
        expect(bloc.state.pendingMutations, hasLength(1));

        enabledController.add(false);
        await _flush();
        await _flush();

        publish.complete(const PeopleListPublishResult.failed());
        await _flush();
        await _flush();

        expect(bloc.state.enabled, isFalse);
        expect(bloc.state.status, equals(PeopleListsStatus.initial));
        expect(bloc.state.lists, isEmpty);
        expect(bloc.state.listIdsByPubkey, isEmpty);
        expect(bloc.state.pendingMutations, isEmpty);
      });

      test(
        'a delete rollback leaves the account that took over alone',
        () async {
          final publish = Completer<PeopleListPublishResult>();
          when(
            () => repository.deleteList(ownerPubkey: _ownerA, listId: 'l1'),
          ).thenAnswer((_) => publish.future);

          final bloc = await startedWithOwnerAList();
          addTearDown(bloc.close);

          bloc.add(const PeopleListsDeleteRequested(listId: 'l1'));
          await _flush();

          ownerPubkeyController.add(_ownerB);
          await _flush();
          await _flush();
          ownerBListsController.add([
            _buildList(id: 'l2', name: 'Crew', pubkeys: const [_memberBob]),
          ]);
          await _flush();

          publish.complete(const PeopleListPublishResult.failed());
          await _flush();
          await _flush();

          expect(bloc.state.ownerPubkey, equals(_ownerB));
          expect(bloc.state.status, equals(PeopleListsStatus.ready));
          expect(bloc.state.lists.single.id, equals('l2'));
          expect(
            bloc.state.listIdsByPubkey,
            equals({
              _memberBob: {'l2'},
            }),
          );
          expect(bloc.state.pendingMutations, isEmpty);
        },
      );

      test('an add that throws after a teardown restores nothing', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.addPubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberBob,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerAList();
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyAddRequested(listId: 'l1', pubkey: _memberBob),
        );
        await _flush();
        expect(bloc.state.lists.single.pubkeys, contains(_memberBob));

        enabledController.add(false);
        await _flush();
        await _flush();

        publish.completeError(StateError('no public key available'));
        await _flush();
        await _flush();

        expect(bloc.state.enabled, isFalse);
        expect(bloc.state.status, equals(PeopleListsStatus.initial));
        expect(bloc.state.lists, isEmpty);
      });

      test('a remove that throws after a teardown restores nothing', () async {
        final publish = Completer<PeopleListPublishResult>();
        when(
          () => repository.removePubkey(
            ownerPubkey: _ownerA,
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        ).thenAnswer((_) => publish.future);

        final bloc = await startedWithOwnerAList();
        addTearDown(bloc.close);

        bloc.add(
          const PeopleListsPubkeyRemoveRequested(
            listId: 'l1',
            pubkey: _memberAlice,
          ),
        );
        await _flush();
        expect(bloc.state.lists.single.pubkeys, isEmpty);

        enabledController.add(false);
        await _flush();
        await _flush();

        publish.completeError(StateError('relay rejected removal'));
        await _flush();
        await _flush();

        expect(bloc.state.enabled, isFalse);
        expect(bloc.state.status, equals(PeopleListsStatus.initial));
        expect(bloc.state.lists, isEmpty);
      });

      // Create captures no snapshot, so all it can leak is a status — but a
      // `failure` (or `ready`) written onto a torn-down state still reports an
      // outcome the account now in state never asked for.
      test(
        'a create that resolves after a teardown writes no status',
        () async {
          final publish = Completer<PeopleListPublishResult>();
          when(
            () => repository.createList(ownerPubkey: _ownerA, name: 'Crew'),
          ).thenAnswer((_) => publish.future);

          final bloc = await startedWithOwnerAList();
          addTearDown(bloc.close);

          bloc.add(
            const PeopleListsCreateRequested(
              expectedOwnerPubkey: _ownerA,
              name: 'Crew',
            ),
          );
          await _flush();
          expect(bloc.state.pendingMutations, hasLength(1));

          enabledController.add(false);
          await _flush();
          await _flush();

          publish.complete(const PeopleListPublishResult.failed());
          await _flush();
          await _flush();

          expect(bloc.state.enabled, isFalse);
          expect(bloc.state.status, equals(PeopleListsStatus.initial));
          expect(bloc.state.pendingMutations, isEmpty);
        },
      );
    });

    // #6480: peopleListsRepositoryProvider is keepAlive but not
    // identity-stable — it watches nostrServiceProvider, whose client is
    // disposed on every identity change. The app-shell BlocProvider.create
    // runs once, so without these the bloc keeps calling a disposed client,
    // where queryEvents returns [] and syncOwner silently stops working.
    group('repository identity swap', () {
      late _MockPeopleListsRepository nextRepository;
      late StreamController<PeopleListsRepository> repositoryController;
      late StreamController<List<UserList>> nextOwnerAListsController;

      setUp(() {
        nextRepository = _MockPeopleListsRepository();
        repositoryController =
            StreamController<PeopleListsRepository>.broadcast();
        nextOwnerAListsController =
            StreamController<List<UserList>>.broadcast();

        when(
          () => nextRepository.watchLists(ownerPubkey: _ownerA),
        ).thenAnswer((_) => nextOwnerAListsController.stream);
        when(
          () =>
              nextRepository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        ).thenAnswer((_) async {});
      });

      tearDown(() async {
        await repositoryController.close();
        if (!nextOwnerAListsController.isClosed) {
          await nextOwnerAListsController.close();
        }
      });

      PeopleListsBloc buildSwappableBloc() {
        return PeopleListsBloc(
          repository: repository,
          ownerPubkeyStream: ownerPubkeyController.stream,
          repositoryStream: repositoryController.stream,
          enabledStream: enabledController.stream,
          clock: _fixedClock,
        );
      }

      Future<PeopleListsBloc> startedWithOwnerA() async {
        final bloc = buildSwappableBloc()..add(const PeopleListsStarted());
        await _flush();
        ownerPubkeyController.add(_ownerA);
        await _flush();
        return bloc;
      }

      test(
        're-runs syncOwner on the new repository for the current owner',
        () async {
          final bloc = await startedWithOwnerA();
          addTearDown(bloc.close);
          clearInteractions(repository);

          repositoryController.add(nextRepository);
          await _flush();

          verify(
            () => nextRepository.syncOwner(ownerPubkey: _ownerA),
          ).called(1);
          verifyNever(
            () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
          );
        },
      );

      test('moves the lists subscription onto the new repository', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        expect(ownerAListsController.hasListener, isTrue);

        repositoryController.add(nextRepository);
        await _flush();

        expect(ownerAListsController.hasListener, isFalse);
        expect(nextOwnerAListsController.hasListener, isTrue);
      });

      test('routes later list snapshots through the new repository', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);

        repositoryController.add(nextRepository);
        await _flush();

        nextOwnerAListsController.add([
          _buildList(id: 'l1', name: 'Friends', pubkeys: const [_memberAlice]),
        ]);
        await _flush();

        expect(bloc.state.status, equals(PeopleListsStatus.ready));
        expect(bloc.state.lists.single.name, equals('Friends'));
        expect(bloc.state.listIdsByPubkey[_memberAlice], equals({'l1'}));
      });

      test(
        'keeps the visible lists across the swap (no loading flicker)',
        () async {
          final bloc = await startedWithOwnerA();
          addTearDown(bloc.close);

          ownerAListsController.add([
            _buildList(
              id: 'l1',
              name: 'Friends',
              pubkeys: const [_memberAlice],
            ),
          ]);
          await _flush();
          expect(bloc.state.status, equals(PeopleListsStatus.ready));

          final emitted = <PeopleListsStatus>[];
          final subscription = bloc.stream.listen((s) => emitted.add(s.status));
          addTearDown(subscription.cancel);

          repositoryController.add(nextRepository);
          await _flush();

          // The swap fires on every cold-start auth flip; blanking the state
          // would flicker PeopleListMembershipIndicator on every profile header.
          expect(emitted, isNot(contains(PeopleListsStatus.loading)));
          expect(bloc.state.lists.single.name, equals('Friends'));
        },
      );

      test(
        'ignores a re-emission of the repository it already holds',
        () async {
          final bloc = await startedWithOwnerA();
          addTearDown(bloc.close);
          clearInteractions(repository);

          // The app-shell stream is seeded with the current instance, so the
          // very first emission is always the one the bloc was built with.
          repositoryController.add(repository);
          await _flush();

          verifyNever(
            () => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
          );
          expect(ownerAListsController.hasListener, isTrue);
        },
      );

      test('does not subscribe or sync while unauthenticated', () async {
        final bloc = buildSwappableBloc()..add(const PeopleListsStarted());
        addTearDown(bloc.close);
        await _flush();

        repositoryController.add(nextRepository);
        await _flush();

        verifyNever(
          () =>
              nextRepository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')),
        );
        expect(nextOwnerAListsController.hasListener, isFalse);
      });

      test('a later owner change uses the swapped-in repository', () async {
        final bloc = await startedWithOwnerA();
        addTearDown(bloc.close);
        final nextOwnerBLists = StreamController<List<UserList>>.broadcast();
        addTearDown(nextOwnerBLists.close);
        when(
          () => nextRepository.watchLists(ownerPubkey: _ownerB),
        ).thenAnswer((_) => nextOwnerBLists.stream);

        repositoryController.add(nextRepository);
        await _flush();
        ownerPubkeyController.add(_ownerB);
        await _flush();

        verify(() => nextRepository.syncOwner(ownerPubkey: _ownerB)).called(1);
        expect(nextOwnerBLists.hasListener, isTrue);
        expect(ownerBListsController.hasListener, isFalse);
      });

      // An account switch fires both streams at once. `sequential()` orders
      // events only within a bucket, so an owner change and a repository swap
      // land in different buckets and can interleave. When the swap re-opened
      // the subscription itself, that interleave left the previous owner's
      // subscription live on the incoming account's repository — and it
      // outlived close(), because close() cancels only whatever happens to sit
      // in the field at the time.
      test(
        'a same-turn owner change and repository swap leave no orphan',
        () async {
          final bloc = await startedWithOwnerA();
          addTearDown(bloc.close);
          final nextOwnerBLists = StreamController<List<UserList>>.broadcast();
          addTearDown(nextOwnerBLists.close);
          when(
            () => nextRepository.watchLists(ownerPubkey: _ownerB),
          ).thenAnswer((_) => nextOwnerBLists.stream);
          clearInteractions(nextRepository);

          ownerPubkeyController.add(_ownerB);
          repositoryController.add(nextRepository);
          await _flush();
          await _flush();
          await _flush();

          // The account being left is never queried on the incoming account's
          // client.
          verifyNever(() => nextRepository.syncOwner(ownerPubkey: _ownerA));
          expect(nextOwnerAListsController.hasListener, isFalse);
          expect(nextOwnerBLists.hasListener, isTrue);

          await bloc.close();
          await _flush();

          // close() cancels every subscription the bloc opened, not just the one
          // that happened to win the field.
          expect(ownerAListsController.hasListener, isFalse);
          expect(ownerBListsController.hasListener, isFalse);
          expect(nextOwnerAListsController.hasListener, isFalse);
          expect(nextOwnerBLists.hasListener, isFalse);
        },
      );
    });
  });
}
