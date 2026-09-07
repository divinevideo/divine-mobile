import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/crosspost_settings/crosspost_settings_cubit.dart';
import 'package:openvine/models/atproto_provisioning_state.dart';
import 'package:openvine/repositories/bluesky_crosspost_repository.dart';
import 'package:openvine/services/crosspost_api_client.dart';

class _MockBlueskyCrosspostRepository extends Mock
    implements BlueskyCrosspostRepository {}

void main() {
  group(CrosspostSettingsCubit, () {
    late _MockBlueskyCrosspostRepository repository;

    const testPubkey = 'abc123def456';
    const loadedStatus = BlueskyCrosspostAccountStatus(
      crosspostEnabled: true,
      username: 'testuser',
      handle: 'testuser.divine.video',
      provisioningState: AtprotoProvisioningState.ready,
      did: 'did:plc:test123',
      usernameClaimStatus: UsernameClaimStatus.claimed,
    );

    CrosspostSettingsCubit buildCubit({
      Duration pollInterval = const Duration(seconds: 5),
      int maxProvisioningPollAttempts = 24,
    }) {
      return CrosspostSettingsCubit(
        repository: repository,
        pubkey: testPubkey,
        provisioningPollInterval: pollInterval,
        maxProvisioningPollAttempts: maxProvisioningPollAttempts,
      );
    }

    setUp(() {
      repository = _MockBlueskyCrosspostRepository();
      when(
        () => repository.loadStatus(pubkey: any(named: 'pubkey')),
      ).thenAnswer((_) async => loadedStatus);
    });

    group('initial state', () {
      test('starts loading status on creation', () {
        final cubit = buildCubit();
        expect(cubit.state.status, CrosspostSettingsStatus.loading);
        addTearDown(cubit.close);
      });
    });

    group('loadStatus', () {
      test('emits loaded state on successful status fetch', () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.enabled, isTrue);
        expect(cubit.state.handle, 'testuser.divine.video');
        expect(cubit.state.provisioningState, AtprotoProvisioningState.ready);
        expect(cubit.state.did, 'did:plc:test123');
        expect(cubit.state.usernameClaimStatus, UsernameClaimStatus.claimed);
      });

      test('emits failure state when status fetch fails', () async {
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => throw const BlueskyCrosspostStatusException(
            CrosspostApiException('Network error'),
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
          ),
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.failure);
        expect(cubit.state.usernameClaimStatus, UsernameClaimStatus.notClaimed);
      });

      test(
        'loads not-linked state while preserving claimed username',
        () async {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);

          await Future<void>.delayed(Duration.zero);

          expect(cubit.state.status, CrosspostSettingsStatus.loaded);
          expect(cubit.state.enabled, isFalse);
          expect(cubit.state.username, 'testuser');
          expect(
            cubit.state.provisioningState,
            AtprotoProvisioningState.notLinked,
          );
        },
      );

      test('loads notClaimed when no Divine username is claimed', () async {
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: false,
            provisioningState: AtprotoProvisioningState.notLinked,
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
          ),
        );

        final cubit = buildCubit();
        addTearDown(cubit.close);

        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.status, CrosspostSettingsStatus.loaded);
        expect(cubit.state.usernameClaimStatus, UsernameClaimStatus.notClaimed);
        expect(cubit.state.username, isNull);
      });
    });

    group('toggleCrosspost', () {
      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'emits loaded with enabled=false on successful toggle',
        setUp: () {
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.disabled,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: false);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.toggling,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.disabled,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        ],
        verify: (cubit) => expect(cubit.state.enabled, isFalse),
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'reverts to previous enabled value on toggle failure',
        setUp: () {
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException('Server error'),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: false);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.toggling,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
            error: CrosspostSettingsError.generic,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'short-circuits to usernameNotClaimed when enabling without username',
        setUp: () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.notClaimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
            error: CrosspostSettingsError.usernameNotClaimed,
            attempt: 1,
          ),
        ],
        verify: (_) {
          verifyNever(
            () => repository.setCrosspost(
              pubkey: any(named: 'pubkey'),
              enabled: any(named: 'enabled'),
            ),
          );
        },
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'does not short-circuit enable when claim status is unknown',
        setUp: () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.unknown,
            ),
          );
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.unknown,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            enabled: true,
            provisioningState: AtprotoProvisioningState.pending,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).called(1);
        },
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'does not short-circuit enable when keycast username is claimed',
        setUp: () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'keycastuser',
              handle: 'keycastuser.divine.video',
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'keycastuser',
              handle: 'keycastuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 1,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.toggling,
            enabled: true,
            username: 'keycastuser',
            handle: 'keycastuser.divine.video',
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            enabled: true,
            username: 'keycastuser',
            handle: 'keycastuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        ],
        verify: (_) {
          verify(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).called(1);
        },
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'maps a username precondition failure to usernameNotSynced when claimed',
        setUp: () {
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'not synced',
              statusCode: 400,
              kind: CrosspostApiErrorKind.usernameNotClaimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
            error: CrosspostSettingsError.usernameNotSynced,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'maps 503 toggle failure to unavailable',
        setUp: () {
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'unavailable',
              statusCode: 503,
              kind: CrosspostApiErrorKind.unavailable,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.failure,
            enabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
            usernameClaimStatus: UsernameClaimStatus.claimed,
            error: CrosspostSettingsError.unavailable,
            attempt: 1,
          ),
        ],
        errors: () => [isA<CrosspostApiException>()],
      );

      test('ignores toggle completion after close', () async {
        final completer = Completer<BlueskyCrosspostAccountStatus>();
        when(
          () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
        ).thenAnswer((_) => completer.future);

        final cubit = buildCubit();
        await Future<void>.delayed(Duration.zero);

        final errors = <Object>[];
        final subscription = cubit.stream.listen(null, onError: errors.add);
        unawaited(cubit.toggleCrosspost(enabled: false));
        await Future<void>.delayed(Duration.zero);
        await cubit.close();

        completer.complete(
          const BlueskyCrosspostAccountStatus(
            crosspostEnabled: false,
            provisioningState: AtprotoProvisioningState.disabled,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(errors, isEmpty);
        await subscription.cancel();
      });

      blocTest<CrosspostSettingsCubit, CrosspostSettingsState>(
        'acknowledgeError clears the error and returns to loaded',
        setUp: () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.notLinked,
              usernameClaimStatus: UsernameClaimStatus.notClaimed,
            ),
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await Future<void>.delayed(Duration.zero);
          await cubit.toggleCrosspost(enabled: true);
          cubit.acknowledgeError();
        },
        skip: 2,
        expect: () => const [
          CrosspostSettingsState(
            status: CrosspostSettingsStatus.loaded,
            usernameClaimStatus: UsernameClaimStatus.notClaimed,
            attempt: 1,
          ),
        ],
      );
    });

    group('copyWith', () {
      test('can clear nullable DID while preserving internal guards', () {
        const state = CrosspostSettingsState(
          did: 'did:plc:test123',
          operationGeneration: 7,
          provisioningPollAttempts: 2,
          provisioningPollingTimedOut: true,
        );

        final copied = state.copyWith(clearDid: true);

        expect(copied.did, isNull);
        expect(copied.operationGeneration, 7);
        expect(copied.provisioningPollAttempts, 2);
        expect(copied.provisioningPollingTimedOut, isTrue);
      });
    });

    group('operationGeneration invariant', () {
      test('documents operationGeneration exclusion from equality', () {
        // This private async epoch is intentionally excluded from props; see
        // CrosspostSettingsState.operationGeneration for the invariant that
        // keeps emitted generation bumps visible.
        expect(
          const CrosspostSettingsState(),
          const CrosspostSettingsState(operationGeneration: 1),
        );
      });

      test(
        'loadStatus generation bump emits with props-visible change',
        () async {
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await Future<void>.delayed(Duration.zero);

          final previousState = cubit.state;
          final emittedStates = <CrosspostSettingsState>[];
          final subscription = cubit.stream.listen(emittedStates.add);
          addTearDown(subscription.cancel);

          await cubit.loadStatus();

          expect(emittedStates, isNotEmpty);
          expect(emittedStates.first, isNot(equals(previousState)));
          expect(
            emittedStates.first.operationGeneration,
            previousState.operationGeneration + 1,
          );
        },
      );

      test(
        'toggleCrosspost generation bump emits with props-visible change',
        () async {
          final completer = Completer<BlueskyCrosspostAccountStatus>();
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
          ).thenAnswer((_) => completer.future);
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await Future<void>.delayed(Duration.zero);

          final previousState = cubit.state;
          final emittedStates = <CrosspostSettingsState>[];
          final subscription = cubit.stream.listen(emittedStates.add);
          addTearDown(subscription.cancel);

          unawaited(cubit.toggleCrosspost(enabled: false));
          await Future<void>.delayed(Duration.zero);

          expect(emittedStates, isNotEmpty);
          expect(emittedStates.first, isNot(equals(previousState)));
          expect(
            emittedStates.first.operationGeneration,
            previousState.operationGeneration + 1,
          );

          completer.complete(
            const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              provisioningState: AtprotoProvisioningState.disabled,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        },
      );
    });

    group('provisioning polling', () {
      test('polls pending status until a terminal state is loaded', () {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          if (loadCount == 1) {
            return const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            );
          }
          return const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          );
        });
        when(() => repository.loadKeycastStatus()).thenAnswer((_) async {
          loadCount += 1;
          return const CrosspostStatus(
            crosspostEnabled: true,
            username: 'testuser',
            provisioningState: AtprotoProvisioningState.ready,
            did: 'did:plc:test123',
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit(
            pollInterval: const Duration(milliseconds: 1),
          );
          fake.flushMicrotasks();
          fake.elapse(const Duration(milliseconds: 1));
          fake.flushMicrotasks();

          expect(loadCount, 2);
          expect(cubit.state.provisioningState, AtprotoProvisioningState.ready);
          final settledCount = loadCount;
          fake.elapse(const Duration(milliseconds: 10));
          fake.flushMicrotasks();
          expect(loadCount, settledCount);
          cubit.close();
        });
      });

      test('stops polling when the cubit closes', () {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          return const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          );
        });
        when(() => repository.loadKeycastStatus()).thenAnswer((_) async {
          loadCount += 1;
          return const CrosspostStatus(
            crosspostEnabled: true,
            provisioningState: AtprotoProvisioningState.pending,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit(
            pollInterval: const Duration(milliseconds: 1),
          );
          fake.flushMicrotasks();
          fake.elapse(const Duration(milliseconds: 5));
          fake.flushMicrotasks();
          expect(fake.pendingTimers, isNotEmpty);
          cubit.close();
          expect(fake.pendingTimers, isEmpty);

          final countAfterClose = loadCount;
          // One initial load plus at least one 1ms poll; without this pin a
          // cubit that never polled would pass on 1 == 1 (#8617).
          expect(countAfterClose, greaterThan(1));
          fake.elapse(const Duration(milliseconds: 5));
          fake.flushMicrotasks();
          expect(loadCount, countAfterClose);
        });
      });

      test(
        'poll failures keep the pending state without surfacing failure',
        () {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          when(() => repository.loadKeycastStatus()).thenAnswer(
            (_) async => throw const CrosspostApiException(
              'unavailable',
              statusCode: 503,
              kind: CrosspostApiErrorKind.unavailable,
            ),
          );

          fakeAsync((fake) {
            final cubit = buildCubit(
              pollInterval: const Duration(milliseconds: 1),
            );
            fake.flushMicrotasks();
            fake.elapse(const Duration(milliseconds: 3));
            fake.flushMicrotasks();

            expect(cubit.state.status, CrosspostSettingsStatus.loaded);
            expect(
              cubit.state.provisioningState,
              AtprotoProvisioningState.pending,
            );
            expect(cubit.state.error, isNull);
            expect(cubit.state.attempt, 0);
            cubit.close();
          });
        },
      );

      test('stops polling after the max failed poll attempts is reached', () {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          return const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          );
        });
        when(() => repository.loadKeycastStatus()).thenAnswer((_) async {
          loadCount += 1;
          throw const CrosspostApiException(
            'unavailable',
            statusCode: 503,
            kind: CrosspostApiErrorKind.unavailable,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit(
            pollInterval: const Duration(milliseconds: 1),
            maxProvisioningPollAttempts: 2,
          );
          fake.flushMicrotasks();

          expect(fake.pendingTimers, isNotEmpty);
          fake.elapse(const Duration(milliseconds: 2));
          fake.flushMicrotasks();

          expect(cubit.state.provisioningPollAttempts, 2);
          expect(cubit.state.provisioningPollingTimedOut, isTrue);
          // The quiet-failure cap owns its own cancel, separate from the
          // success-path cap in _syncProvisioningPoller.
          expect(fake.pendingTimers, isEmpty);
          expect(cubit.state.error, isNull);
          final cappedCount = loadCount;
          // One initial load plus the capped failing polls; without this pin a
          // cubit that never polled would pass on 1 == 1 (#8617).
          expect(cappedCount, greaterThan(1));

          fake.elapse(const Duration(milliseconds: 5));
          fake.flushMicrotasks();
          expect(loadCount, cappedCount);
          cubit.close();
        });
      });

      test('stale poll result does not overwrite toggle result', () async {
        final pollCompleter = Completer<CrosspostStatus>();
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );
        when(
          () => repository.loadKeycastStatus(),
        ).thenAnswer((_) => pollCompleter.future);
        when(
          () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
        ).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: false,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.disabled,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );

        final cubit = buildCubit(pollInterval: const Duration(milliseconds: 1));
        addTearDown(cubit.close);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(const Duration(milliseconds: 1));

        await cubit.toggleCrosspost(enabled: false);
        pollCompleter.complete(
          const CrosspostStatus(
            crosspostEnabled: true,
            provisioningState: AtprotoProvisioningState.pending,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.enabled, isFalse);
        expect(
          cubit.state.provisioningState,
          AtprotoProvisioningState.disabled,
        );
      });

      test('poll that fires during toggle does not start', () {
        late Completer<BlueskyCrosspostAccountStatus> toggleCompleter;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );
        when(
          () => repository.setCrosspost(pubkey: testPubkey, enabled: false),
        ).thenAnswer((_) => toggleCompleter.future);

        fakeAsync((fake) {
          toggleCompleter = Completer<BlueskyCrosspostAccountStatus>();
          final cubit = buildCubit(
            pollInterval: const Duration(milliseconds: 1),
          );
          fake.flushMicrotasks();

          unawaited(cubit.toggleCrosspost(enabled: false));
          fake.flushMicrotasks();
          expect(cubit.state.status, CrosspostSettingsStatus.toggling);

          fake.elapse(const Duration(milliseconds: 1));
          fake.flushMicrotasks();
          verifyNever(() => repository.loadKeycastStatus());

          toggleCompleter.complete(
            const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.disabled,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          fake.flushMicrotasks();
          fake.flushMicrotasks();

          expect(cubit.state.enabled, isFalse);
          expect(
            cubit.state.provisioningState,
            AtprotoProvisioningState.disabled,
          );
          cubit.close();
        });
      });

      test('stops polling after the max pending attempts is reached', () {
        var loadCount = 0;
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer((
          _,
        ) async {
          loadCount += 1;
          return const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          );
        });
        when(() => repository.loadKeycastStatus()).thenAnswer((_) async {
          loadCount += 1;
          return const CrosspostStatus(
            crosspostEnabled: true,
            provisioningState: AtprotoProvisioningState.pending,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit(
            pollInterval: const Duration(milliseconds: 1),
            maxProvisioningPollAttempts: 2,
          );
          fake.flushMicrotasks();

          expect(fake.pendingTimers, isNotEmpty);
          fake.elapse(const Duration(milliseconds: 2));
          fake.flushMicrotasks();

          expect(cubit.state.provisioningPollAttempts, 2);
          expect(cubit.state.provisioningPollingTimedOut, isTrue);
          expect(fake.pendingTimers, isEmpty);
          final cappedCount = loadCount;

          fake.elapse(const Duration(milliseconds: 5));
          fake.flushMicrotasks();
          expect(loadCount, cappedCount);
          cubit.close();
        });
      });

      test(
        'retryProvisioning re-enables crossposting from failed state',
        () async {
          when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: false,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.failed,
              provisioningError: 'PDS quota exhausted',
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );
          when(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).thenAnswer(
            (_) async => const BlueskyCrosspostAccountStatus(
              crosspostEnabled: true,
              username: 'testuser',
              handle: 'testuser.divine.video',
              provisioningState: AtprotoProvisioningState.pending,
              usernameClaimStatus: UsernameClaimStatus.claimed,
            ),
          );

          final cubit = buildCubit();
          addTearDown(cubit.close);
          await Future<void>.delayed(Duration.zero);

          await cubit.retryProvisioning();

          verify(
            () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
          ).called(1);
          expect(cubit.state.enabled, isTrue);
          expect(
            cubit.state.provisioningState,
            AtprotoProvisioningState.pending,
          );
        },
      );

      test('retryProvisioning ignores repeated taps while toggling', () async {
        final completer = Completer<BlueskyCrosspostAccountStatus>();
        when(() => repository.loadStatus(pubkey: testPubkey)).thenAnswer(
          (_) async => const BlueskyCrosspostAccountStatus(
            crosspostEnabled: false,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.failed,
            provisioningError: 'PDS quota exhausted',
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );
        when(
          () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
        ).thenAnswer((_) => completer.future);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        await Future<void>.delayed(Duration.zero);

        unawaited(cubit.retryProvisioning());
        unawaited(cubit.retryProvisioning());
        await Future<void>.delayed(Duration.zero);

        verify(
          () => repository.setCrosspost(pubkey: testPubkey, enabled: true),
        ).called(1);

        completer.complete(
          const BlueskyCrosspostAccountStatus(
            crosspostEnabled: true,
            username: 'testuser',
            handle: 'testuser.divine.video',
            provisioningState: AtprotoProvisioningState.pending,
            usernameClaimStatus: UsernameClaimStatus.claimed,
          ),
        );
        await Future<void>.delayed(Duration.zero);
      });
    });
  });
}
