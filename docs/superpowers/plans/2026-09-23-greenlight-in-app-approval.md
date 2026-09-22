# Greenlight In-App Parent Approval — Mobile Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make in-app recording the primary way a parent gives consent for a 13–15 account, keeping the email/link route as a fallback.

**Architecture:** A thin `MinorConsentRecorder` port wraps the existing `CameraService` so the capture screen can be tested without native hardware. A new multi-part `ApiService` call and repository method submit the parent email plus the recorded clip to relay-manager in one request. The existing `parent-contact` email route stays untouched.

**Tech Stack:** Flutter, Riverpod, `go_router`, `package:http` multipart, existing `CameraService` / `PermissionsService` / `Nip98AuthService`, `divine_ui`.

**Spec:** `docs/superpowers/specs/2026-09-23-greenlight-in-app-approval-design.md`

## Global Constraints

- Work runs from `mobile/`. Flutter commands run there.
- New UI uses `VineTheme` / `context.vineColors` and `divine_ui` components. No raw `Colors.*`, `TextStyle(`, Material buttons, dialogs, or `package:flutter/material.dart` (use `package:material_ui/material_ui.dart`).
- Every new user-facing string is an ARB key read through `context.l10n` in the same change, mirrored into every `app_*.arb` locale or added to `_knownUntranslatedDebt` in `test/l10n/arb_consistency_test.dart`.
- Every test declaration lives inside a `group()`. Tests mirror `lib/` under `test/`; never under `test/unit/`.
- New service under `lib/services/` requires a same-named test and a ratcheted `mobile/scripts/baseline/untested_services.txt`.
- No truncated Nostr IDs in logs; this flow logs no identifiers.
- Hard recording cap: 60 seconds.

---

### Task 0 (dependency, not in this plan): relay-manager route

`POST /v1/minor-review-cases/{caseId}/parent-consent`, multipart, fields `email` and `video`, NIP-98 authenticated. Creates the Zendesk ticket with the video attached, moves the case to `submittedForReview`. Tracked in `divinevideo/divine-relay-manager`. Mobile work below is testable against a mocked repository and must not merge before the route exists or a feature flag stubs it.

---

### Task 1: `MinorConsentRecorder` port and provider

**Files:**
- Create: `mobile/lib/services/minor_consent_recorder.dart`
- Test: `mobile/test/services/minor_consent_recorder_test.dart`
- Modify: `mobile/lib/providers/minor_account_review_providers.dart`
- Modify: `mobile/scripts/baseline/untested_services.txt`

**Interfaces:**
- Produces:
  - `abstract class MinorConsentRecorder { Future<bool> start({required Duration maxDuration, required String outputDirectory}); Future<String?> stop(); Future<void> dispose(); }`
  - `class CameraMinorConsentRecorder implements MinorConsentRecorder` wrapping `CameraService`.
  - `final minorConsentRecorderProvider = Provider<MinorConsentRecorder>(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// mobile/test/services/minor_consent_recorder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakeCameraService implements CameraService {
  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    return true;
  }

  @override
  Future<EditorVideo?> stopRecording() async =>
      const EditorVideo(path: '/tmp/consent.mp4', duration: Duration(seconds: 3));

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CameraMinorConsentRecorder', () {
    test('start forwards the cap and stop returns the recorded path', () async {
      final camera = _FakeCameraService();
      final recorder = CameraMinorConsentRecorder(camera: camera);

      final started = await recorder.start(
        maxDuration: const Duration(seconds: 60),
        outputDirectory: '/tmp',
      );
      final path = await recorder.stop();

      expect(started, isTrue);
      expect(path, '/tmp/consent.mp4');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/minor_consent_recorder_test.dart`
Expected: FAIL — `minor_consent_recorder.dart` not found.

- [ ] **Step 3: Write minimal implementation**

```dart
// mobile/lib/services/minor_consent_recorder.dart
// ABOUTME: Port over CameraService for the minor-consent recording flow so the
// ABOUTME: capture screen is testable without native camera hardware.

import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

abstract class MinorConsentRecorder {
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  });

  Future<String?> stop();

  Future<void> dispose();
}

class CameraMinorConsentRecorder implements MinorConsentRecorder {
  CameraMinorConsentRecorder({required CameraService camera}) : _camera = camera;

  final CameraService _camera;

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) => _camera.startRecording(
    maxDuration: maxDuration,
    outputDirectory: outputDirectory,
  );

  @override
  Future<String?> stop() async {
    final EditorVideo? video = await _camera.stopRecording();
    return video?.path;
  }

  @override
  Future<void> dispose() => _camera.dispose();
}
```

