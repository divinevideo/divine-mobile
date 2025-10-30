# ProofMode Integration TODO

## Sprint 1: Foundation (Data Models)

### Step 1.1: Add ProofManifest to PendingUpload Model
- [ ] Add `proofManifestJson` field to PendingUpload with @HiveField(20)
- [ ] Update constructor to include new field
- [ ] Update factory constructor
- [ ] Update copyWith method
- [ ] Add `proofManifest` getter (deserializes JSON)
- [ ] Add `hasProofMode` getter
- [ ] Regenerate Hive adapter: `flutter pub run build_runner build`
- [ ] **Test**: Write `test/models/pending_upload_proofmode_test.dart`
  - Test serialization/deserialization
  - Test getters with valid/invalid/null JSON
  - Test copyWith preserves ProofManifest
- [ ] **Validate**: Run `flutter test test/models/pending_upload_proofmode_test.dart`

### Step 1.2: Add ProofMode Helper Functions
- [ ] Create `lib/utils/proofmode_publishing_helpers.dart`
- [ ] Implement `getVerificationLevel(ProofManifest)` function
- [ ] Implement `createProofManifestTag(ProofManifest)` function
- [ ] Implement `createDeviceAttestationTag(ProofManifest)` function
- [ ] Implement `createPgpFingerprintTag(ProofManifest)` function
- [ ] **Test**: Write `test/utils/proofmode_publishing_helpers_test.dart`
  - Test all 4 verification levels
  - Test tag creation with real ProofManifest objects
  - Test null safety for optional fields
- [ ] **Validate**: Run `flutter test test/utils/proofmode_publishing_helpers_test.dart`

---

## Sprint 2: Recording Integration

### Step 2.1: Wire ProofModeSessionService into VineRecordingController
- [ ] Add `_proofModeSession` field to VineRecordingController
- [ ] Add `_currentProofSessionId` tracking variable
- [ ] Add `proofModeSession` to constructor
- [ ] Modify `startRecording()` to start ProofMode session on first segment
- [ ] Modify `stopRecording()` to pause ProofMode segment
- [ ] Modify `finishRecording()` to finalize session and return `(File?, ProofManifest?)`
- [ ] Add SHA256 hash calculation of final video before finalizing
- [ ] **Test**: Write `test/integration/proofmode_recording_integration_test.dart`
  - Test session lifecycle: start → pause → resume → finalize
  - Test with ProofMode enabled
  - Test with ProofMode disabled (null service)
  - Mock ProofModeSessionService to verify method calls
- [ ] **Validate**: Run `flutter test test/integration/proofmode_recording_integration_test.dart`

### Step 2.3: Update VineRecordingProvider
- [ ] Add `proofManifest` field to RecordingState
- [ ] Modify `finishRecording()` to capture ProofManifest from controller
- [ ] Update state with ProofManifest after recording finishes
- [ ] **Test**: Write `test/providers/vine_recording_provider_proofmode_test.dart`
  - Test provider state includes ProofManifest
  - Test end-to-end recording → finish → state update
- [ ] **Validate**: Run `flutter test test/providers/vine_recording_provider_proofmode_test.dart`

---

## Sprint 3: Upload & Publishing Integration

### Step 3.1: Pass ProofManifest to Upload Manager
- [ ] Add `ProofManifest?` parameter to `UploadManager.startUpload()`
- [ ] Serialize ProofManifest to JSON when creating PendingUpload
- [ ] Pass ProofManifest from VinePreviewScreen → UploadManager
- [ ] Add error handling for serialization failures
- [ ] **Test**: Write `test/services/upload_manager_proofmode_test.dart`
  - Test PendingUpload created with ProofManifest JSON
  - Test upload persists manifest in Hive
  - Test serialization error handling
- [ ] **Validate**: Run `flutter test test/services/upload_manager_proofmode_test.dart`

### Step 4.1: Add ProofMode Tags to Nostr Events
- [ ] Import `proofmode_publishing_helpers.dart` in VideoEventPublisher
- [ ] Add conditional block in `publishDirectUpload()` to check `upload.hasProofMode`
- [ ] Generate `proof-verification-level` tag
- [ ] Generate `proof-manifest` tag (compact JSON)
- [ ] Generate `proof-device-attestation` tag (if available)
- [ ] Generate `proof-pgp-fingerprint` tag (if available)
- [ ] Add logging for ProofMode tag inclusion
- [ ] **Test**: Write `test/services/video_event_publisher_proofmode_test.dart`
  - Test correct tags for each verification level
  - Test tags omitted when no ProofManifest
  - Test partial ProofMode (manifest without attestation)
  - Test integration: full publishing flow with ProofMode
- [ ] **Validate**: Run `flutter test test/services/video_event_publisher_proofmode_test.dart`

---

## Sprint 4: Comprehensive Testing

### Step 5.1: Integration Tests
- [ ] Create `test/integration/proofmode_end_to_end_test.dart`
- [ ] **Test Case 1**: Happy path - Record → Upload → Publish with ProofMode
  - Initialize all services with ProofMode enabled
  - Record 2-second video
  - Verify ProofManifest created with segments
  - Create upload with manifest
  - Publish and verify all 4 tags present
