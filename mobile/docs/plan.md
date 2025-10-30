# ProofMode Integration Plan

## Executive Summary

Integrate ProofMode cryptographic verification system into OpenVine's video recording → upload → publishing pipeline. ProofMode provides device attestation, frame hashing, and PGP signatures to prove videos are authentic, human-created content recorded on real devices.

**Current State**: ProofMode infrastructure is production-ready but not connected to recording/publishing flow.

**Target State**: Every recorded video automatically captures ProofMode data and publishes it to Nostr events.

---

## Architecture Overview

### Data Flow
```
Recording Start
    ↓
ProofModeSessionService.startSession()
    ↓
Camera Recording (with frame capture)
    ↓
ProofModeSessionService.captureFrame() (periodic)
    ↓
Recording Stop
    ↓
ProofModeSessionService.finalizeSession() → ProofManifest
    ↓
PendingUpload (with ProofManifest)
    ↓
VideoEventPublisher.publishDirectUpload() → Nostr Event (with ProofMode tags)
```

### Key Integration Points

1. **VineRecordingController** - Orchestrates recording, needs ProofMode session lifecycle
2. **PendingUpload Model** - Needs ProofManifest field for persistence
3. **VideoEventPublisher** - Needs to add 4 ProofMode tags from manifest
4. **BlossomUploadService** - Optional: include ProofMode metadata in upload

---

## Phase 1: Foundation & Data Models

### Step 1.1: Add ProofManifest to PendingUpload Model
**Goal**: Store ProofMode data alongside upload metadata for later publishing.

**Files to Modify**:
- `lib/models/pending_upload.dart`
- `lib/models/pending_upload.g.dart` (regenerate)

**Changes**:
```dart
// Add new HiveField
@HiveField(20)
final String? proofManifestJson; // Serialized ProofManifest

// Add to constructor
const PendingUpload({
  // ... existing fields ...
  this.proofManifestJson,
});

// Add to factory
factory PendingUpload.create({
  // ... existing params ...
  String? proofManifestJson,
}) => PendingUpload(
  // ... existing fields ...
  proofManifestJson: proofManifestJson,
);

// Add to copyWith
PendingUpload copyWith({
  // ... existing fields ...
  String? proofManifestJson,
}) => PendingUpload(
  // ... existing fields ...
  proofManifestJson: proofManifestJson ?? this.proofManifestJson,
);

// Add helper methods
ProofManifest? get proofManifest {
  if (proofManifestJson == null) return null;
  try {
    return ProofManifest.fromJson(jsonDecode(proofManifestJson!));
  } catch (e) {
    Log.error('Failed to parse ProofManifest: $e');
    return null;
  }
}

bool get hasProofMode => proofManifestJson != null;
```

**Test Strategy**:
- Unit test: Serialization/deserialization of ProofManifest in PendingUpload
- Unit test: `hasProofMode` and `proofManifest` getters

**Validation**:
- `flutter test test/models/pending_upload_proofmode_test.dart`
- Verify Hive adapter regenerates without errors

---

### Step 1.2: Add ProofMode Helper Functions
**Goal**: Create utilities for extracting ProofMode tags from ProofManifest.

**Files to Create**:
- `lib/utils/proofmode_publishing_helpers.dart`

**Implementation**:
```dart
/// Extract proof-verification-level from ProofManifest
String getVerificationLevel(ProofManifest manifest) {
  // verified_mobile: has attestation + manifest + signature
  if (manifest.deviceAttestation != null &&
      manifest.pgpSignature != null) {
    return 'verified_mobile';
  }

  // verified_web: has manifest + signature (no hardware attestation)
  if (manifest.pgpSignature != null) {
    return 'verified_web';
  }

  // basic_proof: has some proof data
  if (manifest.segments.isNotEmpty) {
    return 'basic_proof';
  }

  return 'unverified';
}

/// Create proof-manifest tag value (compact JSON)
String createProofManifestTag(ProofManifest manifest) {
  return jsonEncode(manifest.toJson());
}

/// Create proof-device-attestation tag value
String? createDeviceAttestationTag(ProofManifest manifest) {
  return manifest.deviceAttestation?.attestationToken;
}

/// Create proof-pgp-fingerprint tag value
String? createPgpFingerprintTag(ProofManifest manifest) {
  return manifest.pgpSignature?.publicKeyFingerprint;
}
```

**Test Strategy**:
- Unit test: `getVerificationLevel()` for all 4 levels
- Unit test: Tag creation functions with real ProofManifest objects
- Unit test: Null safety for optional fields

**Validation**:
- `flutter test test/utils/proofmode_publishing_helpers_test.dart`

---

## Phase 2: Recording Integration

### Step 2.1: Wire ProofModeSessionService into VineRecordingController
**Goal**: Start/stop ProofMode sessions during video recording lifecycle.

