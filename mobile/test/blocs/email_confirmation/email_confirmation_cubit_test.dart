// ABOUTME: Tests EmailConfirmationCubit: starting from the remembered answer,
// ABOUTME: forward-only confirmation, account scoping and the resend lifecycle.

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

const _unconfirmed = EmailConfirmationState(
  account: _account,
  status: EmailConfirmationStatus.unconfirmed,
  email: _email,
);
const _confirmed = EmailConfirmationState(
  account: _account,
  status: EmailConfirmationStatus.confirmed,
  email: _email,
);

void main() {
  setUpAll(() {
    registerFallbackValue(const EmailConfirmation.unknown());
  });

  group(EmailConfirmationCubit, () {
    late _MockEmailConfirmationRepository repository;

    setUp(() {
      repository = _MockEmailConfirmationRepository();
      when(
        () => repository.remembered(any()),
      ).thenReturn(const EmailConfirmation.unknown());
      when(() => repository.remember(any(), any())).thenAnswer((_) async {});
    });

    EmailConfirmationCubit buildCubit() =>
        EmailConfirmationCubit(repository: repository);

    group('loadFor', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'asks Keycast about the account it is pointed at',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        verify: (_) => verify(() => repository.fetchStatus(_account)).called(1),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'starts locked from the remembered answer before Keycast replies',
        setUp: () {
          when(
            () => repository.remembered(_account),
          ).thenReturn(const EmailConfirmation.unconfirmed(_email));
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        expect: () => const [_unconfirmed],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'emits and remembers what Keycast reports',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer(
            (_) async => const EmailConfirmation.unconfirmed(_email),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        expect: () => const [
          EmailConfirmationState(account: _account),
          _unconfirmed,
        ],
        verify: (_) => verify(
          () => repository.remember(
            _account,
            const EmailConfirmation.unconfirmed(_email),
          ),
        ).called(1),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'reports an account with no email',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.missing());
        },
        build: buildCubit,
        act: (cubit) => cubit.loadFor(_account),
        expect: () => const [
          EmailConfirmationState(account: _account),
          EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.noEmail,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'forgets the previous account when signed out',
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.loadFor(null),
        expect: () => const [EmailConfirmationState()],
        verify: (_) => verifyNever(() => repository.fetchStatus(any())),
      );

      test('drops an answer that arrives after the account changed', () async {
        final first = Completer<EmailConfirmation>();
        var calls = 0;
        when(() => repository.fetchStatus(any())).thenAnswer((_) {
          calls++;
          return calls == 1
              ? first.future
              : Future.value(const EmailConfirmation.confirmed('b@x.com'));
        });
        final cubit = buildCubit();

        final firstLoad = cubit.loadFor(_account);
        await cubit.loadFor(_otherAccount);
        first.complete(const EmailConfirmation.unconfirmed(_email));
        await firstLoad;

        expect(cubit.state.account, equals(_otherAccount));
        expect(cubit.state.status, equals(EmailConfirmationStatus.confirmed));
        verifyNever(
          () => repository.remember(
            _account,
            const EmailConfirmation.unconfirmed(_email),
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
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.confirmed(_email));
        },
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.refresh(),
        expect: () => const [_confirmed],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'never moves a confirmed address back to unconfirmed',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer(
            (_) async => const EmailConfirmation.unconfirmed(_email),
          );
        },
        build: buildCubit,
        seed: () => _confirmed,
        act: (cubit) => cubit.refresh(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.remember(any(), any())),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'locks again for a new, unconfirmed address',
        setUp: () {
          when(() => repository.fetchStatus(any())).thenAnswer(
            (_) async => const EmailConfirmation.unconfirmed('new@example.com'),
          );
        },
        build: buildCubit,
        seed: () => _confirmed,
        act: (cubit) => cubit.refresh(),
        expect: () => const [
          EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: 'new@example.com',
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'keeps the last answer when the check cannot answer',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.refresh(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verify(() => repository.fetchStatus(any())).called(1),
      );
    });

    group('markUnconfirmedByKeycast', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'locks again even if the app had the address as confirmed',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        seed: () => _confirmed,
        act: (cubit) => cubit.markUnconfirmedByKeycast(_account),
        expect: () => const [_unconfirmed],
        verify: (_) => verify(
          () => repository.remember(
            _account,
            const EmailConfirmation.unconfirmed(_email),
          ),
        ).called(1),
      );

      // A refusal can arrive after the account that triggered it was swapped
      // out. Acting on it would lock, and cache a verdict for, the account
      // that switched in.
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        "ignores a refusal of another account's signer",
        build: buildCubit,
        seed: () => _confirmed,
        act: (cubit) => cubit.markUnconfirmedByKeycast(_otherAccount),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) {
          verifyNever(() => repository.remember(any(), any()));
          verifyNever(() => repository.fetchStatus(any()));
        },
      );

      // A signer built from a session not yet bound to its account cannot
      // name it; its refusal still locks the signed-in account.
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'takes a refusal that names no account as the signed-in one',
        setUp: () {
          when(
            () => repository.fetchStatus(any()),
          ).thenAnswer((_) async => const EmailConfirmation.unknown());
        },
        build: buildCubit,
        seed: () => _confirmed,
        act: (cubit) => cubit.markUnconfirmedByKeycast(null),
        expect: () => const [_unconfirmed],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'does nothing with no signed-in account',
        build: buildCubit,
        act: (cubit) => cubit.markUnconfirmedByKeycast(_account),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.fetchStatus(any())),
      );
    });

    group('reportCapReached', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        "ignores a cap on another account's signer",
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.reportCapReached(_otherAccount),
        expect: () => const <EmailConfirmationState>[],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'counts each refusal so every one can be explained',
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit
          ..reportCapReached(_account)
          ..reportCapReached(_account),
        expect: () => [
          _unconfirmed.copyWith(capRefusals: 1),
          _unconfirmed.copyWith(capRefusals: 2),
        ],
      );
    });

    group('resend', () {
      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'requests the link for the account it is pointed at',
        setUp: () {
          when(() => repository.resend(any())).thenAnswer((_) async => true);
        },
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.resend(),
        verify: (_) => verify(() => repository.resend(_account)).called(1),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'reports sent when Keycast accepts',
        setUp: () {
          when(() => repository.resend(any())).thenAnswer((_) async => true);
        },
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.resend(),
        expect: () => [
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sending,
          ),
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sent,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'reports failed when Keycast declines',
        setUp: () {
          when(() => repository.resend(any())).thenAnswer((_) async => false);
        },
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.resend(),
        expect: () => [
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sending,
          ),
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.failed,
          ),
        ],
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'ignores a reminder left over from another account',
        build: buildCubit,
        seed: () => _unconfirmed,
        act: (cubit) => cubit.resend(account: _otherAccount),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.resend(any())),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'ignores a second tap while a resend is in flight',
        build: buildCubit,
        seed: () => _unconfirmed.copyWith(
          resendStatus: EmailConfirmationResendStatus.sending,
        ),
        act: (cubit) => cubit.resend(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.resend(any())),
      );

      blocTest<EmailConfirmationCubit, EmailConfirmationState>(
        'does nothing with no signed-in account',
        build: buildCubit,
        act: (cubit) => cubit.resend(),
        expect: () => const <EmailConfirmationState>[],
        verify: (_) => verifyNever(() => repository.resend(any())),
      );
    });
  });
}
