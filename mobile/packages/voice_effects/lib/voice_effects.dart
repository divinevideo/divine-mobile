/// Offline voice processing for recorded voice-over takes: pitch shift,
/// robot, echo and noise reduction on mono PCM, plus the 16-bit WAV codec the
/// takes travel in.
library;

export 'src/audio_effect.dart';
export 'src/echo.dart';
export 'src/noise_reduction.dart';
export 'src/pitch_shift.dart';
export 'src/robotize.dart';
export 'src/wav_codec.dart';
