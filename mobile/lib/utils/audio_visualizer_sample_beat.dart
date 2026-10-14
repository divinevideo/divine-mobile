// ABOUTME: A short drum loop, synthesized and measured into band energies,
// ABOUTME: that the visualizer sheet previews when the video's sound is not there.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:openvine/utils/audio_band_energies.dart';

/// The band energies of a two-second drum loop at 120 beats a minute: a kick
/// on every beat, a snare on the second and fourth, hi-hats in between, and a
/// bass and an arpeggio over it. Laid out like [bandEnergies].
///
/// Built once, on first use, in a few milliseconds.
final Float32List audioVisualizerSampleBeat = bandEnergies(
  _sampleBeatSamples(),
  sampleRate: _sampleRate,
);

const int _sampleRate = 44100;

/// Seconds a beat lasts at 120 beats a minute.
const double _beat = 0.5;

/// The notes of the arpeggio, one per half beat, in hertz: A minor.
const List<double> _arpeggio = [440, 523.25, 659.25, 880];

Float32List _sampleBeatSamples() {
  final samples = Float32List((_sampleRate * _beat * 4).round());
  // A fixed seed keeps the loop the same every time.
  final random = math.Random(9851);
  var previousNoise = 0.0;
  var kickPhase = 0.0;
  for (var i = 0; i < samples.length; i++) {
    final time = i / _sampleRate;
    final sinceBeat = time % _beat;
    final sinceHalfBeat = time % (_beat / 2);
    final beat = (time / _beat).floor();
    final noise = random.nextDouble() * 2 - 1;
    // The difference of two noise samples keeps the highs: a hi-hat.
    final hiss = noise - previousNoise;
    previousNoise = noise;

    // A kick falls from 120 Hz to 45 Hz as it fades.
    final kickFrequency = 45 + 75 * math.exp(-sinceBeat / 0.03);
    kickPhase += 2 * math.pi * kickFrequency / _sampleRate;
    final kick = math.sin(kickPhase) * math.exp(-sinceBeat / 0.12);

    final snare = beat.isOdd
        ? (noise * 0.5 + math.sin(2 * math.pi * 190 * sinceBeat) * 0.3) *
              math.exp(-sinceBeat / 0.08)
        : 0.0;
    final hat = sinceBeat >= _beat / 2
        ? hiss * 0.15 * math.exp(-sinceHalfBeat / 0.03)
        : 0.0;
    final bass = math.sin(2 * math.pi * 55 * time) * 0.15;
    final note = _arpeggio[(time / (_beat / 2)).floor() % _arpeggio.length];
    final arpeggio =
        math.sin(2 * math.pi * note * time) *
        0.12 *
        math.exp(-sinceHalfBeat / 0.15);

    samples[i] = (kick * 0.8 + snare + hat + bass + arpeggio) * 0.5;
  }
  return samples;
}
