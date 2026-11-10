// ABOUTME: Tests FittedCaptionPill, the caption pill sized for the short
// ABOUTME: editor previews of a small phone.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/caption_pill.dart';
import 'package:openvine/widgets/fitted_caption_pill.dart';

import '../helpers/text_lines.dart';

void main() {
  group(FittedCaptionPill, () {
    const text = 'A caption long enough to wrap onto a few lines';

    Future<void> pumpPill(WidgetTester tester, {required Size space}) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.12;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: space,
              child: const FittedCaptionPill(text: text),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('the cue inside a space too short for it, at the bottom', (
        tester,
      ) async {
        await pumpPill(tester, space: const Size(343, 120));

        expect(tester.takeException(), isNull);
        final pill = tester.getRect(find.byType(CaptionPill));
        expect(pill.top, greaterThanOrEqualTo(0));
        expect(pill.bottom, closeTo(120, 0.01));
        expect(pill.left, greaterThanOrEqualTo(0));
        expect(pill.right, lessThanOrEqualTo(343));
        expect(wordsSplitAcrossLines(tester, find.text(text)), isEmpty);
      });

      testWidgets('the cue no larger than the chip label cap', (tester) async {
        await pumpPill(tester, space: const Size(343, 600));

        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(text),
        );
        expect(
          paragraph.textScaler.scale(10),
          closeTo(10 * chipLabelTextScaleLimit, 0.001),
        );
      });
    });
  });
}
