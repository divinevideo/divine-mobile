// ABOUTME: Tests for EmailVerificationCubit
// ABOUTME: Verifies polling lifecycle, state transitions, and error handling

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeKeycastSession extends Fake implements KeycastSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKeycastSession());
    registerFallbackValue(
      const OAuthConfig(
        serverUrl: 'https://login.divine.video',
        clientId: 'client-id',
        redirectUri: 'divine://auth',
      ),
    );
  });

  group('EmailVerificationCubit', () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;

    const testDeviceCode = 'test-device-code-abc123';
    const testVerifier = 'test-verifier-xyz789';
    const testEmail = 'test@example.com';

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      // Reset static state to ensure test isolation
      EmailVerificationCubit.resetCompletedDeviceCode();
    });

    EmailVerificationCubit buildCubit() {
      return EmailVerificationCubit(
        oauthClient: mockOAuth,
        authService: mockAuthService,
      );
    }

    group('initial state', () {
      test('has correct initial state', () {
        final cubit = buildCubit();

        expect(cubit.state, const EmailVerificationState());
        expect(cubit.state.status, EmailVerificationStatus.initial);
        expect(cubit.state.isPolling, isFalse);
        expect(cubit.state.pendingEmail, isNull);
        expect(cubit.state.errorCode, isNull);

        cubit.close();
      });
    });

    group('startPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'emits polling state with email',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        expect: () => [
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: testEmail,
          ),
        ],
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'sets isPolling to true',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        verify: (cubit) {
          expect(cubit.state.isPolling, isTrue);
          expect(cubit.state.pendingEmail, testEmail);
        },
      );

      // BYOK verifiers embed the raw nsec (see PKCE.generateVerifier), and
      // captured logs are uploaded with bug reports — the verifier value
      // must never reach a log message.
      test('never logs raw verifier when completion is missing the code', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult(status: PollStatus.complete));

        const nsecVerifier =
            'prefix.nsec1qwertyuiopasdfghjklzxcvbnm0123456789abcdef';

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: nsecVerifier,
            email: testEmail,
          );

          fake.elapse(const Duration(seconds: 4));

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(cubit.state.errorCode, EmailVerificationError.missingAuthCode);

          final messages = LogCaptureService().getRecentLogs().map(
            (entry) => entry.message,
          );
          expect(
            messages.where(
              (message) =>
                  message.contains(nsecVerifier) || message.contains('nsec1'),
            ),
            isEmpty,
            reason:
                'the BYOK verifier embeds the raw nsec and must never be '
                'logged',
          );
          expect(
            messages.where(
              (message) =>
                  message.startsWith('Verification complete but missing'),
            ),
            isNotEmpty,
            reason: 'the edge-case error log itself must still fire',
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });
    });

    group('poll failures', () {
      test('preserves stored email for duplicate-email token failure', () {
        when(() => mockOAuth.verifyEmail(token: 'verify-token')).thenAnswer(
          (_) async => VerifyEmailResult.error(
            'This email is already registered.',
            statusCode: 409,
            failure: KeycastAuthFailure.emailAlreadyRegistered,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          late EmailTokenVerificationResult verifyResult;
          cubit
              .verifyEmailToken(
                token: 'verify-token',
                keepPollingOnTransient: true,
              )
              .then((result) => verifyResult = result);
          fake.flushMicrotasks();

          expect(
            verifyResult.status,
            EmailTokenVerificationStatus.terminalFailure,
          );
          expect(
            verifyResult.errorCode,
            EmailVerificationError.emailAlreadyRegistered,
          );
          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            cubit.state.errorCode,
            EmailVerificationError.emailAlreadyRegistered,
          );
          expect(cubit.state.pendingEmail, testEmail);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'retries transient token verification while polling stays active',
        () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult(status: PollStatus.pending));

          var verifyCalls = 0;
          when(() => mockOAuth.verifyEmail(token: 'verify-token')).thenAnswer((
            _,
          ) async {
            verifyCalls++;
            if (verifyCalls < 4) {
              return VerifyEmailResult.error(
                'Temporary verification failure',
                statusCode: 503,
                failure: KeycastAuthFailure.temporary,
              );
            }
            return VerifyEmailResult(success: true);
          });

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

            late EmailTokenVerificationResult firstResult;
            cubit
                .verifyEmailToken(
                  token: 'verify-token',
                  keepPollingOnTransient: true,
                )
                .then((result) => firstResult = result);

            fake.flushMicrotasks();
            fake.elapse(const Duration(seconds: 4));
            fake.flushMicrotasks();

            expect(
              firstResult.status,
              EmailTokenVerificationStatus.transientFailure,
            );
            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.errorCode, isNull);
            expect(verifyCalls, 3);

            fake.elapse(const Duration(seconds: 3));
            fake.flushMicrotasks();

            expect(verifyCalls, 4);
            expect(cubit.state.status, EmailVerificationStatus.polling);
            verify(
              () => mockOAuth.pollForCode(testDeviceCode),
            ).called(greaterThan(0));

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('stops polling on duplicate email conflict', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer(
          (_) async => PollResult.error(
            'This email is already registered.',
            statusCode: 409,
            failure: KeycastAuthFailure.emailAlreadyRegistered,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            cubit.state.errorCode,
            EmailVerificationError.emailAlreadyRegistered,
          );
          expect(cubit.state.pendingEmail, testEmail);

          fake.elapse(const Duration(seconds: 30));
          fake.flushMicrotasks();
          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('keeps polling on transient backend failure', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer(
          (_) async => PollResult.error(
            'Temporary verification failure',
            statusCode: 503,
            failure: KeycastAuthFailure.temporary,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();

          expect(cubit.state.status, EmailVerificationStatus.polling);
          expect(cubit.state.errorCode, isNull);

          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(2);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('maps expired verification token to link-expired failure', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer(
          (_) async => PollResult.error(
            'Invalid or expired verification token',
            statusCode: 401,
            failure: KeycastAuthFailure.expiredVerification,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            cubit.state.errorCode,
            EmailVerificationError.verificationLinkExpired,
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });
    });

    group('stopPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'clears state and stops polling',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: testEmail,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.isPolling, isFalse);
          expect(cubit.state.pendingEmail, isNull);
          expect(cubit.state.errorCode, isNull);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'preserves success state to avoid UI flash',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => <EmailVerificationState>[],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.success);
        },
      );
    });

    group('reset', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from success state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from polling state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: testEmail,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
          expect(cubit.state.pendingEmail, isNull);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from failure state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.failure,
          errorCode: EmailVerificationError.timeout,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
          expect(cubit.state.errorCode, isNull);
        },
      );
    });

    group('zombie cubit detection', () {
      const testCode = 'auth-code-from-server';

      test('zombie cubit stops polling when device code already completed', () {
        // Simulate cubit #1 (the one that completed verification)
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit1 = buildCubit();
          cubit1.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the first poll cycle complete (exchange succeeds)
          fake.elapse(const Duration(seconds: 4));

          // Cubit #1 should have completed and set the static field
          expect(cubit1.state.status, EmailVerificationStatus.success);

          // Simulate cubit #2 (zombie from engine restart, different
          // auth service that doesn't know about the sign-in)
          final zombieOAuth = _MockKeycastOAuth();
          final zombieAuthService = _MockAuthService();
          when(() => zombieAuthService.isAuthenticated).thenReturn(false);
          when(() => zombieAuthService.isRegistered).thenReturn(false);
          when(
            () => zombieOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          final cubit2 = EmailVerificationCubit(
            oauthClient: zombieOAuth,
            authService: zombieAuthService,
          );
          cubit2.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the zombie's first poll cycle run
          fake.elapse(const Duration(seconds: 4));

          // Zombie should have emitted success (so the screen navigates)
          expect(cubit2.state.status, EmailVerificationStatus.success);

          // pollForCode should NOT have been called on the zombie
          // because the static guard fires before the network call
          verifyNever(() => zombieOAuth.pollForCode(any()));

          cubit1.close();
          cubit2.close();
          fake.flushMicrotasks();
        });
      });

      test('different device code is not affected by completed code', () {
        // Simulate cubit #1 completing with one device code
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit1 = buildCubit();
          cubit1.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );
          fake.elapse(const Duration(seconds: 4));

          // Now a NEW registration with a different device code should
          // NOT be blocked
          const newDeviceCode = 'new-device-code-different';
          final newOAuth = _MockKeycastOAuth();
          final newAuthService = _MockAuthService();
          when(() => newAuthService.isAuthenticated).thenReturn(false);
          when(() => newAuthService.isRegistered).thenReturn(false);
          when(
            () => newOAuth.pollForCode(newDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          final cubit2 = EmailVerificationCubit(
            oauthClient: newOAuth,
            authService: newAuthService,
          );
          cubit2.startPolling(
            deviceCode: newDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );
          fake.elapse(const Duration(seconds: 4));

          // pollForCode SHOULD have been called — different device code
          verify(() => newOAuth.pollForCode(newDeviceCode)).called(1);

          cubit1.close();
          cubit2.close();
          fake.flushMicrotasks();
        });
      });
    });

    group('stale authSource guard', () {
      // Regression test for: isRegistered returns true based on _authSource
      // which persists across sign-outs. On a device with a prior OAuth session,
      // _authSource stays divineOAuth even after auth state goes unauthenticated.
      // The polling guard must require isAuthenticated AND isRegistered or it
      // kills legitimate new-user registration polls on the first tick.
      test(
        'does not stop polling when isRegistered=true but isAuthenticated=false',
        () {
          // Simulate stale authSource: device had a prior OAuth session (signed
          // out), so isRegistered=true but isAuthenticated=false.
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isRegistered).thenReturn(true);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

            // Advance past two poll cycles (fires at t=3s and t=6s)
            fake.elapse(const Duration(seconds: 7));

            // Polling should still be running — guard must NOT have fired
            expect(cubit.state.status, EmailVerificationStatus.polling);
            verify(
              () => mockOAuth.pollForCode(testDeviceCode),
            ).called(greaterThanOrEqualTo(2));

            // Cancel timers before fakeAsync exits
            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'stops polling when both isAuthenticated=true and isRegistered=true',
        () {
          // Guard should still fire for the legitimate zombie-cubit case:
          // user IS authenticated AND registered (completed sign-in elsewhere).
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(() => mockAuthService.isRegistered).thenReturn(true);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

            // Advance past first poll tick (fires at t=3s, guard cancels timers)
            fake.elapse(const Duration(seconds: 4));

            // Guard fires before the network call — pollForCode never called.
            // (The cubit stops its timer silently without emitting a state change.)
            verifyNever(() => mockOAuth.pollForCode(any()));

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('close', () {
      test('cleans up timers on close', () async {
        final cubit = buildCubit();

        cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        );

        expect(cubit.state.isPolling, isTrue);

        await cubit.close();

        // Cubit should be closed without errors
        // (verifying no lingering timers cause issues)
      });

      test('close leaves no pending timers', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Advance enough to schedule a few backoff ticks.
          fake.elapse(const Duration(seconds: 8));

          unawaited(cubit.close());
          fake.flushMicrotasks();

          // No timers must remain after close — leaked timers would keep the
          // fake clock advancing and cause the test to hang on shutdown.
          expect(fake.pendingTimers, isEmpty);
        });
      });
    });

    group('bounded backoff schedule', () {
      // The fixed-3 s Timer.periodic was replaced with a recursive Timer
      // using EmailVerificationCubit.pollBackoffSchedule (3, 3, 5, 8, 13,
      // 21 s) capped at 30 s. The schedule must:
      //   - keep first-poll UX snappy (no slower than the old 3 s),
      //   - reduce the wakeup count over the 15-min budget, and
      //   - cap at 30 s so users never wait too long after a delayed click.

      test('first poll fires at +3s (matches legacy snappy interval)', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Just before the first scheduled tick.
          fake.elapse(const Duration(seconds: 2));
          verifyNever(() => mockOAuth.pollForCode(any()));

          // Cross the 3 s mark.
          fake.elapse(const Duration(seconds: 1));
          fake.flushMicrotasks();
          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      test('issues fewer polls in 60 s than a fixed 3 s interval would', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // 60 s window.
          // Backoff schedule cumulative ticks at: 3, 6, 11, 19, 32, 53. After
          // index 5 the cap of 30 s applies, so the next tick lands at 83 s
          // (outside the window). That leaves 6 ticks total in 60 s vs the
          // 20 ticks a fixed 3 s interval would produce.
          fake.elapse(const Duration(seconds: 60));
          fake.flushMicrotasks();

          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(6);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      test('caps subsequent polls at 30 s', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Burn through the variable portion of the schedule (sums to
          // 3+3+5+8+13+21 = 53 s, after which the cap takes over).
          fake.elapse(const Duration(seconds: 53));
          fake.flushMicrotasks();
          final pollsAfterScheduleBody = verify(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).callCount;
          expect(pollsAfterScheduleBody, equals(6));

          // From here every additional 30 s should add exactly one poll.
          fake.elapse(const Duration(seconds: 30));
          fake.flushMicrotasks();
          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

          fake.elapse(const Duration(seconds: 30));
          fake.flushMicrotasks();
          verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

          unawaited(cubit.close());
          fake.flushMicrotasks();
        });
      });

      test('exposes a non-empty schedule and a sane cap', () {
        // Guard against future changes to the schedule constants that would
        // silently regress the 15-min budget or remove the cap.
        expect(EmailVerificationCubit.pollBackoffSchedule, isNotEmpty);
        // Cap is 30 s in the current schedule. Allow a small headroom for
        // future tweaks but flag anything that would noticeably blunt UX
        // for a late-clicking user.
        expect(
          EmailVerificationCubit.pollBackoffCap.inSeconds,
          lessThanOrEqualTo(45),
        );
        for (final entry in EmailVerificationCubit.pollBackoffSchedule) {
          expect(entry.inSeconds, greaterThan(0));
          expect(
            entry,
            lessThanOrEqualTo(EmailVerificationCubit.pollBackoffCap),
          );
        }
      });
    });

    group('submitPin', () {
      const pin = '123456';
      const pinCode = 'pin-auth-code';

      void stubExchangeSuccess() {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
        ).thenAnswer((_) async => VerifyPinResult.success(pinCode));
        when(
          () => mockOAuth.exchangeCode(code: pinCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});
      }

      test('valid PIN exchanges the code and authenticates', () {
        stubExchangeSuccess();

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(seconds: 2));

          expect(cubit.state.status, EmailVerificationStatus.success);
          verifyInOrder([
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
            () => mockOAuth.exchangeCode(code: pinCode, verifier: testVerifier),
            () => mockAuthService.signInWithDivineOAuth(any()),
          ]);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'already-completed PIN response clears submission without error',
        () {
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
          ).thenAnswer((_) async => VerifyPinResult.alreadyCompleted());

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            unawaited(cubit.submitPin(pin));
            fake.elapse(const Duration(milliseconds: 100));

            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pinStatus, PinSubmissionStatus.idle);
            expect(cubit.state.pinErrorCode, isNull);
            verifyNever(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            );

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('duplicate email from PIN routes to sign-in recovery failure', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
        ).thenAnswer(
          (_) async =>
              VerifyPinResult.failure(VerifyPinError.emailAlreadyRegistered),
        );

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            cubit.state.errorCode,
            EmailVerificationError.emailAlreadyRegistered,
          );
          expect(cubit.state.pinStatus, PinSubmissionStatus.idle);
          expect(cubit.state.pinErrorCode, isNull);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'abandons exchange when pending context is cleared during verifyPin',
        () {
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          // verifyPin hangs so the escape hatch can clear the pending context
          // before it resolves.
          when(
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return VerifyPinResult.success(pinCode);
          });
          when(
            () => mockOAuth.exchangeCode(code: pinCode, verifier: testVerifier),
          ).thenAnswer(
            (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
          );
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            unawaited(cubit.submitPin(pin));
            fake.elapse(const Duration(milliseconds: 100));
            expect(cubit.state.pinStatus, PinSubmissionStatus.submitting);

            // The user leaves (escape hatch) while verifyPin is still in
            // flight; stopPolling clears the pending context WITHOUT claiming
            // completion.
            cubit.stopPolling();

            // verifyPin now resolves success — the abandoned submit must NOT
            // exchange or sign in.
            fake.elapse(const Duration(seconds: 6));

            verifyNever(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            );
            verifyNever(() => mockAuthService.signInWithDivineOAuth(any()));
            expect(cubit.state.status, isNot(EmailVerificationStatus.success));

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'delayed PIN failure after a new attempt does not emit on current state',
        () {
          const secondDeviceCode = 'second-device-code-def456';
          const secondVerifier = 'second-verifier-uvw123';
          const secondEmail = 'second@example.com';

          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.pollForCode(secondDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return VerifyPinResult.failure(VerifyPinError.invalid);
          });

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            unawaited(cubit.submitPin(pin));
            fake.elapse(const Duration(milliseconds: 100));
            expect(cubit.state.pinStatus, PinSubmissionStatus.submitting);

            cubit.startPolling(
              deviceCode: secondDeviceCode,
              verifier: secondVerifier,
              email: secondEmail,
            );

            fake.elapse(const Duration(seconds: 6));
            fake.flushMicrotasks();

            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);
            expect(cubit.state.pinStatus, PinSubmissionStatus.idle);
            expect(cubit.state.pinErrorCode, isNull);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      void stubPinFailure(VerifyPinError error) {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
        ).thenAnswer((_) async => VerifyPinResult.failure(error));
      }

      test('invalid PIN surfaces pinInvalid and keeps polling status', () {
        stubPinFailure(VerifyPinError.invalid);

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.pinStatus, PinSubmissionStatus.failure);
          expect(cubit.state.pinErrorCode, EmailVerificationError.pinInvalid);
          expect(cubit.state.status, EmailVerificationStatus.polling);
          verifyNever(
            () => mockOAuth.exchangeCode(
              code: any(named: 'code'),
              verifier: any(named: 'verifier'),
            ),
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('expired PIN surfaces pinExpired', () {
        stubPinFailure(VerifyPinError.expired);

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.pinErrorCode, EmailVerificationError.pinExpired);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('locked PIN surfaces pinLocked', () {
        stubPinFailure(VerifyPinError.locked);

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.pinErrorCode, EmailVerificationError.pinLocked);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('unavailable PIN endpoint surfaces pinUnavailable', () {
        stubPinFailure(VerifyPinError.unavailable);

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(milliseconds: 100));

          expect(
            cubit.state.pinErrorCode,
            EmailVerificationError.pinUnavailable,
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('without pending context fails without calling the server', () {
        final cubit = buildCubit();

        cubit.submitPin(pin);

        expect(cubit.state.pinStatus, PinSubmissionStatus.failure);
        expect(cubit.state.pinErrorCode, EmailVerificationError.pinFailed);
        verifyNever(
          () => mockOAuth.verifyPin(
            deviceCode: any(named: 'deviceCode'),
            pin: any(named: 'pin'),
          ),
        );

        cubit.close();
      });
    });

    group('completion race (poll vs PIN submit)', () {
      const pin = '123456';
      const pinCode = 'pin-auth-code';
      const pollCode = 'poll-auth-code';

      // A PIN submit and a poll completion can land on the same cubit at once
      // (user types the PIN while the link's poll is mid-flight). Only one may
      // reach token exchange, and the in-flight poll must
      // not overwrite the PIN-driven success with a missingAuthCode failure.
      test(
        'PIN submit wins; in-flight poll bails without a second exchange',
        () {
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(() => mockOAuth.config).thenReturn(
            const OAuthConfig(
              serverUrl: 'https://login.divine.video',
              clientId: 'client-id',
              redirectUri: 'divine://auth',
            ),
          );
          // pollForCode resolves slowly so the poll is still in flight when
          // the PIN submit claims completion.
          when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((
            _,
          ) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return PollResult.complete(pollCode);
          });
          when(
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
          ).thenAnswer((_) async => VerifyPinResult.success(pinCode));
          when(
            () => mockOAuth.exchangeCode(
              code: any(named: 'code'),
              verifier: any(named: 'verifier'),
            ),
          ).thenAnswer(
            (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
          );
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            // Fire the first poll tick; _poll() is now awaiting the slow
            // pollForCode (in flight).
            fake.elapse(const Duration(seconds: 3));

            // User submits the PIN mid-flight. It claims completion and runs
            // the exchange to success.
            unawaited(cubit.submitPin(pin));
            fake.elapse(const Duration(seconds: 2));

            expect(cubit.state.status, EmailVerificationStatus.success);

            // Let the in-flight poll resolve. It must observe the claim and
            // bail — no second exchange, no missingAuthCode over success.
            fake.elapse(const Duration(seconds: 10));

            expect(cubit.state.status, EmailVerificationStatus.success);
            expect(cubit.state.errorCode, isNull);
            verify(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).called(1);
            verify(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('a second PIN submit after one is claimed does not re-exchange', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockOAuth.config).thenReturn(
          const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'client-id',
            redirectUri: 'divine://auth',
          ),
        );
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
        ).thenAnswer((_) async => VerifyPinResult.success(pinCode));
        when(
          () => mockOAuth.exchangeCode(code: pinCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(seconds: 2));
          expect(cubit.state.status, EmailVerificationStatus.success);

          // Second submit after completion is already claimed must no-op.
          unawaited(cubit.submitPin(pin));
          fake.elapse(const Duration(seconds: 2));

          expect(cubit.state.status, EmailVerificationStatus.success);
          verify(
            () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: pin),
          ).called(1);
          verify(
            () => mockOAuth.exchangeCode(code: pinCode, verifier: testVerifier),
          ).called(1);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'stale poll completion after a new attempt does not exchange or cleanup',
        () {
          const secondDeviceCode = 'second-device-code-def456';
          const secondVerifier = 'second-verifier-uvw123';
          const secondEmail = 'second@example.com';

          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((
            _,
          ) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return PollResult.complete(pollCode);
          });
          when(
            () => mockOAuth.pollForCode(secondDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.exchangeCode(
              code: pollCode,
              verifier: secondVerifier,
            ),
          ).thenAnswer(
            (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
          );
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            fake.elapse(const Duration(seconds: 3));
            verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

            cubit.startPolling(
              deviceCode: secondDeviceCode,
              verifier: secondVerifier,
              email: secondEmail,
            );

            fake.elapse(const Duration(seconds: 5));
            fake.flushMicrotasks();

            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);
            verifyNever(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            );
            verifyNever(
              () => mockOAuth.exchangeCode(
                code: pollCode,
                verifier: secondVerifier,
              ),
            );

            verify(() => mockOAuth.pollForCode(secondDeviceCode)).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'stale terminal poll error after a new attempt does not emit or cleanup',
        () {
          const secondDeviceCode = 'second-device-code-def456';
          const secondVerifier = 'second-verifier-uvw123';
          const secondEmail = 'second@example.com';

          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((
            _,
          ) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return PollResult.error(
              'Invalid or expired verification token',
              statusCode: 401,
              failure: KeycastAuthFailure.expiredVerification,
            );
          });
          when(
            () => mockOAuth.pollForCode(secondDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            fake.elapse(const Duration(seconds: 3));
            verify(() => mockOAuth.pollForCode(testDeviceCode)).called(1);

            cubit.startPolling(
              deviceCode: secondDeviceCode,
              verifier: secondVerifier,
              email: secondEmail,
            );

            fake.elapse(const Duration(seconds: 5));
            fake.flushMicrotasks();

            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);
            expect(cubit.state.errorCode, isNull);

            verify(() => mockOAuth.pollForCode(secondDeviceCode)).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'stale exchange retry after a new attempt does not emit cleanup or sign in',
        () {
          const secondDeviceCode = 'second-device-code-def456';
          const secondVerifier = 'second-verifier-uvw123';
          const secondEmail = 'second@example.com';
          const firstCode = 'first-auth-code';

          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.complete(firstCode));
          when(
            () => mockOAuth.pollForCode(secondDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          var firstExchangeCalls = 0;
          when(
            () =>
                mockOAuth.exchangeCode(code: firstCode, verifier: testVerifier),
          ).thenAnswer((_) async {
            firstExchangeCalls++;
            if (firstExchangeCalls == 1) {
              throw Exception('transient network error');
            }
            return const TokenResponse(bunkerUrl: 'wss://first-session.test');
          });
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            // First poll completes and starts exchange attempt A. Its first
            // exchange throws, putting A into the 2s retry delay.
            fake.elapse(const Duration(seconds: 4));
            expect(firstExchangeCalls, 1);

            // A fresh attempt B starts while A is waiting to retry. This bumps
            // the generation and must keep its polling context/timers intact.
            cubit.startPolling(
              deviceCode: secondDeviceCode,
              verifier: secondVerifier,
              email: secondEmail,
            );
            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);

            // Let A's retry delay elapse and its second exchange return a
            // session. A is stale and must not commit, cleanup B, emit failure
            // or success, or sign in with the first session.
            fake.elapse(const Duration(seconds: 3));
            fake.flushMicrotasks();

            expect(firstExchangeCalls, 1);
            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);
            expect(cubit.state.errorCode, isNull);
            verifyNever(() => mockAuthService.signInWithDivineOAuth(any()));

            // B's scheduled poll should still be alive.
            verify(() => mockOAuth.pollForCode(secondDeviceCode)).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('resendVerification', () {
      test('sends, enters cooldown, then re-enables after 5 minutes', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer((_) async => ResendVerificationResult(success: true));

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.resendStatus, ResendStatus.cooldown);
          expect(cubit.state.resendCooldownSeconds, 300);

          fake.elapse(const Duration(seconds: 1));
          expect(cubit.state.resendCooldownSeconds, 299);

          fake.elapse(const Duration(minutes: 5));
          expect(cubit.state.resendStatus, ResendStatus.idle);
          expect(cubit.state.resendCooldownSeconds, 0);

          verify(
            () => mockOAuth.resendHeadlessVerification(testDeviceCode),
          ).called(1);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('is ignored while already on cooldown', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer((_) async => ResendVerificationResult(success: true));

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));
          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          verify(
            () => mockOAuth.resendHeadlessVerification(testDeviceCode),
          ).called(1);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('a declined result surfaces retryable failure', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer(
          (_) async => ResendVerificationResult.failure(
            ResendVerificationError.declined,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.resendStatus, ResendStatus.failure);
          expect(cubit.state.resendCooldownSeconds, 0);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('an unavailable endpoint surfaces the non-retryable status', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer(
          (_) async => ResendVerificationResult.failure(
            ResendVerificationError.unavailable,
          ),
        );

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.resendStatus, ResendStatus.unavailable);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('an expired registration surfaces the expired status', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer(
          (_) async =>
              ResendVerificationResult.failure(ResendVerificationError.expired),
        );

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.resendStatus, ResendStatus.expired);
          expect(cubit.state.resendCooldownSeconds, 0);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('a thrown error surfaces retryable failure', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenThrow(Exception('network down'));

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));

          expect(cubit.state.resendStatus, ResendStatus.failure);
          expect(cubit.state.resendCooldownSeconds, 0);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('startPolling cancels an active resend cooldown timer', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer((_) async => ResendVerificationResult(success: true));

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));
          expect(cubit.state.resendStatus, ResendStatus.cooldown);
          expect(cubit.state.resendCooldownSeconds, 300);

          // Re-init polling (e.g. re-arm after timeout, or a fresh
          // registration). The cooldown timer must be cancelled so it cannot
          // keep ticking onto the reset state.
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );
          expect(cubit.state.resendStatus, ResendStatus.idle);
          expect(cubit.state.resendCooldownSeconds, 0);

          // An orphaned cooldown timer would fire here and mutate the state.
          fake.elapse(const Duration(seconds: 3));
          expect(cubit.state.resendStatus, ResendStatus.idle);
          expect(
            cubit.state.resendCooldownSeconds,
            0,
            reason: 'orphaned resend timer must be cancelled on re-init',
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'delayed resend completion after a new attempt does not start cooldown',
        () {
          const secondDeviceCode = 'second-device-code-def456';
          const secondVerifier = 'second-verifier-uvw123';
          const secondEmail = 'second@example.com';

          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.pollForCode(secondDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());
          when(
            () => mockOAuth.resendHeadlessVerification(testDeviceCode),
          ).thenAnswer((_) async {
            await Future<void>.delayed(const Duration(seconds: 5));
            return ResendVerificationResult(success: true);
          });

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            unawaited(cubit.resendVerification());
            fake.elapse(const Duration(milliseconds: 100));
            expect(cubit.state.resendStatus, ResendStatus.sending);

            cubit.startPolling(
              deviceCode: secondDeviceCode,
              verifier: secondVerifier,
              email: secondEmail,
            );

            fake.elapse(const Duration(seconds: 6));
            fake.flushMicrotasks();

            expect(cubit.state.status, EmailVerificationStatus.polling);
            expect(cubit.state.pendingEmail, secondEmail);
            expect(cubit.state.resendStatus, ResendStatus.idle);
            expect(cubit.state.resendCooldownSeconds, 0);
            verify(
              () => mockOAuth.resendHeadlessVerification(testDeviceCode),
            ).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('resumePollingAfterTimeout', () {
      const lateCode = 'late-poll-code';

      test('re-arms polling and completes after a late link click', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        // Pending the whole 15-min window, so the cubit times out.
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.exchangeCode(code: lateCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          fake.elapse(const Duration(minutes: 16));
          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

          // The late link click has now marked the email verified server-side,
          // so the re-armed poll returns a code.
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.complete(lateCode));

          cubit.resumePollingAfterTimeout();
          fake.elapse(const Duration(seconds: 4));

          expect(cubit.state.status, EmailVerificationStatus.success);
          verify(
            () =>
                mockOAuth.exchangeCode(code: lateCode, verifier: testVerifier),
          ).called(1);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('no-ops when not timed out', () {
        final cubit = buildCubit();

        cubit.resumePollingAfterTimeout();

        expect(cubit.state.status, EmailVerificationStatus.initial);
        verifyNever(() => mockOAuth.pollForCode(any()));

        cubit.close();
      });
    });

    group('poll timeout keeps PIN entry available', () {
      test(
        'an in-flight poll that resumes after timeout does not reschedule',
        () {
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isRegistered).thenReturn(false);

          // Each poll hangs for ~1000s so a poll is still in flight when the
          // 15-minute timeout fires, and the resume is driven by the fake clock
          // (a timer) rather than a microtask — making the recursion-guard
          // decision observable via elapse().
          var pollCalls = 0;
          when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((
            _,
          ) async {
            pollCalls++;
            await Future<void>.delayed(const Duration(seconds: 1000));
            return PollResult.pending();
          });

          fakeAsync((fake) {
            final cubit = buildCubit()
              ..startPolling(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              );

            // First poll fires at +3s and is still in flight (resolves ~1003s).
            fake.elapse(const Duration(seconds: 4));
            expect(pollCalls, 1);

            // The 15-minute timeout fires while the poll is still in flight.
            fake.elapse(const Duration(minutes: 15));
            expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

            // Drive past the in-flight poll's resolution (~1003s). It must NOT
            // re-arm the poll loop — _onTimeout retains the pending device code
            // for PIN entry, but the poll loop is over. Without the guard, the
            // resumed poll reschedules and pollCalls climbs.
            fake.elapse(const Duration(minutes: 10));

            expect(
              pollCalls,
              1,
              reason: 'a poll resuming after timeout must not reschedule',
            );
            expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('timeout transitions to pollingTimedOut, not failure', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          fake.elapse(const Duration(minutes: 16));

          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);
          expect(cubit.state.pendingEmail, testEmail);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('PIN can still be submitted after the poll timeout', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.verifyPin(deviceCode: testDeviceCode, pin: '123456'),
        ).thenAnswer((_) async => VerifyPinResult.success('late-code'));
        when(
          () =>
              mockOAuth.exchangeCode(code: 'late-code', verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          fake.elapse(const Duration(minutes: 16));
          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

          unawaited(cubit.submitPin('123456'));
          fake.elapse(const Duration(seconds: 2));

          expect(cubit.state.status, EmailVerificationStatus.success);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('timeout does not clobber an in-flight claimed completion', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete('race-code'));
        // Exchange hangs past the 15-minute timeout, so the completion is
        // claimed (set synchronously in _exchangeCodeAndLogin) but unfinished
        // when _onTimeout fires.
        when(
          () =>
              mockOAuth.exchangeCode(code: 'race-code', verifier: testVerifier),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(minutes: 20));
          return const TokenResponse(bunkerUrl: 'wss://relay.test');
        });
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          // First poll at +3s returns complete and claims the exchange.
          fake.elapse(const Duration(seconds: 4));

          // The 15-minute timeout fires while the exchange is still in flight.
          fake.elapse(const Duration(minutes: 15));
          expect(
            cubit.state.status,
            isNot(EmailVerificationStatus.pollingTimedOut),
            reason: 'a claimed completion must not be clobbered by the timeout',
          );

          // Let the exchange finish — success lands.
          fake.elapse(const Duration(minutes: 6));
          expect(cubit.state.status, EmailVerificationStatus.success);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('in-flight recoverable poll error after timeout keeps PIN entry '
          'available', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);

        // The poll hangs past the 15-minute timeout, then resolves with a
        // non-transient but recoverable/unknown failure.
        when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 1000));
          // No explicit failure -> defaults to the non-transient
          // KeycastAuthFailure.unknown (a recoverable/unknown poll error).
          return PollResult.error('server error');
        });

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          fake.elapse(const Duration(seconds: 4)); // poll in flight
          fake.elapse(const Duration(minutes: 15)); // timeout fires
          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

          // The in-flight poll resolves with a recoverable error after the
          // window elapsed. It must NOT tear down the preserved PIN path.
          fake.elapse(const Duration(minutes: 10));

          expect(
            cubit.state.status,
            EmailVerificationStatus.pollingTimedOut,
            reason:
                'a recoverable poll error after timeout must keep PIN entry '
                'usable, not drop to terminal failure',
          );
          expect(cubit.state.pendingEmail, testEmail);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('in-flight expired poll error after timeout still terminates', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);

        when(() => mockOAuth.pollForCode(testDeviceCode)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(seconds: 1000));
          return PollResult.error(
            'expired',
            failure: KeycastAuthFailure.expiredVerification,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          fake.elapse(const Duration(seconds: 4));
          fake.elapse(const Duration(minutes: 15));
          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);

          fake.elapse(const Duration(minutes: 10));

          expect(
            cubit.state.status,
            EmailVerificationStatus.failure,
            reason:
                'a genuinely-expired device code must still terminate even '
                'after the poll window elapsed',
          );
          expect(
            cubit.state.errorCode,
            EmailVerificationError.verificationLinkExpired,
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('timeout cancels an active resend cooldown timer', () {
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.pending());
        when(
          () => mockOAuth.resendHeadlessVerification(testDeviceCode),
        ).thenAnswer((_) async => ResendVerificationResult(success: true));

        fakeAsync((fake) {
          final cubit = buildCubit()
            ..startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

          // Resend late (minute 12) so the 5-minute cooldown is still active
          // when the 15-minute timeout fires.
          fake.elapse(const Duration(minutes: 12));
          unawaited(cubit.resendVerification());
          fake.elapse(const Duration(milliseconds: 100));
          expect(cubit.state.resendStatus, ResendStatus.cooldown);
          expect(cubit.state.resendCooldownSeconds, 300);

          // Timeout fires ~3 min into the cooldown.
          fake.elapse(const Duration(minutes: 3));
          expect(cubit.state.status, EmailVerificationStatus.pollingTimedOut);
          expect(cubit.state.resendStatus, ResendStatus.idle);
          expect(cubit.state.resendCooldownSeconds, 0);

          // An orphaned cooldown tick would revive resendCooldownSeconds onto
          // the timed-out state here.
          fake.elapse(const Duration(seconds: 3));
          expect(cubit.state.resendStatus, ResendStatus.idle);
          expect(
            cubit.state.resendCooldownSeconds,
            0,
            reason: 'resend timer must be cancelled on timeout',
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });
    });
  });

  group('EmailVerificationState', () {
    test('creates with default values', () {
      const state = EmailVerificationState();

      expect(state.status, EmailVerificationStatus.initial);
      expect(state.isPolling, isFalse);
      expect(state.pendingEmail, isNull);
      expect(state.errorCode, isNull);
    });

    test('creates with custom values', () {
      const state = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'test@example.com',
        errorCode: EmailVerificationError.timeout,
      );

      expect(state.status, EmailVerificationStatus.polling);
      expect(state.isPolling, isTrue);
      expect(state.pendingEmail, 'test@example.com');
      expect(state.errorCode, EmailVerificationError.timeout);
    });

    test('isPolling returns true only when status is polling', () {
      expect(const EmailVerificationState().isPolling, isFalse);
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.polling,
        ).isPolling,
        isTrue,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ).isPolling,
        isFalse,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.failure,
        ).isPolling,
        isFalse,
      );
    });

    test('copyWith creates new state with updated values', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'original@example.com',
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.success,
      );

      expect(updated.status, EmailVerificationStatus.success);
      expect(updated.pendingEmail, 'original@example.com');
      expect(updated.errorCode, isNull);
    });

    test('copyWith preserves errorCode when the argument is omitted', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.failure,
        errorCode: EmailVerificationError.timeout,
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.polling,
      );

      expect(updated.status, EmailVerificationStatus.polling);
      expect(updated.errorCode, EmailVerificationError.timeout);
    });

    test('copyWith clears errorCode when passed explicit null', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.failure,
        errorCode: EmailVerificationError.timeout,
      );

      final updated = original.copyWith(errorCode: null);

      expect(updated.errorCode, isNull);
    });

    test('copyWith preserves pinErrorCode when an unrelated field changes', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.pollingTimedOut,
        pinStatus: PinSubmissionStatus.failure,
        pinErrorCode: EmailVerificationError.pinInvalid,
      );

      final updated = original.copyWith(resendCooldownSeconds: 42);

      expect(updated.resendCooldownSeconds, 42);
      expect(updated.pinErrorCode, EmailVerificationError.pinInvalid);
    });

    test('copyWith clears pinErrorCode when passed explicit null', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.pollingTimedOut,
        pinStatus: PinSubmissionStatus.failure,
        pinErrorCode: EmailVerificationError.pinInvalid,
      );

      final updated = original.copyWith(pinErrorCode: null);

      expect(updated.pinErrorCode, isNull);
    });

    group('equality', () {
      test('states with same values are equal', () {
        expect(
          const EmailVerificationState(),
          equals(const EmailVerificationState()),
        );

        expect(
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'test@example.com',
          ),
          equals(
            const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'test@example.com',
            ),
          ),
        );
      });

      test('states with different values are not equal', () {
        expect(
          const EmailVerificationState(status: EmailVerificationStatus.polling),
          isNot(equals(const EmailVerificationState())),
        );

        expect(
          const EmailVerificationState(pendingEmail: 'a@example.com'),
          isNot(
            equals(const EmailVerificationState(pendingEmail: 'b@example.com')),
          ),
        );
      });
    });
  });

  group('EmailVerificationStatus', () {
    test('has all expected values', () {
      expect(EmailVerificationStatus.values, hasLength(5));
      expect(
        EmailVerificationStatus.values,
        containsAll([
          EmailVerificationStatus.initial,
          EmailVerificationStatus.polling,
          EmailVerificationStatus.pollingTimedOut,
          EmailVerificationStatus.success,
          EmailVerificationStatus.failure,
        ]),
      );
    });
  });
}
