# Linux Desktop Support (Experimental)

divine-mobile can be built and run on Linux desktop for browsing and watching videos. Camera recording is **not available** on Linux.

## Status

| Feature | Status |
|---------|--------|
| Browse / discover videos | Works |
| Watch videos | Works (requires libmpv) |
| Login / auth (bunker, nsec) | Works |
| Notifications | Works (via D-Bus) |
| Video recording | Not available |
| Gallery save | Skipped on desktop |
| Firebase / Crashlytics | Gracefully disabled |

## System Dependencies

Install these before building:

```bash
# Ubuntu / Debian
sudo apt install libgtk-3-dev libsecret-1-dev libmpv-dev libepoxy-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good libwebkit2gtk-4.1-dev libasound2-dev

# Fedora
sudo dnf install gtk3-devel libsecret-devel mpv-devel libepoxy-devel gstreamer1-devel gstreamer1-plugins-base-devel gstreamer1-plugins-good webkit2gtk4.1-devel alsa-lib-devel
```

| Package | Used by |
|---------|---------|
| `libgtk-3-dev` | Flutter Linux embedding (all plugins) |
| `libsecret-1-dev` | `flutter_secure_storage_linux` (keychain) |
| `libmpv-dev` | `media_kit_video` — **video playback** engine (libmpv) |
| `libepoxy-dev` | `media_kit_video` — GL texture rendering |
| `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev` | `pro_video_editor` — video metadata & thumbnail generation (**not** playback) |
| `libwebkit2gtk-4.1-dev` | `desktop_webview_window` (embedded webview) |
| `libasound2-dev` | `volume_controller` (system volume via ALSA) |

> **Video playback vs. GStreamer:** playback runs through `media_kit` → **libmpv** (which decodes via FFmpeg, not GStreamer). GStreamer is required only by `pro_video_editor` for metadata extraction and thumbnail generation. `video_player` has no Linux implementation and plays no part on this platform.

## Building

```bash
cd mobile
flutter build linux
```

> **Note:** You must build on a Linux host. Cross-compilation from macOS is not supported.

## How Camera Degradation Works

`CameraLinuxService` is a stub that:
- Reports `isInitialized: false` and `canRecord: false`
- Reports `initializationError` as `CameraInitializationError.unsupportedPlatform`, a code rather than a message
- All recording methods are safe no-ops

`VideoRecorderCameraPreview` turns that code into localized copy and shows it in the existing `VideoRecorderCameraPlaceholder`.

## Known Limitations

- **No Firebase** — `firebase_options.dart` throws `UnsupportedError` for Linux, but `CrashReportingService.initialize()` catches it. Analytics, Crashlytics, and remote config are unavailable.
- **No camera permissions API** — `permission_handler` doesn't support Linux. `CameraPermissionBloc` skips the check on Linux and reports the permissions as granted. macOS does not: it asks through native AVFoundation (see [`CAMERA_ARCHITECTURE.md`](CAMERA_ARCHITECTURE.md#permissions)).
- **Audio session** — `audio_session` has no Linux backend. Calls are wrapped in try/catch and degrade silently.
- **Window manager** — `window_manager` supports Linux. Window sizing and positioning work normally.
