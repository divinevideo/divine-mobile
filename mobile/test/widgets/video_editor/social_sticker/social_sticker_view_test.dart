// ABOUTME: Tests the social sticker as it shows on the video, the same size
// ABOUTME: at any font size, and a countdown on the editor canvas.

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/utils/sound_credit_paint.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_pill_palette.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_view.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

const _mention = SocialStickerData(
  kind: SocialStickerKind.mention,
  pubkey: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  name: 'alice',
);

const _link = SocialStickerData(
  kind: SocialStickerKind.link,
  url: 'https://divine.video/about',
);

void main() {
  group(SocialStickerView, () {
    Future<Size> sizeAt(
      WidgetTester tester,
      SocialStickerData data,
      double textScale,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(child: SocialStickerView(data: data)),
          ),
        ),
      );
      return tester.getSize(find.byType(SocialStickerView));
    }

    group('renders', () {
      testWidgets('a pill the same size at any system font size', (
        tester,
      ) async {
        for (final data in [_mention, _link]) {
          final regular = await sizeAt(tester, data, 1);
          final large = await sizeAt(tester, data, 2);

          expect(large, equals(regular), reason: data.kind.name);
        }
      });

      testWidgets("a reply's comment in its own weight with Bold Text", (
        tester,
      ) async {
        const reply = SocialStickerData(
          kind: SocialStickerKind.reply,
          name: 'divine',
          replyText: 'comment',
        );
        await tester.pumpWidget(
          const MediaQuery(
            data: MediaQueryData(boldText: true),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: SocialStickerView(data: reply)),
            ),
          ),
        );

        final comment = tester.widget<RichText>(
          find.byWidgetPredicate(
            (widget) =>
                widget is RichText && widget.text.toPlainText() == 'comment',
          ),
        );
        expect(comment.text.style?.fontWeight, equals(FontWeight.w400));
      });
    });

    group('countdown', () {
      late ValueNotifier<bool> layerCapture;

      setUp(() {
        layerCapture = ValueNotifier<bool>(false);
      });

      tearDown(() => layerCapture.dispose());

      /// A countdown titled "Summer" that ends [left] from now.
      SocialStickerData countdownIn(Duration left) => SocialStickerData(
        kind: SocialStickerKind.countdown,
        countdownTitle: 'Summer',
        countdownEnd: clock.now().add(left),
      );

      /// Pumps [countdown] as it shows on the editor canvas or, with
      /// [onCanvas] false, with no editor around it, like the draft
      /// rasterizer.
      Future<void> pump(
        WidgetTester tester,
        SocialStickerData countdown, {
        bool onCanvas = true,
      }) {
        final sticker = Center(child: SocialStickerView(data: countdown));
        return tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: onCanvas
                ? VideoEditorScope(
                    editorKey: GlobalKey<ProImageEditorState>(),
                    removeAreaKey: GlobalKey(),
                    originalClipAspectRatio: 9 / 16,
                    bodySizeNotifier: ValueNotifier(const Size(400, 600)),
                    zoomMatrixNotifier: ValueNotifier(Matrix4.identity()),
                    playTimeNotifier: ValueNotifier(Duration.zero),
                    playheadAdvancingNotifier: ValueNotifier<bool>(false),
                    layerCaptureNotifier: layerCapture,
                    fromLibrary: false,
                    onOpenCamera: () {},
                    onOpenClipsEditor: () {},
                    onAddStickers: () {},
                    onOpenMusicLibrary: () {},
                    onOpenVoiceOver: () {},
                    onOpenCaptions: () {},
                    onOpenEffects: () {},
                    onAddEditTextLayer: ([layer]) async => null,
                    child: sticker,
                  )
                : sticker,
          ),
        );
      }

      group('renders', () {
        testWidgets('the time left on the editor canvas, counting down every '
            'second', (tester) async {
          final countdown = countdownIn(
            const Duration(days: 12, hours: 4, seconds: 10),
          );
          await pump(tester, countdown);

          expect(find.text('12 days 04:00:10'), findsOneWidget);
          expect(
            find.text(SocialStickerView.countdownDateOf(countdown)),
            findsNothing,
          );

          await tester.pump(const Duration(seconds: 1));
          expect(find.text('12 days 04:00:09'), findsOneWidget);
        });

        testWidgets('the date while the canvas is captured for the frames', (
          tester,
        ) async {
          final countdown = countdownIn(const Duration(hours: 1));
          await pump(tester, countdown);
          expect(find.text('01:00:00'), findsOneWidget);

          layerCapture.value = true;
          await tester.pump();
          expect(
            find.text(SocialStickerView.countdownDateOf(countdown)),
            findsOneWidget,
          );
          expect(find.text('01:00:00'), findsNothing);

          layerCapture.value = false;
          await tester.pump();
          expect(find.text('01:00:00'), findsOneWidget);
        });

        testWidgets('the date outside the editor, as it goes into the frames', (
          tester,
        ) async {
          final countdown = countdownIn(const Duration(hours: 1));
          await pump(tester, countdown, onCanvas: false);

          expect(
            find.text(SocialStickerView.countdownDateOf(countdown)),
            findsOneWidget,
          );
          expect(find.text('01:00:00'), findsNothing);
        });
      });
    });
  });

  group(SocialStickerCopy, () {
    group('renders', () {
      testWidgets('a solid sound credit in a pill rounded like its own', (
        tester,
      ) async {
        const credit = SocialStickerData(
          kind: SocialStickerKind.soundCredit,
          soundTitle: 'Song',
          soundArtist: 'Artist',
        );
        // Twice the size it lays out at, as the frames carry it scaled.
        final box = soundCreditSize(credit) * 2;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.fromSize(
                size: box,
                child: const SocialStickerCopy(data: credit),
              ),
            ),
          ),
        );

        // Its own corners are 48 round where it lays out, 96 at twice that.
        expect(
          find.byType(SocialStickerCopy),
          paints..something((method, arguments) {
            if (method != #drawRRect) return false;
            final [RRect pill, Paint paint] = arguments;
            return pill.outerRect == Offset.zero & box &&
                (pill.tlRadiusX - 96).abs() < 1e-9 &&
                paint.color ==
                    StickerPillPalette.of(InfoStickerStyle.light).background;
          }),
        );
      });
    });
  });
}
