// ABOUTME: Tests for the prompt that names a clip before it is saved.
// ABOUTME: Covers the title it resolves with, cancelling, and keyboard traits.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_feed_item/actions/clip_title_sheet.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(ClipTitleSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<Future<String?>> openSheet(WidgetTester tester) async {
      late BuildContext opener;
      await tester.pumpWidget(
        testMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                opener = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final title = ClipTitleSheet.show(
        context: opener,
        initialTitle: 'Classic clip',
      );
      await tester.pumpAndSettle();
      return title;
    }

    testWidgets('resolves with the trimmed title on Save', (tester) async {
      final title = await openSheet(tester);

      await tester.enterText(find.byType(TextField), '  Skate day  ');
      await tester.tap(find.text(l10n.shareSheetSaveClip));
      await tester.pumpAndSettle();

      expect(await title, equals('Skate day'));
      expect(find.byType(ClipTitleSheet), findsNothing);
    });

    testWidgets('resolves with null on Cancel', (tester) async {
      final title = await openSheet(tester);

      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(await title, isNull);
    });

    testWidgets('keeps the prompt open for a blank title', (tester) async {
      await openSheet(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      await tester.tap(find.text(l10n.shareSheetSaveClip));
      await tester.pumpAndSettle();

      expect(find.byType(ClipTitleSheet), findsOneWidget);
    });

    testWidgets('asks the keyboard for a single-line title', (tester) async {
      await openSheet(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, equals(TextInputType.text));
      expect(field.textCapitalization, equals(TextCapitalization.words));
      expect(field.textInputAction, equals(TextInputAction.done));
    });
  });
}
