import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/back_on_escape.dart';

void main() {
  group(BackOnEscape, () {
    late GlobalKey<NavigatorState> navigatorKey;

    setUp(() {
      navigatorKey = GlobalKey<NavigatorState>();
    });

    Future<void> pumpApp(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => BackOnEscape(child: child!),
        home: const Scaffold(body: Text('Feed')),
      ),
    );

    Future<void> open(WidgetTester tester, Widget screen) async {
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => Scaffold(body: screen)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> pressEscape(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }

    testWidgets('closes a screen opened over another', (tester) async {
      await pumpApp(tester);
      await open(tester, const Text('Profile'));

      await pressEscape(tester);

      expect(find.text('Profile'), findsNothing);
      expect(find.text('Feed'), findsOneWidget);
    });

    testWidgets('leaves the first screen open', (tester) async {
      await pumpApp(tester);

      await pressEscape(tester);

      expect(find.text('Feed'), findsOneWidget);
    });

    testWidgets('only gives up the focus of a text field before closing', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, const TextField(autofocus: true));
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);

      await pressEscape(tester);

      expect(field.focusNode.hasFocus, isFalse);
      expect(find.byType(TextField), findsOneWidget);

      await pressEscape(tester);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('closes a dialog before the screen under it', (tester) async {
      await pumpApp(tester);
      await open(tester, const Text('Profile'));
      unawaited(
        showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Report')),
        ),
      );
      await tester.pumpAndSettle();

      await pressEscape(tester);

      expect(find.text('Report'), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('closes a dialog from a text field inside it', (tester) async {
      await pumpApp(tester);
      await open(tester, const Text('Profile'));
      unawaited(
        showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => const AlertDialog(
            content: TextField(autofocus: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await pressEscape(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('leaves a dialog open that the user cannot dismiss', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, const Text('Profile'));
      unawaited(
        showDialog<void>(
          context: navigatorKey.currentContext!,
          barrierDismissible: false,
          builder: (_) => const AlertDialog(content: Text('Pick one')),
        ),
      );
      await tester.pumpAndSettle();

      await pressEscape(tester);

      expect(find.text('Pick one'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('closes only a screen that went back on Escape by itself', (
      tester,
    ) async {
      await pumpApp(tester);
      await open(tester, const Text('Recorder'));
      await open(tester, const _ClosesItselfOnEscape());

      await pressEscape(tester);

      expect(find.text('Editor'), findsNothing);
      expect(find.text('Recorder'), findsOneWidget);
    });

    testWidgets('lets a screen that guards going back decide', (tester) async {
      var attempts = 0;
      await pumpApp(tester);
      await open(
        tester,
        PopScope<void>(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) => attempts++,
          child: const Text('Editor'),
        ),
      );

      await pressEscape(tester);

      expect(attempts, equals(1));
      expect(find.text('Editor'), findsOneWidget);
    });

    testWidgets('closes the outer screen when an inner navigator is on its '
        'first screen', (tester) async {
      await pumpApp(tester);
      await open(
        tester,
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Focus(autofocus: true, child: Text('Tab')),
          ),
        ),
      );

      await pressEscape(tester);

      expect(find.text('Tab'), findsNothing);
      expect(find.text('Feed'), findsOneWidget);
    });
  });
}

/// Pops its own route on Escape from a keyboard handler, which runs before
/// any shortcut, the way the image editor closes.
class _ClosesItselfOnEscape extends StatefulWidget {
  const _ClosesItselfOnEscape();

  @override
  State<_ClosesItselfOnEscape> createState() => _ClosesItselfOnEscapeState();
}

class _ClosesItselfOnEscapeState extends State<_ClosesItselfOnEscape> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.pop(context);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      const Focus(autofocus: true, child: Text('Editor'));
}
