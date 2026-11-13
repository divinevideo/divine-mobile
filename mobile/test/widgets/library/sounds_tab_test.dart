// ABOUTME: Widget tests for the Library Sounds tab.
// ABOUTME: Verifies the tab shows user-saved reusable sounds, not asset sounds.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/models/sound_cover.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/saved_sound_tile.dart';
import 'package:openvine/widgets/library/sounds_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

class _MockSoundSyncRepository extends Mock implements SoundSyncRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockContentDeletionService extends Mock
    implements ContentDeletionService {}

class _FakeAudioEvent extends Fake implements AudioEvent {}

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

const _viewerPubkey =
    'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0';

AudioEvent _sound({
  required String id,
  required String title,
  int createdAt = 1700000000,
  String pubkey = 'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
}) {
  return AudioEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    title: title,
    duration: 6,
    url: 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
    source: 'Original Sound',
  );
}

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

SavedSoundTile _tile(WidgetTester tester, String title) =>
    tester.widget<SavedSoundTile>(
      find.ancestor(
        of: find.text(title),
        matching: find.byType(SavedSoundTile),
      ),
    );

/// Whether the row titled [title] previews, and whether that preview plays.
({bool previewing, bool playing}) _preview(WidgetTester tester, String title) {
  final tile = _tile(tester, title);
  return (previewing: tile.isPreviewing, playing: tile.isPlaying);
}

