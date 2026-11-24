## Unreleased

### Removed

- **Relay-based Groups (NIP-29)**: the `NIP29` and `GroupIdentifier` helpers and the unexported group classes in `lib/nip29/`. Nothing in the app or its packages used them, and `NIP29.editStatus` sent kind 9006, which NIP-29 dropped in 2024 in favour of kind 9002 (`edit-metadata`) (#7772).

## 0.1.0

### 🎉 Initial Public Release

This is the first public release of the Nostr SDK for Flutter/Dart, extracted and significantly enhanced from the nostrmo application.

#### ✨ Features Added
- **Comprehensive NIP Support**: 21+ Nostr Implementation Possibilities implemented
- **Complete Event System**: Event creation, validation, signing, and proof-of-work
- **Multiple Signing Strategies**: Local, remote (NIP-46), pubkey-only, and Android signers
- **Advanced Relay Management**: Sophisticated pooling, connection management, and subscription handling
- **Encryption Support**: Both NIP-04 (deprecated) and NIP-44 (recommended) encryption
- **NIP-19 Bech32 Encoding**: Full support for npub, nsec, and note encoding/decoding
- **Contact Lists (NIP-02)**: Complete contact list management
- **Relay-based Groups (NIP-29)**: Group creation, management, and messaging
- **File Upload Support**: NIP-96, Blossom, and multiple service integrations
- **Lightning Integration**: Zaps, LNURL, and wallet connectivity
- **Local Storage**: SQLite-based caching and offline support
- **Cross-platform**: Android, iOS, Web, and Desktop support

#### 🔧 Technical Improvements
- **Fixed Export Issues**: All classes now properly exported and accessible
- **Comprehensive Testing**: 41+ tests covering core functionality
- **Bug Fixes**: Resolved Event.isSigned validation crash
- **Dependency Cleanup**: Replaced git dependencies with official pub.dev packages
- **Documentation**: Complete API reference and architecture documentation

#### 🛠 Breaking Changes
- This is the initial release, no breaking changes from previous versions

#### 📦 Dependencies
- Uses hosted cryptography packages instead of git dependencies
- Added missing transitive dependencies for pub.dev compatibility

#### 🧪 Testing
- Export validation tests
- Event creation and signing tests  
- NIP-19 encoding/decoding tests
- LocalNostrSigner functionality tests

## 0.0.1

* Internal development version (not published)
