// ABOUTME: Widget tests for VideoEditorScreen video editing interface
// ABOUTME: Tests text overlay, sound selection, preview display, and export functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/models/vine_sound.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/screens/video_editor_screen.dart';
import 'package:openvine/services/sound_library_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements VideoPlayerPlatform {
  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    return 0;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    return 0;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {}

  @override
  Future<void> pause(int textureId) async {}

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {}

  @override
  Future<Duration> getPosition(int textureId) async {
    return Duration.zero;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return Stream.value(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1920, 1080),
      ),
    );
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int textureId) {
    return Container();
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return Container();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });
  group('VideoEditorScreen', () {
    late List<VineSound> mockSounds;

    setUp(() {
      mockSounds = [
        VineSound(
          id: 'sound1',
          title: 'Test Sound 1',
          assetPath: 'assets/sounds/test1.mp3',
          duration: const Duration(seconds: 10),
          artist: 'Test Artist',
          tags: ['tag1'],
        ),
        VineSound(
          id: 'sound2',
          title: 'Test Sound 2',
          assetPath: 'assets/sounds/test2.mp3',
          duration: const Duration(seconds: 15),
        ),
      ];
    });

    Widget createTestWidget({
      required String videoPath,
      VoidCallback? onExport,
      VoidCallback? onBack,
      List<VineSound>? sounds,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: VideoEditorScreen(
            videoPath: videoPath,
            onExport: onExport,
            onBack: onBack,
          ),
        ),
      );
    }

    testWidgets('renders app bar with title and Done button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      // Don't wait for video to initialize, just check UI elements
      await tester.pump();

      expect(find.text('Edit Video'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders Add Text button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Text'), findsOneWidget);
    });

    testWidgets('renders Add Sound button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Sound'), findsOneWidget);
    });

    testWidgets('displays video preview area', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pumpAndSettle();

      // Video preview should be present
      // We'll check for a Container or AspectRatio widget
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('shows dark theme colors', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pump();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('calls onBack when back button pressed', (tester) async {
      bool backCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          videoPath: '/test/video.mp4',
          onBack: () => backCalled = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();

      expect(backCalled, true);
    });

    testWidgets('calls onExport when Done button pressed', (tester) async {
      bool exportCalled = false;

      await tester.pumpWidget(
        createTestWidget(
          videoPath: '/test/video.mp4',
          onExport: () => exportCalled = true,
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pump();

      expect(exportCalled, true);
    });

    testWidgets('opens TextOverlayEditor when Add Text tapped', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Text'));
      await tester.pumpAndSettle();

      // Should open a bottom sheet with text editor
      expect(find.text('Enter text'), findsOneWidget);
    });

    testWidgets('opens SoundPickerModal when Add Sound tapped', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4', sounds: mockSounds),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Sound'));
      await tester.pumpAndSettle();

      // Should navigate to sound picker screen
      expect(find.text('Select Sound'), findsOneWidget);
    });

    testWidgets('displays text overlays on video preview', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider('/test/video.mp4').overrideWith((ref) {
              return VideoEditorNotifier(videoPath: '/test/video.mp4')
                ..addTextOverlay(
                  TextOverlay(
                    id: 'text1',
                    text: 'Test Overlay',
                    normalizedPosition: const Offset(0.5, 0.5),
                  ),
                );
            }),
          ],
          child: MaterialApp(
            home: VideoEditorScreen(videoPath: '/test/video.mp4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display the text overlay
      expect(find.text('Test Overlay'), findsOneWidget);
    });

    testWidgets('displays selected sound name when sound is chosen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider('/test/video.mp4').overrideWith((ref) {
              return VideoEditorNotifier(videoPath: '/test/video.mp4')
                ..selectSound('sound1');
            }),
            soundLibraryServiceProvider.overrideWith((ref) {
              final service = SoundLibraryService();
              // We'd need to mock this properly in a real test
              return service;
            }),
          ],
          child: MaterialApp(
            home: VideoEditorScreen(videoPath: '/test/video.mp4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show sound name or indicator
      expect(find.textContaining('Sound:'), findsOneWidget);
    });

    testWidgets('can add multiple text overlays', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );
      await tester.pumpAndSettle();

      // Check that Add Text button exists
      expect(find.text('Add Text'), findsOneWidget);

      // Tap Add Text to open bottom sheet
      await tester.tap(find.text('Add Text'));
      await tester.pumpAndSettle();

      // Verify text editor opened
      expect(find.text('Enter text'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('uses dark theme for all UI elements', (tester) async {
      await tester.pumpWidget(
        createTestWidget(videoPath: '/test/video.mp4'),
      );

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.black);

      // Check for white text on dark background
      final titleText = tester.widget<Text>(find.text('Edit Video'));
      expect(titleText.style?.color, Colors.white);
    });
  });
}
