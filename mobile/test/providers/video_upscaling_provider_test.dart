import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/video_upscaling_provider.dart';

void main() {
  group('videoUpscalingSyncProvider', () {
    late StateProvider<bool> flag;
    late ProviderContainer container;

    setUp(() {
      flag = StateProvider((ref) => false);
      container = ProviderContainer(
        overrides: [
          isFeatureEnabledProvider(FeatureFlag.videoUpscaling).overrideWith(
            (ref) => ref.watch(flag),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      // A process-wide setting; leave it as the next suite expects it.
      DivineVideoPlayerController.upscaling = VideoUpscaling.off;
    });

    test('turns Lanczos upscaling on with the flag', () {
      container.read(flag.notifier).state = true;

      container.read(videoUpscalingSyncProvider);

      expect(DivineVideoPlayerController.upscaling, VideoUpscaling.lanczos);
    });

    test('turns upscaling off again when the flag goes off', () {
      container.listen(videoUpscalingSyncProvider, (_, _) {});
      container.read(flag.notifier).state = true;
      container.read(videoUpscalingSyncProvider);
      expect(DivineVideoPlayerController.upscaling, VideoUpscaling.lanczos);

      container.read(flag.notifier).state = false;
      container.read(videoUpscalingSyncProvider);

      expect(DivineVideoPlayerController.upscaling, VideoUpscaling.off);
    });
  });
}
