// ABOUTME: Tests for SocialSignInCubit: which providers it offers, the
// ABOUTME: sign-in sequence, and how each failure reaches the UI.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/social_sign_in/social_sign_in_cubit.dart';
import 'package:openvine/repositories/social_sign_in_repository.dart';
import 'package:openvine/services/auth/account_activation_coordinator.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_identity_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

class _MockRepository extends Mock implements SocialSignInRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeKeycastSession extends Fake implements KeycastSession {}

void main() {
  group(SocialSignInCubit, () {
    late _MockRepository repository;
    late _MockAuthService authService;
    const session = KeycastSession(bunkerUrl: 'bunker://session');

    setUpAll(() {
      registerFallbackValue(_FakeKeycastSession());
      registerFallbackValue(SocialProvider.google);
    });

    setUp(() {
      repository = _MockRepository();
      authService = _MockAuthService();
      when(() => repository.isAvailable(any())).thenReturn(true);
      when(() => authService.acceptTerms()).thenAnswer((_) async {});
      when(
        () => repository.signIn(any()),
      ).thenAnswer((_) async => session);
      when(
        () => authService.signInWithDivineOAuth(any()),
      ).thenAnswer((_) async {});
      when(() => authService.isAuthenticated).thenReturn(true);
    });

    SocialSignInCubit buildCubit() => SocialSignInCubit(
      repository: repository,
      authService: authService,
    );

    const inProgressApple = SocialSignInState(
      availableProviders: [SocialProvider.apple, SocialProvider.google],
      status: SocialSignInStatus.inProgress,
      activeProvider: SocialProvider.apple,
    );

    SocialSignInState failedApple(SocialSignInFailureReason reason) =>
        SocialSignInState(
          availableProviders: const [
            SocialProvider.apple,
            SocialProvider.google,
          ],
          status: SocialSignInStatus.failed,
          activeProvider: SocialProvider.apple,
          failureReason: reason,
        );

    group('initial state', () {
      test('offers Apple before Google', () {
        expect(buildCubit().state.availableProviders, [
          SocialProvider.apple,
          SocialProvider.google,
        ]);
      });

      test('leaves out providers the device cannot use', () {
        when(
          () => repository.isAvailable(SocialProvider.apple),
        ).thenReturn(false);

        expect(buildCubit().state.availableProviders, [SocialProvider.google]);
      });
    });

    group('signIn', () {
      blocTest<SocialSignInCubit, SocialSignInState>(
        'accepts the terms, then signs in with the Keycast session',
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          inProgressApple.copyWith(status: SocialSignInStatus.signedIn),
        ],
        verify: (_) {
          verifyInOrder([
            () => authService.acceptTerms(),
            () => repository.signIn(SocialProvider.apple),
            () => authService.signInWithDivineOAuth(session),
          ]);
        },
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'goes back to idle when the person closes the sheet',
        setUp: () => when(() => repository.signIn(any())).thenThrow(
          const SocialIdentityException(
            SocialProvider.apple,
            SocialIdentityFailure.cancelled,
          ),
        ),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          inProgressApple.copyWith(status: SocialSignInStatus.idle),
        ],
        verify: (_) =>
            verifyNever(() => authService.signInWithDivineOAuth(any())),
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'reports a provider that cannot sign in here as unavailable',
        setUp: () => when(() => repository.signIn(any())).thenThrow(
          const SocialIdentityException(
            SocialProvider.apple,
            SocialIdentityFailure.unavailable,
          ),
        ),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          failedApple(SocialSignInFailureReason.unavailable),
        ],
      );

      for (final (failure, reason) in [
        (
          SocialLoginFailure.accountLinkRequired,
          SocialSignInFailureReason.accountLinkRequired,
        ),
        (
          SocialLoginFailure.emailMissing,
          SocialSignInFailureReason.emailMissing,
        ),
        (
          SocialLoginFailure.emailNotVerified,
          SocialSignInFailureReason.emailNotVerified,
        ),
        (
          SocialLoginFailure.providerUnavailable,
          SocialSignInFailureReason.unavailable,
        ),
        (SocialLoginFailure.rateLimited, SocialSignInFailureReason.rateLimited),
        (SocialLoginFailure.network, SocialSignInFailureReason.network),
        (SocialLoginFailure.invalidToken, SocialSignInFailureReason.failed),
      ]) {
        blocTest<SocialSignInCubit, SocialSignInState>(
          'reports Keycast refusing with $failure as $reason',
          setUp: () => when(
            () => repository.signIn(any()),
          ).thenThrow(SocialSignInException(failure)),
          build: buildCubit,
          act: (cubit) => cubit.signIn(SocialProvider.apple),
          expect: () => [inProgressApple, failedApple(reason)],
        );
      }

      blocTest<SocialSignInCubit, SocialSignInState>(
        'fails when the app sign-in did not authenticate',
        setUp: () => when(() => authService.isAuthenticated).thenReturn(false),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          failedApple(SocialSignInFailureReason.failed),
        ],
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'reports leftover data of the previous account',
        setUp: () => when(
          () => authService.signInWithDivineOAuth(any()),
        ).thenThrow(const UserDataCleanupException('wipe failed')),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          failedApple(SocialSignInFailureReason.accountCleanupFailed),
        ],
        errors: () => [isA<UserDataCleanupException>()],
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'stays quiet when a newer sign-in took over',
        setUp: () => when(
          () => authService.signInWithDivineOAuth(any()),
        ).thenThrow(const AccountActivationRetiredException()),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => [
          inProgressApple,
          inProgressApple.copyWith(status: SocialSignInStatus.idle),
        ],
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'ignores a second tap while a sign-in runs',
        build: buildCubit,
        act: (cubit) async {
          final first = cubit.signIn(SocialProvider.apple);
          await cubit.signIn(SocialProvider.google);
          await first;
        },
        verify: (_) {
          verify(() => repository.signIn(SocialProvider.apple)).called(1);
          verifyNever(() => repository.signIn(SocialProvider.google));
        },
      );

      blocTest<SocialSignInCubit, SocialSignInState>(
        'ignores a provider it does not offer',
        setUp: () => when(
          () => repository.isAvailable(SocialProvider.apple),
        ).thenReturn(false),
        build: buildCubit,
        act: (cubit) => cubit.signIn(SocialProvider.apple),
        expect: () => <SocialSignInState>[],
        verify: (_) => verifyNever(() => authService.acceptTerms()),
      );
    });
  });
}