**Files to Modify**:
- `lib/services/vine_recording_controller.dart`
- `lib/providers/vine_recording_provider.dart`

**Changes to VineRecordingController**:
```dart
class VineRecordingController {
  // Add field
  final ProofModeSessionService? _proofModeSession;
  String? _currentProofSessionId;

  // Add to constructor
  VineRecordingController({
    ProofModeSessionService? proofModeSession,
  }) : _proofModeSession = proofModeSession;

  // Modify startRecording()
  Future<void> startRecording() async {
    if (!canRecord) return;

    // Start ProofMode session on first segment
    if (_segments.isEmpty && _proofModeSession != null) {
      _currentProofSessionId = await _proofModeSession.startSession();
      if (_currentProofSessionId != null) {
        await _proofModeSession.startRecordingSegment();
      }
    } else if (_proofModeSession != null && _currentProofSessionId != null) {
      // Resume segment for subsequent recordings
      await _proofModeSession.resumeRecording();
    }

    // ... existing recording logic ...
  }

  // Modify stopRecording()
  Future<void> stopRecording() async {
    // ... existing logic ...

    // Pause ProofMode segment
    if (_proofModeSession != null && _currentProofSessionId != null) {
      await _proofModeSession.pauseRecording();
    }

    // ... rest of existing logic ...
  }

  // Modify finishRecording()
  Future<(File?, ProofManifest?)> finishRecording() async {
    // ... existing concatenation logic ...

    ProofManifest? proofManifest;

    if (_proofModeSession != null && _currentProofSessionId != null) {
      // Calculate SHA256 hash of final video
      final videoFile = /* result from concatenation */;
      final videoBytes = await videoFile.readAsBytes();
      final videoHash = sha256.convert(videoBytes).toString();

      // Finalize ProofMode session
      proofManifest = await _proofModeSession.finalizeSession(videoHash);
      _currentProofSessionId = null;
    }

    return (videoFile, proofManifest);
  }
}
```

**Test Strategy**:
- Integration test: ProofMode session lifecycle during recording
- Mock ProofModeSessionService to verify method calls
- Test with/without ProofMode enabled (feature flag)

**Validation**:
- `flutter test test/integration/proofmode_recording_integration_test.dart`
- Verify session starts/pauses/resumes/finalizes correctly

---

### Step 2.2: Add Frame Capture Hook
**Goal**: Capture frame hashes during recording (optional enhancement).

**Files to Modify**:
- `lib/services/vine_recording_controller.dart`

**Implementation** (optional, can be done later):
```dart
// In _startProgressTimer()
_progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
  if (!_disposed && _state == VineRecordingState.recording) {
    // Existing progress update logic...

    // Capture frame for ProofMode (every 500ms)
    if (_proofModeSession != null &&
        DateTime.now().millisecondsSinceEpoch % 500 < 100) {
      _captureCurrentFrame();
    }
  }
});

Future<void> _captureCurrentFrame() async {
  // Platform-specific frame capture
  // This is optional - ProofMode works without frame hashes
  // They provide additional verification but add complexity
}
```

**Decision Point**: Defer frame capture to Phase 3 (post-MVP). Focus on basic ProofMode integration first.

---

### Step 2.3: Update VineRecordingProvider
**Goal**: Pass ProofManifest from recording controller to upload flow.

**Files to Modify**:
- `lib/providers/vine_recording_provider.dart`

**Changes**:
```dart
// Modify finishRecording() method
Future<File?> finishRecording() async {
  try {
    state = state.copyWith(status: RecordingStatus.processing);

    final (videoFile, proofManifest) = await _controller.finishRecording();

    if (videoFile != null) {
      state = state.copyWith(
        status: RecordingStatus.completed,
        videoFile: videoFile,
        proofManifest: proofManifest, // Add to state
      );
      return videoFile;
    }

    // ... error handling ...
  }
}
```

**Test Strategy**:
- Unit test: Provider state includes ProofManifest after finish
- Integration test: Full recording → finish → state update flow

**Validation**:
- `flutter test test/providers/vine_recording_provider_proofmode_test.dart`

---

## Phase 3: Upload Integration

### Step 3.1: Pass ProofManifest to Upload Manager
**Goal**: Include ProofManifest when creating PendingUpload.

**Files to Modify**:
- `lib/screens/pure/vine_preview_screen_pure.dart` (or wherever upload is initiated)
- `lib/services/upload_manager.dart`

**Changes to startUpload()**:
```dart
Future<PendingUpload> startUpload({
  required File videoFile,
  required String nostrPubkey,
  // ... existing params ...
  ProofManifest? proofManifest, // Add parameter
}) async {
  // ... existing logic ...

  String? proofManifestJson;
  if (proofManifest != null) {
    try {
      proofManifestJson = jsonEncode(proofManifest.toJson());
      Log.info('Including ProofMode manifest in upload');
    } catch (e) {
      Log.error('Failed to serialize ProofManifest: $e');
    }
  }

  final upload = PendingUpload.create(
    localVideoPath: videoFile.path,
    nostrPubkey: nostrPubkey,
    // ... existing fields ...
    proofManifestJson: proofManifestJson,
  );

  // ... rest of upload logic ...
}
```

