Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This document describes an older ProofMode model and should not be used as the current launch or reviewer source of truth.

# ProofMode Implementation - Simplified Guardian Project Model

## Overview

Divine uses Guardian Project's battle-tested `libproofmode` native libraries (iOS and Android) for cryptographic proof generation. The ProofMode data is **much simpler** than the original NIP spec draft - it focuses on cryptographic verification rather than session tracking.

## What Guardian Project Provides

Guardian Project's `libproofmode` generates:

1. **Video Hash** - SHA256 hash of the video file
2. **Sensor Data CSV** - Device sensor readings at capture time (location, network, device info)
3. **PGP Signature** - OpenPGP signature of the video file
4. **Public Key** - PGP public key for signature verification
5. **Device Attestation** - Android Keystore hardware attestation during proof
   generation, plus iOS App Attest added at publish time

## Nostr Event Tags

ProofMode data publishes to Nostr as event tags:

```json
[
  ["proof-verification-level", "verified_mobile"],
  ["proofmode", "{\"videoHash\":\"abc123...\",\"sensorDataCsv\":\"timestamp,lat,lon...\",\"pgpSignature\":\"-----BEGIN PGP SIGNATURE-----...\"}"],
  ["proof-device-attestation", "attestation_token_here"],
  ["proof-pgp-fingerprint", "ABCD1234..."]
]
```

## Verification Levels

- **verified_mobile**: Has device attestation + PGP signature + sensor data
- **verified_web**: Has PGP signature + sensor data (no hardware attestation)
- **basic_proof**: Has sensor data but no signature
- **unverified**: No meaningful proof data

## What We DON'T Track

Unlike the original NIP draft, we do NOT track:
- ❌ Recording sessions
- ❌ Individual segments
- ❌ Frame-by-frame hashes
- ❌ User interactions
- ❌ Pause proofs
- ❌ Challenge nonces

**Why?** Guardian Project focuses on **file-level cryptographic proof** rather than session tracking. The video hash + signature proves the file hasn't been tampered with, which is the core value.

## Data Model

```dart
class NativeProofData {
  final String videoHash;           // Required: SHA256 of video
  final String? sensorDataCsv;      // Optional: Device sensors
  final String? pgpSignature;       // Optional: OpenPGP signature
  final String? publicKey;          // Optional: PGP public key
  final String? deviceAttestation;  // Optional: Android SafetyNet
  final String? timestamp;          // Optional: Proof generation time
}
```

## Implementation Flow

1. **Record video** → `VineRecordingController.finishRecording()`
2. **Generate proof** → `NativeProofModeService.generateProof(videoPath)`
   - iOS: Calls `LibProofMode` via platform channel
   - Android: Calls `org.witness:android-libproofmode` via platform channel
3. **Read proof metadata** → `NativeProofModeService.readProofMetadata(proofHash)`
   - Reads CSV sensor data from proof directory
   - Reads PGP signature (.asc file)
   - Reads public key
4. **Create draft** → `VineDraft.create(proofManifestJson: jsonEncode(nativeProof.toJson()))`
5. **Upload & publish** → `VideoEventPublisher.publishDirectUpload(upload)`
   - Adds `proof-verification-level` tag
   - Adds `proofmode` tag with JSON manifest
   - Adds optional attestation/fingerprint tags

## Guardian Project Proof Files

The native library stores proof data in separate files (sidecar approach):

**iOS** - Stored in `Documents/{videoHash}/`:
```
{videoHash}.csv         - Sensor data
{videoHash}.asc         - PGP signature
{videoHash}-pubkey.asc  - Public key
```

**Android** - Similar structure managed by ProofMode library.

## Current Status

✅ **Code**: Data flow works perfectly (draft → upload → publish)
✅ **Native**: iOS and Android platform channels implemented
❌ **Problem**: LibProofMode returns empty hash - need to debug WHY

When recording returns empty hash (`""`), we now fail loudly with error instead of publishing `"unverified"` events with empty data.

## Next Steps

1. Test on device to see iOS/Android logs
2. Debug why `mediaItem.mediaItemHash` is nil/empty
3. Verify LibProofMode is properly initialized
4. Check file permissions for proof storage directory
