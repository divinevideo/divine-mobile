// ABOUTME: Tests EmailConfirmationGate: DMs stay locked behind the confirmation
// ABOUTME: view until the email is confirmed, with a working resend button.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_confirmation/email_confirmation_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/email_confirmation/email_confirmation_gate.dart';

class _MockEmailConfirmationCubit extends MockCubit<EmailConfirmationState>
    implements EmailConfirmationCubit {}

const _account =
    'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';
const _email = 'you@example.com';

void main() {
  group(EmailConfirmationGate, () {
    late _MockEmailConfirmationCubit cubit;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      cubit = _MockEmailConfirmationCubit();
      when(
        () => cubit.resend(account: any(named: 'account')),
      ).thenAnswer((_) async {});
    });

    Widget buildSubject({bool withCubit = true, bool standalone = false}) {
      final gate = EmailConfirmationGate(
        standalone: standalone,
        child: const Text('conversations'),
      );
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: withCubit
              ? BlocProvider<EmailConfirmationCubit>.value(
                  value: cubit,
                  child: gate,
                )
              : gate,
        ),
      );
    }

    group('renders', () {
      testWidgets('the lock until the email is confirmed', (tester) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('conversations'), findsNothing);
        expect(find.text(l10n.emailConfirmationMessagesTitle), findsOneWidget);
        expect(
          find.text(l10n.emailConfirmationMessagesBody(_email)),
          findsOneWidget,
        );
      });

      testWidgets('the conversations once the email is confirmed', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.confirmed,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('conversations'), findsOneWidget);
        expect(find.text(l10n.emailConfirmationMessagesTitle), findsNothing);
      });

      testWidgets('gives instructions when the address is unknown', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
          ),
        );

        await tester.pumpWidget(buildSubject());

        expect(find.text('conversations'), findsNothing);
        expect(find.text(l10n.emailConfirmationCheckInbox), findsOneWidget);
        expect(find.text(l10n.emailConfirmationMessagesBody('')), findsNothing);
        expect(find.text(l10n.emailConfirmationResendButton), findsOneWidget);
      });

      testWidgets('the conversations while the status is unknown', (
        tester,
      ) async {
        when(
          () => cubit.state,
        ).thenReturn(const EmailConfirmationState(account: _account));

        await tester.pumpWidget(buildSubject());

        expect(find.text('conversations'), findsOneWidget);
      });

      testWidgets('the conversations when no cubit is provided', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(withCubit: false));

        expect(find.text('conversations'), findsOneWidget);
      });

      testWidgets('an app bar when it fills a whole route', (tester) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        );

        await tester.pumpWidget(buildSubject(standalone: true));

        expect(find.text(l10n.emailConfirmationTitle), findsOneWidget);
        expect(find.text(l10n.emailConfirmationMessagesTitle), findsOneWidget);
      });
    });

    group(r'$ensureEmailConfirmedToMessage', () {
      Widget buildSender(ValueChanged<bool> onResult) => MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<EmailConfirmationCubit>.value(
          value: cubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => DivineButton(
                label: 'send',
                onPressed: () =>
                    onResult(ensureEmailConfirmedToMessage(context)),
              ),
            ),
          ),
        ),
      );

      testWidgets('stops the send and says why while unconfirmed', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        );
        bool? allowed;

        await tester.pumpWidget(buildSender((value) => allowed = value));
        await tester.tap(find.text('send'));
        await tester.pump();

        expect(allowed, isFalse);
        expect(find.text(l10n.emailConfirmationSendBlocked), findsOneWidget);
      });

      testWidgets('lets a confirmed account send', (tester) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.confirmed,
            email: _email,
          ),
        );
        bool? allowed;

        await tester.pumpWidget(buildSender((value) => allowed = value));
        await tester.tap(find.text('send'));
        await tester.pump();

        expect(allowed, isTrue);
        expect(find.text(l10n.emailConfirmationSendBlocked), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('resends the confirmation link', (tester) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(find.text(l10n.emailConfirmationResendButton));
        await tester.pump();

        verify(() => cubit.resend()).called(1);
      });

      testWidgets('disables resend while a request is in flight', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          const EmailConfirmationState(
            account: _account,
            status: EmailConfirmationStatus.unconfirmed,
            email: _email,
            resendStatus: EmailConfirmationResendStatus.sending,
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.tap(
          find.text(l10n.emailConfirmationResendButton),
          warnIfMissed: false,
        );
        await tester.pump();

        verifyNever(() => cubit.resend(account: any(named: 'account')));
      });
    });
  });
}
