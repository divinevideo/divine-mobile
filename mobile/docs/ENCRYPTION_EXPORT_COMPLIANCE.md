# App Encryption Export Compliance

Status: Launch-critical
Validated against: `mobile/ios/Runner/Info.plist`, `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`, and current crypto-related dependencies on 2026-03-19.

## Submission Summary

- App name: `Divine`
- iOS bundle identifier: `co.openvine.app`
- Android application ID: `co.openvine.app`
- `ITSAppUsesNonExemptEncryption`: `false`

Divine uses publicly documented, standard cryptography for authentication, secure transport, secure local storage, and Nostr messaging features. It does not ship proprietary or custom cryptographic algorithms.

## Why The App Uses Encryption

Divine uses encryption for:

- HTTPS/TLS network transport
- Nostr event signing and identity keys
- encrypted Nostr messaging flows
- secure device storage of keys and credentials
- ProofMode and related authenticity features

These functions rely on standard, publicly available algorithms and libraries.

## Current Cryptography Categories

### Transport security

- TLS 1.2 / 1.3 over HTTPS
- standard exempt transport security

### Nostr identity and signing

- secp256k1-based key pairs and signatures
- standard public-key cryptography used by the Nostr ecosystem

### Encrypted messaging

- NIP-44 and legacy encrypted-message support via standard published algorithms

### Local secure storage

- iOS Keychain
- Android Keystore
- `flutter_secure_storage`

### Authenticity and proof features

- ProofMode-related signing and verification via standard open-source libraries

## Cryptographic Libraries

| Library | Version (pubspec) | Algorithms / Primitives | Purpose |
|---------|-------------------|-------------------------|---------|
| `nostr_sdk` | workspace (local) | secp256k1 ECDSA, secp256k1 ECDH, ChaCha20-Poly1305, HMAC-SHA256, HKDF-SHA256 | Nostr event signing, NIP-44 encryption, key derivation |
| `crypto` | ^3.0.6 | SHA-256, HMAC-SHA256 | Hashing, message authentication |
| `encrypt` | ^5.0.3 | AES-256-CBC (PKCS7) | Legacy NIP-04 encrypted direct messages |
| `dart_pg` / `openpgp` | ^3.0.0 | RSA, AES, SHA-256/512, CAST5, IDEA | ProofMode / C2PA authenticity signatures |
| `flutter_secure_storage` | ^9.2.4 | iOS Keychain (AES-256-GCM via Secure Enclave), Android Keystore (AES-256-GCM) | Secure local storage of private keys and tokens |
| `bech32` | ^0.2.2 | Bech32 encoding (no encryption) | Nostr npub/nsec address encoding |
| `c2pa_flutter` | workspace (local) | SHA-256, ECDSA (P-256) | Content authenticity manifests |

## NIP-44 and NIP-59 Encryption Details

### NIP-44 (Versioned Encrypted Payloads)

NIP-44 is the current Nostr encrypted messaging standard used by Divine. The encryption flow:

1. **Key agreement**: secp256k1 ECDH shared secret between sender and recipient
2. **Key derivation**: HKDF-SHA256 (RFC 5869) with conversation key as IKM
3. **Encryption**: ChaCha20-Poly1305 (RFC 8439) with a random 32-byte nonce
4. **Padding**: Messages are padded to power-of-2 lengths to prevent length-based analysis
5. **Encoding**: Version byte (0x02) || nonce || ciphertext || MAC, then base64

### NIP-59 (Gift Wrapping) — Multi-Layer Encryption

NIP-59 provides sender-anonymous encrypted messaging via three layers:

1. **Rumor** (inner event): Unsigned event with actual content, `created_at` randomized
2. **Seal** (middle layer): Rumor encrypted with NIP-44 between sender and recipient, signed by sender, `kind: 13`
3. **Gift wrap** (outer layer): Seal encrypted with NIP-44 using a random ephemeral key to recipient, signed by ephemeral key, `kind: 1059`

