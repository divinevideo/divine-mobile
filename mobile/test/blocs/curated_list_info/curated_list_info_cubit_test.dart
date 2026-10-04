// ABOUTME: Tests for CuratedListInfoCubit: the form's values, which
// ABOUTME: collaborators a pick keeps, and how each kind of save ends.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

// Full-length 64-char pubkeys — never truncate.
final String _viewer = 'f' * 64;
final String _alice = 'a' * 64;
final String _bob = 'b' * 64;
final String _carol = 'c' * 64;

const String _videoEventId =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

CuratedList _list({
  bool isPublic = true,
  List<String> collaborators = const [],
}) => CuratedList(
  id: 'list-1',
  pubkey: _viewer,
  name: 'Puppets',
  description: 'Strings attached',
  videoEventIds: const [],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  isPublic: isPublic,
  isCollaborative: collaborators.isNotEmpty,
  allowedCollaborators: collaborators,
);

void main() {
  group(CuratedListInfoCubit, () {
    late _MockCuratedListService service;

    setUp(() {
      service = _MockCuratedListService();
      when(() => service.getListById(any())).thenAnswer((_) => _list());
    });

    CuratedListInfoCubit buildCubit({
      CuratedList? existingList,
      String? videoEventId,
      bool withService = true,
    }) => CuratedListInfoCubit(
      currentOwnerPubkey: () => _viewer,
      resolveService: () => withService ? service : null,
      existingList: existingList,
      videoEventId: videoEventId,
    );

    void stubCreate(Future<CuratedList?> Function() answer) {
      when(
        () => service.createList(
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
        ),
      ).thenAnswer((_) => answer());
    }

    void stubUpdate(Future<bool> Function() answer) {
      when(
        () => service.updateList(
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
          onLocalSaved: any(named: 'onLocalSaved'),
        ),
      ).thenAnswer((invocation) {
        (invocation.namedArguments[#onLocalSaved] as void Function()?)?.call();
        return answer();
      });
    }

    test(
      'looks the service up when a save starts, not when it is built',
      () async {
        CuratedListService? current;
        final cubit = CuratedListInfoCubit(
          currentOwnerPubkey: () => _viewer,
          resolveService: () => current,
        );
        addTearDown(cubit.close);
        cubit.nameChanged('Puppets');
        stubCreate(() async => _list());

        current = service;
        await cubit.submitted();

        expect(cubit.state.status, equals(CuratedListInfoStatus.saved));
        verify(() => service.createList(name: 'Puppets')).called(1);
      },
    );

    test(
      'a direct editor visit cannot save after its account changes',
      () async {
        var owner = _viewer;
        final cubit = CuratedListInfoCubit(
          resolveService: () => service,
          currentOwnerPubkey: () => owner,
          existingList: _list(),
        );
        addTearDown(cubit.close);
        cubit.nameChanged('Account A title');
        owner = _alice;
        await cubit.submitted();
        expect(cubit.state.status, CuratedListInfoStatus.failure);
        verifyNever(
          () => service.updateList(
            listId: any(named: 'listId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
            isPublic: any(named: 'isPublic'),
            isCollaborative: any(named: 'isCollaborative'),
            allowedCollaborators: any(named: 'allowedCollaborators'),
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        );
      },
    );

    test('a legacy source with no established author fails closed', () async {
      final legacy = CuratedList(
        id: 'legacy',
        name: 'Legacy',
        videoEventIds: const [],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final cubit = buildCubit(existingList: legacy);
      addTearDown(cubit.close);
      await cubit.submitted();
      expect(cubit.state.status, CuratedListInfoStatus.failure);
    });

    group('initial state', () {
      test('opens empty and public when creating', () {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state, equals(const CuratedListInfoState()));
        expect(cubit.state.isEditing, isFalse);
      });

      test("opens on the list's own values when editing", () {
        final cubit = buildCubit(
          existingList: _list(isPublic: false, collaborators: [_alice]),
        );
        addTearDown(cubit.close);

        expect(
          cubit.state,
          equals(
            CuratedListInfoState(
              name: 'Puppets',
              description: 'Strings attached',
              isPublic: false,
              collaboratorPubkeys: [_alice],
              wasPublic: false,
            ),
          ),
        );
        expect(cubit.state.isEditing, isTrue);
      });
    });

    group('nameChanged', () {
      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'records the name and makes the form submittable',
        build: buildCubit,
        act: (cubit) => cubit.nameChanged('Marionettes'),
        expect: () => const [CuratedListInfoState(name: 'Marionettes')],
        verify: (cubit) => expect(cubit.state.canSubmit, isTrue),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'leaves a name of spaces unsubmittable',
        build: buildCubit,
        act: (cubit) => cubit.nameChanged('   '),
        verify: (cubit) => expect(cubit.state.canSubmit, isFalse),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'clears a failed save',
        build: buildCubit,
        seed: () => const CuratedListInfoState(
          status: CuratedListInfoStatus.failure,
          name: 'Puppet',
        ),
        act: (cubit) => cubit.nameChanged('Puppets'),
        expect: () => const [CuratedListInfoState(name: 'Puppets')],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'is ignored while a save is running',
        build: buildCubit,
        seed: () => const CuratedListInfoState(
          status: CuratedListInfoStatus.saving,
          name: 'Puppets',
        ),
        act: (cubit) => cubit.nameChanged('Marionettes'),
        expect: () => const <CuratedListInfoState>[],
      );
    });

    group('descriptionChanged', () {
      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'records the description',
        build: buildCubit,
        act: (cubit) => cubit.descriptionChanged('Strings attached'),
        expect: () => const [
          CuratedListInfoState(description: 'Strings attached'),
        ],
      );
    });

    group('visibilityChanged', () {
      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'flags a change on an existing list and none back at its own value',
        build: () => buildCubit(existingList: _list()),
        act: (cubit) => cubit
          ..visibilityChanged(isPublic: false)
          ..visibilityChanged(isPublic: true),
        verify: (cubit) {
          expect(cubit.state.isPublic, isTrue);
          expect(cubit.state.visibilityWillChange, isFalse);
        },
        expect: () => [
          isA<CuratedListInfoState>()
              .having((s) => s.isPublic, 'isPublic', isFalse)
              .having(
                (s) => s.visibilityWillChange,
                'visibilityWillChange',
                isTrue,
              ),
          isA<CuratedListInfoState>()
              .having((s) => s.isPublic, 'isPublic', isTrue)
              .having(
                (s) => s.visibilityWillChange,
                'visibilityWillChange',
                isFalse,
              ),
        ],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'never flags a change on a list that does not exist yet',
        build: buildCubit,
        act: (cubit) => cubit.visibilityChanged(isPublic: false),
        verify: (cubit) {
          expect(cubit.state.isPublic, isFalse);
          expect(cubit.state.visibilityWillChange, isFalse);
        },
      );
    });

    group('collaboratorsPicked', () {
      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'replaces the offered collaborators with the picked ones',
        build: () =>
            buildCubit(existingList: _list(collaborators: [_alice, _bob])),
        act: (cubit) => cubit.collaboratorsPicked(
          offered: {_alice, _bob},
          picked: {_bob, _carol},
        ),
        verify: (cubit) => expect(
          cubit.state.collaboratorPubkeys,
          unorderedEquals([_bob, _carol]),
        ),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'keeps a collaborator the picker was never offered',
        build: () =>
            buildCubit(existingList: _list(collaborators: [_alice, _bob])),
        act: (cubit) => cubit.collaboratorsPicked(
          // Bob's profile had not resolved, so the picker never showed him.
          offered: {_alice},
          picked: {_alice, _carol},
        ),
        verify: (cubit) => expect(
          cubit.state.collaboratorPubkeys,
          unorderedEquals([_alice, _bob, _carol]),
        ),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        "drops the owner's own key",
        build: buildCubit,
        act: (cubit) => cubit.collaboratorsPicked(
          offered: const {},
          picked: {_viewer.toUpperCase(), _alice},
          viewerPubkey: _viewer,
        ),
        verify: (cubit) =>
            expect(cubit.state.collaboratorPubkeys, equals([_alice])),
      );
    });

    group('submitted', () {
      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'does nothing while the list has no name',
        build: buildCubit,
        act: (cubit) => cubit.submitted(),
        expect: () => const <CuratedListInfoState>[],
        verify: (_) => verifyZeroInteractions(service),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'creates the list from the trimmed values',
        setUp: () => stubCreate(() async => _list()),
        build: buildCubit,
        seed: () => const CuratedListInfoState(
          name: '  Puppets  ',
          description: '   ',
        ),
        act: (cubit) => cubit.submitted(),
        expect: () => const [
          CuratedListInfoState(
            status: CuratedListInfoStatus.saving,
            name: '  Puppets  ',
            description: '   ',
          ),
          CuratedListInfoState(
            status: CuratedListInfoStatus.saved,
            name: '  Puppets  ',
            description: '   ',
          ),
        ],
        verify: (_) {
          verify(
            () => service.createList(name: 'Puppets'),
          ).called(1);
          verifyNever(() => service.addVideoToList(any(), any()));
        },
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'creates a collaborative list when collaborators are picked',
        setUp: () => stubCreate(() async => _list()),
        build: buildCubit,
        seed: () => CuratedListInfoState(
          name: 'Puppets',
          collaboratorPubkeys: [_alice, _bob],
        ),
        act: (cubit) => cubit.submitted(),
        verify: (_) => verify(
          () => service.createList(
            name: 'Puppets',
            isCollaborative: true,
            allowedCollaborators: [_alice, _bob],
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'saves no collaborators on a private list',
        setUp: () => stubCreate(() async => _list(isPublic: false)),
        build: buildCubit,
        seed: () => CuratedListInfoState(
          name: 'Puppets',
          isPublic: false,
          collaboratorPubkeys: [_alice],
        ),
        act: (cubit) => cubit.submitted(),
        verify: (_) => verify(
          () => service.createList(name: 'Puppets', isPublic: false),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'adds the video to the list it created',
        setUp: () {
          stubCreate(() async => _list());
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => true);
        },
        build: () => buildCubit(videoEventId: _videoEventId),
        seed: () => const CuratedListInfoState(name: 'Puppets'),
        act: (cubit) => cubit.submitted(),
        verify: (cubit) {
          expect(cubit.state.status, equals(CuratedListInfoStatus.saved));
          verify(
            () => service.addVideoToList('list-1', _videoEventId),
          ).called(1);
        },
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'closes on createdWithoutVideo when the list exists but refused the '
        'video, rather than saved or a failure that invites a second list',
        setUp: () {
          stubCreate(() async => _list());
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => false);
        },
        build: () => buildCubit(videoEventId: _videoEventId),
        seed: () => const CuratedListInfoState(name: 'Puppets'),
        act: (cubit) => cubit.submitted(),
        verify: (cubit) {
          expect(
            cubit.state.status,
            equals(CuratedListInfoStatus.createdWithoutVideo),
          );
          expect(cubit.state.canClose, isTrue);
        },
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'fails, adding no video, when the list could not be created',
        setUp: () => stubCreate(() async => null),
        build: () => buildCubit(videoEventId: _videoEventId),
        seed: () => const CuratedListInfoState(name: 'Puppets'),
        act: (cubit) => cubit.submitted(),
        expect: () => const [
          CuratedListInfoState(
            status: CuratedListInfoStatus.saving,
            name: 'Puppets',
          ),
          CuratedListInfoState(
            status: CuratedListInfoStatus.failure,
            name: 'Puppets',
          ),
        ],
        verify: (_) => verifyNever(() => service.addVideoToList(any(), any())),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'fails when the list service is unavailable',
        build: () => buildCubit(withService: false),
        seed: () => const CuratedListInfoState(name: 'Puppets'),
        act: (cubit) => cubit.submitted(),
        expect: () => const [
          CuratedListInfoState(
            status: CuratedListInfoStatus.saving,
            name: 'Puppets',
          ),
          CuratedListInfoState(
            status: CuratedListInfoStatus.failure,
            name: 'Puppets',
          ),
        ],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'lets a rename close before the relay answers',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list()),
        act: (cubit) async {
          cubit.nameChanged('Marionettes');
          await cubit.submitted();
        },
        skip: 1,
        expect: () => [
          isA<CuratedListInfoState>().having(
            (s) => s.status,
            'status',
            CuratedListInfoStatus.saving,
          ),
          isA<CuratedListInfoState>()
              .having(
                (s) => s.status,
                'status',
                CuratedListInfoStatus.savedAwaitingRelay,
              )
              .having((s) => s.canClose, 'canClose', isTrue),
          isA<CuratedListInfoState>().having(
            (s) => s.status,
            'status',
            CuratedListInfoStatus.saved,
          ),
        ],
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Marionettes',
            description: 'Strings attached',
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'sends no visibility when the owner did not flip it',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list()),
        act: (cubit) async {
          cubit.nameChanged('Marionettes');
          await cubit.submitted();
        },
        // The sheet can be open on a list whose visibility changed since, so
        // resending what it opened with would flip the list straight back.
        // Leaving isPublic out of the matcher pins it to null.
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Marionettes',
            description: 'Strings attached',
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'sends no visibility when a private list is only renamed',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list(isPublic: false)),
        act: (cubit) async {
          cubit.nameChanged('Marionettes');
          await cubit.submitted();
        },
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Marionettes',
            description: 'Strings attached',
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'leaves the stored collaborators alone when they were not edited',
        setUp: () => stubUpdate(() async => true),
        build: () =>
            buildCubit(existingList: _list(collaborators: [_alice, _bob])),
        act: (cubit) async {
          cubit
            ..nameChanged('Marionettes')
            // Confirming the picker on the same people, in another order,
            // is not an edit.
            ..collaboratorsPicked(
              offered: {_alice, _bob},
              picked: {_bob, _alice},
            );
          await cubit.submitted();
        },
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Marionettes',
            description: 'Strings attached',
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'writes the collaborators once they change',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list(collaborators: [_alice])),
        act: (cubit) async {
          cubit.collaboratorsPicked(
            offered: {_alice},
            picked: {_alice, _bob},
          );
          await cubit.submitted();
        },
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Puppets',
            description: 'Strings attached',
            isCollaborative: true,
            allowedCollaborators: any(
              named: 'allowedCollaborators',
              that: unorderedEquals([_alice, _bob]),
            ),
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'ends the collaboration when the last collaborator is removed',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list(collaborators: [_alice])),
        act: (cubit) async {
          cubit.collaboratorsPicked(offered: {_alice}, picked: const {});
          await cubit.submitted();
        },
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Puppets',
            description: 'Strings attached',
            isCollaborative: false,
            allowedCollaborators: const [],
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'drops the collaborators of a list that goes private',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list(collaborators: [_alice])),
        act: (cubit) async {
          cubit.visibilityChanged(isPublic: false);
          await cubit.submitted();
        },
        verify: (_) => verify(
          () => service.updateList(
            listId: 'list-1',
            name: 'Puppets',
            description: 'Strings attached',
            isPublic: false,
            isCollaborative: false,
            allowedCollaborators: const [],
            onLocalSaved: any(named: 'onLocalSaved'),
          ),
        ).called(1),
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'reports a rename no relay accepted',
        setUp: () => stubUpdate(() async => false),
        build: () => buildCubit(existingList: _list()),
        act: (cubit) => cubit.submitted(),
        expect: () => [
          isA<CuratedListInfoState>().having(
            (s) => s.status,
            'status',
            CuratedListInfoStatus.saving,
          ),
          isA<CuratedListInfoState>().having(
            (s) => s.status,
            'status',
            CuratedListInfoStatus.savedAwaitingRelay,
          ),
          isA<CuratedListInfoState>()
              .having(
                (s) => s.status,
                'status',
                CuratedListInfoStatus.publishFailed,
              )
              .having((s) => s.canClose, 'canClose', isFalse),
        ],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'holds the form open until a visibility change is accepted',
        setUp: () => stubUpdate(() async => true),
        build: () => buildCubit(existingList: _list(isPublic: false)),
        act: (cubit) async {
          cubit.visibilityChanged(isPublic: true);
          await cubit.submitted();
        },
        skip: 1,
        expect: () => [
          isA<CuratedListInfoState>()
              .having(
                (s) => s.status,
                'status',
                CuratedListInfoStatus.saving,
              )
              .having((s) => s.canClose, 'canClose', isFalse),
          isA<CuratedListInfoState>().having(
            (s) => s.status,
            'status',
            CuratedListInfoStatus.saved,
          ),
        ],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'keeps the flipped switch when a visibility change is rejected',
        setUp: () => stubUpdate(() async => false),
        build: () => buildCubit(existingList: _list(isPublic: false)),
        act: (cubit) async {
          cubit.visibilityChanged(isPublic: true);
          await cubit.submitted();
        },
        verify: (cubit) {
          expect(cubit.state.status, equals(CuratedListInfoStatus.failure));
          expect(cubit.state.isPublic, isTrue);
          expect(cubit.state.canClose, isFalse);
        },
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'fails when creating the list throws',
        setUp: () => stubCreate(() async => throw Exception('relay down')),
        build: buildCubit,
        seed: () => const CuratedListInfoState(name: 'Puppets'),
        act: (cubit) => cubit.submitted(),
        expect: () => const [
          CuratedListInfoState(
            status: CuratedListInfoStatus.saving,
            name: 'Puppets',
          ),
          CuratedListInfoState(
            status: CuratedListInfoStatus.failure,
            name: 'Puppets',
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<CuratedListInfoCubit, CuratedListInfoState>(
        'reports a rename whose publish throws as unaccepted, not unsaved',
        setUp: () => stubUpdate(() async => throw Exception('relay down')),
        build: () => buildCubit(existingList: _list()),
        act: (cubit) => cubit.submitted(),
        verify: (cubit) => expect(
          cubit.state.status,
          equals(CuratedListInfoStatus.publishFailed),
        ),
        errors: () => [isA<Exception>()],
      );

      test(
        'a save still running when the cubit closes does not throw',
        () async {
          final answer = Completer<bool>();
          stubUpdate(() => answer.future);
          final cubit = buildCubit(existingList: _list());

          final save = cubit.submitted();
          expect(
            cubit.state.status,
            equals(CuratedListInfoStatus.savedAwaitingRelay),
          );
          await cubit.close();
          answer.complete(false);

          await expectLater(save, completes);
        },
      );
    });
  });
}