/// Opens the actions of the row titled [title], or of the only row, and
/// chooses [action].
Future<void> _chooseAction(
  WidgetTester tester,
  String action, {
  String? title,
}) async {
  final more = find.byKey(const Key('saved_sound_more'));
  await tester.tap(
    title == null
        ? more
        : find.descendant(
            of: find.ancestor(
              of: find.text(title),
              matching: find.byType(SavedSoundTile),
            ),
            matching: more,
          ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  group(SoundsTab, () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    late _MockAuthService authService;
    late _MockContentDeletionService deletionService;
    late List<String> evictedSoundIds;

    setUpAll(() => registerFallbackValue(_FakeAudioEvent()));

    setUp(() {
      authService = _MockAuthService();
      when(() => authService.currentPublicKeyHex).thenReturn(_viewerPubkey);
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream.empty());
      deletionService = _MockContentDeletionService();
      evictedSoundIds = [];
    });

    Future<void> pumpSoundsTab(
      WidgetTester tester, {
      AudioPlaybackService? audioService,
      FutureOr<bool> Function(String path)? localFileExists,
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            documentsPathProvider.overrideWithValue('/documents'),
            authServiceProvider.overrideWithValue(authService),
            if (audioService != null)
              audioPlaybackServiceProvider.overrideWithValue(audioService),
            ...overrides,
          ],
          child: SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: const _NoopSavedSoundMediaProbe(),
            localFileExists: localFileExists,
            contentDeletionService: () async => deletionService,
            onPublishedSoundDeleted: evictedSoundIds.add,
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, state) =>
                        const Scaffold(body: SoundsTab()),
                  ),
                  GoRoute(
                    path: '/sound/:id',
                    builder: (context, state) =>
                        Text('sound detail ${state.pathParameters['id']}'),
                  ),
                  GoRoute(
                    path: RoutePaths.addSound,
                    builder: (context, state) => const Text('add sound page'),
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

    testWidgets('says which saved sound lost its audio file', (tester) async {
      // The real bloc probes the filesystem here, so nothing but the wiring
      // in _SavedSoundsSection decides which row carries the notice.
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(
        _sound(
          id: 'gone',
          title: 'Gone Sound',
        ).copyWith(url: '/imports/never-written.m4a'),
      );
      await service.saveSound(_sound(id: 'here', title: 'Here Sound'));

      await pumpSoundsTab(
        tester,
        localFileExists: (path) => !path.endsWith('never-written.m4a'),
      );

      expect(find.text(_l10n.videoEditorAudioFileMissing), findsOneWidget);
      expect(_tile(tester, 'Gone Sound').isMissingFile, isTrue);
      expect(
        _tile(tester, 'Here Sound').isMissingFile,
        isFalse,
        reason:
            'Only the row whose file is gone loses its preview — a wiring '
            'hardcoded either way would give both rows the same answer.',
      );
    });

    testWidgets('says which saved sound can no longer be reused', (
      tester,
    ) async {
      const goneVideo = '34236:creator:gone';
      const hereVideo = '34236:creator:here';
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(
        _sound(
          id: 'gone',
          title: 'Gone Sound',
        ).copyWith(sourceVideoReference: goneVideo),
      );
      await service.saveSound(
        _sound(
          id: 'here',
          title: 'Here Sound',
        ).copyWith(sourceVideoReference: hereVideo),
      );
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);

      await pumpSoundsTab(
        tester,
        audioService: audio,
        overrides: [
          savedSoundSourcesProvider.overrideWith(
            (ref, sources) async => {
              goneVideo: null,
              hereVideo: const SoundCover(imageUrl: 'https://x.test/a.jpg'),
            },
          ),
        ],
      );

      expect(find.text(_l10n.savedSoundReuseUnavailable), findsOneWidget);
      expect(_tile(tester, 'Gone Sound').cannotBeReused, isTrue);
      expect(_tile(tester, 'Here Sound').cannotBeReused, isFalse);

      // Listed, so it can be removed, but not played.
      await tester.tap(find.text('Gone Sound'));
      await tester.pumpAndSettle();
      expect(audio.loadedUrls, isEmpty);
    });

    group('a sound that cannot be used', () {
      const goneVideo = '34236:creator:gone';

      for (final (name, sound, exists) in [
        (
          'whose source video is gone',
          _sound(
            id: 'gone',
            title: 'Gone Sound',
          ).copyWith(sourceVideoReference: goneVideo),
          null,
        ),
        (
          'whose file is gone',
          _sound(
            id: 'gone',
            title: 'Gone Sound',
          ).copyWith(url: '/imports/never-written.m4a'),
          (String _) => false,
        ),
      ]) {
        testWidgets('$name can still be removed', (tester) async {
          await SavedSoundsService(sharedPreferences).saveSound(sound);

          await pumpSoundsTab(
            tester,
            localFileExists: exists,
            overrides: [
              savedSoundSourcesProvider.overrideWith(
                (ref, sources) async => {goneVideo: null},
              ),
            ],
          );
          final tile = _tile(tester, 'Gone Sound');
          expect(tile.cannotBeReused || tile.isMissingFile, isTrue);

          await _chooseAction(tester, _l10n.savedSoundRemoveAction);
          expect(find.text(_l10n.savedSoundRemoveConfirmTitle), findsOneWidget);
          await tester.tap(find.text(_l10n.soundsRemoveSavedSound));
          await tester.pumpAndSettle();

          expect(find.text('Gone Sound'), findsNothing);
        });
      }
    });

    group('covers', () {
      const video = '34236:creator:clip';
      const storedFrame = 'https://example.com/stored-frame.jpg';

      Future<void> saveClip() =>
          SavedSoundsService(sharedPreferences).saveSavedSound(
            SavedSound(
              audio: _sound(
                id: 'clip',
                title: 'Clip Sound',
              ).copyWith(sourceVideoReference: video),
              personalHashtags: const [],
              catalogTags: const [],
              waveformSamples: const [],
              sourceContext: const SavedSoundSourceContext(
                thumbnailUrl: storedFrame,
              ),
            ),
          );

      testWidgets('shows what the source video shows now, not the stored '
          'frame', (tester) async {
        // A source now behind a content warning answers with its blurhash.
        const warned = SoundCover(blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
        await saveClip();

        await pumpSoundsTab(
          tester,
          overrides: [
            savedSoundSourcesProvider.overrideWith(
              (ref, sources) async => {video: warned},
            ),
          ],
        );

        expect(_tile(tester, 'Clip Sound').cover, warned);
      });

      testWidgets('shows no frame for a source video found gone', (
        tester,
      ) async {
        await saveClip();

        await pumpSoundsTab(
          tester,
          overrides: [
            savedSoundSourcesProvider.overrideWith(
              (ref, sources) async => {video: null},
            ),
          ],
        );

        expect(_tile(tester, 'Clip Sound').cover, isNull);
      });
    });

    testWidgets('keeps a sound the viewer published usable', (tester) async {
      const goneVideo = '34236:creator:gone';
      await SavedSoundsService(sharedPreferences).saveSound(
        _sound(
          id: 'own',
          title: 'My Beat',
          pubkey: _viewerPubkey,
        ).copyWith(sourceVideoReference: goneVideo),
      );

      await pumpSoundsTab(
        tester,
        overrides: [
          savedSoundSourcesProvider.overrideWith(
            (ref, sources) async => {goneVideo: null},
          ),
        ],
      );

      // Its creator may always reuse it, so the picker offers it too.
      expect(find.text(_l10n.savedSoundReuseUnavailable), findsNothing);
      expect(_tile(tester, 'My Beat').cannotBeReused, isFalse);
    });

    testWidgets('opens saved sound details from its menu', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));

      await pumpSoundsTab(tester);
      await _chooseAction(tester, _l10n.savedSoundOpenAction);

      expect(find.text('sound detail sound1'), findsOneWidget);
    });

    testWidgets('keeps the page of a sound whose file is gone closed', (
      tester,
    ) async {
      await SavedSoundsService(sharedPreferences).saveSound(
        _sound(
          id: 'gone',
          title: 'Gone Sound',
        ).copyWith(url: '/imports/never-written.m4a'),
      );

      await pumpSoundsTab(tester, localFileExists: (_) => false);
      await _chooseAction(tester, _l10n.savedSoundOpenAction);

      expect(find.text('sound detail gone'), findsNothing);
      // The disabled action leaves the menu open, with the other actions.
      expect(find.text(_l10n.savedSoundRemoveAction), findsOneWidget);
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
      const title = 'Original sound - rabble';
      final preview = find.text(title);

      await tester.tap(preview);
      await tester.pump();
      expect(_preview(tester, title), (previewing: true, playing: true));
      expect(audio.playCalls, 1);

      await tester.tap(preview);
      await tester.pumpAndSettle();
      expect(audio.pauseCalls, 1);
      // Still the active preview — a pause must not reload the sound.
      expect(_preview(tester, title), (previewing: true, playing: false));
      expect(audio.playCalls, 1);

      await tester.tap(preview);
      await tester.pump();
      expect(_preview(tester, title), (previewing: true, playing: true));
      expect(audio.playCalls, 2);
    });

    testWidgets('preview returns to idle when the sound ends', (tester) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      final audio = _FakeAudioPlaybackService();
      addTearDown(audio.positions.close);

      await pumpSoundsTab(tester, audioService: audio);
      const title = 'Original sound - rabble';
      await tester.tap(find.text(title));
      await tester.pump();
      expect(_preview(tester, title), (previewing: true, playing: true));

      audio.finishPlayback();
      await tester.pumpAndSettle();

      expect(_preview(tester, title), (previewing: false, playing: false));
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
      const title = 'Original sound - rabble';
      final preview = find.text(title);

      await tester.tap(preview);
      await tester.pump();
      expect(_preview(tester, title), (previewing: true, playing: true));

      // Pause, then resume before the pause path's microtasks fully settle —
      // the resolving play() must not wipe the resumed preview.
      await tester.tap(preview);
      await tester.tap(preview);
      await tester.pump();

      expect(audio.pauseCalls, 1);
      expect(audio.playCalls, 2);
      expect(_preview(tester, title), (previewing: true, playing: true));
    });

    testWidgets(
      'switching sounds does not let the first play clear the second',
      (tester) async {
        final service = SavedSoundsService(sharedPreferences);
        await service.saveSound(_sound(id: 'sound1', title: 'Loop One'));
        await service.saveSound(_sound(id: 'sound2', title: 'Loop Two'));
        final audio = _FakeAudioPlaybackService();
        addTearDown(audio.positions.close);

        await pumpSoundsTab(tester, audioService: audio);

        await tester.tap(find.text('Loop One'));
        await tester.pump();
        expect(audio.playCalls, 1);
        expect(audio.loadedUrls.single, contains('sound1'));

        await tester.tap(find.text('Loop Two'));
        await tester.pump();
        expect(audio.loadedUrls.last, contains('sound2'));
        expect(audio.playCalls, 2);
        expect(
          _preview(tester, 'Loop Two'),
          (previewing: true, playing: true),
        );
        expect(
          _preview(tester, 'Loop One'),
          (previewing: false, playing: false),
        );

        // Natural end of the second preview — not a wipe from the first.
        audio.finishPlayback();
        await tester.pumpAndSettle();
        expect(
          _preview(tester, 'Loop Two'),
          (previewing: false, playing: false),
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

      await tester.tap(find.text('Loop One'));
      await tester.pump();
      await tester.tap(find.text('Loop Two'));
      await tester.pump();

      audio.releaseLoad(sound1Url);
      await tester.pump();

      // sound1's load must finish (and be discarded) before sound2's load
      // starts — never the reverse interleave on the shared player.
      expect(audio.loadedUrls, [sound1Url, sound2Url]);
      expect(audio.playCalls, 1);
      expect(_preview(tester, 'Loop Two'), (previewing: true, playing: true));
    });

    testWidgets('shows the Add sound action in an empty library', (
      tester,
    ) async {
      await pumpSoundsTab(tester);

      expect(find.text('No saved sounds yet'), findsOneWidget);
      expect(find.byKey(const Key('sounds_add_sound')), findsOneWidget);
    });

    testWidgets('shows the Add sound action with saved sounds', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Loop One'));

      await pumpSoundsTab(tester);

      expect(find.text('Loop One'), findsOneWidget);
      expect(find.byKey(const Key('sounds_add_sound')), findsOneWidget);
      // Like the picker's import row, it says what it does under its title.
      expect(find.text(_l10n.soundsAddSoundHint), findsOneWidget);
    });

    testWidgets('waits on a plain cover only for a sound the lookup decides', (
      tester,
    ) async {
      const video = '34236:creator:clip';
      final service = SavedSoundsService(sharedPreferences);
      await service.saveSound(
        _sound(
          id: 'clip',
          title: 'Clip Sound',
        ).copyWith(sourceVideoReference: video),
      );
      await service.saveSound(_sound(id: 'file', title: 'File Sound'));
      final lookup = Completer<Map<String, SoundCover?>>();
      addTearDown(() => lookup.complete(const {}));

      await pumpSoundsTab(
        tester,
        overrides: [
          savedSoundSourcesProvider.overrideWith(
            (ref, sources) => lookup.future,
          ),
        ],
      );

      expect(_tile(tester, 'Clip Sound').isCoverPending, isTrue);
      expect(_tile(tester, 'File Sound').isCoverPending, isFalse);
    });

    testWidgets('repeats why a sound cannot be used above its actions', (
      tester,
    ) async {
      const goneVideo = '34236:creator:gone';
      await SavedSoundsService(sharedPreferences).saveSound(
        _sound(
          id: 'gone',
          title: 'Gone Sound',
        ).copyWith(sourceVideoReference: goneVideo),
      );

      await pumpSoundsTab(
        tester,
        overrides: [
          savedSoundSourcesProvider.overrideWith(
            (ref, sources) async => {goneVideo: null},
          ),
        ],
      );
      expect(find.text(_l10n.savedSoundReuseUnavailable), findsOneWidget);

      await tester.tap(find.byKey(const Key('saved_sound_more')));
      await tester.pumpAndSettle();

      expect(find.byType(SavedSoundMenuHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SavedSoundMenuHeader),
          matching: find.text(_l10n.savedSoundReuseUnavailable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Add sound opens the add flow, not the editor picker', (
      tester,
    ) async {
      await pumpSoundsTab(tester);

      await tester.tap(find.byKey(const Key('sounds_add_sound')));
      await tester.pumpAndSettle();

      // The library add action must route to the Add sound flow, never the
      // editor's catalog/trimming bottom sheet.
      expect(find.text('add sound page'), findsOneWidget);
    });

    testWidgets('filters saved sounds by personal hashtag', (tester) async {
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
      await _chooseAction(tester, _l10n.savedSoundRemoveAction);

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
      await _chooseAction(tester, _l10n.savedSoundRemoveAction);
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(find.text('Original sound - rabble'), findsOneWidget);
    });

    testWidgets('folds the Add sound action away while searching', (
      tester,
    ) async {
      await SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: 'sound1', title: 'Original sound - rabble'));
      await pumpSoundsTab(tester);
      expect(
        tester.getSize(find.byKey(const Key('sounds_add_sound'))).height,
        greaterThan(0),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sounds_add_sound')), findsNothing);
      expect(find.text('Original sound - rabble'), findsOneWidget);

      // Tapping anywhere outside the field drops focus and brings them back
      // (the empty space under the list, so no row handles the tap).
      await tester.tapAt(
        tester.getBottomRight(find.byType(CustomScrollView)) -
            const Offset(20, 20),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sounds_add_sound')), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isFalse,
      );
    });

    testWidgets('drops search focus when the keyboard is dismissed', (
      tester,
    ) async {
      await pumpSoundsTab(tester);
      addTearDown(tester.view.resetViewInsets);

      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('sounds_add_sound')), findsNothing);

      // Android's back button hides the IME without moving focus.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
        isFalse,
      );
      expect(find.byKey(const Key('sounds_add_sound')), findsOneWidget);
    });

    group('own published sound', () {
      final ownId = 'a' * 64;

      Future<void> saveOwnSound() => SavedSoundsService(
        sharedPreferences,
      ).saveSound(_sound(id: ownId, title: 'My beat', pubkey: _viewerPubkey));

      testWidgets('offers to delete it for everyone and does so', (
        tester,
      ) async {
        await saveOwnSound();
        when(
          () => deletionService.deleteSound(
            sound: any(named: 'sound'),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer(
          (_) async => DeleteResult.createSuccess(
            'b' * 64,
            acceptance: DeleteAcceptance.everyRelay,
            deleteEvent: Event.fromJson({
              'id': 'b' * 64,
              'pubkey': _viewerPubkey,
              'created_at': 0,
              'kind': 5,
              'tags': <List<String>>[],
              'content': '',
              'sig': 'sig',
            }),
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSoundsTab(tester);
        await _chooseAction(tester, _l10n.savedSoundRemoveAction);

        expect(find.text(l10n.savedSoundDeleteConfirmTitle), findsOneWidget);
        expect(find.text(l10n.savedSoundRemoveConfirmTitle), findsNothing);

        await tester.tap(find.text(l10n.savedSoundDeleteForEveryone));
        await tester.pumpAndSettle();

        expect(find.text('My beat'), findsNothing);
        expect(find.text(l10n.savedSoundDeleted), findsOneWidget);
        expect(evictedSoundIds, [ownId]);
        final deleted =
            verify(
                  () => deletionService.deleteSound(
                    sound: captureAny(named: 'sound'),
                    reason: any(named: 'reason'),
                  ),
                ).captured.single
                as AudioEvent;
        expect(deleted.id, ownId);
      });

      testWidgets('keeps it public when only removed from the library', (
        tester,
      ) async {
        await saveOwnSound();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSoundsTab(tester);
        await _chooseAction(tester, _l10n.savedSoundRemoveAction);
        await tester.tap(find.text(l10n.savedSoundRemoveLocallyOnly));
        await tester.pumpAndSettle();

        expect(find.text('My beat'), findsNothing);
        verifyNever(
          () => deletionService.deleteSound(
            sound: any(named: 'sound'),
            reason: any(named: 'reason'),
          ),
        );
      });

      testWidgets('keeps the sound and says why when no relay took it', (
        tester,
      ) async {
        await saveOwnSound();
        when(
          () => deletionService.deleteSound(
            sound: any(named: 'sound'),
            reason: any(named: 'reason'),
          ),
        ).thenAnswer(
          (_) async => DeleteResult.failure(
            'silent',
            DeleteFailureKind.relayNoResponse,
          ),
        );
        final l10n = lookupAppLocalizations(const Locale('en'));

        await pumpSoundsTab(tester);
        await _chooseAction(tester, _l10n.savedSoundRemoveAction);
        await tester.tap(find.text(l10n.savedSoundDeleteForEveryone));
        await tester.pumpAndSettle();

        expect(find.text('My beat'), findsOneWidget);
        expect(
          find.text(l10n.shareMenuDeleteFailedRelayNoResponse),
          findsOneWidget,
        );
        expect(evictedSoundIds, isEmpty);
      });
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
      await _chooseAction(tester, _l10n.savedSoundEditAction);

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

      await _chooseAction(tester, _l10n.savedSoundEditAction);

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
                localizationsDelegates: appLocalizationsDelegates,
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

      testWidgets('says nothing while it syncs or once it has', (
        tester,
      ) async {
        final completer = Completer<SoundSyncOutcome>();
        when(syncRepository.reconcile).thenAnswer((_) => completer.future);
        final status = find.byKey(const Key('sound_sync_status'));

        await pumpSyncedSoundsTab(tester);
        // The tab syncs whenever it opens, so a status line would only make
        // the list jump.
        expect(status, findsNothing);

        completer.complete(
          const SoundSyncOutcome(
            pulled: 1,
            pushed: 0,
            deleted: 0,
            deletionsRetried: 0,
          ),
        );
        await tester.pumpAndSettle();

        expect(status, findsNothing);
      });

      testWidgets('says when sync failed', (tester) async {
        when(
          syncRepository.reconcile,
        ).thenAnswer((_) async => throw SyncIndexException('relay down'));

        await pumpSyncedSoundsTab(tester);
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.byKey(const Key('sound_sync_status'))).data,
          _l10n.soundSyncStatusFailed,
        );
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
                sharedPreferencesProvider.overrideWithValue(sharedPreferences),
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
                  localizationsDelegates: appLocalizationsDelegates,
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
