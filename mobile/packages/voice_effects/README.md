# Voice effects

Pure Dart offline audio processing. Voice effects (`PitchShift`, `Robotize`, `Echo`, `NoiseReduction`) operate on mono samples and preserve duration. `TimeStretch` changes duration at constant pitch and preserves interleaved channels.

## Change audio speed

```dart
import 'package:voice_effects/voice_effects.dart';

final original = decodePcmWav(wavBytes);
final faster = const TimeStretch(2).apply(original);
final outputBytes = encodePcmWav(faster);
```

`speed` is a finite positive playback multiplier: `0.5` doubles the length, `2` halves it. The output contains `ceil(inputFrames / speed)` frames at the original sample rate. Normal speed returns an exact independent copy. Processing is synchronous; callers should run long audio jobs in an isolate.

`PcmAudio.samples` stores channels interleaved (`L, R, L, R, ...` for stereo). The waveform similarity overlap-add (WSOLA) stretch chooses a shared frame alignment using all channels, including when the channels cancel in a mono mix. This preserves the stereo image. The WAV codec reads and writes 16-bit integer PCM, clamps output to full scale, and preserves sample rate and channel order.

The existing `decodeWav` / `encodeWav` API remains mono: decoding averages the input channels. Use `decodePcmWav` / `encodePcmWav` when channels must survive. To combine speed with voice effects, deinterleave the audio, apply the mono effect chain to each channel, reinterleave, and stretch the result once.

The caller owns timeline timing and edit persistence. Because speed changes the baked file's duration, source-relative trims and fade lengths must be mapped to the new file's time scale. Always render from the original source when changing the selected speed again, and use the same baked output for preview and export.
