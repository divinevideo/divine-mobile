// ABOUTME: Tests for the chroma-key backdrop clip picker: it hands back the
// ABOUTME: file a library clip plays, following bakes that land while open.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/permissions_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_clip_picker_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:shared_preferences/shared_preferences.dart';

class _MockClipLibraryService extends Mock implements ClipLibraryService {}

class _MockGallerySaveService extends Mock implements GallerySaveService {}

/// A clip manager whose library revision moves the way a bake landing in the
/// library moves it.
class _BakingClipManager extends ClipManagerNotifier {
  @override
  ClipManagerState build() => ClipManagerState();

  void landBake() =>
      state = state.copyWith(libraryRevision: state.libraryRevision + 1);
}

void main() {
  group('showChromaKeyClipPicker', () {
    late Directory tmp;
    late _MockClipLibraryService library;
    late SharedPreferences prefs;

    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('chroma_key_clip_picker');
      library = _MockClipLibraryService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    DivineVideoClip take(String path) => DivineVideoClip(
      id: 'take',
      video: EditorVideo.file(path),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.vertical,
      originalAspectRatio: 9 / 16,
    );

    testWidgets('hands back the keyed file of a take baked while it is open', (
      tester,
    ) async {
      final raw = File('${tmp.path}/raw.mp4')..writeAsStringSync('raw');
      final keyed = File('${tmp.path}/keyed.mp4')..writeAsStringSync('keyed');
      var baked = false;
      when(
        () => library.getAllClips(),
      ).thenAnswer((_) async => [take(baked ? keyed.path : raw.path)]);
      when(() => library.recoverMissingAssets(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as List<DivineVideoClip>,
      );
      when(() => library.getCategories()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipLibraryServiceProvider.overrideWithValue(library),
            gallerySaveServiceProvider.overrideWithValue(
              _MockGallerySaveService(),
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(_BakingClipManager.new),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SizedBox.expand()),
          ),
        ),
      );

      final host = tester.element(find.byType(Scaffold));
      String? picked;
      unawaited(
        showChromaKeyClipPicker(host).then((path) => picked = path),
      );
      await tester.pumpAndSettle();

      // The take's keyed file lands while the picker is showing its raw one.
      baked = true;
      (ProviderScope.containerOf(
        host,
      ).read(clipManagerProvider.notifier) as _BakingClipManager).landBake();
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(GridView),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();

      expect(picked, keyed.path);
    });
  });
}
