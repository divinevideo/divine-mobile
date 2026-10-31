// ABOUTME: Tests the question, Add yours and replies fields of the social sticker
// ABOUTME: sheet: the prompt, and an Add yours hashtag that follows it.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
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
      SocialStickerKind kind,
    ) async {
      final cubit = SocialStickerCubit(
        initial: SocialStickerData.interactive(kind),
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
