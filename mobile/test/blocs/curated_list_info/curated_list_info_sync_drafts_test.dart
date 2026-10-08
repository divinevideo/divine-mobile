// ABOUTME: Verifies saved sync updates preserve unsaved list editor values.
// ABOUTME: Covers permission baselines, account fences and replaced services.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/curated_list_info/curated_list_info_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';

class _Service extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

void main() {
  final owner = 'a' * 64;
  final bob = 'b' * 64;
  final carol = 'c' * 64;

  CuratedList list({
    bool isPublic = true,
    List<String> collaborators = const [],
    bool pending = true,
  }) => CuratedList(
    id: 'sync-drafts',
    name: 'Original',
    description: 'Saved description',
    pubkey: owner,
    videoEventIds: const [],
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isPublic: isPublic,
    isCollaborative: collaborators.isNotEmpty,
    allowedCollaborators: collaborators,
    pendingRepublish: pending,
  );

  CuratedListInfoCubit editor(_Service service, CuratedList existing) =>
      CuratedListInfoCubit(
        resolveService: () => service,
        currentOwnerPubkey: () => owner,
        existingList: existing,
      );

  test(
    'Sync retries saved work without saving or dropping draft fields',
    () async {
      final service = _Service();
      final saved = list(collaborators: [bob]);
      var current = saved;
      when(() => service.getListById(saved.authorScopedId))
          .thenAnswer((_) => current);
      when(() => service.retryListSync(saved.id)).thenAnswer((_) async {
        current = saved.copyWith(pendingRepublish: false);
        return true;
      });
      final cubit = editor(service, saved);
      addTearDown(cubit.close);
      cubit
        ..nameChanged('Draft name')
        ..descriptionChanged('Draft description')
        ..visibilityChanged(isPublic: false)
        ..collaboratorsPicked(offered: {bob, carol}, picked: {carol});

      await cubit.retrySync();

      expect(cubit.state.name, 'Draft name');
      expect(cubit.state.description, 'Draft description');
      expect(cubit.state.isPublic, isFalse);
      expect(cubit.state.collaboratorPubkeys, [carol]);
      expect(cubit.state.visibilityWillChange, isTrue);
      expect(cubit.state.wasPublic, isTrue);
      expect(cubit.state.needsSync, isFalse);
      expect(cubit.state.status, CuratedListInfoStatus.editing);
      verify(() => service.retryListSync(saved.id)).called(1);
      verifyNever(() => service.createList(name: any(named: 'name')));
      verifyNever(() => service.updateList(listId: any(named: 'listId')));
    },
  );

  test(
    'failed Sync preserves draft collaborators and its saved baseline',
    () async {
      final service = _Service();
      final saved = list(collaborators: [bob]);
      when(() => service.getListById(saved.authorScopedId)).thenReturn(saved);
      when(() => service.getListById(saved.id)).thenReturn(saved);
      when(() => service.retryListSync(saved.id))
          .thenAnswer((_) async => false);
      when(
        () => service.updateList(
          listId: saved.id,
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
          onLocalSaved: any(named: 'onLocalSaved'),
          onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
        ),
      ).thenAnswer((_) async => true);
      final cubit = editor(service, saved);
      addTearDown(cubit.close);
      cubit.collaboratorsPicked(offered: {bob, carol}, picked: {carol});

      await cubit.retrySync();

      expect(cubit.state.collaboratorPubkeys, [carol]);
      expect(cubit.state.status, CuratedListInfoStatus.failure);
      expect(cubit.state.needsSync, isTrue);
      verifyNever(() => service.updateList(listId: any(named: 'listId')));
      await cubit.submitted();
      verify(
        () => service.updateList(
          listId: saved.id,
          name: saved.name,
          description: saved.description,
          isCollaborative: true,
          allowedCollaborators: [carol],
          onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
        ),
      ).called(1);
    },
  );

  test(
    'background delivery clears pending status without resetting drafts',
    () {
      final service = _Service();
      final saved = list(collaborators: [bob]);
      var current = saved;
      when(() => service.getListById(saved.authorScopedId))
          .thenAnswer((_) => current);
      final cubit = editor(service, saved);
      addTearDown(cubit.close);
      cubit
        ..nameChanged('Draft')
        ..descriptionChanged('Draft description')
        ..visibilityChanged(isPublic: false)
        ..collaboratorsPicked(offered: {bob, carol}, picked: {carol});
      current = saved.copyWith(pendingRepublish: false);

      cubit.refreshRecoveryReadOnly();

      expect(cubit.state.needsSync, isFalse);
      expect(cubit.state.name, 'Draft');
      expect(cubit.state.description, 'Draft description');
      expect(cubit.state.isPublic, isFalse);
      expect(cubit.state.visibilityWillChange, isTrue);
      expect(cubit.state.collaboratorPubkeys, [carol]);
    },
  );

  test(
    'untouched permissions follow background changes without a later rollback',
    () async {
      final service = _Service();
      final saved = list(collaborators: [bob]);
      var current = saved;
      when(() => service.getListById(any())).thenAnswer((_) => current);
      when(
        () => service.updateList(
          listId: any(named: 'listId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          isCollaborative: any(named: 'isCollaborative'),
          allowedCollaborators: any(named: 'allowedCollaborators'),
          onLocalSaved: any(named: 'onLocalSaved'),
          onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
        ),
      ).thenAnswer((_) async => true);
      final cubit = editor(service, saved);
      addTearDown(cubit.close);
      cubit.nameChanged('Draft name');
      current = list(isPublic: false, pending: false);

      cubit.refreshRecoveryReadOnly();

      expect(cubit.state.isPublic, isFalse);
      expect(cubit.state.wasPublic, isFalse);
      expect(cubit.state.visibilityWillChange, isFalse);
      expect(cubit.state.collaboratorPubkeys, isEmpty);
      expect(cubit.state.name, 'Draft name');
      await cubit.submitted();
      verify(
        () => service.updateList(
          listId: saved.id,
          name: 'Draft name',
          description: saved.description,
          onLocalSaved: any(named: 'onLocalSaved'),
        ),
      ).called(1);
    },
  );

  test(
    'settled permission recovery refreshes the saved target and enables drafts',
    () {
      final service = _Service();
      final pending = list(isPublic: false).copyWith(
        pendingVisibility: CuratedListVisibility(
          isPublic: true,
          isCollaborative: true,
          allowedCollaborators: [bob],
          relayAccepted: true,
        ),
      );
      var current = pending;
      when(() => service.getListById(pending.authorScopedId))
          .thenAnswer((_) => current);
      final cubit = editor(service, pending);
      addTearDown(cubit.close);
      expect(cubit.state.canEdit, isFalse);
      current = list(collaborators: [bob], pending: false);

      cubit.refreshRecoveryReadOnly();

      expect(cubit.state.permissionRecoveryPending, isFalse);
      expect(cubit.state.needsSync, isFalse);
      expect(cubit.state.wasPublic, isTrue);
      expect(cubit.state.isPublic, isTrue);
      expect(cubit.state.collaboratorPubkeys, [bob]);
      expect(cubit.state.canEdit, isTrue);
    },
  );

  test('a foreign record cannot change the baseline or be retried', () async {
    final service = _Service();
    final saved = list();
    when(() => service.getListById(saved.authorScopedId))
        .thenReturn(saved.copyWith(pubkey: bob, isPublic: false));
    final cubit = editor(service, saved);
    addTearDown(cubit.close);
    cubit.nameChanged('Draft');

    cubit.refreshRecoveryReadOnly();
    await cubit.retrySync();

    expect(cubit.state.name, 'Draft');
    expect(cubit.state.isPublic, isTrue);
    expect(cubit.state.wasPublic, isTrue);
    expect(cubit.state.needsSync, isTrue);
    expect(cubit.state.status, CuratedListInfoStatus.failure);
    verifyNever(() => service.retryListSync(any()));
  });

  test('a replaced service rejects the old Sync answer and refreshes current status', () async {
    final original = _Service();
    final replacement = _Service();
    CuratedListService active = original;
    final saved = list();
    final answer = Completer<bool>();
    when(() => original.getListById(saved.authorScopedId)).thenReturn(saved);
    when(() => replacement.getListById(saved.authorScopedId))
        .thenReturn(list(isPublic: false));
    when(() => original.retryListSync(saved.id))
        .thenAnswer((_) => answer.future);
    final cubit = CuratedListInfoCubit(
      resolveService: () => active,
      currentOwnerPubkey: () => owner,
      existingList: saved,
    );
    addTearDown(cubit.close);
    cubit.nameChanged('Draft');
    final retry = cubit.retrySync();
    active = replacement;
    answer.complete(true);
    await retry;

    expect(cubit.state.name, 'Draft');
    expect(cubit.state.isPublic, isFalse);
    expect(cubit.state.wasPublic, isFalse);
    expect(cubit.state.needsSync, isTrue);
    expect(cubit.state.status, CuratedListInfoStatus.failure);
    verifyNever(() => replacement.retryListSync(any()));
  });

  test('a late Sync answer cannot refresh another account', () async {
    final service = _Service();
    final saved = list();
    var activeOwner = owner;
    final answer = Completer<bool>();
    when(() => service.getListById(saved.authorScopedId)).thenReturn(saved);
    when(() => service.retryListSync(saved.id))
        .thenAnswer((_) => answer.future);
    final cubit = CuratedListInfoCubit(
      resolveService: () => service,
      currentOwnerPubkey: () => activeOwner,
      existingList: saved,
    );
    addTearDown(cubit.close);
    final retry = cubit.retrySync();
    final before = cubit.state;
    activeOwner = bob;
    answer.complete(true);
    await retry;
    cubit.refreshRecoveryReadOnly();

    expect(cubit.isSessionCurrent, isFalse);
    expect(cubit.state, before);
  });

  test(
    'a thrown permission retry retains recovery guards and failure status',
    () async {
      final service = _Service();
      final pending = list(isPublic: false).copyWith(
        pendingVisibility: const CuratedListVisibility(
          isPublic: true,
          isCollaborative: false,
          allowedCollaborators: [],
          relayAccepted: true,
        ),
      );
      when(() => service.getListById(pending.authorScopedId))
          .thenReturn(pending);
      when(() => service.retryListSync(pending.id))
          .thenThrow(StateError('Stored retry refused'));
      final cubit = editor(service, pending);
      addTearDown(cubit.close);

      await cubit.retrySync();

      expect(cubit.state.status, CuratedListInfoStatus.failure);
      expect(cubit.state.permissionRecoveryPending, isTrue);
      expect(cubit.state.needsSync, isTrue);
      expect(cubit.state.isPublic, isTrue);
      expect(cubit.state.canEdit, isFalse);
      expect(cubit.state.canSubmit, isFalse);
      verifyNever(() => service.updateList(listId: any(named: 'listId')));
    },
  );

  test(
    'a repair hold arriving during Sync preserves the draft and stays blocked',
    () async {
      final service = _Service();
      final saved = list(collaborators: [bob]);
      when(() => service.getListById(saved.authorScopedId)).thenReturn(saved);
      when(() => service.retryListSync(saved.id)).thenAnswer((_) async {
        service.recoveryNeedsRepair = true;
        return false;
      });
      final cubit = editor(service, saved);
      addTearDown(cubit.close);
      cubit
        ..nameChanged('Draft')
        ..visibilityChanged(isPublic: false)
        ..collaboratorsPicked(offered: {bob, carol}, picked: {carol});

      await cubit.retrySync();

      expect(cubit.state.name, 'Draft');
      expect(cubit.state.isPublic, isFalse);
      expect(cubit.state.collaboratorPubkeys, [carol]);
      expect(cubit.state.status, CuratedListInfoStatus.failure);
      expect(cubit.state.recoveryReadOnly, isTrue);
      expect(cubit.state.canSubmit, isFalse);
    },
  );

  test(
    'a retry completing after the editor closes cannot emit or read storage',
    () async {
      final service = _Service();
      final saved = list();
      final answer = Completer<bool>();
      when(() => service.getListById(saved.authorScopedId)).thenReturn(saved);
      when(() => service.retryListSync(saved.id))
          .thenAnswer((_) => answer.future);
      final cubit = editor(service, saved);
      final retry = cubit.retrySync();
      await cubit.close();
      clearInteractions(service);
      answer.complete(true);

      await retry;
      cubit.refreshRecoveryReadOnly();

      verifyZeroInteractions(service);
    },
  );

  test('background delivery settles only the failed Sync status', () async {
    final service = _Service();
    final saved = list();
    var current = saved;
    when(() => service.getListById(saved.authorScopedId))
        .thenAnswer((_) => current);
    when(() => service.retryListSync(saved.id)).thenAnswer((_) async => false);
    final cubit = editor(service, saved);
    addTearDown(cubit.close);
    cubit.nameChanged('Unsaved name');
    await cubit.retrySync();
    expect(cubit.state.status, CuratedListInfoStatus.failure);
    current = saved.copyWith(pendingRepublish: false);

    cubit.refreshRecoveryReadOnly();

    expect(cubit.state.status, CuratedListInfoStatus.editing);
    expect(cubit.state.needsSync, isFalse);
    expect(cubit.state.name, 'Unsaved name');
    verifyNever(() => service.updateList(listId: any(named: 'listId')));
  });

  test('background delivery cannot hide an unrelated Save failure', () async {
    final service = _Service();
    final saved = list();
    var current = saved;
    when(() => service.getListById(any())).thenAnswer((_) => current);
    when(
      () => service.updateList(
        listId: any(named: 'listId'),
        name: any(named: 'name'),
        description: any(named: 'description'),
        isPublic: any(named: 'isPublic'),
        isCollaborative: any(named: 'isCollaborative'),
        allowedCollaborators: any(named: 'allowedCollaborators'),
        onLocalSaved: any(named: 'onLocalSaved'),
        onPublicationUnconfirmed: any(named: 'onPublicationUnconfirmed'),
      ),
    ).thenAnswer((_) async => false);
    final cubit = editor(service, saved);
    addTearDown(cubit.close);
    cubit.nameChanged('Unsaved name');
    await cubit.submitted();
    expect(cubit.state.status, CuratedListInfoStatus.failure);
    current = saved.copyWith(pendingRepublish: false);

    cubit.refreshRecoveryReadOnly();

    expect(cubit.state.status, CuratedListInfoStatus.failure);
    expect(cubit.state.needsSync, isFalse);
    expect(cubit.state.name, 'Unsaved name');
  });
}
