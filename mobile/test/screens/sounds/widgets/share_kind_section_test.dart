import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/sounds/widgets/share_kind_section.dart';

void main() {
  group(ShareKindSection, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildSection({
      SoundKind? kind,
      ValueChanged<SoundKind?>? onChanged,
    }) => MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ShareKindSection(kind: kind, onChanged: onChanged),
      ),
    );

    group('renders', () {
      testWidgets('asks for a choice while none is made', (tester) async {
        await tester.pumpWidget(buildSection(onChanged: (_) {}));

        expect(find.text(l10n.soundsShareKindChoose), findsOneWidget);
      });

      testWidgets('names the chosen kind', (tester) async {
        await tester.pumpWidget(
          buildSection(kind: SoundKind.effect, onChanged: (_) {}),
        );

        expect(find.text(l10n.soundsShareKindEffect), findsOneWidget);
      });
    });

    group('interactions', () {
      Future<void> choose(WidgetTester tester, String option) async {
        await tester.tap(find.byKey(const Key('add_sound_kind_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option).last);
        await tester.pumpAndSettle();
      }

      testWidgets('reports the kind picked from its menu', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(buildSection(onChanged: picked.add));

        await choose(tester, l10n.categoryMusic);

        expect(picked, [SoundKind.music]);
      });

      testWidgets('reports neither as no kind', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(
          buildSection(kind: SoundKind.music, onChanged: picked.add),
        );

        await choose(tester, l10n.soundsShareKindNeither);

        expect(picked, [null]);
      });

      testWidgets('cannot be opened while the kind cannot change', (
        tester,
      ) async {
        await tester.pumpWidget(buildSection());

        await tester.tap(find.byKey(const Key('add_sound_kind_button')));
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundsShareKindNeither), findsNothing);
      });
    });
  });
}
