// ABOUTME: Tests for VideoEditorBlockingOverlay: hides the editor underneath
// ABOUTME: from touch and screen readers, and announces the wait once.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/video_editor_blocking_overlay.dart';

List<String> _captureAnnouncements(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        final data = message['data']! as Map<Object?, Object?>;
        announced.add(data['message']! as String);
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

Future<void> _pump(
  WidgetTester tester, {
  required bool blocking,
  VoidCallback? onSplit,
  VoidCallback? onCancel,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: TextButton(onPressed: onSplit, child: const Text('Split')),
            ),
            if (blocking)
              VideoEditorBlockingOverlay(
                announcement: 'Merging clips',
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group(VideoEditorBlockingOverlay, () {
    group('semantics', () {
      testWidgets('hides the editor underneath from screen readers', (
        tester,
      ) async {
        await _pump(tester, blocking: false, onSplit: () {});
        expect(find.semantics.byLabel('Split'), findsOne);

        await _pump(tester, blocking: true, onSplit: () {});

        expect(find.semantics.byLabel('Split'), findsNothing);
      });

      testWidgets('keeps its own controls usable by screen readers', (
        tester,
      ) async {
        var cancelled = 0;
        await _pump(tester, blocking: true, onCancel: () => cancelled++);

        tester.semantics.tap(find.semantics.byLabel('Cancel'));
        await tester.pump();

        expect(cancelled, equals(1));
      });
    });

    group('touch', () {
      testWidgets('absorbs taps meant for the editor underneath', (
        tester,
      ) async {
        var splits = 0;
        await _pump(tester, blocking: false, onSplit: () => splits++);
        await tester.tap(find.text('Split'));
        expect(splits, equals(1));

        await _pump(tester, blocking: true, onSplit: () => splits++);
        await tester.tap(find.text('Split'), warnIfMissed: false);
        await tester.pump();

        expect(splits, equals(1));
      });
    });

    group('announcement', () {
      testWidgets('announces what the user is waiting for when it appears', (
        tester,
      ) async {
        final announced = _captureAnnouncements(tester);

        await _pump(tester, blocking: true);
        await tester.pump();

        expect(announced, equals(['Merging clips']));
      });

      testWidgets('does not repeat the announcement while it stays up', (
        tester,
      ) async {
        final announced = _captureAnnouncements(tester);
        await _pump(tester, blocking: true);
        await tester.pump();
        expect(announced, hasLength(1));

        await _pump(tester, blocking: true, onCancel: () {});
        await tester.pump();

        expect(announced, hasLength(1));
      });
    });
  });
}
