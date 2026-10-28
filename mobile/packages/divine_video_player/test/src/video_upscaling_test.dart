import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(VideoUpscaling, () {
    group('wireValue', () {
      // Kotlin's VideoUpscale.Mode.fromWire matches these strings and treats
      // anything else as off, so a renamed enum value would silently switch
      // upscaling off on Android. Pin them so a rename breaks here instead.
      test('maps off to the stable "off" wire string', () {
        expect(VideoUpscaling.off.wireValue, equals('off'));
      });

      test('maps lanczos to the stable "lanczos" wire string', () {
        expect(VideoUpscaling.lanczos.wireValue, equals('lanczos'));
      });
    });
  });
}
