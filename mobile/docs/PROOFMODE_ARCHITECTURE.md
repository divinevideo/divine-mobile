Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# ProofMode Architecture

## Overview

ProofMode provides cryptographic verification for video authenticity in OpenVine. It creates tamper-evident proof manifests during video recording that can be verified by viewers to confirm video integrity.

## Core Principles

1. **Non-intrusive**: ProofMode operates transparently during normal video recording
2. **Progressive Rollout**: Feature flags control gradual activation of ProofMode phases
3. **Hardware-backed**: Uses iOS App Attest and Android Keystore hardware
   attestation
4. **Cryptographic Signing**: PGP signatures ensure manifest authenticity
5. **Frame-level Verification**: SHA256 hashes of video frames prove recording continuity

## Architecture Components

### 1. ProofModeSessionService

**Purpose**: Manages proof session lifecycle during video recording

**Key Responsibilities**:
- Start/stop proof sessions aligned with video recording
- Capture frame hashes during recording (SHA256)
- Track recording segments for pause/resume support
- Record user interactions (start/stop/touch events)
- Generate pause proofs during recording pauses
- Finalize session with complete ProofManifest

**Integration Point**: `VineRecordingController` calls ProofModeSessionService methods during recording lifecycle

**Example Flow**:
```dart
// Start recording
final sessionId = await proofModeSession.startSession();
await proofModeSession.startRecordingSegment();

// Capture frames during recording
await proofModeSession.captureFrame(frameData);

// Pause/resume
await proofModeSession.stopRecordingSegment();
await proofModeSession.startRecordingSegment(); // Resume

// Finish recording
await proofModeSession.stopRecordingSegment();
final manifest = await proofModeSession.finalizeSession(videoHash);
```

### 2. ProofModeKeyService

**Purpose**: Manages PGP keypairs for signing proof manifests

**Key Responsibilities**:
- Generate PGP keypairs (RSA 2048-bit)
- Store keys securely using SecureKeyStorage
- Sign proof manifests with PGP private key
- Verify PGP signatures
- Export public keys for verification

**Key Storage**: Uses `SecureKeyStorage` with platform-specific secure storage:
- iOS: Keychain
- Android: EncryptedSharedPreferences
- Other platforms: SharedPreferences (fallback)

**Example Usage**:
```dart
// Generate keypair (done once)
await keyService.generateKeys('user@example.com', 'User Name');

// Sign manifest
final signature = await keyService.signData(manifestJson);

// Verify signature
final isValid = await keyService.verifySignature(
  manifestJson,
  signature.signature,
  signature.publicKeyFingerprint,
);
```

### 3. ProofModeAttestationService

**Purpose**: Generates hardware-backed device attestation tokens

**Platform-specific Implementation**:

**iOS (App Attest)**:
- Uses the first-party `divine_device_attestation` workspace package via
  `IosDeviceAttestationService`
- Generates hardware-backed attestation tokens
- Runs at publish time, not during proof generation: the account the proof is
  published under is not fixed until the event is signed
