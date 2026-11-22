// ABOUTME: Tests EmailConfirmationCubit: following the signed-in account,
// ABOUTME: keeping the last answer on unknown, and the resend lifecycle.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';

class _MockEmailConfirmationRepository extends Mock
    implements EmailConfirmationRepository {}

const _account =
    'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';
const _otherAccount =
    'b4d2f1c7e8e3a59f6d2c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d';
const _email = 'you@example.com';

void main() {
  group(EmailConfirmationCubit, () {
    late _MockEmailConfirmationRepository repository;

    setUp(() {
      repository = _MockEmailConfirmationRepository();
    });

    EmailConfirmationCubit buildCubit() =>
        EmailConfirmationCubit(repository: repository);

    group('loadFor', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'emits unconfirmed with the address for an unconfirmed account',
        setUp: () {
          when(
            () => repository.fetchStatus(),
          ).thenAnswer(
            (_) async => const EmailConfirmation.unconfirmed(_email),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        expect: () => const [
          EmailConfirmationState(account: _account),
          EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'stays unknown when the check cannot answer',
        setUp: () {
          when(
            () => repository.fetchStatus(),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        expect: () => const [EmailConfirmationState(account: _account)],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'forgets the previous account when signed out',
        build: buildCubit,
        seed: () => const EmailConfirmationState(
          account: _account,
          status: EmailConfirmationStatus.unconfirmed,
          email: _email,
        ),
        act: (cubit) => cubit.loadFor(null),
        expect: () => const [EmailConfirmationState()],
        verify: (_) => verifyNever(() => repository.fetchStatus()),
      );

      test('drops an answer that arrives after the account changed', () async {
        final first = Completer<EmailConfirmation>();
        var calls = 0;
        when(() => repository.fetchStatus()).thenAnswer((_) {
          calls++;
          return calls == 1
              ? first.future
              : Future.value(const EmailConfirmation.confirmed());
        });
        final cubit = buildCubit();

        final firstLoad = cubit.loadFor(_account);
        await cubit.loadFor(_otherAccount);
        first.complete(const EmailConfirmation.unconfirmed(_email));
        await firstLoad;

        expect(
          cubit.state,
          equals(
            const EmailConfirmationState(
              account: _otherAccount,
              status: EmailConfirmationStatus.confirmed,
            ),
          ),
        );
        await cubit.close();
      });
    });

    group('refresh', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'moves to confirmed once the link was clicked',
        setUp: () {
          when(
            () => repository.fetchStatus(),
          ).thenAnswer((_) async => const EmailConfirmation.confirmed());
        },
        build: buildCubit,
        seed: () => const EmailConfirmationState(
          account: _account,
          status: EmailConfirmationStatus.unconfirmed,
          email: _email,
        ),
        act: (cubit) => cubit.refresh(),
        expect: () => const [
          EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.confirmed,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'keeps the last answer when the check cannot answer',
        setUp: () {
          when(
            () => repository.fetchStatus(),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        seed: () => const EmailConfirmationState(
          account: _account,
          status: EmailConfirmationStatus.unconfirmed,
          email: _email,
        ),
        act: (cubit) => cubit.refresh(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verify(() => repository.fetchStatus()).called(1),
      );
    });

    group('resend', () {
      const unconfirmed = EmailConfirmationState(
        account: _account,
        status: EmailConfirmationStatus.unconfirmed,
        email: _email,
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'reports sent when Keycast accepts',
        setUp: () {
          when(() => repository.resend()).thenAnswer((_) async => true);
        },
        build: buildCubit,
        seed: () => unconfirmed,
        act: (cubit) => cubit.resend(),
        expect: () => [
          unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sending,
          ),
          unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sent,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'reports failed when Keycast declines',
        setUp: () {
          when(() => repository.resend()).thenAnswer((_) async => false);
        },
        build: buildCubit,
        seed: () => unconfirmed,
        act: (cubit) => cubit.resend(),
        expect: () => [
          unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sending,
          ),
          unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.failed,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'ignores a second tap while a resend is in flight',
        build: buildCubit,
        seed: () => unconfirmed.copyWith(
          resendStatus: EmailConfirmationResendStatus.sending,
        ),
        act: (cubit) => cubit.resend(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.resend()),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'does nothing with no signed-in account',
        build: buildCubit,
        act: (cubit) => cubit.resend(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.resend()),
      );
    });
  });
}
