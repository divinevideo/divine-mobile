// ABOUTME: Tests ProfileSaveRetryService (#3161) — the background re-drive of
// ABOUTME: the durable pending profile-save slot: sweep outcomes, backoff,
// ABOUTME: re-entrancy, triggers, and manual retry.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/profile_save_retry_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const pubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

  late _MockProfileRepository repository;
  late AppDatabase db;
  late PendingProfileSavesDao dao;
  late StreamController<bool> foreground;
  late StreamController<void> retryTrigger;
  late DateTime clock;

  const config = ProfileSaveRetryConfig(maxRetries: 3);

  // Track every built service so tearDown can dispose it — a sweep that hits a
  // retryable failure arms a real retry Timer, which must be cancelled before
  // the DB/streams close or a late fire would sweep a torn-down fixture.
  final built = <ProfileSaveRetryService>[];

  ProfileSaveRetryService buildService() {
    final service = ProfileSaveRetryService(
      crashReporting: CrashReportingService(),
      profileRepository: repository,
      pendingProfileSavesDao: dao,
      userPubkey: pubkey,
      appForegroundStream: foreground.stream,
      retryTriggerStream: retryTrigger.stream,
      retryConfig: config,
      now: () => clock,
    );
    built.add(service);
    return service;
  }

  // Returns the minted generation so interleaving tests can assert which
  // enqueue was driven.
  Future<String> seed({
    PendingProfileSaveStatus status = PendingProfileSaveStatus.pending,
    int retryCount = 0,
    DateTime? lastAttemptAt,
  }) {
    return dao.upsert(
      PendingProfileSaveEntry(
        userPubkey: pubkey,
        payloadJson: const PendingProfileSave(
          pubkey: pubkey,
          displayName: 'Alice',
        ).encode(),
        status: status,
        retryCount: retryCount,
        lastAttemptAt: lastAttemptAt,
        queuedAt: DateTime.utc(2026, 7, 13),
      ),
    );
  }

  setUp(() {
    repository = _MockProfileRepository();
    db = AppDatabase.test(NativeDatabase.memory());
    dao = db.pendingProfileSavesDao;
    foreground = StreamController<bool>.broadcast();
    retryTrigger = StreamController<void>.broadcast();
    clock = DateTime.utc(2026, 7, 13, 12);

    when(
      () => repository.resetInterruptedPendingSave(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() async {
    for (final service in built) {
      await service.dispose();
    }
    built.clear();
    await foreground.close();
    await retryTrigger.close();
    await db.close();
  });

  group('sweep outcomes', () {
    test('confirmed leaves the slot cleared (by the repository)', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async {
        await dao.clear(pubkey); // simulate the repo clearing on confirm
        return PendingSaveDriveOutcome.confirmed;
      });

      await buildService().sweep();

      expect(await dao.get(pubkey), isNull);
    });

    test(
      'retryableFailure below cap increments retry and stays pending',
      () async {
        await seed();
        when(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);

        await buildService().sweep();

        final entry = await dao.get(pubkey);
        expect(entry!.status, PendingProfileSaveStatus.pending);
        expect(entry.retryCount, 1);
      },
    );

    test('retryableFailure at the cap marks the slot failed', () async {
      // maxRetries=3, retryCount=2 → this attempt is the 3rd → exhausted.
      await seed(retryCount: 2);
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);

      await buildService().sweep();

      final entry = await dao.get(pubkey);
      expect(entry!.status, PendingProfileSaveStatus.failed);
      expect(entry.lastError, contains('Could not publish'));
    });

    test('permanentFailure marks the slot failed', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.permanentFailure);

      await buildService().sweep();

      expect((await dao.get(pubkey))!.status, PendingProfileSaveStatus.failed);
    });
  });

  group('sweep guards', () {
    test('does nothing when the slot is empty', () async {
      await buildService().sweep();
      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
    });

    test('skips a failed slot (awaits manual retry)', () async {
      await seed(status: PendingProfileSaveStatus.failed);
      await buildService().sweep();
      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
    });

    test('skips while inside the backoff window', () async {
      // retryCount=1 → backoff = initialDelay*2 = 4s. lastAttempt 1s ago.
      await seed(
        retryCount: 1,
        lastAttemptAt: clock.subtract(const Duration(seconds: 1)),
      );
      await buildService().sweep();
      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
    });

    test('drives once the backoff window has elapsed', () async {
      await seed(
        retryCount: 1,
        lastAttemptAt: clock.subtract(const Duration(seconds: 10)),
      );
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.confirmed);

      await buildService().sweep();

      verify(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).called(1);
    });

    test('a re-entrant trigger is coalesced, not run concurrently', () async {
      await seed();
      final gate = Completer<void>();
      var driveCalls = 0;
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async {
        driveCalls++;
        await gate.future;
        return PendingSaveDriveOutcome.retryableFailure;
      });

      final service = buildService();
      final first = service.sweep();
      final second = service.sweep(); // coalesced into a follow-up pass
      gate.complete();
      await Future.wait([first, second]);

      // The coalesced follow-up pass runs after the first, but the row is now
      // inside its post-attempt backoff window, so it schedules rather than
      // driving again — no concurrent or redundant second drive.
      expect(driveCalls, 1);
    });
  });

  group('triggers', () {
    test('a foreground=true transition triggers a sweep', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.confirmed);

      final service = buildService();
      await service.initialize();
      clearInteractions(repository);

      foreground.add(true);
      await pumpEventQueue();

      verify(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).called(1);
    });

    test('a retry-trigger event triggers a sweep', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.confirmed);

      final service = buildService();
      await service.initialize();
      clearInteractions(repository);

      retryTrigger.add(null);
      await pumpEventQueue();

      verify(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).called(1);
    });

    test('foreground=false does not trigger a sweep', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);

      final service = buildService();
      await service.initialize();
      clearInteractions(repository);

      foreground.add(false);
      await pumpEventQueue();

      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
    });
  });

  group('lifecycle', () {
    test('initialize resets an interrupted slot and is idempotent', () async {
      final service = buildService();
      await service.initialize();
      await service.initialize();

      verify(() => repository.resetInterruptedPendingSave(pubkey)).called(1);
      expect(service.isInitialized, isTrue);
    });

    test('dispose cancels triggers so later events do not sweep', () async {
      await seed();
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async => PendingSaveDriveOutcome.retryableFailure);

      final service = buildService();
      await service.initialize();
      await service.dispose();
      clearInteractions(repository);

      foreground.add(true);
      retryTrigger.add(null);
      await pumpEventQueue();

      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
      expect(service.isInitialized, isFalse);
    });

    test(
      'disposing during a retryable drive does not retry, mutate the row, '
      'or arm a timer',
      () async {
        await seed();
        final fake = FakeAsync();
        late Completer<void> driveStarted;
        late Completer<void> releaseDrive;
        fake.run((_) {
          driveStarted = Completer<void>();
          releaseDrive = Completer<void>();
        });
        var driveCalls = 0;
        when(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((_) async {
          driveCalls++;
          if (!driveStarted.isCompleted) driveStarted.complete();
          await releaseDrive.future;
          return PendingSaveDriveOutcome.retryableFailure;
        });

        // Capture retry timers in virtual time while keeping database I/O real.
        final service = ProfileSaveRetryService(
          crashReporting: CrashReportingService(),
          profileRepository: repository,
          pendingProfileSavesDao: dao,
          userPubkey: pubkey,
          appForegroundStream: foreground.stream,
          retryTriggerStream: retryTrigger.stream,
          retryConfig: const ProfileSaveRetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 5),
            maxDelay: Duration(milliseconds: 40),
          ),
        );

        var sweepDone = false;
        fake.run(
          (_) => unawaited(service.sweep().then((_) => sweepDone = true)),
        );
        while (!driveStarted.isCompleted) {
          fake.flushMicrotasks();
          await pumpEventQueue();
        }
        await service.dispose(); // teardown mid-drive
        releaseDrive.complete(); // the drive returns a retryable failure
        while (!sweepDone) {
          fake.flushMicrotasks();
          await pumpEventQueue();
        }

        expect(driveCalls, 1, reason: 'no second drive after dispose');
        final entry = await dao.get(pubkey);
        expect(
          entry!.retryCount,
          0,
          reason: 'incrementRetry never ran past disposal',
        );

        // Advance any wrongly armed retry after the drive has returned.
        fake.elapse(const Duration(milliseconds: 30));
        await pumpEventQueue();
        fake.flushMicrotasks();
        expect(driveCalls, 1, reason: 'no timer-driven retry after dispose');
      },
    );
  });

  group('retryNow', () {
    test('resets a failed slot to a fresh retry and re-drives', () async {
      await seed(status: PendingProfileSaveStatus.failed, retryCount: 3);
      when(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).thenAnswer((_) async {
        await dao.clear(pubkey);
        return PendingSaveDriveOutcome.confirmed;
      });

      await buildService().retryNow();

      verify(
        () => repository.drivePendingSave(
          pubkey,
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      ).called(1);
      expect(await dao.get(pubkey), isNull);
    });

    test('is a no-op when there is no slot', () async {
      await buildService().retryNow();
      verifyNever(
        () => repository.drivePendingSave(
          any(),
          expectedGeneration: any(named: 'expectedGeneration'),
        ),
      );
    });
  });

  group('self-scheduled retry (relay-recovery)', () {
    test(
      'one recovery signal eventually publishes via the armed retry timer '
      '(no second signal needed)',
      () async {
        await seed();

        // First attempt fails (relay pool not reconnected yet), the retry the
        // armed timer schedules confirms — with no further external signal.
        var calls = 0;
        final firstDrive = Completer<void>();
        final retryCleared = Completer<void>();
        when(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            firstDrive.complete();
            return PendingSaveDriveOutcome.retryableFailure;
          }
          await dao.clear(pubkey);
          retryCleared.complete();
          return PendingSaveDriveOutcome.confirmed;
        });

        // Real clock + tiny backoff so the armed timer fires quickly. (The
        // shared buildService injects a frozen clock, which would desync from
        // the DAO's real-time attempt stamps and defeat the backoff gate.)
        final service = ProfileSaveRetryService(
          crashReporting: CrashReportingService(),
          profileRepository: repository,
          pendingProfileSavesDao: dao,
          userPubkey: pubkey,
          appForegroundStream: foreground.stream,
          retryTriggerStream: retryTrigger.stream,
          retryConfig: const ProfileSaveRetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 5),
            maxDelay: Duration(milliseconds: 40),
          ),
        );
        addTearDown(service.dispose);
        await service.initialize();
        clearInteractions(repository);

        // A single offline→online recovery signal.
        retryTrigger.add(null);
        await firstDrive.future;
        expect(calls, 1, reason: 'the signal drives the first attempt');

        // No second signal — the armed timer must drive the retry that lands.
        await retryCleared.future;
        expect(
          calls,
          greaterThanOrEqualTo(2),
          reason: 'the armed timer drove a second attempt on its own',
        );
        expect(
          await dao.get(pubkey),
          isNull,
          reason: 'the confirmed retry cleared the slot',
        );
      },
    );
  });

  group('level-triggered chaining (interleaved saves)', () {
    test(
      'a newer save that replaces an in-flight older one is driven to '
      'completion without a second trigger',
      () async {
        final gA = await seed();
        final aDriveStarted = Completer<void>();
        final releaseA = Completer<void>();
        String? gB;

        when(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((invocation) async {
          final gen = invocation.namedArguments[#expectedGeneration] as String?;
          if (gen == gA) {
            if (!aDriveStarted.isCompleted) aDriveStarted.complete();
            await releaseA.future;
            // The real repo returns noPendingSave once a newer generation has
            // replaced the row this drive was scoped to.
            return PendingSaveDriveOutcome.noPendingSave;
          }
          // Driving B: confirm and clear, as the repo does on a relay OK.
          await dao.clear(pubkey, generation: gB);
          return PendingSaveDriveOutcome.confirmed;
        });

        final service = buildService();
        // The only trigger — drives A. B is never manually driven and no
        // foreground/connectivity signal is emitted.
        final sweepFuture = service.sweep();
        await aDriveStarted.future;

        // B replaces A while A's publish is parked mid-flight.
        gB = await seed();

        releaseA.complete();
        await sweepFuture; // the coalesced loop chains to B and drives it

        verify(
          () => repository.drivePendingSave(pubkey, expectedGeneration: gA),
        ).called(1);
        verify(
          () => repository.drivePendingSave(pubkey, expectedGeneration: gB),
        ).called(1);
        expect(
          await dao.get(pubkey),
          isNull,
          reason: 'B was driven and its confirmed publish cleared the slot',
        );
      },
    );
  });

  group('enqueue wake (idle service)', () {
    test(
      'a fresh enqueue re-drives an idle service with no foreground or '
      'connectivity signal',
      () async {
        final slotCleared = Completer<void>();
        when(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).thenAnswer((_) async {
          await dao.clear(pubkey);
          slotCleared.complete();
          return PendingSaveDriveOutcome.confirmed;
        });

        // Real clock + tiny backstop delay so the enqueue-armed sweep fires
        // quickly.
        final service = ProfileSaveRetryService(
          crashReporting: CrashReportingService(),
          profileRepository: repository,
          pendingProfileSavesDao: dao,
          userPubkey: pubkey,
          appForegroundStream: foreground.stream,
          retryTriggerStream: retryTrigger.stream,
          retryConfig: const ProfileSaveRetryConfig(
            maxRetries: 3,
            initialDelay: Duration(milliseconds: 5),
            maxDelay: Duration(milliseconds: 40),
          ),
        );
        addTearDown(service.dispose);
        await service.initialize();
        clearInteractions(repository);

        // No foreground / connectivity event — just enqueue a save.
        await seed();

        await slotCleared.future;

        verify(
          () => repository.drivePendingSave(
            pubkey,
            expectedGeneration: any(named: 'expectedGeneration'),
          ),
        ).called(1);
        expect(
          await dao.get(pubkey),
          isNull,
          reason: 'the enqueue-armed sweep drove and cleared the slot',
        );
      },
    );
  });
}
