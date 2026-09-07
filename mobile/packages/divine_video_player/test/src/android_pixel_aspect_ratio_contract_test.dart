import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android pixel aspect ratio contract', () {
    test('captures and emits Media3 pixel aspect ratio with dimensions', () {
      final source = _androidSourceFile().readAsStringSync();
      final callback = source.indexOf('override fun onVideoSizeChanged');
      final validDimensions = source.indexOf(
        'if (videoSize.width > 0 && videoSize.height > 0)',
        callback,
      );
      final capture = source.indexOf(
        'pixelWidthHeightRatio = videoSize.pixelWidthHeightRatio.toDouble()',
        validDimensions,
      );
      final stateEmission = source.indexOf(
        '"pixelWidthHeightRatio" to pixelWidthHeightRatio',
      );

      expect(callback, greaterThanOrEqualTo(0));
      expect(validDimensions, greaterThan(callback));
      expect(capture, greaterThan(validDimensions));
      expect(stateEmission, greaterThanOrEqualTo(0));
    });
  });
}

File _androidSourceFile() {
  final packageRelative = File(
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
  if (packageRelative.existsSync()) return packageRelative;

  return File(
    'packages/divine_video_player/'
    'android/src/main/kotlin/com/divinevideo/divine_video_player/'
    'DivineVideoPlayerInstance.kt',
  );
}
