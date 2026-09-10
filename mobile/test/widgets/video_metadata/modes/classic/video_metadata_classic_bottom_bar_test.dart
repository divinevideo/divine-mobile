import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(VideoMetadataClassicBottomBar, () {
    late SharedPreferences prefs;
    late _MockGallerySaveService mockGallerySaveService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockGallerySaveService = _MockGallerySaveService();
      when(
        () => mockGallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveSuccess());
    });

    testWidgets('renders Post button labeled "Done"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('button is disabled when metadata is invalid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(animatedOpacity.opacity, lessThan(1));
    });

    testWidgets('button is enabled when metadata is valid', (tester) async {
      final validState = VideoEditorProviderState(
        title: 'Test Video',
        finalRenderedClip: DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(validState),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(animatedOpacity.opacity, equals(1.0));
    });

    testWidgets('tapping Done calls postVideo when valid', (tester) async {
      var postVideoCalled = false;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: DivineVideoClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ),
        onPostVideo: () => postVideoCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(() => mockNotifier),
            gallerySaveServiceProvider.overrideWith(
              (ref) => mockGallerySaveService,
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });

    testWidgets('Post button is activatable by a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final validState = VideoEditorProviderState(
        title: 'Test Video',
        finalRenderedClip: DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(validState),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataClassicBottomBar()),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      final postFinder = find.bySemanticsLabel(
        l10n.videoMetadataPostSemanticLabel,
      );
      expect(postFinder, findsOneWidget);
      final postData = tester.getSemantics(postFinder).getSemanticsData();

      expect(postData.hasAction(SemanticsAction.tap), isTrue);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.identifier == 'post_button',
        ),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onPostVideo});

  final VideoEditorProviderState _state;
  final VoidCallback? onPostVideo;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> postVideo(BuildContext context) async {
    onPostVideo?.call();
  }
}
