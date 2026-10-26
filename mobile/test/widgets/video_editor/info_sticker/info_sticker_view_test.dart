// ABOUTME: Tests the info sticker view where the draft rasterizer mounts it:
// ABOUTME: with no Material above it.

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/info_sticker_view.dart';
import 'package:openvine/widgets/video_editor/info_sticker/rec_timer_painter.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';

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

      testWidgets('a REC timer that moves on with each whole second', (
        tester,
      ) async {
        final playTime = ValueNotifier(Duration.zero);
        addTearDown(playTime.dispose);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoEditorScope(
              editorKey: GlobalKey(),
              removeAreaKey: GlobalKey(),
              originalClipAspectRatio: 9 / 16,
              bodySizeNotifier: ValueNotifier(const Size(400, 600)),
              zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
              playTimeNotifier: playTime,
              playheadAdvancingNotifier: ValueNotifier<bool>(false),
              fromLibrary: false,
              onOpenCamera: () {},
              onOpenClipsEditor: () {},
              onAddStickers: () {},
              onAddEditTextLayer: ([layer]) async => null,
              onOpenMusicLibrary: () {},
              onOpenVoiceOver: () {},
              onOpenCaptions: () {},
              onOpenEffects: () {},
              child: const Center(
                child: InfoStickerView(
                  data: InfoStickerData(
                    kind: InfoStickerKind.recTimer,
                    localeName: 'en',
                    style: InfoStickerStyle.camcorder,
                  ),
                ),
              ),
            ),
          ),
        );
        RecTimerPainter painter() =>
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(InfoStickerView),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as RecTimerPainter;

        playTime.value = const Duration(milliseconds: 1200);
        await tester.pump();
        final atOneSecond = painter();
        expect(atOneSecond.elapsed, equals(const Duration(seconds: 1)));

        playTime.value = const Duration(milliseconds: 1700);
        await tester.pump();
        expect(painter(), same(atOneSecond));

        playTime.value = const Duration(milliseconds: 2100);
        await tester.pump();
        expect(painter().elapsed, equals(const Duration(seconds: 2)));
      });

      testWidgets('a Turkish camcorder date in capitals with a dotted I', (
        tester,
      ) async {
        await tester.runAsync(() => initializeDateFormatting('tr'));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Center(
              child: InfoStickerView(
                data: InfoStickerData(
                  kind: InfoStickerKind.date,
                  localeName: 'tr',
                  style: InfoStickerStyle.camcorder,
                  dateTime: DateTime(2026, 10, 26),
                ),
              ),
            ),
          ),
        );

        // October is "Eki" in Turkish.
        expect(find.textContaining('EKİ'), findsOneWidget);
        expect(find.textContaining('EKI'), findsNothing);
      });
    });
  });
}
