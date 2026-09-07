Status: Historical

> Historical note
> This proposal predates the current application startup architecture and is not an implementation plan. It references removed services, including `SocialService`; trust the current startup code and `docs/ARCHITECTURE.md`.

# Startup Optimization Migration Guide

## Overview

This guide documents the migration from the current 60+ provider initialization in main.dart to an optimized progressive loading strategy that reduces startup time from 3.2s to under 1.6s.

## Current State

- **60+ providers** initialized synchronously in main.dart
- **3.2 second** startup time
- **Future.delayed** used for notification service on web
- All services initialized before UI is shown

## Target State

- **Progressive initialization** with phase-based loading
- **< 1.6 second** time to interactive UI
- Event-driven async patterns (no Future.delayed)
- Critical services only for initial UI

## Implementation Steps

### Step 1: Integrate Startup Coordinator

Replace the current `AppInitializer` with `OptimizedAppInitializer`:

```dart
// In main.dart
import 'package:openvine/features/app/startup/optimized_app_initializer.dart';

// Replace:
home: const ResponsiveWrapper(child: AppInitializer()),

// With:
home: const ResponsiveWrapper(child: OptimizedAppInitializer()),
```

### Step 2: Update Notification Service

Replace Future.delayed with proper async pattern:

```dart
// In provider setup, replace the notification service initialization
ChangeNotifierProxyProvider3<INostrService, UserProfileService, VideoEventService, NotificationServiceEnhanced>(
  create: (context) {
    final service = NotificationServiceEnhanced();
    
    // Use deferred initializer instead of Future.delayed
    DeferredNotificationInitializer.initialize(
      service: service,
      nostrService: context.read<INostrService>(),
      profileService: context.read<UserProfileService>(),
      videoService: context.read<VideoEventService>(),
      isWeb: kIsWeb,
    );
    
    return service;
  },
  update: (_, nostrService, profileService, videoService, previous) => 
    previous ?? NotificationServiceEnhanced(),
),
```

### Step 3: Categorize Services by Phase

#### Critical Services (Must init before UI)
- AuthService
- SecureKeyStorageService
- NostrService (basic connection)

#### Essential Services (For basic UI interaction)
- ConnectionStatusService
- VideoVisibilityManager
- SeenVideosService

#### Standard Services (Can load after UI visible)
- VideoEventService
- UserProfileService
- SocialService
- VideoManager
- UploadManager

#### Deferred Services (Load after app interactive)
- AnalyticsService
- NotificationService
- CurationService
- ContentReportingService
- ContentDeletionService
- AgeVerificationService

### Step 4: Profile and Monitor

Enable startup profiling in debug builds:

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kDebugMode) {
    StartupProfiler.instance.markAppStart();
  }
  
  // ... rest of initialization
}
```

### Step 5: Implement Progressive Provider Creation

Convert synchronous provider creation to lazy initialization:

```dart
// Instead of creating all providers at once:
ChangeNotifierProvider(create: (_) => HeavyService()),

// Use lazy initialization:
ChangeNotifierProvider(
  create: (_) => HeavyService(),
  lazy: true, // Only create when first accessed
),
```

## Migration Checklist

- [ ] Replace AppInitializer with OptimizedAppInitializer
- [ ] Update notification service to use DeferredNotificationInitializer
- [ ] Add startup profiling
- [ ] Categorize all services by startup phase
- [ ] Update provider registration in startup coordinator
- [ ] Test startup time on multiple devices
- [ ] Verify all features work with progressive loading
- [ ] Monitor startup metrics in production

## Performance Targets

| Metric | Before | After | Target |
|--------|--------|-------|---------|
| Time to first paint | 3.2s | 1.2s | < 1.6s |
| Time to interactive | 3.2s | 1.5s | < 2.0s |
| Critical services | 60+ | 3 | < 5 |
| Memory at startup | High | Lower | -30% |

## Rollback Plan

If issues arise, revert to synchronous initialization:
1. Replace OptimizedAppInitializer with AppInitializer
2. Remove startup coordinator integration
3. Restore original provider setup

## Testing

Run startup performance tests:

```bash
flutter test test/features/app/startup/
```

Profile actual startup time:

```bash
flutter run --profile --trace-startup
```

## Future Optimizations

1. **Module lazy loading** - Load feature modules on demand
2. **Service worker** - Pre-cache critical resources on web
3. **Splash screen** - Show branded splash during init
4. **Parallel initialization** - Initialize independent services concurrently
5. **State persistence** - Cache initialization state between sessions
