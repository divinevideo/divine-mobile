import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/playback_loops.dart';

void main() {
  group('loopsInPlayback', () {
    test('divides playback by the length of a clip a second or longer', () {
      expect(
        loopsInPlayback(
          watched: const Duration(seconds: 15),
          clipLength: const Duration(seconds: 6),
        ),
        equals(2.5),
      );
      expect(
        loopsInPlayback(
          watched: const Duration(milliseconds: 1500),
          clipLength: minimumLoopDuration,
        ),
        equals(1.5),
      );
    });

    test('counts a clip under a second as a second long', () {
      // By clip length, 5 s of a 67 ms clip would be 74.6 loops.
      expect(
        loopsInPlayback(
          watched: const Duration(seconds: 5),
          clipLength: const Duration(milliseconds: 67),
        ),
        equals(5),
      );
    });
  });
}
