# Contributing to diVine

Thank you for your interest in contributing to diVine! This guide will help you get set up and building the app.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Building Divine](#building-divine)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Standards](#code-standards)
- [Submitting Changes](#submitting-changes)

## Prerequisites

### Required Software

**Mobile Development:**
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable - 3.8.0 or higher)
- [Dart SDK](https://dart.dev/get-dart) (comes with Flutter)
- **For iOS development**:
  - macOS with Xcode 14+
  - CocoaPods (`sudo gem install cocoapods`)
- **For Android development**:
  - Android Studio with Android SDK
  - Java Development Kit (JDK) 11+

**Backend Development:**
- [Node.js](https://nodejs.org/) (LTS version 18+)
- [npm](https://www.npmjs.com/) or [pnpm](https://pnpm.io/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/install-and-update/) for Cloudflare Workers

### Recommended Tools
- [VS Code](https://code.visualstudio.com/) with Flutter and Dart extensions
- [Android Studio](https://developer.android.com/studio) for Android development
- Git for version control

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/openvine.git
cd openvine
```

### 2. Install Flutter Dependencies

```bash
cd openvine/mobile
flutter pub get
```

### 3. Install Backend Dependencies (Optional)

```bash
cd ../backend
npm install
```

## Building Divine

### Development Builds

diVine supports multiple platforms. **macOS desktop is the primary development platform** for fast iteration.

#### macOS Desktop (Primary Development Platform)
```bash
cd mobile
flutter run -d macos
```

Or use the convenience script:
```bash
./run_dev.sh macos debug
```

#### iOS Simulator
```bash
cd mobile
flutter run -d iPhone  # or specific simulator name
```

Or use the convenience script:
```bash
./run_dev.sh ios debug
```

#### Android Emulator/Device
```bash
cd mobile
flutter run -d <device-id>
```

Or use the convenience script:
```bash
./run_dev.sh android debug
```

#### Windows Desktop
```bash
cd mobile
flutter run -d windows
```

### Production Builds

#### iOS Release

**Using Build Script (Recommended)**:
```bash
./build_native.sh ios release
```

**Manual Build**:
```bash
cd mobile
flutter build ios --release
```

**TestFlight Build**:
```bash
./build_testflight.sh
```

#### Android Release
```bash
cd mobile
flutter build appbundle --release  # For Google Play Store
flutter build apk --release         # For direct distribution
```

#### macOS Release
```bash
./build_native.sh macos release
```

#### Platform Availability
- ✅ **Primary Platforms**: iOS, Android
- ✅ **Secondary Platforms**: macOS, Windows desktop
- ❌ **Not for Release**: Web/Chrome build (divine.video uses a separate React app)

## Development Workflow

### Using the Embedded Relay

The embedded relay architecture is a key part of diVine's design:

```dart
// Import the embedded relay package
import 'package:flutter_embedded_nostr_relay/flutter_embedded_nostr_relay.dart';

// Initialize the embedded relay
final embeddedRelay = EmbeddedNostrRelay();
await embeddedRelay.initialize();

// Add external relays
await embeddedRelay.addExternalRelay('wss://relay3.openvine.co');
await embeddedRelay.addExternalRelay('wss://relay.damus.io');

// NostrService connects to ws://localhost:7447
// The embedded relay manages all external relay connections
```

**Key Architecture Points**:
- The embedded relay runs **inside** the Flutter app as a local WebSocket server (port 7447)
- `NostrService` connects to `ws://localhost:7447` (NOT directly to external relays)
- The embedded relay manages all external relay connections and caching
- See `docs/NOSTR_RELAY_ARCHITECTURE.md` for complete details

### Hot Reload

Flutter's hot reload works on all platforms during development:

```bash
# After making code changes, press 'r' in the terminal
r     # Hot reload
R     # Hot restart (full restart)
```

### Running Tests

```bash
cd mobile
flutter test                              # Run all unit tests
flutter test test/integration/            # Run integration tests
flutter test --coverage                   # Generate coverage report
```

### Code Analysis

```bash
cd mobile
flutter analyze                           # Run static analysis
dart format lib/ test/                    # Format code
```

## Testing

diVine follows **strict Test-Driven Development (TDD)** principles:

### Testing Requirements

1. **Write Tests First**: Always write failing tests before implementation
2. **Test Coverage**: Maintain ≥80% code coverage
3. **Test Types Required**:
   - Unit tests for all services and business logic
   - Widget tests for UI components
   - Integration tests for critical user flows
   - Golden tests for visual regression testing

### Running Golden Tests

Golden tests capture widget screenshots for visual regression testing:

```bash
# Update/generate golden images
./scripts/golden.sh update

# Verify golden tests pass
./scripts/golden.sh verify

# Show changes
./scripts/golden.sh diff
```

See `mobile/docs/GOLDEN_TESTING_GUIDE.md` for complete documentation.

## Code Standards

### General Principles

- **YAGNI**: Don't add features we don't need right now
- **Readability First**: Prefer simple, maintainable code over clever solutions
- **No Mocks in E2E Tests**: Always use real data and real APIs
- **No Arbitrary Delays**: Never use `Future.delayed()` - use proper async patterns (Completers, Streams, callbacks)

### Nostr ID Handling

**CRITICAL RULE**: NEVER truncate Nostr IDs anywhere in the codebase.

❌ **FORBIDDEN**:
```dart
eventId.substring(0, 8)
Log.info('Video: ${video.id.substring(0, 8)}')
```

✅ **REQUIRED**:
```dart
Log.info('Video: ${video.id}')  // Use full ID
// For UI display, use visual truncation with ellipsis, not string manipulation
```

### Code Quality Checklist

Before submitting any changes:

```bash
cd mobile
flutter test                    # All tests must pass
flutter analyze                 # Zero issues required
dart format lib/ test/          # Code must be formatted
```

### File Headers

All code files must start with a 2-line comment:

```dart
// ABOUTME: This file provides video playback functionality
// ABOUTME: Handles player state, controls, and buffering
```

### Naming Conventions

- **No Temporal Names**: Never use `New`, `Improved`, `Enhanced`, `V2`, `Updated`, etc.
- **Descriptive Names**: Use clear, descriptive names that explain the full scope
- **Generic Reusability**: Reusable components should have generic names

### State Management

- Uses **Riverpod** for state management
- Follow the provider pattern established in the codebase
- See existing providers in `mobile/lib/providers/` for examples

## Submitting Changes

### Before Submitting

1. **Run All Tests**: Ensure 100% of tests pass
2. **Check Analysis**: `flutter analyze` must report zero issues
3. **Format Code**: Run `dart format` on all modified files
4. **Update Tests**: Add/update tests for your changes
5. **Update Documentation**: Update relevant docs if needed

### Pull Request Process

1. **Fork** the repository
2. **Create a Feature Branch**: `git checkout -b feature/your-feature-name`
3. **Commit Changes**: Use clear, descriptive commit messages
4. **Write Tests**: Ensure comprehensive test coverage
5. **Run Quality Checks**: Tests, analysis, formatting
6. **Push to Your Fork**: `git push origin feature/your-feature-name`
7. **Open a Pull Request**: Provide a clear description of your changes

### Commit Message Format

```
type(scope): brief description

Detailed explanation of what changed and why.

- Bullet points for key changes
- Include any breaking changes
- Reference related issues (#123)
```

**Types**: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`

**Examples**:
```
feat(video): add automatic thumbnail generation
fix(relay): resolve connection timeout on slow networks
docs(contributing): add build instructions for Windows
test(upload): add integration tests for upload cancellation
```

## Common Issues

### "Package not found: flutter_embedded_nostr_relay"

**Cause**: Symlink is missing or broken
**Solution**:
```bash
# Verify symlink
ls -la ../flutter_embedded_nostr_relay

# Recreate if needed
cd ..
ln -s /path/to/flutter_embedded_nostr_relay flutter_embedded_nostr_relay
cd openvine/mobile
flutter pub get
```

### "Failed to connect to relay"

**Cause**: NostrService trying to connect to external relays directly
**Solution**: Ensure NostrService connects ONLY to `ws://localhost:7447`

### CocoaPods Sync Errors (iOS/macOS)

**Cause**: CocoaPods out of sync with Podfile.lock
**Solution**: Use the native build scripts which handle this automatically:
```bash
./build_native.sh ios debug
./build_native.sh macos debug
```

### Build Failures After Dependency Changes

**Solution**:
```bash
cd mobile
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## Development Tools

### Recommended VS Code Extensions

- **Flutter** (Dart-Code.flutter)
- **Dart** (Dart-Code.dart-code)
- **Flutter Riverpod Snippets**
- **Error Lens** (for inline error display)
- **GitLens** (for Git integration)

### Useful Flutter Commands

```bash
flutter doctor              # Check Flutter installation
flutter devices             # List connected devices
flutter logs                # View device logs
flutter clean               # Clean build cache
flutter pub upgrade         # Upgrade dependencies
flutter build --help        # Show all build options
```

## Getting Help

- **Documentation**: Check `docs/` directory for detailed guides
- **Architecture**: See `docs/NOSTR_RELAY_ARCHITECTURE.md` for relay architecture
- **Issues**: Open an issue on GitHub for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions

## License

By contributing to diVine, you agree that your contributions will be licensed under the Mozilla Public License 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
