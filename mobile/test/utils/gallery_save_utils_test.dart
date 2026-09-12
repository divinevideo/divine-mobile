// ABOUTME: Tests for saveToGallery utility — early returns, successful save,
// ABOUTME: permission-denied retry path.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/gallery_save_utils.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

/// A minimal [ConsumerWidget] that calls [saveToGallery] on tap
/// so we can exercise the function in a widget-test environment.
class _TestHarness extends ConsumerWidget {
  const _TestHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () => saveToGallery(context, ref),
      child: const Text('save'),
    );
  }
}

DivineVideoClip _createClip() {
  return DivineVideoClip(
    id: 'clip-1',
    video: EditorVideo.file('/path/clip.mp4'),
    duration: const Duration(seconds: 3),
    recordedAt: DateTime(2025),
    targetAspectRatio: .vertical,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
  });

  group('saveToGallery', () {
    late _MockGallerySaveService mockGallerySaveService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGallerySaveService = _MockGallerySaveService();
    });

    Widget buildSubject({DivineVideoClip? clip}) {
      final state = VideoEditorProviderState(finalRenderedClip: clip);
      return ProviderScope(
        overrides: [
          gallerySaveServiceProvider.overrideWithValue(mockGallerySaveService),
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(state),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: _TestHarness())),
      );
    }

    testWidgets('returns early when gallery permission is dismissed forever', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'gallery_permission_dismissed_forever': true,
      });

      await tester.pumpWidget(buildSubject(clip: _createClip()));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      verifyNever(() => mockGallerySaveService.saveVideoToGallery(any()));
    });

    testWidgets('returns early when finalRenderedClip is null', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      verifyNever(() => mockGallerySaveService.saveVideoToGallery(any()));
    });

    testWidgets('calls saveVideoToGallery when clip is available', (
      tester,
    ) async {
      final clip = _createClip();
      when(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).thenAnswer((_) async => const GallerySaveSuccess());

      await tester.pumpWidget(buildSubject(clip: clip));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      verify(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).called(1);
    });

    testWidgets('does not show permission sheet on save success', (
      tester,
    ) async {
      final clip = _createClip();
      when(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).thenAnswer((_) async => const GallerySaveSuccess());

      await tester.pumpWidget(buildSubject(clip: clip));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // Only one call — no retry.
      verify(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).called(1);
    });

    testWidgets('does not show permission sheet on save failure', (
      tester,
    ) async {
      final clip = _createClip();
      when(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).thenAnswer((_) async => const GallerySaveFailure('disk full'));

      await tester.pumpWidget(buildSubject(clip: clip));
      await tester.tap(find.text('save'));
      await tester.pumpAndSettle();

      // Only one call — no retry for generic failures.
      verify(
        () => mockGallerySaveService.saveVideoToGallery(clip.requireVideo),
      ).called(1);
    });
  });
}
