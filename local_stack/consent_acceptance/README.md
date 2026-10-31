# Local parent-consent acceptance

This harness exercises the production Dart `ApiService`, NIP-98 signer and
multipart upload against an **unmodified relay-manager Worker candidate** over
HTTP. A checksum verifies the pinned Worker/shared source and dependency lock.
Miniflare supplies real disposable D1 and R2. Ticketing, Access JWKS,
Keycast and relay enforcement use synthetic, allowlisted local responses; all
other outbound requests are denied. No existing service configuration or
credentials are loaded.

Use backend PR #312's exact candidate
`85d5015785b97d8d0082d3aa3743dbe395ac90ba` and the mobile repository's pinned
Flutter SDK. In an isolated backend checkout/snapshot, run
`npm ci --legacy-peer-deps` from `worker/` (matching that candidate's CI),
then from the mobile repository root:

```sh
python3 local_stack/consent_acceptance/run.py /path/to/backend-candidate
```

The runner starts a fresh loopback server on an unused port, waits for readiness,
tests the real signed upload, cached-success reuse, exact private playback bytes,
unauthorized playback denial, Access expiry/audience checks, byte ranges and
the moderator approval transition, then destroys the local runtime.

For the native emulator walkthrough, run the server separately:

```sh
node local_stack/consent_acceptance/server.mjs /path/to/backend-candidate
adb reverse tcp:48787 tcp:48787
```

Install the debug staging app on the emulator and grant its CAMERA,
RECORD_AUDIO and POST_NOTIFICATIONS permissions. Run the production capture
screen through the normal timeline-preserving integration harness:

```sh
E2E_BACKEND_LOG=/path/to/captured-server.log \
E2E_TEST_PERMISSIONS='android.permission.CAMERA android.permission.RECORD_AUDIO' \
  bash local_stack/profile.sh integration_test/consent/native_consent_capture_test.dart
```

On CI, the workflow builds the exact integration-test APK **before** booting the
emulator and sets `E2E_PREBUILT_APK` to that file. The profiler then uses the
existing Flutter integration driver with `--use-application-binary`, so no Gradle
build competes with the running emulator. CI-only Gradle/Kotlin limits bound
build memory; local/release defaults are unchanged. The prebuilt dispatch and
failure reporting have four command-boundary regressions in `test_profile.py`.

The native test uses the real camera service, recorder, preview, submission
Cubit/repository and HTTP upload. Only the account identity is synthetic; the
backend's external dependencies remain synthetic as above. A focused two-route
test app hosts the production screen; authentication and the feature flag are
set explicitly. Production redirect eligibility remains covered by the routing
tests, not by this screen walkthrough. It records the
emulator scene, never a real family. Test control routes and generated Access
tokens exist only on the loopback harness and are never production code.

These checks establish local contract/device behavior. They do not establish a
deployed Access policy, third-party service delivery, physical-phone behavior
or a human moderator's actual account approval.
