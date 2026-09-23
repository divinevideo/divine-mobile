// ABOUTME: Tests SoundSyncCubit status transitions.
// ABOUTME: Pins that no error strings or exceptions land in state.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_cubit.dart';
import 'package:openvine/blocs/creator_sync/sound_sync_state.dart';
import 'package:openvine/observability/reportable_error.dart';

class _MockRepository extends Mock implements SoundSyncRepository {}

class _CapturingObserver extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  group(SoundSyncCubit, () {
    late _MockRepository repository;

    setUp(() => repository = _MockRepository());

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits syncing then success on a clean pass',
      build: () {
        when(repository.reconcile).thenAnswer(
          (_) async => const SoundSyncOutcome(
            pulled: 2,
            pushed: 1,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.success, pulled: 2, pushed: 1),
      ],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits failure without reporting an expected relay error',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(SyncIndexException('relay down'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [isA<SyncIndexException>()],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits locked when the vault key is unavailable',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(VaultKeyUnavailableException('relay unreachable'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.locked),
      ],
      errors: () => [isA<VaultKeyUnavailableException>()],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'ignores a second syncNow while one is in flight',
      build: () {
        when(repository.reconcile).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return const SoundSyncOutcome(
            pulled: 0,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          );
        });
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) async {
        unawaited(cubit.syncNow());
        await cubit.syncNow();
      },
      verify: (_) => verify(repository.reconcile).called(1),
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'emits failure and reports an unexpected error, e.g. a malformed '
      'remote body',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(const FormatException('Saved sound missing audio'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) => cubit.syncNow(),
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [
        isA<Reportable<Object>>().having(
          (r) => r.unwrap(),
          'unwrap',
          isA<FormatException>(),
        ),
      ],
    );

    blocTest<SoundSyncCubit, SoundSyncState>(
      'does not wedge sync after an unexpected error — a later syncNow '
      'still calls reconcile',
      build: () {
        when(
          repository.reconcile,
        ).thenThrow(const FormatException('Saved sound missing audio'));
        return SoundSyncCubit(repository: repository);
      },
      act: (cubit) async {
        await cubit.syncNow();
        await cubit.syncNow();
      },
      expect: () => const [
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
        SoundSyncState(status: SoundSyncStatus.syncing),
        SoundSyncState(status: SoundSyncStatus.failure),
      ],
      errors: () => [
        isA<Reportable<Object>>(),
        isA<Reportable<Object>>(),
      ],
      verify: (_) => verify(repository.reconcile).called(2),
    );

    test(
      'does not throw or report a spurious error when the cubit closes '
      'while reconcile is in flight',
      () async {
        // Pins the success-path `isClosed` guard in syncNow(): without it,
        // emitting after close throws a StateError that the catch-all
        // wraps as Reportable and forwards to the observer — a spurious
        // Crashlytics report on every close-mid-sync navigation.
        final completer = Completer<SoundSyncOutcome>();
        when(repository.reconcile).thenAnswer((_) => completer.future);
        final observer = _CapturingObserver();
        final priorObserver = Bloc.observer;
        Bloc.observer = observer;
        addTearDown(() => Bloc.observer = priorObserver);

        final cubit = SoundSyncCubit(repository: repository);
        addTearDown(() async {
          if (!cubit.isClosed) await cubit.close();
        });

        final syncFuture = cubit.syncNow();
        await cubit.close();
        completer.complete(
          const SoundSyncOutcome(
            pulled: 0,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );

        await expectLater(syncFuture, completes);
        expect(observer.errors, isEmpty);
      },
    );
  });
}
