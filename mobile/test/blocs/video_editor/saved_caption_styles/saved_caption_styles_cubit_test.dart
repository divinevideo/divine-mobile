// ABOUTME: Tests for SavedCaptionStylesCubit: loading the saved styles and
// ABOUTME: routing save, rename, delete and reorder through the repository.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/saved_caption_styles/saved_caption_styles_cubit.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/saved_caption_style.dart';
import 'package:openvine/repositories/saved_caption_style_repository.dart';

class _MockSavedCaptionStyleRepository extends Mock
    implements SavedCaptionStyleRepository {}

void main() {
  final style = CaptionCustomStyle.initial();

  SavedCaptionStyle saved(String id, {int orderIndex = 0}) => SavedCaptionStyle(
    id: id,
    name: 'Style $id',
    style: style,
    createdAt: DateTime(2026, 9, 15),
    orderIndex: orderIndex,
  );

  final a = saved('a');
  final b = saved('b', orderIndex: 1);
  final c = saved('c', orderIndex: 2);

  group(SavedCaptionStylesCubit, () {
    late _MockSavedCaptionStyleRepository repository;

    setUp(() {
      repository = _MockSavedCaptionStyleRepository();
    });

    setUpAll(() {
      registerFallbackValue(CaptionCustomStyle.initial());
    });

    group('load', () {
      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'emits loading then the saved styles',
        setUp: () {
          when(() => repository.getStyles()).thenAnswer((_) async => [a, b]);
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        expect: () => [
          const SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.loading,
          ),
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.ready,
            styles: [a, b],
          ),
        ],
      );

      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'reports a failure and keeps the list empty when the read throws',
        setUp: () {
          when(
            () => repository.getStyles(),
          ).thenThrow(StateError('database closed'));
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        expect: () => const [
          SavedCaptionStylesState(status: SavedCaptionStylesStatus.loading),
          SavedCaptionStylesState(status: SavedCaptionStylesStatus.failure),
        ],
        errors: () => [isA<StateError>()],
      );
    });

    group('save', () {
      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'writes through the repository and reloads the list',
        setUp: () {
          when(
            () => repository.save(
              rawName: any(named: 'rawName'),
              style: any(named: 'style'),
            ),
          ).thenAnswer((_) async => a);
          when(() => repository.getStyles()).thenAnswer((_) async => [a]);
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        act: (cubit) => cubit.save(name: 'Intro', style: style),
        expect: () => [
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.ready,
            styles: [a],
          ),
        ],
        verify: (_) {
          verify(
            () => repository.save(rawName: 'Intro', style: style),
          ).called(1);
        },
      );

      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'keeps the loaded list and reports a failure when the write throws',
        setUp: () {
          when(
            () => repository.save(
              rawName: any(named: 'rawName'),
              style: any(named: 'style'),
            ),
          ).thenThrow(StateError('disk full'));
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        seed: () => SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.ready,
          styles: [a],
        ),
        act: (cubit) => cubit.save(name: 'Intro', style: style),
        expect: () => [
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.failure,
            styles: [a],
          ),
        ],
        errors: () => [isA<StateError>()],
        verify: (_) => verifyNever(() => repository.getStyles()),
      );
    });

    group('rename', () {
      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'renames through the repository and reloads',
        setUp: () {
          when(
            () => repository.rename(
              id: any(named: 'id'),
              rawName: any(named: 'rawName'),
            ),
          ).thenAnswer((_) async => true);
          when(
            () => repository.getStyles(),
          ).thenAnswer((_) async => [a.copyWith(name: 'Outro')]);
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        act: (cubit) => cubit.rename(id: 'a', name: 'Outro'),
        expect: () => [
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.ready,
            styles: [a.copyWith(name: 'Outro')],
          ),
        ],
        verify: (_) {
          verify(() => repository.rename(id: 'a', rawName: 'Outro')).called(1);
        },
      );
    });

    group('delete', () {
      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'deletes through the repository and reloads',
        setUp: () {
          when(() => repository.delete(any())).thenAnswer((_) async => true);
          when(() => repository.getStyles()).thenAnswer((_) async => [b]);
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        seed: () => SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.ready,
          styles: [a, b],
        ),
        act: (cubit) => cubit.delete('a'),
        expect: () => [
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.ready,
            styles: [b],
          ),
        ],
        verify: (_) => verify(() => repository.delete('a')).called(1),
      );
    });

    group('reorder', () {
      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'shows the new order at once, then persists and reloads it',
        setUp: () {
          when(() => repository.reorder(any())).thenAnswer((_) async {});
          when(() => repository.getStyles()).thenAnswer(
            (_) async => [
              c.copyWith(orderIndex: 0),
              a.copyWith(orderIndex: 1),
              b.copyWith(orderIndex: 2),
            ],
          );
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        seed: () => SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.ready,
          styles: [a, b, c],
        ),
        // Dragging the last row to the top: the target index is the final
        // position, as ReorderableListView.onReorderItem reports it.
        act: (cubit) => cubit.reorder(2, 0),
        expect: () => [
          SavedCaptionStylesState(
            status: SavedCaptionStylesStatus.ready,
            styles: [
              c.copyWith(orderIndex: 0),
              a.copyWith(orderIndex: 1),
              b.copyWith(orderIndex: 2),
            ],
          ),
        ],
        verify: (_) {
          verify(() => repository.reorder(['c', 'a', 'b'])).called(1);
        },
      );

      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'moves a row down to the end',
        setUp: () {
          when(() => repository.reorder(any())).thenAnswer((_) async {});
          when(() => repository.getStyles()).thenAnswer(
            (_) async => [
              b.copyWith(orderIndex: 0),
              c.copyWith(orderIndex: 1),
              a.copyWith(orderIndex: 2),
            ],
          );
        },
        build: () => SavedCaptionStylesCubit(repository: repository),
        seed: () => SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.ready,
          styles: [a, b, c],
        ),
        act: (cubit) => cubit.reorder(0, 2),
        verify: (_) {
          verify(() => repository.reorder(['b', 'c', 'a'])).called(1);
        },
      );

      blocTest<SavedCaptionStylesCubit, SavedCaptionStylesState>(
        'ignores a drop back onto the same position',
        build: () => SavedCaptionStylesCubit(repository: repository),
        seed: () => SavedCaptionStylesState(
          status: SavedCaptionStylesStatus.ready,
          styles: [a, b, c],
        ),
        act: (cubit) => cubit.reorder(1, 1),
        expect: () => const <SavedCaptionStylesState>[],
        verify: (_) => verifyNever(() => repository.reorder(any())),
      );
    });
  });
}
