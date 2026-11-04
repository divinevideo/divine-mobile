# caption_generator

On-device speech-to-text closed caption (CC) generation for Android, iOS, and
macOS. Feed it an audio file — typically the WAV that `pro_video_editor`
audio extraction produces — and it returns a list of timed text segments.

This is a **last-resort, best-effort** path: on-device recognizers are far
from perfect, so surface the result as an editable suggestion, never as
authoritative captions.

## Usage

```dart
import 'package:caption_generator/caption_generator.dart';

final generator = CaptionGenerator();

// Word-level segments with start/end timestamps.
final words = await generator.generateCaptions(
  audioPath: extractedAudio.audioFilePath,
  localeIdentifier: 'en-US', // defaults to the device locale
);

// Merge words into display-ready caption cues. Cues break at sentence-final
// punctuation, silence gaps, and length/duration limits.
final cues = groupCaptionSegments(words);
for (final cue in cues) {
  print('${cue.start} -> ${cue.end}: ${cue.text}');
}
```

`groupCaptionSegments` splits on sentence-final punctuation by default
(`splitAtSentenceEnd`). Recognizer word timings tend to smear speech pauses
away, so punctuation is the more reliable break signal — on both platforms
the transcript is punctuated (iOS/macOS via `addsPunctuation`, Android via
`EXTRA_ENABLE_FORMATTING`). Unpunctuated input is unaffected and still breaks
on silence and the length/duration limits.

Failures throw typed `CaptionGenerationException` subclasses
(`SpeechNotAuthorizedException`, `SpeechRecognizerUnavailableException`,
`UnsupportedAudioFormatException`, ...) so callers can branch per failure
mode. An empty list means the recognizer found no speech.

## Platform backends

| Platform | Engine | Notes |
|---|---|---|
| iOS / macOS | `SFSpeechRecognizer` | On-device when the locale supports it and `preferOnDeviceRecognition` is true; otherwise Apple's server-based recognition (limited to ~1 minute of audio). |
| Android 14+ | Platform `SpeechRecognizer` | `createOnDeviceSpeechRecognizer` + `EXTRA_AUDIO_SOURCE` file input + `RecognitionPart` word timing. Fully on-device; language packs are managed by the OS. |

Set `requireOnDeviceRecognition: true` when recognition must stay local. On
Apple platforms this fails with `SpeechRecognizerUnavailableException` when the
locale has no on-device recognizer, without falling back to server recognition.
Android always uses its on-device recognizer.

On Android, `RecognitionPart` only reports each word's **start** offset, so a
word's end time is approximated by the next word's start; the final word gets a
bounded cadence-based fallback. Devices below Android 14, devices without
Google's on-device recognition service (e.g. de-Googled ROMs), and locales
without a downloaded language pack throw `SpeechRecognizerUnavailableException`
— treat that as "CC suggestion not available on this device".

### Input format

* **Apple platforms**: any audio container the OS can read (WAV, M4A, ...).
* **Android**: a RIFF/WAVE file containing 16-bit integer or 32-bit float
  PCM. The package converts it to the 16 kHz mono PCM the recognizer
  expects; other containers throw `UnsupportedAudioFormatException`.

### iOS / macOS setup

Add the usage description to the app's `Info.plist` (already done for the
Divine Runners):

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>...</string>
```

The first call prompts the user for speech recognition permission.

### Android setup

No model download required. The plugin manifest declares the
`android.speech.RecognitionService` package-visibility query it needs.

The consuming app must request and hold `android.permission.RECORD_AUDIO`;
Android's platform recognizer requires that grant even when transcribing file
input. Missing permission is reported as `SpeechNotAuthorizedException`.
