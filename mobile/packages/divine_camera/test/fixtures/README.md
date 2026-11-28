# Synthetic capture-inspection fixtures

These one-second 128×240 files contain a synthetic green picture. The audio
variant adds a generated 330 Hz tone. They contain no user media and are not
production app assets.

Generated with FFmpeg:

```sh
ffmpeg -f lavfi -i 'color=c=green:s=128x240:r=12:d=1' -an \
  -c:v libx264 -threads 1 -preset veryslow -crf 30 \
  -map_metadata -1 -movflags +faststart desktop_silent_portrait.mp4
ffmpeg -f lavfi -i 'color=c=green:s=128x240:r=12:d=1' \
  -f lavfi -i 'sine=frequency=330:sample_rate=48000:duration=1' \
  -c:v libx264 -threads 1 -preset veryslow -crf 30 -c:a aac -b:a 32k \
  -map_metadata -1 -movflags +faststart desktop_audio_portrait.mp4
ffmpeg -f lavfi -i 'color=c=green:s=128x240' -frames:v 1 \
  -map_metadata -1 -threads 1 desktop_still_portrait.jpg
```

These are decoder characterization inputs, not output from a physical webcam.
The explicit native entrypoint is outside normal unit-test discovery because
platform-neutral Dart jobs do not install the native runtime; it runs in
`Divine Camera CI` (`Linux Capture Ownership`) with `libmpv2` installed, and
can also be run locally on Linux with `libmpv2` and Flutter 3.47.9:

```sh
flutter test --no-pub \
  test/src/desktop/desktop_video_file_inspector_native_smoke.dart
```

Windows additionally sets `DIVINE_NATIVE_LIBMPV` to the bundled DLL's full path
and places the bundle directory on `PATH` for its native dependencies.

The tests verify demuxed duration, encoded dimensions and presence or absence
of an audio track. A demuxer may include one 1024-sample AAC priming packet in
the audio variant's duration. These tests do not establish webcam/microphone
capture, GPU rendering or audio-device playback.
