// ABOUTME: Tests for ChangeEmailCubit
// ABOUTME: Covers loading the current address, validation, and refusal mapping

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/change_email/change_email_cubit.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

class _MockAccountCredentialsRepository extends Mock
    implements AccountCredentialsRepository {}

void main() {
  group(ChangeEmailCubit, () {
    late _MockAccountCredentialsRepository repository;

    setUp(() {
      repository = _MockAccountCredentialsRepository();
      when(() => repository.fetchAccountStatus()).thenAnswer((_) async => null);
    });

    ChangeEmailCubit buildSubject() => ChangeEmailCubit(repository: repository);

    void stubAccount(String email) {
      when(() => repository.fetchAccountStatus()).thenAnswer(
        (_) async => KeycastAccountStatus(
          email: email,
          emailVerified: true,
          publicKey: 'abc',
          verifiedMinor: false,
        ),
      );
    }

    void stubResult(ChangeEmailResult result) {
      when(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => result);
    }

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'waits for the current-address load before accepting a no-op change',
      build: buildSubject,
      setUp: () {
        when(() => repository.fetchAccountStatus()).thenAnswer(
          (_) => Future<KeycastAccountStatus>.microtask(
            () => const KeycastAccountStatus(
              email: 'old@example.com',
              emailVerified: true,
              publicKey: 'abc',
              verifiedMinor: false,
            ),
          ),
        );
      },
      act: (cubit) async {
        final load = cubit.loadCurrentEmail();
        cubit
          ..updateNewEmail('OLD@example.com')
          ..updatePassword('hunter2');
        await cubit.submit();
        await load;
      },
      skip: 3,
      expect: () => [
        isA<ChangeEmailState>()
            .having((s) => s.currentEmail, 'currentEmail', 'old@example.com')
            .having(
              (s) => s.newEmailError,
              'newEmailError',
              NewEmailFieldError.sameAsCurrent,
            ),
      ],
      verify: (_) => verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      ),
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'shows the address Keycast has on file',
      build: buildSubject,
      setUp: () => stubAccount('old@example.com'),
      act: (cubit) => cubit.loadCurrentEmail(),
      expect: () => [
        isA<ChangeEmailState>().having(
          (s) => s.currentEmail,
          'currentEmail',
          'old@example.com',
        ),
      ],
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'stays quiet when the current address cannot be read',
      build: buildSubject,
      act: (cubit) => cubit.loadCurrentEmail(),
      expect: () => <ChangeEmailState>[],
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'rejects a malformed address before sending anything',
      build: buildSubject,
      act: (cubit) async {
        cubit
          ..updateNewEmail('not-an-email')
          ..updatePassword('hunter2');
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        isA<ChangeEmailState>().having(
          (s) => s.newEmailError,
          'newEmailError',
          NewEmailFieldError.invalid,
        ),
      ],
      verify: (_) => verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      ),
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'catches a no-op change that Keycast would accept silently',
      build: buildSubject,
      setUp: () => stubAccount('old@example.com'),
      act: (cubit) async {
        await cubit.loadCurrentEmail();
        cubit
          ..updateNewEmail('  OLD@example.com ')
          ..updatePassword('hunter2');
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<ChangeEmailState>().having(
          (s) => s.newEmailError,
          'newEmailError',
          NewEmailFieldError.sameAsCurrent,
        ),
      ],
      verify: (_) => verifyNever(
        () => repository.changeEmail(
          newEmail: any(named: 'newEmail'),
          password: any(named: 'password'),
        ),
      ),
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'sends the trimmed address and reports the request as sent',
      build: buildSubject,
      setUp: () => stubResult(ChangeEmailResult.success()),
      act: (cubit) async {
        cubit
          ..updateNewEmail(' new@example.com ')
          ..updatePassword('hunter2');
        await cubit.submit();
      },
      skip: 2,
      expect: () => [
        isA<ChangeEmailState>().having(
          (s) => s.status,
          'status',
          ChangeEmailStatus.submitting,
        ),
        isA<ChangeEmailState>().having(
          (s) => s.status,
          'status',
          ChangeEmailStatus.requestSent,
        ),
      ],
      verify: (_) => verify(
        () => repository.changeEmail(
          newEmail: 'new@example.com',
          password: 'hunter2',
        ),
      ).called(1),
    );

    blocTest<ChangeEmailCubit, ChangeEmailState>(
      'surfaces a rejected password as a recoverable reason',
      build: buildSubject,
      setUp: () => stubResult(
        ChangeEmailResult.failure(ChangeEmailFailure.wrongPassword),
      ),
      act: (cubit) async {
        cubit
          ..updateNewEmail('new@example.com')
          ..updatePassword('wrong');
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<ChangeEmailState>()
            .having((s) => s.status, 'status', ChangeEmailStatus.failure)
            .having(
              (s) => s.failureReason,
              'failureReason',
              ChangeEmailFailureReason.wrongPassword,
            ),
      ],
    );

    test('never stringifies the password it is holding', () {
      const state = ChangeEmailState(
        newEmail: 'new@example.com',
        password: 'secret-value',
      );

      // Equatable stringifies props by default in debug builds, and anything
      // that prints a state — DivineBlocObserver's `bloc.lastState` crash key
      // above all — would carry the plaintext with it.
      expect(state.toString(), isNot(contains('secret-value')));
    });
  });
}
