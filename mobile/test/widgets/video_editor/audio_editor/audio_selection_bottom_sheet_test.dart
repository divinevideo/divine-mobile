// ABOUTME: Tests for AudioSelectionBottomSheet widget
// ABOUTME: Validates rendering of category bar, sounds, loading and
// ABOUTME: error states with mocked sound providers.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/config/official_accounts.dart' show kHqPubkeyHex;
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/paged_sounds.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/audio_file_picker_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:sound_service/sound_service.dart';
import 'package:sounds_repository/sounds_repository.dart' show RankedSounds;

AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
  List<String> publicTags = const [],
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration ?? 5.0,
    publicTags: publicTags,
  );
}

/// [createdAt] for a sound published [age] ago.
int _publishedAgo(Duration age) =>
    DateTime.now().subtract(age).millisecondsSinceEpoch ~/ 1000;

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

class _MockAudioFilePickerService extends Mock
    implements AudioFilePickerService {}

/// A playback service that answers every call the selection overlay makes,
/// so a test can assert on selection rather than on playback plumbing.
_MockAudioPlaybackService _stubbedAudioService() {
  final service = _MockAudioPlaybackService();
  when(
    () => service.positionStream,
  ).thenAnswer((_) => const Stream<Duration>.empty());
  when(
    () => service.durationStream,
  ).thenAnswer((_) => const Stream<Duration?>.empty());
  when(
    () => service.headphonesConnectedStream,
  ).thenAnswer((_) => const Stream<bool>.empty());
  when(() => service.duration).thenReturn(null);
  when(() => service.isPlaying).thenReturn(false);
  when(
    () => service.playingStream,
  ).thenAnswer((_) => const Stream<bool>.empty());
  when(
    () => service.loadAudio(any()),
  ).thenAnswer((_) async => const Duration(seconds: 5));
  when(() => service.seek(Duration.zero)).thenAnswer((_) async {});
  when(service.play).thenAnswer((_) async {});
  when(service.pause).thenAnswer((_) async {});
  when(service.stop).thenAnswer((_) async {});
  when(service.dispose).thenAnswer((_) async {});
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(AudioSelectionBottomSheet, () {
    late ScrollController scrollController;

    setUp(() {
      scrollController = ScrollController();
    });

    tearDown(() {
      scrollController.dispose();
    });

    Widget buildWidget({
      AsyncValue<List<AudioEvent>>? trendingSoundsAsync,
      List<List<AudioEvent>> newestPagesToLoad = const [],
      List<String>? loadedPages,
      List<AudioEvent> savedSounds = const [],
      List<SavedSound> savedSoundRecords = const [],
      Set<String> missingFileSoundIds = const {},
      List<VineSound> bundledSounds = const [],
      AudioPlaybackService? audioService,
      String? viewerPubkey,
      Map<String, int>? usageCounts,
      Map<String, SoundCover?>? covers,
      bool coversPending = false,
      bool coversFail = false,
      Completer<Map<String, SoundCover?>>? forYouCovers,
      List<String>? loadedLists,
      List<AudioEvent> forYouSounds = const [],
      List<List<AudioEvent>> laterForYouPages = const [],
      List<AudioEvent> divineSounds = const [],
      RankedSounds popularSounds = (
        sounds: const <AudioEvent>[],
        usageCounts: const <String, int>{},
      ),
      Map<String, List<AudioEvent>> searchResults = const {},
      List<String>? relaySearches,
      AudioEvent? consentSound,
      bool? consentResult,
      Completer<bool>? pendingConsent,
      AudioFilePickerService? audioFilePicker,
    }) {
      final savedSoundsBloc = _MockSavedSoundsBloc();
      when(() => savedSoundsBloc.state).thenReturn(
        SavedSoundsState(
          status: SavedSoundsStatus.loaded,
          sounds: [
            ...savedSounds.map(
              (sound) => SavedSound(
                audio: sound,
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
              ),
            ),
            ...savedSoundRecords,
          ],
          missingFileSoundIds: missingFileSoundIds,
        ),
      );
      return BlocProvider<SavedSoundsBloc>.value(
        value: savedSoundsBloc,
        child: ProviderScope(
          overrides: [
            // `audioReuseConsentProvider` reads the viewer so it can grant a
            // creator consent for their own sound.
            authServiceProvider.overrideWithValue(
              _StubAuthService(viewerPubkey),
            ),
            audioReuseConsentProvider.overrideWith(
              (ref, sound) async {
                if (pendingConsent != null) return pendingConsent.future;
                if (sound.hasExplicitReuseConsent && !sound.allowsReuse) {
                  return false;
                }
                return sound.id != consentSound?.id || (consentResult ?? true);
              },
            ),
            if (audioFilePicker != null)
              audioFilePickerServiceProvider.overrideWithValue(audioFilePicker),
            soundLibraryServiceProvider.overrideWith(
              (_) async => _FakeSoundLibraryService(bundledSounds),
            ),
            if (trendingSoundsAsync != null)
              trendingSoundsProvider.overrideWith(
                () => _FakeTrendingSounds(
                  trendingSoundsAsync,
                  pagesToLoad: newestPagesToLoad,
                  loadedPages: loadedPages,
                ),
              ),
            if (usageCounts != null)
              trendingSoundUsageCountsProvider.overrideWith(
                (_) async => usageCounts,
              ),
            if (covers != null)
              trendingSoundCoversProvider.overrideWith((_) async => covers),
            if (coversPending)
              trendingSoundCoversProvider.overrideWith(
                (_) => Completer<Map<String, SoundCover?>>().future,
              ),
            if (coversFail)
              trendingSoundCoversProvider.overrideWith(
                (_) async => throw Exception('relay down'),
              ),
            // Always overridden: the real ones read the follow list and
            // Funnelcake, neither of which a widget test should reach.
            forYouSoundsProvider.overrideWithBuild(
              (_, _) async =>
                  PagedSounds(pages: [forYouSounds, ...laterForYouPages]),
            ),
            divineSoundsProvider.overrideWith((_) async => divineSounds),
            popularSoundsProvider.overrideWithBuild((_, _) async {
              loadedLists?.add('popular');
              return PagedSounds(
                pages: [popularSounds.sounds],
                usageCounts: popularSounds.usageCounts,
              );
            }),
            if (forYouCovers != null)
              forYouSoundCoversProvider.overrideWith(
                (_) => forYouCovers.future,
              ),
            // Always overridden: without it a keystroke would build the real
            // repository, and with it a Nostr client, inside a widget test.
            soundSearchResultsProvider.overrideWith((ref, query) async {
              if (query.isNotEmpty) relaySearches?.add(query);
              return searchResults[query] ?? const [];
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AudioSelectionBottomSheet(
                scrollController: scrollController,
                audioService: audioService,
              ),
            ),
          ),
        ),
      );
    }

    final testSounds = [
      _createTestAudioEvent(id: 'sound-1', title: 'Alpha Track'),
      _createTestAudioEvent(id: 'sound-2', title: 'Beta Song'),
      _createTestAudioEvent(id: 'sound-3', title: 'Gamma Beat'),
    ];

    group('layout', () {
      test('takes either the sheet controller or an embedding callback', () {
        expect(AudioSelectionBottomSheet.new, throwsAssertionError);
        expect(
          () => AudioSelectionBottomSheet(
            scrollController: ScrollController(),
            onSoundPicked: (_) {},
          ),
          throwsAssertionError,
        );
      });

      test('takes a category bar leading only when embedded', () {
        expect(
          () => AudioSelectionBottomSheet(
            scrollController: ScrollController(),
            categoryBarLeading: const SizedBox(),
          ),
          throwsAssertionError,
        );
        expect(
          () => AudioSelectionBottomSheet(
            onSoundPicked: (_) {},
            categoryBarLeading: const SizedBox(),
          ),
          returnsNormally,
        );
      });
    });

    group('Rendering', () {
      testWidgets('renders $AudioSelectionBottomSheet', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
      });

      testWidgets('leads My Sounds with the import action', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoEditorAudioImportAudio), findsNothing);

        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorAudioImportAudio), findsOneWidget);
      });

      testWidgets('offers importing when a search finds nothing', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'nothing like it');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('audio_search_import')), findsOneWidget);
      });

      testWidgets('places the search above the list tabs', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getTopLeft(find.byType(TextField).first).dy,
          lessThan(tester.getTopLeft(find.byType(AudioCategoryBar)).dy),
        );
      });

      testWidgets('imports through the app audio picker', (tester) async {
        final picker = _MockAudioFilePickerService();
        when(
          () => picker.pickAudioFile(
            typeGroupLabel: any(named: 'typeGroupLabel'),
          ),
        ).thenAnswer((_) async => null);
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            audioFilePicker: picker,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioImportAudio));
        await tester.pumpAndSettle();

        verify(
          () => picker.pickAudioFile(
            typeGroupLabel: any(named: 'typeGroupLabel'),
          ),
        ).called(1);
      });

      testWidgets('renders $AudioCategoryBar with all category chips', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(AudioCategoryBar), findsOneWidget);
        expect(find.text(l10n.exploreTabForYou), findsWidgets);
        expect(find.text(l10n.exploreTabPopular), findsWidgets);
        expect(find.text(l10n.exploreTabNew), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryMySounds), findsWidgets);
      });
    });

    group('Reuse counts', () {
      // A picker row's count has to come from the one batched query the sheet
      // runs for the whole community list; a per-row provider watch would fan
      // out one relay COUNT per row.
      const communitySoundId =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

      testWidgets('shows the batched count on a community sound', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(id: communitySoundId, title: 'Alpha Track'),
            ]),
            usageCounts: const {communitySoundId: 9},
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Alpha Track'), findsOneWidget);
        expect(find.textContaining(l10n.soundVideoCount(9)), findsOneWidget);
      });

      testWidgets('lists community sounds before any count resolves', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(id: communitySoundId, title: 'Alpha Track'),
            ]),
            usageCounts: const {},
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Alpha Track'), findsOneWidget);
        expect(find.textContaining(l10n.soundVideoCount(9)), findsNothing);
      });
    });

    group('Covers', () {
      const sourceVideo =
          '34236:a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012:clip';
      const coverUrl = 'https://example.com/clip.jpg';

      Iterable<String?> shownCoverUrls(WidgetTester tester) => tester
          .widgetList<VineCachedImage>(find.byType(VineCachedImage))
          .map((image) => image.imageUrl);

      testWidgets('leads a community sound with the video it came from', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'community-sound',
                title: 'Original sound',
              ).copyWith(sourceVideoReference: sourceVideo),
            ]),
            covers: const {sourceVideo: SoundCover(imageUrl: coverUrl)},
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(shownCoverUrls(tester), [coverUrl]);
      });

      testWidgets('leaves out a sound whose video is gone', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'alive',
                title: 'Video still there',
              ).copyWith(sourceVideoReference: sourceVideo),
              _createTestAudioEvent(
                id: 'gone',
                title: 'Video deleted',
              ).copyWith(sourceVideoReference: '$sourceVideo-deleted'),
              _createTestAudioEvent(id: 'standalone', title: 'Standalone'),
            ]),
            covers: const {
              sourceVideo: SoundCover(imageUrl: coverUrl),
              '$sourceVideo-deleted': null,
            },
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Video still there'), findsOneWidget);
        expect(find.text('Standalone'), findsOneWidget);
        expect(find.text('Video deleted'), findsNothing);
      });

      testWidgets('keeps every sound when the video lookup fails', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'gone',
                title: 'Video deleted',
              ).copyWith(sourceVideoReference: '$sourceVideo-deleted'),
            ]),
            coversFail: true,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Video deleted'), findsOneWidget);
      });

      testWidgets('waits on a plain tile only for sounds with a video', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'from-video',
                title: 'From a video',
              ).copyWith(sourceVideoReference: sourceVideo),
              _createTestAudioEvent(id: 'standalone', title: 'Standalone'),
            ]),
            coversPending: true,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        Finder inRow(String title, Key key) => find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(AudioListTile),
          ),
          matching: find.byKey(key),
        );
        expect(
          inRow('From a video', const Key('sound_cover_pending')),
          findsOneWidget,
        );
        expect(
          inRow('Standalone', const Key('sound_cover_fallback')),
          findsOneWidget,
        );
      });

      Future<void> pumpPublishedCover(WidgetTester tester, String url) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'community-sound',
                title: 'Kitchen beat',
              ).copyWith(sourceVideoReference: sourceVideo, imageUrl: url),
            ]),
            covers: const {sourceVideo: SoundCover(imageUrl: coverUrl)},
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
      }

      testWidgets('prefers the cover a sound was published with', (
        tester,
      ) async {
        const ownCover = 'https://media.divine.video/own-cover';
        await pumpPublishedCover(tester, ownCover);

        expect(shownCoverUrls(tester), [ownCover]);
      });

      testWidgets('shows the video instead of a cover stored elsewhere', (
        tester,
      ) async {
        await pumpPublishedCover(tester, 'https://example.com/own-cover.jpg');

        expect(shownCoverUrls(tester), [coverUrl]);
      });

      testWidgets('leads a saved sound with the video it was saved from', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            savedSoundRecords: [
              SavedSound(
                audio: _createTestAudioEvent(
                  id: 'saved-sound',
                  title: 'Saved Track',
                ),
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
                sourceContext: const SavedSoundSourceContext(
                  thumbnailUrl: coverUrl,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Saved Track'), findsOneWidget);
        expect(shownCoverUrls(tester), [coverUrl]);
      });
    });

    group('For you', () {
      testWidgets('ranks a sound a followed person shared today above '
          'Divine sounds, and an old one below them', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: [
              _createTestAudioEvent(
                id: 'old',
                title: 'Old beat',
                createdAt: _publishedAgo(const Duration(days: 60)),
              ),
              _createTestAudioEvent(
                id: 'fresh',
                title: 'Fresh beat',
                createdAt: _publishedAgo(const Duration(hours: 1)),
              ),
            ],
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        double top(String title) => tester.getTopLeft(find.text(title)).dy;
        expect(top('Fresh beat'), lessThan(top('Wednesday My Dudes')));
        expect(top('Wednesday My Dudes'), lessThan(top('Old beat')));
      });

      testWidgets('shows a shipped sound once though Divine published it, '
          'and a published one the app does not ship, neither badged', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
              ),
            ],
            divineSounds: [
              AudioEvent(
                id: 'a' * 64,
                pubkey: kHqPubkeyHex,
                createdAt: 1704067200,
                url: 'https://example.com/wednesday.mp3',
                title: 'Wednesday My Dudes',
                divineSoundId: 'wednesday',
              ),
              AudioEvent(
                id: 'b' * 64,
                pubkey: kHqPubkeyHex,
                createdAt: 1704067200,
                url: 'https://example.com/fresh.mp3',
                title: 'Fresh from Divine',
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
        expect(find.text('Fresh from Divine'), findsOneWidget);
        expect(find.byKey(const Key('audio_community_badge')), findsNothing);
        final shipped = tester.widget<AudioListTile>(
          find.ancestor(
            of: find.text('Wednesday My Dudes'),
            matching: find.byType(AudioListTile),
          ),
        );
        expect(shipped.audio.isBundled, isTrue);
        expect(shipped.audio.attributionEventId, 'a' * 64);
      });

      testWidgets('badges community sounds but not Divine sounds', (
        tester,
      ) async {
        const communityId =
            'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: [
              _createTestAudioEvent(id: communityId, title: 'Followed beat'),
            ],
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final badge = find.byKey(const Key('audio_community_badge'));
        expect(badge, findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Followed beat'),
              matching: find.byType(AudioListTile),
            ),
            matching: badge,
          ),
          findsOneWidget,
        );
      });
    });

    group('Kind filter', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      /// Picks [label] from the filter pill's menu; the pill itself shows the
      /// current kind's label, so the menu's is the last one.
      Future<void> pickKind(WidgetTester tester, String label) async {
        await tester.tap(find.byKey(const Key('audio_kind_filter')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
      }

      final forYouSounds = [
        _createTestAudioEvent(
          id: 'song',
          title: 'Tagged song',
          publicTags: const ['Music'],
        ),
        _createTestAudioEvent(
          id: 'boom',
          title: 'Tagged boom',
          publicTags: const ['sfx'],
        ),
        _createTestAudioEvent(id: 'untagged', title: 'Untagged clip'),
      ];
      final bundledSounds = [
        VineSound(
          id: 'theme',
          title: 'Divine theme',
          assetPath: 'assets/sounds/theme.mp3',
          duration: const Duration(seconds: 6),
          tags: const ['music'],
        ),
        VineSound(
          id: 'wednesday',
          title: 'Wednesday My Dudes',
          assetPath: 'assets/sounds/wednesday.mp3',
          duration: const Duration(milliseconds: 6269),
        ),
      ];

      testWidgets('shows every sound until a kind is picked', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: forYouSounds,
            bundledSounds: bundledSounds,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.libraryFilterAll), findsOneWidget);
        expect(find.byType(AudioListTile), findsNWidgets(5));
      });

      testWidgets('Effects keeps only sounds tagged or bundled as effects', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: forYouSounds,
            bundledSounds: bundledSounds,
          ),
        );
        await tester.pumpAndSettle();

        await pickKind(tester, l10n.videoEditorAudioFilterEffects);

        expect(find.text('Tagged boom'), findsOneWidget);
        expect(find.text('Wednesday My Dudes'), findsOneWidget);
        expect(find.text('Tagged song'), findsNothing);
        expect(find.text('Divine theme'), findsNothing);
        expect(find.text('Untagged clip'), findsNothing);
      });

      testWidgets('Music keeps only music, and All brings the rest back', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: forYouSounds,
            bundledSounds: bundledSounds,
          ),
        );
        await tester.pumpAndSettle();

        await pickKind(tester, l10n.categoryMusic);

        expect(find.text('Tagged song'), findsOneWidget);
        expect(find.text('Divine theme'), findsOneWidget);
        expect(find.byType(AudioListTile), findsNWidgets(2));

        await pickKind(tester, l10n.libraryFilterAll);

        expect(find.byType(AudioListTile), findsNWidgets(5));
      });

      testWidgets('narrows My Sounds as well', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            savedSounds: [
              _createTestAudioEvent(
                id: 'saved-song',
                title: 'Saved song',
                publicTags: const ['music'],
              ),
              _createTestAudioEvent(
                id: 'saved-boom',
                title: 'Saved boom',
                publicTags: const ['effect'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await pickKind(tester, l10n.videoEditorAudioFilterEffects);
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Saved boom'), findsOneWidget);
        expect(find.text('Saved song'), findsNothing);
      });

      testWidgets('narrows New as well', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              _createTestAudioEvent(
                id: 'new-song',
                title: 'New song',
                publicTags: const ['music'],
              ),
              _createTestAudioEvent(id: 'new-clip', title: 'New clip'),
            ]),
          ),
        );
        await tester.pumpAndSettle();

        await pickKind(tester, l10n.categoryMusic);
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('New song'), findsOneWidget);
        expect(find.text('New clip'), findsNothing);
      });

      testWidgets('says nothing matched, without a search hint, when a kind '
          'empties a list', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: [forYouSounds.first],
          ),
        );
        await tester.pumpAndSettle();

        await pickKind(tester, l10n.videoEditorAudioFilterEffects);

        expect(find.byType(AudioListTile), findsNothing);
        expect(find.text(l10n.soundsNoSoundsFound), findsOneWidget);
        expect(find.text(l10n.soundsNoSoundsFoundDescription), findsNothing);
      });
    });

    group('Loading order', () {
      testWidgets('loads the other lists once the open list has its covers', (
        tester,
      ) async {
        final forYouCovers = Completer<Map<String, SoundCover?>>();
        final loadedLists = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouCovers: forYouCovers,
            loadedLists: loadedLists,
          ),
        );
        await tester.pump();

        expect(loadedLists, isEmpty);

        forYouCovers.complete(const {});
        await tester.pumpAndSettle();

        expect(loadedLists, ['popular']);
      });
    });

    group('Popular', () {
      testWidgets('lists popular sounds with their reuse counts', (
        tester,
      ) async {
        const popularId =
            'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            popularSounds: (
              sounds: [_createTestAudioEvent(id: popularId, title: 'Hit')],
              usageCounts: const {popularId: 28},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabPopular));
        await tester.pumpAndSettle();

        expect(find.text('Hit'), findsOneWidget);
        expect(find.textContaining(l10n.soundVideoCount(28)), findsOneWidget);
      });
    });

    group('Loading more', () {
      final lateSound = _createTestAudioEvent(
        id: 'late',
        title: 'Late arrival',
      );

      testWidgets('loads the next page once the list is scrolled to its end', (
        tester,
      ) async {
        final loadedPages = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([
              for (var i = 0; i < 30; i++)
                _createTestAudioEvent(id: 'sound-$i', title: 'Sound $i'),
            ]),
            newestPagesToLoad: [
              [lateSound],
            ],
            loadedPages: loadedPages,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        expect(loadedPages, isEmpty);

        await tester.drag(find.text('Sound 3'), const Offset(0, -4000));
        await tester.pumpAndSettle();

        expect(loadedPages, ['Late arrival']);
        expect(find.text('Late arrival'), findsOneWidget);
      });

      testWidgets('keeps asking while a page adds nothing to show', (
        tester,
      ) async {
        final loadedPages = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            newestPagesToLoad: [
              const [],
              [lateSound],
            ],
            loadedPages: loadedPages,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(loadedPages, ['', 'Late arrival']);
        expect(find.text('Late arrival'), findsOneWidget);
      });

      testWidgets('waits while a search orders the list by fit', (
        tester,
      ) async {
        final loadedPages = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            newestPagesToLoad: [
              [lateSound],
            ],
            loadedPages: loadedPages,
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'beta');
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Beta Song'), findsOneWidget);
        expect(loadedPages, isEmpty);

        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        expect(loadedPages, ['Late arrival']);
      });

      testWidgets('waits while a kind narrows the list', (tester) async {
        final loadedPages = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            newestPagesToLoad: [
              [lateSound],
            ],
            loadedPages: loadedPages,
          ),
        );
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        Future<void> pickKind(String label) async {
          await tester.tap(find.byKey(const Key('audio_kind_filter')));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
        }

        // Picked before New's list is built, so it never asks unnarrowed.
        await pickKind(l10n.videoEditorAudioFilterEffects);
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(loadedPages, isEmpty);

        await pickKind(l10n.libraryFilterAll);

        expect(loadedPages, ['Late arrival']);
      });

      testWidgets('ranks a later For you page after the rows above it', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: const AsyncValue.data([]),
            forYouSounds: [
              _createTestAudioEvent(
                id: 'fresh',
                title: 'Fresh beat',
                createdAt: _publishedAgo(const Duration(hours: 1)),
              ),
            ],
            // Ranked in with the first page, a day-old sound would come
            // before the second Divine sound.
            laterForYouPages: [
              [
                _createTestAudioEvent(
                  id: 'yesterday',
                  title: 'Yesterday beat',
                  createdAt: _publishedAgo(const Duration(days: 1)),
                ),
              ],
            ],
            bundledSounds: [
              for (final title in ['Wednesday My Dudes', 'Thursday Thing'])
                VineSound(
                  id: title,
                  title: title,
                  assetPath: 'assets/sounds/$title.mp3',
                  duration: const Duration(seconds: 6),
                ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        double top(String title) => tester.getTopLeft(find.text(title)).dy;
        expect(top('Fresh beat'), lessThan(top('Wednesday My Dudes')));
        expect(top('Fresh beat'), lessThan(top('Thursday Thing')));
        expect(top('Yesterday beat'), greaterThan(top('Wednesday My Dudes')));
        expect(top('Yesterday beat'), greaterThan(top('Thursday Thing')));
      });
    });

    group('Search', () {
      testWidgets('exposes the E2E identifier on the search field', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final node = tester.getSemantics(
          find.bySemanticsIdentifier(SemanticIds.audioSearchField),
        );
        expect(node.flagsCollection.isTextField, isTrue);

        handle.dispose();
      });

      testWidgets('filters followed and Divine sounds on For you', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            forYouSounds: [
              _createTestAudioEvent(id: 'followed-1', title: 'Wednesday beat'),
              _createTestAudioEvent(id: 'followed-2', title: 'Monday blues'),
            ],
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'wednes');
        await tester.pumpAndSettle();

        expect(find.text('Wednesday beat'), findsOneWidget);
        expect(find.text('Wednesday My Dudes'), findsOneWidget);
        expect(find.text('Monday blues'), findsNothing);
      });

      testWidgets('filters community sounds on community tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'beta');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Beta Song'), findsOneWidget);
        expect(find.text('Alpha Track'), findsNothing);
      });

      testWidgets('filters saved sounds on My Sounds tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSounds: [
              _createTestAudioEvent(id: 'saved-1', title: 'Uh Oh'),
              _createTestAudioEvent(id: 'saved-2', title: 'Victory Lap'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'uh oh');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Uh Oh'), findsOneWidget);
        expect(find.text('Victory Lap'), findsNothing);
      });

      testWidgets('orders For you by fit, a Divine sound first among equals', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            forYouSounds: [
              _createTestAudioEvent(
                id: 'followed-contains',
                title: 'Kaboom',
                createdAt: _publishedAgo(const Duration(hours: 1)),
              ),
              _createTestAudioEvent(
                id: 'followed-prefix',
                title: 'Boom box',
                createdAt: _publishedAgo(const Duration(hours: 1)),
              ),
            ],
            bundledSounds: [
              VineSound(
                id: 'boom-divine',
                title: 'Boom bap',
                assetPath: 'assets/sounds/boom.mp3',
                duration: const Duration(seconds: 3),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'boom');
        await tester.pumpAndSettle();

        double top(String title) => tester.getTopLeft(find.text(title)).dy;
        // Without the search, today's followed sounds would lead.
        expect(top('Boom bap'), lessThan(top('Boom box')));
        expect(top('Boom box'), lessThan(top('Kaboom')));
      });

      testWidgets('orders My Sounds by the label the owner gave', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSoundRecords: [
              SavedSound(
                audio: _createTestAudioEvent(id: 'saved-1', title: 'Clip'),
                personalLabel: 'My drum loop',
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
              ),
              SavedSound(
                audio: _createTestAudioEvent(id: 'saved-2', title: 'Clip 2'),
                personalLabel: 'Drum',
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'drum');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        double top(String title) => tester.getTopLeft(find.text(title)).dy;
        expect(top('Drum'), lessThan(top('My drum loop')));
      });

      testWidgets('finds a community sound by a tag its title omits', (
        tester,
      ) async {
        final tagged = _createTestAudioEvent(
          id: 'sound-4',
          title: 'Field recording 04',
        ).copyWith(publicTags: const ['horses', 'hooves']);

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([...testSounds, tagged]),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'hooves');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text('Field recording 04'), findsOneWidget);
        expect(find.text('Alpha Track'), findsNothing);
      });

      testWidgets('reaches past the loaded page once the query settles', (
        tester,
      ) async {
        final offPage = _createTestAudioEvent(
          id: 'sound-off-page',
          title: 'Crowd ambience',
        );

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            searchResults: {
              'crowd': [offPage],
            },
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'crowd');
        await tester.pumpAndSettle();

        expect(
          find.text('Crowd ambience'),
          findsNothing,
          reason:
              'nothing on the loaded page matches, and the relay has not '
              'been asked yet',
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text('Crowd ambience'), findsOneWidget);
      });

      testWidgets('keeps loaded matches on screen while the query settles', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'beta');
        await tester.pump();

        expect(
          find.text('Beta Song'),
          findsOneWidget,
          reason:
              'the list narrows on the first keystroke rather than '
              'blanking until the debounced search answers',
        );
        expect(find.text('Alpha Track'), findsNothing);
      });

      testWidgets('finds a saved sound by the label its owner gave it', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSoundRecords: [
              SavedSound(
                audio: _createTestAudioEvent(
                  id: 'saved-1',
                  title: 'Original sound',
                ),
                personalLabel: 'Horses hooves',
                personalHashtags: const ['foley'],
                catalogTags: const [],
                waveformSamples: const [],
              ),
              SavedSound(
                audio: _createTestAudioEvent(
                  id: 'saved-2',
                  title: 'Victory Lap',
                ),
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'hooves');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Horses hooves'), findsOneWidget);
        expect(find.text('Victory Lap'), findsNothing);
      });

      testWidgets('warns when the search text holds a private key', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField).first,
          'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.searchPrivateKeyWarning), findsOneWidget);
      });

      testWidgets('keeps a saved-sounds search off the relays', (tester) async {
        // Private labels are the words a user reaches for on this tab, and
        // only the Community tab shows relay results, so a query typed here
        // must not go out as a `#t` filter.
        final relaySearches = <String>[];
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            relaySearches: relaySearches,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).first, 'hooves');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(relaySearches, isEmpty);

        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(relaySearches, equals(['hooves']));
      });

      testWidgets('titles a saved row with its label, not the published name', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSoundRecords: [
              SavedSound(
                audio: _createTestAudioEvent(
                  id: 'saved-1',
                  title: 'Original sound',
                ),
                personalLabel: 'Horses hooves',
                personalHashtags: const [],
                catalogTags: const [],
                waveformSamples: const [],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Horses hooves'), findsOneWidget);
        expect(find.text('Original sound'), findsNothing);
      });

      testWidgets('does not select a sound that forbids reuse', (tester) async {
        final forbiddenSound = _createTestAudioEvent(
          id: 'forbidden-sound',
          title: 'Credit only',
        );
        final explicitForbidden = forbiddenSound.copyWith(
          allowsReuse: false,
          hasExplicitReuseConsent: true,
        );

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([explicitForbidden]),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Credit only'));
        await tester.pumpAndSettle();

        expect(find.byType(AudioEditorSelectionOverlay), findsNothing);
      });

      testWidgets('marks a tapped sound while its reuse check runs, and '
          'unmarks it when the check refuses', (tester) async {
        final consent = Completer<bool>();
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            pendingConsent: consent,
            audioService: _stubbedAudioService(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beta Song'));
        await tester.pump();

        AudioListTile tile(String title) => tester.widget<AudioListTile>(
          find.ancestor(
            of: find.text(title),
            matching: find.byType(AudioListTile),
          ),
        );
        expect(tile('Beta Song').isSelected, isTrue);
        expect(
          tester
              .widget<AudioEditorSelectionOverlay>(
                find.byType(AudioEditorSelectionOverlay),
              )
              .isLoading,
          isTrue,
        );

        consent.complete(false);
        await tester.pumpAndSettle();

        expect(tile('Beta Song').isSelected, isFalse);
        expect(find.byType(AudioEditorSelectionOverlay), findsNothing);
      });

      testWidgets('loads the sound while its reuse check runs', (tester) async {
        final consent = Completer<bool>();
        final audioService = _stubbedAudioService();
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            pendingConsent: consent,
            audioService: audioService,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beta Song'));
        await tester.pump();

        verify(
          () => audioService.loadAudio('https://example.com/audio/sound-2.mp3'),
        ).called(1);
        verifyNever(audioService.play);

        consent.complete(true);
        await tester.pumpAndSettle();

        verify(audioService.play).called(1);
        verifyNever(() => audioService.loadAudio(any()));
      });

      testWidgets('keeps the later pick when an earlier check answers last', (
        tester,
      ) async {
        final consent = Completer<bool>();
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            pendingConsent: consent,
            audioService: _stubbedAudioService(),
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Beta Song'));
        await tester.pump();
        // The overlay spins while the check is open, so nothing settles.
        await tester.tap(find.text(l10n.exploreTabForYou));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(find.text('Wednesday My Dudes'));
        await tester.pumpAndSettle();

        consent.complete(true);
        await tester.pumpAndSettle();

        final overlay = tester.widget<AudioEditorSelectionOverlay>(
          find.byType(AudioEditorSelectionOverlay),
        );
        expect(overlay.audio.title, 'Wednesday My Dudes');
      });

      testWidgets('selects a legacy-policy verified archive original sound', (
        tester,
      ) async {
        final classicVideo = VideoEvent(
          id: 'a' * 64,
          pubkey: 'b' * 64,
          createdAt: 1704067200,
          content: '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
          videoUrl: 'https://example.com/classic.mp4',
          isVerifiedArchive: true,
          archiveAudioReuseEnabled: true,
        );
        final classicSound = AudioEvent.fromVideoOriginalSound(
          classicVideo,
          creatorName: 'Classic Creator',
        );

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([classicSound]),
            consentSound: classicSound,
            consentResult: true,
            audioService: _stubbedAudioService(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Original sound - Classic Creator'));
        await tester.pumpAndSettle();

        expect(find.byType(AudioEditorSelectionOverlay), findsOneWidget);
      });

      testWidgets('collapses repeated reuse-blocked toasts into one', (
        tester,
      ) async {
        // Regression (#6769): each blocked tap used to enqueue its own
        // snackbar, so a burst of taps left ~20s of backlog that trailed the
        // user out of the sheet and misattributed itself to whatever sound
        // they picked next.
        final explicitForbidden = _createTestAudioEvent(
          id: 'forbidden-sound',
          title: 'Credit only',
        ).copyWith(allowsReuse: false, hasExplicitReuseConsent: true);

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([explicitForbidden]),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Credit only'));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text(l10n.soundReuseUnavailable), findsOneWidget);

        // One toast's lifetime clears the whole burst rather than the first
        // of three.
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.text(l10n.soundReuseUnavailable), findsNothing);
      });

      testWidgets("selects the creator's own legacy sound", (tester) async {
        const ownerPubkey = 'owner-pubkey-hex';
        final audioService = _MockAudioPlaybackService();
        final ownLegacySound = _createTestAudioEvent(
          id: 'own-legacy-sound',
          title: 'Own Legacy Sound',
          pubkey: ownerPubkey,
        ).copyWith(allowsReuse: false, hasExplicitReuseConsent: false);

        when(() => audioService.isPlaying).thenReturn(false);
        when(
          () => audioService.playingStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(
          () => audioService.durationStream,
        ).thenAnswer((_) => const Stream<Duration?>.empty());
        when(
          () => audioService.positionStream,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(() => audioService.duration).thenReturn(null);
        when(
          () => audioService.seek(Duration.zero),
        ).thenAnswer((_) => Future<void>.value());
        when(audioService.stop).thenAnswer((_) => Future<void>.value());
        when(
          () => audioService.loadAudio(ownLegacySound.url!),
        ).thenAnswer((_) => Future.value(const Duration(seconds: 5)));
        when(audioService.play).thenAnswer((_) => Future<void>.value());
        when(audioService.pause).thenAnswer((_) => Future<void>.value());
        when(audioService.dispose).thenAnswer((_) => Future<void>.value());

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([ownLegacySound]),
            audioService: audioService,
            viewerPubkey: ownerPubkey,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Own Legacy Sound'));
        await tester.pumpAndSettle();

        expect(find.byType(AudioEditorSelectionOverlay), findsOneWidget);
      });

      testWidgets('renders search empty state when no tab matches', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSounds: [
              _createTestAudioEvent(id: 'saved-sound', title: 'Saved Sound'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'not a match');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundsNoSoundsFound), findsOneWidget);
        expect(find.text(l10n.soundsNoSoundsFoundDescription), findsOneWidget);
      });
    });

    group('Loading state', () {
      testWidgets('renders $BrandedLoadingIndicator on community tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.loading()),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
      });

      testWidgets('shows selected-audio loading before stop completes', (
        tester,
      ) async {
        final audioService = _MockAudioPlaybackService();
        final stopCompleter = Completer<void>();
        final sound = _createTestAudioEvent(title: 'Slow Load');
        Future<void> completeImmediately(Invocation _) => Future<void>.value();
        Future<Duration> loadDuration(Invocation _) =>
            Future.value(const Duration(seconds: 5));
        Future<void> waitForStop(Invocation _) => stopCompleter.future;

        when(() => audioService.isPlaying).thenReturn(false);
        when(
          () => audioService.playingStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(
          () => audioService.durationStream,
        ).thenAnswer((_) => const Stream<Duration?>.empty());
        when(
          () => audioService.positionStream,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(() => audioService.duration).thenReturn(null);
        when(
          () => audioService.seek(Duration.zero),
        ).thenAnswer(completeImmediately);
        when(audioService.stop).thenAnswer(waitForStop);
        when(() => audioService.loadAudio(sound.url!)).thenAnswer(loadDuration);
        when(audioService.play).thenAnswer(completeImmediately);
        when(audioService.pause).thenAnswer(completeImmediately);
        when(audioService.dispose).thenAnswer(completeImmediately);

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([sound]),
            audioService: audioService,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Slow Load'));
        await tester.pump();

        expect(find.byType(BrandedLoadingIndicator), findsOneWidget);
        verifyNever(() => audioService.loadAudio(sound.url!));

        stopCompleter.complete();
        await tester.pumpAndSettle();

        verify(() => audioService.loadAudio(sound.url!)).called(1);
      });
    });

    group('Lifecycle', () {
      testWidgets('does not setState after the sheet is disposed mid-preview', (
        tester,
      ) async {
        final audioService = _MockAudioPlaybackService();
        final playCompleter = Completer<void>();
        final sound = _createTestAudioEvent(title: 'Pending Preview');
        Future<void> immediate(Invocation _) => Future<void>.value();
        Future<Duration> loadDuration(Invocation _) =>
            Future.value(const Duration(seconds: 5));
        Future<void> blockOnPlay(Invocation _) => playCompleter.future;

        when(() => audioService.isPlaying).thenReturn(false);
        when(
          () => audioService.playingStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(
          () => audioService.durationStream,
        ).thenAnswer((_) => const Stream<Duration?>.empty());
        when(
          () => audioService.positionStream,
        ).thenAnswer((_) => const Stream<Duration>.empty());
        when(() => audioService.duration).thenReturn(null);
        when(() => audioService.seek(Duration.zero)).thenAnswer(immediate);
        when(audioService.stop).thenAnswer(immediate);
        when(() => audioService.loadAudio(sound.url!)).thenAnswer(loadDuration);
        // Blocks for the whole "playback" so the preview future is still
        // pending when the sheet is torn down.
        when(audioService.play).thenAnswer(blockOnPlay);
        when(audioService.pause).thenAnswer(immediate);
        when(audioService.dispose).thenAnswer(immediate);

        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data([sound]),
            audioService: audioService,
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        // Start the preview; the handler now sits awaiting play().
        await tester.tap(find.text('Pending Preview'));
        await tester.pumpAndSettle();

        // Tear the sheet down while play() is still pending.
        await tester.pumpWidget(const SizedBox.shrink());

        // Resolve the preview after disposal: the finally path awaits
        // pause() then a mounted-guarded setState that must be skipped.
        playCompleter.complete();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });

    group('Empty state', () {
      testWidgets('renders empty state when no bundled sounds available', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoEditorAudioNoSoundsAvailableTitle),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.music_off), findsOneWidget);
      });

      testWidgets('renders bundled Wednesday clip on For you', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            bundledSounds: [
              VineSound(
                id: 'wednesday',
                title: 'Wednesday My Dudes',
                assetPath: 'assets/sounds/wednesday.mp3',
                duration: const Duration(milliseconds: 6269),
                tags: ['meme', 'classic', 'frog'],
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
      });

      testWidgets('renders saved sounds empty state on My Sounds tab', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundsSavedEmptyTitle), findsOneWidget);
        expect(find.text(l10n.soundsSavedEmptyDescription), findsOneWidget);
      });
    });

    group('Error state', () {
      testWidgets('renders error state when community fails', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.error(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.videoEditorAudioFailedToLoadTitle),
          findsOneWidget,
        );
        expect(_divineIcon(DivineIconName.warningCircle), findsOneWidget);
      });

      testWidgets('renders retry button on error state', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.error(
              Exception('network error'),
              StackTrace.current,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.exploreTabNew));
        await tester.pumpAndSettle();

        expect(find.text(l10n.commonRetry), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    });

    group('Initial state', () {
      testWidgets('renders no $AudioListTile while no sounds are loaded', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioListTile), findsNothing);
      });

      testWidgets('says a saved sound whose file is gone cannot be used', (
        tester,
      ) async {
        final audioService = _stubbedAudioService();
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            audioService: audioService,
            savedSounds: [
              _createTestAudioEvent(
                id: 'local_import_gone',
                title: 'Gone Sound',
                url: '/imports/gone.m4a',
              ),
              _createTestAudioEvent(
                id: 'local_import_here',
                title: 'Here Sound',
                url: '/imports/here.m4a',
              ),
            ],
            missingFileSoundIds: const {'local_import_gone'},
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(
          find.text('Gone Sound'),
          findsOneWidget,
          reason:
              'Dropping the row would hide a sound the user knows they '
              'saved; the picker says why instead (#8023).',
        );
        expect(find.text(l10n.videoEditorAudioFileMissing), findsOneWidget);

        await tester.tap(find.text('Gone Sound'));
        await tester.pumpAndSettle();
        expect(
          find.byType(AudioEditorSelectionOverlay),
          findsNothing,
          reason:
              'Attaching it would put a source that plays nothing on the '
              'draft.',
        );

        // Positive control: the sibling with a file still selects, so the
        // assertion above is about the missing file and not about taps
        // never landing in this harness.
        await tester.tap(find.text('Here Sound'));
        await tester.pumpAndSettle();
        expect(find.byType(AudioEditorSelectionOverlay), findsOneWidget);
      });

      testWidgets('renders saved sounds on My Sounds tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(
            trendingSoundsAsync: AsyncValue.data(testSounds),
            savedSounds: [
              _createTestAudioEvent(id: 'saved-sound', title: 'Saved Sound'),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryMySounds));
        await tester.pumpAndSettle();

        expect(find.text('Saved Sound'), findsOneWidget);
      });
    });
  });
}

