// ABOUTME: Tests the social sticker sheet's inputs: the countdown title field
// ABOUTME: capitalizes each word, and hashtag suggestions stay closed after a pick.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/blocs/video_editor/social_sticker/social_sticker_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/widgets/video_editor/info_sticker/sticker_sheet_controls.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_inputs.dart';

import '../../../helpers/text_lines.dart';

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  // #10017: picking a suggestion must close the list for good.
  group(SocialStickerHashtagField, () {
    late _MockHashtagRepository hashtags;

    setUp(() {
      hashtags = _MockHashtagRepository();
      when(
        () => hashtags.countHashtagsLocally(query: any(named: 'query')),
      ).thenReturn(0);
      when(
        () => hashtags.searchHashtags(
          query: 'ab',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => ['abc']);
    });

    // Built in the test body, not `setUp`: the debounce timer has to start
    // inside the widget test's fake clock.
    Future<void> pumpField(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => SocialStickerCubit(
                  initial: const SocialStickerData(
                    kind: SocialStickerKind.hashtag,
                  ),
                  blocklistRepository: _MockContentBlocklistRepository(),
                ),
              ),
              BlocProvider(
                create: (_) => HashtagSearchBloc(hashtagRepository: hashtags),
              ),
            ],
            child: const SingleChildScrollView(
              child: SocialStickerHashtagField(),
            ),
          ),
        ),
      ),
    );

    testWidgets('stays closed when a later search returns after a pick', (
      tester,
    ) async {
      final response = Completer<List<String>>();
      when(
        () => hashtags.searchHashtags(
          query: 'abd',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => response.future);
      await pumpField(tester);

      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('#abc'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'abd');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('#abc'));
      await tester.pump();

      response.complete(['abd', 'abe']);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('#abe'), findsNothing);
    });

    testWidgets('stays closed when a search returns after the text is '
        'deleted', (tester) async {
      final response = Completer<List<String>>();
      when(
        () => hashtags.searchHashtags(
          query: 'abd',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => response.future);
      await pumpField(tester);

      await tester.enterText(find.byType(EditableText), 'abd');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(find.byType(EditableText), '');
      await tester.pump();

      response.complete(['abe']);
      // One frame for the state, one for the row that selects it.
      await tester.pump();
      await tester.pump();
      expect(find.text('#abe'), findsNothing);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('#abe'), findsNothing);
    });

    testWidgets('starts no search for text typed just before a pick', (
      tester,
    ) async {
      when(
        () => hashtags.searchHashtags(
          query: 'abd',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => ['abd', 'abe']);
      await pumpField(tester);

      await tester.enterText(find.byType(EditableText), 'ab');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'abd');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('#abc'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('#abe'), findsNothing);
      verifyNever(
        () => hashtags.searchHashtags(
          query: 'abd',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      );
    });
  });

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

  group(SocialStickerStylePicker, () {
    group('renders', () {
      testWidgets('the names of the looks without splitting a word at the '
          'largest text size', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 3.12;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        // Without a hashtag yet there is no sticker to show in each look,
        // so the looks show their names.
        final cubit = SocialStickerCubit(
          initial: const SocialStickerData(kind: SocialStickerKind.hashtag),
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
                child: const SocialStickerStylePicker(),
              ),
            ),
          ),
        );

        expect(
          wordsSplitAcrossLines(
            tester,
            find.descendant(
              of: find.byType(StickerChoiceTile),
              matching: find.byType(RichText),
            ),
          ),
          isEmpty,
        );
      });
    });
  });
}
