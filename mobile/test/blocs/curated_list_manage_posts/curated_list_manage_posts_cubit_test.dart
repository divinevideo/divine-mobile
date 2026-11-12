// ABOUTME: Tests for CuratedListManagePostsCubit: selection toggling and
// ABOUTME: batch removal outcomes including partial failure and close-guard.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

CuratedList _listWith(List<String> videoEventIds) => CuratedList(
  id: 'list-1',
  name: 'List One',
  videoEventIds: videoEventIds,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group(CuratedListManagePostsCubit, () {
    late _MockCuratedListService service;

    setUp(() {
      service = _MockCuratedListService();
    });

    CuratedListManagePostsCubit buildCubit() =>
        CuratedListManagePostsCubit(service: service, listId: 'list-1');

    /// Serves list-1 holding [items] until a removal drops one; the returned
    /// items are live, for removal stubs to drop from.
    List<String> stubListHolding(List<String> items) {
      final live = [...items];
      when(
        () => service.getListById('list-1'),
      ).thenAnswer((_) => _listWith([...live]));
      return live;
    }

    group('togglePost', () {
      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'adds then removes a video id',
        build: buildCubit,
        act: (cubit) => cubit
          ..togglePost('a')
          ..togglePost('b')
          ..togglePost('a'),
        expect: () => const [
          CuratedListManagePostsState(selectedVideoIds: {'a'}),
          CuratedListManagePostsState(selectedVideoIds: {'a', 'b'}),
          CuratedListManagePostsState(selectedVideoIds: {'b'}),
        ],
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'is ignored while a removal is running',
        build: buildCubit,
        seed: () => const CuratedListManagePostsState(
          status: CuratedListManagePostsStatus.removing,
          selectedVideoIds: {'a'},
        ),
        act: (cubit) => cubit.togglePost('b'),
        expect: () => const <CuratedListManagePostsState>[],
      );
    });

    group('removeSelected', () {
      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'does nothing with an empty selection',
        build: buildCubit,
        act: (cubit) => cubit.removeSelected(),
        expect: () => const <CuratedListManagePostsState>[],
        verify: (_) {
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'removes every selected post and reports success',
        build: buildCubit,
        setUp: () {
          final items = stubListHolding(['a', 'b']);
          when(
            () => service.removeVideoFromList('list-1', any()),
          ).thenAnswer((invocation) async {
            items.remove(invocation.positionalArguments[1]);
            return true;
          });
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.success,
            removedCount: 2,
          ),
        ],
        verify: (_) {
          verify(() => service.removeVideoFromList('list-1', 'a')).called(1);
          verify(() => service.removeVideoFromList('list-1', 'b')).called(1);
        },
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'counts a queued-republish removal as removed, not failed',
        build: buildCubit,
        setUp: () {
          final items = stubListHolding(['a', 'b']);
          when(
            () => service.removeVideoFromList('list-1', 'a'),
          ).thenAnswer((_) async => items.remove('a'));
          // False with the post gone: the service commits the removal
          // locally before publishing and queues a republish on failure,
          // so the grid no longer shows the post (#8453 review).
          when(
            () => service.removeVideoFromList('list-1', 'b'),
          ).thenAnswer((_) async => !items.remove('b'));
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.success,
            removedCount: 2,
          ),
        ],
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'reports failure for a post that is still in the list',
        build: buildCubit,
        setUp: () {
          final items = stubListHolding(['a', 'b']);
          when(
            () => service.removeVideoFromList('list-1', 'a'),
          ).thenAnswer((_) async => items.remove('a'));
          when(
            () => service.removeVideoFromList('list-1', 'b'),
          ).thenAnswer((_) async => false);
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.failure,
            removedCount: 1,
            failedCount: 1,
          ),
        ],
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'counts a throwing removal as failed and keeps going',
        build: buildCubit,
        setUp: () {
          final items = stubListHolding(['a', 'b']);
          when(
            () => service.removeVideoFromList('list-1', 'a'),
          ).thenAnswer((_) async => throw Exception('relay down'));
          when(
            () => service.removeVideoFromList('list-1', 'b'),
          ).thenAnswer((_) async => items.remove('b'));
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.failure,
            removedCount: 1,
            failedCount: 1,
          ),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(() => service.removeVideoFromList('list-1', 'b')).called(1);
        },
      );

      group('an addressable post (#7135)', () {
        final eventId = 'e' * 64;
        final olderEventId = 'd' * 64;
        final address = '34236:${'a' * 64}:clip';

        test('is removed where the list holds it by its coordinate', () async {
          final items = stubListHolding([address, olderEventId]);
          when(
            () => service.removeVideoFromList('list-1', address),
          ).thenAnswer((_) async => items.remove(address));
          final cubit = buildCubit()
            ..togglePost(eventId, videoAddress: address);
          addTearDown(cubit.close);

          await cubit.removeSelected();

          expect(cubit.state.status, CuratedListManagePostsStatus.success);
          expect(cubit.state.removedCount, 1);
          expect(cubit.state.selectedVideoAddresses, isEmpty);
          verify(
            () => service.removeVideoFromList('list-1', address),
          ).called(1);
          verifyNever(() => service.removeVideoFromList('list-1', eventId));
          verifyNever(
            () => service.removeVideoFromList('list-1', olderEventId),
          );
        });

        test('is removed under every name the list holds it by', () async {
          final items = stubListHolding([eventId, address]);
          when(
            () => service.removeVideoFromList('list-1', any()),
          ).thenAnswer(
            (invocation) async =>
                items.remove(invocation.positionalArguments[1]),
          );
          final cubit = buildCubit()
            ..togglePost(eventId, videoAddress: address);
          addTearDown(cubit.close);

          await cubit.removeSelected();

          expect(cubit.state.status, CuratedListManagePostsStatus.success);
          verify(
            () => service.removeVideoFromList('list-1', eventId),
          ).called(1);
          verify(
            () => service.removeVideoFromList('list-1', address),
          ).called(1);
        });

        test(
          'counts as failed while the list still holds its coordinate',
          () async {
            stubListHolding([address]);
            when(
              () => service.removeVideoFromList('list-1', any()),
            ).thenAnswer((_) async => false);
            final cubit = buildCubit()
              ..togglePost(eventId, videoAddress: address);
            addTearDown(cubit.close);

            await cubit.removeSelected();

            expect(cubit.state.status, CuratedListManagePostsStatus.failure);
            expect(cubit.state.failedCount, 1);
          },
        );

        test('keeps its coordinate while it is selected', () {
          final cubit = buildCubit()
            ..togglePost(eventId, videoAddress: address);
          addTearDown(cubit.close);
          expect(cubit.state.selectedVideoAddresses, {eventId: address});

          cubit.togglePost(eventId, videoAddress: address);

          expect(cubit.state.selectedVideoIds, isEmpty);
          expect(cubit.state.selectedVideoAddresses, isEmpty);
        });
      });

      // A list saved before #7135 can hold a post by the event id of an older
      // version; removing the post has to drop that item as well.
      group('an older version of a post (#7135)', () {
        final eventId = 'e' * 64;
        final olderEventId = 'd' * 64;
        final otherEventId = 'f' * 64;
        final address = '34236:${'a' * 64}:clip';

        CuratedListManagePostsCubit buildResolvingCubit(
          CuratedListVideoAddressResolver resolve,
        ) => CuratedListManagePostsCubit(
          service: service,
          listId: 'list-1',
          resolveVideoAddresses: resolve,
        );

        test('is removed with the post', () async {
          final items = stubListHolding([otherEventId, olderEventId, address]);
          when(() => service.removeVideoFromList('list-1', any())).thenAnswer(
            (invocation) async =>
                items.remove(invocation.positionalArguments[1]),
          );
          final requested = <List<String>>[];
          final cubit = buildResolvingCubit((ids) async {
            requested.add(ids);
            return {olderEventId: address};
          })..togglePost(eventId, videoAddress: address);
          addTearDown(cubit.close);

          await cubit.removeSelected();

          expect(requested, [
            [otherEventId, olderEventId],
          ]);
          expect(cubit.state.status, CuratedListManagePostsStatus.success);
          verify(
            () => service.removeVideoFromList('list-1', olderEventId),
          ).called(1);
          verify(
            () => service.removeVideoFromList('list-1', address),
          ).called(1);
          verifyNever(
            () => service.removeVideoFromList('list-1', otherEventId),
          );
        });

        test('counts the post as failed while the list still holds the older '
            'version', () async {
          stubListHolding([olderEventId]);
          when(
            () => service.removeVideoFromList('list-1', any()),
          ).thenAnswer((_) async => false);
          final cubit = buildResolvingCubit(
            (_) async => {olderEventId: address},
          )..togglePost(eventId, videoAddress: address);
          addTearDown(cubit.close);

          await cubit.removeSelected();

          expect(cubit.state.status, CuratedListManagePostsStatus.failure);
          expect(cubit.state.failedCount, 1);
        });

        test(
          'still removes the names it knows when the lookup fails',
          () async {
            final items = stubListHolding([olderEventId, address]);
            when(
              () => service.removeVideoFromList('list-1', address),
            ).thenAnswer((_) async => items.remove(address));
            final cubit = buildResolvingCubit(
              (_) async => throw Exception('relay down'),
            )..togglePost(eventId, videoAddress: address);
            addTearDown(cubit.close);

            await cubit.removeSelected();

            expect(cubit.state.status, CuratedListManagePostsStatus.success);
            verify(
              () => service.removeVideoFromList('list-1', address),
            ).called(1);
            verifyNever(
              () => service.removeVideoFromList('list-1', olderEventId),
            );
          },
        );

        test('asks nothing when no selected post has a coordinate', () async {
          final items = stubListHolding([eventId, olderEventId]);
          when(
            () => service.removeVideoFromList('list-1', eventId),
          ).thenAnswer((_) async => items.remove(eventId));
          var asked = false;
          final cubit = buildResolvingCubit((_) async {
            asked = true;
            return const {};
          })..togglePost(eventId);
          addTearDown(cubit.close);

          await cubit.removeSelected();

          expect(asked, isFalse);
          expect(cubit.state.status, CuratedListManagePostsStatus.success);
        });
      });

      test('does not throw when closed mid-removal', () async {
        stubListHolding(['a']);
        final gate = Completer<bool>();
        when(
          () => service.removeVideoFromList('list-1', 'a'),
        ).thenAnswer((_) => gate.future);

        final cubit = buildCubit()..togglePost('a');
        final removal = cubit.removeSelected();
        await cubit.close();
        verify(() => service.removeVideoFromList('list-1', 'a')).called(1);
        gate.complete(true);

        await expectLater(removal, completes);
      });
    });
  });
}