/// Fake TrendingSounds notifier for testing: its first page is
/// [_initialValue], and each [loadMore] adds the next of [pagesToLoad].
class _FakeTrendingSounds extends TrendingSounds {
  _FakeTrendingSounds(
    this._initialValue, {
    this.pagesToLoad = const [],
    this.loadedPages,
  });

  final AsyncValue<List<AudioEvent>> _initialValue;
  final List<List<AudioEvent>> pagesToLoad;

  /// Records the titles of each page [loadMore] added.
  final List<String>? loadedPages;

  @override
  Future<PagedSounds> build() {
    return _initialValue.when(
      data: (sounds) => Future.value(
        PagedSounds(pages: [sounds], hasMore: pagesToLoad.isNotEmpty),
      ),
      loading: () => Completer<PagedSounds>().future,
      error: Future.error,
    );
  }

  @override
  Future<void> loadMore() async {
    final current = state.requireValue;
    if (!current.canLoadMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    await pumpEventQueue();
    final page = pagesToLoad[current.pages.length - 1];
    loadedPages?.add(page.map((sound) => sound.title).join(', '));
    state = AsyncData(
      current.withPage((
        sounds: page,
        usageCounts: const {},
        hasMore: current.pages.length < pagesToLoad.length,
      )),
    );
  }
}

class _MockSavedSoundsBloc extends MockBloc<SavedSoundsEvent, SavedSoundsState>
    implements SavedSoundsBloc {}

class _FakeSoundLibraryService extends SoundLibraryService {
  _FakeSoundLibraryService(this._bundledSounds);

  final List<VineSound> _bundledSounds;

  @override
  List<VineSound> get sounds => List.unmodifiable(_bundledSounds);

  @override
  List<VineSound> get customSounds => const [];

  @override
  bool get isLoaded => true;

  @override
  Future<void> loadSounds() async {}

  @override
  Future<void> loadCustomSounds() async {}
}

class _StubAuthService extends Mock implements AuthService {
  _StubAuthService([this._pubkey]);

  final String? _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;

  @override
  Stream<AuthState> get authStateStream => const Stream<AuthState>.empty();

  @override
  AuthState get authState =>
      _pubkey == null ? AuthState.unauthenticated : AuthState.authenticated;
}
