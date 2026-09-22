// ABOUTME: Widget tests for the standalone sound upload flow: pick a file,
// ABOUTME: credit it, share it, and land the result in My Sounds.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:nostr_sdk/event.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/blocs/sound_upload/sound_upload_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/screens/sound_upload/sound_upload_screen.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

class _MockImportService extends Mock implements LocalAudioImportService {}

class _MockPublisher extends Mock implements LocalAudioEventPublisher {}

class _FakeAudioEvent extends Fake implements AudioEvent {}

class _FakeAttribution extends Fake implements AudioShareAttribution {}

class _FakeAudioPlaybackService extends Fake implements AudioPlaybackService {
  final _playing = StreamController<bool>.broadcast();
  final loadedPaths = <String>[];
  bool _isPlaying = false;

  @override
  Stream<bool> get playingStream => _playing.stream;

  @override
  bool get isPlaying => _isPlaying;

  @override
  Future<Duration?> loadAudioFromFile(String filePath) async {
    loadedPaths.add(filePath);
    return const Duration(seconds: 6);
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> stop() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> dispose() async {
    await _playing.close();
  }
}

class _NoopSavedSoundMediaProbe implements SavedSoundMediaProbe {
  const _NoopSavedSoundMediaProbe();

  @override
  Future<SavedSoundMediaResult?> probe(AudioEvent sound) async => null;
}

const _self =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _soundEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

AudioEvent _imported() => AudioEvent.fromLocalImport(
  id: '${AudioEvent.localImportMarker}_1',
  filePath: '/tmp/beat.m4a',
  createdAt: 1,
  title: 'beat',
  mimeType: 'audio/mp4',
  duration: 6.2,
);

Event _publishedEvent() => Event.fromJson({
  'id': _soundEventId,
  'pubkey': _self,
  'created_at': 0,
  'kind': 1063,
  'tags': [
    ['url', 'https://cdn.example/beat.m4a'],
    ['title', 'beat'],
    ['creator', 'Alice'],
    ['p', _self],
    ['allow_audio_reuse', 'true'],
  ],
  'content': 'beat\nCreated by Alice',
  'sig': 'sig',
});

XFile _pickedFile() => XFile('/picked/beat.m4a', name: 'beat.m4a');

void main() {
  late SharedPreferences sharedPreferences;
  late _MockImportService importService;
  late _MockPublisher publisher;
  late _FakeAudioPlaybackService audioService;
  late AppLocalizations l10n;

  setUpAll(() {
    registerFallbackValue(_FakeAudioEvent());
    registerFallbackValue(_FakeAttribution());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    importService = _MockImportService();
    publisher = _MockPublisher();
    audioService = _FakeAudioPlaybackService();
    l10n = lookupAppLocalizations(const Locale('en'));
    when(
      () => importService.importAudioFile(
        sourcePath: any(named: 'sourcePath'),
        displayName: any(named: 'displayName'),
      ),
    ).thenAnswer((_) async => _imported());
    when(
      () => publisher.publish(
        audio: any(named: 'audio'),
        attribution: any(named: 'attribution'),
        allowAudioReuse: any(named: 'allowAudioReuse'),
      ),
    ).thenAnswer((_) async => LocalAudioPublished(_publishedEvent()));
  });

  Future<GoRouter> pumpUpload(
    WidgetTester tester, {
    Future<XFile?> Function()? pickAudioFile,
    SavedSoundsService? savedSoundsService,
  }) async {
    final router = GoRouter(
      initialLocation: SoundUploadScreen.path,
      routes: [
        GoRoute(
          path: '/',
          // A Scaffold, so the snackbar shown just before the pop has a
          // host to land on, as the Library screen provides in the app.
          builder: (_, _) => const Scaffold(body: Text('library sounds tab')),
          routes: [
            GoRoute(
              path: SoundUploadScreen.path.substring(1),
              builder: (_, _) => BlocProvider(
                create: (_) => SoundUploadCubit(
                  importService: importService,
                  publisher: publisher,
                  publisherName: 'Alice',
                  publisherPubkey: _self,
                ),
                child: SoundUploadView(
                  pickAudioFile: pickAudioFile ?? () async => _pickedFile(),
                  audioService: audioService,
                ),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      SavedSoundsScope(
        service: savedSoundsService ?? SavedSoundsService(sharedPreferences),
        mediaProbe: const _NoopSavedSoundMediaProbe(),
        localFileExists: (_) => true,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> pickFile(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('sound_upload_pick_file')));
    await tester.pumpAndSettle();
  }

  group(SoundUploadView, () {
    group('renders', () {
      testWidgets('opens on the file picker with no share bar', (
        tester,
      ) async {
        await pumpUpload(tester);

        expect(find.text(l10n.soundUploadTitle), findsOneWidget);
        expect(find.byKey(const Key('sound_upload_pick_file')), findsOneWidget);
        expect(find.byKey(const Key('sound_upload_share')), findsNothing);
        expect(find.byKey(const Key('audio_credit_title')), findsNothing);
      });

      testWidgets('shows the picked file, a prefilled credit, and share', (
        tester,
      ) async {
        await pumpUpload(tester);

        await pickFile(tester);

        expect(find.text('beat'), findsWidgets);
        expect(find.byKey(const Key('sound_upload_preview')), findsOneWidget);
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
        await tester.scrollUntilVisible(
          find.text(l10n.soundUploadReuseNotice),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(l10n.soundUploadReuseNotice), findsOneWidget);
        final share = tester.widget<DivineButton>(
          find.byKey(const Key('sound_upload_share')),
        );
        expect(share.onPressed, isNotNull);
        verify(
          () => importService.importAudioFile(
            sourcePath: '/picked/beat.m4a',
            displayName: 'beat.m4a',
          ),
        ).called(1);
      });

      testWidgets('does nothing when the picker is dismissed', (
        tester,
      ) async {
        await pumpUpload(tester, pickAudioFile: () async => null);

        await pickFile(tester);

        expect(find.byKey(const Key('sound_upload_pick_file')), findsOneWidget);
        verifyNever(
          () => importService.importAudioFile(
            sourcePath: any(named: 'sourcePath'),
            displayName: any(named: 'displayName'),
          ),
        );
      });
    });

    group('interactions', () {
      testWidgets('previews the picked file through the player', (
        tester,
      ) async {
        await pumpUpload(tester);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('sound_upload_preview')));
        await tester.pump();

        expect(audioService.loadedPaths, ['/tmp/beat.m4a']);
        expect(audioService.isPlaying, isTrue);
      });

      testWidgets('disables share until the credit is complete', (
        tester,
      ) async {
        await pumpUpload(tester);
        await pickFile(tester);

        await tester.tap(find.text(l10n.soundOwnWork));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('audio_credit_source')), findsOneWidget);
        expect(
          tester
              .widget<DivineButton>(find.byKey(const Key('sound_upload_share')))
              .onPressed,
          isNull,
        );

        await tester.enterText(
          find.byKey(const Key('audio_credit_source')),
          'https://example.com/source',
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<DivineButton>(find.byKey(const Key('sound_upload_share')))
              .onPressed,
          isNotNull,
        );
      });

      testWidgets('shares the sound, saves it to Sounds, and pops', (
        tester,
      ) async {
        final router = await pumpUpload(tester);
        await pickFile(tester);
        await tester.enterText(
          find.byKey(const Key('audio_credit_tags')),
          '#beat kitchen',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('sound_upload_share')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
        expect(find.text(l10n.soundUploadShared), findsOneWidget);
        expect(
          SavedSoundsService(
            sharedPreferences,
          ).loadSavedSounds().map((sound) => sound.audio.id),
          [_soundEventId],
        );
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

      testWidgets('stays put and says so when publishing fails', (
        tester,
      ) async {
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
        final router = await pumpUpload(tester);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('sound_upload_share')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, SoundUploadScreen.path);
        expect(find.text(l10n.soundUploadFailed), findsOneWidget);
        expect(find.byKey(const Key('audio_credit_title')), findsOneWidget);
        expect(
          SavedSoundsService(sharedPreferences).loadSavedSounds(),
          isEmpty,
        );
      });

      testWidgets('stays put with a retry when saving to Sounds fails', (
        tester,
      ) async {
        final service = _FlakySavedSoundsService(sharedPreferences);
        final router = await pumpUpload(tester, savedSoundsService: service);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('sound_upload_share')));
        await tester.pumpAndSettle();

        // Published, but the library write threw: no pop, say so, offer a
        // retry — a published sound with no library row could never be
        // deleted from anywhere else.
        expect(router.state.uri.path, SoundUploadScreen.path);
        expect(find.text(l10n.soundsSaveFailed), findsOneWidget);
        expect(find.byKey(const Key('sound_upload_share')), findsNothing);
        expect(
          find.byKey(const Key('sound_upload_retry_save')),
          findsOneWidget,
        );
        expect(service.loadSavedSounds(), isEmpty);
        verify(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).called(1);

        service.heal();
        await tester.tap(find.byKey(const Key('sound_upload_retry_save')));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
        expect(find.text(l10n.soundUploadShared), findsOneWidget);
        expect(
          service.loadSavedSounds().map((sound) => sound.audio.id),
          [_soundEventId],
        );
        // Retrying the save must not publish a second Kind 1063.
        verifyNever(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        );
      });

      testWidgets('cannot swap the file while a failed save is outstanding', (
        tester,
      ) async {
        final service = _FlakySavedSoundsService(sharedPreferences);
        await pumpUpload(tester, savedSoundsService: service);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('sound_upload_share')));
        await tester.pumpAndSettle();

        // The bar is bound to the sound already on the relay. Picking another
        // file here would leave that bar in place with no way to publish the
        // new pick, so Change is disabled while the failure stands. The retry
        // window itself is covered by the next test.
        expect(
          find.byKey(const Key('sound_upload_retry_save')),
          findsOneWidget,
        );
        final change = tester.widget<DivineButton>(
          find.byKey(const Key('sound_upload_change_file')),
        );
        expect(change.onPressed, isNull);
      });

      testWidgets('keeps the swap guard while the retry is in flight', (
        tester,
      ) async {
        final service = _ParkedSavedSoundsService(sharedPreferences);
        await pumpUpload(tester, savedSoundsService: service);
        await pickFile(tester);

        await tester.tap(find.byKey(const Key('sound_upload_share')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('sound_upload_retry_save')),
          findsOneWidget,
        );

        // Hold the retry open. Clearing the failure flag here would hand the
        // user back the same dead end the guard exists to close, bounded by
        // however long the persist takes.
        await tester.tap(find.byKey(const Key('sound_upload_retry_save')));
        await tester.pump();

        expect(
          tester
              .widget<DivineButton>(
                find.byKey(const Key('sound_upload_change_file')),
              )
              .onPressed,
          isNull,
          reason: 'Change must stay guarded for the whole retry',
        );
        expect(
          tester
              .widget<DivineButton>(
                find.byKey(const Key('sound_upload_retry_save')),
              )
              .onPressed,
          isNull,
          reason: 'the same save must not be startable twice',
        );

        service.release();
        await tester.pumpAndSettle();
      });

      testWidgets('reports an unreadable file and keeps the picker', (
        tester,
      ) async {
        when(
          () => importService.importAudioFile(
            sourcePath: any(named: 'sourcePath'),
            displayName: any(named: 'displayName'),
          ),
        ).thenThrow(const LocalAudioImportException('nope'));
        await pumpUpload(tester);

        await pickFile(tester);

        expect(find.text(l10n.videoEditorAudioImportFailed), findsOneWidget);
        expect(find.byKey(const Key('sound_upload_pick_file')), findsOneWidget);
      });

      testWidgets('blocks back navigation while publishing', (tester) async {
        final gate = Completer<LocalAudioPublishResult>();
        when(
          () => publisher.publish(
            audio: any(named: 'audio'),
            attribution: any(named: 'attribution'),
            allowAudioReuse: any(named: 'allowAudioReuse'),
          ),
        ).thenAnswer((_) => gate.future);
        final router = await pumpUpload(tester);
        await pickFile(tester);
        await tester.tap(find.byKey(const Key('sound_upload_share')));
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
        expect(router.state.uri.path, SoundUploadScreen.path);
        expect(
          tester
              .widget<DivineButton>(find.byKey(const Key('sound_upload_share')))
              .isLoading,
          isTrue,
        );

        gate.complete(LocalAudioPublished(_publishedEvent()));
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/');
      });
    });
  });
}

/// Fails every library write until [heal] is called, standing in for a
/// `SharedPreferences` write that returns false.
/// Fails the first save, then parks the retry until [release] is called.
class _ParkedSavedSoundsService extends SavedSoundsService {
  _ParkedSavedSoundsService(super._preferences);

  bool _failed = false;
  final _parked = Completer<SavedSoundSaveResult>();

  void release() => _parked.complete(SavedSoundSaveResult.saved);

  @override
  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) {
    if (!_failed) {
      _failed = true;
      throw StateError('Failed to persist saved sounds');
    }
    return _parked.future;
  }
}

class _FlakySavedSoundsService extends SavedSoundsService {
  _FlakySavedSoundsService(super._preferences);

  bool _failing = true;

  void heal() => _failing = false;

  @override
  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) {
    if (_failing) throw StateError('Failed to persist saved sounds');
    return super.saveSavedSound(sound);
  }
}
