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

const _bernWithCountry = InfoStickerPlace(
  name: 'Bern',
  detail: 'Switzerland',
  latitude: 46.95,
  longitude: 7.45,
  countryCode: 'CH',
);

const _thun = InfoStickerPlace(
  name: 'Thun',
  detail: 'Switzerland',
  latitude: 46.76,
  longitude: 7.63,
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
      for (final initial in [
        const InfoStickerData(
          kind: InfoStickerKind.weather,
          localeName: 'en',
          temperatureCelsius: 21,
        ),
        const InfoStickerData(
          kind: InfoStickerKind.altitude,
          localeName: 'en',
          altitudeMeters: 540,
        ),
        const InfoStickerData(
          kind: InfoStickerKind.dayCount,
          localeName: 'en',
          dayNumber: 3,
        ),
      ]) {
        testWidgets('${initial.kind.name} requires a number after clearing', (
          tester,
        ) async {
          final results = await pumpSheet(tester, initial: initial);
          final field = find.byType(TextField).first;
          await tester.enterText(field, '');
          await tester.pumpAndSettle();

          expect(
            tester.widget<DivineButton>(find.byType(DivineButton)).onPressed,
            isNull,
          );

          final isDay = initial.kind == InfoStickerKind.dayCount;
          await tester.enterText(field, isDay ? '0' : '-');
          await tester.pumpAndSettle();
          expect(
            tester.widget<DivineButton>(find.byType(DivineButton)).onPressed,
            isNull,
          );

          await tester.enterText(field, isDay ? '12' : '-12');
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
          await tester.pumpAndSettle();
          final data = results.single!;
          expect(
            switch (data.kind) {
              InfoStickerKind.weather => data.displayTemperature,
              InfoStickerKind.altitude => data.displayAltitude,
              _ => data.dayNumber,
            },
            equals(isDay ? 12 : -12),
          );
        });
      }

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

      testWidgets("empties the altitude when another place's lookup fails", (
        tester,
      ) async {
        when(
          () => repository.searchPlaces('Bern', languageCode: 'en'),
        ).thenAnswer((_) async => [_bern, _thun]);
        when(() => repository.elevationAt(_bern)).thenAnswer((_) async => 540);
        when(
          () => repository.elevationAt(_thun),
        ).thenThrow(const InfoStickerLookupException('offline'));
        await pumpSheet(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.altitude,
            localeName: 'en',
          ),
        );

        await tester.enterText(find.byType(TextField), 'Bern');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineSelectableRow, 'Bern'));
        await tester.pumpAndSettle();
        expect(find.text('540'), findsOneWidget);

        await tester.tap(find.text(l10n.videoEditorInfoStickerChangePlace));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineSelectableRow, 'Thun'));
        await tester.pumpAndSettle();

        expect(find.text('540'), findsNothing);
        expect(
          find.text(l10n.videoEditorInfoStickerLoadFailed),
          findsOneWidget,
        );
      });

      testWidgets('marks the pin when a place has no flag for the one picked', (
        tester,
      ) async {
        when(
          () => repository.searchPlaces('Bern', languageCode: 'en'),
        ).thenAnswer((_) async => [_bernWithCountry, _thun]);
        await pumpSheet(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.location,
            localeName: 'en',
          ),
        );
        await tester.enterText(find.byType(TextField), 'Bern');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineSelectableRow, 'Bern'));
        await tester.pumpAndSettle();
        final pin = find.bySemanticsLabel(
          '📍 ${l10n.videoEditorInfoStickerSymbolPin}',
        );
        await tester.tap(
          find.bySemanticsLabel(
            '🇨🇭 ${l10n.videoEditorInfoStickerSymbolFlag}',
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.getSemantics(pin), isSemantics(isSelected: false));

        await tester.tap(find.text(l10n.videoEditorInfoStickerChangePlace));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DivineSelectableRow, 'Thun'));
        await tester.pumpAndSettle();

        expect(tester.getSemantics(pin), isSemantics(isSelected: true));
      });

      testWidgets('moves on from the day to the total days', (tester) async {
        await pumpSheet(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.dayCount,
            localeName: 'en',
            dayNumber: 1,
          ),
        );

        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(
          [for (final field in fields) field.textInputAction],
          equals([TextInputAction.next, TextInputAction.done]),
        );
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
