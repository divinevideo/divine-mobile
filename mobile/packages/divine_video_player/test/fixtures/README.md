# Native desktop media fixtures

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
```

Desktop CI explicitly runs the native smoke entrypoint on Linux with libmpv2.
Windows plays through Media Foundation instead, so the entrypoint does not
apply there. It is outside normal unit-test discovery because those jobs do
not install the native runtime. From the player package on Linux, with
Flutter 3.47.9:

```sh
DIVINE_LINUX_NO_VIDEO_OUTPUT=1 flutter test --no-pub \
  test/src/linux/linux_video_player_backend_native_smoke.dart
```

Set `DIVINE_NATIVE_LIBMPV` to a library's full path to test a specific libmpv
build instead of the one the system resolves.

The tests cover actual libmpv duration and audio-output events plus the public
thumbnail behavior under the diagnostic flag. Null video output does not
establish GPU rendering, portrait geometry or real audio-device playback.
