// ABOUTME: Tests the sample beat the visualizer sheet previews: two seconds
// ABOUTME: of band energies with a kick on every beat.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:openvine/utils/audio_visualizer_sample_beat.dart';

void main() {
  group('audioVisualizerSampleBeat', () {
    /// The energy below about 150 Hz, where the kick and bass play, in
    /// [row].
    double bass(int row) {
      var sum = 0.0;
      for (var band = 0; band <= 10; band++) {
        sum += audioVisualizerSampleBeat[row * audioBandCount + band];
      }
      return sum;
    }

    test('lasts two seconds and kicks on each of its four beats', () {
      expect(
        audioVisualizerSampleBeat,
        hasLength(2 * audioBandFrameRate * audioBandCount),
      );
      // A beat is 30 rows. Just after each one the kick is far louder than
      // halfway to the next.
      for (var beat = 0; beat < 4; beat++) {
        expect(bass(beat * 30 + 3), greaterThan(3 * bass(beat * 30 + 18)));
      }
    });
  });
}
