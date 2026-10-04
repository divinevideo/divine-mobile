import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/repositories/shorebird_patch_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({
    this.current,
    this.status = UpdateStatus.upToDate,
    this.onUpdate,
    this.checkCompleter,
  });

  @override
  final bool isAvailable = true;
  Patch? current;
  Patch? next;
  UpdateStatus status;
  void Function()? onUpdate;
  final Completer<UpdateStatus>? checkCompleter;
  UpdateTrack? checkedTrack;
  UpdateTrack? updatedTrack;
  int updateCalls = 0;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async {
    checkedTrack = track;
    return checkCompleter?.future ?? status;
  }

  @override
  Future<Patch?> readCurrentPatch() async => current;

  @override
  Future<Patch?> readNextPatch() async => next ?? current;

  @override
  Future<void> update({UpdateTrack? track}) async {
    updateCalls++;
    updatedTrack = track;
    onUpdate?.call();
  }
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  tearDown(ShorebirdPatchRepository.resetOperationQueueForTesting);

  group('updateSubscribedTrackAtStartup', () {
    test(
      'startup defaults to stable and downloads an outdated patch',
      () async {
        final updater = _FakeUpdater(status: UpdateStatus.outdated);
        final repository = ShorebirdPatchRepository(
          updater: updater,
          preferences: preferences,
        );

        await repository.updateSubscribedTrackAtStartup();

        expect(updater.checkedTrack, UpdateTrack.stable);
        expect(updater.updatedTrack, UpdateTrack.stable);
      },
    );

    test('startup keeps a validation device subscribed to staging', () async {
      await preferences.setString('shorebird_subscribed_track', 'staging');
      final updater = _FakeUpdater(status: UpdateStatus.outdated);
      final repository = ShorebirdPatchRepository(
        updater: updater,
        preferences: preferences,
      );

      await repository.updateSubscribedTrackAtStartup();

      expect(updater.checkedTrack, UpdateTrack.staging);
      expect(updater.updatedTrack, UpdateTrack.staging);
    });

    test(
      'startup does not call update when the selected track is current',
      () async {
        final updater = _FakeUpdater();
        final repository = ShorebirdPatchRepository(
          updater: updater,
          preferences: preferences,
        );

        await repository.updateSubscribedTrackAtStartup();

        expect(updater.updatedTrack, isNull);
      },
    );
  });

  group('applyStagingPatch', () {
    test(
      'apply does not claim success or switch tracks when nothing moves',
      () async {
        final updater = _FakeUpdater(current: const Patch(number: 3));
        final repository = ShorebirdPatchRepository(
          updater: updater,
          preferences: preferences,
        );

        final result = await repository.applyStagingPatch();

        expect(result, ShorebirdPatchApplyResult.unchanged);
        expect(repository.subscribedTrack, ShorebirdSubscribedTrack.stable);
      },
    );

    test(
      'apply does not claim an already-pending patch as newly downloaded',
      () async {
        final updater = _FakeUpdater(current: const Patch(number: 3))
          ..next = const Patch(number: 4);
        final repository = ShorebirdPatchRepository(
          updater: updater,
          preferences: preferences,
        );

        final result = await repository.applyStagingPatch();

        expect(result, ShorebirdPatchApplyResult.unchanged);
        expect(repository.subscribedTrack, ShorebirdSubscribedTrack.stable);
      },
    );

    test(
      'apply persists staging only after a new next patch appears',
      () async {
        final updater = _FakeUpdater(
          current: const Patch(number: 3),
          onUpdate: () {},
        );
        updater.onUpdate = () => updater.next = const Patch(number: 4);
        final repository = ShorebirdPatchRepository(
          updater: updater,
          preferences: preferences,
        );

        final result = await repository.applyStagingPatch();

        expect(result, ShorebirdPatchApplyResult.installed);
        expect(repository.subscribedTrack, ShorebirdSubscribedTrack.staging);
      },
    );
  });

  group('useStableTrack', () {
    test('useStableTrack restores the production subscription', () async {
      await preferences.setString('shorebird_subscribed_track', 'staging');
      final repository = ShorebirdPatchRepository(
        updater: _FakeUpdater(),
        preferences: preferences,
      );

      await repository.useStableTrack();

      expect(repository.subscribedTrack, ShorebirdSubscribedTrack.stable);
    });
  });

  group('operation serialization', () {
    test('startup and Developer Options updates cannot race', () async {
      final stableCheck = Completer<UpdateStatus>();
      final startupUpdater = _FakeUpdater(checkCompleter: stableCheck);
      final stagingUpdater = _FakeUpdater(current: const Patch(number: 3));
      stagingUpdater.onUpdate = () =>
          stagingUpdater.next = const Patch(number: 4);
      final startupRepository = ShorebirdPatchRepository(
        updater: startupUpdater,
        preferences: preferences,
      );
      final stagingRepository = ShorebirdPatchRepository(
        updater: stagingUpdater,
        preferences: preferences,
      );

      final startup = startupRepository.updateSubscribedTrackAtStartup();
      await pumpEventQueue();
      final staging = stagingRepository.applyStagingPatch();
      await pumpEventQueue();

      expect(stagingUpdater.updateCalls, 0);
      stableCheck.complete(UpdateStatus.upToDate);
      await startup;
      expect(await staging, ShorebirdPatchApplyResult.installed);
      expect(stagingUpdater.updateCalls, 1);
    });

    test('test reset releases later operations from a pending fake', () async {
      final pendingCheck = Completer<UpdateStatus>();
      final pendingRepository = ShorebirdPatchRepository(
        updater: _FakeUpdater(checkCompleter: pendingCheck),
        preferences: preferences,
      );

      final pendingOperation = pendingRepository
          .updateSubscribedTrackAtStartup();
      await pumpEventQueue();

      ShorebirdPatchRepository.resetOperationQueueForTesting();

      final laterRepository = ShorebirdPatchRepository(
        updater: _FakeUpdater(current: const Patch(number: 7)),
        preferences: preferences,
      );
      final snapshot = await laterRepository.readSnapshot().timeout(
        const Duration(seconds: 1),
      );

      expect(snapshot.current?.number, 7);
      pendingCheck.complete(UpdateStatus.upToDate);
      await pendingOperation;
    });
  });
}
