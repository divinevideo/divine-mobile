# divine_video_player

Seamless multi-clip video player using native platform APIs.

## Features

- Seamless playback across multiple video clips with no delay
- Continuous timeline with global position tracking
- Native implementations: Media3/ExoPlayer (Android), AVFoundation (iOS/macOS) and Media Foundation (Windows); Dart backends on media_kit/mpv (Linux) and an `HTMLVideoElement` (web). Windows, Linux and web have fewer features (see the backend notes below)
- Buffering handled natively, plus a best-effort `preload` of upcoming clips (see below)
- Looping, clip jumping, and playback speed control
- Multi-track audio overlays synced to the video timeline, each at its own playback speed with unchanged pitch (`AudioTrack.playbackSpeed`; Android, iOS and macOS)
- An equalizer per clip and per overlay track (`AudioEqualizer`): shelf and peak bands, the same filters `pro_video_editor` exports with
- Optional texture rendering for Flutter widget compositing (e.g. `ColorFiltered`)
- Placeholder widget support to hide black frames before first frame renders
- Native video caching (Android)
- App lifecycle handling (auto-pause on background, resume on foreground; Android, iOS and macOS)

## Usage

```dart
import 'package:divine_video_player/divine_video_player.dart';

// Create controller
final controller = DivineVideoPlayerController();
await controller.initialize();

// Single video
await controller.setSource(
  VideoClip(uri: '/path/to/video.mp4'),
);

// Network URL
await controller.setSource(
  VideoClip(uri: 'https://example.com/video.mp4'),
);

// Flutter asset (copies to temp file)
await controller.setSource(
  await VideoClip.asset('assets/intro.mp4'),
);

// In-memory bytes (writes to temp file)
await controller.setSource(
  await VideoClip.memory(bytes, fileName: 'clip.mp4'),
);

// Or multiple clips as a continuous timeline
await controller.setClips([
  VideoClip(
    uri: '/path/to/video1.mp4',
    start: Duration.zero,
    end: const Duration(seconds: 5),
  ),
  VideoClip(
    uri: '/path/to/video2.mp4',
    start: const Duration(seconds: 2),
    end: const Duration(seconds: 8),
  ),
]);

// Playback
await controller.play();
await controller.pause();
await controller.stop();         // clears surface, resets position
await controller.seekTo(const Duration(seconds: 10));
await controller.jumpToClip(1);  // jump to clip at index
await controller.setPlaybackSpeed(1.5);
await controller.setLooping(looping: true);

// Audio overlays (e.g. background music, synced to video timeline)
await controller.setAudioTracks([
  AudioTrack(
    uri: 'https://cdn.com/music.mp3',
    videoStartTime: const Duration(seconds: 5),
    videoEndTime: const Duration(seconds: 35),
    trackStart: const Duration(seconds: 10),
    trackEnd: const Duration(seconds: 40),
    volume: 0.8,
  ),
]);

// Independent volume control
await controller.setVolume(0.5);              // video audio
await controller.setAudioTrackVolume(0, 0.8); // overlay track at index

// Equalizer bands, applied in order and changeable while playing (Android,
// iOS, macOS and Windows; on Windows a clip's equalizer needs a player
// created with VideoBufferProfile.full and the manifest entry in the Windows
// backend notes). On Android a clip's equalizer needs a player created with
// VideoBufferProfile.full, except for a single looping clip whose audio plays
// from a decoded loop, which applies it on any profile; an overlay track's
// needs no particular profile. On iOS and macOS an
// overlay track plays an equalized copy of the stretch of its file it plays
// (at most 300 s when neither its video end nor its track end bounds it),
// rendered once a change has rested for 500 ms; a remote track is downloaded
// for it first. responseDb gives what the bands add up to.
const warmer = AudioEqualizer(
  bands: [
    AudioEqualizerBand(
      type: AudioEqualizerBandType.lowShelf,
      frequency: 200,
      gain: 4,
    ),
    AudioEqualizerBand(
      type: AudioEqualizerBandType.peak,
      frequency: 2500,
      gain: -3,
      q: 1.4,
    ),
    AudioEqualizerBand(
      type: AudioEqualizerBandType.highShelf,
      frequency: 8000,
      gain: -2,
    ),
  ],
);
await controller.setClipEqualizers([
  warmer, // first clip
  null, // second clip unchanged
]);
await controller.setAudioTrackEqualizer(0, warmer);

// Remove all overlay audio
await controller.removeAllAudioTracks();

// Render with a placeholder while the first frame loads
DivineVideoPlayer(
  controller: controller,
  placeholder: const Center(child: CircularProgressIndicator()),
);

// Listen to state changes
controller.stateStream.listen((state) {
  print('Position: ${state.position}');
  print('Status: ${state.status}');
  print('Clip: ${state.currentClipIndex}/${state.clipCount}');
});

// Wait for first frame
await controller.firstFrameRendered;

// Dispose when done
await controller.dispose();
```

