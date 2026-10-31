// ABOUTME: Tests the poll and quiz fields of the social sticker sheet: the
// ABOUTME: keyboard's Next goes from one answer to the next, past the buttons.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_poll_inputs.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(SocialStickerPollFields, () {
    group('interactions', () {
      testWidgets('Next goes from the question through every answer of a '
          'quiz, past the buttons beside them', (tester) async {
        final cubit = SocialStickerCubit(
          initial: SocialStickerData.poll(SocialStickerKind.quiz),
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
                  child: SocialStickerPollFields(autofocus: true),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        bool hasFocus(int field) => tester
            .widget<EditableText>(find.byType(EditableText).at(field))
            .focusNode
            .hasFocus;
        expect(hasFocus(0), isTrue);

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(hasFocus(1), isTrue);

        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        expect(hasFocus(2), isTrue);
      });

      testWidgets('keeps a pasted answer on one line', (tester) async {
        final cubit = SocialStickerCubit(
          initial: SocialStickerData.poll(SocialStickerKind.poll),
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
                  child: SocialStickerPollFields(),
                ),
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(EditableText).at(0), 'Dinner\n?');
        await tester.enterText(find.byType(EditableText).at(1), 'Pizza\nPasta');

        expect(cubit.state.data.pollQuestion, isNot(contains('\n')));
        expect(cubit.state.data.pollOptions.first, isNot(contains('\n')));
      });
    });
  });
}
