# Screens by Architecture

This document categorizes all screens based on whether they use the AppShell (with bottom navigation, header, and back button) or render as full-screen without the shell.

## Screens Using AppShell

These routes are wrapped in a `ShellRoute` and display with the AppShell widget (bottom nav, header, back button).

### Main Tabs

| Route | Screen | Description |
|-------|--------|-------------|
| `/home/:index` | `HomeScreenRouter` | Home feed |
| `/explore` | `ExploreScreen` | Explore grid |
| `/explore/:index` | `ExploreScreen` | Explore feed mode |
| `/notifications/:index` | `NotificationsScreen` | Notifications |
| `/profile/:npub` | `ProfileScreenRouter` | Profile grid |
| `/profile/:npub/:index` | `ProfileScreenRouter` | Profile feed mode |

### Sub-routes (within Shell)

| Route | Screen | Description |
|-------|--------|-------------|
| `/search` | `SearchScreenPure` | Search (empty) |
| `/search/:searchTerm` | `SearchScreenPure` | Search results grid |
| `/search/:searchTerm/:index` | `SearchScreenPure` | Search results feed |
| `/hashtag/:tag` | `HashtagScreenRouter` | Hashtag grid |
| `/hashtag/:tag/:index` | `HashtagScreenRouter` | Hashtag feed |

---

## Screens NOT Using AppShell

These routes are NOT wrapped in the ShellRoute and display without the AppShell (full screen, no bottom navigation).

### Authentication & Onboarding

| Route | Screen |
|-------|--------|
| `/welcome` | `WelcomeScreen` |
| `/import-key` | `KeyImportScreen` |
| `/setup-profile` | `ProfileSetupScreen` |

### Settings

| Route | Screen |
|-------|--------|
| `/settings` | `SettingsScreen` |
| `/edit-profile` | `ProfileSetupScreen` |
| `/relay-settings` | `RelaySettingsScreen` |
| `/blossom-settings` | `BlossomSettingsScreen` |
| `/notification-settings` | `NotificationSettingsScreen` |
| `/key-management` | `KeyManagementScreen` |
| `/relay-diagnostic` | `RelayDiagnosticScreen` |
| `/safety-settings` | `SafetySettingsScreen` |
| `/settings/privacy` | `PrivacySettingsScreen` |
| `/developer-options` | `DeveloperOptionsScreen` |

### Camera & Video

| Route | Screen |
|-------|--------|
| `/camera` | `UniversalCameraScreenPure` |
| `/clip-manager` | `ClipManagerScreen` |
| `/edit-video` | `VideoEditorScreen` |
| `/drafts`, `/clips` | `ClipLibraryScreen` |

### Social

| Route | Screen |
|-------|--------|
| `/followers/:pubkey` | `FollowersScreen` |
| `/following/:pubkey` | `FollowingScreen` |

### Deep Links

| Route | Screen |
|-------|--------|
| `/video/:id` | `VideoDetailScreen` |

---

## Architecture Notes

### Shell Route Configuration
- All tab routes (home, explore, notifications, profile) and their variants are children of a single `ShellRoute`
- Each tab maintains its own Navigator stack via navigator keys for per-tab state preservation
- The AppShell provides: AppBar with dynamic title, back/menu button, search and camera buttons, bottom navigation bar

### Non-Shell Routes
- Settings, authentication, camera, and editor screens are full-screen without bottom navigation
- These screens manage their own AppBar and navigation
- Deep-link targets are also non-shell for focused viewing

### Route Parameter Conventions
- `:index` - Video position in feed
- `:npub` - User's Nostr public key (npub format)
- `:tag` - Hashtag name
- `:searchTerm` - Search query
- `:pubkey` - User's public key (hex format)
- `:id` - Video/event ID
