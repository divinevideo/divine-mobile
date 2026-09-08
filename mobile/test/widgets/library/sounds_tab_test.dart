// ABOUTME: Widget tests for the Library Sounds tab.
// ABOUTME: Verifies the tab shows user-saved reusable sounds, not asset sounds.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/saved_sound_card.dart';
import 'package:openvine/widgets/library/sounds_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

/// Stands in for just_audio's ownership of the `play()` future: it stays
/// pending until playback ends, and resolves early when `pause()` or `stop()`
/// takes the player away.
class _FakeAudioPlaybackService extends Fake implements AudioPlaybackService {
  final positions = StreamController<Duration>.broadcast();
  Completer<void>? _playing;
  final _loadHold = <String, Completer<void>>{};
  final loadedUrls = <String>[];
  int playCalls = 0;
  int pauseCalls = 0;
  int stopCalls = 0;

  /// Gates the next `loadAudio` for [url] until [releaseLoad] is called.
  void holdLoad(String url) {
    _loadHold[url] = Completer<void>();
  }

  void releaseLoad(String url) {
    final hold = _loadHold.remove(url);
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Future<Duration?> loadAudio(String url) async {
    final hold = _loadHold[url];
    if (hold != null) await hold.future;
    loadedUrls.add(url);
    return const Duration(seconds: 6);
  }

  @override
  Future<void> play() {
    playCalls++;
    return (_playing = Completer<void>()).future;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _resolvePlay();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _resolvePlay();
  }

  /// Completes the sound the way reaching its end would.
  void finishPlayback() => _resolvePlay();

  void _resolvePlay() {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
  }
}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

AudioEvent _sound({
  required String id,
  required String title,
  int createdAt = 1700000000,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    createdAt: createdAt,
    title: title,
    duration: 6,
    url: 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
    source: 'Original Sound',
  );
}

DivineIconName? _previewIcon(WidgetTester tester) => tester
    .widget<DivineIconButton>(find.byKey(const Key('saved_sound_preview')))
    .icon;

void main() {
  group(SoundsTab, () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    Future<void> pumpSoundsTab(
      WidgetTester tester, {
      Future<AudioEvent?> Function(BuildContext)? showAudioPicker,
      AudioPlaybackService? audioService,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            documentsPathProvider.overrideWithValue('/documents'),
            if (audioService != null)
              audioPlaybackServiceProvider.overrideWithValue(audioService),
          ],
          child: SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: const _NoopSavedSoundMediaProbe(),
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) => Scaffold(
                      body: SoundsTab(showAudioPicker: showAudioPicker),
                    ),
                  ),
                  GoRoute(
                    path: '/sound/:id',
                    builder: (context, state) => Text(
                      'sound detail ${state.pathParameters['id']}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows saved sounds without featured or trending sections', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);

      expect(find.text('Original sound - rabble'), findsOneWidget);
      expect(find.text('Featured Sounds'), findsNothing);
      expect(find.text('Trending Sounds'), findsNothing);
    });

    testWidgets('opens saved sound details from the card', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);
      await tester.tap(find.text('Original sound - rabble'));
      await tester.pumpAndSettle();

