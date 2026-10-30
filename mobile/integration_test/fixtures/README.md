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

The regular macOS application build prerequisites are required. The fixtures share the unit tests' synthetic texture; what they add is a real H.264/AAC encode and native decode. In both portrait and landscape they cover two analysis pixels of camera translation, gentle rotation/scale, a moving edge-touching subject beside plain margins, and camera translation beside plain margins. Full-texture clips are positive repair controls. Both plain-margin shots and both subject-motion shots are conservative rejection controls. A plain margin within a few pixels of the band can still be repaired on encoded footage, because resampling ringing gives the band corners, so the plain-margin shots keep theirs at 12% of the frame. Every video contains 90 frames over three seconds and AAC audio. Generated videos stay outside the repository.

For camera-motion fixtures, the test requires an accepted repair without trimming, decodes the actual exported
MP4, checks the measured seam improvement and residual camera displacement, and
checks frame count, duration, and audio retention. It retains MP4s, diagnostic logs,
and JSON measurements under the fixture directory's native-output subdirectory.
Use ffprobe and video playback to inspect those artifacts independently. The conservative rejection controls must return no match and no rendered replacement; their diagnostics are retained too.

This test is an explicit native integration command; passing ordinary app CI does
not establish that it ran. It does not replace validation of a reported recording
or a physical device. Do not describe a synthetic-video result as a test of the
reporter's actual footage.

To replay an existing recording privately, also pass
--dart-define=LOOP_ALIGNMENT_INPUT_VIDEO=/absolute/path/to/recording.mp4 and use a
private fixture directory for artifacts. The same repair assertions apply: a
no-match result fails the test and retains diagnostics. It is not converted into
a passing rejection test. Keep private recordings and their artifacts out of Git.
