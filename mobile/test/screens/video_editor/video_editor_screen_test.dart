import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';

void main() {
  group('editorRecorderRoute', () {
    const editorKey = Key('editor');
    const recorderKey = Key('recorder');

    Future<void> pushRecorder(WidgetTester tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ColoredBox(key: editorKey, color: Color(0xFFFFFFFF)),
        ),
      );
      navigatorKey.currentState!.push<bool>(
        editorRecorderRoute(
          const ColoredBox(key: recorderKey, color: Color(0xFF000000)),
        ),
      );
    }

    testWidgets('keeps painting the editor while the recorder fades in', (
      tester,
    ) async {
      await pushRecorder(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(recorderKey), findsOneWidget);
      expect(find.byKey(editorKey), findsOneWidget);
    });

    testWidgets('stops painting the editor once the recorder covers it', (
      tester,
    ) async {
      await pushRecorder(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(recorderKey), findsOneWidget);
      expect(find.byKey(editorKey), findsNothing);
      expect(find.byKey(editorKey, skipOffstage: false), findsOneWidget);
    });
  });
}
