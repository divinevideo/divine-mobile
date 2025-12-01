# Test Suite Documentation

ABOUTME: Test documentation explaining the comprehensive test suite for the Nostr SDK
ABOUTME: Describes test structure, what's covered, and how to run tests

This directory contains a comprehensive test suite for the Nostr SDK, created as part of validating the library exports and functionality.

## Test Structure

### Unit Tests (`test/unit/`)

#### `exports_test.dart`
Validates that all exported classes and constants are properly accessible from the main package:
- Core classes (Nostr, Event, EventKind, Subscription)
- Signing implementations (NostrSigner, LocalNostrSigner, PubkeyOnlyNostrSigner)
- Relay classes (Relay, RelayPool, RelayStatus, RelayType, EventFilter)
- NIP implementations (Contact, ContactList, Nip19, GroupIdentifier)
- Utility classes (StringUtil, DateFormatUtil, UploadUtil)
- Constants validation

#### `event_test.dart`
Tests core Event functionality:
- Event creation with valid parameters
- Custom timestamps
- Tag handling
- Deterministic ID generation
- Event validation (before/after signing)
- JSON serialization/deserialization
- Event equality comparison
- Invalid parameter handling
- Proof-of-work functionality

**Bug Found & Fixed**: The `Event.isSigned` property was attempting to verify empty signatures, causing crashes. Fixed to check for empty signature first.

#### `local_signer_test.dart`
Tests LocalNostrSigner functionality:
- Key pair generation using `generatePrivateKey()`
- Event signing with proper signature validation
- NIP-04 encryption/decryption
- NIP-44 encryption/decryption
- Key consistency validation
- Signature uniqueness
- Graceful method handling

#### `nip19_test.dart`
Tests NIP-19 bech32 encoding/decoding:
- Public key to npub encoding/decoding
- Private key to nsec encoding/decoding  
- Event ID to note encoding/decoding
- Simple display format generation
- Type validation (isPubkey, isPrivateKey, isNoteId)
- Round-trip data integrity
- Malformed input handling
- Bech32 string validation

## Test Results

All tests are currently passing:
- **41 total tests** across 4 test files
- **100% export validation** - all major classes accessible
- **Core functionality verified** - Event creation, signing, encoding work correctly
- **Bug fixes included** - Found and fixed `Event.isSigned` crash bug

## Running Tests

### Run All Tests
```bash
flutter test test/unit/
```

### Run Individual Test Files
```bash
flutter test test/unit/exports_test.dart
flutter test test/unit/event_test.dart  
flutter test test/unit/local_signer_test.dart
flutter test test/unit/nip19_test.dart
```

### Run With Verbose Output
```bash
flutter test test/unit/ --reporter expanded
```

## Test-Driven Export Validation

This test suite was created using a **test-driven approach** to validate library exports:

1. **Export Validation**: First tested that all exported classes are importable
2. **Functionality Testing**: Then tested that the imported classes actually work
3. **Bug Discovery**: Found and fixed bugs during testing (e.g., `Event.isSigned`)
4. **Iterative Improvement**: Fixed issues and re-ran tests until all passed

## Coverage Areas

### ✅ Currently Tested
- Package exports and imports
- Event creation, validation, and signing
- Local signing with key generation
- NIP-19 bech32 encoding/decoding
- Basic cryptographic operations

### 🚧 Future Test Areas
- Relay connection and messaging
- NIP-02 contact list operations
- Full Nostr client integration tests
- NIP-29 group functionality
- File upload operations
- Error handling edge cases
- Performance testing

## Testing Philosophy

These tests follow the principle of **validating library exports as they are uncommented**. This ensures:

1. **No broken exports** - Every uncommented export is immediately tested
2. **Functional validation** - Classes don't just import, they actually work
3. **Regression prevention** - Changes that break functionality are caught immediately
4. **Documentation by example** - Tests serve as usage documentation

This approach has already proven valuable by discovering the major export issue where almost all functionality was commented out, and finding/fixing the `Event.isSigned` bug.