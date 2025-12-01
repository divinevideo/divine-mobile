# Trust & Safety Settings - Implementation Plan

## Overview

Add user-controlled Trust & Safety settings to diVine, allowing users to:
1. Verify their age (18+)
2. Choose how adult content is handled (auto show, ask each time, auto hide)
3. See which moderation providers are active (Divine only for v1)

## Design

### User Flow

1. User opens Settings → Safety & Privacy
2. New sections appear at top:
   - **Age Verification**: Toggle to confirm 18+
   - **Adult Content**: Radio selection for preference
   - **Moderation Providers**: Shows Divine (enabled, read-only for v1)

### Preference Behaviors

| Preference | Behavior |
|------------|----------|
| Always show | After 18+ verification, auto-send Blossom auth headers for age-gated content |
| Ask each time | Show click-through dialog for each age-gated video (default) |
| Never show | Filter age-gated content from feed entirely, never request auth |

## Implementation Tasks

### Task 1: Add AdultContentPreference enum and storage

**File**: `lib/services/age_verification_service.dart`

Add:
```dart
enum AdultContentPreference {
  alwaysShow,    // Auto-send auth after 18+ verified
  askEachTime,   // Click-through per video (default)
  neverShow,     // Filter from feed
}
```

Add storage:
- `_adultContentPreferenceKey = 'adult_content_preference'`
- `AdultContentPreference get adultContentPreference`
- `Future<void> setAdultContentPreference(AdultContentPreference)`

**Test file**: `test/services/age_verification_preference_test.dart`

### Task 2: Update MediaAuthInterceptor to respect preference

**File**: `lib/services/media_auth_interceptor.dart`

Modify `handleUnauthorizedMedia()`:
- If preference is `neverShow`: return null immediately (signal to hide)
- If preference is `alwaysShow` and 18+ verified: auto-create auth header
- If preference is `askEachTime`: show dialog (current behavior)

Add method:
- `bool shouldFilterContent()` - returns true if preference is `neverShow`

**Test file**: `test/services/media_auth_interceptor_preference_test.dart`

### Task 3: Build Safety Settings UI

**File**: `lib/screens/safety_settings_screen.dart`

Replace empty sections with:

1. **Age Verification section**:
   - CheckboxListTile: "I confirm I am 18 years or older"
   - Subtitle: "Required to view adult content"
   - On change: calls `ageVerificationService.setAgeVerified()`

2. **Adult Content section**:
   - RadioListTile group for 3 preferences
   - Disabled if not 18+ verified (with explanation)
   - On change: calls `ageVerificationService.setAdultContentPreference()`

3. **Moderation Providers section**:
   - **Divine** (always enabled):
     - CheckboxListTile with "Learn more" link → `divine.video/moderation`
     - Always checked, cannot be disabled
   - **People I follow**:
     - CheckboxListTile toggle
     - Subscribes to NIP-51 mute lists (kind 10000) from user's contact list
     - Uses existing `ContentModerationService._loadMuteListByPubkey()`
   - **Add custom labeler**:
     - Button/tile that opens input dialog
     - User enters npub or nip05 address
     - Resolves nip05 to pubkey if needed
     - Subscribes to that pubkey's mute list
   - **Added labelers list**:
     - Shows user-added custom labelers
     - Each with checkbox (enable/disable) and delete button

**Test file**: `test/screens/safety_settings_screen_test.dart`

### Task 3b: Add custom labeler input dialog

**File**: `lib/widgets/add_labeler_dialog.dart` (new)

Dialog with:
- Text field for npub or nip05 input
- Validation (must be valid npub or resolvable nip05)
- Loading state while resolving nip05
- Error handling for invalid input
- Returns pubkey on success

**Test file**: `test/widgets/add_labeler_dialog_test.dart`

### Task 4: Add provider for AgeVerificationService

**File**: `lib/providers/app_providers.dart`

Add:
```dart
final ageVerificationServiceProvider = Provider<AgeVerificationService>((ref) {
  return ref.read(serviceLocatorProvider).get<AgeVerificationService>();
});
```

Ensure service is registered in service locator during app initialization.

### Task 5: Wire up video feed filtering for "Never show"

**File**: `lib/services/video_event_service.dart` or feed providers

When preference is `neverShow`:
- Track which video IDs returned 401 from Blossom
- Filter those from feed display
- OR: Don't attempt to load thumbnails that require auth

## File Summary

| File | Action |
|------|--------|
| `lib/services/age_verification_service.dart` | Modify - add enum, preference storage |
| `lib/services/media_auth_interceptor.dart` | Modify - respect preference |
| `lib/screens/safety_settings_screen.dart` | Modify - add UI sections |
| `lib/widgets/add_labeler_dialog.dart` | Create - custom labeler input dialog |
| `lib/providers/app_providers.dart` | Modify - add provider |
| `test/services/age_verification_preference_test.dart` | Create - TDD tests |
| `test/services/media_auth_interceptor_preference_test.dart` | Create - TDD tests |
| `test/screens/safety_settings_screen_test.dart` | Create - UI tests |
| `test/widgets/add_labeler_dialog_test.dart` | Create - dialog tests |

## Moderation Provider Details

### Divine (default)
- Always enabled, cannot be disabled
- Link to `https://divine.video/moderation` for transparency
- Uses hardcoded Divine moderation pubkey (TBD)

### People I Follow
- Subscribes to NIP-51 kind 10000 (mute list) from each contact
- Uses existing `ContentModerationService.subscribeToMuteList("pubkey:<hex>")`
- Aggregates all mute entries from followed users

### Custom Labelers
- User enters npub or nip05 address
- Use `NIP05Service` to resolve nip05 → pubkey
- Use `nostr_sdk` to decode npub → pubkey
- Subscribe to their kind 10000 mute list
- Store list of custom labelers in SharedPreferences

## Verification

After implementation:
1. Run `flutter test` - all tests pass
2. Run `flutter analyze` - zero issues
3. Manual test on macOS:
   - Toggle 18+ verification
   - Change adult content preference
   - Verify behavior matches matrix for each preference
