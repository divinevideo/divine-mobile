// ABOUTME: Simplified test infrastructure for pure Riverpod provider testing
// ABOUTME: Provides minimal container setup and testing utilities for TDD provider development

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// App lifecycle state enum (simplified version for testing)
enum AppLifecycleState { resumed, inactive, paused, detached, hidden }

/// Simple provider test harness for TDD development
///
/// This is a minimal setup focused on testing core state providers
/// without complex service dependencies.
class ProviderTestHarness {
  late ProviderContainer container;

  /// Test lifecycle state tracking (internal state for testing)
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  List<VideoEvent> _videoFeed = [];
  List<VideoEvent> _homeFeed = [];
  int _currentVideoIndex = -1;
  String? _currentVideoId;
  bool _isVideoPlaying = false;
  bool _isVideoReady = false;
  String? _errorMessage;

  /// Initialize the test environment
  void setUp() {
    // Create a simple provider container
    // We'll override specific providers as needed in each test
    container = ProviderContainer();

    Log.info(
      '🧪 ProviderTestHarness initialized',
      category: LogCategory.system,
    );
  }

  /// Clean up test environment
  void tearDown() {
    container.dispose();
    Log.info('🧪 ProviderTestHarness disposed', category: LogCategory.system);
  }

  // Test data manipulation methods

  /// Set app lifecycle state
  void setAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
  }

  /// Set video feed data
  void setVideoFeed(List<VideoEvent> videos) {
    _videoFeed = videos;
  }

  /// Set home feed data
  void setHomeFeed(List<VideoEvent> videos) {
    _homeFeed = videos;
  }

  /// Set current video index
  void setCurrentVideoIndex(int index) {
    _currentVideoIndex = index;
    if (index >= 0 && index < _videoFeed.length) {
      _currentVideoId = _videoFeed[index].id;
    } else {
      _currentVideoId = null;
    }
  }

  /// Set current video playing state
  void setVideoPlaying(bool isPlaying) {
    _isVideoPlaying = isPlaying;
  }

  /// Set current video ready state
  void setVideoReady(bool isReady) {
    _isVideoReady = isReady;
  }

  /// Set error state
  void setErrorMessage(String? error) {
    _errorMessage = error;
  }

  // Test helper methods for common scenarios

  /// Setup scenario: App starts with empty feeds
  void setupEmptyAppStart() {
    setAppLifecycleState(AppLifecycleState.resumed);
    setVideoFeed([]);
    setHomeFeed([]);
    setCurrentVideoIndex(-1);
    setVideoPlaying(false);
    setVideoReady(false);
    setErrorMessage(null);
  }

  /// Setup scenario: App starts with videos loaded
  void setupAppWithVideos(List<VideoEvent> videos) {
    setAppLifecycleState(AppLifecycleState.resumed);
    setVideoFeed(videos);
    setHomeFeed(videos.take(videos.length ~/ 2).toList());
    setCurrentVideoIndex(0);
    setVideoPlaying(false);
    setVideoReady(true);
    setErrorMessage(null);
  }

  /// Setup scenario: App goes to background
  void setupAppBackgrounded() {
    setAppLifecycleState(AppLifecycleState.paused);
    setVideoPlaying(false);
  }

  /// Setup scenario: Video playing normally
  void setupVideoPlaying(List<VideoEvent> videos, int index) {
    setAppLifecycleState(AppLifecycleState.resumed);
    setVideoFeed(videos);
    setCurrentVideoIndex(index);
    setVideoPlaying(true);
    setVideoReady(true);
    setErrorMessage(null);
  }

  /// Setup scenario: Video failed to load
  void setupVideoError(List<VideoEvent> videos, int index, String error) {
    setAppLifecycleState(AppLifecycleState.resumed);
    setVideoFeed(videos);
    setCurrentVideoIndex(index);
    setVideoPlaying(false);
    setVideoReady(false);
    setErrorMessage(error);
  }

  // Getter methods for accessing current state

  AppLifecycleState get currentAppLifecycleState => _appLifecycleState;
  List<VideoEvent> get currentVideoFeed => List.unmodifiable(_videoFeed);
  List<VideoEvent> get currentHomeFeed => List.unmodifiable(_homeFeed);
  int get currentVideoIndex => _currentVideoIndex;
  String? get currentVideoId => _currentVideoId;
  bool get isVideoPlaying => _isVideoPlaying;
  bool get isVideoReady => _isVideoReady;
  String? get errorMessage => _errorMessage;
}

/// Test data creation helpers

class TestDataBuilder {
  /// Create mock videos for testing
  static List<VideoEvent> createMockVideos(int count) {
    return List.generate(count, (index) {
      final now = DateTime.now();
      return VideoEvent(
        id: 'test_video_$index',
        pubkey: 'test_pubkey_$index',
        createdAt:
            now.subtract(Duration(minutes: index)).millisecondsSinceEpoch ~/
            1000,
        content: 'Test video $index content',
        timestamp: now.subtract(Duration(minutes: index)),
        videoUrl: 'https://example.com/video_$index.mp4',
        thumbnailUrl: 'https://example.com/thumb_$index.jpg',
        title: 'Test Video $index',
        hashtags: ['test', 'video$index'],
        duration: 30 + index,
        dimensions: '1920x1080',
        fileSize: 1000000 + (index * 100000),
        mimeType: 'video/mp4',
        sha256: 'test_sha256_$index',
      );
    });
  }

  /// Create a single mock video with specific properties
  static VideoEvent createMockVideo({
    String? id,
    String? title,
    String? videoUrl,
    bool isGif = false,
    List<String>? hashtags,
  }) {
    final now = DateTime.now();
    final effectiveId = id ?? 'mock_${now.millisecondsSinceEpoch}';

    return VideoEvent(
      id: effectiveId,
      pubkey: 'mock_pubkey_$effectiveId',
      createdAt: now.millisecondsSinceEpoch ~/ 1000,
      content: title ?? 'Mock video content',
      timestamp: now,
      videoUrl:
          videoUrl ??
          (isGif
              ? 'https://example.com/video.gif'
              : 'https://example.com/video.mp4'),
      thumbnailUrl: 'https://example.com/thumb.jpg',
      title: title ?? 'Mock Video',
      hashtags: hashtags ?? ['mock', 'test'],
      duration: isGif ? 0 : 30,
      dimensions: '1920x1080',
      fileSize: 1500000,
      mimeType: isGif ? 'image/gif' : 'video/mp4',
      sha256: 'mock_sha256',
    );
  }
}
