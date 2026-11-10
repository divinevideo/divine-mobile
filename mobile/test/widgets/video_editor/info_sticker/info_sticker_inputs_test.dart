// ABOUTME: Tests the number fields of the info sticker sheet: their labels stay
// ABOUTME: whole, the fields stacking or the units moving when they would not.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/info_sticker/info_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/repositories/info_sticker_repository.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_inputs.dart';

class _MockInfoStickerRepository extends Mock
    implements InfoStickerRepository {}

void main() {
  /// Shows [child] for [initial] at [textScale], on a screen [width] wide,
  /// an iPhone SE's by default.
  Future<void> pumpInputs(
    WidgetTester tester, {
    required InfoStickerData initial,
    required Widget child,
    double textScale = 1,
    double width = 375,
  }) async {
    tester.view.physicalSize = Size(width, 667);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final cubit = InfoStickerCubit(
      repository: _MockInfoStickerRepository(),
      initial: initial,
    );
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    );
  }

  bool isCut(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  group(InfoStickerDayCountFields, () {
    // A new day counter: no total yet, so its label rests in the field at
    // its largest.
    const dayCount = InfoStickerData(
      kind: InfoStickerKind.dayCount,
      localeName: 'en',
      dayNumber: 1,
    );

    group('renders', () {
      testWidgets('the fields side by side where both labels fit', (
        tester,
      ) async {
        await pumpInputs(
          tester,
          initial: dayCount,
          child: const InfoStickerDayCountFields(),
          width: 600,
        );

        final fields = find.byType(TextField);
        expect(
          tester.getTopLeft(fields.at(1)).dy,
          equals(tester.getTopLeft(fields.at(0)).dy),
        );
      });

      testWidgets('both labels whole on a small phone, the fields stacked', (
        tester,
      ) async {
        await pumpInputs(
          tester,
          initial: dayCount,
          child: const InfoStickerDayCountFields(),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(isCut(tester, l10n.videoEditorInfoStickerDayLabel), isFalse);
        expect(
          isCut(tester, l10n.videoEditorInfoStickerDayTotalLabel),
          isFalse,
        );
      });
    });
  });

  group(InfoStickerValueField, () {
    group('renders', () {
      testWidgets('its label whole at the largest text size, with the units '
          'under the field', (tester) async {
        await pumpInputs(
          tester,
          initial: const InfoStickerData(
            kind: InfoStickerKind.weather,
            localeName: 'en',
            temperatureCelsius: 21,
          ),
          child: const InfoStickerValueField(),
          textScale: 3.12,
        );

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          isCut(tester, l10n.videoEditorInfoStickerTemperatureLabel),
          isFalse,
        );
      });
    });
  });
}
