// ABOUTME: Tests the info sticker view where the draft rasterizer mounts it:
// ABOUTME: with no Material above it.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';

void main() {
  group(InfoStickerView, () {
    group('renders', () {
      testWidgets('its text without the fallback underline', (tester) async {
        await tester.pumpWidget(
          // A MaterialApp with no Material inside it styles text with the
          // yellow underline that marks text outside a Material.
          const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: InfoStickerView(
                data: InfoStickerData(
                  kind: InfoStickerKind.battery,
                  localeName: 'en',
                  batteryLevel: 23,
                ),
              ),
            ),
          ),
        );

        final text = tester.widget<RichText>(
          find.descendant(
            of: find.byType(InfoStickerView),
            matching: find.byType(RichText),
          ),
        );
        expect(text.text.style?.decoration, isNot(TextDecoration.underline));
        expect(text.text.toPlainText(), equals('23%'));
      });
    });
  });
}
