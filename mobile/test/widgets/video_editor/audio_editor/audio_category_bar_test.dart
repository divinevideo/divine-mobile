// ABOUTME: Tests for AudioCategoryBar widget
// ABOUTME: Validates the tab order and the selection callback

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioCategoryBar, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildWidget({required ValueChanged<AudioCategory> onSelect}) {
      final controller = TabController(
        length: AudioCategory.values.length,
        vsync: const TestVSync(),
      );
      addTearDown(controller.dispose);
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AudioCategoryBar(controller: controller, onSelect: onSelect),
        ),
      );
    }

    testWidgets('renders the four lists in tab order', (tester) async {
      await tester.pumpWidget(buildWidget(onSelect: (_) {}));
      await tester.pumpAndSettle();

      final positions = [
        for (final label in [
          l10n.exploreTabForYou,
          l10n.exploreTabPopular,
          l10n.exploreTabNew,
          l10n.videoEditorAudioCategoryMySounds,
        ])
          tester.getTopLeft(find.text(label)).dx,
      ];
      expect(positions, orderedEquals([...positions]..sort()));
    });

    for (final (label, category) in [
      (l10n.exploreTabForYou, AudioCategory.forYou),
      (l10n.exploreTabPopular, AudioCategory.popular),
      (l10n.exploreTabNew, AudioCategory.newest),
      (l10n.videoEditorAudioCategoryMySounds, AudioCategory.mySounds),
    ]) {
      testWidgets('selects ${category.name} from its tab', (tester) async {
        AudioCategory? selected;
        await tester.pumpWidget(buildWidget(onSelect: (c) => selected = c));
        await tester.pumpAndSettle();

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(selected, equals(category));
      });
    }
  });
}