### Preloading & caching

Configure the Android disk cache and warm upcoming videos before they play:

```dart
// Configure the Android player's disk cache (call once at app startup)
await DivineVideoPlayerController.configureCache(
  maxSizeBytes: 500 * 1024 * 1024, // 500 MB
);

// Preload without a controller (Android, iOS and macOS)
await DivineVideoPlayerController.preload([
  VideoClip(uri: 'https://example.com/next-video.mp4'),
]);
```

`preload` needs a native backend: on Android it prepares the clips in a
temporary ExoPlayer and releases it as soon as that player is first ready,
idle or failed, and on iOS and macOS it only makes a best-effort metadata
request. It does not send a clip's `httpHeaders`, so it cannot warm an
authenticated source. On Windows it fetches the first MiB of each HTTP(S) MP4
that has no app headers into memory, where a player opening the same URL
starts from it, and answers once those requests end. Linux and web register no
platform channel, and `preload` does not check for them, so a call there throws
a `MissingPluginException`.

The disk cache exists on Android only. ExoPlayer streams HTTP(S) sources
through a write-through `SimpleCache` at `<cacheDir>/divine_video_cache`
(`kNativeVideoCacheDirectoryName`), so a URL it has already streamed is
served from disk the next time. Three kinds of source deliberately bypass it:

- Local sources — `VideoClip.file`, or any URI that is not `http`/`https`.
  The bytes are already on the device; caching them would only store a
  second copy. An app that hands the player files from its own download
  cache therefore pays for one copy, not two.
- Any source with `httpHeaders`. Headers are what viewer-authenticated
  sources carry, and their bytes must not be persisted, so the player decides
  this on the client rather than relying on how the origin marks the
  response.
- The B2 playback hosts (`media-b2.divine.video` and
  `media-b2-cdn.divine.video`), so every new open
  checks the endpoint's policy instead of replaying an earlier approved copy.

On iOS and macOS there is no disk cache to configure: AVFoundation loads
media through its own stack and does not consult `URLCache`, so
`configureCache` is a no-op there. Two things do keep bytes on disk for a
while. A single remote clip that starts at its beginning, at full volume and
normal speed, with `trimToCommonTrackEnd` set and no `.m3u8` extension, loads
through the plugin's own `CachingAssetLoader`, which sends the clip's
`httpHeaders` itself. When the file is at most 16 MB it downloads it once
into a temporary `divine-loop-*.mp4`, so the looping audio can be decoded
without fetching the clip a second time; a larger file, or one with no
length, is fetched range by range instead. Because the loader sends the
headers itself, this includes a viewer-authenticated clip. The file is
deleted when the player moves to other clips, stops or is disposed; nothing
removes one left behind by an app that was killed. And an equalized overlay
track plays from `divine_eq_*` files in the temporary directory: a download
of a remote track (up to 50 MB) and the rendered copy. Those left by an
earlier run are deleted when the next run creates its first player.

### Controller options

