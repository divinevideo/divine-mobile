// ABOUTME: Tests the place search of the info sticker sheet: its suggestions
// ABOUTME: keep their room above the keyboard at the largest text size.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_place_picker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_sheet.dart';

class _MockInfoStickerRepository extends Mock
    implements InfoStickerRepository {}

const _bern = InfoStickerPlace(
  name: 'Bern',
  detail: 'Switzerland',
  address: 'Bern, Switzerland',
);

void main() {
  group(InfoStickerPlacePicker, () {
    late _MockInfoStickerRepository repository;

    setUp(() {
      repository = _MockInfoStickerRepository();
      when(repository.isPlaceSearchAvailable).thenAnswer((_) async => true);
      when(
        () => repository.searchPlaces('Bern', languageCode: 'en'),
      ).thenAnswer((_) async => [_bern]);
    });

    Future<void> pumpSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showInfoStickerSheet(
                  context,
                  initial: const InfoStickerData(
                    kind: InfoStickerKind.location,
                    localeName: 'en',
                  ),
                  isNew: true,
                  repository: repository,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    group('renders', () {
      testWidgets('a suggestion above the keyboard at the largest text size', (
        tester,
      ) async {
        // An iPhone SE with its keyboard up, at the largest iOS text size.
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        tester.platformDispatcher.textScaleFactorTestValue = 3.12;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpSheet(tester);

        await tester.enterText(find.byType(TextField), 'Bern');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();

        final suggestion = tester.getRect(
          find.widgetWithText(DivineSelectableRow, 'Bern'),
        );
        expect(suggestion.height, greaterThan(0));
        expect(suggestion.bottom, lessThanOrEqualTo(667 - 260));
      });

      testWidgets('the privacy note at the foot while the list is short', (
        tester,
      ) async {
        await pumpSheet(tester);

        final l10n = lookupAppLocalizations(const Locale('en'));
        final note = tester.getRect(
          find.text(l10n.videoEditorInfoStickerPlacePrivacyNote),
        );
        final step = tester.getRect(find.byType(InfoStickerPlacePicker));
        // The note keeps its 8 px gap to the foot of the step.
        expect(note.bottom, moreOrLessEquals(step.bottom - 8, epsilon: 1));
      });
    });
  });
}
