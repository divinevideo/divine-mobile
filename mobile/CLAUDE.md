# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Reference

**For detailed AI assistant guidelines, see `.claude/CLAUDE.md` and `.claude/FLUTTER.md`.**

## Build & Test Commands

```bash
# Development (macOS is primary development platform)
./run_dev.sh macos debug           # Primary development - macOS desktop
./run_dev.sh ios debug             # iOS simulator
./run_dev.sh android debug         # Android emulator/device

# Testing
flutter test                       # Run all unit tests
flutter test test/path/to_test.dart  # Run single test file
flutter analyze                    # Static analysis (MANDATORY after code changes)

# Native builds (use these instead of direct flutter build for iOS/macOS)
./build_native.sh ios debug        # iOS with proper CocoaPods sync
./build_native.sh macos debug      # macOS with proper CocoaPods sync
./build_native.sh ios release      # iOS release build

# Code generation (after modifying models/providers with annotations)
dart run build_runner build --delete-conflicting-outputs

# Golden tests (visual regression)
./scripts/golden.sh update         # Update golden images
./scripts/golden.sh verify         # Verify golden tests pass
```

## Architecture Overview

**diVine** (OpenVine) is a decentralized Vine-like video sharing app powered by Nostr.

### Core Stack
- **Frontend**: Flutter/Dart with Riverpod 3 for state management
- **Protocol**: Nostr (decentralized social network)
- **Media Upload**: Blossom servers (decentralized media hosting)
- **Local Storage**: Drift (SQLite), Hive

### Key Architectural Patterns

**Embedded Nostr Relay Architecture**:
- App connects to local embedded relay at `ws://localhost:7447`
- `EmbeddedNostrRelay` manages external relay connections internally
- NostrService should NEVER connect directly to external relays

**Video Feed Architecture** (Riverpod-based reactive):
```
VideoEventService (ChangeNotifier)
    → maintains _eventLists[SubscriptionType]
    → providers watch service
    → UI rebuilds reactively
```
- `homeFeedProvider`: Personalized feed (followed users only)
- `videoEventsProvider`: Discovery/explore feed (all public videos)
- Each subscription type has isolated event list

**State Management**:
- Use `@riverpod` annotations with code generation
- Services extend `ChangeNotifier` and are wrapped in providers
- UI uses `ref.watch()` for reactive updates - never poll services

### Directory Structure

```
lib/
├── config/          # App configuration
├── database/        # Drift database, DAOs
├── features/        # Feature modules
├── models/          # Data models (with freezed/json_serializable)
├── providers/       # Riverpod providers
├── router/          # GoRouter navigation
├── screens/         # Screen widgets
├── services/        # Business logic services
├── state/           # State management
├── theme/           # VineTheme (dark mode only)
├── utils/           # Utilities
└── widgets/         # Reusable widgets
```

## Critical Project Rules

### UI Requirements
- **DARK MODE ONLY**: Use `Colors.black`, `VineTheme.backgroundColor`, `VineTheme.vineGreen`
- **No Modals**: Prefer full-screen navigation over modal dialogs/sheets

### Code Standards
- All code files MUST start with 2-line `ABOUTME:` comment
- **NEVER truncate Nostr IDs** - always use full 64-character hex IDs
- **NEVER use `Future.delayed()`** for timing - use proper async patterns (Completers, Streams)
- Match surrounding code style over external standards

### Testing (TDD Required)
- Write test BEFORE implementation
- Run `flutter analyze` after every code change
- Never add timeout parameters to test commands

### Nostr Event Types
- Kind 0: User profiles (NIP-01)
- Kind 3: Contact lists (NIP-02)
- Kind 6: Reposts (NIP-18)
- Kind 7: Reactions (NIP-25)
- Kind 34236: Addressable short videos (NIP-71)

## Platform Targets

- **Primary Development**: macOS desktop
- **Release Targets**: iOS, Android
- **Secondary**: Windows desktop
- **Not for release**: Web/Chrome (divine.video runs separate React app)
