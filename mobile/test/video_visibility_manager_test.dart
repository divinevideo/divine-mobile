import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_visibility_manager.dart';

void main() {
  group('VideoVisibilityManager', () {
    test('videos become playable above threshold and not below', () {
      final manager = VideoVisibilityManager();

      // Below threshold (0.5)
      manager.updateVideoVisibility('v1', 0.49);
      expect(manager.shouldVideoPlay('v1'), isFalse);

      // Above threshold
      manager.updateVideoVisibility('v1', 0.7);
      expect(manager.shouldVideoPlay('v1'), isTrue);

      // Drop below again
      manager.updateVideoVisibility('v1', 0.1);
      expect(manager.shouldVideoPlay('v1'), isFalse);
    });

    test('auto-play marks only one actively playing video', () {
      final manager = VideoVisibilityManager();

      // Make both playable
      manager.updateVideoVisibility('a', 0.9);
      manager.updateVideoVisibility('b', 0.9);
      expect(manager.playableVideos.contains('a'), isTrue);
      expect(manager.playableVideos.contains('b'), isTrue);

      // Set actively playing to a
      manager.setActivelyPlaying('a');
      expect(manager.activelyPlayingVideo, 'a');

      // Now set b as actively playing
      manager.setActivelyPlaying('b');
      expect(manager.activelyPlayingVideo, 'b');

      // Ensure previous is no longer designated
      // Note: playableVideos still includes both; activelyPlaying enforces which should auto-play
      expect(manager.shouldAutoPlay('a'), isFalse);
      expect(manager.shouldAutoPlay('b'), isTrue);
    });

    test('removing a video clears it from tracking', () {
      final manager = VideoVisibilityManager();
      manager.updateVideoVisibility('x', 0.9);
      expect(manager.visibleVideos.contains('x'), isTrue);
      expect(manager.shouldVideoPlay('x'), isTrue);

      manager.removeVideo('x');
      expect(manager.visibleVideos.contains('x'), isFalse);
      expect(manager.shouldVideoPlay('x'), isFalse);
    });
  });
}
