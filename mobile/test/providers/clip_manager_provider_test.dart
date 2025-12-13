// ABOUTME: Tests for ClipManagerProvider - Riverpod state management
// ABOUTME: Validates state updates and provider lifecycle

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

void main() {
  group('ClipManagerProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no clips', () {
      final state = container.read(clipManagerProvider);

      expect(state.clips, isEmpty);
      expect(state.hasClips, isFalse);
    });

    test('addClip updates state with new clip', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
      expect(state.totalDuration, equals(const Duration(seconds: 2)));
    });

    test('deleteClip removes clip from state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video1.mp4',
        duration: const Duration(seconds: 2),
      );
      notifier.addClip(
        filePath: '/path/to/video2.mp4',
        duration: const Duration(seconds: 1),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.deleteClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.clips.length, equals(1));
    });

    test('setPreviewingClip updates preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );

      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, equals(clipId));
    });

    test('clearPreview removes preview state', () {
      final notifier = container.read(clipManagerProvider.notifier);

      notifier.addClip(
        filePath: '/path/to/video.mp4',
        duration: const Duration(seconds: 2),
      );
      final clipId = container.read(clipManagerProvider).clips[0].id;
      notifier.setPreviewingClip(clipId);
      notifier.clearPreview();

      final state = container.read(clipManagerProvider);
      expect(state.previewingClipId, isNull);
    });
  });
}
