# Dart Package Release Checklist

ABOUTME: Complete guide for preparing and releasing the Nostr SDK to pub.dev
ABOUTME: Covers all steps from package cleanup to publication and maintenance

## Overview

Dart packages are published to [pub.dev](https://pub.dev), the official package repository. Here's everything needed to release this Nostr SDK properly.

## Pre-Release Requirements

### 1. Package Metadata (`pubspec.yaml`)

The current `pubspec.yaml` needs significant updates:

```yaml
name: nostr_sdk
description: Comprehensive Flutter/Dart SDK for building Nostr applications with extensive NIP support
version: 0.1.0  # Follow semantic versioning
homepage: https://github.com/rabble/nostr_sdk
repository: https://github.com/rabble/nostr_sdk
issue_tracker: https://github.com/rabble/nostr_sdk/issues
documentation: https://github.com/rabble/nostr_sdk

environment:
  sdk: '>=3.4.1 <4.0.0'
  flutter: ">=1.17.0"

# Fix dependency issues (see below)
```

**Issues to Fix:**
- ❌ Description is generic
- ❌ Missing homepage/repository URLs  
- ❌ Version too low (0.0.1)
- ❌ Git dependency issue (cryptography_flutter)

### 2. Dependency Cleanup

**Critical Issue**: Git dependencies aren't allowed on pub.dev:

```yaml
# PROBLEM: This will prevent publication
cryptography_flutter:
  git:
    url: https://github.com/mvarendorff/cryptography
    ref: fix/compatibility-agp-8x
    path: cryptography_flutter
```

**Solutions:**
1. Use official published version if available
2. Fork and publish your own version
3. Replace with alternative package
4. Make it an optional dependency

### 3. Documentation Requirements

#### Required Files:
- ✅ `README.md` (we have excellent documentation)
- ✅ `CHANGELOG.md` (basic one exists)
- ❌ `LICENSE` (exists but need to verify)
- ✅ `API_REFERENCE.md` (comprehensive)
- ✅ `ARCHITECTURE.md` (detailed)

#### Example/Demo App:
```
example/
├── lib/
│   └── main.dart
├── pubspec.yaml
└── README.md
```

### 4. Code Quality

#### Run Analysis:
```bash
dart analyze --fatal-infos
```

#### Format Code:
```bash
dart format --set-exit-if-changed .
```

#### Dependency Validation:
```bash
dart pub deps --style=tree
dart pub downgrade  # Test minimum versions
```

## Release Process Steps

### Step 1: Fix Critical Issues

1. **Fix Git Dependency**:
   ```bash
   # Option 1: Try official version
   flutter pub add cryptography_flutter
   
   # Option 2: Make conditional
   # Add platform-specific implementations
   ```

2. **Update pubspec.yaml**:
   ```yaml
   name: nostr_sdk
   description: Comprehensive Flutter/Dart SDK for building Nostr applications. Supports 21+ NIPs including events, signing, encryption, relays, and file uploads.
   version: 0.1.0
   homepage: https://github.com/rabble/nostr_sdk
   repository: https://github.com/rabble/nostr_sdk
   
   # Add topics for discoverability
   topics:
     - nostr
     - decentralized
     - social
     - bitcoin
     - cryptography
     - nip
   ```

3. **License Verification**:
   ```bash
   # Check license compatibility
   cat LICENSE
   ```

### Step 2: Create Example App

```dart
// example/lib/main.dart
import 'package:flutter/material.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nostr SDK Example',
      home: NostrExample(),
    );
  }
}

class NostrExample extends StatefulWidget {
  @override
  _NostrExampleState createState() => _NostrExampleState();
}

class _NostrExampleState extends State<NostrExample> {
  late Nostr nostr;
  String? publicKey;
  List<Event> events = [];

  @override
  void initState() {
    super.initState();
    _initializeNostr();
  }

  Future<void> _initializeNostr() async {
    final privateKey = generatePrivateKey();
    final signer = LocalNostrSigner(privateKey);
    publicKey = await signer.getPublicKey();
    
    final eventFilters = [EventFilter(kinds: [EventKind.TEXT_NOTE])];
    nostr = Nostr(signer, publicKey!, eventFilters, (url) => Relay(url));
    
    await nostr.addRelay(Relay('wss://relay.damus.io'));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nostr SDK Example')),
      body: Column(
        children: [
          if (publicKey != null)
            Text('Public Key: ${Nip19.encodeSimplePubKey(publicKey!)}'),
          ElevatedButton(
            onPressed: _sendTestEvent,
            child: Text('Send Test Event'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return ListTile(
                  title: Text(event.content),
                  subtitle: Text(Nip19.encodeSimplePubKey(event.pubkey)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestEvent() async {
    final event = Event(
      publicKey!,
      EventKind.TEXT_NOTE,
      [],
      'Hello from Nostr SDK! ${DateTime.now()}',
    );
    
    final sent = await nostr.sendEvent(event);
    if (sent != null) {
      setState(() {
        events.insert(0, sent);
      });
    }
  }
}
```

### Step 3: Quality Assurance

```bash
# Run all quality checks
dart analyze --fatal-infos
dart format --set-exit-if-changed .
flutter test
dart pub publish --dry-run
```

### Step 4: Version and Changelog

```markdown
# CHANGELOG.md

## 0.1.0

### Added
- Initial public release of Nostr SDK
- Support for 21+ Nostr Implementation Possibilities (NIPs)
- Complete event creation, signing, and validation
- Multiple signer implementations (local, remote, pubkey-only)
- Advanced relay pooling with connection management
- NIP-19 bech32 encoding/decoding
- NIP-02 contact list management
- NIP-04 and NIP-44 encryption support
- NIP-29 relay-based groups
- File upload support (NIP-96, Blossom)
- Lightning integration (Zaps, LNURL)
- Local SQLite storage for offline support
- Cross-platform support (Android, iOS, Web, Desktop)

### Fixed
- Export accessibility issues (all classes now properly exported)
- Event.isSigned validation bug
- Comprehensive test suite with 41+ tests

### Technical
- Extracted and refactored from nostrmo application
- Added comprehensive API documentation
- Created detailed architecture documentation
- Implemented test-driven export validation
```

## Publication Commands

### Dry Run (Test):
```bash
dart pub publish --dry-run
```

### Actual Publication:
```bash
dart pub publish
```

## Post-Release Tasks

### 1. Create GitHub Release
```bash
git tag v0.1.0
git push origin v0.1.0
```

### 2. Monitor Package
- Check pub.dev score: https://pub.dev/packages/nostr_sdk/score
- Monitor download stats
- Respond to issues

### 3. Maintenance
- Regular dependency updates
- Bug fixes and improvements
- New NIP implementations
- Documentation updates

## Package Scoring

pub.dev scores packages on:
- **Likes** (user engagement)
- **Popularity** (downloads)  
- **Pub Points** (quality metrics):
  - Follows Dart file conventions
  - Provides documentation
  - Supports multiple platforms
  - Has null safety
  - Uses analysis options

## Marketing/Promotion

1. **Announce on**:
   - Nostr protocol channels
   - Flutter/Dart communities
   - Bitcoin development forums
   - Your social channels

2. **Create**:
   - Blog post about the release
   - Demo video/tutorial
   - Integration examples

## Estimated Timeline

- **1-2 days**: Fix dependencies and metadata
- **1 day**: Create example app
- **1 day**: Quality assurance and testing
- **1 hour**: Publication process
- **Ongoing**: Maintenance and updates

## Critical Blockers

1. **Git Dependency**: Must resolve `cryptography_flutter` issue
2. **License Clarity**: Ensure license is compatible
3. **Platform Testing**: Test on all supported platforms

Would you like me to help tackle any of these specific areas first?