**Test Strategy**:
- Unit test: PendingUpload created with ProofManifest JSON
- Integration test: End-to-end recording → upload with ProofMode

**Validation**:
- `flutter test test/services/upload_manager_proofmode_test.dart`
- Verify manifest persists in Hive storage

---

### Step 3.2: Optional - Send ProofMode Metadata to Blossom
**Goal**: Include ProofMode data in Blossom upload request (if server supports it).

**Files to Modify**:
- `lib/services/blossom_upload_service.dart`

**Decision Point**: **Skip for MVP**. Blossom servers don't need ProofMode data - it goes directly into Nostr events. This step can be added later if Blossom adds ProofMode support.

---

## Phase 4: Publishing Integration

### Step 4.1: Add ProofMode Tags to Nostr Events
**Goal**: Publish ProofMode verification data in video Nostr events.

**Files to Modify**:
- `lib/services/video_event_publisher.dart`

**Changes to publishDirectUpload()**:
```dart
Future<bool> publishDirectUpload(PendingUpload upload, ...) async {
  // ... existing validation and tag creation ...

  // Add ProofMode tags if available
  if (upload.hasProofMode && upload.proofManifest != null) {
    final manifest = upload.proofManifest!;

    // Add proof-verification-level tag
    final verificationLevel = ProofModePublishingHelpers.getVerificationLevel(manifest);
    tags.add(['proof-verification-level', verificationLevel]);

    // Add proof-manifest tag (compact JSON)
    final manifestJson = ProofModePublishingHelpers.createProofManifestTag(manifest);
    tags.add(['proof-manifest', manifestJson]);

    // Add proof-device-attestation tag (if available)
    final attestationToken = ProofModePublishingHelpers.createDeviceAttestationTag(manifest);
    if (attestationToken != null) {
      tags.add(['proof-device-attestation', attestationToken]);
    }

    // Add proof-pgp-fingerprint tag (if available)
    final pgpFingerprint = ProofModePublishingHelpers.createPgpFingerprintTag(manifest);
    if (pgpFingerprint != null) {
      tags.add(['proof-pgp-fingerprint', pgpFingerprint]);
    }

    Log.info('Added ProofMode tags to video event: $verificationLevel');
  }

  // ... rest of publishing logic ...
}
```

**Test Strategy**:
- Unit test: Correct tags generated for each verification level
- Unit test: Tags omitted when no ProofManifest
- Integration test: End-to-end publishing with ProofMode tags

**Validation**:
- `flutter test test/services/video_event_publisher_proofmode_test.dart`
- Manual verification: Publish video and inspect event tags on relay

---

## Phase 5: Testing & Verification

### Step 5.1: Comprehensive Integration Tests
**Goal**: Verify complete flow from recording to publishing.

**Test Coverage**:
1. **Happy Path**: Record → Upload → Publish with ProofMode
2. **ProofMode Disabled**: Record → Upload → Publish without ProofMode
3. **Partial ProofMode**: Manifest without attestation (verified_web level)
4. **Error Recovery**: ProofMode failure doesn't break recording/upload

**Files to Create**:
- `test/integration/proofmode_end_to_end_test.dart`

**Test Structure**:
```dart
testWidgets('Complete ProofMode flow - recording to publishing', (tester) async {
  // 1. Initialize services with ProofMode enabled
  final proofModeSession = ProofModeSessionService(...);
  final recordingController = VineRecordingController(
    proofModeSession: proofModeSession,
  );

  // 2. Record video with ProofMode session
  await recordingController.initialize();
  await recordingController.startRecording();
  await Future.delayed(Duration(seconds: 2));
  await recordingController.stopRecording();

  final (videoFile, manifest) = await recordingController.finishRecording();

  // 3. Verify manifest was created
  expect(manifest, isNotNull);
  expect(manifest!.segments, isNotEmpty);
  expect(manifest.pgpSignature, isNotNull);

  // 4. Create upload with manifest
  final upload = PendingUpload.create(
    localVideoPath: videoFile!.path,
    nostrPubkey: testPubkey,
    proofManifestJson: jsonEncode(manifest.toJson()),
  );

  // 5. Publish and verify tags
  final publisher = VideoEventPublisher(...);
  final success = await publisher.publishDirectUpload(upload);

  expect(success, isTrue);

  // 6. Verify event has ProofMode tags
  final publishedEvent = /* get from mock NostrService */;
  expect(
    publishedEvent.tags.any((t) => t[0] == 'proof-verification-level'),
    isTrue,
  );
  expect(
    publishedEvent.tags.any((t) => t[0] == 'proof-manifest'),
    isTrue,
  );
});
```

