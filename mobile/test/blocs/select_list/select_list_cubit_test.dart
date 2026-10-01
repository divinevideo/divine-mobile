// ABOUTME: Tests for SelectListCubit: which lists are picked, how the picks
// ABOUTME: are written, and how the lists on offer follow the service.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/select_list/select_list_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

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
    });

    void stubLists(List<CuratedList> lists) {
      when(() => service.myLists).thenReturn(lists);
    }

    SelectListCubit buildCubit() =>
        SelectListCubit(service: service, videoEventId: _videoId);

    /// The listener the cubit registered on the service.
    VoidCallback capturedListener() =>
        verify(() => service.addListener(captureAny())).captured.single
            as VoidCallback;

    group('initial state', () {
      test(
        "offers the viewer's lists with those holding the video picked",
        () {
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
        },
      );
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
          verify(() => service.addVideoToList('first', _videoId)).called(1);
          verify(() => service.addVideoToList('second', _videoId)).called(1);
          verify(
            () => service.removeVideoFromList('holds', _videoId),
          ).called(1);
          verifyNever(() => service.addVideoToList('holds', any()));
        },
      );

      blocTest<SelectListCubit, SelectListState>(
        'keeps the sheet open with the picks when a list refuses the change',
        setUp: () {
          stubLists([_list('works'), _list('refuses')]);
          when(
            () => service.addVideoToList('works', any()),
          ).thenAnswer((_) async => true);
          when(
            () => service.addVideoToList('refuses', any()),
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

        verify(() => service.addVideoToList('empty', _videoId)).called(1);
        expect(cubit.state.status, SelectListStatus.saved);
      });
    });

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
              .having((s) => s.status, 'status', SelectListStatus.failure)
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

      test('keeps a save in progress on its status', () async {
        stubLists([_list('empty')]);
        final listener = <VoidCallback>[];
        when(
          () => service.addListener(any()),
        ).thenAnswer((invocation) {
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
}
