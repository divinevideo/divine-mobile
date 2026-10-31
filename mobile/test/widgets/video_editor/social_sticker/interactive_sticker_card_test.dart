// ABOUTME: Tests the question, Add yours and replies cards: what the frames show,
// ABOUTME: who joined or replied in the player's copy, and the buttons on them.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/interactive_sticker_card.dart';

void main() {
  group(InteractiveStickerCard, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final question = SocialStickerData.interactive(
      SocialStickerKind.question,
      prompt: 'Ask me anything',
    );
    const addYours = SocialStickerData(
      kind: SocialStickerKind.addYours,
      prompt: 'Show your desk',
      hashtag: 'desksetup',
    );
    final replies = SocialStickerData.interactive(
      SocialStickerKind.replies,
      prompt: 'Reply with a video',
    );
    const responses = StickerResponses(
      count: 3,
      latest: [
        StickerResponsePreview(),
        StickerResponsePreview(isBlurred: true),
      ],
    );

    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: SizedBox(width: 360, height: 300, child: child)),
      ),
    );

    group('renders', () {
      testWidgets('a question over its answer field', (tester) async {
        await pump(
          tester,
          FittedBox(child: InteractiveStickerCard(data: question)),
        );

        expect(find.text('Ask me anything'), findsOneWidget);
        expect(find.text(l10n.videoStickerQuestionAnswerHint), findsOneWidget);
      });

      testWidgets('an Add yours with no one in the frames', (tester) async {
        await pump(
          tester,
          const FittedBox(child: InteractiveStickerCard(data: addYours)),
        );

        expect(find.text('#desksetup'), findsOneWidget);
        expect(find.text(l10n.videoStickerAddYoursButton), findsOneWidget);
        expect(find.text(l10n.videoStickerAddYoursJoined(0)), findsNothing);
      });

      testWidgets('the copy of an Add yours with who joined', (tester) async {
        await pump(
          tester,
          const InteractiveStickerCopy(data: addYours, responses: responses),
        );

        expect(find.text(l10n.videoStickerAddYoursJoined(3)), findsOneWidget);
      });

      testWidgets('the copy of a replies sticker with how many replied', (
        tester,
      ) async {
        await pump(
          tester,
          InteractiveStickerCopy(data: replies, responses: responses),
        );

        expect(find.text(l10n.videoStickerRepliesCount(3)), findsOneWidget);
        expect(find.byType(ImageFiltered), findsNothing);
      });

      testWidgets('a replies sticker the same size with or without who '
          'replied, so the copy lies on the frames', (tester) async {
        await pump(
          tester,
          FittedBox(child: InteractiveStickerCard(data: replies)),
        );
        final without = tester.getSize(find.byType(InteractiveStickerCard));
        await pump(
          tester,
          FittedBox(
            child: InteractiveStickerCard(data: replies, responses: responses),
          ),
        );

        expect(
          tester.getSize(find.byType(InteractiveStickerCard)),
          equals(without),
        );
      });
    });

    group('interactions', () {
      testWidgets("a tap on a question's field answers it", (tester) async {
        var answered = 0;
        await pump(
          tester,
          InteractiveStickerCopy(data: question, onAnswer: () => answered++),
        );

        await tester.tap(find.text(l10n.videoStickerQuestionAnswerHint));

        expect(answered, equals(1));
      });

      testWidgets('an Add yours joins on its button and opens who joined '
          'beside it', (tester) async {
        var joined = 0;
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: addYours,
            responses: responses,
            onJoin: () => joined++,
            onOpenResponses: () => opened++,
          ),
        );

        await tester.tap(find.text(l10n.videoStickerAddYoursButton));
        await tester.tap(find.text(l10n.videoStickerAddYoursJoined(3)));

        expect(joined, equals(1));
        expect(opened, equals(1));
      });

      testWidgets('a replies sticker opens the replies', (tester) async {
        var opened = 0;
        await pump(
          tester,
          InteractiveStickerCopy(
            data: replies,
            responses: responses,
            onOpenResponses: () => opened++,
          ),
        );

        await tester.tap(find.text('Reply with a video'));

        expect(opened, equals(1));
      });
    });
  });
}
