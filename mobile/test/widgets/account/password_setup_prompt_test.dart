// ABOUTME: Widget tests for PasswordSetupPromptView
// ABOUTME: Covers the explanation, the link request, and each outcome's copy

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/password_setup/password_setup_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/account/password_setup_prompt.dart';

class _MockPasswordSetupCubit extends MockCubit<PasswordSetupStatus>
    implements PasswordSetupCubit {}

void main() {
  group(PasswordSetupPromptView, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockPasswordSetupCubit cubit;

    setUp(() {
      cubit = _MockPasswordSetupCubit();
    });

    Future<void> pump(WidgetTester tester, PasswordSetupStatus status) async {
      when(() => cubit.state).thenReturn(status);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider<PasswordSetupCubit>.value(
              value: cubit,
              child: const PasswordSetupPromptView(),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('the explanation and the link button before a request', (
        tester,
      ) async {
        await pump(tester, PasswordSetupStatus.idle);

        expect(find.text(l10n.accountCredentialsPasswordNotSet), findsOne);
        expect(find.text(l10n.accountCredentialsPasswordSetupSend), findsOne);
      });

      testWidgets('the inbox hint instead of the button once sent', (
        tester,
      ) async {
        await pump(tester, PasswordSetupStatus.sent);

        expect(find.text(l10n.accountCredentialsPasswordSetupSent), findsOne);
        expect(
          find.text(l10n.accountCredentialsPasswordSetupSend),
          findsNothing,
        );
      });

      testWidgets('a retryable failure beside the button', (tester) async {
        await pump(tester, PasswordSetupStatus.failed);

        expect(find.text(l10n.accountCredentialsUnknown), findsOne);
        expect(find.text(l10n.accountCredentialsPasswordSetupSend), findsOne);
      });

      testWidgets('the sign-in hint when the session is gone', (tester) async {
        await pump(tester, PasswordSetupStatus.needsSignIn);

        expect(find.text(l10n.accountCredentialsNeedsSignIn), findsOne);
      });
    });

    group('interactions', () {
      testWidgets('tapping the button requests the link', (tester) async {
        when(() => cubit.requestLink()).thenAnswer((_) async {});
        await pump(tester, PasswordSetupStatus.idle);

        await tester.tap(find.text(l10n.accountCredentialsPasswordSetupSend));
        await tester.pump();

        verify(() => cubit.requestLink()).called(1);
      });

      testWidgets('the button does nothing while a request is running', (
        tester,
      ) async {
        when(() => cubit.requestLink()).thenAnswer((_) async {});
        await pump(tester, PasswordSetupStatus.sending);

        await tester.tap(find.byType(DivineButton), warnIfMissed: false);
        await tester.pump();

        verifyNever(() => cubit.requestLink());
      });
    });
  });
}
