// ABOUTME: Tests for ForgotPasswordDialog (showForgotPasswordDialog)
// ABOUTME: Verifies dialog rendering, email validation, and reset callback

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';

void main() {
  group('showForgotPasswordDialog', () {
    late List<String> resetEmails;

    setUp(() {
      resetEmails = [];
    });

    Widget createTestWidget({
      String initialEmail = '',
      Future<bool> Function(String email)? onSendResetEmail,
      VoidCallback? onResetAccepted,
      TargetPlatform? platform,
    }) {
      return MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme.copyWith(platform: platform),
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => showForgotPasswordDialog(
                      context: context,
                      initialEmail: initialEmail,
                      onSendResetEmail:
                          onSendResetEmail ??
                          (email) async {
                            resetEmails.add(email);
                            return true;
                          },
                      onResetAccepted: onResetAccepted,
                    ),
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('displays Reset Password title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
      });

      testWidgets('displays instructional text', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.forgotPasswordDescription), findsOneWidget);
      });

      testWidgets('displays Cancel button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(
          find.widgetWithText(TextButton, l10n.forgotPasswordCancel),
          findsOneWidget,
        );
      });

      testWidgets('displays Email Reset Link button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
          findsOneWidget,
        );
      });

      testWidgets('pre-populates email field', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'user@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);

        expect(find.text('user@example.com'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('keeps the form controls above the keyboard', (tester) async {
        const viewport = Size(430, 932);
        const keyboardExtent = 336.0;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);

        await tester.tap(find.byType(TextFormField));
        tester.view.viewInsets = const FakeViewPadding(
          bottom: keyboardExtent,
        );
        await tester.pumpAndSettle();

        final visibleBottom = viewport.height - keyboardExtent;
        final l10n = lookupAppLocalizations(const Locale('en'));
        final controls = {
          'email field': find.byType(TextFormField),
          'reset action': find.widgetWithText(
            ElevatedButton,
            l10n.forgotPasswordSendLink,
          ),
        };
        for (final entry in controls.entries) {
          expect(entry.value, findsOneWidget);
          expect(
            tester.getRect(entry.value).bottom,
            lessThanOrEqualTo(visibleBottom),
            reason: '${entry.key} must stay above the keyboard',
          );
        }
      });

      testWidgets('tapping instructional text dismisses field focus', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        final editable = find.byType(EditableText);
        await tester.tap(editable);
        await tester.pump();
        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isTrue,
        );

        await tester.tap(find.text(l10n.forgotPasswordDescription));
        await tester.pump();

        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isFalse,
        );
      });

      testWidgets('dragging the form dismisses field focus on iOS', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(platform: TargetPlatform.iOS));
        await tester.pumpAndSettle();
        await openDialog(tester);

        final editable = find.byType(EditableText);
        await tester.tap(editable);
        await tester.pump();
        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isTrue,
        );

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -80),
        );
        await tester.pump();

        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isFalse,
        );
      });

      testWidgets('Cancel closes dialog', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);

        await tester.tap(
          find.widgetWithText(TextButton, l10n.forgotPasswordCancel),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
      });

      testWidgets('shows validation error for invalid email', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        // Clear and enter invalid email
        await tester.enterText(find.byType(TextFormField), 'not-an-email');
        await tester.pump();

        // Tap send
        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        // Dialog should still be open (validation failed)
        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
        expect(resetEmails, isEmpty);
      });

      testWidgets('calls onSendResetEmail with valid email', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'valid@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(resetEmails, equals(['valid@example.com']));
      });

      testWidgets('closes dialog after sending', (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialEmail: 'user@example.com'),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
      });

      testWidgets('notifies after an accepted reset closes the sheet', (
        tester,
      ) async {
        var acceptedCount = 0;
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onResetAccepted: () => acceptedCount += 1,
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
        expect(acceptedCount, 1);
      });

      testWidgets('shows busy state and blocks duplicate sends or dismissal', (
        tester,
      ) async {
        final sendCompleter = Completer<bool>();
        var sendCount = 0;
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) {
              sendCount += 1;
              return sendCompleter.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pump();

        expect(
          find.widgetWithText(ElevatedButton, l10n.authSending),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, l10n.authSending),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, l10n.forgotPasswordCancel),
              )
              .onPressed,
          isNull,
        );
        expect(sendCount, 1);

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.authSending),
          warnIfMissed: false,
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();

        expect(sendCount, 1);
        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);

        sendCompleter.complete(false);
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
        expect(find.text(l10n.authFailedToSendResetEmail), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, l10n.authTryAgain),
              )
              .onPressed,
          isNotNull,
        );
      });

      testWidgets('ignores a second submit tap before rebuild', (tester) async {
        final sendCompleter = Completer<bool>();
        var sendCount = 0;
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) {
              sendCount += 1;
              return sendCompleter.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        final sendButton = find.widgetWithText(
          ElevatedButton,
          l10n.forgotPasswordSendLink,
        );
        await tester.tap(sendButton);
        await tester.tap(sendButton, warnIfMissed: false);

        expect(sendCount, 1);

        sendCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
      });

      testWidgets('system back does not dismiss the sheet mid-submit', (
        tester,
      ) async {
        final sendCompleter = Completer<bool>();
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) => sendCompleter.future,
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pump();

        await tester.binding.handlePopRoute();
        await tester.pump();

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);

        sendCompleter.complete(true);
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsNothing);
      });

      testWidgets('keeps dialog open and shows retry copy when sending fails', (
        tester,
      ) async {
        final announcements = <String>[];
        tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
              SystemChannels.accessibility,
              (message) async {
                final data = message! as Map<Object?, Object?>;
                if (data['type'] == 'announce') {
                  final payload = data['data']! as Map<Object?, Object?>;
                  announcements.add(payload['message']! as String);
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
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
        expect(find.text(l10n.authFailedToSendResetEmail), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, l10n.authTryAgain),
          findsOneWidget,
        );
        expect(announcements, contains(l10n.authFailedToSendResetEmail));
      });

      testWidgets('shows retry copy when the reset callback throws', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) async => throw StateError('boom'),
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.forgotPasswordTitle), findsOneWidget);
        expect(find.text(l10n.authFailedToSendResetEmail), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, l10n.authTryAgain),
          findsOneWidget,
        );
      });

      testWidgets('clears retry copy when the email changes', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            initialEmail: 'user@example.com',
            onSendResetEmail: (_) async => false,
          ),
        );
        await tester.pumpAndSettle();
        await openDialog(tester);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.authFailedToSendResetEmail), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'other@example.com');
        await tester.pump();

        expect(find.text(l10n.authFailedToSendResetEmail), findsNothing);
        expect(
          find.widgetWithText(ElevatedButton, l10n.forgotPasswordSendLink),
          findsOneWidget,
        );
      });
    });
  });
}
