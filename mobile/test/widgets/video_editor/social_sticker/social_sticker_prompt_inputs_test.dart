// ABOUTME: Tests the question, Add yours and replies fields of the social sticker
// ABOUTME: sheet: the prompt, and an Add yours hashtag that follows it.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show VideoStickerAudience;
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_prompt_inputs.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(SocialStickerPromptFields, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<SocialStickerCubit> pump(
      WidgetTester tester,
      SocialStickerKind kind, {
      SocialStickerData? initial,
    }) async {
      final cubit = SocialStickerCubit(
        initial: initial ?? SocialStickerData.interactive(kind),
        blocklistRepository: _MockContentBlocklistRepository(),
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
              child: const SingleChildScrollView(
                child: SocialStickerPromptFields(autofocus: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    group('renders', () {
      testWidgets('a question with a note on where answers go', (tester) async {
        await pump(tester, SocialStickerKind.question);

        expect(find.byType(DivineTextField), findsOneWidget);
        expect(
          find.text(l10n.videoEditorSocialStickerQuestionNote),
          findsOneWidget,
        );
      });

      testWidgets('a replies sticker with its title field', (tester) async {
        await pump(tester, SocialStickerKind.replies);

        expect(
          find.text(l10n.videoEditorSocialStickerRepliesTitleHint),
          findsOneWidget,
        );
        expect(
          find.text(l10n.videoEditorSocialStickerRepliesNote),
          findsOneWidget,
        );
      });

      testWidgets('no choice of who may answer a question, or an answer '
          'that keeps the one its chain started with', (tester) async {
        await pump(tester, SocialStickerKind.question);

        expect(
          find.text(l10n.videoEditorSocialStickerAudienceTitle),
          findsNothing,
        );

        await pump(
          tester,
          SocialStickerKind.addYours,
          initial: const SocialStickerData(
            kind: SocialStickerKind.addYours,
            prompt: 'Show your desk',
            hashtag: 'desksetup',
            chainRoot: '34236:pubkey:chain',
            audience: VideoStickerAudience.following,
          ),
        );

        expect(
          find.text(l10n.videoEditorSocialStickerAudienceTitle),
          findsNothing,
        );
      });
    });

    group('interactions', () {
      testWidgets('an Add yours hashtag follows its prompt into its field', (
        tester,
      ) async {
        final cubit = await pump(tester, SocialStickerKind.addYours);

        await tester.enterText(
          find.byType(EditableText).first,
          'Show your desk',
        );
        await tester.pump();

        expect(cubit.state.data.prompt, equals('Show your desk'));
        expect(find.text('showyourdesk'), findsOneWidget);
      });

      testWidgets('Next goes from an Add yours prompt to its hashtag', (
        tester,
      ) async {
        await pump(tester, SocialStickerKind.addYours);

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();

        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).last)
              .focusNode
              .hasFocus,
          isTrue,
        );
      });

      testWidgets('picks who may answer a replies sticker, and says who sees '
          'it', (tester) async {
        final cubit = await pump(tester, SocialStickerKind.replies);

        expect(
          cubit.state.data.audience,
          equals(VideoStickerAudience.everyone),
        );
        await tester.tap(
          find.text(l10n.videoEditorSocialStickerAudienceCreator),
        );
        await tester.pump();

        expect(cubit.state.data.audience, equals(VideoStickerAudience.creator));
        expect(
          find.text(l10n.videoEditorSocialStickerAudienceCreatorRepliesNote),
          findsOneWidget,
        );

        await tester.tap(
          find.text(l10n.videoEditorSocialStickerAudienceFollowing),
        );
        await tester.pump();

        expect(
          cubit.state.data.audience,
          equals(VideoStickerAudience.following),
        );
        expect(
          find.text(l10n.videoEditorSocialStickerAudienceFollowingRepliesNote),
          findsOneWidget,
        );
      });

      testWidgets('a hashtag the creator writes is published as typed', (
        tester,
      ) async {
        final cubit = await pump(tester, SocialStickerKind.addYours);

        await tester.enterText(find.byType(EditableText).last, 'Desks');
        await tester.pump();

        expect(cubit.state.data.hashtag, equals('desks'));
      });
    });
  });
}
