# divine_video_player

Seamless multi-clip video player using native platform APIs.

## Features

- Seamless playback across multiple video clips with no delay
- Continuous timeline with global position tracking
- Native implementations: Media3/ExoPlayer (Android), AVFoundation (iOS/macOS), media_kit/mpv (Linux)
- Preloading and buffering handled natively
- Looping, clip jumping, and playback speed control
- Multi-track audio overlays synced to the video timeline
- Optional texture rendering for Flutter widget compositing (e.g. `ColorFiltered`)
- Placeholder widget support to hide black frames before first frame renders
- Native video caching
- App lifecycle handling (auto-pause on background, resume on foreground)

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

// Remove all overlay audio
await controller.removeAllAudioTracks();

// Render with a placeholder while the first frame loads
DivineVideoPlayerWidget(
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

Pre-buffer upcoming videos so playback starts instantly:

```dart
// Configure the Android player's disk cache (call once at app startup)
await DivineVideoPlayerController.configureCache(
  maxSizeBytes: 500 * 1024 * 1024, // 500 MB
);

// Preload without creating a player
await DivineVideoPlayerController.preload([
  VideoClip(uri: 'https://example.com/next-video.mp4'),
]);
```

The disk cache exists on Android only. ExoPlayer streams HTTP(S) sources
through a write-through `SimpleCache` at `<cacheDir>/divine_video_cache`
(`kNativeVideoCacheDirectoryName`), so a URL it has already streamed is
served from disk the next time. Two kinds of source deliberately bypass it:

- Local sources — `VideoClip.file`, or any URI that is not `http`/`https`.
  The bytes are already on the device; caching them would only store a
  second copy. An app that hands the player files from its own download
  cache therefore pays for one copy, not two.
- Viewer-authenticated sources, which the origin serves `no-store`; those
  bytes are never persisted.

On iOS and macOS there is no cache to configure: AVFoundation loads media
through its own stack and does not consult `URLCache`, so `configureCache`
is a no-op there and `preload` only makes a best-effort metadata request.

### Texture rendering

By default the player renders via a native platform view. When you need
Flutter widgets like `ColorFiltered` to affect the video pixels — for
example in a video editor — enable texture mode:

```dart
final controller = DivineVideoPlayerController(useTexture: true);
await controller.initialize();
```

The widget automatically uses a `Texture` widget when `useTexture` is
enabled and falls back to the platform view otherwise.

## Platform Requirements

- Android: API 28+
- iOS: 16.0+
- macOS: 13.0+
- Linux: `libmpv` is bundled through `media_kit_libs_video`; install the
  system packages `libfontconfig1` and `libass9` if your distro does not
  already provide them.

## Linux Backend Notes

Linux uses a Dart backend built on `media_kit` rather than the package's
platform-channel plugin path. That keeps the public `DivineVideoPlayer`
API consistent without introducing a separate C++ Linux plugin to maintain.

The Linux backend supports:

- HLS and MP4 playback
- Multi-clip timelines using `media_kit` playlists with per-clip `start` and `end`
- Play, pause, seek, loop, buffer, volume, speed, and disposal

The Linux backend does not yet support overlay audio tracks via
`setAudioTracks`. Callers that need mixed timeline audio should continue to
use the existing mobile/macOS native backends.
