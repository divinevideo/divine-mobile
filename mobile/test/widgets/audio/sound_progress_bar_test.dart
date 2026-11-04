// ABOUTME: Tests the thin progress line shared by the sound picker and My
// ABOUTME: Sounds: it fills to the fraction played and never past its ends.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/audio/sound_progress_bar.dart';

Widget _bar(double progress) => MaterialApp(
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: VineTheme.theme,
  home: Scaffold(
    body: SizedBox(width: 200, child: SoundProgressBar(progress: progress)),
  ),
);

double _filled(WidgetTester tester) => tester
    .widget<FractionallySizedBox>(find.byType(FractionallySizedBox))
    .widthFactor!;

void main() {
  group(SoundProgressBar, () {
    testWidgets('fills to the fraction played', (tester) async {
      await tester.pumpWidget(_bar(0.42));

      expect(_filled(tester), 0.42);
    });

    for (final (name, progress, filled) in [
      ('past its end', 1.3, 1.0),
      ('below its start', -0.2, 0.0),
    ]) {
      testWidgets('stops at its edge for a position $name', (tester) async {
        await tester.pumpWidget(_bar(progress));

        expect(tester.takeException(), isNull);
        expect(_filled(tester), filled);
      });
    }
  });
}