```dart
DivineVideoPlayerController(
  useTexture: false,        // see Texture rendering below
  useLegacySurface: false,  // Android only; see the dartdoc before opting in
  bufferProfile: VideoBufferProfile.full, // .feed caps the buffer per player
  exclusivePlayback: true,  // only one such video plays at a time
  debugLabel: 'feed',       // names the player in diagnostic logs
);
```

- `bufferProfile`: `VideoBufferProfile.feed` bounds how much each player
  buffers into memory, for surfaces with many players such as the feed;
  `full` keeps the platform defaults, and is what a clip's equalizer and the
  decoder-error retry need. Only Android acts on it.
- `exclusivePlayback`: starting one exclusive player pauses the others.
  Pass `false` only for a companion player that is part of another
  player's picture, such as a chroma-key backdrop.
- `setClips(clips, startPosition: ...)` starts at a point on the combined
  timeline without a separate seek. `setClipVolumes` changes each clip's
  volume cheaply enough to follow a slider (Android, iOS, macOS and Windows),
  and `setFrameEffects` draws effects the app registered natively over a
  window of the timeline (Android, iOS and macOS).
- On Android, iOS, macOS and Windows, errors arrive in
  `DivineVideoPlayerState.errorCode` as a `NativePlayerErrorCode`, with
  `shouldFailover` and `isTransient` to decide whether to try another
  source or retry. The Linux and web backends leave `errorCode` unset.

### Texture rendering

By default the player renders via a native platform view. When you need
Flutter widgets like `ColorFiltered` to affect the video pixels — for
example in a video editor — enable texture mode:

```dart
final controller = DivineVideoPlayerController(useTexture: true);
await controller.initialize();
```

The widget automatically uses a `Texture` widget when `useTexture` is
enabled and falls back to the platform view otherwise. Windows has no
platform views, so its players always render into a texture.

## Platform Requirements

- Android: API 28+
- iOS: 16.0+
- macOS: 13.0+
- Windows: 10 version 1903 or later. Plays through Windows' own Media
  Foundation, so nothing is bundled.
- Linux: plays through `media_kit` against the system `libmpv`;
  `media_kit_libs_linux` enables that backend but does not bundle `libmpv`.
  Install `libmpv-dev` and `libepoxy-dev` before building (see
  `mobile/docs/LINUX_SUPPORT.md`).
- Web: an `HTMLVideoElement` shown through `HtmlElementView`; see the web
  notes below.

## Windows Backend Notes

Windows plays through the plugin's native code in `windows/`, which speaks the
same platform channels as Android and Apple platforms. It drives Windows'
`MediaPlayer` (Media Foundation) in frame-server mode and copies each frame
into shared D3D11 textures that Flutter samples directly, so decoding and
rendering stay on the GPU.

The Windows backend supports:

- HLS and MP4, from local files and http(s) URLs. A video whose header asks
  for a rotation plays upright: Media Foundation rotates the frames it hands
  over, so `rotationDegrees` stays 0 and the reported size is the upright one
- A clip's `httpHeaders` on every request, HLS playlists and segments
  included: HLS goes through `AdaptiveMediaSource`, and an MP4 through Range
  requests of 1 MiB, each chunk fetched once and the next one ahead of the
  decoder. Chunks of files without app headers are shared by every player in
  a 64 MiB in-memory cache, which `preload` fills with a file's first MiB
- Multi-clip timelines using a `MediaPlaybackList` with per-clip `start` and
  `end`, each clip at its own speed times the player's speed, and
  `trimToCommonTrackEnd` read from the file's `moov` before the first frame
- Play, pause, stop, seek, jump to clip, loop, volume, speed, per-clip volume,
  and disposal; playing players pause while the window is minimized and resume
  when it is restored, as Android does in the background
- Equalizers and volumes above 1.0, for clips and overlay tracks, through the
  plugin's own audio effect with the same filters and -1 dBFS limiter as
  Android (see below)
- Overlay audio tracks with their timeline window, fades, volume curve and
  speed, kept in step with the video as on Android (moved back when they drift
  more than 250 ms)
