# Native loop alignment verification

The ordinary Flutter unit tests do not run the platform video decoder or renderer.
This explicit macOS integration test uses the editor's production input mapping,
repair repository, native PVE backend, rendered-output inspection, and result
application. Only temporary output placement is redirected; no plugin channels or
rendering operations are mocked.

From mobile/, generate controlled H.264/AAC videos and run the real native app:

```sh
python3 integration_test/fixtures/generate_loop_drift.py /private/tmp/loop-native-verification
mise exec -- flutter test --no-pub -d macos integration_test/video_editor/loop_alignment_native_test.dart --dart-define=LOOP_ALIGNMENT_FIXTURE_DIR=/private/tmp/loop-native-verification --reporter expanded
```

The regular macOS application build prerequisites are required. The fixtures use
independently generated texture, plain margins, and two analysis pixels of camera
drift over three seconds. Both portrait and landscape videos contain 90 frames
and audio. Generated videos stay outside the repository.

The test requires an accepted repair without trimming, decodes the actual exported
MP4, checks the measured seam improvement and residual camera displacement, and
checks frame count, duration, and audio retention. It retains MP4s, diagnostic logs,
and JSON measurements under the fixture directory's native-output subdirectory.
Use ffprobe and video playback to inspect those artifacts independently.

This test is an explicit native integration command; passing ordinary app CI does
not establish that it ran. It does not replace validation of a reported recording
or a physical device. Do not describe a synthetic-video result as a test of the
reporter's actual footage.

To replay an existing recording privately, also pass
--dart-define=LOOP_ALIGNMENT_INPUT_VIDEO=/absolute/path/to/recording.mp4 and use a
private fixture directory for artifacts. The same repair assertions apply: a
no-match result fails the test and retains diagnostics. It is not converted into
a passing rejection test. Keep private recordings and their artifacts out of Git.
