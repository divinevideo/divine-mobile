# Feature Flags System

Status: Current
Validated against: feature flag package structure on 2026-03-19.

A comprehensive TDD-built feature flag system for Divine, providing build-time configuration, runtime management, and user override capabilities.

## Architecture

The feature flag system follows clean architecture principles with clear separation of concerns:

- **Models**: Core data structures (`FeatureFlag`, `FeatureFlagState`, `FlagMetadata`)
- **Services**: Business logic (`FeatureFlagService`, `BuildConfiguration`)
- **Providers**: Riverpod state management and dependency injection
- **Widgets**: UI components (`FeatureFlagWidget`, `FeatureFlagScreen`)

## Available Feature Flags

- `enhancedVideoPlayer` - Improved video playback engine with better performance
- `enhancedAnalytics` - Detailed usage tracking and insights
- `debugTools` - Developer debugging utilities and diagnostics

## Quick Start

### 1. Conditional UI Rendering

```dart
import 'package:openvine/features/feature_flags/widgets/feature_flag_widget.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';

FeatureFlagWidget(
  flag: FeatureFlag.enhancedAnalytics,
  disabled: const StandardCameraWidget(),
  child: const EnhancedCameraWidget(),
)
```

### 2. Programmatic Flag Checking

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNewCameraEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.enhancedAnalytics)
    );
    
    if (isNewCameraEnabled) {
      return const EnhancedCameraWidget();
    } else {
      return const StandardCameraWidget();
    }
  }
}
```

### 3. Settings Screen Integration

```dart
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';

// Navigate to feature flag settings
context.push(FeatureFlagScreen.path);
```

## Build Configuration

Feature flags have build-time defaults that can be configured per environment:

```dart
// In BuildConfiguration
bool getDefault(FeatureFlag flag) {
  switch (flag) {
    case FeatureFlag.debugTools:
      return kDebugMode; // Only enabled in debug builds
    case FeatureFlag.enhancedAnalytics:
      return false; // Disabled by default
    // ... other flags
  }
}
```

## State Management

The system uses Riverpod for reactive state management:

- **Service Provider**: `featureFlagServiceProvider` - Core service instance
- **State Provider**: `featureFlagStateProvider` - Complete flag state map
- **Individual Provider**: `isFeatureEnabledProvider(flag)` - Single flag state

## Persistence

- User overrides are automatically persisted to `SharedPreferences`
- Flags without user overrides use build-time defaults
- Reset functionality restores all flags to build defaults

## Error Handling

The service gracefully handles storage errors:
- Updates in-memory state even if persistence fails
- Logs errors for debugging
- Continues operation without crashing

## Testing

Comprehensive test coverage with 47 tests across:
- Unit tests for models, services, and providers
- Widget tests for UI components
- Integration tests for end-to-end workflows
- Error scenario testing

### Test Example

```dart
testWidgets('should show enhanced feature when flag enabled', (tester) async {
  final mockPrefs = MockSharedPreferences();
  when(mockPrefs.getBool('ff_enhancedAnalytics')).thenReturn(true);
  
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(mockPrefs),
      ],
      child: MyApp(),
    ),
  );
  
  expect(find.text('Enhanced Camera'), findsOneWidget);
});
```

## Best Practices

1. **Always provide fallbacks**: Use the `disabled` parameter in `FeatureFlagWidget`
2. **Use meaningful names**: Flag names should clearly indicate the feature
3. **Test both states**: Ensure your app works with flags enabled and disabled
4. **Consider performance**: Flag checks are fast but avoid excessive polling
5. **Document dependencies**: Note if features depend on other flags or services

## Implementation Details

Built following TDD methodology with strict red-green-refactor cycles, the system provides:

- Type-safe flag definitions with compile-time checking
- Immutable state management with copy-on-write semantics
- Reactive UI updates when flags change
- Comprehensive error handling and graceful degradation
- Clean separation of concerns with dependency injection

For detailed implementation information, see the individual component files in the `lib/features/feature_flags/` directory.

## B2 playback canary

`b2PlaybackCanary` is an internal per-device opt-in, always off by default.
Enable Developer Mode, then turn on **B2 Playback Canary** in Feature Flags.
Only bare 64-character content hashes on media.divine.video, cdn.divine.video,
or blossom.divine.video are eligible. Signed/query URLs, derivatives, and
third-party media keep their existing source selection. Signed Nostr events and
uploads are unchanged.

Eligible feed playback preserves the normal resolver/MP4/HLS/original order.
When that ladder reaches an eligible original, it attempts
`https://media-b2.divine.video/{hash}` before the canonical original. Optimized
derivatives remain on their existing canonical route until replicated support
is available; enabling this flag does not mean all playback uses B2. A typed HTTP 503 or connection failure can
fall back. A B2 404 may hide a moderation/deletion denial and stops the ladder;
401, 403, other 4xx, origin/configuration 5xx, and ambiguous errors also stop.
Because B2 sits later in the same ladder, a 401, 403 or other non-404 4xx from
a canonical rendition also stops it, where the flag-off ladder would try the
next rendition. The native player preserves HTTP 503 separately; older native
binaries that only report a generic server error fail closed.

