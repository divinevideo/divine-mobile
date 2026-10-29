import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/rooms/rooms_cubit.dart';

class _MockRoomActivityRepository extends Mock
    implements RoomActivityRepository {}

void main() {
  group(RoomsCubit, () {
    const loading = RoomActivitySummary(channelId: 'general');
    const loaded = RoomActivitySummary(
      channelId: 'general',
      unreadCount: 3,
      loading: false,
    );

    late _MockRoomActivityRepository repository;
    late StreamController<void> changes;
    late Map<String, RoomActivitySummary> summaries;

    setUp(() {
      repository = _MockRoomActivityRepository();
      changes = StreamController<void>.broadcast();
      summaries = {'general': loading};
      when(
        () => repository.summaries,
      ).thenAnswer((_) => Map.unmodifiable(summaries));
      when(() => repository.changes).thenAnswer((_) => changes.stream);
      when(() => repository.start()).thenAnswer((_) async {});
    });

    tearDown(() => changes.close());

    test('starts from the repository summaries', () {
      final cubit = RoomsCubit(repository);
      addTearDown(cubit.close);
      expect(cubit.state['general'], same(loading));
    });

    blocTest<RoomsCubit, Map<String, RoomActivitySummary>>(
      'emits the repository summaries after each change',
      build: () => RoomsCubit(repository),
      act: (cubit) async {
        summaries = {'general': loaded};
        changes.add(null);
        await pumpEventQueue();
      },
      expect: () => [
        isA<Map<String, RoomActivitySummary>>().having(
          (state) => state['general'],
          'general',
          same(loaded),
        ),
      ],
    );

    test('stops listening for changes once closed', () async {
      final cubit = RoomsCubit(repository);
      expect(changes.hasListener, isTrue);
      await cubit.close();
      expect(changes.hasListener, isFalse);
    });

    test('start starts every room through the repository', () async {
      final cubit = RoomsCubit(repository);
      addTearDown(cubit.close);
      await cubit.start();
      verify(() => repository.start()).called(1);
    });
  });
}
