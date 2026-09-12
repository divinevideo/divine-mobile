import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent, VineSound;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';

void main() {
  group(VideoMetadataFormFields, () {
    Widget buildWidget({
      VideoEditorProviderState? state,
      bool enableTags = true,
      bool enableExpiration = true,
      bool enableContentWarning = true,
      bool enableCollaborators = true,
      bool enableInspiredBy = true,
      VideoReplyContext? replyContext,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(state ?? VideoEditorProviderState()),
          ),
          videoReplyContextProvider.overrideWith(
            () => _TestVideoReplyContextNotifier(replyContext),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: VideoMetadataFormFields(
                enableTags: enableTags,
                enableExpiration: enableExpiration,
                enableContentWarning: enableContentWarning,
                enableCollaborators: enableCollaborators,
                enableInspiredBy: enableInspiredBy,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders $VideoMetadataFormFields', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byType(VideoMetadataFormFields), findsOneWidget);
    });

    testWidgets('renders Title text field', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Title',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders Description text field', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineTextField && w.labelText == 'Description',
        ),
        findsOneWidget,
      );
    });

    testWidgets('updates title via provider on text change', (tester) async {
      late _MockVideoEditorNotifier mockNotifier;

      mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: VideoMetadataFormFields()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleField = find.byWidgetPredicate(
        (w) => w is DivineTextField && w.labelText == 'Title',
      );
      await tester.enterText(titleField, 'My Video');
      await tester.pumpAndSettle();

      expect(mockNotifier.lastTitle, equals('My Video'));
    });

    testWidgets('updates description via provider on text change', (
      tester,
    ) async {
      late _MockVideoEditorNotifier mockNotifier;

      mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: VideoMetadataFormFields()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descField = find.byWidgetPredicate(
        (w) => w is DivineTextField && w.labelText == 'Description',
      );
      await tester.enterText(descField, 'A description');
      await tester.pumpAndSettle();

      expect(mockNotifier.lastDescription, equals('A description'));
    });

    testWidgets('hides tags section when enableTags is false', (tester) async {
      await tester.pumpWidget(buildWidget(enableTags: false));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsNothing);
    });

    testWidgets('shows MetadataLimitWarningBanner when present', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          state: VideoEditorProviderState(metadataLimitReached: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('64KB limit reached. Remove some content to continue.'),
        findsOneWidget,
      );
    });

    testWidgets('hides MetadataLimitWarningBanner when limit not reached', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(
        find.text('64KB limit reached. Remove some content to continue.'),
        findsNothing,
      );
    });

    testWidgets('reply visibility toggle updates shareReplyToFeed', (
      tester,
    ) async {
      final mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(() => mockNotifier),
            videoReplyContextProvider.overrideWith(
              () => _TestVideoReplyContextNotifier(
                const VideoReplyContext(
                  rootEventId: 'root-id',
                  rootEventKind: 34236,
                  rootAuthorPubkey: 'author-pubkey',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(child: VideoMetadataFormFields()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(VideoMetadataFormFields)),
      );
      final tile = find.widgetWithText(
        DivineSwitchTile,
        l10n.videoMetadataShareReplyToFeedTitle,
      );
      expect(tile, findsOneWidget);
      expect(tester.widget<DivineSwitchTile>(tile).value, isFalse);

      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();

      final toggle = find.descendant(
        of: tile,
        matching: find.byType(Switch),
      );
      expect(toggle, findsOneWidget);

      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(mockNotifier.lastShareReplyToFeed, isTrue);
      expect(tester.widget<DivineSwitchTile>(tile).value, isTrue);
    });

    testWidgets("audio reuse toggle is shown for the user's own audio", (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(VideoMetadataFormFields)),
      );
      expect(
        find.widgetWithText(
          DivineSwitchTile,
          l10n.soundAllowRemix,
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      "audio reuse toggle is hidden when reusing another creator's sound",
      (tester) async {
        await tester.pumpWidget(
          buildWidget(
            state: VideoEditorProviderState(
              selectedSound: AudioEvent(
                id: 'video_${'b' * 64}',
                pubkey: 'c' * 64,
                createdAt: 1700000000,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(VideoMetadataFormFields)),
        );
        expect(
          find.widgetWithText(
            DivineSwitchTile,
            l10n.soundAllowRemix,
          ),
          findsNothing,
        );
      },
    );

    testWidgets('audio reuse toggle is shown for a bundled divine sound', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildWidget(
          state: VideoEditorProviderState(
            selectedSound: AudioEvent.fromBundledSound(
              VineSound(
                id: 'boom',
                title: 'Vine Boom',
                assetPath: 'assets/sounds/vine-boom.mp3',
                duration: const Duration(seconds: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(VideoMetadataFormFields)),
      );
      expect(
        find.widgetWithText(
          DivineSwitchTile,
          l10n.soundAllowRemix,
        ),
        findsOneWidget,
      );
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  String? lastTitle;
  String? lastDescription;
  bool? lastShareReplyToFeed;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    if (title != null) lastTitle = title;
    if (description != null) lastDescription = description;
  }

  @override
  void setShareReplyToFeed(bool shareReplyToFeed) {
    lastShareReplyToFeed = shareReplyToFeed;
    state = state.copyWith(shareReplyToFeed: shareReplyToFeed);
  }
}

class _TestVideoReplyContextNotifier extends VideoReplyContextNotifier {
  _TestVideoReplyContextNotifier(this._initialState);

  final VideoReplyContext? _initialState;

  @override
  VideoReplyContext? build() => _initialState;
}
