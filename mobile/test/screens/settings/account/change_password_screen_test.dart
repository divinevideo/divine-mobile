// ABOUTME: Widget tests for ChangePasswordView
// ABOUTME: Covers validation, the refusal copy, and the success handoff

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/change_password/change_password_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';
import 'package:openvine/screens/settings/account/change_password_screen.dart';

class _MockAccountCredentialsRepository extends Mock
    implements AccountCredentialsRepository {}

/// Collects what the screen hands to screen readers.
List<Object?> _captureAnnouncements(WidgetTester tester) {
  final announced = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        announced.add((message['data'] as Map?)?['message']);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

void main() {
  group(ChangePasswordView, () {
    late _MockAccountCredentialsRepository repository;
    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      repository = _MockAccountCredentialsRepository();
    });

    void stubResult(ChangePasswordResult result) {
      when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async => result);
    }

    Widget buildSubject() {
      // Starting at the nested location builds General Settings underneath it,
      // the same stack a push from that screen produces — so a successful
      // change has somewhere to pop back to.
      final router = GoRouter(
        initialLocation: '/general-settings/change-password',
        routes: [
          GoRoute(
            path: '/general-settings',
            builder: (_, _) => const Scaffold(body: Text('general settings')),
            routes: [
              GoRoute(
                path: 'change-password',
                builder: (_, _) => BlocProvider<ChangePasswordCubit>(
                  create: (_) => ChangePasswordCubit(repository: repository),
                  child: const ChangePasswordView(),
                ),
              ),
            ],
          ),
        ],
      );

      return MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        routerConfig: router,
      );
    }

    Future<void> fillForm(
      WidgetTester tester, {
      String current = 'hunter2',
      String newPassword = 'hunter22',
      String confirm = 'hunter22',
    }) async {
      await tester.enterText(
        find.widgetWithText(
          DivineAuthTextField,
          l10n.changePasswordCurrentLabel,
        ),
        current,
      );
      await tester.enterText(
        find.widgetWithText(DivineAuthTextField, l10n.authNewPasswordLabel),
        newPassword,
      );
      await tester.enterText(
        find.widgetWithText(
          DivineAuthTextField,
          l10n.authConfirmNewPasswordLabel,
        ),
        confirm,
      );
      await tester.pump();
    }

    testWidgets('will not submit while a field is still empty', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pump();

      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });

    testWidgets('flags a confirmation that does not match', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester, confirm: 'hunter23');
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pump();

      expect(find.text(l10n.authPasswordsDoNotMatch), findsOneWidget);
      verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      );
    });

    testWidgets('keeps a wrong current password on the screen', (tester) async {
      stubResult(
        ChangePasswordResult.failure(ChangePasswordFailure.wrongPassword),
      );
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester, current: 'wrong');
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.changePasswordWrongCurrent), findsOneWidget);
      expect(find.byType(ChangePasswordView), findsOneWidget);
    });

    testWidgets('leaves the screen and confirms once the password changed', (
      tester,
    ) async {
      stubResult(ChangePasswordResult.success());
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordView), findsNothing);
      expect(find.text(l10n.changePasswordSuccess), findsOneWidget);
    });

    testWidgets('reads a refusal out to a screen reader', (tester) async {
      stubResult(
        ChangePasswordResult.failure(ChangePasswordFailure.wrongPassword),
      );
      final announced = _captureAnnouncements(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester, current: 'wrong');
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pumpAndSettle();

      // Nothing moves focus to the message, so the announcement is the only
      // way a screen-reader user learns the submit was refused.
      expect(announced, contains(l10n.changePasswordWrongCurrent));
    });

    testWidgets('reads the success out before leaving the screen', (
      tester,
    ) async {
      stubResult(ChangePasswordResult.success());
      final announced = _captureAnnouncements(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await fillForm(tester);
      await tester.tap(
        find.widgetWithText(DivineButton, l10n.authUpdatePassword),
      );
      await tester.pumpAndSettle();

      expect(announced, contains(l10n.changePasswordSuccess));
    });
  });
}
