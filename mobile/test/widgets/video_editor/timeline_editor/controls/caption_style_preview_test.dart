// ABOUTME: Tests for CaptionStylePreview: a word-highlighting style lights up
// ABOUTME: the sample caption's words one after another.

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/caption_style_preview.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const highlightColor = Color(0xFF27C58B);

  Future<void> pump(
    WidgetTester tester, {
    required CaptionStyle style,
    required double loopValue,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptionStylePreview(
          style: style,
          loopValue: loopValue,
          loopMs: 2400,
          width: 200,
          height: 80,
        ),
      ),
    );
  }

  /// The words of the preview caption drawn in [highlightColor]. A caption
  /// without highlights renders plain text, which has no spans at all.
  List<String> litWords(WidgetTester tester) {
    final text = tester.widget<Text>(find.byType(Text));
    final lit = <String>[];
    text.textSpan?.visitChildren((span) {
      if (span is TextSpan && span.style?.color == highlightColor) {
        lit.add(span.text!);
      }
      return true;
    });
    return lit;
  }

  group(CaptionStylePreview, () {
    final karaoke = CaptionCustomStyle.initial()
        .copyWith(
          animation: CaptionAnimationStyle.highlight,
          highlightColor: highlightColor,
        )
        .resolve();

    testWidgets('lights up the sample words one after another', (
      tester,
    ) async {
      await pump(tester, style: karaoke, loopValue: 0);
      expect(litWords(tester), ['Do']);

      await pump(tester, style: karaoke, loopValue: 0.2);
      expect(litWords(tester), ['It']);

      await pump(tester, style: karaoke, loopValue: 0.45);
      expect(litWords(tester), ['For']);
    });

    testWidgets('lights up nothing for a style without highlights', (
      tester,
    ) async {
      await pump(
        tester,
        style: CaptionCustomStyle.initial().resolve(),
        loopValue: 0.2,
      );

      expect(litWords(tester), isEmpty);
    });
  });
}