Note: confirm the `EditorVideo` field name against `pro_video_editor` before committing; adjust `video?.path` to the real getter.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/minor_consent_recorder_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the provider**

In `mobile/lib/providers/minor_account_review_providers.dart` add:

```dart
/// Recorder used by the in-app parent-consent capture flow.
final minorConsentRecorderProvider = Provider<MinorConsentRecorder>((ref) {
  final camera = CameraService.create(
    onUpdateState: ({bool? forceCameraRebuild}) {},
    onAutoStopped: (EditorVideo? video) {},
  );
  final recorder = CameraMinorConsentRecorder(camera: camera);
  ref.onDispose(recorder.dispose);
  return recorder;
});
```

Import `package:openvine/services/minor_consent_recorder.dart` and the `CameraService` / `EditorVideo` types.

- [ ] **Step 6: Ratchet the untested-services floor**

Run: `cd mobile && UPDATE_BASELINE=1 bash scripts/check_untested_services_floor.sh`
Expected: `mobile/scripts/baseline/untested_services.txt` unchanged if the test counts; otherwise it will list the new service — resolve by ensuring the test imports the service directly.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/services/minor_consent_recorder.dart mobile/test/services/minor_consent_recorder_test.dart mobile/lib/providers/minor_account_review_providers.dart mobile/scripts/baseline/untested_services.txt
git commit -m "feat(age-review): add minor-consent recorder port"
```

---

### Task 2: Multi-part submit in `ApiService` and repository

**Files:**
- Modify: `mobile/lib/services/api_service.dart`
- Modify: `mobile/lib/repositories/minor_account_review_repository.dart`
- Test: `mobile/test/repositories/minor_account_review_repository_test.dart`

**Interfaces:**
- Consumes: `Nip98AuthService.createAuthToken({url, method, payload})`.
- Produces:
  - `Future<void> ApiService.submitMinorAccountReviewParentConsent({required String caseId, required String email, required String videoPath})`
  - `Future<void> MinorAccountReviewRepository.submitParentConsent({required String caseId, required String email, required String videoPath})`

- [ ] **Step 1: Write the failing repository test**

```dart
// add to mobile/test/repositories/minor_account_review_repository_test.dart
group('submitParentConsent', () {
  test('forwards caseId, email and videoPath to ApiService', () async {
    final api = MockApiService();
    when(() => api.submitMinorAccountReviewParentConsent(
      caseId: 'case-1',
      email: 'parent@example.com',
      videoPath: '/tmp/consent.mp4',
    )).thenAnswer((_) async {});

    final repository = MinorAccountReviewRepository(apiService: api);
    await repository.submitParentConsent(
      caseId: 'case-1',
      email: 'parent@example.com',
      videoPath: '/tmp/consent.mp4',
    );

    verify(() => api.submitMinorAccountReviewParentConsent(
      caseId: 'case-1',
      email: 'parent@example.com',
      videoPath: '/tmp/consent.mp4',
    )).called(1);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/repositories/minor_account_review_repository_test.dart`
Expected: FAIL — method not defined.

- [ ] **Step 3: Add the repository method**

```dart
// mobile/lib/repositories/minor_account_review_repository.dart
Future<void> submitParentConsent({
  required String caseId,
  required String email,
  required String videoPath,
}) async {
  await _apiService.submitMinorAccountReviewParentConsent(
    caseId: caseId,
    email: email,
    videoPath: videoPath,
  );
}
```

- [ ] **Step 4: Add the ApiService method**

```dart
// mobile/lib/services/api_service.dart
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<void> submitMinorAccountReviewParentConsent({
  required String caseId,
  required String email,
  required String videoPath,
}) async {
  final uri = Uri.parse(
    '$_relayManagerBaseUrl/v1/minor-review-cases/$caseId/parent-consent',
  );
  final file = File(videoPath);
  final bytes = await file.readAsBytes();
  final payload = sha256.convert(bytes).toString();

  final request = http.MultipartRequest('POST', uri)
    ..fields['email'] = email
    ..files.add(await http.MultipartFile.fromPath('video', videoPath));

  final token = await _authService?.createAuthToken(
    url: uri.toString(),
    method: HttpMethod.post,
    payload: payload,
  );
  request.headers.addAll({
    'Accept': 'application/json',
    ...buildDivineClientHeaders(appVersion: _appVersion),
    if (token != null) 'Authorization': token.authorizationHeader,
  });

  final streamed = await _request(() async => _client.send(request).then(
    (s) async => http.Response.fromStream(s),
  ));

  if (streamed.statusCode == 200 ||
      streamed.statusCode == 201 ||
      streamed.statusCode == 204) {
    return;
  }

  throw ApiException(
    'Failed to submit parent consent video',
    statusCode: streamed.statusCode,
    responseBody: streamed.body,
  );
}
```

- [ ] **Step 5: Run tests**

Run: `cd mobile && flutter test test/repositories/minor_account_review_repository_test.dart`
Expected: PASS. Then `cd mobile && flutter analyze lib/services/api_service.dart lib/repositories/minor_account_review_repository.dart`.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/api_service.dart mobile/lib/repositories/minor_account_review_repository.dart mobile/test/repositories/minor_account_review_repository_test.dart
git commit -m "feat(age-review): submit parent consent video as multipart"
```

---

### Task 3: Capture screen (record, review, retake)

**Files:**
- Create: `mobile/lib/screens/minor_account_review_record_consent_screen.dart`
- Create: `mobile/lib/blocs/minor_consent_capture/minor_consent_capture_cubit.dart`
- Test: `mobile/test/blocs/minor_consent_capture/minor_consent_capture_cubit_test.dart`
- Modify: `mobile/lib/router/route_paths.dart`
- Modify: `mobile/lib/router/routes/minor_account_review_routes.dart`

**Interfaces:**
- Consumes: `minorConsentRecorderProvider`, `permissionsServiceProvider`.
- Produces: `MinorAccountReviewRecordConsentScreen.path`, and a cubit state
  `MinorConsentCaptureState { idle, recording, review(filePath), denied, error }`.

- [ ] **Step 1: Write the failing cubit test**

```dart
// mobile/test/blocs/minor_consent_capture/minor_consent_capture_cubit_test.dart
group('MinorConsentCaptureCubit', () {
  test('start then stop lands in review with the recorded path', () async {
    final recorder = _FakeRecorder();
    final cubit = MinorConsentCaptureCubit(recorder: recorder);

    await cubit.start(outputDirectory: '/tmp');
    expect(cubit.state, isA<MinorConsentCaptureRecording>());

    await cubit.stop();
    expect(cubit.state, isA<MinorConsentCaptureReview>());
    expect((cubit.state as MinorConsentCaptureReview).filePath, '/tmp/consent.mp4');
  });

  test('a denied start surfaces denied state', () async {
    final recorder = _FakeRecorder(startResult: false);
    final cubit = MinorConsentCaptureCubit(recorder: recorder);

    await cubit.start(outputDirectory: '/tmp');
    expect(cubit.state, isA<MinorConsentCaptureDenied>());
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/blocs/minor_consent_capture/minor_consent_capture_cubit_test.dart`
Expected: FAIL — files not found.

- [ ] **Step 3: Implement the cubit**

States: `sealed class MinorConsentCaptureState`, subclasses `MinorConsentCaptureIdle`, `Recording`, `Review(String filePath)`, `Denied`, `Error`. Cubit wraps `MinorConsentRecorder`, calls `start(maxDuration: const Duration(seconds: 60), outputDirectory: ...)`, and on `false` emits `Denied`; `stop()` emits `Review(path)` or `Error` when null; a `retake()` returns to `Idle`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/blocs/minor_consent_capture/minor_consent_capture_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Build the screen**

`MinorAccountReviewRecordConsentScreen` renders a live camera preview (reuse the existing preview widget from the recorder screen), a prompt card with the four required lines, a record/stop control, and on `Review` a playback with **Retake** and **Use this video**. Follow `mobile/lib/screens/minor_account_review_parent_consent_screen.dart` for layout, `VineTheme`, and `divine_ui` components. Denied state renders copy plus a **Use email instead** button routing to the parent-consent screen.

- [ ] **Step 6: Register the route**

Add `RoutePaths.minorAccountReviewConsentRecord = '/account-review/parent-consent/record'` and a `GoRoute` in `minor_account_review_routes.dart` matching the existing entries; expose `MinorAccountReviewRecordConsentScreen.path` as a thin delegate.

- [ ] **Step 7: Add ARB keys** for the prompt card, buttons, and denied copy; mirror into locales or the untranslated-debt list, then run `cd mobile && flutter test test/l10n/arb_consistency_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/screens/minor_account_review_record_consent_screen.dart mobile/lib/blocs/minor_consent_capture mobile/test/blocs/minor_consent_capture mobile/lib/router/route_paths.dart mobile/lib/router/routes/minor_account_review_routes.dart mobile/lib/l10n
git commit -m "feat(age-review): add in-app consent recording screen"
```

---

### Task 4: Submit and success, wire the primary CTA

**Files:**
- Modify: `mobile/lib/screens/minor_account_review_record_consent_screen.dart`
- Modify: `mobile/lib/screens/minor_account_review_parent_consent_screen.dart`
- Test: `mobile/test/screens/minor_account_review_parent_consent_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Assert the parent-consent screen's primary action now routes to the record screen, and that the email action is secondary.

- [ ] **Step 2: Run it to verify it fails**

Run: `cd mobile && flutter test test/screens/minor_account_review_parent_consent_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Swap the CTAs**

Primary `DivineButton` label uses a new key `minorAccountReviewParentConsentRecordCta` and `context.push(MinorAccountReviewRecordConsentScreen.path)`. Existing `minorAccountReviewParentConsentEmailCta` button becomes `DivineButtonType.secondary`.

- [ ] **Step 4: Add the email-confirm + submit step**

On **Use this video**, collect/confirm the parent email (reuse `DivineAuthTextField` and `Validators.validateEmail` from `minor_account_review_parent_contact_screen.dart`), then call `ref.read(minorAccountReviewRepositoryProvider).submitParentConsent(caseId:, email:, videoPath:)`. On success invalidate `currentMinorAccountReviewStatusProvider` and `protectedMinorStatusProvider`, then show the success view (`minorAccountReviewSubmissionReceivedTitle`). On failure keep the local file, show a retry, and keep the email fallback visible. Handle `kDebugMode` the same way the parent-contact screen does.

- [ ] **Step 5: Run tests**

Run: `cd mobile && flutter test test/screens/minor_account_review_parent_consent_screen_test.dart` then `cd mobile && flutter analyze`.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/minor_account_review_parent_consent_screen.dart mobile/lib/screens/minor_account_review_record_consent_screen.dart mobile/test/screens/minor_account_review_parent_consent_screen_test.dart
git commit -m "feat(age-review): make in-app recording the primary consent path"
```

---

### Task 5: Error, permission, and offline handling

**Files:**
- Modify: `mobile/lib/screens/minor_account_review_record_consent_screen.dart`
- Test: `mobile/test/screens/minor_account_review_record_consent_screen_test.dart`

- [ ] **Step 1: Write failing tests** for three states using the cubit fake: camera permission denied shows the email fallback; a submit failure keeps the review state and shows retry; an offline submit surfaces retry without discarding the clip.
- [ ] **Step 2: Run to verify they fail.**
- [ ] **Step 3: Implement** the permission check through `permissionsServiceProvider` (`checkCameraStatus` / `requestCameraPermission`, `checkMicrophoneStatus` / `requestMicrophonePermission`) before recording, and the retry affordance on submit failure.
- [ ] **Step 4: Run to verify they pass**, then `cd mobile && flutter analyze`.
- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/minor_account_review_record_consent_screen.dart mobile/test/screens/minor_account_review_record_consent_screen_test.dart
git commit -m "feat(age-review): handle consent capture permission and retry states"
```

---

### Task 6: Golden and final verification

**Files:**
- Create: `mobile/test/goldens/minor_account_review_record_consent_test.dart`

- [ ] **Step 1:** Add a golden test for the idle and review states, draining fonts with `await tester.runAsync(GoogleFonts.pendingFonts)` per `mobile/docs/GOLDEN_TESTING_GUIDE.md`. Reference images are generated on the runner only.
- [ ] **Step 2:** Run the affected suites and guards:

```bash
cd mobile && flutter test test/services/minor_consent_recorder_test.dart test/blocs/minor_consent_capture test/repositories/minor_account_review_repository_test.dart test/screens/minor_account_review_parent_consent_screen_test.dart test/screens/minor_account_review_record_consent_screen_test.dart test/l10n/arb_consistency_test.dart
cd mobile && flutter analyze
cd mobile && bash scripts/ci/run_guards.sh
```

- [ ] **Step 3:** Commit.

```bash
git add mobile/test/goldens
git commit -m "test(age-review): add consent capture golden and verification"
```

---

## Self-Review

- **Spec coverage:** flow (Tasks 3–4), recording UX (Task 3), data flow (Tasks 2, 4), backend (Task 0), storage/retention (Task 0, no mobile work), error handling (Task 5), testing (Tasks 1–6), out of scope excluded.
- **Open blocker:** the retention/access policy on #230 must be agreed before Task 0 builds; the mobile work can proceed behind a mock.
- **Verification risk:** exact `EditorVideo` field name and the camera-preview widget reuse are confirmed at Task 1 Step 3 and Task 3 Step 5 before code is committed.