- [ ] **Test Case 2**: ProofMode disabled - Record → Upload → Publish without ProofMode
  - Initialize with null ProofModeSessionService
  - Record and publish normally
  - Verify no ProofMode tags in event
- [ ] **Test Case 3**: Partial ProofMode - verified_web level
  - Mock ProofManifest without device attestation
  - Verify correct verification level
  - Verify 3 tags present (no attestation tag)
- [ ] **Test Case 4**: Error recovery - ProofMode failure doesn't break recording
  - Mock ProofMode session to throw errors
  - Verify recording still completes
  - Verify upload/publish still works
- [ ] **Validate**: Run `flutter test test/integration/proofmode_end_to_end_test.dart`

### Step 5.2: Feature Flag Testing
- [ ] **Test Case 1**: ProofMode disabled globally (config flag)
  - Set `ProofModeConfig.isCaptureEnabled = false`
  - Verify session doesn't start
  - Verify no tags in published events
- [ ] **Test Case 2**: ProofMode enabled but session creation fails
  - Mock session creation to return null
  - Verify graceful degradation
- [ ] **Test Case 3**: ProofMode enabled but finalization fails
  - Mock finalization to return null
  - Verify upload continues without manifest
- [ ] **Validate**: Ensure all tests pass with ProofMode both enabled and disabled

### Step 5.3: Manual Verification Checklist
- [ ] Build app for iOS: `./build_native.sh ios debug`
- [ ] Build app for Android: `flutter build apk --debug`
- [ ] **Manual Test 1**: Record 6-second video on iOS
- [ ] **Manual Test 2**: Upload and publish video
- [ ] **Manual Test 3**: Use Nostr client to fetch published event
- [ ] **Manual Test 4**: Verify event contains all 4 ProofMode tags:
  - [ ] `proof-verification-level`
  - [ ] `proof-manifest`
  - [ ] `proof-device-attestation`
  - [ ] `proof-pgp-fingerprint`
- [ ] **Manual Test 5**: Verify badge displays correctly on video
- [ ] **Manual Test 6**: Disable ProofMode in settings
- [ ] **Manual Test 7**: Record and publish video without ProofMode
- [ ] **Manual Test 8**: Verify no ProofMode tags when disabled

---

## Sprint 5: Documentation & Performance

### Step 6.1: Update Documentation
- [ ] Create `docs/PROOFMODE_INTEGRATION.md` with:
  - [ ] Architecture overview section
  - [ ] Data flow diagram
  - [ ] Feature flag configuration guide
  - [ ] Testing guidelines
  - [ ] Troubleshooting section
- [ ] Review and update `docs/KIND_34236_SCHEMA.md` for accuracy
- [ ] Update `README.md` to mention ProofMode feature
- [ ] Add code comments to key integration points

### Step 6.2: Performance Testing
- [ ] **Benchmark 1**: Recording initialization time
  - Measure with ProofMode enabled
  - Measure with ProofMode disabled
  - Target: <50ms overhead
- [ ] **Benchmark 2**: Video processing time
  - Measure manifest generation overhead
  - Target: <200ms overhead
- [ ] **Benchmark 3**: Upload time
  - Measure manifest serialization overhead
  - Target: <100ms overhead
- [ ] **Benchmark 4**: Memory usage
  - Profile memory during recording
  - Verify no leaks during extended sessions
- [ ] Document performance metrics in `docs/PROOFMODE_PERFORMANCE.md`

### Step 6.3: Privacy & Security Review
- [ ] **Review 1**: PGP keys stored securely in device keychain
- [ ] **Review 2**: Device attestation tokens don't leak identifiers
- [ ] **Review 3**: Manifest data doesn't include PII
- [ ] **Review 4**: Feature can be disabled by users
- [ ] **Review 5**: Clear user communication about ProofMode
- [ ] Document security considerations in `docs/PROOFMODE_SECURITY.md`

---

## Final Checklist Before Merge

- [ ] All unit tests pass: `flutter test`
- [ ] All integration tests pass
- [ ] Static analysis clean: `flutter analyze`
- [ ] Code formatted: `dart format .`
- [ ] Manual testing complete on iOS and Android
- [ ] Documentation complete
- [ ] Performance benchmarks acceptable
- [ ] Security review complete
- [ ] Feature flag tested (enabled/disabled)
- [ ] Git commit with descriptive message
- [ ] PR created with link to this plan

---

## Future Enhancements (Post-MVP)

- [ ] **Step 2.2**: Implement frame capture during recording (deferred)
- [ ] **Step 3.2**: Send ProofMode metadata to Blossom (if servers support it)
- [ ] Sensor data capture (accelerometer/gyroscope)
- [ ] Optional GPS timestamping
- [ ] AI-based human presence detection
- [ ] Detailed verification UI for viewing ProofMode data

---

## Notes & Blockers

### Blockers
- None currently

### Technical Decisions
- **Frame Capture**: Deferred to post-MVP due to complexity
- **Blossom Integration**: Skipped for MVP - ProofMode data goes to Nostr only
- **Hive Field**: Using @HiveField(20) for ProofManifest to avoid conflicts

### Questions for Rabble
- Should we make ProofMode opt-in or opt-out by default?
- Should we display ProofMode status during recording (UI indicator)?
- Should we add a settings screen to view/manage ProofMode keys?
