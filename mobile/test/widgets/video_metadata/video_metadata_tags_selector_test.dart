import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/social_sticker.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_selection_tile.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
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

  group(VideoMetadataTagsSelector, () {
    testWidgets('renders tags label when no tags selected', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataTagsLabel), findsWidgets);
    });

    testWidgets('renders selected tags joined as value', (tester) async {
      final state = VideoEditorProviderState(tags: {'flutter', 'dart'});

      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: state,
        ),
      );

      expect(find.text('flutter, dart'), findsOneWidget);
    });

    testWidgets('renders the tags the post carries, sticker ones first', (
      tester,
    ) async {
      final sticker = const SocialStickerData(
        kind: SocialStickerKind.hashtag,
        hashtag: 'sticker',
      ).toMeta();
      final tags = [for (var i = 0; i < 10; i++) 'tag$i'];
      final state = VideoEditorProviderState(
        tags: tags.toSet(),
        editorEditingParameters:
            CompleteParameters.fromMap(
              <String, dynamic>{},
            ).copyWith(
              layers: [
                WidgetLayer(
                  widget: const SizedBox(),
                  meta: sticker,
                  exportConfigs: WidgetLayerExportConfigs(meta: sticker),
                ),
              ],
            ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: state,
        ),
      );

      // A post carries ten tags, so the last typed one does not make it.
      expect(
        find.text(['sticker', ...tags.take(9)].join(', ')),
        findsOneWidget,
      );
    });

    testWidgets('picker header describes cancel and apply actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataTagsPickerCancelSemanticLabel),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(l10n.videoMetadataTagsPickerConfirmSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('pasting multiple tags adds chips and clears the field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final searchField = find.byType(TextField).last;
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'foo, bar');
      await tester.pump();

      expect(find.text('foo'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
      expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);

      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets(
      'tapping a suggestion clears the field but keeps search results visible',
      (tester) async {
        when(
          () => hashtagRepository.searchHashtags(
            query: 'mus',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => ['music']);

        await tester.pumpWidget(
          _buildTestApp(
            hashtagRepository: hashtagRepository,
            videoEditorState: VideoEditorProviderState(),
          ),
        );

        await tester.tap(
          find.byType(VideoMetadataSelectionTile),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.byType(TextField).last;
        expect(searchField, findsOneWidget);

        await tester.enterText(searchField, 'mus');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('music'), findsOneWidget);

        await tester.tap(find.text('music'));
        await tester.pump();

        // Field is cleared immediately.
        expect(tester.widget<TextField>(searchField).controller?.text, isEmpty);
        // The tapped tag is now a selected chip, and the suggestion chip for
        // 'music' is filtered out by the bloc (it's already selected).
        expect(find.text('music'), findsOneWidget);
        // The previous query results remain visible so the user can rapidly
        // select multiple related tags. 'mus' appears as a suggestion chip
        // (canAddQuery is true for the preserved query).
        expect(find.text('mus'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
      },
    );

    testWidgets('opening with existing tags does not show no-results copy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(tags: {'music'}),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text('music'), findsAtLeastNWidgets(1));
      expect(find.text(l10n.videoMetadataTagsPickerNoResults), findsNothing);
    });

    testWidgets(
      'removing a selected suggestion restores it to the visible results',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        when(
          () => hashtagRepository.searchHashtags(
            query: 'mus',
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => ['music', 'musician']);

        await tester.pumpWidget(
          _buildTestApp(
            hashtagRepository: hashtagRepository,
            videoEditorState: VideoEditorProviderState(),
          ),
        );

        await tester.tap(
          find.byType(VideoMetadataSelectionTile),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        final searchField = find.byType(TextField).last;
        await tester.enterText(searchField, 'mus');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.text('music'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('musician'), findsOneWidget);
        expect(find.text('mus'), findsOneWidget);

        await tester.tap(
          find.bySemanticsLabel(l10n.videoMetadataDeleteTagHint('music')),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('music'), findsAtLeastNWidgets(1));
        expect(find.text('musician'), findsOneWidget);
      },
    );

    testWidgets('a short drag on the results keeps the picker and its tags', (
      tester,
    ) async {
      when(
        () => hashtagRepository.searchHashtags(
          query: 'mus',
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => ['music', 'musician']);

      await tester.pumpWidget(
        _buildTestApp(
          hashtagRepository: hashtagRepository,
          videoEditorState: VideoEditorProviderState(),
        ),
      );

      await tester.tap(
        find.byType(VideoMetadataSelectionTile),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(find.byType(TextField).last, 'mus');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('music'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // The results pane is the only scroll view wired to the sheet's own
      // controller, so it is where an overscroll turns into a sheet drag.
      final results = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView && widget.controller != null,
      );
      expect(results, findsOneWidget);

      // A third of the viewport: past the floor the sheet used to sit on,
      // short of the one it sits on now. Reaching the floor pops the modal,
      // and the selection pops with it.
      await tester.drag(results, const Offset(0, 200));
      await tester.pump();
      // Long enough for the modal's exit transition to have finished, had the
      // drag triggered one. `pumpAndSettle` cannot be used: the sheet keeps a
      // LinearProgressIndicator mounted at zero opacity, which never settles.
      await tester.pump(const Duration(milliseconds: 500));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataTagsPickerConfirmSemanticLabel),
        findsOneWidget,
      );
      expect(find.text('music'), findsAtLeastNWidgets(1));
    });

    group('hashtag limits', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final tooLongCopy = l10n.videoMetadataTagsPickerTagTooLong(
        HashtagExtractor.maxHashtagLength,
      );

      Future<void> openPicker(
        WidgetTester tester, {
        Set<String> tags = const {},
      }) async {
        await tester.pumpWidget(
          _buildTestApp(
            hashtagRepository: hashtagRepository,
            videoEditorState: VideoEditorProviderState(tags: tags),
          ),
        );
        await tester.tap(
          find.byType(VideoMetadataSelectionTile),
          warnIfMissed: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      testWidgets('a pasted multi-line list becomes separate lowercase tags', (
        tester,
      ) async {
        await openPicker(tester);

        // "Hashtags" and "Vines" meet only at a line break, which a
        // single-line field would delete.
        await tester.enterText(
          find.byType(TextField).last,
          'General Hashtags\nVines\n#vine\u00a0#FunnyVine',
        );
        await tester.pump();

        for (final tag in ['general', 'hashtags', 'vines', 'vine']) {
          expect(find.text(tag), findsOneWidget);
        }
        expect(find.text('funnyvine'), findsOneWidget);
        expect(find.textContaining('hashtagsvines'), findsNothing);

        await tester.pump(const Duration(milliseconds: 400));
      });

      testWidgets('a pasted tag over the limit is rejected with a hint', (
        tester,
      ) async {
        await openPicker(tester);
        final pastedList = 'VineHashtagsMasterList' * 10;

        await tester.enterText(find.byType(TextField).last, pastedList);
        await tester.pump();

        expect(find.text(tooLongCopy), findsOneWidget);
        expect(find.text(pastedList.toLowerCase()), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller
              ?.text,
          isEmpty,
        );

        // Still shown after the cleared field's debounced empty query.
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text(tooLongCopy), findsOneWidget);
      });

      testWidgets(
        'warns instead of searching when the text holds a private key',
        (tester) async {
          await openPicker(tester);

          // Short enough to stay in the field as a search rather than be
          // committed and rejected as an over-long tag.
          await tester.enterText(
            find.byType(TextField).last,
            'nsec1vl029mgpspedva04g90vltkh6f',
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text(l10n.searchPrivateKeyWarning), findsOneWidget);
          verifyNever(
            () => hashtagRepository.searchHashtags(
              query: any(named: 'query', that: contains('nsec1')),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          );
        },
      );

      testWidgets('shows a character counter once a tag gets long', (
        tester,
      ) async {
        await openPicker(tester);

        await tester.enterText(find.byType(TextField).last, 'a' * 39);
        await tester.pump();
        expect(find.text('39/50'), findsNothing);

        await tester.enterText(find.byType(TextField).last, 'a' * 43);
        await tester.pump();
        expect(find.text('43/50'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            l10n.videoMetadataTagsPickerCharacterCount(43, 50),
          ),
          findsOneWidget,
        );
        expect(find.text(tooLongCopy), findsNothing);

        await tester.pump(const Duration(milliseconds: 400));
      });

      testWidgets('explains the limit once a tag reaches it', (tester) async {
        await openPicker(tester);

        await tester.enterText(
          find.byType(TextField).last,
          'a' * HashtagExtractor.maxHashtagLength,
        );
        await tester.pump();

        expect(find.text(tooLongCopy), findsOneWidget);
        expect(find.text('50/50'), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 400));
      });

      testWidgets('explains the tag limit once a video has 10 tags', (
        tester,
      ) async {
        await openPicker(
          tester,
          tags: {for (var i = 0; i < 10; i++) 'tag$i'},
        );

        expect(
          find.text(
            l10n.videoMetadataTagsPickerTagLimitReached(
              HashtagExtractor.maxHashtagsPerVideo,
            ),
          ),
          findsOneWidget,
        );

        await tester.enterText(find.byType(TextField).last, 'eleven ');
        await tester.pump();
        expect(find.text('eleven'), findsNothing);

        await tester.pump(const Duration(milliseconds: 400));
      });
    });
  });

  group(HashtagInputFormatter, () {
    const formatter = HashtagInputFormatter();

    TextEditingValue value(String text) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    test('turns every separator into a single space', () {
      final result = formatter.formatEditUpdate(
        value(''),
        value('#vines\n#vine\tfunny\u00a0comedy,meme'),
      );
      expect(result.text, equals(' vines vine funny comedy meme'));
      expect(result.selection.extentOffset, equals(result.text.length));
    });

    test('drops characters a hashtag cannot contain', () {
      final result = formatter.formatEditUpdate(value(''), value('fun!ny😀'));
      expect(result.text, equals('funny'));
    });

    test('blocks typing past the maximum length in the current tag', () {
      final full = 'a' * HashtagExtractor.maxHashtagLength;
      final result = formatter.formatEditUpdate(value(full), value('${full}b'));
      expect(result.text, equals(full));
    });

    test('lets a new tag start after a full one', () {
      final full = 'a' * HashtagExtractor.maxHashtagLength;
      final result = formatter.formatEditUpdate(value(full), value('$full '));
      expect(result.text, equals('$full '));
    });
  });
}

Widget _buildTestApp({
  required HashtagRepository hashtagRepository,
  required VideoEditorProviderState videoEditorState,
}) {
  return ProviderScope(
    overrides: [
      hashtagRepositoryProvider.overrideWithValue(hashtagRepository),
      videoEditorProvider.overrideWith(
        () => _MockVideoEditorNotifier(videoEditorState),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: VideoMetadataTagsSelector()),
    ),
  );
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    if (tags != null) {
      state = state.copyWith(tags: tags);
    }
  }
}

class _MockHashtagRepository extends Mock implements HashtagRepository {}
