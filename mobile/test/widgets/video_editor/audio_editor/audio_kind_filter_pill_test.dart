import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show SoundKind;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_kind_filter_pill.dart';

void main() {
  group(AudioKindFilterPill, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Widget buildPill({
      SoundKind? selected,
      ValueChanged<SoundKind?>? onChanged,
    }) => MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              suffixIconConstraints: const BoxConstraints(),
              suffixIcon: AudioKindFilterPill(
                selected: selected,
                onChanged: onChanged ?? (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    group('renders', () {
      testWidgets('All while no kind is picked', (tester) async {
        await tester.pumpWidget(buildPill());

        expect(find.text(l10n.libraryFilterAll), findsOneWidget);
      });

      testWidgets('the picked kind', (tester) async {
        await tester.pumpWidget(buildPill(selected: SoundKind.effect));

        expect(find.text(l10n.videoEditorAudioFilterEffects), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('reports the kind picked from its menu', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(buildPill(onChanged: picked.add));

        await tester.tap(find.byKey(const Key('audio_kind_filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.categoryMusic));
        await tester.pumpAndSettle();

        expect(picked, [SoundKind.music]);
      });

      testWidgets('a screen reader opens its menu', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(buildPill(onChanged: picked.add));

        tester.semantics.tap(
          find.semantics.byLabel(
            l10n.searchFilterPillSemanticLabel(l10n.libraryFilterAll),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.categoryMusic));
        await tester.pumpAndSettle();

        expect(picked, [SoundKind.music]);
      });

      testWidgets('reports All as no kind', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(
          buildPill(selected: SoundKind.music, onChanged: picked.add),
        );

        await tester.tap(find.byKey(const Key('audio_kind_filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.libraryFilterAll));
        await tester.pumpAndSettle();

        expect(picked, [null]);
      });

      testWidgets('reports nothing when the menu is dismissed', (tester) async {
        final picked = <SoundKind?>[];
        await tester.pumpWidget(buildPill(onChanged: picked.add));

        await tester.tap(find.byKey(const Key('audio_kind_filter')));
        await tester.pumpAndSettle();
        expect(find.text(l10n.videoEditorAudioFilterEffects), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorAudioFilterEffects), findsNothing);
        expect(picked, isEmpty);
      });
    });
  });
}
