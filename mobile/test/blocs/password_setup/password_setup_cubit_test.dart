// ABOUTME: Tests for PasswordSetupCubit
// ABOUTME: Covers the request outcomes and that a second tap sends no second email

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/password_setup/password_setup_cubit.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

class _MockAccountCredentialsRepository extends Mock
    implements AccountCredentialsRepository {}

void main() {
  group(PasswordSetupCubit, () {
    late _MockAccountCredentialsRepository repository;

    setUp(() {
      repository = _MockAccountCredentialsRepository();
    });

    PasswordSetupCubit buildSubject() =>
        PasswordSetupCubit(repository: repository);

    void stubResult(PasswordSetupRequestResult result) {
      when(
        () => repository.requestPasswordSetup(),
      ).thenAnswer((_) async => result);
    }

    group('requestLink', () {
      blocTest<PasswordSetupCubit, PasswordSetupStatus>(
        'reports the link as sent once Keycast accepts the request',
        setUp: () => stubResult(PasswordSetupRequestResult.requested),
        build: buildSubject,
        act: (cubit) => cubit.requestLink(),
        expect: () => const [
          PasswordSetupStatus.sending,
          PasswordSetupStatus.sent,
        ],
      );

      blocTest<PasswordSetupCubit, PasswordSetupStatus>(
        'asks to sign in again when the session is gone',
        setUp: () => stubResult(PasswordSetupRequestResult.needsSignIn),
        build: buildSubject,
        act: (cubit) => cubit.requestLink(),
        expect: () => const [
          PasswordSetupStatus.sending,
          PasswordSetupStatus.needsSignIn,
        ],
      );

      blocTest<PasswordSetupCubit, PasswordSetupStatus>(
        'reports a failure the person can retry',
        setUp: () => stubResult(PasswordSetupRequestResult.failed),
        build: buildSubject,
        act: (cubit) => cubit.requestLink(),
        expect: () => const [
          PasswordSetupStatus.sending,
          PasswordSetupStatus.failed,
        ],
      );

      blocTest<PasswordSetupCubit, PasswordSetupStatus>(
        'sends no second request once the link was sent',
        setUp: () => stubResult(PasswordSetupRequestResult.requested),
        build: buildSubject,
        seed: () => PasswordSetupStatus.sent,
        act: (cubit) => cubit.requestLink(),
        expect: () => const <PasswordSetupStatus>[],
        verify: (_) => verifyNever(() => repository.requestPasswordSetup()),
      );

      blocTest<PasswordSetupCubit, PasswordSetupStatus>(
        'retries after a failure',
        setUp: () => stubResult(PasswordSetupRequestResult.requested),
        build: buildSubject,
        seed: () => PasswordSetupStatus.failed,
        act: (cubit) => cubit.requestLink(),
        expect: () => const [
          PasswordSetupStatus.sending,
          PasswordSetupStatus.sent,
        ],
      );
    });
  });
}
