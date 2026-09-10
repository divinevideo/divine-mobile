// ABOUTME: Tests for VideoEditorProcessingOverlay widget
// ABOUTME: Verifies opacity and visibility based on clip processing state

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

DivineVideoClip _createClip({Completer<bool>? processingCompleter}) {
  return DivineVideoClip(
    id: 'test-clip',
    video: EditorVideo.file('/test/video.mp4'),
    duration: const Duration(seconds: 2),
    recordedAt: DateTime.now(),
    targetAspectRatio: model.AspectRatio.square,
    processingCompleter: processingCompleter,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group('VideoEditorProcessingOverlay', () {
    late ProviderContainer container;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      sharedPreferences = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
      );
      container.read(videoEditorProvider.notifier).setDraftId('draft-test');
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('should be visible when clip is processing', (tester) async {
      final completer = Completer<bool>();
      final clip = _createClip(processingCompleter: completer);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoEditorProcessingOverlay(clip: clip)),
          ),
        ),
      );

      // Should show overlay when processing
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(180, 0, 0, 0),
      );
      expect(overlayFinder, findsOneWidget);
    });

    testWidgets('should be invisible when clip is not processing', (
      tester,
    ) async {
      final clip = _createClip(); // No processingCompleter

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoEditorProcessingOverlay(clip: clip)),
          ),
        ),
      );

      // Should not show overlay when not processing
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(140, 0, 0, 0),
      );
      expect(overlayFinder, findsNothing);
    });

    testWidgets('should be invisible when processing is completed', (
      tester,
    ) async {
      final completer = Completer<bool>()..complete(true);
      final clip = _createClip(processingCompleter: completer);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoEditorProcessingOverlay(clip: clip)),
          ),
        ),
      );

      // Should not show overlay when processing is complete
      final overlayFinder = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color.fromARGB(140, 0, 0, 0),
      );
      expect(overlayFinder, findsNothing);
    });

    testWidgets(
      'shows an error + retry affordance instead of a spinner when the render '
      'failed, and invokes onRetry (#6058)',
      (tester) async {
        final clip = _createClip();
        var retried = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: VideoEditorProcessingOverlay(
                  clip: clip,
                  // Failure must win even while isProcessing is still true.
                  isProcessing: true,
                  hasFailed: true,
                  onRetry: () => retried = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.videoMetadataGenerationFailed), findsOneWidget);
        expect(
          find.byType(PartialCircleSpinner),
          findsNothing,
          reason: 'the failed overlay must not show the render spinner',
        );

        await tester.tap(find.byType(DivineIconButton));
        await tester.pump();
        expect(retried, isTrue);
      },
    );

    testWidgets('renders composed export progress', (
      tester,
    ) async {
      final clip = _createClip();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoEditorProcessingOverlay(
                clip: clip,
                isProcessing: true,
              ),
            ),
          ),
        ),
      );

      VideoEditorRenderService.emitCompositeProgressForTesting(
        taskId: 'draft-test',
        progress: 0.95,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final spinner = tester.widget<PartialCircleSpinner>(
        find.byType(PartialCircleSpinner),
      );
      expect(spinner.progress, closeTo(0.95, 1e-9));
    });
  });
}
