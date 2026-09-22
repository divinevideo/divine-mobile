// ABOUTME: Widget tests for the private sound import screen.
// ABOUTME: Verifies pick, preview, naming, durable save, and failure copy.

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_scope.dart';
import 'package:openvine/blocs/sound_import/sound_import_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/documents_path_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/screens/sounds/import_sound_page.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';

class _FakeAudioPlaybackService extends Fake implements AudioPlaybackService {
  final positions = StreamController<Duration>.broadcast();
  final loadedPaths = <String>[];
  Completer<void>? _playing;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Future<Duration?> loadAudioFromFile(String filePath) async {
    loadedPaths.add(filePath);
    return const Duration(seconds: 3);
  }

  @override
  Future<Duration?> loadAudio(String url) async {
    loadedPaths.add(url);
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

  @override
  Future<void> dispose() async {}

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
      title: 'Pick',
      mimeType: 'audio/mpeg',
      duration: 3,
    );
  }
}

void main() {
  group(ImportSoundPage, () {
    late SharedPreferences sharedPreferences;
    late Directory root;
    late Directory storageDir;
    late File source;
    late List<String> reclaimed;
    late _FakeAudioPlaybackService audio;
    AudioImportPickedFile? nextPick;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      root = await Directory.systemTemp.createTemp('import_page_test_');
      storageDir = Directory('${root.path}/storage')..createSync();
      source = File('${root.path}/pick.mp3')..writeAsBytesSync([1, 2, 3]);
      reclaimed = <String>[];
      audio = _FakeAudioPlaybackService();
      nextPick = AudioImportPickedFile(path: source.path, name: 'pick.mp3');
    });

    tearDown(() async {
      await audio.positions.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
            audioPlaybackServiceProvider.overrideWithValue(audio),
          ],
          child: SavedSoundsScope(
            service: SavedSoundsService(sharedPreferences),
            mediaProbe: const _NoopSavedSoundMediaProbe(),
            localFileExists: (_) async => true,
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: VineTheme.theme,
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const ImportSoundPage(),
                  ),
                  GoRoute(
                    path: '/home/0',
                    builder: (_, _) => const Text('home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the pick prompt before a file is chosen', (
      tester,
    ) async {
      await pumpPage(tester);

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.soundsImportPromptTitle), findsOneWidget);
      expect(find.byKey(const Key('import_sound_pick')), findsOneWidget);
      expect(find.byKey(const Key('import_sound_save')), findsNothing);
    });

    testWidgets('a cancelled pick leaves the prompt up', (tester) async {
      nextPick = null;

      await pumpPage(tester);
      await tester.tap(find.byKey(const Key('import_sound_pick')));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.soundsImportPromptTitle), findsOneWidget);
    });

    testWidgets('previews, names, and durably saves the picked sound', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('import_sound_pick')));
      await tester.pumpAndSettle();

      // A copied sound can be previewed before it is saved.
      await tester.tap(find.byKey(const Key('import_sound_preview')));
      await tester.pump();
      expect(audio.loadedPaths, hasLength(1));

      await tester.enterText(
        find.byKey(const Key('import_sound_name_field')),
        'Beach loop',
      );
      await tester.tap(find.byKey(const Key('import_sound_save')));
      await tester.pumpAndSettle();

      final saved = SavedSoundsService(sharedPreferences).loadSavedSounds();
      expect(saved.single.personalLabel, 'Beach loop');
      expect(saved.single.audio.isLocalImport, isTrue);
      // Saved is success only after the durable write, then the flow closes.
      expect(find.text('home'), findsOneWidget);
      expect(reclaimed, isEmpty);
    });

    testWidgets('an unsupported file reports a format failure and saves none', (
      tester,
    ) async {
      nextPick = AudioImportPickedFile(path: source.path, name: 'notes.txt');

      await pumpPage(tester);
      await tester.tap(find.byKey(const Key('import_sound_pick')));
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.soundsImportUnsupportedFormat), findsOneWidget);
      expect(SavedSoundsService(sharedPreferences).loadSavedSounds(), isEmpty);
    });

    testWidgets('leaving without saving reclaims the copied file', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.byKey(const Key('import_sound_pick')));
      await tester.pumpAndSettle();

      // Replacing the page disposes the cubit, which reclaims the unsaved copy.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(reclaimed, hasLength(1));
    });
  });
}
