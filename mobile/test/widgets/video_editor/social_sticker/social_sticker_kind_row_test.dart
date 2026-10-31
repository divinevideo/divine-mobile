// ABOUTME: Tests the interactive sticker row of the sticker sheet: it offers the
// ABOUTME: question, Add yours and replies, and no second interactive card.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_kind_row.dart';

void main() {
  group(InteractiveStickerKindRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<List<Object?>> pump(
      WidgetTester tester, {
      bool hasInteractiveCard = false,
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