      expect(find.text('sound detail sound1'), findsOneWidget);
    });

    testWidgets('filters saved sounds by search query', (tester) async {
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(_sound(id: 'sound1', title: 'Drum Loop'));
      await service.saveSound(_sound(id: 'sound2', title: 'Piano Loop'));

      await pumpSoundsTab(tester);
      await tester.enterText(find.byType(TextField), 'drum');
      await tester.pumpAndSettle();

      expect(find.text('Drum Loop'), findsOneWidget);
      expect(find.text('Piano Loop'), findsNothing);
    });

    testWidgets('scrolls the search field away with the list', (tester) async {
      final service = SavedSoundsService(sharedPreferences);
      for (var i = 0; i < 15; i++) {
        await service.saveSound(_sound(id: 'sound$i', title: 'Loop $i'));
      }

      await pumpSoundsTab(tester);
      expect(find.byType(TextField), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      // The field lives in the scroll view now, not in a fixed header above
      // it, so scrolling hands its height back to the results.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Loop'), findsWidgets);
    });

    testWidgets('preview pauses and resumes instead of restarting', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);

      await pumpSoundsTab(tester, audioService: audio);
      final preview = find.byKey(const Key('saved_sound_preview'));

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(_previewIcon(tester), DivineIconName.pause);
      expect(audio.playCalls, 1);

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(audio.pauseCalls, 1);
      expect(_previewIcon(tester), DivineIconName.play);
      // Still the active preview — a pause must not reload the sound.
      expect(audio.playCalls, 1);

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(_previewIcon(tester), DivineIconName.pause);
      expect(audio.playCalls, 2);
    });

    testWidgets('preview returns to idle when the sound ends', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);

      await pumpSoundsTab(tester, audioService: audio);
      await tester.tap(find.byKey(const Key('saved_sound_preview')));
      await tester.pumpAndSettle();
      expect(_previewIcon(tester), DivineIconName.pause);

      audio.finishPlayback();
      await tester.pumpAndSettle();

      expect(_previewIcon(tester), DivineIconName.play);
    });

    testWidgets('rapid pause then resume keeps the preview active', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);

      await pumpSoundsTab(tester, audioService: audio);
      final preview = find.byKey(const Key('saved_sound_preview'));

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(_previewIcon(tester), DivineIconName.pause);

      // Pause, then resume before the pause path's microtasks fully settle —
      // the resolving play() must not wipe the resumed preview.
      await tester.tap(preview);
      await tester.tap(preview);
      await tester.pumpAndSettle();

      expect(audio.pauseCalls, 1);
      expect(audio.playCalls, 2);
      expect(_previewIcon(tester), DivineIconName.pause);
    });

    Finder previewOnCard(String title) => find.descendant(
      of: find.ancestor(
        of: find.text(title),
        matching: find.byType(SavedSoundCard),
      ),
      matching: find.byKey(const Key('saved_sound_preview')),
    );

    testWidgets(
      'switching sounds does not let the first play clear the second',
      (tester) async {
        final service = SavedSoundsService(sharedPreferences);
        await service.saveSound(_sound(id: 'sound1', title: 'Loop One'));
        await service.saveSound(_sound(id: 'sound2', title: 'Loop Two'));
        final audio = _FakeAudioPlaybackService();
        addTearDown(audio.positions.close);

        await pumpSoundsTab(tester, audioService: audio);

        await tester.tap(previewOnCard('Loop One'));
        await tester.pumpAndSettle();
        expect(audio.playCalls, 1);
        expect(audio.loadedUrls.single, contains('sound1'));

        await tester.tap(previewOnCard('Loop Two'));
        await tester.pumpAndSettle();
        expect(audio.loadedUrls.last, contains('sound2'));
        expect(audio.playCalls, 2);
        expect(
          tester.widget<DivineIconButton>(previewOnCard('Loop Two')).icon,
          DivineIconName.pause,
        );

        // Natural end of the second preview — not a wipe from the first.
        audio.finishPlayback();
        await tester.pumpAndSettle();
        expect(
          tester.widget<DivineIconButton>(previewOnCard('Loop Two')).icon,
          DivineIconName.play,
        );
      },
    );

    testWidgets('overlapping loads serialize onto the later sound', (
      tester,
    ) async {
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(_sound(id: 'sound1', title: 'Loop One'));
      await service.saveSound(_sound(id: 'sound2', title: 'Loop Two'));
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);
      const sound1Url = 'https://example.com/audio/sound1.m4a';
      const sound2Url = 'https://example.com/audio/sound2.m4a';
      audio.holdLoad(sound1Url);

      await pumpSoundsTab(tester, audioService: audio);

      await tester.tap(previewOnCard('Loop One'));
      await tester.pump();
      await tester.tap(previewOnCard('Loop Two'));
      await tester.pump();

      audio.releaseLoad(sound1Url);
      await tester.pumpAndSettle();

      // sound1's load must finish (and be discarded) before sound2's load
      // starts — never the reverse interleave on the shared player.
      expect(audio.loadedUrls, [sound1Url, sound2Url]);
      expect(audio.playCalls, 1);
      expect(
        tester.widget<DivineIconButton>(previewOnCard('Loop Two')).icon,
        DivineIconName.pause,
      );
    });

    testWidgets('saves sound selected from Add audio picker', (tester) async {
      await pumpSoundsTab(
        tester,
        showAudioPicker: (_) async =>
            _sound(id: 'wednesday', title: 'Wednesday My Dudes'),
      );

      await tester.tap(find.text('Add audio'));
      await tester.pumpAndSettle();

      expect(find.text('Wednesday My Dudes'), findsOneWidget);
      expect(find.byKey(const Key('saved_sound_label_field')), findsOneWidget);

      final savedSounds = SavedSoundsService(
        sharedPreferences,
      ).loadSavedSounds();
      expect(
        savedSounds.map((sound) => sound.audio.title),
        contains('Wednesday My Dudes'),
      );
    });

    testWidgets('filters rich cards by personal hashtag', (tester) async {
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSavedSound(
        SavedSound(
          audio: _sound(id: 'sound1', title: 'Drum Loop'),
          personalHashtags: const ['practice'],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );
      await service.saveSavedSound(
        SavedSound(
          audio: _sound(id: 'sound2', title: 'Piano Loop'),
          personalHashtags: const ['favorite'],
          catalogTags: const [],
          waveformSamples: const [],
        ),
      );

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_filter_practice')));
      await tester.pumpAndSettle();

      expect(find.text('Drum Loop'), findsOneWidget);
      expect(find.text('Piano Loop'), findsNothing);
    });

    testWidgets('shows empty state when no sounds have been saved', (
      tester,
    ) async {
      await pumpSoundsTab(tester);

      expect(find.text('No saved sounds yet'), findsOneWidget);
      expect(
        find.text('Tap Use Sound on a video to save it here.'),
        findsOneWidget,
      );
    });

    testWidgets('removes a saved sound after the prompt is confirmed', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_remove')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.savedSoundRemoveConfirmTitle), findsOneWidget);
      expect(find.text('Original sound - rabble'), findsOneWidget);

      await tester.tap(find.text(l10n.soundsRemoveSavedSound));
      await tester.pumpAndSettle();

      expect(find.text('Original sound - rabble'), findsNothing);
      expect(find.text('No saved sounds yet'), findsOneWidget);
    });

    testWidgets('keeps the sound when the remove prompt is cancelled', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_remove')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text('Original sound - rabble'), findsOneWidget);
    });

    testWidgets('edit sheet keeps its fields above the keyboard', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      // 300 physical / 3.0 DPR = 100 logical points of keyboard.
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);

      await pumpSoundsTab(tester);
      await tester.tap(find.byKey(const Key('saved_sound_edit')));
      await tester.pumpAndSettle();

      final keyboardTop = tester.view.physicalSize.height / 3.0 - 100;
      final fields = find.byType(DivineTextField);
      expect(fields, findsNWidgets(2));
      for (final field in [fields.first, fields.last]) {
        expect(tester.getRect(field).bottom, lessThanOrEqualTo(keyboardTop));
      }
    });

    testWidgets('edits sound details in a bottom sheet', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final l10n = lookupAppLocalizations(const Locale('en'));

      await pumpSoundsTab(tester);
      expect(find.byKey(const Key('saved_sound_label_field')), findsNothing);

      await tester.tap(find.byKey(const Key('saved_sound_edit')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.savedSoundDetailsSheetTitle), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('saved_sound_label_field')),
        'Practice loop',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saved_sound_details_save')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.savedSoundDetailsSheetTitle), findsNothing);
      expect(find.text('Practice loop'), findsOneWidget);
      expect(
        SavedSoundsService(
          sharedPreferences,
        ).loadSavedSounds().single.personalLabel,
        'Practice loop',
      );
    });

    group('sync trigger', () {
      late _MockSoundSyncRepository syncRepository;

      Future<void> pumpSyncedSoundsTab(WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              documentsPathProvider.overrideWithValue('/documents'),
              soundSyncAvailabilityProvider.overrideWith(
                (ref) async => SoundSyncAvailable(syncRepository),
              ),
            ],
            child: SavedSoundsScope(
              service: SavedSoundsService(sharedPreferences),
              mediaProbe: const _NoopSavedSoundMediaProbe(),
              child: MaterialApp.router(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: VineTheme.theme,
                routerConfig: GoRouter(
                  routes: [
                    GoRoute(
                      path: '/',
                      builder: (context, state) =>
                          const Scaffold(body: SoundsTab()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        // Lets soundSyncAvailabilityProvider's FutureProvider resolve so
        // SoundsTab rebuilds with the now-available repository and mounts
        // BlocProvider<SoundSyncCubit>, whose create: fires syncNow().
        await tester.pump();
        await tester.pump();
      }

      setUp(() {
        syncRepository = _MockSoundSyncRepository();
      });

      testWidgets('reconciles once when the tab opens', (tester) async {
        final completer = Completer<SoundSyncOutcome>();
        when(syncRepository.reconcile).thenAnswer((_) => completer.future);

        await pumpSyncedSoundsTab(tester);

        verify(syncRepository.reconcile).called(1);

        completer.complete(
          const SoundSyncOutcome(
            pulled: 0,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        await tester.pumpAndSettle();
      });

      testWidgets('shows syncing then synced status', (tester) async {
        final completer = Completer<SoundSyncOutcome>();
        when(syncRepository.reconcile).thenAnswer((_) => completer.future);
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSyncedSoundsTab(tester);

        expect(find.text(l10n.soundSyncStatusSyncing), findsOneWidget);
        expect(find.text(l10n.soundSyncStatusSynced), findsNothing);

        completer.complete(
          const SoundSyncOutcome(
            pulled: 1,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundSyncStatusSyncing), findsNothing);
        expect(find.text(l10n.soundSyncStatusSynced), findsOneWidget);
      });

      testWidgets('shows locked status when the vault key is unavailable', (
        tester,
      ) async {
        when(
          syncRepository.reconcile,
        ).thenThrow(VaultKeyUnavailableException('locked'));
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSyncedSoundsTab(tester);
        await tester.pumpAndSettle();

        expect(find.text(l10n.soundSyncStatusLocked), findsOneWidget);
      });
    });

    group('vault key locked at the provider', () {
      const testPubkey =
          'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

      testWidgets(
        'shows the locked banner when the vault key cannot be unlocked',
        (tester) async {
          final mockClient = _MockNostrClient();
          final mockSigner = _MockNostrSigner();
          when(() => mockClient.signer).thenReturn(mockSigner);
          when(() => mockClient.hasKeys).thenReturn(true);
          when(() => mockClient.publicKey).thenReturn(testPubkey);
          // No signed-in account from the signer's perspective —
          // VaultKeyService throws VaultKeyUnavailableException before ever
          // touching secure storage or a relay. Unlike the mocked-cubit
          // "shows locked status" case above, this drives the real
          // soundSyncAvailabilityProvider failure path end to end.
          when(mockSigner.getPublicKey).thenAnswer((_) async => null);
          final l10n = lookupAppLocalizations(const Locale('en'));

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(
                  sharedPreferences,
                ),
                documentsPathProvider.overrideWithValue('/documents'),
                nostrSessionProvider.overrideWith(
                  () => _TestNostrSession(
                    NostrSessionReadiness.nostrReady(
                      pubkey: testPubkey,
                      client: mockClient,
                    ),
                  ),
                ),
              ],
              child: SavedSoundsScope(
                service: SavedSoundsService(sharedPreferences),
                mediaProbe: const _NoopSavedSoundMediaProbe(),
                child: MaterialApp.router(
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: VineTheme.theme,
                  routerConfig: GoRouter(
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (context, state) =>
                            const Scaffold(body: SoundsTab()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(l10n.soundSyncStatusLocked), findsOneWidget);
          expect(find.text(l10n.soundSyncStatusSyncing), findsNothing);
          expect(find.text(l10n.soundSyncStatusSynced), findsNothing);
        },
      );
    });
  });
}

class _NoopSavedSoundMediaProbe implements SavedSoundMediaProbe {
  const _NoopSavedSoundMediaProbe();

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}
