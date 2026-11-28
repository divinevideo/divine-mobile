import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart'
    show
        AudioEvent,
        AudioExternalSource,
        AudioLicenseMetadata,
        ClipSourceCredit,
        VineSound;
import 'package:openvine/collab_room/collab_room_providers.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/publishing_ideas/publishing_ideas.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_caption_field.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_credits.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_collaborators_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_content_warning_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_expiration_selector.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_inspired_by_input.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_selector.dart';

import 'package:pro_image_editor/pro_image_editor.dart';

import '../../helpers/test_provider_overrides.dart';

void main() {
  group(VideoMetadataFormFields, () {
    Widget buildWidget({
      VideoEditorProviderState? state,
      bool enableTags = true,
      bool enableExpiration = true,
      bool enableContentWarning = true,
      bool enableCollaborators = true,
      bool enableInspiredBy = true,
      bool enableSchedule = true,
      bool enableIdeas = false,
      bool publishingIdeasEnabled = false,
      VideoReplyContext? replyContext,
      String? collabRoomId,
      List<ClipSourceCredit> clipCredits = const [],
    }) {
      return ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(
            createMockAuthService(currentPublicKeyHex: _viewer),
          ),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(
              state ?? VideoEditorProviderState(),
              clipCredits: clipCredits,
            ),
          ),
          isFeatureEnabledProvider(
            FeatureFlag.publishingIdeas,
          ).overrideWithValue(publishingIdeasEnabled),
          videoReplyContextProvider.overrideWith(
            () => _TestVideoReplyContextNotifier(replyContext),
          ),
          collabRoomPostProvider.overrideWith(
            () => _TestCollabRoomPostNotifier(collabRoomId),
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
                enableSchedule: enableSchedule,
                enableIdeas: enableIdeas,
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
          overrides: [
            authServiceProvider.overrideWithValue(createMockAuthService()),
            videoEditorProvider.overrideWith(() => mockNotifier),
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
          overrides: [
            authServiceProvider.overrideWithValue(createMockAuthService()),
            videoEditorProvider.overrideWith(() => mockNotifier),
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

      final descField = find.byWidgetPredicate(
        (w) => w is DivineTextField && w.labelText == 'Description',
      );
      await tester.enterText(descField, 'A description');
      await tester.pumpAndSettle();

      expect(mockNotifier.lastDescription, equals('A description'));
    });

    group('post time tile (#3538)', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      double gapBetweenExpirationAndCollaborators(WidgetTester tester) {
        Rect boxOf(Finder child) => tester.getRect(
          find.ancestor(of: child, matching: find.byType(ClipRRect)).first,
        );
        final expiration = boxOf(find.byType(VideoMetadataExpirationSelector));
        final collaborators = boxOf(
          find.byType(VideoMetadataCollaboratorsInput),
        );
        return collaborators.top - expiration.bottom;
      }

      testWidgets('renders when scheduling is on', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoMetadataScheduleLabel), findsOneWidget);
      });

      testWidgets('hides when enableSchedule is false', (tester) async {
        await tester.pumpWidget(buildWidget(enableSchedule: false));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoMetadataScheduleLabel), findsNothing);
      });

      testWidgets('hides for a video reply without leaving a gap', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            replyContext: const VideoReplyContext(
              rootEventId: 'root-id',
              rootEventKind: 34236,
              rootAuthorPubkey: 'root-author',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoMetadataScheduleLabel), findsNothing);
        expect(gapBetweenExpirationAndCollaborators(tester), equals(16));
      });

      testWidgets('hides for a Together post without leaving a gap', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget(collabRoomId: 'f' * 32));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoMetadataScheduleLabel), findsNothing);
        expect(gapBetweenExpirationAndCollaborators(tester), equals(16));
      });
    });

    testWidgets('hides tags section when enableTags is false', (tester) async {
      await tester.pumpWidget(buildWidget(enableTags: false));
      await tester.pumpAndSettle();

      expect(find.text('Tags'), findsNothing);
    });

    testWidgets(
      'keeps the regular gap above tags while publishing ideas are off',
      (tester) async {
        await tester.pumpWidget(buildWidget(enableIdeas: true));
        await tester.pumpAndSettle();

        final descriptionBottom = tester
            .getBottomLeft(find.byType(VideoMetadataCaptionField))
            .dy;
        final tagsTop = tester
            .getTopLeft(find.byType(VideoMetadataTagsSelector))
            .dy;

        expect(tagsTop - descriptionBottom, moreOrLessEquals(16));
      },
    );

    testWidgets(
      'ignores the publishing ideas flag when enableIdeas is false',
      (tester) async {
        await tester.pumpWidget(buildWidget(publishingIdeasEnabled: true));
        await tester.pumpAndSettle();

        expect(find.byType(PublishingIdeas), findsNothing);
      },
    );

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
            authServiceProvider.overrideWithValue(createMockAuthService()),
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

    testWidgets('leaves out the reply visibility toggle when not a reply', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.text(l10n.videoMetadataShareReplyToFeedTitle), findsNothing);
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

    testWidgets('audio reuse is locked off by a later restricted track', (
      tester,
    ) async {
      AudioEvent providerSound(bool allowsDerivatives) => AudioEvent(
        id: 'external_provider_sound_$allowsDerivatives',
        pubkey: AudioEvent.externalProviderMarker,
        createdAt: 1700000000,
        externalSource: AudioExternalSource(
          provider: 'catalog',
          providerSoundId: '$allowsDerivatives',
          providerName: 'Catalog',
          sourceUrl: 'https://example.com/sound',
          previewUrl: 'https://example.com/preview.mp3',
          license: AudioLicenseMetadata(
            type: 'test',
            name: 'Test',
            url: 'https://example.com/terms',
            allowsCommercialUse: false,
            allowsDerivatives: allowsDerivatives,
            requiresAttribution: false,
          ),
        ),
      );
      await tester.pumpWidget(
        buildWidget(
          state: VideoEditorProviderState(
            allowAudioReuse: true,
            editorEditingParameters:
                CompleteParameters.fromMap(<String, dynamic>{}).copyWith(
                  meta: {
                    VideoEditorConstants.audioStateHistoryKey: [
                      providerSound(true).toJson(),
                      providerSound(false).toJson(),
                    ],
                  },
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(VideoMetadataFormFields)),
      );
      final tile = tester.widget<DivineSwitchTile>(
        find.widgetWithText(DivineSwitchTile, l10n.soundAllowRemix),
      );
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNull);
      expect(tile.subtitle, l10n.soundCreditOnly);
    });

    group('clip credits', () {
      double gapBetweenInspiredByAndContentWarning(WidgetTester tester) {
        Rect boxOf(Finder child) => tester.getRect(
          find.ancestor(of: child, matching: find.byType(ClipRRect)).first,
        );
        final inspiredBy = boxOf(find.byType(VideoMetadataInspiredByInput));
        final contentWarning = boxOf(
          find.byType(VideoMetadataContentWarningSelector),
        );
        return contentWarning.top - inspiredBy.bottom;
      }

      testWidgets('keeps the normal gap when no other creator is credited', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(gapBetweenInspiredByAndContentWarning(tester), equals(16));
        expect(find.byType(VideoMetadataClipCredits), findsNothing);
      });

      testWidgets('keeps the normal gap when only the viewer is credited', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(clipCredits: [_credit(_viewer)]),
        );
        await tester.pumpAndSettle();

        expect(gapBetweenInspiredByAndContentWarning(tester), equals(16));
        expect(find.byType(VideoMetadataClipCredits), findsNothing);
      });

      testWidgets('shows the credit row when another creator is credited', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(clipCredits: [_credit(_author)]),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(VideoMetadataFormFields)),
        );
        expect(find.byType(VideoMetadataClipCredits), findsOneWidget);
        expect(
          find.textContaining(
            l10n.videoMetadataClipCreditRow('').trim(),
          ),
          findsOneWidget,
        );
      });
    });

    group('video reuse toggle', () {
      testWidgets('starts on and turns off when tapped', (tester) async {
        final mockNotifier = _MockVideoEditorNotifier(
          VideoEditorProviderState(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(createMockAuthService()),
              videoEditorProvider.overrideWith(() => mockNotifier),
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
          l10n.videoMetadataVideoReuseTitle,
        );
        expect(tester.widget<DivineSwitchTile>(tile).value, isTrue);

        await tester.ensureVisible(tile);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: tile, matching: find.byType(Switch)),
        );
        await tester.pumpAndSettle();

        expect(mockNotifier.lastAllowVideoReuse, isFalse);
        expect(tester.widget<DivineSwitchTile>(tile).value, isFalse);
      });

      testWidgets('is locked off when the sound forbids derivatives', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            state: VideoEditorProviderState(
              selectedSound: AudioEvent(
                id: 'external_provider_freesound_42',
                pubkey: AudioEvent.externalProviderMarker,
                createdAt: 1700000000,
                externalSource: AudioExternalSource(
                  provider: 'freesound',
                  providerSoundId: '42',
                  providerName: 'Freesound',
                  sourceUrl: 'https://freesound.org/s/42',
                  previewUrl: 'https://cdn.example.com/42.mp3',
                  license: AudioLicenseMetadata(
                    type: 'cc-by-nd',
                    name: 'CC BY-ND 4.0',
                    url: 'https://creativecommons.org/licenses/by-nd/4.0/',
                    allowsCommercialUse: true,
                    allowsDerivatives: false,
                    requiresAttribution: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(VideoMetadataFormFields)),
        );
        final tile = tester.widget<DivineSwitchTile>(
          find.widgetWithText(
            DivineSwitchTile,
            l10n.videoMetadataVideoReuseTitle,
          ),
        );
        expect(tile.value, isFalse);
        expect(tile.onChanged, isNull);
        expect(
          tile.subtitle,
          equals(l10n.videoMetadataVideoReuseSoundLicenseSubtitle),
        );
      });
    });
  });
}

const _viewer =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _author =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

ClipSourceCredit _credit(String author) =>
    ClipSourceCredit.fromAddressableId(addressableId: '34236:$author:clip');

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.clipCredits = const []});

  final VideoEditorProviderState _state;
  final List<ClipSourceCredit> clipCredits;

  @override
  List<ClipSourceCredit> get clipSourceCredits => clipCredits;

  String? lastTitle;
  String? lastDescription;
  bool? lastShareReplyToFeed;
  bool? lastAllowVideoReuse;

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

  @override
  void setAllowVideoReuse(bool allowVideoReuse) {
    lastAllowVideoReuse = allowVideoReuse;
    state = state.copyWith(allowVideoReuse: allowVideoReuse);
  }
}

class _TestCollabRoomPostNotifier extends CollabRoomPostNotifier {
  _TestCollabRoomPostNotifier(this._initialRoomId);

  final String? _initialRoomId;

  @override
  String? build() => _initialRoomId;
}

class _TestVideoReplyContextNotifier extends VideoReplyContextNotifier {
  _TestVideoReplyContextNotifier(this._initialState);

  final VideoReplyContext? _initialState;

  @override
  VideoReplyContext? build() => _initialState;
}
