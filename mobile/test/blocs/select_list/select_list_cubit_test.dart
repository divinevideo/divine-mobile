// ABOUTME: Tests for SelectListCubit: which lists are picked, how the picks
// ABOUTME: are written, and how the lists on offer follow the service.

import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_journal.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/committed_list_account.dart';
import '../../helpers/curated_list_publish_stubs.dart';

class _MockCuratedListService extends Mock implements CuratedListService {
  @override
  bool recoveryNeedsRepair = false;
}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

// Full-length 64-char ids — never truncate.
final String _videoId = 'a' * 64;
final String _otherVideoId = 'b' * 64;
final String _ownerPubkey = 'f' * 64;

CuratedList _list(
  String id, {
  List<String> videoEventIds = const [],
  bool isPublic = true,
}) => CuratedList(
  id: id,
  pubkey: _ownerPubkey,
  name: id,
  isPublic: isPublic,
  videoEventIds: videoEventIds,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group(SelectListCubit, () {
    late _MockCuratedListService service;

    setUp(() {
      service = _MockCuratedListService();
      when(() => service.isCurrentSession).thenReturn(true);
    });

    void stubLists(List<CuratedList> lists) {
      when(() => service.pickerListsForOwner(any())).thenReturn(lists);
    }

    SelectListCubit buildCubit() => SelectListCubit(
      service: service,
      videoEventId: _videoId,
      currentOwnerPubkey: () => _ownerPubkey,
    );

    /// The listener the cubit registered on the service.
    VoidCallback capturedListener() =>
        verify(() => service.addListener(captureAny())).captured.single
            as VoidCallback;

    group('initial state', () {
      test("offers the viewer's lists with those holding the video picked", () {
        stubLists([
          _list('holds', videoEventIds: [_videoId]),
          _list('other', videoEventIds: [_otherVideoId]),
          _list('empty'),
        ]);
        final cubit = buildCubit();
        addTearDown(cubit.close);

        expect(cubit.state.lists.map((list) => list.id), [
          'holds',
          'other',
          'empty',
        ]);
        expect(cubit.state.memberListIds, {'holds'});
        expect(cubit.state.selectedListIds, {'holds'});
        expect(cubit.state.status, SelectListStatus.editing);
        expect(cubit.state.listIdsToAdd, isEmpty);
        expect(cubit.state.listIdsToRemove, isEmpty);
      });
    });

    group('read-only recovery', () {
      test(
        'keeps saved rows while blocking staging, submit and sync',
        () async {
          final pending = _list(
            'holds',
            videoEventIds: [_videoId],
          ).copyWith(pendingRepublish: true);
          stubLists([pending, _list('empty')]);
          service.recoveryNeedsRepair = true;
          final cubit = buildCubit();
          addTearDown(cubit.close);

          cubit.toggled('holds');
          cubit.toggled('empty');
          expect(await cubit.submitted(), isNull);
          await cubit.syncRequested('holds');

          expect(cubit.state.lists, [pending, _list('empty')]);
          expect(cubit.state.selectedListIds, {'holds'});
          expect(cubit.state.recoveryReadOnly, isTrue);
          expect(cubit.state.canEdit, isFalse);
          expect(cubit.state.canSubmit, isFalse);
          expect(cubit.state.status, SelectListStatus.editing);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
          verifyNever(() => service.retryListSync(any()));
        },
      );

      test(
        'a live hold drops unsaved picks before a stale callback writes',
        () async {
          stubLists([
            _list('holds', videoEventIds: [_videoId]),
            _list('empty'),
          ]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.toggled('holds');
          cubit.toggled('empty');
          service.recoveryNeedsRepair = true;

          expect(await cubit.submitted(), isNull);
          cubit.toggled('empty');
          expect(cubit.state.selectedListIds, {'holds'});
          expect(cubit.state.listIdsToAdd, isEmpty);
          expect(cubit.state.listIdsToRemove, isEmpty);
          expect(cubit.state.status, SelectListStatus.editing);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      test(
        'a hold interrupts a batch even if repaired before its await ends',
        () async {
          stubLists([_list('first'), _list('second')]);
          final gate = Completer<bool>();
          when(
            () => service.addVideoToList('$_ownerPubkey:first', _videoId),
          ).thenAnswer((_) => gate.future);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          final listener = capturedListener();
          cubit
            ..toggled('first')
            ..toggled('second');
          final save = cubit.submitted();
          service.recoveryNeedsRepair = true;
          listener();
          service.recoveryNeedsRepair = false;
          listener();
          gate.complete(true);

          expect(await save, isNull);
          expect(cubit.state.status, SelectListStatus.editing);
          verifyNever(
            () => service.addVideoToList('$_ownerPubkey:second', _videoId),
          );
        },
      );

      test(
        'a hold interrupts sync without reporting its stale outcome',
        () async {
          stubLists([
            _list(
              'holds',
              videoEventIds: [_videoId],
            ).copyWith(pendingRepublish: true),
          ]);
          final gate = Completer<bool>();
          when(
            () => service.retryListSync('$_ownerPubkey:holds'),
          ).thenAnswer((_) => gate.future);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          final sync = cubit.syncRequested('holds');
          service.recoveryNeedsRepair = true;
          gate.complete(false);
          await sync;

          expect(cubit.state.recoveryReadOnly, isTrue);
          expect(cubit.state.status, SelectListStatus.editing);
          expect(cubit.state.syncingListIds, isEmpty);
          expect(cubit.state.failedSyncListIds, isEmpty);
        },
      );

      test(
        'missing provider service preserves the known hold until a replacement',
        () {
          stubLists([
            _list('holds', videoEventIds: [_videoId]),
          ]);
          service.recoveryNeedsRepair = true;
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.serviceChanged(null);
          service.recoveryNeedsRepair = false;
          cubit.refreshRecoveryReadOnly();

          expect(cubit.state.recoveryReadOnly, isTrue);
          expect(cubit.state.serviceAvailable, isFalse);
          expect(cubit.state.selectedListIds, {'holds'});
          final replacement = _MockCuratedListService();
          when(() => replacement.isCurrentSession).thenReturn(true);
          when(
            () => replacement.pickerListsForOwner(any()),
          ).thenReturn([_list('new')]);
          cubit.serviceChanged(replacement);
          expect(cubit.state.recoveryReadOnly, isFalse);
          expect(cubit.state.serviceAvailable, isTrue);
          expect(cubit.state.lists.single.id, 'new');
          expect(cubit.state.selectedListIds, isEmpty);
          expect(cubit.state.canEdit, isTrue);
        },
      );

      test(
        'replacement drops staging and prevents the previous batch continuing',
        () async {
          stubLists([_list('first'), _list('second')]);
          final gate = Completer<bool>();
          when(
            () => service.addVideoToList('$_ownerPubkey:first', _videoId),
          ).thenAnswer((_) => gate.future);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit
            ..toggled('first')
            ..toggled('second');
          final save = cubit.submitted();
          final replacement = _MockCuratedListService()
            ..recoveryNeedsRepair = true;
          when(() => replacement.isCurrentSession).thenReturn(true);
          when(() => replacement.pickerListsForOwner(any())).thenReturn([
            _list('replacement', videoEventIds: [_videoId]),
          ]);
          cubit.serviceChanged(replacement);
          gate.complete(true);

          expect(await save, isNull);
          expect(cubit.state.recoveryReadOnly, isTrue);
          expect(cubit.state.selectedListIds, {'replacement'});
          expect(cubit.state.status, SelectListStatus.editing);
          verifyNever(
            () => service.addVideoToList('$_ownerPubkey:second', _videoId),
          );
          verifyNever(() => replacement.addVideoToList(any(), any()));
        },
      );

      test('immutable flags participate in copies and equality', () {
        const initial = SelectListState(
          lists: [],
          memberListIds: {},
          selectedListIds: {},
        );
        final held = initial.copyWith(
          recoveryReadOnly: true,
          serviceAvailable: false,
        );
        expect(held, isNot(initial));
        expect(held.copyWith(), held);
        expect(held.canEdit, isFalse);
        expect(
          held.copyWith(recoveryReadOnly: false, serviceAvailable: true),
          initial,
        );
      });
    });

    group('toggled', () {
      blocTest<SelectListCubit, SelectListState>(
        'picks an unpicked list and unpicks a picked one',
        setUp: () => stubLists([
          _list('holds', videoEventIds: [_videoId]),
        ]),
        build: buildCubit,
        act: (cubit) => cubit
          ..toggled('holds')
          ..toggled('holds'),
        expect: () => [
          isA<SelectListState>()
              .having((s) => s.selectedListIds, 'selected', isEmpty)
              .having((s) => s.listIdsToRemove, 'to remove', {'holds'}),
          isA<SelectListState>()
              .having((s) => s.selectedListIds, 'selected', {'holds'})
              .having((s) => s.listIdsToRemove, 'to remove', isEmpty),
        ],
      );

      blocTest<SelectListCubit, SelectListState>(
        'ignores a list the sheet does not offer',
        setUp: () => stubLists([_list('empty')]),
        build: buildCubit,
        act: (cubit) => cubit.toggled('elsewhere'),
        expect: () => isEmpty,
      );

      blocTest<SelectListCubit, SelectListState>(
        'clears a failure so the line goes away once the picks change',
        setUp: () {
          stubLists([_list('empty')]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit.toggled('empty');
          await cubit.submitted();
          cubit.toggled('empty');
        },
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.editing,
          ),
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saving,
          ),
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.failure,
          ),
          isA<SelectListState>()
              .having((s) => s.status, 'status', SelectListStatus.editing)
              .having((s) => s.selectedListIds, 'selected', isEmpty),
        ],
      );
    });

    group('submitted', () {
      blocTest<SelectListCubit, SelectListState>(
        'closes at once when nothing changed',
        setUp: () => stubLists([
          _list('holds', videoEventIds: [_videoId]),
        ]),
        build: buildCubit,
        act: (cubit) => cubit.submitted(),
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saved,
          ),
        ],
        verify: (_) {
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      blocTest<SelectListCubit, SelectListState>(
        'adds the video to every newly picked list and removes it from '
        'every unpicked one',
        setUp: () {
          stubLists([
            _list('holds', videoEventIds: [_videoId]),
            _list('first'),
            _list('second'),
          ]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => true);
          when(
            () => service.removeVideoFromList(any(), any()),
          ).thenAnswer((_) async => true);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit
            ..toggled('first')
            ..toggled('second')
            ..toggled('holds');
          await cubit.submitted();
        },
        skip: 3,
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saving,
          ),
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saved,
          ),
        ],
        verify: (_) {
          verify(
            () => service.addVideoToList('$_ownerPubkey:first', _videoId),
          ).called(1);
          verify(
            () => service.addVideoToList('$_ownerPubkey:second', _videoId),
          ).called(1);
          verify(
            () => service.removeVideoFromList('$_ownerPubkey:holds', _videoId),
          ).called(1);
          verifyNever(
            () => service.addVideoToList('$_ownerPubkey:holds', any()),
          );
        },
      );

      blocTest<SelectListCubit, SelectListState>(
        'removes the video from the only list that holds it, leaving '
        'nothing picked',
        setUp: () {
          stubLists([
            _list('holds', videoEventIds: [_videoId]),
          ]);
          when(
            () => service.removeVideoFromList(any(), any()),
          ).thenAnswer((_) async => true);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit.toggled('holds');
          await cubit.submitted();
        },
        skip: 1,
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saving,
          ),
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saved,
          ),
        ],
        verify: (_) {
          verify(
            () => service.removeVideoFromList('$_ownerPubkey:holds', _videoId),
          ).called(1);
        },
      );

      blocTest<SelectListCubit, SelectListState>(
        'keeps the sheet open with the picks when a list refuses the change',
        setUp: () {
          stubLists([_list('works'), _list('refuses')]);
          when(
            () => service.addVideoToList('$_ownerPubkey:works', any()),
          ).thenAnswer((_) async => true);
          when(
            () => service.addVideoToList('$_ownerPubkey:refuses', any()),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit
            ..toggled('works')
            ..toggled('refuses');
          await cubit.submitted();
        },
        skip: 3,
        expect: () => [
          isA<SelectListState>()
              .having((s) => s.status, 'status', SelectListStatus.failure)
              .having((s) => s.selectedListIds, 'selected', {
                'works',
                'refuses',
              }),
        ],
      );

      blocTest<SelectListCubit, SelectListState>(
        'names a private list with no room when that is all that failed',
        setUp: () {
          stubLists([
            _list(
              'full',
              isPublic: false,
              // Enough references that one more cannot fit in a single
              // NIP-44 plaintext, so the converter's real arithmetic decides.
              videoEventIds: [
                for (var i = 0; i < 1000; i++) i.toString().padLeft(64, '0'),
              ],
            ),
          ]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit.toggled('full');
          await cubit.submitted();
        },
        skip: 2,
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.failureListFull,
          ),
        ],
      );

      blocTest<SelectListCubit, SelectListState>(
        'stays generic when a full private list is not the only failure',
        setUp: () {
          stubLists([
            _list(
              'full',
              isPublic: false,
              videoEventIds: [
                for (var i = 0; i < 1000; i++) i.toString().padLeft(64, '0'),
              ],
            ),
            _list('refuses'),
          ]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => false);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit
            ..toggled('full')
            ..toggled('refuses');
          await cubit.submitted();
        },
        skip: 3,
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.failure,
          ),
        ],
      );

      blocTest<SelectListCubit, SelectListState>(
        'reports a service that throws and keeps the picks',
        setUp: () {
          stubLists([_list('empty')]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenThrow(StateError('no signer'));
        },
        build: buildCubit,
        act: (cubit) async {
          cubit.toggled('empty');
          await cubit.submitted();
        },
        skip: 2,
        expect: () => [
          isA<SelectListState>()
              .having((s) => s.status, 'status', SelectListStatus.failure)
              .having((s) => s.selectedListIds, 'selected', {'empty'}),
        ],
        errors: () => [isA<StateError>()],
      );

      test('ignores a second submit while the first is running', () async {
        stubLists([_list('empty')]);
        when(
          () => service.addVideoToList(any(), any()),
        ).thenAnswer((_) async => true);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.toggled('empty');

        final first = cubit.submitted();
        expect(cubit.state.isSaving, isTrue);
        await cubit.submitted();
        await first;

        verify(
          () => service.addVideoToList('$_ownerPubkey:empty', _videoId),
        ).called(1);
        expect(cubit.state.status, SelectListStatus.saved);
      });
    });

    group('opening account', () {
      test(
        'a recovery hold never preserves rows after an account changes',
        () async {
          stubLists([
            _list('private', isPublic: false, videoEventIds: [_videoId]),
          ]);
          service.recoveryNeedsRepair = true;
          String? owner = _ownerPubkey;
          final cubit = SelectListCubit(
            service: service,
            videoEventId: _videoId,
            currentOwnerPubkey: () => owner,
          );
          addTearDown(cubit.close);
          owner = 'e' * 64;
          expect(await cubit.submitted(), SelectListStatus.failure);
          expect(cubit.state.lists, isEmpty);
          expect(cubit.state.selectedListIds, isEmpty);
          expect(cubit.state.canEdit, isFalse);
          verifyNever(() => service.addVideoToList(any(), any()));
        },
      );

      test('does not submit a visit after the account changes', () async {
        stubLists([_list('empty')]);
        String? owner = _ownerPubkey;
        final cubit = SelectListCubit(
          service: service,
          videoEventId: _videoId,
          currentOwnerPubkey: () => owner,
        );
        addTearDown(cubit.close);
        cubit.toggled('empty');
        owner = 'e' * 64;
        expect(await cubit.submitted(), SelectListStatus.failure);
        verifyNever(() => service.addVideoToList(any(), any()));
      });

      test('stops the remainder of a batch after an account changes', () async {
        stubLists([_list('first'), _list('second')]);
        final gate = Completer<bool>();
        when(
          () => service.addVideoToList('$_ownerPubkey:first', _videoId),
        ).thenAnswer((_) => gate.future);
        String? owner = _ownerPubkey;
        final cubit = SelectListCubit(
          service: service,
          videoEventId: _videoId,
          currentOwnerPubkey: () => owner,
        );
        addTearDown(cubit.close);
        cubit
          ..toggled('first')
          ..toggled('second');
        final save = cubit.submitted();
        owner = 'e' * 64;
        gate.complete(true);
        expect(await save, SelectListStatus.failure);
        verifyNever(
          () => service.addVideoToList('$_ownerPubkey:second', _videoId),
        );
      });

      test('unknown authors are not offered as owned lists', () {
        stubLists([
          _list('legacy').copyWith(pubkey: ''),
          _list('foreign').copyWith(pubkey: 'e' * 64),
        ]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        expect(cubit.state.lists, isEmpty);
        expect(cubit.state.canSubmit, isFalse);
      });

      test(
        'revalidates ownership of a selected coordinate before writing',
        () async {
          stubLists([_list('same')]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.toggled('same');
          stubLists([_list('same').copyWith(pubkey: 'e' * 64)]);
          expect(await cubit.submitted(), SelectListStatus.failure);
          verifyNever(() => service.addVideoToList(any(), any()));
        },
      );
    });

    test(
      'sync retries publication without changing local membership',
      () async {
        final list = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([list]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => service.retryListSync('$_ownerPubkey:pending'),
        ).thenAnswer((_) async => false);
        await cubit.syncRequested('pending');
        expect(cubit.state.memberListIds, {'pending'});
        expect(cubit.state.selectedListIds, {'pending'});
        expect(cubit.state.status, SelectListStatus.syncFailed);
        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => service.removeVideoFromList(any(), any()));
      },
    );

    test(
      'external sync clears the creation notice and preserves other draft picks',
      () async {
        final pending = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending, _list('other')]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final listener = capturedListener();
        cubit.toggled('other');
        cubit.createdListWithVideoPendingSync();
        expect(cubit.state.status, SelectListStatus.videoPendingSync);
        stubLists([pending.copyWith(pendingRepublish: false), _list('other')]);
        listener();
        expect(cubit.state.status, SelectListStatus.editing);
        expect(cubit.state.pendingSyncListIds, isEmpty);
        expect(cubit.state.selectedListIds, {'pending', 'other'});
      },
    );

    test(
      'creation settling after sync does not revive a stale pending notice',
      () {
        final pending = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        stubLists([pending.copyWith(pendingRepublish: false)]);

        cubit.createdListWithVideoPendingSync();

        expect(cubit.state.status, SelectListStatus.editing);
        expect(cubit.state.pendingSyncListIds, isEmpty);
        expect(cubit.state.selectedListIds, {'pending'});
      },
    );

    test(
      'sync settles from current service data even before its notification',
      () async {
        final pending = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(() => service.retryListSync('$_ownerPubkey:pending')).thenAnswer((
          _,
        ) async {
          stubLists([pending.copyWith(pendingRepublish: false)]);
          return true;
        });
        await cubit.syncRequested('pending');
        expect(cubit.state.status, SelectListStatus.editing);
        expect(cubit.state.pendingSyncListIds, isEmpty);
        expect(cubit.state.syncingListIds, isEmpty);
        expect(cubit.state.selectedListIds, {'pending'});
      },
    );

    test(
      'syncing one list preserves another outstanding membership notice',
      () async {
        final first = _list(
          'first',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        final second = _list(
          'second',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([first, second]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(() => service.retryListSync('$_ownerPubkey:first')).thenAnswer((
          _,
        ) async {
          stubLists([first.copyWith(pendingRepublish: false), second]);
          return true;
        });
        await cubit.syncRequested('first');
        expect(cubit.state.status, SelectListStatus.videoPendingSync);
        expect(cubit.state.pendingSyncListIds, {'second'});
        expect(cubit.state.selectedListIds, {'first', 'second'});
      },
    );

    test(
      'retry exceptions restore actionable state without dropping membership',
      () async {
        final pending = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        when(
          () => service.retryListSync('$_ownerPubkey:pending'),
        ).thenThrow(StateError('relay closed'));
        await cubit.syncRequested('pending');
        expect(cubit.state.status, SelectListStatus.syncFailed);
        expect(cubit.state.syncingListIds, isEmpty);
        expect(cubit.state.failedSyncListIds, {'pending'});
        expect(cubit.state.selectedListIds, {'pending'});
        expect(cubit.state.canSubmit, isTrue);
      },
    );

    test(
      'a retry result after an account change clears stale rows and selections',
      () async {
        final pending = _list(
          'pending',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending]);
        String? owner = _ownerPubkey;
        final cubit = SelectListCubit(
          service: service,
          videoEventId: _videoId,
          currentOwnerPubkey: () => owner,
        );
        addTearDown(cubit.close);
        final answer = Completer<bool>();
        when(
          () => service.retryListSync('$_ownerPubkey:pending'),
        ).thenAnswer((_) => answer.future);
        final retry = cubit.syncRequested('pending');
        expect(cubit.state.syncingListIds, {'pending'});
        owner = 'e' * 64;
        answer.complete(true);
        await retry;
        expect(cubit.state.status, SelectListStatus.failure);
        expect(cubit.state.lists, isEmpty);
        expect(cubit.state.selectedListIds, isEmpty);
        expect(cubit.state.syncingListIds, isEmpty);
        expect(cubit.state.failedSyncListIds, isEmpty);
      },
    );

    group('createdListRefusedVideo', () {
      blocTest<SelectListCubit, SelectListState>(
        'shows the failure line, leaving the picks alone',
        setUp: () => stubLists([_list('empty')]),
        build: buildCubit,
        act: (cubit) => cubit
          ..toggled('empty')
          ..createdListRefusedVideo(),
        skip: 1,
        expect: () => [
          isA<SelectListState>()
              .having(
                (s) => s.status,
                'status',
                SelectListStatus.createdWithoutVideo,
              )
              .having((s) => s.selectedListIds, 'selected', {'empty'}),
        ],
      );

      blocTest<SelectListCubit, SelectListState>(
        'is ignored while a save runs',
        setUp: () {
          stubLists([_list('empty')]);
          when(
            () => service.addVideoToList(any(), any()),
          ).thenAnswer((_) async => true);
        },
        build: buildCubit,
        act: (cubit) async {
          cubit.toggled('empty');
          final save = cubit.submitted();
          cubit.createdListRefusedVideo();
          await save;
        },
        skip: 2,
        expect: () => [
          isA<SelectListState>().having(
            (s) => s.status,
            'status',
            SelectListStatus.saved,
          ),
        ],
      );
    });

    group('lists changed', () {
      test('picks a list that gained the video, such as one just created', () {
        stubLists([_list('empty')]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.toggled('empty');
        final listener = capturedListener();

        stubLists([
          _list('empty'),
          _list('fresh', videoEventIds: [_videoId]),
        ]);
        listener();

        expect(cubit.state.lists.map((list) => list.id), ['empty', 'fresh']);
        expect(cubit.state.memberListIds, {'fresh'});
        expect(cubit.state.selectedListIds, {'empty', 'fresh'});
        expect(cubit.state.status, SelectListStatus.editing);
      });

      test('unpicks a list that lost the video and drops one that is gone', () {
        stubLists([
          _list('lost', videoEventIds: [_videoId]),
          _list('gone'),
          _list('kept'),
        ]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit
          ..toggled('gone')
          ..toggled('kept');
        final listener = capturedListener();

        stubLists([_list('lost'), _list('kept')]);
        listener();

        expect(cubit.state.memberListIds, isEmpty);
        expect(cubit.state.selectedListIds, {'kept'});
      });

      test('uses the incoming membership snapshot for the pending notice', () {
        final pending = _list(
          'unpublished',
          videoEventIds: [_videoId],
        ).copyWith(pendingRepublish: true);
        stubLists([pending]);
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final listener = capturedListener();
        cubit.createdListWithVideoPendingSync();
        expect(cubit.state.status, SelectListStatus.videoPendingSync);

        stubLists([pending.copyWith(videoEventIds: [])]);
        listener();
        expect(cubit.state.status, SelectListStatus.recoveryPendingSync);
        expect(cubit.state.memberListIds, isEmpty);
        expect(cubit.state.selectedListIds, isEmpty);

        stubLists([pending]);
        listener();
        expect(cubit.state.status, SelectListStatus.videoPendingSync);
        expect(cubit.state.memberListIds, {'unpublished'});
        expect(cubit.state.selectedListIds, {'unpublished'});
        verifyNever(() => service.addVideoToList(any(), any()));
        verifyNever(() => service.removeVideoFromList(any(), any()));
      });

      test('keeps a save in progress on its status', () async {
        stubLists([_list('empty')]);
        final listener = <VoidCallback>[];
        when(() => service.addListener(any())).thenAnswer((invocation) {
          listener.add(invocation.positionalArguments.single as VoidCallback);
        });
        when(() => service.addVideoToList(any(), any())).thenAnswer((_) async {
          // The service notifies its listeners as it writes.
          stubLists([
            _list('empty', videoEventIds: [_videoId]),
          ]);
          listener.single();
          return true;
        });
        final cubit = buildCubit();
        addTearDown(cubit.close);
        cubit.toggled('empty');

        await cubit.submitted();

        expect(cubit.state.status, SelectListStatus.saved);
        expect(cubit.state.memberListIds, {'empty'});
        expect(cubit.state.selectedListIds, {'empty'});
      });
    });

    for (final retirement in ['account switch', 'permanent lease retirement']) {
      var currentOwner = _ownerPubkey;
      late Completer<bool> pendingWrite;
      blocTest<SelectListCubit, SelectListState>(
        '$retirement clears picks after an exceptional save completion',
        setUp: () {
          currentOwner = _ownerPubkey;
          pendingWrite = Completer<bool>();
          stubLists([_list('first'), _list('second')]);
          when(
            () => service.addVideoToList('$_ownerPubkey:first', _videoId),
          ).thenAnswer((_) => pendingWrite.future);
        },
        build: () => SelectListCubit(
          service: service,
          videoEventId: _videoId,
          currentOwnerPubkey: () => currentOwner,
        ),
        act: (cubit) async {
          cubit
            ..toggled('first')
            ..toggled('second');
          final saving = cubit.submitted();
          if (retirement == 'account switch') {
            currentOwner = 'e' * 64;
          } else {
            // The owner can still be A while its old permanent lease is gone.
            when(() => service.isCurrentSession).thenReturn(false);
          }
          pendingWrite.completeError(StateError('retired save'));
          expect(await saving, SelectListStatus.failure);
        },
        skip: 3,
        expect: () => [
          isA<SelectListState>()
              .having((s) => s.status, 'status', SelectListStatus.failure)
              .having((s) => s.lists, 'old lists', isEmpty)
              .having((s) => s.memberListIds, 'members', isEmpty)
              .having((s) => s.selectedListIds, 'old picks', isEmpty)
              .having((s) => s.syncingListIds, 'sync progress', isEmpty)
              .having((s) => s.failedSyncListIds, 'sync failures', isEmpty),
        ],
        verify: (_) {
          verify(
            () => service.addVideoToList('$_ownerPubkey:first', _videoId),
          ).called(1);
          verifyNever(
            () => service.addVideoToList('$_ownerPubkey:second', _videoId),
          );
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
        errors: () => [isA<StateError>()],
      );
    }

    test('a retired lease cannot revive when the same owner returns', () async {
      final pending = _list(
        'retired',
      ).copyWith(pendingPlaintextEventIds: ['c' * 64]);
      stubLists([pending]);
      final cubit = buildCubit();
      addTearDown(cubit.close);
      when(() => service.isCurrentSession).thenReturn(false);
      await cubit.syncRequested('retired');
      cubit.toggled('retired');
      expect(cubit.state.lists, isEmpty);
      expect(cubit.state.selectedListIds, isEmpty);
      expect(cubit.state.status, SelectListStatus.failure);
      verifyNever(() => service.retryListSync(any()));
      verifyNever(() => service.addVideoToList(any(), any()));
    });

    group('permission and deletion recovery', () {
      CuratedList recovery({bool member = false}) =>
          _list(
            'recovering',
            videoEventIds: member ? [_videoId] : const [],
            isPublic: false,
          ).copyWith(
            pendingVisibility: const CuratedListVisibility(
              isPublic: true,
              isCollaborative: false,
              allowedCollaborators: [],
              relayAccepted: true,
            ),
          );

      test(
        'a deletion-only retry is offered without video membership',
        () async {
          final pending = _list(
            'redaction',
          ).copyWith(pendingPlaintextEventIds: ['c' * 64]);
          stubLists([pending]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          expect(cubit.state.pendingSyncListIds, {'redaction'});
          when(
            () => service.retryListSync('$_ownerPubkey:redaction'),
          ).thenAnswer((_) async => false);
          await cubit.syncRequested('redaction');
          expect(cubit.state.status, SelectListStatus.syncFailed);
          expect(cubit.state.selectedListIds, isEmpty);
          expect(cubit.state.memberListIds, isEmpty);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
          when(
            () => service.retryListSync('$_ownerPubkey:redaction'),
          ).thenAnswer((_) async {
            stubLists([pending.copyWith(pendingPlaintextEventIds: [])]);
            return true;
          });
          await cubit.syncRequested('redaction');
          expect(cubit.state.pendingSyncListIds, isEmpty);
          expect(cubit.state.status, SelectListStatus.editing);
        },
      );

      test(
        'ACKed permission recovery blocks both adding and removing a pick',
        () {
          for (final member in [false, true]) {
            stubLists([recovery(member: member)]);
            final cubit = buildCubit();
            addTearDown(cubit.close);
            final before = cubit.state;
            cubit.toggled('recovering');
            expect(cubit.state, before);
            expect(cubit.state.pendingSyncListIds, {'recovering'});
          }
        },
      );

      test(
        'a permission ACK arriving after a draft pick prevents its write',
        () async {
          stubLists([_list('recovering', isPublic: false)]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.toggled('recovering');
          stubLists([recovery()]);
          expect(await cubit.submitted(), SelectListStatus.recoveryPendingSync);
          expect(cubit.state.lists, isNotEmpty);
          verifyNever(() => service.addVideoToList(any(), any()));
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      test(
        'explicit sync settles confirmed visibility before editing resumes',
        () async {
          final pending = recovery();
          stubLists([pending]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          when(
            () => service.retryListSync('$_ownerPubkey:recovering'),
          ).thenAnswer((_) async {
            stubLists([
              pending.copyWith(isPublic: true, clearPendingVisibility: true),
            ]);
            return true;
          });
          await cubit.syncRequested('recovering');
          expect(cubit.state.lists.single.isPublic, isTrue);
          expect(cubit.state.pendingSyncListIds, isEmpty);
          expect(cubit.state.selectedListIds, isEmpty);
          cubit.toggled('recovering');
          expect(cubit.state.selectedListIds, {'recovering'});
          verifyNever(() => service.addVideoToList(any(), any()));
        },
      );

      test(
        'another list can be edited while one waits for permission recovery',
        () async {
          stubLists([recovery(), _list('other')]);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          cubit.toggled('other');
          when(
            () => service.addVideoToList('$_ownerPubkey:other', _videoId),
          ).thenAnswer((_) async => true);
          expect(await cubit.submitted(), SelectListStatus.saved);
          verify(
            () => service.addVideoToList('$_ownerPubkey:other', _videoId),
          ).called(1);
          verifyNever(
            () => service.addVideoToList('$_ownerPubkey:recovering', any()),
          );
        },
      );
    });

    group('close', () {
      test('stops following the service', () async {
        stubLists([]);
        final cubit = buildCubit();
        final listener = capturedListener();

        await cubit.close();

        verify(() => service.removeListener(listener)).called(1);
      });
    });
  });

  group('SelectListCubit with owner-scoped recovery', () {
    test('a newer public winner stays editable through real deletion recovery '
        'after logout retires its older permission target', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final nostr = _MockNostrClient();
      final auth = _MockAuthService();
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(_ownerPubkey);
      stubListPublishing(client: nostr, auth: auth, pubkey: _ownerPubkey);
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      final oldEventId = 'c' * 64;
      final original = _list(
        'external-winner',
      ).copyWith(nostrEventId: oldEventId);
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([original.toJson()]),
      );
      final previousService = CuratedListService(
        nostrService: nostr,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(previousService.dispose);
      final sent = Completer<Event>();
      final accepted = Completer<PublishOutcome>();
      when(() => nostr.publishEventAwaitOk(any())).thenAnswer((invocation) {
        sent.complete(invocation.positionalArguments.single as Event);
        return accepted.future;
      });
      final privateRequest = previousService.updateList(
        listId: original.id,
        isPublic: false,
      );
      final privateEvent = await sent.future;
      final winner = original.copyWith(
        name: 'Newer public winner',
        nostrEventId: 'd' * 64,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          privateEvent.createdAt * 1000,
          isUtc: true,
        ).add(const Duration(seconds: 1)),
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([winner.toJson()]),
      );
      accepted.complete(acceptedOutcome(privateEvent));
      expect(await privateRequest, isFalse);
      expect(previousService.getListById(winner.id)!.isPublic, isTrue);

      // Cleanup proves supersession from the durable row before wiping it, and
      // preserves only the owner's event IDs and private-commit prerequisite.
      await UserDataCleanupService(
        prefs,
      ).clearUserSpecificData(userPubkey: _ownerPubkey);
      expect(previousService.isCurrentSession, isFalse);
      await prefs.reload();
      final journal = CuratedListRecoveryJournal(
        prefs: prefs,
        runCurrent: (operation) => operation(),
      );
      expect(journal.record(_ownerPubkey, winner.id)!.visibility, isNull);
      expect(
        journal.record(_ownerPubkey, winner.id)!.requiresPrivateCommit,
        isTrue,
      );
      await prefs.setString(
        CuratedListService.listsStorageKey,
        jsonEncode([winner.toJson()]),
      );
      await stubCommittedListAccount(auth: auth, preferences: prefs);
      final service = CuratedListService(
        nostrService: nostr,
        authService: auth,
        prefs: prefs,
      );
      addTearDown(service.dispose);
      final cubit = SelectListCubit(
        service: service,
        videoEventId: _videoId,
        currentOwnerPubkey: () => _ownerPubkey,
      );
      addTearDown(cubit.close);
      final recovered = cubit.state.lists.single;
      expect(recovered.name, winner.name);
      expect(recovered.nostrEventId, winner.nostrEventId);
      expect(recovered.publicationTarget.isPublic, isTrue);
      expect(recovered.pendingVisibility, isNull);
      expect(recovered.pendingPlaintextEventIds, [oldEventId]);
      expect(cubit.state.pendingSyncListIds, {winner.id});
      cubit.toggled(winner.id);
      expect(cubit.state.selectedListIds, {winner.id});
      expect(cubit.state.memberListIds, isEmpty);
      clearInteractions(nostr);
      clearInteractions(auth);

      await cubit.syncRequested(winner.id);

      expect(cubit.state.status, SelectListStatus.syncFailed);
      expect(cubit.state.selectedListIds, {winner.id});
      expect(cubit.state.memberListIds, isEmpty);
      expect(cubit.state.lists.single.publicationTarget.isPublic, isTrue);
      expect(cubit.state.lists.single.pendingVisibility, isNull);
      expect(cubit.state.lists.single.pendingPlaintextEventIds, [oldEventId]);
      expect(
        journal.record(_ownerPubkey, winner.id)!.requiresPrivateCommit,
        isTrue,
      );
      expect(journal.record(_ownerPubkey, winner.id)!.plaintextEventIds, [
        oldEventId,
      ]);
      verifyNever(() => nostr.publishEventAwaitOk(any()));
      verifyNever(() => nostr.publishEvent(any()));
      verifyNever(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
        ),
      );
      cubit.toggled(winner.id);
      expect(cubit.state.selectedListIds, isEmpty);
      expect(cubit.state.lists.single.isPublic, isTrue);
    });
  });
}