- Signs a challenge over both the media proof hash and the event pubkey, and
  uses a key scoped to that account — see
  [NOSTR_VIDEO_EVENTS.md](NOSTR_VIDEO_EVENTS.md#device_attestation-payload-ios)
- Always hardware-backed on iOS 14+

**Android (hardware key attestation)**:
- Uses the app's native `HardwareAttestationNotarizationProvider`
- Generates an Android Keystore key with the proof nonce as its attestation
  challenge
- Returns the hardware-backed certificate chain on supported physical devices

**Fallback**:
- Generates software-based attestation for unsupported platforms
- Marked as `isHardwareBacked: false`

**Example Usage**:
```dart
// Initialize service
await attestationService.initialize();

// Generate attestation for challenge
final attestation = await attestationService.generateAttestation(challengeNonce);

// Check hardware attestation availability
final isHardwareBacked = await attestationService.isHardwareAttestationAvailable();
```

### 4. ProofModeConfig

**Purpose**: Centralized feature flag management for ProofMode rollout

**Configuration Flags**:
- `isDevelopmentEnabled`: Dev/testing mode
- `isCryptoEnabled`: PGP key generation
- `isCaptureEnabled`: Frame capture during recording
- `isPublishEnabled`: Publishing proofs to Nostr
- `isVerifyEnabled`: Verification services
- `isUIEnabled`: UI badges and verification displays
- `isProductionEnabled`: Full production rollout

**Example Usage**:
```dart
// Check if ProofMode is enabled
if (await ProofModeConfig.isCaptureEnabled) {
  await proofModeSession.startSession();
}

// Get current capabilities
final capabilities = await ProofModeConfig.getCapabilities();
print('ProofMode enabled features: $capabilities');
```

### 5. NostrEncoding

**Purpose**: Nostr key encoding/decoding utilities

**Key Operations**:
- Encode/decode public keys (hex ↔ npub)
- Encode/decode private keys (hex ↔ nsec)
- Derive public key from private key (secp256k1)
- Validate hex/npub/nsec format
- Generate secure random private keys

**Implementation**: Thin wrapper around `nostr_sdk`:
- `Nip19` class for bech32 encoding/decoding (NIP-19 standard)
- `nostr_keys.getPublicKey()` for secp256k1 derivation
- `nostr_keys.generatePrivateKey()` for secure key generation

**Example Usage**:
```dart
// Generate keypair
final privateKey = NostrEncoding.generatePrivateKey();
final publicKey = NostrEncoding.derivePublicKey(privateKey);

// Encode to bech32
final npub = NostrEncoding.encodePublicKey(publicKey);
final nsec = NostrEncoding.encodePrivateKey(privateKey);

// Decode from bech32
final hexPubkey = NostrEncoding.decodePublicKey(npub);
final hexPrivkey = NostrEncoding.decodePrivateKey(nsec);
```

### 6. SecureKeyContainer

**Purpose**: Memory-safe container for cryptographic private keys

**Security Features**:
- Automatic memory wiping on disposal
- Private key never exposed except via controlled access
- Throws exception if accessed after disposal
- Logs security events

**Example Usage**:
```dart
// Create from private key
final container = SecureKeyContainer.fromHex(privateKeyHex);

// Access public key (safe, no memory leak)
final publicKey = container.publicKeyHex;
final npub = container.npubPublicKey;

// Controlled private key access
container.withPrivateKey((privateKey) {
  // Use private key for signing
  final signature = sign(privateKey, data);
  return signature;
});

// Automatic cleanup
container.dispose(); // Wipes private key from memory
```

## Data Models

### ProofManifest

Complete proof package for a video recording session:

```dart
class ProofManifest {
  final String sessionId;                      // Unique session identifier
  final String challengeNonce;                 // Anti-replay challenge
  final DateTime vineSessionStart;             // Session start time
  final DateTime vineSessionEnd;               // Session end time
  final List<RecordingSegment> segments;       // Recording segments
  final List<PauseProof> pauseProofs;          // Pause period proofs
  final List<UserInteractionProof> interactions; // User touch events
  final String finalVideoHash;                 // SHA256 of final video
  final DeviceAttestation? deviceAttestation;  // Hardware attestation
  final ProofSignature? pgpSignature;          // PGP signature

  Duration get totalDuration;      // Total session time
  Duration get recordingDuration;  // Active recording time only
}
```

### RecordingSegment

Proof for continuous recording period (between pauses):

```dart
class RecordingSegment {
  final String segmentId;              // Segment identifier
  final DateTime startTime;            // Segment start
  final DateTime endTime;              // Segment end
  final List<String> frameHashes;      // SHA256 hashes of frames
  final List<DateTime>? frameTimestamps; // Frame capture times
  final Map<String, dynamic>? sensorData; // Sensor readings during segment

  Duration get duration; // Segment duration
}
```

### DeviceAttestation

Hardware-backed device verification:

```dart
class DeviceAttestation {
  final String token;              // Platform-specific attestation token
  final String platform;           // 'iOS', 'Android', or fallback
  final String deviceId;           // Device identifier
  final bool isHardwareBacked;     // True if hardware TEE used
  final DateTime createdAt;        // Attestation timestamp
  final String? challenge;         // Challenge nonce
  final Map<String, dynamic>? metadata; // Platform-specific data
}
```

### ProofSignature

PGP signature of proof manifest:

```dart
class ProofSignature {
  final String signature;              // PGP signature (ASCII armor)
  final String publicKeyFingerprint;   // PGP key fingerprint
  final DateTime signedAt;             // Signature timestamp
}
```

## Video Recording Integration

ProofMode integrates with `VineRecordingController`:

```dart
class VineRecordingController {
  final ProofModeSessionService? proofModeSession;

  Future<void> startRecording() async {
    // Start ProofMode session
    if (proofModeSession != null) {
      try {
        await proofModeSession.startSession();
        await proofModeSession.startRecordingSegment();
      } catch (e) {
        // Recording continues even if ProofMode fails
        Log.error('ProofMode session start failed: $e');
      }
    }

    // Start camera recording
    await _cameraService.startRecording();
  }

  Future<(File?, ProofManifest?)> finishRecording() async {
    // Stop recording
    await _cameraService.stopRecording();
    final videoFile = await _cameraService.finishRecording();

    // Generate ProofManifest
    ProofManifest? manifest;
    if (proofModeSession != null && videoFile != null) {
      final videoHash = await _calculateSHA256(videoFile);
      manifest = await proofModeSession.finalizeSession(videoHash);
    }

    return (videoFile, manifest);
  }
}
```

## Blossom Upload Integration

ProofMode manifest is uploaded alongside video to Blossom server:

> **The `X-ProofMode-*` headers are best-effort supplementary metadata, not the
> delivery mechanism for the manifest.** The canonical copy is the `proofmode`
> tag on the kind 34236 event, and the C2PA manifest is embedded in the video
> bytes themselves. No Blossom server currently reads these headers.
>
> They are also hard-capped: `BlossomUploadService.maxProofModeHeaderBytes`
> (8 KiB combined) governs what actually goes on the wire, cheapest-and-most-
> identifying first (`X-ProofMode-C2PA`, then `-Signature`, `-PublicKey`,
> `-Attestation`, `-Manifest`). `-Signature` and `-PublicKey` sit above the
> bulk headers because a signature without its key cannot be verified from
> headers alone. Measured against `media.divine.video`, combined request
> headers must stay under **128 KiB over HTTP/1.1** (past it the edge answers
> 502) and under **64 KiB over HTTP/2** (past it the connection is closed
> mid-request).
>
> An Android device attestation is the `X509Certificate.toString()` dump of
> the whole cert chain, so its size varies per device, and it used to travel
> twice — base64 in `X-ProofMode-Manifest` and again in
> `X-ProofMode-Attestation`. Past roughly **47.5 KB of raw attestation** the
> request crosses 128 KiB and the publish carrying it fails. A Pixel 8 Pro
> produced 53,826 bytes, shorter chains stayed under the line and uploaded
> fine, and iOS ships a compact integrity token that never came close.
>
> The attestation is a **per-capture** artifact, not a device constant:
> `readProofMetadata` reads `<proofDir>/<fileHash>.attest` for the file being
> proofed, and that file only exists for captures where attestation actually
> succeeded. One handset can therefore hold a clip with no attestation that
> publishes fine and a 53,826-byte one that does not — a device failing *some*
> publishes is the expected shape, not evidence against this diagnosis.
>
> Do not reintroduce an uncapped header here; put new proof payloads in a
> request body.

```dart
class BlossomUploadService {
  Future<UploadResult> uploadVideo({
    required File videoFile,
    required String nostrPubkey,
    String? proofManifestJson,
  }) async {
    final headers = <String, String>{
      'Authorization': nostrAuthToken,
      'Content-Type': 'video/mp4',
    };

    // Add ProofMode headers if manifest provided
    if (proofManifestJson != null) {
      final manifest = jsonDecode(proofManifestJson);

      // Base64 encode manifest
      headers['X-ProofMode-Manifest'] = base64Encode(
        utf8.encode(proofManifestJson),
      );

      // Add signature header
      if (manifest['pgpSignature'] != null) {
        headers['X-ProofMode-Signature'] = manifest['pgpSignature']['signature'];
      }

      // Add attestation header
      if (manifest['deviceAttestation'] != null) {
        headers['X-ProofMode-Attestation'] = manifest['deviceAttestation']['token'];
      }
    }

    // Upload video with headers
    final response = await dio.put(uploadUrl, data: videoData, options: Options(headers: headers));
    return UploadResult.fromResponse(response);
  }
}
```

## Progressive Rollout Phases

### Phase 1: Crypto Foundation (✅ Complete)
- PGP keypair generation
- Secure key storage
- Basic signature verification
- **Feature Flag**: `proofmode_crypto`

### Phase 2: Capture Integration (✅ Complete)
- Session lifecycle management
- Frame hash capture
- Device attestation
- Segment tracking
- **Feature Flag**: `proofmode_capture`

### Phase 3: Upload Integration (✅ Complete)
- ProofManifest serialization
- Blossom header integration
- Manifest signing
- **Feature Flag**: `proofmode_publish`

### Phase 4: Verification Services (Pending)
- Manifest verification API
- Signature validation
- Attestation verification
- **Feature Flag**: `proofmode_verify`

### Phase 5: UI Integration (Pending)
- Verification badges
- Proof detail viewers
- Trust indicators
- **Feature Flag**: `proofmode_ui`

### Phase 6: Production (Pending)
- Performance optimization
- Full security audit
- Documentation
- **Feature Flag**: `proofmode_production`

## Security Considerations

### Threat Model

**Protected Against**:
1. **Video Tampering**: Frame hashes detect alterations
2. **Time Manipulation**: Timestamps in signed manifest
3. **Device Spoofing**: Hardware attestation from TEE
4. **Replay Attacks**: Challenge nonces prevent reuse
5. **Signature Forgery**: PGP signatures with fingerprint verification

**Not Protected Against** (by design):
1. **Screen Recording**: ProofMode doesn't prevent screen recording
2. **Social Engineering**: User can choose not to enable ProofMode
3. **Stolen Keys**: If PGP keys are compromised, old proofs are invalid
4. **Camera Tampering**: Assumes camera hardware is trusted

### Key Management

**PGP Keys**:
- Generated once per user
- Stored in platform secure storage
- Never transmitted over network
- Public keys published to Nostr for verification
- Private keys wiped from memory after use

**Nostr Keys**:
- Used for signing Nostr events (not proof manifests)
- Managed by AuthService
- Integration point for ProofMode signing

### Privacy Considerations

**Data Collection**:
- Frame hashes: Cannot be reverse-engineered to video content
- Sensor data: Generic readings, no personal information
- Device attestation: Platform-specific device ID (not personally identifiable)
- User interactions: Touch coordinates relative to screen, no content

**Data Sharing**:
- ProofManifests are optional (user opt-in)
- Uploaded to user-chosen Blossom server
- Published to Nostr as Kind 34236 event
- Users control who can view proofs

## Testing

### Test Coverage

**Unit Tests**:
- `test/services/proofmode_key_service_test.dart`: Key generation, signing, verification
- `test/services/proofmode_attestation_config_test.dart`: Configuration management
- `test/utils/nostr_encoding_test.dart`: Encoding/decoding operations
- `test/utils/nostr_encoding_derive_pubkey_test.dart`: secp256k1 key derivation
- `test/utils/secure_key_container_refactor_test.dart`: Memory-safe key container

**Integration Tests**:
- `test/integration/proofmode_recording_integration_test.dart`: Full recording lifecycle
- `test/services/blossom_upload_proofmode_test.dart`: Upload with ProofMode headers

**Test Results**: 35/35 core ProofMode tests passing (as of Sprint 4 completion)

### Manual Testing

See `docs/MANUAL_TEST_VIDEO_UPLOAD.md` for manual upload verification procedures.

## Performance Characteristics

### Frame Capture Overhead

**Default Configuration**:
- Frame sample rate: 1 (capture every frame)
- Max frame hashes: 1000
- Hash algorithm: SHA256

**Overhead per Frame**:
- SHA256 computation: ~1ms per frame
- Memory: ~64 bytes per hash

**For 6-second video at 30fps**:
- Total frames: 180
- Frames captured: 180 (all frames within limit)
- Total overhead: ~180ms
- Memory: ~11KB

**Optimization Options**:
- Reduce sample rate (capture every 2nd or 3rd frame)
- Reduce max hashes (cap at 100-500 frames)
- Trade-off: Lower verification granularity vs. lower overhead

### Signing Overhead

**PGP Signature Generation**:
- RSA 2048-bit signing: ~50-100ms
- Done once at end of recording (not per-frame)
- Non-blocking (async)

**Device Attestation**:
- iOS App Attest: one network round trip to Apple on an account's first publish
  (`generateKey` + `attestKey`, both rate limited), then local
  `generateAssertion` per publish. The key id and attestation object are cached
  in `UserDefaults` per account, so switching accounts costs one more round trip
  rather than re-using another identity's key. A key that was generated but not
  attested — Apple throttled or offline — is recorded too, so the next publish
  retries `attestKey` on it instead of spending a second rate-limited
  generation. A wedged Apple callback is abandoned after 30s so it cannot stall
  later publishes.
- Android Keystore hardware attestation runs as part of native proof generation
- A failed attestation degrades the proof to no `device_attestation` field; it
  never discards the PGP signature or C2PA manifest.
- The published payload shape and the verifier rule that follows from the cache
  are documented in [NOSTR_VIDEO_EVENTS.md](NOSTR_VIDEO_EVENTS.md#device_attestation-payload-ios).

## Future Enhancements

### Planned Features

1. **C2PA Integration**: Standard media provenance metadata
2. **Multi-camera Support**: Coordinate proofs across multiple angles
3. **Live Streaming Proofs**: Real-time proof generation for live content
4. **Proof Revocation**: Ability to revoke compromised keys
5. **Proof Aggregation**: Combine multiple proofs for edited content
6. **Blockchain Anchoring**: Optional timestamp anchoring to Bitcoin/Ethereum

### Research Areas

1. **Zero-Knowledge Proofs**: Prove properties without revealing video
2. **Homomorphic Signatures**: Sign transformed video content
3. **Quantum-Resistant Crypto**: Future-proof signature algorithms
4. **Distributed Verification**: Decentralized proof verification network

## References

### Standards

- **NIP-19**: Nostr bech32 encoding (npub/nsec format)
- **NIP-71**: Video events (Kind 34236)
- **RFC 4880**: OpenPGP Message Format
- **FIPS 180-4**: SHA-256 Secure Hash Standard

### Specifications

- **iOS App Attest**: https://developer.apple.com/documentation/devicecheck/attestation
- **Android Key Attestation**: https://developer.android.com/privacy-and-security/security-key-attestation
- **Blossom Protocol**: https://github.com/hzrd149/blossom

### Related Documentation

- `docs/KIND_34236_SCHEMA.md`: Nostr video event schema
- `docs/CAMERA_ARCHITECTURE.md`: Camera integration architecture
- `docs/MANUAL_TEST_VIDEO_UPLOAD.md`: Manual testing procedures
- `lib/utils/nostr_encoding.dart`: Nostr key operations (ABOUTME comments)
- `lib/services/proofmode_session_service.dart`: Session management (ABOUTME comments)
