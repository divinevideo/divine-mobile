// ABOUTME: Widget tests for the sound list's rows, starting with the action
// ABOUTME: row that heads a list, at the text sizes of a small phone.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/audio/sound_list_tile.dart';

import '../../helpers/text_lines.dart';

void main() {
  group(SoundListActionTile, () {
    group('at the largest text size on a small phone', () {
      testWidgets('keeps every word of its title whole', (tester) async {
        tester.view
          ..physicalSize = const Size(375, 667)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3.12;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        final l10n = lookupAppLocalizations(const Locale('de'));

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SoundListActionTile(
                icon: DivineIconName.folderOpen,
                title: l10n.videoEditorAudioImportAudio,
                subtitle: l10n.soundUploadSupportedFormats,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(
          wordsSplitAcrossLines(
            tester,
            find.text(l10n.videoEditorAudioImportAudio),
          ),
          isEmpty,
        );
      });
    });
  });
}
