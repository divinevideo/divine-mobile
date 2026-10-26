// ABOUTME: Tests the info sticker sheet: a sticker cannot be added before it
// ABOUTME: has what it shows, and the sheet returns what the creator set up.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_sheet.dart';

class _MockInfoStickerRepository extends Mock
    implements InfoStickerRepository {}

const _bern = InfoStickerPlace(
  name: 'Bern',
  detail: 'Switzerland',
  latitude: 46.95,
  longitude: 7.45,
);

void main() {
  group(InfoStickerSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockInfoStickerRepository repository;

    setUp(() {
      repository = _MockInfoStickerRepository();
    });

    /// Opens the sheet from a button and records what it resolves with.
    Future<List<InfoStickerData?>> pumpSheet(
      WidgetTester tester, {
      required InfoStickerData initial,
      bool isNew = true,
    }) async {
      final results = <InfoStickerData?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => results.add(
                  await showInfoStickerSheet(
                    context,
                    initial: initial,
                    isNew: isNew,
                    repository: repository,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    group('interactions', () {
      testWidgets('adds a location sticker picked from the suggestions', (
        tester,
      ) async {
        when(
          () => repository.searchPlaces('Bern', languageCode: 'en'),
        ).thenAnswer((_) async => [_bern]);
        final results = await pumpSheet(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.location,
            localeName: 'en',
          ),
        );

        // The sheet opens at the place search, with nothing to place yet.
        expect(find.text(l10n.videoEditorInfoStickerAdd), findsNothing);

        await tester.enterText(find.byType(TextField), 'Bern');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineSelectableRow, 'Bern'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
        await tester.pumpAndSettle();

        expect(results.single?.placeName, equals('Bern'));
      });

      testWidgets('returns the style picked for a sticker on the canvas', (
        tester,
      ) async {
        final results = await pumpSheet(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.battery,
            localeName: 'en',
            batteryLevel: 42,
          ),
          isNew: false,
        );

        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorInfoStickerStyleDark),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorDoneLabel));
        await tester.pumpAndSettle();

        expect(
          results.single,
          equals(
            const InfoStickerData(
              kind: InfoStickerKind.battery,
              localeName: 'en',
              batteryLevel: 42,
              style: InfoStickerStyle.dark,
            ),
          ),
        );
      });
    });
  });
}