- Playback telemetry: a clip's `X-Playback-Load-Id` correlates its requests,
  each reported as `playback_network` events like Android's, until
  `clearPlaybackTelemetryContext` revokes it
- `errorCode` mapped from the HTTP status or Windows error as on Android, and
  native diagnostics forwarded to the app's logger

It does not support frame effects (`setFrameEffects` does nothing), and
`bufferedPositionMs` of an MP4 read through Range requests reports the whole
clip as buffered. There is no disk cache; `configureCache` is Android's.

### The audio effect needs a manifest entry

Windows creates the equalizer and volume-boost effect by name inside each
player's audio pipeline, which an unpackaged app allows only for classes its
manifest registers. Add this to the app's `windows/runner/runner.exe.manifest`,
inside `<assembly>`:

```xml
<file name="divine_video_player_plugin.dll">
  <activatableClass
      name="DivineVideoPlayer.AudioShapingEffect"
      threadingModel="both"
      xmlns="urn:schemas-microsoft-com:winrt.v1"/>
</file>
```

Without it, playback is unchanged except that equalizers are not applied and
volumes above 1.0 play at 1.0; the plugin logs this once.

## Linux Backend Notes

Linux uses a Dart backend built on `media_kit` rather than the package's
platform-channel plugin path, against the system or application package's
libmpv.

Linux uses mpv's `auto-safe` decoder selection with software texture output.
This retains allowlisted hardware decoding while avoiding unrestricted codec
probing, which can report a failed decoder attempt after a successful software
fallback and leave paused preview readiness in error.

The Linux backend supports:

- HLS and MP4 playback
- Multi-clip timelines using `media_kit` playlists with per-clip `start` and `end`
- Play, pause, seek, loop, buffer, volume, speed, and disposal

The Linux backend does not yet support overlay audio tracks via
`setAudioTracks`. Callers that need mixed timeline audio should continue to
use the native backends.

It also ignores a clip's `httpHeaders`, `volume`, `equalizer` and
`trimToCommonTrackEnd`: the playlist carries only each clip's URI, `start`
and `end`, so a source that needs request headers cannot play on this backend.
`setClipVolumes`, `setClipEqualizers`, `setAudioTrackEqualizer` and
`setFrameEffects` do nothing there, and the backend does not pause when the
app goes to the background.

### Native desktop playback verification

With Flutter 3.47.9 and the platform's native build dependencies installed,
run on Linux:

```sh
python3 tool/native_playback_harness_test.py
python3 tool/native_playback_harness.py --platform linux
```

and on Windows:

```sh
python tool/native_playback_harness.py --platform windows
```

The harness builds a separate Release consumer with the application's locked
dependencies and launches it (under Xvfb on Linux). It checks actual Flutter
pixels for a
green local clip, a paused red HTTP replacement at position zero, and blue after
explicit playback advances. A synthetic invalid source must still report an
error and must never report a rendered frame. The HTTP server is loopback-only;
the probe uses no account or remote media. Desktop CI runs the same checks.

The four-second changing fixture is synthetic H.264, generated with:

```sh
ffmpeg -f lavfi -i color=c=red:s=128x240:r=12:d=2 \
  -f lavfi -i color=c=blue:s=128x240:r=12:d=2 \
  -filter_complex '[0:v][1:v]concat=n=2:v=1:a=0[v]' -map '[v]' \
  -c:v libx264 -pix_fmt yuv420p -movflags +faststart -map_metadata -1 \
  test/fixtures/desktop_changing_portrait.mp4
```

## Web Backend Notes

Web uses a Dart backend on an `HTMLVideoElement`. It plays one clip: when
the controller passes more than one, only the first is played, and overlay
audio calls do nothing. Like Linux, it ignores a clip's `httpHeaders`,
`equalizer` and `trimToCommonTrackEnd`, so a source that needs request
headers cannot play on web. It also skips `setClipVolumes`,
`setClipEqualizers`, `setAudioTrackEqualizer` and `setFrameEffects`, and has
no disk cache, no `preload` and no lifecycle pause.
