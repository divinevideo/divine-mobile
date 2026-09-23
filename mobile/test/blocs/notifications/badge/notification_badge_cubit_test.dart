// ABOUTME: Unit tests for NotificationBadgeCubit.
// ABOUTME: Verifies stream subscription, emission, and cleanup.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

void main() {
  group(NotificationBadgeCubit, () {
    late _MockNotificationRepository repository;

    setUp(() {
      repository = _MockNotificationRepository();
    });

    NotificationBadgeCubit buildCubit() {
      return NotificationBadgeCubit(repository: repository);
    }

    test('initial state is 0', () async {
      when(
        () => repository.watchUnreadCount(),
      ).thenAnswer((_) => const Stream<int>.empty());

      final cubit = buildCubit();

      expect(cubit.state, equals(0));

      await cubit.close();
    });

    blocTest<NotificationBadgeCubit, int>(
      'emits counts from watchUnreadCount stream',
      setUp: () {
        when(
          () => repository.watchUnreadCount(),
        ).thenAnswer((_) => Stream.fromIterable([1, 3, 0]));
      },
      build: buildCubit,
      expect: () => const [1, 3, 0],
    );

    blocTest<NotificationBadgeCubit, int>(
      'forwards stream errors via addError',
      setUp: () {
        when(
          () => repository.watchUnreadCount(),
        ).thenAnswer((_) => Stream<int>.error(StateError('boom')));
      },
      build: buildCubit,
      errors: () => [isA<StateError>()],
    );

    test('emits zero with no subscription when repository is null', () async {
      final cubit = NotificationBadgeCubit();

      expect(cubit.state, equals(0));

      await cubit.close();
    });

    test('cancels subscription on close', () async {
      final controller = StreamController<int>();
      when(
        () => repository.watchUnreadCount(),
      ).thenAnswer((_) => controller.stream);

      final cubit = buildCubit();
      await cubit.close();

      // Adding to the controller after close should not throw — the
      // subscription was cancelled (and awaited) before super.close().
      controller.add(5);
      await controller.close();
    });
  });
}
