// ABOUTME: Tests the social sticker sheet: hashtags and their limit, links,
// ABOUTME: and switching the sound a sound credit credits.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/search_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/video_editor/social_sticker/social_sticker_sheet.dart';

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockHashtagRepository extends Mock implements HashtagRepository {}

void main() {
  group(SocialStickerSheet, () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockHashtagRepository hashtagRepository;

    setUp(() {
      hashtagRepository = _MockHashtagRepository();
      when(
        () => hashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const []);
    });

    /// Opens the sheet from a button and records what it resolves with.
    Future<List<SocialStickerData?>> pumpSheet(
      WidgetTester tester, {
      required SocialStickerData initial,
      Set<String> otherHashtags = const {},
      List<SocialStickerData> soundChoices = const [],
    }) async {
      final results = <SocialStickerData?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentBlocklistRepositoryProvider.overrideWithValue(
              _MockContentBlocklistRepository(),
            ),
            hashtagRepositoryProvider.overrideWithValue(hashtagRepository),
          ],
          child: MaterialApp(
            theme: VineTheme.theme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => results.add(
                    await showSocialStickerSheet(
                      context,
                      initial: initial,
                      isNew: true,
                      otherHashtags: otherHashtags,
                      soundChoices: soundChoices,
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return results;
    }

    group('interactions', () {
      testWidgets('adds the hashtag picked from the suggestions', (
        tester,
      ) async {
        when(
          () => hashtagRepository.searchHashtags(
            query: 'sum',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => ['Summer', 'summertime']);
        final results = await pumpSheet(
          tester,
          initial: const SocialStickerData(kind: SocialStickerKind.hashtag),
        );

        await tester.enterText(find.byType(TextField), 'sum');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();
        await tester.tap(find.text('#summer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
        await tester.pumpAndSettle();

        expect(results.single?.hashtag, equals('summer'));
      });

      testWidgets('keeps a hashtag the post has no room for off the video', (
        tester,
      ) async {
        final results = await pumpSheet(
          tester,
          initial: const SocialStickerData(kind: SocialStickerKind.hashtag),
          otherHashtags: {for (var i = 0; i < 10; i++) 'tag$i'},
        );

        await tester.enterText(find.byType(TextField), 'summer');
        await tester.pump(searchDebounceDuration);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoMetadataTagsPickerTagLimitReached(10)),
          findsOneWidget,
        );
        expect(results, isEmpty);
      });
      testWidgets('adds a link typed without its scheme', (tester) async {
        final results = await pumpSheet(
          tester,
          initial: const SocialStickerData(kind: SocialStickerKind.link),
        );

        await tester.enterText(find.byType(TextField).first, 'divine.video');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
        await tester.pumpAndSettle();

        expect(results.single?.url, equals('https://divine.video'));
      });

      testWidgets('credits the sound picked among those in the video', (
        tester,
      ) async {
        const song = SocialStickerData(
          kind: SocialStickerKind.soundCredit,
          soundTitle: 'Song',
          soundArtist: 'Artist',
        );
        const other = SocialStickerData(
          kind: SocialStickerKind.soundCredit,
          soundTitle: 'Other',
          soundArtist: 'Band',
        );
        final results = await pumpSheet(
          tester,
          initial: song,
          soundChoices: const [song, other],
        );

        await tester.tap(find.text('Other · Band'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorInfoStickerAdd));
        await tester.pumpAndSettle();

        expect(results.single?.soundTitle, equals('Other'));
      });
    });
  });
}
