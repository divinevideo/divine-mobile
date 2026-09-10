// ABOUTME: Widget tests for FullReactionEmojiPickerSheet.
// ABOUTME: Verifies the sheet mounts the emoji picker and resolves its result.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/inbox/conversation/widgets/full_reaction_emoji_picker_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group('FullReactionEmojiPickerSheet', () {
    testWidgets('mounts the emoji picker when shown', (tester) async {
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    unawaited(
                      FullReactionEmojiPickerSheet.show(context: context),
                    );
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiEditor), findsOneWidget);
    });

    testWidgets('resolves to null when dismissed without a choice', (
      tester,
    ) async {
      String? selected;
      var completed = false;
      await tester.pumpWidget(
        testMaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () async {
                    selected = await FullReactionEmojiPickerSheet.show(
                      context: context,
                    );
                    completed = true;
                  },
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dismiss the sheet without selecting an emoji.
      Navigator.of(tester.element(find.byType(EmojiEditor))).pop();
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(selected, isNull);
    });

    group('buildI18n', () {
      test('maps every category label to its localized value', () {
        final en = lookupAppLocalizations(const Locale('en'));
        final i18n = FullReactionEmojiPickerSheet.buildI18n(en);

        expect(i18n.search, en.emojiPickerSearchHint);
        expect(i18n.categoryRecent, en.emojiCategoryRecent);
        expect(i18n.categorySmileys, en.emojiCategorySmileys);
        expect(i18n.categoryAnimals, en.emojiCategoryAnimals);
        expect(i18n.categoryFood, en.emojiCategoryFood);
        expect(i18n.categoryActivities, en.emojiCategoryActivities);
        expect(i18n.categoryTravel, en.emojiCategoryTravel);
        expect(i18n.categoryObjects, en.emojiCategoryObjects);
        expect(i18n.categorySymbols, en.emojiCategorySymbols);
        expect(i18n.categoryFlags, en.emojiCategoryFlags);
      });

      test('follows the active locale instead of hardcoded English', () {
        final en = lookupAppLocalizations(const Locale('en'));
        final de = lookupAppLocalizations(const Locale('de'));

        // German labels differ from English, proving the picker reads from
        // l10n rather than the package's hardcoded English defaults.
        expect(de.emojiCategorySmileys, isNot(en.emojiCategorySmileys));
        expect(
          FullReactionEmojiPickerSheet.buildI18n(de).categorySmileys,
          de.emojiCategorySmileys,
        );
      });
    });
  });
}
