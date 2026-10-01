// ABOUTME: Exercises people metadata edits through Main's mutation queue.
// ABOUTME: Verifies ACKs, cancellation, drafts and shared member-write ordering.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_info_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

class _Repository extends Mock implements PeopleListsRepository {}

final String _ownerA = 'a' * 64;
final String _ownerB = 'b' * 64;
final String _member = 'c' * 64;
final String _eventId = 'e' * 64;
UserList _list() => UserList(
  id: 'crew',
  name: 'Crew',
  description: 'Original description',
  pubkeys: const [],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
void main() {
  late _Repository repository;
  setUp(() {
    repository = _Repository();
    when(() => repository.watchLists(ownerPubkey: any(named: 'ownerPubkey')))
        .thenAnswer((_) => const Stream.empty());
    when(() => repository.syncOwner(ownerPubkey: any(named: 'ownerPubkey')))
        .thenAnswer((_) async {});
    when(
      () => repository.syncFollowedLists(
        viewerPubkey: any(named: 'viewerPubkey'),
        isCancelled: any(named: 'isCancelled'),
      ),
    ).thenAnswer((_) async {});
  });
  PeopleListsBloc createBloc() {
    final bloc = PeopleListsBloc(
      repository: repository,
      ownerPubkeyStream: const Stream.empty(),
      repositoryStream: const Stream.empty(),
      enabledStream: const Stream.empty(),
      initialOwnerPubkey: _ownerA,
      clock: () => DateTime.utc(2026),
    );
    addTearDown(bloc.close);
    bloc.add(
      PeopleListsRepositoryListsChanged(ownerPubkey: _ownerA, lists: [_list()]),
    );
    return bloc;
  }

  PeopleListInfoCubit createInfo(PeopleListsBloc bloc) {
    final cubit = PeopleListInfoCubit(
      submitMutation: bloc.submit,
      ownerPubkey: _ownerA,
      list: _list(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  void stubInfo(Future<PeopleListPublishResult> Function() answer) {
    when(
      () => repository.updateListInfo(
        ownerPubkey: any(named: 'ownerPubkey'),
        listId: any(named: 'listId'),
        name: any(named: 'name'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) => answer());
  }

  Future<void> settled(PeopleListsBloc bloc) async {
    if (bloc.state.status != PeopleListsStatus.ready) {
      await bloc.stream.firstWhere((s) => s.status == PeopleListsStatus.ready);
    }
  }

  Completer<PeopleListPublishResult> pendingAck() {
    final answer = Completer<PeopleListPublishResult>();
    addTearDown(() {
      if (!answer.isCompleted) {
        answer.complete(const PeopleListPublishResult.failed());
      }
    });
    return answer;
  }

  for (final failed in [false, true]) {
    test(
      'metadata ${failed ? 'refusal retains drafts' : 'ACK allows closure'}',
      () async {
        final answer = pendingAck();
        stubInfo(() => answer.future);
        final bloc = createBloc();
        await settled(bloc);
        final info = createInfo(bloc)
          ..nameChanged('Renamed crew ')
          ..descriptionChanged(' New description');
        final started = bloc.stream.firstWhere(
          (s) => s.status == PeopleListsStatus.submitting,
        );
        final save = info.submitted();
        await started;
        expect(info.state.isSaving, isTrue);
        expect(info.state.canClose, isFalse);
        expect(bloc.state.pendingMutations, isNotEmpty);
        verify(
          () => repository.updateListInfo(
            ownerPubkey: _ownerA,
            listId: 'crew',
            name: 'Renamed crew ',
            description: ' New description',
          ),
        ).called(1);
        verifyNever(
          () => repository.updateList(
            ownerPubkey: any(named: 'ownerPubkey'),
            listId: any(named: 'listId'),
            name: any(named: 'name'),
            description: any(named: 'description'),
          ),
        );
        answer.complete(
          failed
              ? const PeopleListPublishResult.failed()
              : PeopleListPublishResult.submitted(eventId: _eventId),
        );
        expect(
          await save,
          failed ? PeopleListInfoStatus.failure : PeopleListInfoStatus.saved,
        );
        expect(info.state.canClose, !failed);
        expect(info.state.name, 'Renamed crew ');
        expect(info.state.description, ' New description');
        expect(bloc.state.pendingMutations, isEmpty);
        if (!failed) expect(bloc.state.lastSubmittedEventId, _eventId);
      },
    );
  }
  test(
    'noop retains Main status policy and the optional description',
    () async {
      stubInfo(() async => const PeopleListPublishResult.noop());
      final bloc = createBloc();
      await settled(bloc);
      expect(
        await bloc.submit(
          PeopleListsInfoUpdateRequested(
            expectedOwnerPubkey: _ownerA,
            listId: 'crew',
            name: 'Crew',
          ),
        ),
        PeopleListsOperationResult.succeeded,
      );
      verify(
        () => repository.updateListInfo(
          ownerPubkey: _ownerA,
          listId: 'crew',
          name: 'Crew',
          description: any(named: 'description', that: isNull),
        ),
      ).called(1);
    },
  );
  test(
    'metadata shares the member-write queue and waits for its ACK',
    () async {
      final memberAck = pendingAck();
      when(
        () => repository.addPubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _member,
        ),
      ).thenAnswer((_) => memberAck.future);
      stubInfo(() async => const PeopleListPublishResult.noop());
      final bloc = createBloc();
      await settled(bloc);
      final started = bloc.stream.firstWhere(
        (s) => s.status == PeopleListsStatus.submitting,
      );
      final add = bloc.submit(
        PeopleListsPubkeyAddRequested(listId: 'crew', pubkey: _member),
      );
      await started;
      final info = createInfo(bloc)..nameChanged('Crew renamed');
      final save = info.submitted();
      await Future<void>.delayed(Duration.zero);
      verifyNever(
        () => repository.updateListInfo(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      );
      memberAck.complete(PeopleListPublishResult.submitted(eventId: _eventId));
      expect(await add, PeopleListsOperationResult.succeeded);
      expect(await save, PeopleListInfoStatus.saved);
      expect(bloc.state.lists.single.pubkeys, [_member]);
      verify(
        () => repository.updateListInfo(
          ownerPubkey: _ownerA,
          listId: 'crew',
          name: 'Crew renamed',
          description: 'Original description',
        ),
      ).called(1);
    },
  );
  test(
    'owner replacement cancels an ACK without closing or dropping drafts',
    () async {
      final answer = pendingAck();
      stubInfo(() => answer.future);
      final bloc = createBloc();
      await settled(bloc);
      final info = createInfo(bloc)..nameChanged('My draft');
      final started = bloc.stream.firstWhere(
        (s) => s.status == PeopleListsStatus.submitting,
      );
      final save = info.submitted();
      await started;
      final switched = bloc.stream.firstWhere(
        (s) => s.activeOwnerPubkey == _ownerB,
      );
      bloc.add(PeopleListsOwnerChanged(ownerPubkey: _ownerB));
      await switched;
      expect(await save, PeopleListInfoStatus.failure);
      expect(info.state.canClose, isFalse);
      expect(info.state.name, 'My draft');
      answer.complete(PeopleListPublishResult.submitted(eventId: _eventId));
      await Future<void>.delayed(Duration.zero);
      expect(info.state.status, PeopleListInfoStatus.failure);
      expect(bloc.state.activeOwnerPubkey, _ownerB);
      expect(bloc.state.lastSubmittedEventId, isNull);
      expect(await info.submitted(), PeopleListInfoStatus.failure);
      verify(
        () => repository.updateListInfo(
          ownerPubkey: _ownerA,
          listId: 'crew',
          name: 'My draft',
          description: 'Original description',
        ),
      ).called(1);
      verifyNever(
        () => repository.updateListInfo(
          ownerPubkey: _ownerB,
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      );
    },
  );
  test(
    'closing the cubit prevents another submission from publishing',
    () async {
      final bloc = createBloc();
      await settled(bloc);
      final info = createInfo(bloc);
      await info.close();
      expect(await info.submitted(), isNull);
      verifyZeroInteractions(repository);
    },
  );
  test(
    'manual dismissal still returns the pending request actual failure',
    () async {
      final answer = pendingAck();
      stubInfo(() => answer.future);
      final bloc = createBloc();
      await settled(bloc);
      final info = createInfo(bloc);
      final started = bloc.stream.firstWhere(
        (s) => s.status == PeopleListsStatus.submitting,
      );
      final save = info.submitted();
      await started;
      await info.close();
      answer.complete(const PeopleListPublishResult.failed());
      expect(await save, PeopleListInfoStatus.failure);
      expect(info.isClosed, isTrue);
      expect(bloc.state.pendingMutations, isEmpty);
    },
  );
  test('repository exceptions preserve the form values for retry', () async {
    stubInfo(() async => throw StateError('storage rejected'));
    final bloc = createBloc();
    await settled(bloc);
    final info = createInfo(bloc)..descriptionChanged('Keep this draft');
    expect(await info.submitted(), PeopleListInfoStatus.failure);
    expect(info.state.canClose, isFalse);
    expect(info.state.description, 'Keep this draft');
  });
  test(
    'owner replacement cancels queued metadata before any publication',
    () async {
      final memberAck = pendingAck();
      when(
        () => repository.addPubkey(
          ownerPubkey: _ownerA,
          listId: 'crew',
          pubkey: _member,
        ),
      ).thenAnswer((_) => memberAck.future);
      final bloc = createBloc();
      await settled(bloc);
      final started = bloc.stream.firstWhere(
        (s) => s.status == PeopleListsStatus.submitting,
      );
      final add = bloc.submit(
        PeopleListsPubkeyAddRequested(listId: 'crew', pubkey: _member),
      );
      await started;
      final info = createInfo(bloc)..nameChanged('Queued draft');
      final save = info.submitted();
      final switched = bloc.stream.firstWhere(
        (s) => s.activeOwnerPubkey == _ownerB,
      );
      bloc.add(PeopleListsOwnerChanged(ownerPubkey: _ownerB));
      await switched;
      expect(await add, PeopleListsOperationResult.cancelled);
      expect(await save, PeopleListInfoStatus.failure);
      expect(info.state.name, 'Queued draft');
      expect(info.state.canClose, isFalse);
      memberAck.complete(PeopleListPublishResult.submitted(eventId: _eventId));
      await Future<void>.delayed(Duration.zero);
      verifyNever(
        () => repository.updateListInfo(
          ownerPubkey: any(named: 'ownerPubkey'),
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
        ),
      );
    },
  );
  for (final wrongOwner in [_ownerB, '']) {
    test(
      'a ${wrongOwner.isEmpty ? 'missing' : 'different'} opening owner cannot enqueue metadata',
      () async {
        final bloc = createBloc();
        await settled(bloc);
        expect(
          await bloc.submit(
            PeopleListsInfoUpdateRequested(
              expectedOwnerPubkey: wrongOwner,
              listId: 'crew',
              name: 'Refused',
            ),
          ),
          PeopleListsOperationResult.cancelled,
        );
        verifyZeroInteractions(repository);
      },
    );
  }
}
