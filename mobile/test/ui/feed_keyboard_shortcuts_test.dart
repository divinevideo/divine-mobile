import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/ui/feed_keyboard_shortcuts.dart';

void main() {
  group(FeedKeyboardShortcuts, () {
    late List<String> commands;

    setUp(() {
      commands = <String>[];
    });

    Widget feed({required bool isActive, Widget? child}) =>
        FeedKeyboardShortcuts(
          isActive: isActive,
          onPreviousVideo: () => commands.add('previous'),
          onNextVideo: () => commands.add('next'),
          onTogglePlayback: () => commands.add('playback'),
          onToggleMute: () => commands.add('mute'),
          child: child ?? const SizedBox.expand(),
        );

    Future<void> pumpApp(WidgetTester tester, Widget home) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: home),
        ),
      );
      // The feed takes focus after its first frame.
      await tester.pump();
    }

    Future<void> pressFeedKeys(WidgetTester tester) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    }

    group('keys', () {
      testWidgets('the arrows, Space and M run the feed commands', (
        tester,
      ) async {
        await pumpApp(tester, feed(isActive: true));

        await pressFeedKeys(tester);

        expect(commands, equals(['next', 'previous', 'playback', 'mute']));
      });

      testWidgets('a held arrow moves one video', (tester) async {
        await pumpApp(tester, feed(isActive: true));

        await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);

        expect(commands, equals(['next']));
      });

      testWidgets('a focused control inside the feed keeps Space', (
        tester,
      ) async {
        final buttonFocus = FocusNode();
        addTearDown(buttonFocus.dispose);
        await pumpApp(
          tester,
          feed(
            isActive: true,
            child: Center(
              child: TextButton(
                focusNode: buttonFocus,
                onPressed: () => commands.add('button'),
                child: const Text('Like'),
              ),
            ),
          ),
        );
        buttonFocus.requestFocus();
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pump();

        expect(commands, equals(['button']));
      });
    });

    group('focus', () {
      // Arrows are left out here: with nothing focused they move the focus,
      // which may land on the feed as on any other focusable widget.
      testWidgets('a feed that is not active leaves the focus alone', (
        tester,
      ) async {
        await pumpApp(tester, feed(isActive: false));

        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(commands, isEmpty);
      });

      testWidgets('takes the focus when it becomes active', (tester) async {
        await pumpApp(tester, feed(isActive: false));
        await pumpApp(tester, feed(isActive: true));

        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(commands, equals(['mute']));
      });

      testWidgets('leaves the focus in a text field', (tester) async {
        Widget screen({required bool feedIsActive}) => Column(
          children: [
            const TextField(autofocus: true),
            Expanded(child: feed(isActive: feedIsActive)),
          ],
        );
        await pumpApp(tester, screen(feedIsActive: false));
        await pumpApp(tester, screen(feedIsActive: true));

        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(commands, isEmpty);
        expect(
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<EditableText>(),
          isNotNull,
        );
      });

      testWidgets('takes the focus when clicked with a mouse', (tester) async {
        await pumpApp(tester, feed(isActive: false));

        await tester.tap(
          find.byType(FeedKeyboardShortcuts),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(commands, equals(['mute']));
      });

      testWidgets('a touch does not take the focus', (tester) async {
        await pumpApp(tester, feed(isActive: false));

        await tester.tap(find.byType(FeedKeyboardShortcuts));
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.keyM);

        expect(commands, isEmpty);
      });
    });
  });
}
