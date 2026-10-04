import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_cubit.dart';
import 'package:openvine/blocs/shorebird_patch/shorebird_patch_state.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    this.isAvailable = true,
    this.current,
    this.next,
    this.hasExplicitNext = false,
    this.updateStatus = UpdateStatus.upToDate,
    this.readThrows = false,
    this.checkCompleter,
    this.checkThrows = false,
    this.updateThrows = false,
  });

  @override
  final bool isAvailable;
  Patch? current;
  Patch? next;
  final bool hasExplicitNext;
  UpdateStatus updateStatus;
  bool readThrows;
  Completer<UpdateStatus>? checkCompleter;
  final bool checkThrows;
  final bool updateThrows;
  void Function()? onCheck;
  void Function()? onUpdate;
  UpdateTrack? checkedTrack;
  UpdateTrack? updatedTrack;
  int checkCalls = 0;
  int updateCalls = 0;

  @override
  Future<Patch?> readCurrentPatch() async {
    if (readThrows) throw Exception('read failed');
    return current;
  }

  @override
  Future<Patch?> readNextPatch() async {
    if (readThrows) throw Exception('read failed');
    return next != null || hasExplicitNext ? next : current;
  }

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    checkCalls++;
    checkedTrack = track;
    onCheck?.call();
    if (checkThrows) throw Exception('check failed');
    return checkCompleter?.future ?? updateStatus;
  }

  @override
  Future<void> update({UpdateTrack? track}) async {
    updateCalls++;
    updatedTrack = track;
    onUpdate?.call();
    if (updateThrows) throw Exception('update failed');
  }
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  ShorebirdPatchCubit cubitFor(_FakeUpdater updater) => ShorebirdPatchCubit(
    repository: ShorebirdPatchRepository(
      updater: updater,
      preferences: preferences,
    ),
  );

  group(ShorebirdPatchCubit, () {
    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'load preserves the staging escape hatch when patch reads fail',
      setUp: () async {
        await preferences.setString('shorebird_subscribed_track', 'staging');
      },
      build: () => cubitFor(_FakeUpdater(readThrows: true)),
      act: (cubit) => cubit.load(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.failure,
          usesStagingTrack: true,
        ),
      ],
      errors: () => [isNotNull],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'load preserves the staging escape hatch when updater is unavailable',
      setUp: () async {
        await preferences.setString('shorebird_subscribed_track', 'staging');
      },
      build: () => cubitFor(_FakeUpdater(isAvailable: false)),
      act: (cubit) => cubit.load(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.unavailable,
          usesStagingTrack: true,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'load reports not checked and refreshes the running patch',
      build: () => cubitFor(_FakeUpdater(current: const Patch(number: 7))),
      act: (cubit) => cubit.load(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.notChecked,
          currentPatchNumber: 7,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'load reports unavailable without reading patch state',
      build: () => cubitFor(_FakeUpdater(isAvailable: false, readThrows: true)),
      act: (cubit) => cubit.load(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.unavailable),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'load reports read failures through state and the error channel',
      build: () => cubitFor(_FakeUpdater(readThrows: true)),
      act: (cubit) => cubit.load(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.failure),
      ],
      errors: () => [isNotNull],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'check distinguishes a downloaded patch from rollback',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.notChecked,
      ),
      build: () => cubitFor(
        _FakeUpdater(
          current: const Patch(number: 3),
          next: const Patch(number: 4),
          updateStatus: UpdateStatus.restartRequired,
        ),
      ),
      act: (cubit) => cubit.checkStagingTrack(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.checking),
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.restartRequired,
          currentPatchNumber: 3,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'check reports rollback when the next patch was removed',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.notChecked,
      ),
      build: () => cubitFor(
        _FakeUpdater(
          current: const Patch(number: 3),
          hasExplicitNext: true,
          updateStatus: UpdateStatus.restartRequired,
        ),
      ),
      act: (cubit) => cubit.checkStagingTrack(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.checking),
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.rollbackRequired,
          currentPatchNumber: 3,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'check still reports rollback after current is uninstalled',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.notChecked,
        currentPatchNumber: 3,
      ),
      build: () {
        final updater = _FakeUpdater(
          current: const Patch(number: 3),
          hasExplicitNext: true,
          updateStatus: UpdateStatus.restartRequired,
        );
        updater.onCheck = () => updater.current = null;
        return cubitFor(updater);
      },
      act: (cubit) => cubit.checkStagingTrack(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.checking,
          currentPatchNumber: 3,
        ),
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.rollbackRequired,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'check reports failures through state and the error channel',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.notChecked,
      ),
      build: () => cubitFor(_FakeUpdater(checkThrows: true)),
      act: (cubit) => cubit.checkStagingTrack(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.checking),
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.failure),
      ],
      errors: () => [isA<Exception>()],
    );

    test('Apply is gated until a check reports an available update', () async {
      final updater = _FakeUpdater();
      final cubit = cubitFor(updater);
      addTearDown(cubit.close);

      await cubit.applyStagedPatch();

      expect(updater.updateCalls, 0);
    });

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'apply reports unchanged when update installs nothing',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.updateAvailable,
      ),
      build: () => cubitFor(_FakeUpdater()),
      act: (cubit) => cubit.applyStagedPatch(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.applying),
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.unchanged),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'apply reports installed only when a new next patch appears',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.updateAvailable,
        currentPatchNumber: 3,
      ),
      build: () {
        final updater = _FakeUpdater(current: const Patch(number: 3));
        updater.onUpdate = () => updater.next = const Patch(number: 4);
        return cubitFor(updater);
      },
      act: (cubit) => cubit.applyStagedPatch(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.applying,
          currentPatchNumber: 3,
        ),
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.applied,
          currentPatchNumber: 3,
          usesStagingTrack: true,
        ),
      ],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'apply reports failures through state and the error channel',
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.updateAvailable,
      ),
      build: () => cubitFor(_FakeUpdater(updateThrows: true)),
      act: (cubit) => cubit.applyStagedPatch(),
      expect: () => const [
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.applying),
        ShorebirdPatchState(status: ShorebirdPatchValidationStatus.failure),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<ShorebirdPatchCubit, ShorebirdPatchState>(
      'returning to stable is busy until the subscription is persisted',
      setUp: () async {
        await preferences.setString('shorebird_subscribed_track', 'staging');
      },
      seed: () => const ShorebirdPatchState(
        status: ShorebirdPatchValidationStatus.applied,
        usesStagingTrack: true,
      ),
      build: () => cubitFor(_FakeUpdater()),
      act: (cubit) => cubit.useStableTrack(),
      expect: () => const [
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.selectingStableTrack,
          usesStagingTrack: true,
        ),
        ShorebirdPatchState(
          status: ShorebirdPatchValidationStatus.stableRestored,
        ),
      ],
      verify: (_) {
        expect(preferences.getString('shorebird_subscribed_track'), 'stable');
      },
    );

    test(
      're-entrant checks are ignored while the first check is pending',
      () async {
        final completer = Completer<UpdateStatus>();
        final updater = _FakeUpdater(checkCompleter: completer);
        final cubit = cubitFor(updater);
        addTearDown(cubit.close);
        await cubit.load();

        final first = cubit.checkStagingTrack();
        await pumpEventQueue();
        var secondDone = false;
        final second = cubit.checkStagingTrack().whenComplete(() {
          secondDone = true;
        });
        await pumpEventQueue();
        // The repeat is ignored, so it returns while the first is still held.
        expect(secondDone, isTrue);
        expect(updater.checkCalls, 1);

        completer.complete(UpdateStatus.upToDate);
        await Future.wait([first, second]);
      },
    );
  });
}