This ensures relays and observers see only the ephemeral key, not the sender identity. The recipient unwraps: decrypt outer (with own key + ephemeral pubkey) then decrypt inner (with own key + sender pubkey from seal).

### Legacy NIP-04 (Deprecated)

- AES-256-CBC with secp256k1 ECDH shared secret
- Retained for backward compatibility with older Nostr clients
- Divine prefers NIP-44 for all new encrypted messages

## Standards References

### IETF RFCs

| Standard | RFC | Usage in Divine |
|----------|-----|-----------------|
| ChaCha20-Poly1305 | RFC 8439 | NIP-44 message encryption |
| HKDF-SHA256 | RFC 5869 | NIP-44 key derivation from ECDH shared secret |
| TLS 1.2 | RFC 5246 | HTTPS transport (minimum supported) |
| TLS 1.3 | RFC 8446 | HTTPS transport (preferred) |
| OpenPGP | RFC 4880 | ProofMode / C2PA signing |

### NIST Standards

| Standard | Identifier | Usage in Divine |
|----------|------------|-----------------|
| AES | FIPS 197 | NIP-04 legacy messaging (AES-256-CBC), secure storage |
| SHA-256 | FIPS 180-4 | Hashing, HMAC, key derivation |

### SECG Standards

| Standard | Identifier | Usage in Divine |
|----------|------------|-----------------|
| secp256k1 | SEC 2 v2.0 | Nostr key pairs, event signing (ECDSA), ECDH key agreement |

## Export Control Classification

### United States (BIS/EAR)

- **ECCN**: 5D992.c — "Mass market" encryption software with symmetric key length ≤ 128 bits or publicly available source code
- **License Exception**: ENC (§ 740.17) — eligible because the app uses only standard, publicly available cryptographic algorithms and does not provide a cryptographic platform, SDK, or toolkit to third parties
- **Self-classification**: No CCATS filing required for mass-market software under ENC § 740.17(b)(1) when encryption is limited to standard functions (authentication, digital signatures, secure transport, secure storage)
- **Annual self-classification report**: Due to BIS by February 1 each year if distributing via app stores (per Supplement No. 8 to Part 742)

### European Union

- **EU Dual-Use Regulation** (Regulation 2021/821): Category 5, Part 2
- Mobile apps using standard publicly available encryption for authentication and secure transport are generally exempt under the "mass market" note (Note 3 to Category 5, Part 2)
- No individual export license required for intra-EU or standard commercial distribution

### France (ANSSI)

- Apps using only standard publicly available cryptography distributed through public app stores: **declaration not required** under current ANSSI guidance
- If the app were to add proprietary encryption or act as a cryptographic provider, a declaration to ANSSI would be required under Article 30 of Loi n° 2004-575 (LCEN)

## Current Dependency Record

Relevant current app-level dependencies include:

- `nostr_sdk`
- `crypto`
- `encrypt`
- `dart_pg` / `openpgp`
- `flutter_secure_storage`
- `bech32`
- `c2pa_flutter`
- `divine_device_attestation`

If the crypto dependency set changes, re-validate this document before submission.

## Submission Guidance

The current repo truth supports answering export-compliance questions as:

- the app uses encryption: `Yes`
- the app uses only exempt or standard publicly available encryption: `Yes`
- non-exempt encryption declaration required in the binary: `No`

That is why `ITSAppUsesNonExemptEncryption` remains `false`.

## Re-Validation Checklist

- [ ] `mobile/ios/Runner/Info.plist` still contains `ITSAppUsesNonExemptEncryption = false`
- [ ] the app still relies only on standard published crypto primitives
- [ ] no proprietary or custom encryption implementation has been introduced
- [ ] App Store Connect answers match this document

## Related Docs

- [docs/APP_STORE_REVIEW_DOSSIER.md](../../docs/APP_STORE_REVIEW_DOSSIER.md)
- [mobile/docs/APPLE_REVIEW_RESPONSE.md](APPLE_REVIEW_RESPONSE.md)
