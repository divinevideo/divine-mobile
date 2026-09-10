// ABOUTME: Tests for VideoRecorderSegmentBar widget
// ABOUTME: Validates segment bar rendering, duration display, and clip visualization

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_segment_bar.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoRecorderSegmentBar Widget Tests', () {
    testWidgets('renders segment bar widget', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [VideoRecorderSegmentBar()])),
          ),
        ),
      );

      expect(find.byType(VideoRecorderSegmentBar), findsOneWidget);
    });

    testWidgets('initially shows empty bar with no segments', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [VideoRecorderSegmentBar()])),
          ),
        ),
      );

      // Bar should render but without segment content
      expect(find.byType(VideoRecorderSegmentBar), findsOneWidget);
      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('displays clips as colored segments', (tester) async {
      final testClips = [
        DivineVideoClip(
          id: 'clip1',
          video: EditorVideo.file('/test/clip1.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
        DivineVideoClip(
          id: 'clip2',
          video: EditorVideo.file('/test/clip2.mp4'),
          duration: const Duration(seconds: 3),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _TestClipManagerNotifier(testClips),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Stack(children: [VideoRecorderSegmentBar()])),
          ),
        ),
      );

      await tester.pump();

      // Should render segment bar with clips
      expect(find.byType(VideoRecorderSegmentBar), findsOneWidget);

      // Row contains the segments as children (inside LayoutBuilder)
      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(VideoRecorderSegmentBar),
          matching: find.byType(Row),
        ),
      );

      // Should have 2 clip segments + 1 divider + 1 remaining space = 4 children
      expect(row.children.length, equals(4));
    });
  });
}

/// Test Notifier that provides clips in build()
class _TestClipManagerNotifier extends ClipManagerNotifier {
  _TestClipManagerNotifier(this._clips);

  final List<DivineVideoClip> _clips;

  @override
  ClipManagerState build() {
    super.build(); // Call parent to setup ref.onDispose
    return ClipManagerState(clips: _clips);
  }
}
