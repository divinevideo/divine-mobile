// ABOUTME: Widget tests for the sound list's rows: the action row that heads
// ABOUTME: a list at a small phone's text sizes, and a sound row's cover.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/audio/sound_cover_image.dart';
import 'package:openvine/widgets/audio/sound_list_tile.dart';

import '../../helpers/text_lines.dart';

void main() {
  group(SoundListTile, () {
    group('renders', () {
      testWidgets("its sound's kind on the cover", (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            home: const Scaffold(
              body: SoundListTile(
                title: 'Boom',
                colorSeed: 'boom',
                kind: SoundKind.effect,
                onTap: null,
              ),
            ),
          ),
        );

        expect(
          tester.widget<SoundCoverImage>(find.byType(SoundCoverImage)).kind,
          SoundKind.effect,
        );
      });
    });
  });

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
