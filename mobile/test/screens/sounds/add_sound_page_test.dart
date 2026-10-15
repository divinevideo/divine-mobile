// ABOUTME: Widget tests for the Add sound screen: pick, preview, save privately
// ABOUTME: under a name, or share publicly with a credit and land in My Sounds.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/add_sound/add_sound_cubit.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/screens/sounds/add_sound_page.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

class _MockPublisher extends Mock implements LocalAudioEventPublisher {}

class _FakeAudioEvent extends Fake implements AudioEvent {}

class _FakeAttribution extends Fake implements AudioShareAttribution {}

class _FakeAudioPlaybackService extends Fake implements AudioPlaybackService {
  final loadedPaths = <String>[];
  Completer<void>? _playing;

  @override
  Future<Duration?> loadAudioFromFile(String filePath) async {
    loadedPaths.add(filePath);
    return const Duration(seconds: 3);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> play() => (_playing = Completer<void>()).future;

  @override
  Future<void> pause() async => _resolvePlay();

  @override
  Future<void> stop() async => _resolvePlay();

  void _resolvePlay() {
    final playing = _playing;
    _playing = null;
    if (playing != null && !playing.isCompleted) playing.complete();
  }
}

class _NoopSavedSoundMediaProbe implements SavedSoundMediaProbe {
  const _NoopSavedSoundMediaProbe();

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

/// Avoids real file IO so the page's status transitions resolve in a microtask
/// instead of racing a directory copy and a spinner animation.
class _FakeImportService extends LocalAudioImportService {
  _FakeImportService(this.storageDir);

  final Directory storageDir;

  @override
  Future<AudioEvent> importAudioFile({
    required String sourcePath,
    required String displayName,
  }) async {
    if (!displayName.toLowerCase().endsWith('.mp3')) {
      throw const LocalAudioImportException(
        'unsupported',
        reason: LocalAudioImportFailureReason.unsupportedType,
      );
    }
    final file = File('${storageDir.path}/$displayName')
      ..writeAsBytesSync([1, 2, 3]);
    return AudioEvent.fromLocalImport(
      id: 'local_import_test',
      filePath: file.path,
      createdAt: 1,
      title: 'beat',
      mimeType: 'audio/mpeg',
      duration: 3,
    );
  }
}

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Event _publishedEvent() => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': [
    ['url', 'https://cdn.example/beat.mp3'],
    ['title', 'beat'],
    ['creator', 'Alice'],
    ['p', _self],
    ['allow_audio_reuse', 'true'],
  ],
  'content': 'beat\nCreated by Alice',
  'sig': 'sig',
});