---

### Step 5.2: Feature Flag Testing
**Goal**: Ensure ProofMode can be disabled without breaking functionality.

**Test Cases**:
- ProofMode disabled globally (config flag)
- ProofMode enabled but session creation fails
- ProofMode enabled but finalization fails

**Validation**:
- Recording/upload/publishing works without ProofMode
- No ProofMode tags when disabled
- Graceful degradation on errors

---

### Step 5.3: Manual Verification Checklist
**Goal**: Human verification of ProofMode integration.

**Steps**:
1. Build and run app on iOS/Android
2. Record a 6-second video
3. Upload and publish video
4. Use Nostr client to fetch published event
5. Verify event contains all 4 ProofMode tags
6. Verify badge displays correctly on video
7. Test with ProofMode disabled in settings
8. Verify no ProofMode tags when disabled

---

## Phase 6: Documentation & Rollout

### Step 6.1: Update Documentation
**Goal**: Document ProofMode integration for future developers.

**Files to Update**:
- `docs/PROOFMODE_INTEGRATION.md` (create)
- `docs/KIND_34236_SCHEMA.md` (verify accuracy)
- `README.md` (mention ProofMode)

**Documentation Sections**:
1. Architecture overview
2. Data flow diagrams
3. Feature flag configuration
4. Testing guidelines
5. Troubleshooting guide

---

### Step 6.2: Performance Testing
**Goal**: Ensure ProofMode doesn't degrade performance.

**Metrics to Measure**:
- Recording initialization time (with/without ProofMode)
- Video processing time (manifest generation overhead)
- Upload time (manifest serialization overhead)
- Memory usage during recording

**Acceptance Criteria**:
- <50ms overhead for ProofMode initialization
- <200ms overhead for manifest generation
- No memory leaks during extended recording sessions

---

### Step 6.3: Privacy & Security Review
**Goal**: Verify ProofMode implementation follows security best practices.

**Review Points**:
1. PGP keys stored securely (device keychain)
2. Device attestation tokens don't leak device identifiers
3. Manifest data doesn't include PII
4. Feature can be disabled by users
5. Clear user communication about ProofMode data

---

## Implementation Order

### Sprint 1 (Foundation)
- Step 1.1: Add ProofManifest to PendingUpload ✓
- Step 1.2: ProofMode helper functions ✓

### Sprint 2 (Recording Integration)
- Step 2.1: Wire ProofModeSessionService into VineRecordingController ✓
- Step 2.3: Update VineRecordingProvider ✓

### Sprint 3 (Upload & Publishing)
- Step 3.1: Pass ProofManifest to Upload Manager ✓
- Step 4.1: Add ProofMode tags to Nostr events ✓

### Sprint 4 (Testing)
- Step 5.1: Integration tests ✓
- Step 5.2: Feature flag testing ✓
- Step 5.3: Manual verification ✓

### Sprint 5 (Polish & Launch)
- Step 6.1: Documentation ✓
- Step 6.2: Performance testing ✓
- Step 6.3: Security review ✓

---

## Risk Mitigation

### Technical Risks
1. **Risk**: ProofMode session lifecycle mismatches recording lifecycle
   - **Mitigation**: Comprehensive state machine testing

2. **Risk**: ProofManifest serialization/deserialization errors
   - **Mitigation**: Extensive unit tests + error handling

3. **Risk**: Performance degradation during recording
   - **Mitigation**: Optional frame capture, async operations

### Product Risks
1. **Risk**: Users confused by ProofMode badges
   - **Mitigation**: Clear UI/UX + help documentation

2. **Risk**: ProofMode increases app complexity
   - **Mitigation**: Feature flag + gradual rollout

---

## Success Metrics

1. **Functional Success**:
   - ✓ 100% of videos recorded with ProofMode have verification tags
   - ✓ All 4 verification levels work correctly
   - ✓ ProofMode can be disabled without breaking functionality

2. **Performance Success**:
   - ✓ <50ms ProofMode initialization overhead
   - ✓ <200ms manifest generation overhead
   - ✓ No memory leaks

3. **Quality Success**:
   - ✓ >90% test coverage for ProofMode integration
   - ✓ Zero critical bugs in production
   - ✓ <5% user reports of ProofMode issues

---

## Future Enhancements (Post-MVP)

1. **Frame Capture**: Implement periodic frame hashing during recording
2. **Sensor Data**: Capture accelerometer/gyroscope during recording
3. **Location Proofs**: Optional GPS timestamping
4. **Human Detection**: AI-based human presence verification
5. **Blossom Integration**: Send ProofMode metadata to Blossom servers
6. **Verification UI**: Display detailed ProofMode verification results
