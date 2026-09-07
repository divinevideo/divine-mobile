Status: Historical

> Historical note
> This captures the red phase of an obsolete video-system rebuild and does not describe the current test suite. It references the removed `VideoCacheService`; trust the current implementation and runnable tests.

# TDD Test Specifications for Video System Rebuild

## ✅ TDD Red Phase Complete

**Status**: All tests are properly failing as expected in TDD methodology. The "Red" phase is complete.

## 📋 Test Coverage Summary

### 1. Video Manager Interface Tests (`test/unit/services/video_manager_interface_test.dart`)
**Purpose**: Define the contract that any VideoManager implementation must follow

**Key Requirements Tested**:
- Single Source of Truth for video ordering
- Memory management with <500MB limit
- Video preloading around current index  
- Circuit breaker for failing videos
- State change notifications
- Concurrent operation handling
- Debug information tracking

**Critical Missing Components**:
- `IVideoManager` interface
- `VideoState` model
- `VideoManagerConfig` class
- `VideoManagerException` class
- `MockVideoManager` test helper

### 2. Integration Behavior Tests (`test/integration/video_system_behavior_test.dart`)
**Purpose**: Test complete video system flows and memory management

**Key Requirements Tested**:
- Memory usage under 500MB (current system uses 3GB+)
- Video controller disposal for distant videos
- Race condition prevention
- Error recovery without crashes
- Performance under load (1000+ videos)
- Network failure handling
- Complete Nostr event → UI display flow

**Critical Missing Components**:
- `VideoManagerService` implementation
- Memory tracking and cleanup logic
- Aggressive garbage collection
- Circuit breaker implementation

### 3. Widget Tests (`test/widget/screens/feed_screen_test.dart`)
**Purpose**: Test UI behavior and user interactions

**Key Requirements Tested**:
- PageView construction and scrolling
- Index bounds checking and rapid page changes
- Preloading triggers on scroll
- Video activation/deactivation lifecycle
- Error boundaries for individual videos
- Performance optimization (lazy loading)
- Accessibility support

**Critical Missing Components**:
- `FeedScreenV2` widget
- `VideoFeedItemV2` widget
- Mock dependencies (`mockito` package)
- UI state management integration

### 4. Video Feed Item Tests (`test/widget/widgets/video_feed_item_test.dart`)
**Purpose**: Test individual video component behavior

**Key Requirements Tested**:
- All video loading states (loading, ready, error, disposed)
- Controller lifecycle management
- Error display and retry functionality
- GIF vs video handling
- Accessibility features
- Performance optimizations

## 🏗️ Implementation Requirements

### Core Models Needed
```dart
// lib/models/video_state.dart
enum VideoLoadingState { notLoaded, loading, ready, failed, permanentlyFailed, disposed }

class VideoState {
  final VideoEvent event;
  final VideoLoadingState loadingState;
  final String? errorMessage;
  final int retryCount;
  final bool canRetry;
  // ... additional fields
}
```

### Core Services Needed
```dart
// lib/services/video_manager_interface.dart
abstract class IVideoManager {
  List<VideoEvent> get videos;
  List<VideoEvent> get readyVideos;
  VideoState? getVideoState(String videoId);
  VideoPlayerController? getController(String videoId);
  
  Future<void> addVideoEvent(VideoEvent event);
  Future<void> preloadVideo(String videoId);
  void preloadAroundIndex(int currentIndex);
  void disposeVideo(String videoId);
  
  Stream<void> get stateChanges;
  Map<String, dynamic> getDebugInfo();
  void dispose();
}

// lib/services/video_manager_service.dart - Main implementation
```

### Critical Performance Requirements
- **Memory Limit**: <500MB total (max 15 controllers × 30MB each)
- **Current Problem**: 3GB+ usage (100+ controllers × 30MB each)
- **Controller Lifecycle**: Dispose videos >3 positions from current view
- **Preloading Strategy**: Current + 3 ahead, 1 behind
- **Race Condition Prevention**: No "VideoPlayerController was disposed" crashes

### Error Handling Requirements
- Circuit breaker for videos that fail 3+ times
- Graceful network failure recovery
- Invalid URL validation
- Controller initialization timeouts
- Memory pressure handling

## 🔄 Next Steps (Green Phase)

1. **Week 1**: Implement core VideoManager and VideoState
2. **Week 2**: Add memory management and controller lifecycle
3. **Week 3**: Implement error handling and circuit breaker
4. **Week 4**: Create UI components (FeedScreenV2, VideoFeedItemV2)
5. **Week 5**: Integration testing and performance optimization

## 🎯 Success Criteria

All tests in this specification must pass:
- ✅ **Memory Usage**: <500MB with 100+ videos loaded
- ✅ **Race Conditions**: Zero "disposed controller" crashes
- ✅ **Performance**: >95% video load success rate
- ✅ **UI Responsiveness**: Smooth scrolling with preloading
- ✅ **Error Recovery**: Graceful handling of network/format failures

## 📝 Notes for Implementation Teams

- **MockVideoManager**: Create in `test/mocks/mock_video_manager.dart`
- **Test Helpers**: Located in `test/helpers/test_helpers.dart`
- **Package Dependencies**: Add `mockito` to `dev_dependencies`
- **Current System**: Dual list architecture in `video_event_service.dart` and `video_cache_service.dart` causes index mismatches

---

**VidTesterPro** - TDD Video System Test Specification Complete
**Issue**: #82 Core Behavior Test Specification  
**Phase**: Red ✅ | Green 🔄 | Refactor ⏳