void main() {
  late SharedPreferences sharedPreferences;
  late Directory root;
  late Directory storageDir;
  late File source;
  late List<String> reclaimed;
  late _FakeAudioPlaybackService audio;
  late _MockPublisher publisher;
  late AppLocalizations l10n;
  AudioImportPickedFile? nextPick;

  setUpAll(() {
    registerFallbackValue(_FakeAudioEvent());
    registerFallbackValue(_FakeAttribution());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    root = await Directory.systemTemp.createTemp('add_sound_page_test_');
    storageDir = Directory('${root.path}/storage')..createSync();
    source = File('${root.path}/beat.mp3')..writeAsBytesSync([1, 2, 3]);
    reclaimed = <String>[];
    audio = _FakeAudioPlaybackService();
    publisher = _MockPublisher();
    l10n = lookupAppLocalizations(const Locale('en'));
    nextPick = AudioImportPickedFile(path: source.path, name: 'beat.mp3');
    when(
      () => publisher.publish(
        audio: any(named: 'audio'),
        attribution: any(named: 'attribution'),
        allowAudioReuse: any(named: 'allowAudioReuse'),
      ),
    ).thenAnswer((_) async => LocalAudioPublished(_publishedEvent()));
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<GoRouter> pump(
    WidgetTester tester, {
    required Widget page,
    List<Override> overrides = const [],
    SavedSoundsService? savedSoundsService,
  }) async {
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          // A Scaffold, so the snackbar shown just before the pop has a
          // host to land on, as the Library screen provides in the app.
          builder: (_, _) => const Scaffold(body: Text('library sounds tab')),
          routes: [GoRoute(path: 'add', builder: (_, _) => page)],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          audioPlaybackServiceProvider.overrideWithValue(audio),
          ...overrides,
        ],
        child: SavedSoundsScope(
          service: savedSoundsService ?? SavedSoundsService(sharedPreferences),
          mediaProbe: const _NoopSavedSoundMediaProbe(),
          localFileExists: (_) async => true,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: VineTheme.theme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// The view behind an injected cubit, so the public share runs against a
  /// mock publisher and a signed-in credit.
  Future<GoRouter> pumpView(
    WidgetTester tester, {
    SavedSoundsService? savedSoundsService,
  }) {
    return pump(
      tester,
      savedSoundsService: savedSoundsService,
      page: Builder(
        builder: (context) => BlocProvider(
          create: (_) => AddSoundCubit(
            importService: _FakeImportService(storageDir),
            pickFile: () async => nextPick,
            saveSound: context.read<SavedSoundsBloc>().saveSound,
            reclaimAudio: (path) async => reclaimed.add(path),
            viewerAccountId: () => _self,
            publisher: () => publisher,
            publisherName: 'Alice',
            publisherPubkey: _self,
          ),
          child: const AddSoundView(),
        ),
      ),
    );
  }

  Future<void> pickFile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_sound_pick')));
    await tester.pumpAndSettle();
  }

  Future<void> sharePublicly(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('add_sound_share_publicly')));
    await tester.pumpAndSettle();
  }

  DivineButton saveButton(WidgetTester tester) =>
      tester.widget<DivineButton>(find.byKey(const Key('add_sound_save')));

  List<SavedSound> librarySounds([SavedSoundsService? service]) =>
      (service ?? SavedSoundsService(sharedPreferences)).loadSavedSounds();

  group(AddSoundPage, () {
    List<Override> pageOverrides() => [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      documentsPathProvider.overrideWithValue('/documents'),
      currentAccountIdProvider.overrideWithValue(null),
      localAudioImportServiceProvider.overrideWithValue(
        _FakeImportService(storageDir),
      ),
      audioImportFilePickerProvider.overrideWithValue(
        (_) =>
            () async => nextPick,
      ),
      audioImportReclaimerProvider.overrideWithValue(
        (path) async => reclaimed.add(path),
      ),
    ];

    testWidgets('names and privately saves a picked sound, then closes', (
      tester,
    ) async {
      final router = await pump(
        tester,
        page: const AddSoundPage(),
        overrides: pageOverrides(),
      );

      await pickFile(tester);
      await tester.enterText(
        find.byKey(const Key('add_sound_name_field')),
        'Beach loop',
      );
      await tester.tap(find.byKey(const Key('add_sound_save')));
      await tester.pumpAndSettle();

      final saved = librarySounds();
      expect(saved.single.personalLabel, 'Beach loop');
      expect(saved.single.audio.isLocalImport, isTrue);
      // Saved is success only after the durable write, then the flow closes.
      expect(router.state.uri.path, '/');
      expect(find.text(l10n.soundsSavedToLibrary), findsOneWidget);
      expect(reclaimed, isEmpty);
      verifyNever(
        () => publisher.publish(
          audio: any(named: 'audio'),
          attribution: any(named: 'attribution'),
          allowAudioReuse: any(named: 'allowAudioReuse'),
        ),
      );
    });

    testWidgets('leaving without saving reclaims the copied file', (
      tester,
    ) async {
      await pump(
        tester,
        page: const AddSoundPage(),
        overrides: pageOverrides(),
      );
      await pickFile(tester);

      // Replacing the page disposes the cubit, which reclaims the unsaved copy.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(reclaimed, hasLength(1));
    });
  });

  group(AddSoundView, () {
    group('renders', () {
      testWidgets('opens on the file picker with no save bar', (tester) async {
        await pumpView(tester);

        expect(find.text(l10n.soundsAddSound), findsOneWidget);
        expect(find.text(l10n.soundsImportPromptDescription), findsOneWidget);
        expect(find.byKey(const Key('add_sound_pick')), findsOneWidget);
        expect(find.byKey(const Key('add_sound_save')), findsNothing);
      });

      testWidgets('keeps a picked sound private by default', (tester) async {
        await pumpView(tester);

        await pickFile(tester);

        expect(find.text('beat'), findsOneWidget);
        expect(find.byKey(const Key('add_sound_name_field')), findsOneWidget);
        expect(find.byKey(const Key('audio_credit_title')), findsNothing);
        expect(saveButton(tester).label, l10n.savedSoundSaveAction);
        expect(saveButton(tester).onPressed, isNotNull);
      });

      testWidgets('sharing swaps the name for a prefilled public credit', (
        tester,
      ) async {
        await pumpView(tester);
        await pickFile(tester);

        await sharePublicly(tester);

        expect(find.byKey(const Key('add_sound_name_field')), findsNothing);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byKey(const Key('audio_credit_creator')),
                  matching: find.byType(TextField),
                ),
              )
              .controller
              ?.text,
          'Alice',
        );
        expect(find.byKey(const Key('audio_credit_source')), findsNothing);
        expect(saveButton(tester).label, l10n.soundUploadShareAction);
        expect(saveButton(tester).onPressed, isNotNull);
      });
    });

    group('interactions', () {
      testWidgets('previews the picked file through the player', (
        tester,
      ) async {
        await pumpView(tester);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('add_sound_preview')));
        await tester.pump();

        expect(audio.loadedPaths, ['${storageDir.path}/beat.mp3']);
      });

      testWidgets('reports an unsupported file and saves none', (
        tester,
      ) async {
        nextPick = AudioImportPickedFile(path: source.path, name: 'notes.txt');
        await pumpView(tester);

        await pickFile(tester);

        expect(find.text(l10n.soundsImportUnsupportedFormat), findsOneWidget);
        expect(find.byKey(const Key('add_sound_pick')), findsOneWidget);
        expect(librarySounds(), isEmpty);
      });

      testWidgets('disables share until the credit is complete', (
        tester,
      ) async {
        await pumpView(tester);
        await pickFile(tester);
        await sharePublicly(tester);

        await tester.tap(find.text(l10n.soundOwnWork));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('audio_credit_source')), findsOneWidget);
        expect(saveButton(tester).onPressed, isNull);

        await tester.enterText(
          find.byKey(const Key('audio_credit_source')),
          'https://example.com/source',
        );
        await tester.pumpAndSettle();

        expect(saveButton(tester).onPressed, isNotNull);
      });

      testWidgets('shares the sound, saves it to Sounds, and pops', (
        tester,
      ) async {
        final router = await pumpView(tester);
        await pickFile(tester);
        await sharePublicly(tester);
        await tester.enterText(
          find.byKey(const Key('audio_credit_tags')),
          '#beat kitchen',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
        expect(find.text(l10n.soundUploadShared), findsOneWidget);
        expect(librarySounds().map((sound) => sound.audio.id), [
          _soundEventId,
        ]);
        final captured =
            verify(
                  () => publisher.publish(
                    audio: any(named: 'audio'),
                    attribution: captureAny(named: 'attribution'),
                    allowAudioReuse: true,
                  ),
                ).captured.single
                as AudioShareAttribution;
        expect(captured.publicTags, ['beat', 'kitchen']);
        expect(captured.creatorPubkey, _self);
      });

      testWidgets('stays put and says so when sharing fails', (tester) async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer(
          (_) async => const LocalAudioPublishFailed(
            LocalAudioPublishFailure.relayRejected,
          ),
        );
        final router = await pumpView(tester);
        await pickFile(tester);
        await sharePublicly(tester);

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/add');
        expect(find.text(l10n.soundUploadFailed), findsOneWidget);
        expect(find.byKey(const Key('audio_credit_title')), findsOneWidget);
        expect(librarySounds(), isEmpty);
      });

      testWidgets('takes the keyboard off the credit while sharing', (
        tester,
      ) async {
        final gate = Completer<LocalAudioPublishResult>();
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) => gate.future);
        await pumpView(tester);
        await pickFile(tester);
        await sharePublicly(tester);
        final title = find.byKey(const Key('audio_credit_title'));
        await tester.showKeyboard(title);
        expect(tester.testTextInput.hasAnyClients, isTrue);

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pump();

        // Typing now would change the field but not the credit being shared,
        // so a retry would publish a credit other than the one on screen.
        expect(tester.testTextInput.hasAnyClients, isFalse);

        gate.complete(
          const LocalAudioPublishFailed(LocalAudioPublishFailure.relayRejected),
        );
        await tester.pumpAndSettle();

        await tester.showKeyboard(title);
        expect(
          tester.testTextInput.hasAnyClients,
          isTrue,
          reason: 'a failed share hands the credit back for editing',
        );
      });

      testWidgets('keeps the share label while the first Sounds write runs', (
        tester,
      ) async {
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) async => LocalAudioPublished(_publishedEvent()));
        final service = _HeldSavedSoundsService(sharedPreferences);
        final router = await pumpView(tester, savedSoundsService: service);
        await pickFile(tester);
        await sharePublicly(tester);

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pump();
        await tester.pump();

        // Published, and the Sounds write it leads to is in flight: nothing
        // has failed, so nothing should read as a retry yet.
        expect(service.isHolding, isTrue);
        expect(saveButton(tester).isLoading, isTrue);
        expect(saveButton(tester).label, l10n.soundUploadShareAction);

        service.release();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
        expect(find.text(l10n.soundUploadShared), findsOneWidget);
      });

      testWidgets('offers a save-only retry when Sounds fails after sharing', (
        tester,
      ) async {
        final service = _ParkedSavedSoundsService(sharedPreferences);
        final router = await pumpView(tester, savedSoundsService: service);
        await pickFile(tester);
        await sharePublicly(tester);

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pumpAndSettle();

        // Published, but the library write threw: no pop, say so, offer a
        // retry — a published sound with no library row could never be
        // deleted from anywhere else. The file and the share choice are
        // locked to the sound already on the relay.
        expect(router.state.uri.path, '/add');
        expect(find.text(l10n.soundsSaveFailed), findsOneWidget);
        expect(saveButton(tester).label, l10n.soundUploadRetrySaveAction);
        expect(
          tester
              .widget<DivineButton>(
                find.byKey(const Key('add_sound_change_file')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<DivineSwitchTile>(
                find.byKey(const Key('add_sound_share_publicly')),
              )
              .onChanged,
          isNull,
        );

        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pump();
        expect(
          saveButton(tester).onPressed,
          isNull,
          reason: 'the same save must not be startable twice',
        );

        service.release();
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
        expect(find.text(l10n.soundUploadShared), findsOneWidget);
        // Retrying the save must not publish a second Kind 1063.
        verify(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).called(1);
      });

      testWidgets('blocks back navigation while sharing', (tester) async {
        final gate = Completer<LocalAudioPublishResult>();
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) => gate.future);
        final router = await pumpView(tester);
        await pickFile(tester);
        await sharePublicly(tester);
        await tester.tap(find.byKey(const Key('add_sound_save')));
        await tester.pump();

        final popScope = tester.widget(
          find.byWidgetPredicate((widget) => widget is PopScope),
        ) as PopScope;
        expect(popScope.canPop, isFalse);

        // The app bar's back button must not sidestep the PopScope either.
        await tester.tap(
          find.bySemanticsIdentifier(DiVineAppBarLeading.backButtonSemanticId),
        );
        await tester.pump();
        expect(router.state.uri.path, '/add');
        expect(saveButton(tester).isLoading, isTrue);

        gate.complete(LocalAudioPublished(_publishedEvent()));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
      });
    });
  });
}

/// Holds every save until [release] is called.
class _HeldSavedSoundsService extends SavedSoundsService {
  _HeldSavedSoundsService(super._preferences);

  final _held = Completer<void>();
  bool isHolding = false;

  void release() => _held.complete();

  @override
  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) async {
    isHolding = true;
    await _held.future;
    return super.saveSavedSound(sound);
  }
}

/// Fails the first save, then parks the retry until [release] is called.
class _ParkedSavedSoundsService extends SavedSoundsService {
  _ParkedSavedSoundsService(super._preferences);

  bool _failed = false;
  final _parked = Completer<void>();

  void release() => _parked.complete();

  @override
  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) async {
    if (!_failed) {
      _failed = true;
      throw StateError('Failed to persist saved sounds');
    }
    await _parked.future;
    return super.saveSavedSound(sound);
  }
}
