// ABOUTME: Tests for DivineAuthCubit
// ABOUTME: Verifies form state, validation, sign-in, sign-up, and error handling

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/utils/validators.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _RecordingAnalytics implements AnalyticsEventSink {
  final properties = <({String name, String? value})>[];

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async => properties.add((name: name, value: value));

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

class _FakeKeycastSession extends Fake implements KeycastSession {}

class _FakeSecureKeyContainer extends Fake implements SecureKeyContainer {}

/// Captures errors routed through [Bloc.observer] so a test can assert that a
/// flow reported none.
class _RecordingBlocObserver extends BlocObserver {
  _RecordingBlocObserver(this.errors);

  final List<Object> errors;

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKeycastSession());
    registerFallbackValue(_FakeSecureKeyContainer());
    registerFallbackValue(
      const OAuthConfig(
        serverUrl: 'https://login.divine.video',
        clientId: 'client-id',
        redirectUri: 'divine://auth',
      ),
    );
  });

  group(DivineAuthCubit, () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;
    late _MockPendingVerificationService mockPendingVerification;
    late _MockInviteApiClient mockInviteApiClient;
    late _RecordingAnalytics analytics;

    const testEmail = 'test@example.com';
    const testPassword = 'password123';
    const testVerifier = 'test-verifier-xyz789';
    const testDeviceCode = 'test-device-code-abc123';
    const testCode = 'auth-code-456';

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      mockPendingVerification = _MockPendingVerificationService();
      mockInviteApiClient = _MockInviteApiClient();
      analytics = _RecordingAnalytics();
      when(
        () => mockAuthService.clearPendingDivineOAuthSession(),
      ).thenAnswer((_) async {});
      when(() => mockOAuth.config).thenReturn(
        const OAuthConfig(
          serverUrl: 'https://login.divine.video',
          clientId: 'client-id',
          redirectUri: 'divine://auth',
        ),
      );
    });

    DivineAuthCubit buildCubit({String? inviteCode}) {
      return DivineAuthCubit(
        oauthClient: mockOAuth,
        authService: mockAuthService,
        pendingVerificationService: mockPendingVerification,
        inviteApiClient: mockInviteApiClient,
        inviteCode: inviteCode,
        validationMessages: AuthValidationMessages.englishDefaults,
        analytics: analytics,
      );
    }

    group('initial state', () {
      test('is $DivineAuthInitial', () {
        final cubit = buildCubit();
        expect(cubit.state, isA<DivineAuthInitial>());
        cubit.close();
      });
    });

    group('initialize', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState in sign-up mode by default',
        build: buildCubit,
        act: (cubit) => cubit.initialize(),
        expect: () => [const DivineAuthFormState()],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState in sign-in mode when isSignIn is true',
        build: buildCubit,
        act: (cubit) => cubit.initialize(isSignIn: true),
        expect: () => [const DivineAuthFormState(isSignIn: true)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState with initial email when provided',
        build: buildCubit,
        act: (cubit) =>
            cubit.initialize(initialEmail: testEmail, isSignIn: true),
        expect: () => [
          const DivineAuthFormState(email: testEmail, isSignIn: true),
        ],
      );
    });

    group('updateEmail', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'updates email and clears email and general errors',
        build: buildCubit,
        seed: () => const DivineAuthFormState(
          emailError: 'old error',
          generalError: 'old general error',
        ),
        act: (cubit) => cubit.updateEmail(testEmail),
        expect: () => [const DivineAuthFormState(email: testEmail)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.updateEmail(testEmail),
        expect: () => <DivineAuthState>[],
      );
    });

    group('updatePassword', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'updates password and clears password and general errors',
        build: buildCubit,
        seed: () => const DivineAuthFormState(
          passwordError: 'old error',
          generalError: 'old general error',
        ),
        act: (cubit) => cubit.updatePassword(testPassword),
        expect: () => [const DivineAuthFormState(password: testPassword)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.updatePassword(testPassword),
        expect: () => <DivineAuthState>[],
      );
    });

    group('togglePasswordVisibility', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'toggles obscurePassword from true to false',
        build: buildCubit,
        seed: () => const DivineAuthFormState(),
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => [const DivineAuthFormState(obscurePassword: false)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'toggles obscurePassword from false to true',
        build: buildCubit,
        seed: () => const DivineAuthFormState(obscurePassword: false),
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => [const DivineAuthFormState()],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => <DivineAuthState>[],
      );
    });

    group('updateMarketingConsent', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'sets marketingConsent when the user opts in',
        build: buildCubit,
        seed: () => const DivineAuthFormState(),
        act: (cubit) => cubit.updateMarketingConsent(true),
        expect: () => [const DivineAuthFormState(marketingConsent: true)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.updateMarketingConsent(true),
        expect: () => <DivineAuthState>[],
      );
    });

    group('submit', () {
      group('validation', () {
        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits email error when email is empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(password: testPassword),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.emailError,
              'emailError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits email error when email is invalid',
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: 'not-an-email',
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.emailError,
              'emailError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits password error when password is empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(email: testEmail),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.passwordError,
              'passwordError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits password error when password is too short',
          build: buildCubit,
          seed: () =>
              const DivineAuthFormState(email: testEmail, password: 'short'),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.passwordError,
              'passwordError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits both errors when email and password are empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>()
                .having((s) => s.emailError, 'emailError', isNotNull)
                .having((s) => s.passwordError, 'passwordError', isNotNull),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'does nothing when state is not $DivineAuthFormState',
          build: buildCubit,
          act: (cubit) => cubit.submit(),
          expect: () => <DivineAuthState>[],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'does nothing when already submitting',
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSubmitting: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => <DivineAuthState>[],
        );
      });

      group('sign in', () {
        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits submitting then $DivineAuthSuccess on successful sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            isA<DivineAuthSuccess>(),
          ],
          verify: (_) {
            verify(
              () => mockOAuth.headlessLogin(
                email: testEmail,
                password: testPassword,
                scope: 'policy:full',
              ),
            ).called(1);
            verify(
              () => mockOAuth.exchangeCode(
                code: testCode,
                verifier: testVerifier,
              ),
            ).called(1);
            verify(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).called(1);
            verifyNever(() => mockAuthService.clearPendingDivineOAuthSession());
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'normalizes email before sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: ' Test@Example.com ',
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          verify: (_) {
            verify(
              () => mockOAuth.headlessLogin(
                email: testEmail,
                password: testPassword,
                scope: 'policy:full',
              ),
            ).called(1);
          },
        );

        test(
          'closing mid-sign-in reports no error to the bloc observer',
          () async {
            // Same close-mid-flight race as skipWithAnonymousAccount: the
            // sign-in flips AuthService to `authenticated` before returning,
            // which reroutes off the auth screen and closes this cubit while
            // the await is still in flight.
            //
            // Assert via the observer, not on completion: emit-after-close is
            // swallowed by the generic catch, so `completes` alone stays green
            // even with the guard removed.
            final signedIn = Completer<void>();
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).thenAnswer((_) => signedIn.future);

            final observed = <Object>[];
            final previousObserver = Bloc.observer;
            Bloc.observer = _RecordingBlocObserver(observed);
            addTearDown(() => Bloc.observer = previousObserver);

            final cubit = buildCubit()
              ..initialize(isSignIn: true)
              ..updateEmail(testEmail)
              ..updatePassword(testPassword);

            final submit = cubit.submit();
            await cubit.close();
            signedIn.complete();

            await expectLater(submit, completes);
            expect(observed, isEmpty);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'consumes invite with exchanged session before completing sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockInviteApiClient.consumeInviteWithSession(
                code: any(named: 'code'),
                oauthConfig: any(named: 'oauthConfig'),
                session: any(named: 'session'),
              ),
            ).thenAnswer(
              (_) async => const InviteConsumeResult(
                message: 'Welcome',
                codesAllocated: 5,
              ),
            );
            when(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).thenAnswer((_) async {});
          },
          build: () => buildCubit(inviteCode: 'ab12ef34'),
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            isA<DivineAuthSuccess>(),
          ],
          verify: (_) {
            verifyInOrder([
              () => mockOAuth.exchangeCode(
                code: testCode,
                verifier: testVerifier,
              ),
              () => mockInviteApiClient.consumeInviteWithSession(
                code: 'AB12-EF34',
                oauthConfig: any(named: 'oauthConfig'),
                session: any(named: 'session'),
              ),
              () => mockAuthService.signInWithDivineOAuth(any()),
            ]);
            expect(analytics.properties, [
              (name: AnalyticsUserProperty.inviteCode, value: 'AB12-EF34'),
            ]);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits invite recovery error when invite activation fails during sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockInviteApiClient.consumeInviteWithSession(
                code: any(named: 'code'),
                oauthConfig: any(named: 'oauthConfig'),
                session: any(named: 'session'),
              ),
            ).thenThrow(
              const InviteApiException(
                'Invite already been used',
                statusCode: 409,
              ),
            );
          },
          build: () => buildCubit(inviteCode: 'ab12ef34'),
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError:
                  'That invite code is no longer available. '
                  'Go back to your invite code, join the waitlist, or contact support.',
              showInviteGateRecovery: true,
              inviteRecoveryCode: 'AB12-EF34',
            ),
          ],
          errors: () => [isA<InviteApiException>()],
          verify: (_) {
            verify(
              () => mockAuthService.clearPendingDivineOAuthSession(),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'redacts sensitive invite activation causes during sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockInviteApiClient.consumeInviteWithSession(
                code: any(named: 'code'),
                oauthConfig: any(named: 'oauthConfig'),
                session: any(named: 'session'),
              ),
            ).thenThrow(
              const InviteApiException(
                'Failed to authenticate invite request: signer leaked '
                'nsec1qwertyuiopasdfghjklzxcvbnm0123456789abcdef',
                code: InviteApiErrorCode.clientAuthFailed,
                cause: FormatException(
                  'relay refused npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefg',
                ),
              ),
            );
          },
          build: () => buildCubit(inviteCode: 'ab12ef34'),
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            isA<DivineAuthFormState>(),
          ],
          errors: () => [isA<InviteApiException>()],
          verify: (_) {
            final logMessage = LogCaptureService()
                .getRecentLogs()
                .map((entry) => entry.message)
                .lastWhere(
                  (message) => message.startsWith('Invite activation failed:'),
                );

            expect(logMessage, contains('nsec1<redacted>'));
            expect(logMessage, contains('npub1<redacted>'));
            expect(logMessage, isNot(contains('nsec1qwerty')));
            expect(logMessage, isNot(contains('npub1abc')));
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits invalidCredentials reason on a keycast 401 '
          '(INVALID_CREDENTIALS), no error string in state',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(
                  success: false,
                  errorCode: 'INVALID_CREDENTIALS',
                  errorDescription: 'Invalid email or password',
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              signInFailureReason: SignInFailureReason.invalidCredentials,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits emailNotVerified reason on a keycast 403',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(
                  success: false,
                  errorCode: 'EMAIL_NOT_VERIFIED',
                  errorDescription:
                      'Please verify your email address before signing in',
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              signInFailureReason: SignInFailureReason.emailNotVerified,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits network reason and logs description on transport failure',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult.error(
                  'Network error: ClientException: XMLHttpRequest error.',
                  code: 'network_error',
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              signInFailureReason: SignInFailureReason.network,
            ),
          ],
          verify: (_) {
            final logMessage = LogCaptureService()
                .getRecentLogs()
                .map((entry) => entry.message)
                .lastWhere((message) => message.startsWith('Sign in failed:'));

            expect(logMessage, contains('code=network_error'));
            expect(logMessage, contains('reason=SignInFailureReason.network'));
            expect(
              logMessage,
              contains('ClientException: XMLHttpRequest error.'),
            );
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits unknown reason when login returns success but no code',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (HeadlessLoginResult(success: true), testVerifier),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              signInFailureReason: SignInFailureReason.unknown,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when code exchange throws $OAuthException',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenThrow(OAuthException('Token exchange failed'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Token exchange failed',
            ),
          ],
          errors: () => [isA<OAuthException>()],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits generic error when code exchange throws unexpected exception',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenThrow(Exception('network timeout'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Failed to complete authentication',
            ),
          ],
          errors: () => [isA<Exception>()],
        );
      });

      group('sign up', () {
        // Duplicate registrations are not cosmetic: each one mints a separate
        // pending row with its own token, so the first email's link dies and
        // the second registration's pubkey becomes the account. Measured in
        // prod on 2026-08-10 (two registers 2.9s apart for one signup).
        test(
          'a second submit while the first is in flight is dropped',
          () async {
            final registered = Completer<(HeadlessRegisterResult, String)>();
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer((_) => registered.future);
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});

            final cubit = buildCubit()
              ..initialize()
              ..updateEmail(testEmail)
              ..updatePassword(testPassword);

            final first = cubit.submit();
            // No await between the two: this is the same-frame double tap.
            final second = cubit.submit();

            registered.complete((
              HeadlessRegisterResult(
                success: true,
                pubkey: 'test-pubkey',
                verificationRequired: true,
                deviceCode: testDeviceCode,
                email: testEmail,
              ),
              testVerifier,
            ));
            await Future.wait([first, second]);

            verify(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).called(1);

            await cubit.close();
          },
        );

        test(
          'forwards marketingConsent to headlessRegister when opted in',
          () async {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
                marketingConsent: any(named: 'marketingConsent'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: true,
                  deviceCode: testDeviceCode,
                  email: testEmail,
                ),
                testVerifier,
              ),
            );
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});

            final cubit = buildCubit()
              ..initialize()
              ..updateEmail(testEmail)
              ..updatePassword(testPassword)
              ..updateMarketingConsent(true);

            await cubit.submit();

            verify(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
                marketingConsent: true,
              ),
            ).called(1);

            await cubit.close();
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits $DivineAuthEmailVerification when verification is required',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: true,
                  deviceCode: testDeviceCode,
                  email: testEmail,
                ),
                testVerifier,
              ),
            );
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            const DivineAuthEmailVerification(
              email: testEmail,
              deviceCode: testDeviceCode,
              verifier: testVerifier,
            ),
          ],
          verify: (_) {
            verify(
              () => mockPendingVerification.save(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
                inviteCode: any(named: 'inviteCode'),
              ),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'normalizes email before sign up and pending verification',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: true,
                  deviceCode: testDeviceCode,
                  email: testEmail,
                ),
                testVerifier,
              ),
            );
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: ' Test@Example.com ',
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          verify: (_) {
            verify(
              () => mockOAuth.headlessRegister(
                email: testEmail,
                password: testPassword,
                scope: 'policy:full',
              ),
            ).called(1);
            verify(
              () => mockPendingVerification.save(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
                inviteCode: any(named: 'inviteCode'),
              ),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'persists invite code with pending verification data',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: true,
                  deviceCode: testDeviceCode,
                  email: testEmail,
                ),
                testVerifier,
              ),
            );
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});
          },
          build: () => buildCubit(inviteCode: 'ab12ef34'),
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          verify: (_) {
            verify(
              () => mockPendingVerification.save(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
                inviteCode: 'AB12-EF34',
              ),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general message when registration succeeds '
          'without verification required',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: false,
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              generalError: 'Registration complete. Please check your email.',
            ),
          ],
        );

        group('registration error codes', () {
          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps email_exists error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error('Email taken', code: 'CONFLICT'),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>()
                  .having(
                    (s) => s.generalError,
                    'generalError',
                    contains('already registered'),
                  )
                  .having(
                    (s) => s.showLoginOptionsRecovery,
                    'showLoginOptionsRecovery',
                    isTrue,
                  ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps invalid_email error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Bad email',
                    code: 'invalid_email',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('valid email'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps weak_password error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error('Weak', code: 'weak_password'),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('too weak'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps rate_limited error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Slow down',
                    code: 'rate_limited',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Too many attempts'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps server_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Internal error',
                    code: 'server_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Server error'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps connection_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'No network',
                    code: 'connection_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('check your internet'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps network_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'No network',
                    code: 'network_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('check your internet'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'falls back to server description for unknown error codes',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult(
                    success: false,
                    pubkey: '',
                    verificationRequired: false,
                    errorCode: 'unknown_code_xyz',
                    errorDescription: 'A server-provided description',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                generalError: 'A server-provided description',
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'falls back to generic message when error code and '
            'description are null',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult(
                    success: false,
                    pubkey: '',
                    verificationRequired: false,
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Registration failed'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'uses generic fallback for registration_failed error code',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Failed',
                    code: 'registration_failed',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                generalError: 'Failed',
              ),
            ],
          );
        });

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when headlessRegister throws',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenThrow(Exception('network failure'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            isA<DivineAuthFormState>().having(
              (s) => s.generalError,
              'generalError',
              contains('unexpected error'),
            ),
          ],
          errors: () => [isA<Exception>()],
        );

        test(
          'closing mid-sign-up reports no error to the bloc observer',
          () async {
            // The sign-up path emits DivineAuthEmailVerification after two
            // awaits. Leaving the screen while headlessRegister is in flight
            // closes the cubit, so that emit throws — and submit()'s own
            // recovery emit then throws again with nothing left to catch it.
            final registered = Completer<(HeadlessRegisterResult, String)>();
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer((_) => registered.future);
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
                inviteCode: any(named: 'inviteCode'),
              ),
            ).thenAnswer((_) async {});

            final observed = <Object>[];
            final previousObserver = Bloc.observer;
            Bloc.observer = _RecordingBlocObserver(observed);
            addTearDown(() => Bloc.observer = previousObserver);

            final cubit = buildCubit()
              ..initialize()
              ..updateEmail(testEmail)
              ..updatePassword(testPassword);

            final submit = cubit.submit();
            await cubit.close();
            registered.complete((
              HeadlessRegisterResult(
                success: true,
                pubkey: 'test-pubkey',
                verificationRequired: true,
                deviceCode: testDeviceCode,
                email: testEmail,
              ),
              testVerifier,
            ));

            await expectLater(submit, completes);
            expect(observed, isEmpty);
          },
        );
      });
    });

    group('sendPasswordResetEmail', () {
      test('returns true when the OAuth client accepts the request', () async {
        final expected = ForgotPasswordResult(success: true);
        when(
          () => mockOAuth.sendPasswordResetEmail(any()),
        ).thenAnswer((_) async => expected);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        final result = await cubit.sendPasswordResetEmail(testEmail);

        expect(result, isTrue);
        verify(() => mockOAuth.sendPasswordResetEmail(testEmail)).called(1);
      });

      test('returns false when the OAuth client rejects the request', () async {
        final expected = ForgotPasswordResult(
          success: false,
          error: 'Not found',
        );
        when(
          () => mockOAuth.sendPasswordResetEmail(any()),
        ).thenAnswer((_) async => expected);

        final cubit = buildCubit();
        addTearDown(cubit.close);
        final result = await cubit.sendPasswordResetEmail(testEmail);

        expect(result, isFalse);
      });

      blocTest<DivineAuthCubit, DivineAuthState>(
        'normalizes email before password reset',
        setUp: () {
          when(
            () => mockOAuth.sendPasswordResetEmail(any()),
          ).thenAnswer((_) async => ForgotPasswordResult(success: true));
        },
        build: buildCubit,
        act: (cubit) => cubit.sendPasswordResetEmail(' Test@Example.com '),
        expect: () => <DivineAuthState>[],
        verify: (_) {
          verify(() => mockOAuth.sendPasswordResetEmail(testEmail)).called(1);
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'handles failed password reset without emitting error state',
        setUp: () {
          when(() => mockOAuth.sendPasswordResetEmail(any())).thenAnswer(
            (_) async =>
                ForgotPasswordResult(success: false, error: 'Not found'),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.sendPasswordResetEmail(testEmail),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'returns failure and reports exceptions without emitting state',
        setUp: () {
          when(
            () => mockOAuth.sendPasswordResetEmail(any()),
          ).thenThrow(Exception('network error'));
        },
        build: buildCubit,
        act: (cubit) async {
          final result = await cubit.sendPasswordResetEmail(testEmail);
          expect(result, isFalse);
        },
        expect: () => <DivineAuthState>[],
        errors: () => [isA<Exception>()],
      );
    });

    group('skipWithAnonymousAccount', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits isSkipping then $DivineAuthSuccess on success',
        setUp: () {
          when(
            () => mockAuthService.createAnonymousAccount(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          isA<DivineAuthSuccess>(),
        ],
        verify: (_) {
          verify(() => mockAuthService.createAnonymousAccount()).called(1);
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'consumes invite before creating anonymous account when invite code exists',
        setUp: () {
          when(
            () => mockInviteApiClient.consumeInviteWithKeyContainer(
              code: any(named: 'code'),
              keyContainer: any(named: 'keyContainer'),
            ),
          ).thenAnswer(
            (_) async => const InviteConsumeResult(
              message: 'Welcome',
              codesAllocated: 5,
            ),
          );
          when(
            () => mockAuthService.createAnonymousAccountFromKeyContainer(any()),
          ).thenAnswer((_) async {});
        },
        build: () => buildCubit(inviteCode: 'ab12ef34'),
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          isA<DivineAuthSuccess>(),
        ],
        verify: (_) {
          verifyNever(() => mockAuthService.createAnonymousAccount());
          verifyInOrder([
            () => mockInviteApiClient.consumeInviteWithKeyContainer(
              code: 'AB12-EF34',
              keyContainer: any(named: 'keyContainer'),
            ),
            () => mockAuthService.createAnonymousAccountFromKeyContainer(any()),
          ]);
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits invite recovery error when anonymous invite activation fails',
        setUp: () {
          when(
            () => mockInviteApiClient.consumeInviteWithKeyContainer(
              code: any(named: 'code'),
              keyContainer: any(named: 'keyContainer'),
            ),
          ).thenThrow(
            const InviteApiException('Invite revoked', statusCode: 403),
          );
        },
        build: () => buildCubit(inviteCode: 'ab12ef34'),
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            generalError:
                'That invite code cannot be used right now. '
                'Go back to your invite code, join the waitlist, or contact support.',
            showInviteGateRecovery: true,
            inviteRecoveryCode: 'AB12-EF34',
          ),
        ],
        errors: () => [isA<InviteApiException>()],
        verify: (_) {
          verifyNever(() => mockAuthService.createAnonymousAccount());
          verifyNever(
            () => mockAuthService.createAnonymousAccountFromKeyContainer(any()),
          );
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits isSkipping then generalError on failure',
        setUp: () {
          when(
            () => mockAuthService.createAnonymousAccount(),
          ).thenThrow(Exception('identity creation failed'));
        },
        build: buildCubit,
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          isA<DivineAuthFormState>()
              .having((s) => s.isSkipping, 'isSkipping', isFalse)
              .having((s) => s.generalError, 'generalError', isNotNull),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when already skipping',
        build: buildCubit,
        seed: () => const DivineAuthFormState(isSkipping: true),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when already submitting',
        build: buildCubit,
        seed: () => const DivineAuthFormState(isSubmitting: true),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );

      test(
        'closing mid-creation reports no error to the bloc observer',
        () async {
          // Account creation flips AuthService to `authenticated` before it
          // returns. The router then leaves the create-account screen, which
          // closes this cubit while the await is still in flight.
          final accountCreated = Completer<void>();
          when(
            () => mockAuthService.createAnonymousAccount(),
          ).thenAnswer((_) => accountCreated.future);

          final observed = <Object>[];
          final previousObserver = Bloc.observer;
          Bloc.observer = _RecordingBlocObserver(observed);
          addTearDown(() => Bloc.observer = previousObserver);

          final cubit = buildCubit();
          cubit.initialize();

          final skip = cubit.skipWithAnonymousAccount();
          await cubit.close();
          accountCreated.complete();
          await skip;

          expect(observed, isEmpty);
        },
      );
    });

    group('returnToForm', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'returns to form with email preserved from '
        '$DivineAuthEmailVerification state',
        build: buildCubit,
        seed: () => const DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        ),
        act: (cubit) => cubit.returnToForm(),
        expect: () => [const DivineAuthFormState(email: testEmail)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'returns to default form state from non-verification state',
        build: buildCubit,
        seed: () => const DivineAuthSuccess(),
        act: (cubit) => cubit.returnToForm(),
        expect: () => [const DivineAuthFormState()],
      );
    });

    group('$DivineAuthFormState', () {
      test('canSubmit returns true when form is valid and not submitting', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
        );
        expect(state.canSubmit, isTrue);
      });

      test('canSubmit returns false when email is empty', () {
        const state = DivineAuthFormState(password: testPassword);
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when password is empty', () {
        const state = DivineAuthFormState(email: testEmail);
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when there is an email error', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          emailError: 'Invalid',
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when there is a password error', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          passwordError: 'Too short',
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when submitting', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSubmitting: true,
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when skipping', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSkipping: true,
        );
        expect(state.canSubmit, isFalse);
      });

      test('copyWith preserves values when no arguments provided', () {
        const original = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSignIn: true,
          emailError: 'err',
          passwordError: 'perr',
          generalError: 'gerr',
          showInviteGateRecovery: true,
          inviteRecoveryCode: 'AB12-EF34',
          obscurePassword: false,
          isSubmitting: true,
        );
        final copied = original.copyWith();
        expect(copied, equals(original));
      });

      test('copyWith clears errors when clear flags are set', () {
        const original = DivineAuthFormState(
          email: testEmail,
          emailError: 'err',
          passwordError: 'perr',
          generalError: 'gerr',
        );
        final cleared = original.copyWith(
          clearEmailError: true,
          clearPasswordError: true,
          clearGeneralError: true,
          clearInviteGateRecovery: true,
        );
        expect(cleared.emailError, isNull);
        expect(cleared.passwordError, isNull);
        expect(cleared.generalError, isNull);
        expect(cleared.showInviteGateRecovery, isFalse);
        expect(cleared.inviteRecoveryCode, isNull);
        expect(cleared.inviteRecoverySourceSlug, isNull);
      });

      test('props contains all fields', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSignIn: true,
          emailError: 'e',
          passwordError: 'p',
          generalError: 'g',
          signInFailureReason: SignInFailureReason.invalidCredentials,
          showInviteGateRecovery: true,
          inviteRecoveryCode: 'AB12-EF34',
          inviteRecoverySourceSlug: 'lele-pons',
          obscurePassword: false,
          isSubmitting: true,
          marketingConsent: true,
        );
        expect(state.props, hasLength(18));
      });
    });

    group('$DivineAuthEmailVerification', () {
      test('props contains all fields', () {
        const state = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        expect(state.props, equals([testEmail, testDeviceCode, testVerifier]));
      });

      test('two states with same values are equal', () {
        const a = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        const b = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        expect(a, equals(b));
      });
    });
  });
}
