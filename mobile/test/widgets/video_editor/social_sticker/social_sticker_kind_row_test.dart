// ABOUTME: Tests the interactive sticker row of the sticker sheet: it offers the
// ABOUTME: question, Add yours and replies, and no second interactive card.

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/utils/sticker_emoji_font.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_kind_row.dart';

void main() {
  group(InteractiveStickerKindRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    // A slider's emoji loads the sticker emoji font, which outlives the test.
    tearDown(resetStickerEmojiFontForTesting);

    Future<List<Object?>> pump(
      WidgetTester tester, {
      bool hasInteractiveCard = false,
      bool canAskQuestion = true,
    }) async {
      final popped = <Object?>[];
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async =>
                      popped.add(await context.push<Object>('/row')),
                  child: const Text('open'),
                ),
              ),
            ),
            routes: [
              GoRoute(
                path: 'row',
                builder: (_, _) => Scaffold(
                  body: InteractiveStickerKindRow(
                    hasInteractiveCard: hasInteractiveCard,
                    canAskQuestion: canAskQuestion,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return popped;
    }

    group('renders', () {
      testWidgets('at its usual height while every name fits on a line', (
        tester,
      ) async {
        await pump(tester);

        expect(
          tester.getSize(find.byType(InteractiveStickerKindRow)).height,
          equals(112),
        );
      });

      testWidgets('each name whole on a small phone with large text', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(tester);

        for (final label in [
          l10n.videoEditorSocialStickerCountdown,
          l10n.videoEditorSocialStickerReplies,
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.widgetWithText(StickerKindTile, label),
              matching: find.text(label),
            ),
          );
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
        }
      });

      testWidgets('the question, Add yours and replies beside the polls', (
        tester,
      ) async {
        await pump(tester);

        for (final label in [
          l10n.videoEditorSocialStickerPoll,
          l10n.videoEditorSocialStickerQuestion,
          l10n.videoEditorSocialStickerAddYours,
          l10n.videoEditorSocialStickerReplies,
        ]) {
          // An Add yours shows its name on its tile and on its button.
          await tester.scrollUntilVisible(
            find.text(label).first,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          expect(find.text(label), findsWidgets, reason: label);
        }
      });

      testWidgets('replies and Add yours right after the countdown', (
        tester,
      ) async {
        await pump(tester);

        final labels = tester
            .widgetList<StickerKindTile>(find.byType(StickerKindTile))
            .map((tile) => tile.label)
            .take(3);
        expect(
          labels,
          equals([
            l10n.videoEditorSocialStickerCountdown,
            l10n.videoEditorSocialStickerReplies,
            l10n.videoEditorSocialStickerAddYours,
          ]),
        );
      });

      testWidgets('no question for an account that may not ask one', (
        tester,
      ) async {
        await pump(tester, canAskQuestion: false);

        final labels = tester
            .widgetList<StickerKindTile>(find.byType(StickerKindTile))
            .map((tile) => tile.label)
            .toList();
        expect(labels, contains(l10n.videoEditorSocialStickerSlider));
        expect(labels, isNot(contains(l10n.videoEditorSocialStickerQuestion)));
      });

      testWidgets('no interactive card once the video has one', (
        tester,
      ) async {
        await pump(tester, hasInteractiveCard: true);

        expect(find.text(l10n.videoEditorSocialStickerQuestion), findsNothing);
        expect(find.text(l10n.videoEditorSocialStickerReplies), findsNothing);
        expect(
          find.text(l10n.videoEditorSocialStickerCountdown),
          findsOneWidget,
        );
      });
    });

    group('interactions', () {
      testWidgets('a tap on the question pops its kind', (tester) async {
        final popped = await pump(tester);

        final question = find.text(l10n.videoEditorSocialStickerQuestion);
        await tester.scrollUntilVisible(
          question,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        await tester.tap(question);
        await tester.pumpAndSettle();

        expect(popped, equals([SocialStickerKind.question]));
      });
    });
  });
}
