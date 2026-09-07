Status: Historical

> Historical note
> This guide describes an obsolete dual-video-system experiment and is not current testing guidance. `VideoCacheService` has been removed; trust the current implementation and testing documentation under `mobile/docs/`.

# Video System Testing Guide

## Current Status

Your app is running in **HYBRID MODE** - both the new VideoManagerService and legacy VideoCacheService are active simultaneously. This explains why performance feels better (you're getting benefits from both systems) but also why you're confused about which one is actually running.

## What's Currently Happening

1. **VideoFeedProvider** creates both systems:
   - `VideoCacheService` (legacy) - line 95 in main.dart
   - `VideoManagerService` (new) - line 60 in video_feed_provider.dart

2. **VideoFeedItem** receives controllers from BOTH:
   - `videoCacheService` parameter (legacy)
   - `videoController` parameter from VideoManager (new)

3. **Both systems may be processing the same videos** causing potential duplication of work

## How to Test Which System Performs Better

### Method 1: Debug Menu (Easiest)
1. Open the app feed screen
2. Tap the 3-dot menu (⋮) in top-right corner
3. You'll see these new options:
   - **Toggle Debug Overlay** - Shows real-time metrics
   - **🔀 Hybrid Mode (Current)** - Both systems active (current state)
   - **⚡ VideoManagerService** - New system only
   - **🏛️ VideoCacheService (Legacy)** - Old system only
   - **📊 Performance Report** - Print comparison to console

### Method 2: Triple-tap Gesture
1. Triple-tap the top-right 15% of the screen
2. This toggles the debug overlay on/off
3. The overlay shows real-time performance metrics

### Method 3: Run Test Script
```bash
cd mobile
dart test_video_systems.dart
```

## Debug Overlay Information

When enabled, the overlay shows:
- **Current System**: Which video system is active
- **Success Rate**: % of videos that load successfully 
- **Load Time**: Average time to load videos (milliseconds)
- **Memory**: Estimated memory usage
- **Videos**: Loaded/Total count

## Switching Between Systems

Use the debug menu to switch between:

1. **Hybrid** (current): Both systems active
   - Pros: Best compatibility, fallback options
   - Cons: Higher memory usage, potential conflicts

2. **VideoManagerService**: New system only
   - Pros: Better architecture, memory management, error handling
   - Cons: May have bugs still being worked out

3. **VideoCacheService**: Legacy system only  
   - Pros: Battle-tested, stable
   - Cons: Memory issues, poor error handling, dual-list architecture problems

## Expected Results

Based on the code analysis:

- **VideoManagerService** should provide:
  - Better memory management (<500MB target)
  - Circuit breaker error handling
  - Single source of truth (no dual-list issues)
  - Intelligent preloading

- **VideoCacheService** provides:
  - TikTok-style preloading
  - Progressive compatibility testing
  - Network-aware caching
  - Proven stability

## What the Performance Difference Tells Us

If you test and find:

- **VideoManager wins**: Complete the migration, remove VideoCacheService
- **VideoCache wins**: The new system needs more work before migration
- **Similar performance**: Either system works, choose based on maintainability

## Code Changes to Make Pure Systems

### For VideoManagerService Only:
```dart
// In VideoFeedItem, remove:
videoCacheService: provider.videoCacheService,

// Keep only:
videoController: provider.getController(videoEvent.id),
videoState: provider.getVideoState(videoEvent.id),
```

### For VideoCacheService Only:
```dart
// In VideoFeedProvider, remove VideoManager:
// Don't create VideoManagerService in constructor
// Remove _videoManager references
```

## Memory Usage Comparison

Run the debug overlay and compare memory usage:
- **Target**: <500MB total app memory
- **VideoManager**: ~20MB per cached video, max 15 videos = 300MB
- **VideoCache**: Similar per-video usage but less intelligent cleanup

The debug system will help you see which approach actually works better in practice versus theory.
