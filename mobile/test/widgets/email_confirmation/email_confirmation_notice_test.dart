// ABOUTME: Tests EmailConfirmationNotice: the confirm-your-email pop-up and the
// ABOUTME: resend outcome messages.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_notice.dart';

class _MockEmailConfirmationCubit extends MockCubit<EmailConfirmationState>
    implements EmailConfirmationCubit {}

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

void main() {
  group(EmailConfirmationNotice, () {
    late _MockEmailConfirmationCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockEmailConfirmationCubit();
      when(
        () => cubit.resend(account: any(named: 'account')),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject() => BlocProvider<EmailConfirmationCubit>.value(
      value: cubit,
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            EmailConfirmationNotice(child: child ?? const SizedBox()),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    testWidgets('reminds the account to confirm once it is known unconfirmed', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.fromIterable(const [_unconfirmed]),
        initialState: const EmailConfirmationState(account: _account),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.emailConfirmationNotice(_email)), findsOneWidget);
    });

    testWidgets('closes the reminder when another account signs in', (
      tester,
    ) async {
      final states = StreamController<EmailConfirmationState>();
      addTearDown(states.close);
      whenListen(
        cubit,
        states.stream,
        initialState: const EmailConfirmationState(account: _account),
      );

      await tester.pumpWidget(buildSubject());
      states.add(_unconfirmed);
      await tester.pumpAndSettle();
      expect(find.text(l10n.emailConfirmationNotice(_email)), findsOneWidget);

      states.add(const EmailConfirmationState(account: _otherAccount));
      await tester.pumpAndSettle();

      expect(find.text(l10n.emailConfirmationNotice(_email)), findsNothing);
    });

    testWidgets('resends only for the account the reminder names', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.fromIterable(const [_unconfirmed]),
        initialState: const EmailConfirmationState(account: _account),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.emailConfirmationResendButton));
      await tester.pump();

      verify(() => cubit.resend(account: _account)).called(1);
    });

    testWidgets('explains a refused post with a way to confirm', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.fromIterable([_unconfirmed.copyWith(capRefusals: 1)]),
        initialState: _unconfirmed,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.emailConfirmationCapReached), findsOneWidget);
      await tester.tap(find.text(l10n.emailConfirmationResendButton));
      await tester.pump();
      verify(() => cubit.resend(account: _account)).called(1);
    });

    testWidgets('stays quiet for a confirmed account', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable(const [
          EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.confirmed,
          ),
        ]),
        initialState: const EmailConfirmationState(account: _account),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.emailConfirmationNotice(_email)), findsNothing);
    });

    testWidgets('reports a sent link', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable([
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.sent,
          ),
        ]),
        initialState: _unconfirmed.copyWith(
          resendStatus: EmailConfirmationResendStatus.sending,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.emailConfirmationResendSent), findsOneWidget);
    });

    testWidgets('reports a failed resend', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable([
          _unconfirmed.copyWith(
            resendStatus: EmailConfirmationResendStatus.failed,
          ),
        ]),
        initialState: _unconfirmed.copyWith(
          resendStatus: EmailConfirmationResendStatus.sending,
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text(l10n.emailConfirmationResendFailed), findsOneWidget);
    });
  });
}
