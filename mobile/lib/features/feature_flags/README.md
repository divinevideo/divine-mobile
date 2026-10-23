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

Eligible feed playback attempts `https://media-b2.divine.video/{hash}` before
the normal MP4/HLS/original ladder. A typed HTTP 503 or connection failure can
fall back. A B2 404 may hide a moderation/deletion denial and stops the ladder;
401, 403, other 4xx, origin/configuration 5xx, and ambiguous errors also stop.
The native player preserves HTTP 503 separately; older native binaries that
only report a generic server error fail closed.

The feed bypasses its event-ID disk cache and disk prefetch for eligible
canary videos. Android also bypasses its native disk cache for the canary host.
Apple uses a temporary per-player download rather than a persistent native
cache. Logs distinguish `B2 canary attempt`,
`B2 canary result`, and `B2 canary fallback` with the selected URL. A successful
player open is not proof of a particular HTTP response header or a cold origin
read; use endpoint diagnostics when measuring those.

Turning the flag off rebuilds feed players on canonical sources for subsequent
playback and preserves existing canonical disk caches. No global purge is
needed. This local flag is not a remote kill switch; endpoint activation and
approved-public replication readiness remain separate operator steps.
