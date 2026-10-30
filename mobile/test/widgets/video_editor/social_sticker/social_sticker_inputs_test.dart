// ABOUTME: Tests the social sticker sheet's countdown fields: the title field
// ABOUTME: capitalizes each word, as the other title fields do.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_inputs.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(SocialStickerCountdownFields, () {
    group('renders', () {
      testWidgets('a title field that capitalizes each word', (tester) async {
        final cubit = SocialStickerCubit(
          initial: SocialStickerData.countdown(now: DateTime.utc(2026, 10, 30)),
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
                  child: SocialStickerCountdownFields(),
                ),
              ),
            ),
          ),
        );

        final title = tester.widget<EditableText>(find.byType(EditableText));

        expect(title.textCapitalization, equals(TextCapitalization.words));
      });
    });
  });
}
