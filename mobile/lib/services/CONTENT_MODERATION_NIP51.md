# NIP-51 Mute List Subscription in Content Moderation Service

## Overview

The `ContentModerationService` now supports subscribing to external NIP-51 mute lists, enabling decentralized content filtering through user-controlled and community-curated blocklists.

## Features

- ✅ Subscribe to mute lists by pubkey
- ✅ Parse NIP-51 kind 10000 (mute list) events
- ✅ Support for multiple mute list types: pubkeys, events, keywords, hashtags
- ✅ Automatic content filtering based on subscribed lists
- ✅ Local and external list management

## Usage

### Initialization

```dart
final service = ContentModerationService(
  nostrService: nostrService,
  authService: authService,
  prefs: prefs,
);

await service.initialize();
```

### Subscribe to External Mute List

Subscribe to a user's mute list by their public key:

```dart
// Subscribe to a curator's mute list
await service.subscribeToMuteList('pubkey:<hex_pubkey>');
```

Example:

```dart
await service.subscribeToMuteList(
  'pubkey:3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d'
);
```

### Check Content Against Mute Lists

```dart
final result = service.checkContent(event);

if (result.shouldFilter) {
  // Content matched a mute list entry
  print('Content filtered: ${result.warningMessage}');
  print('Severity: ${result.severity}');
  print('Reasons: ${result.reasons}');
}
```

### Unsubscribe from Mute List

```dart
await service.unsubscribeFromMuteList('pubkey:<hex_pubkey>');
```

### Get Moderation Statistics

```dart
final stats = service.getModerationStats();
print('Total mute lists: ${stats['totalMuteLists']}');
print('Total entries: ${stats['totalEntries']}');
print('Pubkey blocks: ${stats['pubkeyBlocks']}');
print('Keyword mutes: ${stats['keywordMutes']}');
```

## NIP-51 Tag Types Supported

The service parses the following NIP-51 tag types from mute list events:

| Tag Type | Description | Internal Type | Default Severity |
|----------|-------------|---------------|------------------|
| `p` | Mute user by pubkey | `pubkey` | hide |
| `e` | Mute specific event | `event` | hide |
| `word` | Mute keyword/phrase | `keyword` | hide |
| `t` | Mute hashtag | `keyword` | hide |

## NIP-51 Event Structure

A NIP-51 kind 10000 (mute list) event looks like:

```json
{
  "kind": 10000,
  "content": "",
  "tags": [
    ["p", "<blocked_pubkey>", "Spam"],
    ["e", "<blocked_event_id>", "Harassment"],
    ["word", "badword", "Offensive language"],
    ["t", "spam", "Spam hashtag"]
  ]
}
```

## Multiple List Support

The service supports subscribing to multiple external mute lists simultaneously. All subscribed lists are checked when filtering content:

```dart
// Subscribe to multiple curated lists
await service.subscribeToMuteList('pubkey:<curator1>');
await service.subscribeToMuteList('pubkey:<curator2>');
await service.subscribeToMuteList('pubkey:<curator3>');

// Content is filtered if it matches ANY entry in ANY subscribed list
```

## Architecture

### NostrListServiceMixin Integration

The service uses `NostrListServiceMixin` for efficient event querying from the embedded relay, following the same pattern as `BookmarkService` and `MuteService`.

### Event Loading Flow

1. Query embedded relay for kind 10000 events by pubkey
2. Select most recent event (kind 10000 is replaceable)
3. Parse tags into `MuteListEntry` objects
4. Store in `_muteLists` map indexed by list ID
5. Apply filters during `checkContent()` calls

### List ID Format

External list subscriptions use the format: `pubkey:<hex_pubkey>`

Example: `pubkey:3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d`

## Configuration

### Settings

```dart
await service.updateSettings(
  enableDefaultModeration: true,    // Use built-in moderation
  enableCustomMuteLists: true,      // Use subscribed external lists
  showContentWarnings: true,        // Show warning UI
  autoHideLevel: ContentSeverity.hide,  // Auto-hide threshold
);
```

### Severity Levels

- `info` - Informational only
- `warning` - Show warning but allow viewing
- `hide` - Hide by default, show if requested
- `block` - Completely block content

## Future Enhancements

- [ ] Subscribe to mute lists by event ID
- [ ] Private mute list entries (NIP-44 encrypted)
- [ ] Automatic list updates via subscriptions
- [ ] List reputation/trust scoring
- [ ] User-selectable community lists
