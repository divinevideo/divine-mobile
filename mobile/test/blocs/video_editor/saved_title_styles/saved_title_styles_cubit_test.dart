// ABOUTME: Tests for SavedTitleStylesCubit: loading the saved styles and
// ABOUTME: routing save, rename, delete and reorder through the repository.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/saved_title_styles/saved_title_styles_cubit.dart';
import 'package:openvine/models/video_editor/saved_title_style.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/repositories/saved_title_style_repository.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

class _MockSavedTitleStyleRepository extends Mock
    implements SavedTitleStyleRepository {}

void main() {
  const style = TitleStyle(
    fontIndex: 0,
    color: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    colorMode: LayerBackgroundMode.backgroundAndColor,
  );

  SavedTitleStyle saved(String id, {int orderIndex = 0}) => SavedTitleStyle(
    id: id,
    name: 'Style $id',
    style: style,
    createdAt: DateTime(2026, 9, 15),
    orderIndex: orderIndex,
  );

  final a = saved('a');
  final b = saved('b', orderIndex: 1);
  final c = saved('c', orderIndex: 2);

  group(SavedTitleStylesCubit, () {
    late _MockSavedTitleStyleRepository repository;

    setUp(() {
      repository = _MockSavedTitleStyleRepository();
    });

    setUpAll(() {
      registerFallbackValue(style);
    });

    group('load', () {
      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
        'emits loading then the saved styles',
        setUp: () {
          when(() => repository.getStyles()).thenAnswer((_) async => [a, b]);
        },
        build: () => SavedTitleStylesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        expect: () => [
          const SavedTitleStylesState(
            status: SavedTitleStylesStatus.loading,
          ),
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.ready,
            styles: [a, b],
          ),
        ],
      );

      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
        'reports a failure and keeps the list empty when the read throws',
        setUp: () {
          when(
            () => repository.getStyles(),
          ).thenThrow(StateError('database closed'));
        },
        build: () => SavedTitleStylesCubit(repository: repository),
        act: (cubit) => cubit.load(),
        expect: () => const [
          SavedTitleStylesState(status: SavedTitleStylesStatus.loading),
          SavedTitleStylesState(status: SavedTitleStylesStatus.failure),
        ],
        errors: () => [isA<StateError>()],
      );
    });

    group('save', () {
      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
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
        build: () => SavedTitleStylesCubit(repository: repository),
        act: (cubit) => cubit.save(name: 'Intro', style: style),
        expect: () => [
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.ready,
            styles: [a],
          ),
        ],
        verify: (_) {
          verify(
            () => repository.save(rawName: 'Intro', style: style),
          ).called(1);
        },
      );

      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
        'keeps the loaded list and reports a failure when the write throws',
        setUp: () {
          when(
            () => repository.save(
              rawName: any(named: 'rawName'),
              style: any(named: 'style'),
            ),
          ).thenThrow(StateError('disk full'));
        },
        build: () => SavedTitleStylesCubit(repository: repository),
        seed: () => SavedTitleStylesState(
          status: SavedTitleStylesStatus.ready,
          styles: [a],
        ),
        act: (cubit) => cubit.save(name: 'Intro', style: style),
        expect: () => [
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.failure,
            styles: [a],
          ),
        ],
        errors: () => [isA<StateError>()],
        verify: (_) => verifyNever(() => repository.getStyles()),
      );
    });

    group('rename', () {
      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
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
        build: () => SavedTitleStylesCubit(repository: repository),
        act: (cubit) => cubit.rename(id: 'a', name: 'Outro'),
        expect: () => [
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.ready,
            styles: [a.copyWith(name: 'Outro')],
          ),
        ],
        verify: (_) {
          verify(() => repository.rename(id: 'a', rawName: 'Outro')).called(1);
        },
      );
    });

    group('delete', () {
      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
        'deletes through the repository and reloads',
        setUp: () {
          when(() => repository.delete(any())).thenAnswer((_) async => true);
          when(() => repository.getStyles()).thenAnswer((_) async => [b]);
        },
        build: () => SavedTitleStylesCubit(repository: repository),
        seed: () => SavedTitleStylesState(
          status: SavedTitleStylesStatus.ready,
          styles: [a, b],
        ),
        act: (cubit) => cubit.delete('a'),
        expect: () => [
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.ready,
            styles: [b],
          ),
        ],
        verify: (_) => verify(() => repository.delete('a')).called(1),
      );
    });

    group('reorder', () {
      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
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
        build: () => SavedTitleStylesCubit(repository: repository),
        seed: () => SavedTitleStylesState(
          status: SavedTitleStylesStatus.ready,
          styles: [a, b, c],
        ),
        // Dragging the last row to the top: the target index is the final
        // position, as ReorderableListView.onReorderItem reports it.
        act: (cubit) => cubit.reorder(2, 0),
        expect: () => [
          SavedTitleStylesState(
            status: SavedTitleStylesStatus.ready,
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

      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
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
        build: () => SavedTitleStylesCubit(repository: repository),
        seed: () => SavedTitleStylesState(
          status: SavedTitleStylesStatus.ready,
          styles: [a, b, c],
        ),
        act: (cubit) => cubit.reorder(0, 2),
        verify: (_) {
          verify(() => repository.reorder(['b', 'c', 'a'])).called(1);
        },
      );

      blocTest<SavedTitleStylesCubit, SavedTitleStylesState>(
        'ignores a drop back onto the same position',
        build: () => SavedTitleStylesCubit(repository: repository),
        seed: () => SavedTitleStylesState(
          status: SavedTitleStylesStatus.ready,
          styles: [a, b, c],
        ),
        act: (cubit) => cubit.reorder(1, 1),
        expect: () => const <SavedTitleStylesState>[],
        verify: (_) => verifyNever(() => repository.reorder(any())),
      );
    });
  });
}
