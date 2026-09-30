# Settings Information Architecture

Status: Current
Validated against: `settings_screen.dart`, `settings_categories_screen.dart`, and `settings_routes.dart` on 2026-09-30.

Settings is organized around what the user is trying to do. The hub is a short list of categories; each category is its own screen that reuses the existing controls, so moving a control does not change the preference it stores.

## Settings Hub

Route: `SettingsScreen.path = /settings`

Authenticated users see the account header (with the account switcher when that experiment is on) and any urgent account prompts: secure-account, session-expired recovery, and account-status restrictions. Below that, the categories:

| Category | Route | Screen |
|---|---|---|
| Account | `/settings/account` | `SettingsScreen(accountOnly: true)` |
| What you see | `/settings/viewing` | `ViewingSettingsScreen` |
| Create & share | `/settings/creating` | `CreatingSettingsScreen` |
| Notifications | `/notification-settings` | `NotificationSettingsScreen` |
| Privacy & safety | `/settings/privacy` | `PrivacySettingsScreen` |
| App preferences | `/settings/app-preferences` | `AppPreferencesSettingsScreen` |
| Connections | `/settings/connections` | `ConnectionsSettingsScreen` |
| Help & About Divine | `/settings/help-about` | `HelpAboutSettingsScreen` |

The version tile at the foot of the hub still unlocks developer mode.

## Categories

### Account

- change email and password (Divine sign-in only)
- verification and supporter membership
- key management, NIP-05 address, move account, remove keys from device
- delete account

Signed-out users see a sign-in row instead.

### What you see

- content language, closed captions, square videos only, stats visibility
- content filters

### Create & share

- hold to record, music mode (iOS and Android), audio device (not Linux), audio sharing
- crossposting and Bluesky publishing, when eligible
- creator analytics, badges, and tips or monetization links when enabled
- account content labels

### Privacy & safety

- analytics consent
- Content & Safety (`/safety-settings`): age verification, Divine-hosted-only and verified-only filters, moderation providers, custom labelers, blocked users

### App preferences

- app language, appearance, storage
- experimental features, and developer options when developer mode is on

### Connections

- integrated apps (where the sandbox is supported) and integration permissions
- Nostr network settings (`/settings/connections/nostr`): relays, relay diagnostics, Blossom media servers, signature verification, client attribution

### Help & About Divine

- support center, share Divine, legal, app version

## Earlier routes

`/nostr-settings`, `/general-settings`, and `/content-preferences` still resolve for existing deep links. `/nostr-settings` shows the network settings plus the account actions; the Connections destination shows the network settings only.

## Automation anchors

E2E flows reach deeper rows through the category rows' semantic identifiers in `SemanticIds`: `settingsAccountRow`, `settingsAppPreferencesRow`, and `settingsConnectionsRow`. Keep those ids on the category rows when rows move between categories, and update `mobile/e2e/maestro/` in the same change.
