import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart' show AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide AspectRatio;
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(VideoMetadataCaptureClipPreview, () {
    late DivineVideoClip testClip;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      testClip = DivineVideoClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        thumbnailPath: 'test_thumbnail.jpg',
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );
    });

    testWidgets('displays clip thumbnail when available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(
                VideoEditorProviderState(finalRenderedClip: testClip),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      // Should display thumbnail image
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('displays placeholder when no thumbnail', (tester) async {
      final clipNoThumbnail = DivineVideoClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([clipNoThumbnail]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      // Should display placeholder icon
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DivineIcon && widget.icon == DivineIconName.playCircle,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows processing overlay when isProcessing is true', (
      tester,
    ) async {
      final state = VideoEditorProviderState(isProcessing: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      // Processing overlay should be present
      expect(find.byType(VideoEditorProcessingOverlay), findsOneWidget);
    });

    testWidgets('play button is disabled when no final rendered clip', (
      tester,
    ) async {
      final state = VideoEditorProviderState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      // Play indicator should exist but be disabled (no onTap callback)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('play button is enabled when final rendered clip exists', (
      tester,
    ) async {
      final finalClip = DivineVideoClip(
        id: 'final-clip',
        video: EditorVideo.file('final.mp4'),
        duration: const Duration(seconds: 15),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      final state = VideoEditorProviderState(finalRenderedClip: finalClip);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      // Play button should be tappable
      final playButton = find.bySemanticsLabel('Open post preview screen');
      expect(playButton, findsOneWidget);
    });

    testWidgets('has correct aspect ratio', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));

      expect(aspectRatio.aspectRatio, equals(testClip.targetAspectRatio.value));
    });

    testWidgets('has Hero widget with correct tag', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, equals('Video-metadata-clip-preview-video'));
    });

    testWidgets('displays with correct height', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(of: find.byType(Hero), matching: find.byType(SizedBox)),
      );

      expect(sizedBox.height, equals(200));
    });

    testWidgets('has rounded corners', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });

    testWidgets(
      'cover-editor tap is disabled until finalRenderedClip is available',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(VideoEditorProviderState()),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataCaptureClipPreview()),
            ),
          ),
        );

        final tappable = tester.widget<GestureDetector>(
          find
              .descendant(
                of: find.byType(ClipRRect),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(
          tappable.onTap,
          isNull,
          reason:
              'Cover editor must not open before the final rendered clip is '
              'ready, otherwise VideoMetadataCoverScreen receives a stale clip.',
        );
      },
    );

    testWidgets(
      'cover-editor tap is enabled once finalRenderedClip is available',
      (tester) async {
        final finalClip = DivineVideoClip(
          id: 'final-clip',
          video: EditorVideo.file('final.mp4'),
          duration: const Duration(seconds: 15),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(
                  VideoEditorProviderState(finalRenderedClip: finalClip),
                ),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: VideoMetadataCaptureClipPreview()),
            ),
          ),
        );

        final tappable = tester.widget<GestureDetector>(
          find
              .descendant(
                of: find.byType(ClipRRect),
                matching: find.byType(GestureDetector),
              )
              .first,
        );
        expect(tappable.onTap, isNotNull);
      },
    );

    testWidgets('open-preview stays activatable alongside the cover button', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final finalClip = DivineVideoClip(
        id: 'final-clip',
        video: EditorVideo.file('final.mp4'),
        duration: const Duration(seconds: 15),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(
                VideoEditorProviderState(finalRenderedClip: finalClip),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureClipPreview()),
          ),
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      // The cover button sits inside the preview's tap target. Wrapping it in
      // an excludeSemantics Semantics() cost the enclosing preview node its
      // tap action — the whole 200px stage went inert for TalkBack while the
      // pointer path still worked.
      final openPreview = find.bySemanticsLabel(
        l10n.videoMetadataOpenPreviewSemanticLabel,
      );
      expect(openPreview, findsOneWidget);
      expect(
        tester
            .getSemantics(openPreview)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverTitle),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}

/// Mock clip manager notifier for testing
class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Mock video editor notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