The feed bypasses its event-ID disk cache only when the selected first source
is a B2 original. Canonical renditions retain disk playback and prefetch;
prefetch stops before a B2 original rather than caching its raw fallback. Android also bypasses its native disk cache for both B2 hosts.
Apple uses a temporary per-player download rather than a persistent native
cache. Logs distinguish `B2 canary attempt`,
`B2 canary result`, and `B2 canary fallback` with the selected URL. A successful
player open is not proof of a particular HTTP response header or a cold origin
read; use endpoint diagnostics when measuring those.

Turning the flag off rebuilds feed players on canonical sources for subsequent
playback and preserves existing canonical disk caches. No global purge is
needed. This local flag is not a remote kill switch; endpoint activation and
approved-public replication readiness remain separate operator steps.

For the debug-only allowlisted host override and an isolated native QA entry,
see [private B2 playback QA](../../../../docs/testing/b2-playback-qa.md).

### Bunny playback canary

`bunnyPlaybackCanary` is an internal, default-off device opt-in for the main
native video feed. Build the test app with
`--dart-define=BUNNY_PLAYBACK_PATHS=<comma-separated exact paths>` using only
currently verified paths from the CDN operator. Use `/{sha256}` for a raw
original or `/{sha256}/720p.mp4` for a rendition. Supply the leading slash and
the complete lowercase SHA-256. Keep real fixture lists out of Git, logs shared
outside the pilot, and release builds. A build without the list has no Bunny
candidates.

Enable **Bunny Playback Canary** under **Developer Options → Feature Flags**.
Use one CDN canary at a time. B2 takes precedence when both switches are on.
Trigger playback of an enrolled clip and check the Bunny attempt in the local
player logs. Confirm the app still uses the same rendition, then test a
controlled Bunny timeout or HTTP 503 to see the equivalent canonical source
attempted. A Bunny 401, 403, or 404 must stop playback. An authenticated
age-verification retry must open the canonical host and never send its viewer
authorization to Bunny. Turning the flag off rebuilds playback from canonical
sources without waiting for DNS.

### Server-selected Bunny playback

`bunnyPlayback` is an internal flag, off by default. Enable it per device in
Developer Mode, or use `--dart-define=FF_BUNNY_PLAYBACK=true` in a test build.
Android and iOS feeds query the canonical media service for each public parent;
the server controls readiness, market and cohort selection. This includes exact
original, 720p/480p MP4 and HLS master paths, without changing rendition order.
The existing `bunnyPlaybackCanary` additionally accepts those exact HLS master
and 480p paths through `BUNNY_PLAYBACK_PATHS` for isolated fixtures. B2 canary
selection takes precedence. Authenticated retries remain canonical.

Selection requests have a one-second deadline, at most eight concurrent parents,
256 cached parents and 30-second expiry. Transport/configuration failures keep
canonical playback. A policy denial remains terminal, including when event-key
video bytes are cached. Bunny network/timeout/503 failures can use the matching
canonical source; 401/403/404 and unknown failures stop. HLS children carry no viewer credentials. Android bypasses its app-owned
disk cache for every Bunny request. iOS HLS uses a direct AVURLAsset rather than
the progressive download cache; native streaming-cache behavior still needs
device validation.

Turning the flag off rebuilds live and queued sources and ignores late selection
responses. Disk prefetch is suspended while server selection is active. Uploads
continue through the canonical upload flow, and signed post URLs remain canonical;
a newly published video can select Bunny after server enrollment is verified.
Deploy the selection endpoint and verified publisher before testing this flag.
There is no visual change outside the developer flag entry.

## Song catalog

`songCatalog` is an internal prototype: it adds a Songs list to the editor's
sound picker, with the most played songs and a search by title or artist. The
songs come from the Apple Music API catalog and play as its previews.

The flag exists only in a build made with a MusicKit developer token; any
other build does not list it and ignores a stored value:

```bash
flutter run --dart-define=APPLE_MUSIC_DEVELOPER_TOKEN=<token> --dart-define=FF_SONG_CATALOG=true
```

Without `FF_SONG_CATALOG` the flag is off by default; enable Developer Mode,
then turn on **Songs (Apple Music previews)** in Feature Flags. The token is a
signed JWT that expires after at most six months, so a build stops listing
songs once its token does. Keep the token out of the repository.

A picked song is added like any provider sound: the editor trims it to the
video and renders it into the file. Its terms forbid derivatives, so a video
made with one never offers its audio or itself for reuse. Publishing still
posts the video publicly, with a sound credit that links to the song's page.
