# Desktop native editor implementation detail

This executes Task 3 of the [approved desktop delivery design](https://github.com/divinevideo/divine-mobile/blob/c0680104ccb47a3c0231276b71e24773198f4d37/docs/superpowers/specs/2026-11-23-desktop-distribution-design.md). The existing app,
editor contracts, mobile/Apple implementations and distribution targets remain
in place. Full creation and uploads remain required; this is not another design
approval checkpoint.

## Verified failing boundary

The locked pro_video_editor 2.54.0 native Linux plugin registers successfully,
but renderVideoToFile fails with MissingPluginException. The shipped Windows
libmpv binary has encoders and muxers disabled. Its playback capability is not
an export backend. The earlier FFmpeg package removal remains relevant to
maintainability; this implementation uses GStreamer Editing Services rather
than bringing FFmpeg Kit back.

A Linux x64 GES 1.24.2 native C API probe rendered a trimmed, horizontally
flipped H.264/AAC MP4 from synthetic footage. Decoding verified ten frames at
20 fps, a 0.5-second timeline, the expected left/right pixels and non-silent
audio. This establishes the native primitive, not application parity or Windows
runtime behavior. GES supports Windows; matching Windows execution is required.

## Owning package and interfaces

Add mobile/packages/divine_desktop_video_editor, with its own analysis options,
100% package coverage workflow, native builds and explicit native tests. Keep
its registration out of application startup until the required editor contract
is implemented and tested. Its responsibilities are:

- A Dart client owns one-shot native media processes, request snapshots,
  progress, cancellation, result consumption and temporary files.
- A small native Flutter plugin locates the bundled helper. Windows also owns
  a job object so helpers cannot outlive the app; Linux helpers install a
  parent-death signal before processing input.
- A shared C++ helper implements the existing editor wire data using GES,
  GStreamer readers, encoders and effects. Requests travel over stdin and
  progress/results over stdout, rather than placing media data in process
  arguments. The helper writes only into the request's owned working directory.
- The compatibility adapter preserves ProVideoEditor APIs, materialization,
  cancellation and error types. Reuse the upstream native method client where
  possible; own the desktop transport and streaming bridges explicitly.
- The caller consumes completed artifacts before the job directory is removed.
  A failed or cancelled job never hands a partial file to upload/publishing.

A helper process separates its GStreamer libraries from the app's existing
native plugins and gives cancellation an actual resource boundary. It is not a
persistent service. Do not add telemetry, account state or networking services.

## Implementation sequence

1. Write failing client tests with real synthetic child processes for protocol,
   progress, failure, cancellation, queued work and cleanup. Implement the client
   and its native locator/parent-lifetime boundary. Preserve payload privacy.
2. Turn the native GES primitive into a request-driven renderer. Test missing
   input/encoder, successful render, cancellation, failure cleanup and malformed
   requests. Exercise actual output through the Dart transport on Linux and
   Windows, using synthetic media.
3. Implement metadata, thumbnails/luma frames, audio extraction/merging and
   waveforms needed by current app callers. Test actual decoded output and
   stream completion/cancellation, not successful dispatch alone.
4. Cover the app's transforms, timeline composition, overlays, audio, speed,
   reverse, transitions, masks, stabilization and custom effects. Build a
   caller/field/effect parity matrix from current code; reject unsupported input
   explicitly during development and do not activate a partial adapter.
5. Integrate desktop registration, recording-output mirroring and editor
   preview/export behind the existing app boundaries. Run creation/import to
   export/playback/upload cancellation/retry tests with synthetic accounts and
   footage. Preserve account storage and logout/account-switch cleanup.
6. Complete packaging and library/license manifests, fresh-context whole-diff
   review, relevant coverage/analysis/guards and inspected native CI. Physical
   hardware and store prerequisites remain explicit until verified.

## Runtime pin

The Windows GStreamer SDK candidate is the official MSVC x64 1.28.9 installer:
https://gstreamer.freedesktop.org/data/pkg/windows/1.28.9/msvc/gstreamer-1.0-msvc-x86_64-1.28.9.exe
SHA-256: ce4008705e8c6fe92803535b82fb3d6551e183f438e6ef26682ac4d0aca61076.
This pin is not proof that the required runtime components are present or that
an installer is a distribution candidate. Verify native execution and audit the
selected libraries, notices and corresponding source before packaging.

## Evidence limits

The diagnostic Linux image runs x64 under emulation on an arm64 host. It uses
synthetic footage and no webcam, microphone, real account or production app
entrypoint. Windows SDK existence is not Windows execution. No store submission,
new account, credential/access change, release or merge is part of this
implementation checkpoint. Use the original delivery plan for those boundaries.
