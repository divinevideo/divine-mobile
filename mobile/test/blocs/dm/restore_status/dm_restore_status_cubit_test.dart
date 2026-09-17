// ABOUTME: Tests for DmRestoreStatusCubit, which publishes app-scoped DM
// ABOUTME: history-recovery status so an empty view can say "maybe not yet"
// ABOUTME: instead of asserting a conversation is empty.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/restore_status/dm_restore_status_cubit.dart';

class _MockDmRepository extends Mock implements DmRepository {}

void main() {
  group(DmRestoreStatusCubit, () {
    late _MockDmRepository dmRepository;

    setUp(() {
      dmRepository = _MockDmRepository();
      when(() => dmRepository.isRecoveringHistory).thenReturn(false);
      when(() => dmRepository.hasAttemptedHistoryRecovery).thenReturn(false);
      when(
        () => dmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(true);
      when(
        () => dmRepository.historyRecoveryStream,
      ).thenAnswer((_) => const Stream<bool>.empty());
    });

    test('seeds from the repository because the stream does not replay', () {
      when(() => dmRepository.isRecoveringHistory).thenReturn(true);
      when(() => dmRepository.hasAttemptedHistoryRecovery).thenReturn(true);
      when(
        () => dmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(false);

      final cubit = DmRestoreStatusCubit(dmRepository: dmRepository);
      addTearDown(cubit.close);

      expect(cubit.state.isRestoring, isTrue);
      expect(cubit.state.isComplete, isFalse);
      expect(cubit.state.mayBeIncomplete, isTrue);
    });

    test(
      'a fresh repository reports nothing outstanding before a drain runs',
      () {
        when(
          () => dmRepository.hasCompletedHistoryRecoveryBefore,
        ).thenReturn(false);

        final cubit = DmRestoreStatusCubit(dmRepository: dmRepository);
        addTearDown(cubit.close);

        expect(cubit.state.mayBeIncomplete, isFalse);
      },
    );

    test('a settled repository reports nothing outstanding', () {
      when(() => dmRepository.hasAttemptedHistoryRecovery).thenReturn(true);

      final cubit = DmRestoreStatusCubit(dmRepository: dmRepository);
      addTearDown(cubit.close);

      expect(cubit.state.mayBeIncomplete, isFalse);
    });

    blocTest<DmRestoreStatusCubit, DmRestoreStatusState>(
      'a drain that stops without completing still reports outstanding work',
      setUp: () {
        // The exact desync this exists for: every drain exit that is not a
        // clean exhaustion — page cap, exception, no connected relay — ends
        // the running flag while leaving the persisted flag false.
        when(() => dmRepository.isRecoveringHistory).thenReturn(true);
        when(() => dmRepository.hasAttemptedHistoryRecovery).thenReturn(true);
        when(
          () => dmRepository.hasCompletedHistoryRecoveryBefore,
        ).thenReturn(false);
        when(
          () => dmRepository.historyRecoveryStream,
        ).thenAnswer((_) => Stream<bool>.value(false));
      },
      build: () => DmRestoreStatusCubit(dmRepository: dmRepository),
      wait: const Duration(milliseconds: 50),
      verify: (cubit) {
        expect(cubit.state.isRestoring, isFalse);
        expect(cubit.state.hasAttempted, isTrue);
        expect(cubit.state.isComplete, isFalse);
        expect(cubit.state.mayBeIncomplete, isTrue);
      },
    );

    blocTest<DmRestoreStatusCubit, DmRestoreStatusState>(
      're-reads the persisted flag on every recovery tick',
      setUp: () {
        when(() => dmRepository.isRecoveringHistory).thenReturn(true);
        when(() => dmRepository.hasAttemptedHistoryRecovery).thenReturn(true);
        when(
          () => dmRepository.hasCompletedHistoryRecoveryBefore,
        ).thenReturn(false);
        final controller = StreamController<bool>();
        when(
          () => dmRepository.historyRecoveryStream,
        ).thenAnswer((_) => controller.stream);
        final recovery =
            Future<void>.delayed(
              const Duration(milliseconds: 20),
            ).then((_) {
              when(
                () => dmRepository.hasCompletedHistoryRecoveryBefore,
              ).thenReturn(true);
              when(
                () => dmRepository.hasAttemptedHistoryRecovery,
              ).thenReturn(true);
              controller.add(false);
            });
        addTearDown(() => recovery);
      },
      build: () => DmRestoreStatusCubit(dmRepository: dmRepository),
      wait: const Duration(milliseconds: 100),
      verify: (cubit) {
        expect(cubit.state.mayBeIncomplete, isFalse);
      },
    );

    test('cancels its subscription on close', () async {
      final controller = StreamController<bool>();
      when(
        () => dmRepository.historyRecoveryStream,
      ).thenAnswer((_) => controller.stream);

      final cubit = DmRestoreStatusCubit(dmRepository: dmRepository);
      expect(controller.hasListener, isTrue);

      await cubit.close();

      expect(controller.hasListener, isFalse);
      await controller.close();
    });
  });
}
