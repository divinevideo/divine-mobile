// ABOUTME: Tests for PeopleListInfoCubit: the form's values and how a save
// ABOUTME: of a people list's name and description ends.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

class _MockPeopleListsBloc extends MockBloc<PeopleListsEvent, PeopleListsState>
    implements PeopleListsBloc {}

// Full-length 64-char pubkey — never truncate.
final String _ownerPubkey = 'f' * 64;

UserList _list({String? description}) => UserList(
  id: 'punk-friends',
  name: 'Punk Friends',
  description: description,
  pubkeys: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      PeopleListsInfoUpdateRequested(
        expectedOwnerPubkey: _ownerPubkey,
        listId: 'fallback',
        name: 'Fallback',
      ),
    );
  });
  group(PeopleListInfoCubit, () {
    late _MockPeopleListsBloc mutations;

    setUp(() {
      mutations = _MockPeopleListsBloc();
    });

    tearDown(() async => mutations.close());

    PeopleListInfoCubit buildCubit({String? description}) =>
        PeopleListInfoCubit(
          submitMutation: mutations.submit,
          currentOwnerPubkey: () => _ownerPubkey,
          ownerPubkey: _ownerPubkey,
          list: _list(description: description),
        );

    void stubUpdate(Future<PeopleListsOperationResult> Function() answer) {
      when(
        () => mutations.submit(any()),
      ).thenAnswer((_) => answer());
    }

    test(
      'blocks a stale account before saving and after a late outcome',
      () async {
        var owner = _ownerPubkey;
        final answer = Completer<PeopleListsOperationResult>();
        stubUpdate(() => answer.future);
        final cubit = PeopleListInfoCubit(
          submitMutation: mutations.submit,
          ownerPubkey: _ownerPubkey,
          currentOwnerPubkey: () => owner,
          list: _list(),
        );
        addTearDown(cubit.close);
        final pending = cubit.submitted();
        owner = 'b' * 64;
        answer.complete(PeopleListsOperationResult.succeeded);
        expect(await pending, PeopleListInfoStatus.failure);
        expect(cubit.state.canClose, isFalse);
        await cubit.submitted();
        verify(
          () => mutations.submit(
            PeopleListsInfoUpdateRequested(
              expectedOwnerPubkey: _ownerPubkey,
              listId: _list().id,
              name: _list().name,
              description: '',
            ),
          ),
        ).called(1);
      },
    );

    group('initial state', () {
      test("opens on the list's own values", () {
        final cubit = buildCubit(description: 'The early crew');
        addTearDown(cubit.close);

        expect(
          cubit.state,
          equals(
            const PeopleListInfoState(
              name: 'Punk Friends',
              description: 'The early crew',
            ),
          ),
        );
        expect(cubit.state.canSubmit, isTrue);
      });

      test('shows an absent description as empty', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state.description, isEmpty);
      });
    });

    group('nameChanged', () {
      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'records the name and clears a failed save',
        build: buildCubit,
        seed: () => const PeopleListInfoState(
          name: 'Punk Friends',
          description: '',
          status: PeopleListInfoStatus.failure,
        ),
        act: (cubit) => cubit.nameChanged('Punk Family'),
        expect: () => const [
          PeopleListInfoState(name: 'Punk Family', description: ''),
        ],
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'leaves a name of spaces unsubmittable',
        build: buildCubit,
        act: (cubit) => cubit.nameChanged('   '),
        verify: (cubit) => expect(cubit.state.canSubmit, isFalse),
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'is ignored while a save is running',
        build: buildCubit,
        seed: () => const PeopleListInfoState(
          name: 'Punk Friends',
          description: '',
          status: PeopleListInfoStatus.saving,
        ),
        act: (cubit) => cubit.nameChanged('Punk Family'),
        expect: () => const <PeopleListInfoState>[],
      );
    });

    group('descriptionChanged', () {
      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'records the description',
        build: buildCubit,
        act: (cubit) => cubit.descriptionChanged('The whole family'),
        expect: () => const [
          PeopleListInfoState(
            name: 'Punk Friends',
            description: 'The whole family',
          ),
        ],
      );
    });

    group('submitted', () {
      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'does nothing while the list has no name',
        build: buildCubit,
        seed: () => const PeopleListInfoState(name: ' ', description: ''),
        act: (cubit) => cubit.submitted(),
        expect: () => const <PeopleListInfoState>[],
        verify: (_) => verifyZeroInteractions(mutations),
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'publishes the values as typed and closes once submitted',
        setUp: () => stubUpdate(
          () async => PeopleListsOperationResult.succeeded,
        ),
        build: () => buildCubit(description: 'The early crew'),
        act: (cubit) async {
          cubit
            ..nameChanged('Punk Family ')
            ..descriptionChanged(' The whole family');
          await cubit.submitted();
        },
        skip: 2,
        expect: () => const [
          PeopleListInfoState(
            name: 'Punk Family ',
            description: ' The whole family',
            status: PeopleListInfoStatus.saving,
          ),
          PeopleListInfoState(
            name: 'Punk Family ',
            description: ' The whole family',
            status: PeopleListInfoStatus.saved,
          ),
        ],
        verify: (cubit) {
          expect(cubit.state.canClose, isTrue);
          verify(
            () => mutations.submit(
              PeopleListsInfoUpdateRequested(
                expectedOwnerPubkey: _ownerPubkey,
                listId: 'punk-friends',
                name: 'Punk Family ',
                description: ' The whole family',
              ),
            ),
          ).called(1);
        },
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'closes on a save that changed nothing',
        setUp: () =>
            stubUpdate(() async => PeopleListsOperationResult.succeeded),
        build: buildCubit,
        act: (cubit) => cubit.submitted(),
        verify: (cubit) =>
            expect(cubit.state.status, PeopleListInfoStatus.saved),
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'stays open when the relay refuses the save',
        setUp: () => stubUpdate(() async => PeopleListsOperationResult.failed),
        build: buildCubit,
        act: (cubit) => cubit.submitted(),
        expect: () => const [
          PeopleListInfoState(
            name: 'Punk Friends',
            description: '',
            status: PeopleListInfoStatus.saving,
          ),
          PeopleListInfoState(
            name: 'Punk Friends',
            description: '',
            status: PeopleListInfoStatus.failure,
          ),
        ],
        verify: (cubit) => expect(cubit.state.canClose, isFalse),
      );

      blocTest<PeopleListInfoCubit, PeopleListInfoState>(
        'stays open when the save throws',
        setUp: () => stubUpdate(() async => throw Exception('relay down')),
        build: buildCubit,
        act: (cubit) => cubit.submitted(),
        verify: (cubit) =>
            expect(cubit.state.status, PeopleListInfoStatus.failure),
        errors: () => [isA<Exception>()],
      );
    });
  });
}
