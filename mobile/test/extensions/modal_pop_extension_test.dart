import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

void main() {
  group('ModalPopExtension', () {
    /// Opens a dialog and hands back both its future and the callback its
    /// button would run, so a test can invoke that callback after the route
    /// is gone — the state a real tap lands in when the tree is rebuilt
    /// between the pointer-down and the gesture arena resolving.
    ///
    /// The dead-route tests below leave `result` alone: tearing the whole tree
    /// down is a blunter teardown than the route pop the app does, and when
    /// that future resolves is the route's business rather than the guard's.
    Future<({Future<Object?> result, bool Function() pop})> openDialog(
      WidgetTester tester, {
      required bool Function(BuildContext dialogContext) onPressed,
    }) async {
      late bool Function() capturedPop;
      late BuildContext hostContext;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      final result = showDialog<Object?>(
        context: hostContext,
        builder: (dialogContext) {
          capturedPop = () => onPressed(dialogContext);
          return const SizedBox.shrink();
        },
      );
      await tester.pumpAndSettle();

      return (result: result, pop: capturedPop);
    }

    /// Opens `home -> covered screen -> dialog`, and hands back the dialog's
    /// own context, so a test can pop twice and see which route the second
    /// pop takes.
    Future<BuildContext> openDialogOverScreen(WidgetTester tester) async {
      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      );

      Navigator.of(hostContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('covered screen')),
        ),
      );
      await tester.pumpAndSettle();

      late BuildContext dialogContext;
      unawaited(
        showDialog<bool>(
          context: tester.element(find.text('covered screen')),
          builder: (context) {
            dialogContext = context;
            return const SizedBox.shrink();
          },
        ),
      );
      await tester.pumpAndSettle();

      return dialogContext;
    }

    testWidgets('pops the modal route with the result on a live route', (
      tester,
    ) async {
      final dialog = await openDialog(
        tester,
        onPressed: (dialogContext) => dialogContext.popModalIfMounted(true),
      );

      expect(dialog.pop(), isTrue);
      await tester.pumpAndSettle();

      await expectLater(dialog.result, completion(isTrue));
    });

    testWidgets('completes with null when no result is given', (tester) async {
      final dialog = await openDialog(
        tester,
        onPressed: (dialogContext) => dialogContext.popModalIfMounted(),
      );

      expect(dialog.pop(), isTrue);
      await tester.pumpAndSettle();

      await expectLater(dialog.result, completion(isNull));
    });

    testWidgets('returns false without throwing once the route is gone', (
      tester,
    ) async {
      final dialog = await openDialog(
        tester,
        onPressed: (dialogContext) => dialogContext.popModalIfMounted(true),
      );

      // Stands in for anything that drops the route while a tap is in flight:
      // a rebuild above the modal, a redirect, a deep link.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(dialog.pop, returnsNormally);
      expect(dialog.pop(), isFalse);
    });

    testWidgets('unguarded Navigator.of throws where the guard returns false', (
      tester,
    ) async {
      // Pins the failure this extension exists to prevent: without the mounted
      // check the same callback walks a defunct element and throws, which
      // FlutterError.onError files in Crashlytics as a fatal (#6512).
      final dialog = await openDialog(
        tester,
        onPressed: (dialogContext) {
          Navigator.of(dialogContext).pop(true);
          return true;
        },
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(dialog.pop, throwsFlutterError);
    });

    testWidgets('refuses a second pop while the modal is still exiting', (
      tester,
    ) async {
      final dialogContext = await openDialogOverScreen(tester);

      expect(dialogContext.popModalIfMounted(true), isTrue);
      // A modal stays mounted for the length of its exit transition, so the
      // mounted check alone lets a second tap in this window through.
      await tester.pump(const Duration(milliseconds: 20));

      expect(dialogContext.popModalIfMounted(true), isFalse);
      await tester.pumpAndSettle();

      expect(find.text('covered screen'), findsOneWidget);
    });

    testWidgets('an unguarded second pop takes the route underneath', (
      tester,
    ) async {
      // Pins what the isCurrent check buys: the same second tap, unguarded,
      // dismisses the screen the modal was covering.
      final dialogContext = await openDialogOverScreen(tester);

      expect(dialogContext.popModalIfMounted(true), isTrue);
      await tester.pump(const Duration(milliseconds: 20));

      Navigator.of(dialogContext).pop(true);
      await tester.pumpAndSettle();

      expect(find.text('covered screen'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });
}
