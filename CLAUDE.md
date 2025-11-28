# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**diVine** (OpenVine) is a decentralized Vine-like short-form video sharing app built on the Nostr protocol. The project consists of:
- **Flutter Mobile App** (`mobile/`): Cross-platform client for iOS, Android, macOS, and Windows
- **Crawler** (`crawler/`): Content crawler utilities
- **Website** (`website/`): Separate React app for divine.video (not built from this repo)

## Build & Development Commands

```bash
# Primary Development (run from /mobile directory)
./run_dev.sh macos debug           # Primary dev platform - macOS desktop
./run_dev.sh ios debug             # iOS simulator
./run_dev.sh android debug         # Android emulator/device
./run_dev.sh windows debug         # Windows desktop

# Testing
flutter test                       # Run all unit tests
flutter test test/path/to_test.dart  # Run single test file
flutter analyze                    # Static analysis (REQUIRED after code changes)

# Native builds (use instead of direct flutter build for iOS/macOS)
./build_native.sh ios debug        # iOS with CocoaPods sync
./build_native.sh macos debug      # macOS with CocoaPods sync
./build_native.sh ios release      # iOS release
./build_testflight.sh              # TestFlight build

# Code generation (after modifying models/providers)
dart run build_runner build --delete-conflicting-outputs

# Golden tests (visual regression)
./scripts/golden.sh update         # Update golden images
./scripts/golden.sh verify         # Verify tests pass
```

## Architecture

### Technology Stack
- **Frontend**: Flutter/Dart with Riverpod 3 for state management
- **Protocol**: Nostr (decentralized social network protocol)
- **Media Upload**: Blossom servers (decentralized media hosting)
- **Local Storage**: Drift (SQLite) for events, Hive for preferences
- **Navigation**: GoRouter for declarative routing

### Embedded Nostr Relay Architecture

**Critical**: The app uses an embedded relay architecture - it does NOT connect directly to external relays.

```
NostrService → ws://localhost:7447 → EmbeddedNostrRelay → External Relays
```

- `NostrService` connects ONLY to `ws://localhost:7447`
- `EmbeddedNostrRelay` runs inside the app as a local WebSocket server
- External relays (e.g., `wss://relay3.openvine.co`) are managed via `addExternalRelay()`
- The embedded relay handles caching, connection management, and event routing

### Video Feed Architecture (Riverpod-based)

```
VideoEventService (ChangeNotifier)
    → maintains _eventLists[SubscriptionType]
    → Riverpod providers watch service
    → UI rebuilds reactively via ref.watch()
```

Key providers:
- `homeFeedProvider`: Personalized feed (followed users only)
- `videoEventsProvider`: Discovery/explore feed (all public videos)
- Each subscription type maintains isolated event lists

### Directory Structure

```
mobile/lib/
├── config/          # App configuration constants
├── database/        # Drift database, DAOs, migrations
├── features/        # Feature modules (feature flags, startup)
├── models/          # Data models (with freezed/json_serializable)
├── providers/       # Riverpod providers (*.g.dart generated)
├── router/          # GoRouter navigation configuration
├── screens/         # Screen widgets
├── services/        # Business logic services
├── theme/           # VineTheme (dark mode only)
├── utils/           # Utilities and helpers
└── widgets/         # Reusable UI components
```

### Nostr Event Types (NIPs)
- **Kind 0**: User profiles (NIP-01)
- **Kind 3**: Contact lists (NIP-02)
- **Kind 6**: Reposts (NIP-18)
- **Kind 7**: Reactions (NIP-25)
- **Kind 34236**: Addressable short looping videos (NIP-71) - primary video content

## Code Standards

### File Headers
All code files must start with a 2-line comment:
```dart
// ABOUTME: Brief description of what this file does
// ABOUTME: Additional context about the file's purpose
```

### UI Requirements
- **DARK MODE ONLY**: Use `Colors.black`, `VineTheme.backgroundColor`, `VineTheme.vineGreen`
- **No Modals**: Prefer full-screen navigation over modal dialogs/sheets

### Critical Rules
- **NEVER truncate Nostr IDs** - always use full 64-character hex event IDs or npub/nsec formats
- **NEVER use `Future.delayed()`** for timing - use Completers, Streams, or callbacks
- **NEVER add timeout parameters** to test commands
- Match surrounding code style over external standards
- Run `flutter analyze` after every code change

### State Management (Riverpod 3)
```dart
// Provider with code generation
@riverpod
MyService myService(Ref ref) => MyService();

// UI watches and rebuilds automatically
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(myServiceProvider);
    // ...
  }
}
```

### Async Patterns
Use proper async patterns - never arbitrary delays:
```dart
// ✅ Correct: Use Completers
final completer = Completer<String>();
controller.onInitialized = () => completer.complete('ready');
return completer.future;

// ❌ Forbidden: Arbitrary delays
await Future.delayed(Duration(milliseconds: 500));
```

## Platform Targets

| Platform | Use Case |
|----------|----------|
| **macOS desktop** | Primary development platform |
| **iOS, Android** | Release targets |
| **Windows desktop** | Secondary target |
| **Web/Chrome** | NOT used - divine.video runs separate React app |

## Testing

This project follows TDD principles:
1. Write failing test first
2. Implement minimal code to pass
3. Run `flutter analyze`
4. Refactor while keeping tests green

Golden tests for visual regression:
```bash
./scripts/golden.sh update   # Generate/update golden images
./scripts/golden.sh verify   # Verify against golden images
```

## Key Services

| Service | Purpose |
|---------|---------|
| `NostrService` | Nostr protocol communication via embedded relay |
| `VideoEventService` | Video feed management with subscription types |
| `BlossomUploadService` | Decentralized media upload to Blossom servers |
| `EmbeddedNostrRelay` | Local relay with SQLite storage |
| `AuthService` | User authentication and key management |

## Documentation

- Architecture: `mobile/docs/NOSTR_RELAY_ARCHITECTURE.md`
- Event types: `mobile/docs/NOSTR_EVENT_TYPES.md`
- Golden testing: `mobile/docs/GOLDEN_TESTING_GUIDE.md`
- Detailed AI guidelines: `.claude/CLAUDE.md`, `.claude/FLUTTER.md`
