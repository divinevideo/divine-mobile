// ABOUTME: Tests for AudioSelectionBottomSheet widget
// ABOUTME: Validates rendering of category bar, sounds, loading and
// ABOUTME: error states with mocked sound providers.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:sound_service/sound_service.dart';

AudioEvent _createTestAudioEvent({
  String id = 'test-sound-id',
  String pubkey = 'test-pubkey',
  int createdAt = 1704067200,
  String? url,
  String? title,
  String? source,
  double? duration,
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    url: url ?? 'https://example.com/audio/$id.mp3',
    title: title,
    source: source,
    duration: duration ?? 5.0,
  );
}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

class _MockAudioPlaybackService extends Mock implements AudioPlaybackService {}

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
      List<AudioEvent> savedSounds = const [],
      List<VineSound> bundledSounds = const [],
      AudioPlaybackService? audioService,
      String? viewerPubkey,
      AudioEvent? consentSound,
      bool? consentResult,
    }) {
      final savedSoundsBloc = _MockSavedSoundsBloc();
      when(() => savedSoundsBloc.state).thenReturn(
        SavedSoundsState(
          status: SavedSoundsStatus.loaded,
          sounds: savedSounds
              .map(
                (sound) => SavedSound(
                  audio: sound,
                  personalHashtags: const [],
                  catalogTags: const [],
                  waveformSamples: const [],
                ),
              )
              .toList(growable: false),
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
            soundLibraryServiceProvider.overrideWith(
              (_) async => _FakeSoundLibraryService(bundledSounds),
            ),
            if (consentSound != null && consentResult != null)
              audioReuseConsentProvider(
                consentSound,
              ).overrideWith((ref) => Future.value(consentResult)),
            if (trendingSoundsAsync != null)
              trendingSoundsProvider.overrideWith(
                () => _FakeTrendingSounds(trendingSoundsAsync),
              ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
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

    group('Rendering', () {
      testWidgets('renders $AudioSelectionBottomSheet', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AudioSelectionBottomSheet), findsOneWidget);
      });

      testWidgets('shows import action in the audio picker', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: const AsyncValue.data([])),
        );
        await tester.pumpAndSettle();

        expect(find.text('Import audio'), findsOneWidget);
        expect(find.byIcon(Icons.upload_file), findsOneWidget);
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
        expect(find.text(l10n.videoEditorAudioCategoryDivine), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryCommunity), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryFeatured), findsWidgets);
        expect(find.text(l10n.videoEditorAudioCategoryMySounds), findsWidgets);
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

      testWidgets('filters featured sounds on featured tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'wednes');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryFeatured));
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
      });

      testWidgets('filters community sounds on community tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField).first, 'beta');
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Credit only'));
        await tester.pumpAndSettle();

        expect(find.byType(AudioEditorSelectionOverlay), findsNothing);
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
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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

      testWidgets('renders featured sounds on featured tab', (tester) async {
        await tester.pumpWidget(
          buildWidget(trendingSoundsAsync: AsyncValue.data(testSounds)),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.videoEditorAudioCategoryFeatured));
        await tester.pumpAndSettle();

        expect(find.text('Wednesday My Dudes'), findsOneWidget);
      });

      testWidgets('renders bundled Wednesday clip on Divine tab', (
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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
        await tester.tap(find.text(l10n.videoEditorAudioCategoryCommunity));
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

/// Fake TrendingSounds notifier for testing.
class _FakeTrendingSounds extends TrendingSounds {
  _FakeTrendingSounds(this._initialValue);

  final AsyncValue<List<AudioEvent>> _initialValue;

  @override
  Future<List<AudioEvent>> build() {
    return _initialValue.when(
      data: Future.value,
      loading: () => Completer<List<AudioEvent>>().future,
      error: Future.error,
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
