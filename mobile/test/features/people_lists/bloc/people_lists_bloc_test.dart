// ABOUTME: Unit tests for PeopleListsBloc global owner-scoped lists state.
// ABOUTME: Covers auth transitions, optimistic mutations, and submitted state.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _MockPeopleListsRepository extends Mock
    implements PeopleListsRepository {}

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

Future<void> _flush() => Future<void>.delayed(Duration.zero);

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
      'emits optimistic state for add pubkey before repository returns',
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
      'emits optimistic state for remove pubkey before repository returns',
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
      act: (bloc) =>
          bloc.add(const PeopleListsCreateRequested(name: 'New List')),
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

        bloc.add(const PeopleListsCreateRequested(name: 'Friends'));
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

          bloc.add(const PeopleListsCreateRequested(name: 'Crew'));
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
