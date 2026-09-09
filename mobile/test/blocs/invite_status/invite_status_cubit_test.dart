// ABOUTME: Unit tests for InviteStatusCubit

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/repositories/invite_availability_repository.dart';

class _MockInviteApiClient extends Mock implements InviteApiClient {}

void main() {
  group(InviteStatusCubit, () {
    late _MockInviteApiClient mockInviteApiClient;

    const testAccountId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testStatus = InviteStatus(
      canInvite: true,
      remaining: 3,
      total: 5,
      codes: [
        InviteCode(code: 'AB23-EF7K', claimed: false),
        InviteCode(
          code: 'HN4P-QR56',
          claimed: true,
          claimedBy: 'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
        ),
      ],
    );

    setUp(() {
      mockInviteApiClient = _MockInviteApiClient();
    });

    InviteStatusCubit buildCubit({
      InviteStatusAuthSession initialAuthSession =
          const InviteStatusAuthSession(
            accountId: testAccountId,
            isSignerReady: true,
          ),
      Stream<InviteStatusAuthSession> authSessionStream =
          const Stream<InviteStatusAuthSession>.empty(),
      InviteAvailabilityRepository? availabilityRepository,
      Duration authWaitTimeout = const Duration(seconds: 12),
    }) => InviteStatusCubit(
      inviteApiClient: mockInviteApiClient,
      initialAuthSession: initialAuthSession,
      authSessionStream: authSessionStream,
      availabilityRepository: availabilityRepository,
      authWaitTimeout: authWaitTimeout,
    );

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(InviteStatusLoadingStatus.initial));
      expect(cubit.state.inviteStatus, isNull);
      expect(cubit.state.hasUnclaimedCodes, isFalse);
      expect(cubit.state.unclaimedCount, equals(0));
      expect(cubit.state.hasAvailableInvites, isFalse);
      expect(cubit.state.availableInviteCount, equals(0));
      expect(cubit.state.accountId, equals(testAccountId));
      expect(cubit.state.isSignerReady, isTrue);
    });

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then loaded with invite status',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits loading then error on failure',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenThrow(Exception('network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.error,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load does not re-fetch if already loading',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.loading,
        accountId: testAccountId,
        isSignerReady: true,
      ),
      act: (cubit) => cubit.load(),
      expect: () => <InviteStatusState>[],
      verify: (_) {
        verifyNever(() => mockInviteApiClient.getInviteStatus());
      },
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load does not fetch when invite auth is not ready',
      build: () => buildCubit(
        initialAuthSession: const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: false,
        ),
      ),
      act: (cubit) => cubit.load(),
      expect: () => <InviteStatusState>[],
      verify: (_) {
        verifyNever(() => mockInviteApiClient.getInviteStatus());
      },
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load after error re-fetches successfully',
      setUp: () {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.error,
        accountId: testAccountId,
        isSignerReady: true,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load exposes an expected 401 auth gap as an error',
      setUp: () {
        when(() => mockInviteApiClient.getInviteStatus()).thenThrow(
          const InviteApiException(
            'Authorization header required',
            statusCode: 401,
            code: InviteApiErrorCode.authRequired,
          ),
        );
      },
      build: buildCubit,
      seed: () => const InviteStatusState(
        status: InviteStatusLoadingStatus.loaded,
        inviteStatus: testStatus,
        accountId: testAccountId,
        isSignerReady: true,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          inviteStatus: testStatus,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.error,
          inviteStatus: testStatus,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
      errors: () => <Object>[],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'load emits error on non-401 invite api failure',
      setUp: () {
        when(() => mockInviteApiClient.getInviteStatus()).thenThrow(
          const InviteApiException(
            'Invite service unavailable',
            statusCode: 500,
            code: InviteApiErrorCode.internalError,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.error,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
      errors: () => [isA<InviteApiException>()],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'generateInvite creates one code then reloads invite status',
      setUp: () {
        when(() => mockInviteApiClient.generateInvite()).thenAnswer(
          (_) async =>
              const GenerateInviteResult(code: 'WX56-3MKT', remaining: 4),
        );
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);
      },
      build: buildCubit,
      act: (cubit) => cubit.generateInvite(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: testStatus,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
      verify: (_) {
        verify(() => mockInviteApiClient.generateInvite()).called(1);
        verify(() => mockInviteApiClient.getInviteStatus()).called(1);
      },
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'generateInvite emits error on non-401 invite api failure',
      setUp: () {
        when(() => mockInviteApiClient.generateInvite()).thenThrow(
          const InviteApiException(
            'Invite service unavailable',
            statusCode: 500,
            code: InviteApiErrorCode.internalError,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.generateInvite(),
      expect: () => [
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loading,
          accountId: testAccountId,
          isSignerReady: true,
        ),
        const InviteStatusState(
          status: InviteStatusLoadingStatus.error,
          accountId: testAccountId,
          isSignerReady: true,
        ),
      ],
      errors: () => [isA<InviteApiException>()],
    );

    test(
      'load does not emit after close when request completes late',
      () async {
        final completer = Completer<InviteStatus>();
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) => completer.future);

        final cubit = buildCubit();
        final emittedStates = <InviteStatusState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        unawaited(cubit.load());
        await Future<void>.delayed(Duration.zero);

        expect(
          emittedStates,
          equals([
            const InviteStatusState(
              status: InviteStatusLoadingStatus.loading,
              accountId: testAccountId,
              isSignerReady: true,
            ),
          ]),
        );

        await cubit.close();
        completer.complete(testStatus);
        await Future<void>.delayed(Duration.zero);

        expect(
          emittedStates,
          equals([
            const InviteStatusState(
              status: InviteStatusLoadingStatus.loading,
              accountId: testAccountId,
              isSignerReady: true,
            ),
          ]),
        );

        await subscription.cancel();
      },
    );

    test(
      'Keycast status loads when delayed RPC signer becomes ready',
      () async {
        final authSessions = StreamController<InviteStatusAuthSession>();
        addTearDown(authSessions.close);
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);

        final cubit = buildCubit(
          initialAuthSession: const InviteStatusAuthSession(
            accountId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            isSignerReady: false,
          ),
          authSessionStream: authSessions.stream,
        )..start();
        addTearDown(cubit.close);

        verifyNever(() => mockInviteApiClient.getInviteStatus());

        authSessions.add(
          const InviteStatusAuthSession(
            accountId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            isSignerReady: true,
          ),
        );
        await cubit.stream.firstWhere(
          (state) => state.status == InviteStatusLoadingStatus.loaded,
        );

        verify(() => mockInviteApiClient.getInviteStatus()).called(1);
        expect(cubit.state.inviteStatus, equals(testStatus));
      },
    );

    test('waiting for auth falls through to error after timeout', () {
      fakeAsync((async) {
        final cubit = buildCubit(
          initialAuthSession: const InviteStatusAuthSession(
            accountId: testAccountId,
            isSignerReady: false,
          ),
          authWaitTimeout: const Duration(seconds: 1),
        );
        final emittedStates = <InviteStatusState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        expect(cubit.state.status, InviteStatusLoadingStatus.waitingForAuth);

        async.elapse(const Duration(seconds: 1));

        expect(
          emittedStates,
          equals([
            const InviteStatusState(
              status: InviteStatusLoadingStatus.error,
              accountId: testAccountId,
            ),
          ]),
        );
        verifyNever(() => mockInviteApiClient.getInviteStatus());

        unawaited(subscription.cancel());
        unawaited(cubit.close());
      });
    });

    test('retry restarts bounded auth wait while signer is unavailable', () {
      fakeAsync((async) {
        final cubit = buildCubit(
          initialAuthSession: const InviteStatusAuthSession(
            accountId: testAccountId,
            isSignerReady: false,
          ),
          authWaitTimeout: const Duration(seconds: 1),
        );
        final emittedStates = <InviteStatusState>[];
        final subscription = cubit.stream.listen(emittedStates.add);

        async.elapse(const Duration(seconds: 1));
        unawaited(cubit.load());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 1));

        expect(
          emittedStates,
          equals([
            const InviteStatusState(
              status: InviteStatusLoadingStatus.error,
              accountId: testAccountId,
            ),
            const InviteStatusState(
              status: InviteStatusLoadingStatus.waitingForAuth,
              accountId: testAccountId,
            ),
            const InviteStatusState(
              status: InviteStatusLoadingStatus.error,
              accountId: testAccountId,
            ),
          ]),
        );
        verifyNever(() => mockInviteApiClient.getInviteStatus());

        unawaited(subscription.cancel());
        unawaited(cubit.close());
      });
    });

    test('signer readiness after auth timeout still loads status', () async {
      final authSessions = StreamController<InviteStatusAuthSession>();
      addTearDown(authSessions.close);
      when(
        () => mockInviteApiClient.getInviteStatus(),
      ).thenAnswer((_) async => testStatus);

      final cubit = buildCubit(
        initialAuthSession: const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: false,
        ),
        authSessionStream: authSessions.stream,
        authWaitTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(cubit.close);

      await cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.error,
      );

      authSessions.add(
        const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: true,
        ),
      );
      await cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.loaded,
      );

      verify(() => mockInviteApiClient.getInviteStatus()).called(1);
      expect(cubit.state.inviteStatus, testStatus);
    });

    test(
      'imported nsec loads status immediately when signer is ready',
      () async {
        when(
          () => mockInviteApiClient.getInviteStatus(),
        ).thenAnswer((_) async => testStatus);

        final cubit = buildCubit()..start();
        addTearDown(cubit.close);

        await cubit.stream.firstWhere(
          (state) => state.status == InviteStatusLoadingStatus.loaded,
        );

        verify(() => mockInviteApiClient.getInviteStatus()).called(1);
      },
    );

    test(
      'account switch ignores a late response from the previous account',
      () async {
        final authSessions = StreamController<InviteStatusAuthSession>();
        final accountAResponse = Completer<InviteStatus>();
        const accountBStatus = InviteStatus(
          canInvite: true,
          remaining: 5,
          total: 5,
          codes: [],
        );
        var requestCount = 0;
        when(() => mockInviteApiClient.getInviteStatus()).thenAnswer((_) {
          requestCount++;
          return requestCount == 1
              ? accountAResponse.future
              : Future<InviteStatus>.value(accountBStatus);
        });

        final cubit = buildCubit(authSessionStream: authSessions.stream)
          ..start();
        addTearDown(() async {
          await authSessions.close();
          await cubit.close();
        });
        await Future<void>.delayed(Duration.zero);

        authSessions.add(
          const InviteStatusAuthSession(
            accountId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            isSignerReady: true,
          ),
        );
        await cubit.stream.firstWhere(
          (state) =>
              state.accountId ==
                  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb' &&
              state.status == InviteStatusLoadingStatus.loaded,
        );

        accountAResponse.complete(testStatus);
        await Future<void>.delayed(Duration.zero);

        expect(
          cubit.state.accountId,
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );
        expect(cubit.state.inviteStatus, equals(accountBStatus));
        verify(() => mockInviteApiClient.getInviteStatus()).called(2);
      },
    );

    test('account switch clears the previous allocation immediately', () async {
      final authSessions = StreamController<InviteStatusAuthSession>();
      final accountBResponse = Completer<InviteStatus>();
      var requestCount = 0;
      when(() => mockInviteApiClient.getInviteStatus()).thenAnswer((_) {
        requestCount++;
        return requestCount == 1
            ? Future<InviteStatus>.value(testStatus)
            : accountBResponse.future;
      });

      final cubit = buildCubit(authSessionStream: authSessions.stream)..start();
      addTearDown(() async {
        await authSessions.close();
        await cubit.close();
      });
      await cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.loaded,
      );

      final switchedState = cubit.stream.firstWhere(
        (state) =>
            state.accountId ==
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      );
      authSessions.add(
        const InviteStatusAuthSession(
          accountId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          isSignerReady: true,
        ),
      );

      expect((await switchedState).inviteStatus, isNull);
      expect(cubit.state.inviteStatus, isNull);

      accountBResponse.complete(
        const InviteStatus(canInvite: false, remaining: 0, total: 0, codes: []),
      );
      await cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.loaded,
      );
    });

    test('A-B-A session churn rejects the first A response', () async {
      final authSessions = StreamController<InviteStatusAuthSession>();
      final firstAccountAResponse = Completer<InviteStatus>();
      const accountBStatus = InviteStatus(
        canInvite: true,
        remaining: 2,
        total: 2,
        codes: [],
      );
      const currentAccountAStatus = InviteStatus(
        canInvite: true,
        remaining: 1,
        total: 1,
        codes: [],
      );
      var requestCount = 0;
      when(() => mockInviteApiClient.getInviteStatus()).thenAnswer((_) {
        requestCount++;
        return switch (requestCount) {
          1 => firstAccountAResponse.future,
          2 => Future<InviteStatus>.value(accountBStatus),
          _ => Future<InviteStatus>.value(currentAccountAStatus),
        };
      });

      final cubit = buildCubit(authSessionStream: authSessions.stream)..start();
      addTearDown(() async {
        await authSessions.close();
        await cubit.close();
      });
      await Future<void>.delayed(Duration.zero);

      authSessions.add(
        const InviteStatusAuthSession(
          accountId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          isSignerReady: true,
        ),
      );
      await cubit.stream.firstWhere(
        (state) => state.inviteStatus == accountBStatus,
      );

      authSessions.add(
        const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: true,
        ),
      );
      await cubit.stream.firstWhere(
        (state) => state.inviteStatus == currentAccountAStatus,
      );

      firstAccountAResponse.complete(testStatus);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.accountId, testAccountId);
      expect(cubit.state.inviteStatus, currentAccountAStatus);
      verify(() => mockInviteApiClient.getInviteStatus()).called(3);
    });

    test('readiness flap during refresh starts a replacement load', () async {
      final authSessions = StreamController<InviteStatusAuthSession>();
      final staleRefreshResponse = Completer<InviteStatus>();
      const replacementStatus = InviteStatus(
        canInvite: true,
        remaining: 4,
        total: 4,
        codes: [],
      );
      var requestCount = 0;
      when(() => mockInviteApiClient.getInviteStatus()).thenAnswer((_) {
        requestCount++;
        return switch (requestCount) {
          1 => Future<InviteStatus>.value(testStatus),
          2 => staleRefreshResponse.future,
          _ => Future<InviteStatus>.value(replacementStatus),
        };
      });

      final cubit = buildCubit(authSessionStream: authSessions.stream)..start();
      addTearDown(() async {
        await authSessions.close();
        await cubit.close();
      });
      await cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.loaded,
      );

      final loadingState = cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.loading,
      );
      unawaited(cubit.load());
      await loadingState;

      final waitingForAuthState = cubit.stream.firstWhere(
        (state) => state.status == InviteStatusLoadingStatus.waitingForAuth,
      );
      authSessions.add(
        const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: false,
        ),
      );
      await waitingForAuthState;

      final replacementLoadedState = cubit.stream.firstWhere(
        (state) => state.inviteStatus == replacementStatus,
      );
      authSessions.add(
        const InviteStatusAuthSession(
          accountId: testAccountId,
          isSignerReady: true,
        ),
      );
      await replacementLoadedState;

      staleRefreshResponse.complete(testStatus);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.status, InviteStatusLoadingStatus.loaded);
      expect(cubit.state.inviteStatus, replacementStatus);
      verify(() => mockInviteApiClient.getInviteStatus()).called(3);
    });

    blocTest<InviteStatusCubit, InviteStatusState>(
      'persistent 401 is an error rather than a zero allocation',
      setUp: () {
        when(() => mockInviteApiClient.getInviteStatus()).thenThrow(
          const InviteApiException(
            'Authorization header required',
            statusCode: 401,
            code: InviteApiErrorCode.authRequired,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<InviteStatusState>().having(
          (state) => state.status,
          'status',
          InviteStatusLoadingStatus.loading,
        ),
        isA<InviteStatusState>()
            .having(
              (state) => state.status,
              'status',
              InviteStatusLoadingStatus.error,
            )
            .having((state) => state.inviteStatus, 'inviteStatus', isNull),
      ],
      errors: () => <Object>[],
    );

    blocTest<InviteStatusCubit, InviteStatusState>(
      'successful zero allocation remains a loaded server result',
      setUp: () {
        when(() => mockInviteApiClient.getInviteStatus()).thenAnswer(
          (_) async => const InviteStatus(
            canInvite: false,
            remaining: 0,
            total: 0,
            codes: [],
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<InviteStatusState>().having(
          (state) => state.status,
          'status',
          InviteStatusLoadingStatus.loading,
        ),
        isA<InviteStatusState>()
            .having(
              (state) => state.status,
              'status',
              InviteStatusLoadingStatus.loaded,
            )
            .having(
              (state) => state.availableInviteCount,
              'availableInviteCount',
              0,
            ),
      ],
    );

    group('state computed properties', () {
      test('hasUnclaimedCodes returns true when unclaimed exist', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 1,
            total: 1,
            codes: [InviteCode(code: 'AAAA-BBBB', claimed: false)],
          ),
        );
        expect(state.hasUnclaimedCodes, isTrue);
        expect(state.unclaimedCount, equals(1));
        expect(state.hasAvailableInvites, isTrue);
        expect(state.availableInviteCount, equals(1));
      });

      test('hasUnclaimedCodes returns false when all claimed', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 0,
            total: 1,
            codes: [InviteCode(code: 'AAAA-BBBB', claimed: true)],
          ),
        );
        expect(state.hasUnclaimedCodes, isFalse);
        expect(state.unclaimedCount, equals(0));
        expect(state.hasAvailableInvites, isFalse);
        expect(state.availableInviteCount, equals(0));
      });

      test('hasAvailableInvites includes remaining invite capacity', () {
        const state = InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 5,
            total: 5,
            codes: [],
          ),
        );
        expect(state.hasUnclaimedCodes, isFalse);
        expect(state.unclaimedCount, equals(0));
        expect(state.hasAvailableInvites, isTrue);
        expect(state.availableInviteCount, equals(5));
      });
    });

    group('signup invite availability', () {
      test(
        'skips status and generate requests while invites are disabled',
        () async {
          when(
            () => mockInviteApiClient.getInviteStatus(),
          ).thenAnswer((_) async => testStatus);
          when(() => mockInviteApiClient.generateInvite()).thenAnswer(
            (_) async =>
                const GenerateInviteResult(code: 'AAAA-BBBB', remaining: 0),
          );

          final availability = InviteAvailabilityRepository(
            client: mockInviteApiClient,
            seed: const InviteAvailabilityState(
              hasResolved: true,
              serverMode: OnboardingMode.open,
            ),
          );
          addTearDown(availability.dispose);

          final cubit = buildCubit(availabilityRepository: availability);
          addTearDown(cubit.close);
          await cubit.load();
          await cubit.generateInvite();

          verifyNever(() => mockInviteApiClient.getInviteStatus());
          verifyNever(() => mockInviteApiClient.generateInvite());
          expect(cubit.state.inviteStatus, isNull);
        },
      );

      test(
        'clears loaded status when availability flips to disabled',
        () async {
          when(
            () => mockInviteApiClient.getInviteStatus(),
          ).thenAnswer((_) async => testStatus);

          final availability = InviteAvailabilityRepository(
            client: mockInviteApiClient,
            seed: const InviteAvailabilityState(
              hasResolved: true,
              serverMode: OnboardingMode.inviteCodeRequired,
            ),
          );
          addTearDown(availability.dispose);

          final cubit = buildCubit(availabilityRepository: availability);
          addTearDown(cubit.close);
          await cubit.load();
          expect(cubit.state.inviteStatus, testStatus);

          availability.setOverride(InviteAvailabilityOverride.forceDisabled);
          await Future<void>.delayed(Duration.zero);

          expect(cubit.state.inviteStatus, isNull);
          verify(() => mockInviteApiClient.getInviteStatus()).called(1);
        },
      );
    });
  });
}
